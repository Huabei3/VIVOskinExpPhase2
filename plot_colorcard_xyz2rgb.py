# -*- coding: utf-8 -*-
"""plot_colorcard_xyz2rgb.py — Python 版，模仿 MATLAB plot_colorcard_xyz2rgb.m

功能对齐：
  XYZ_mea{3}（第 3 台手机 96 色 XYZ 测量值）分别用两种 LUT_type 转为 RGB，
  再用 datai 反算 RGB->XYZ，求 phase1 vs phase2 的 CIEDE2000 色差，
  最后 24 个色块画两张 4x6 色卡。

关键差异（用户指定）：
  RGB_all{k} 处 MATLAB 用 lut3d_xyz2rgbNoParitp，
  Python 版改用 python 管线自带的 lut3d_xyz2rgbKDitp1（lut_gpu.py）。
  另内置 lut3d_xyz2rgbNoParitp 的 Python 复刻作为算法对齐参考，
  用于判断 KDitp1(带 uniquetol 去重) 与 NoParitp(逐点) 结果是否一致。

依赖（vivorender 环境）: numpy scipy torch pandas PIL
输出:
  colorcard_xyz_mea3_python_phase1.png / _phase2.png   (PIL 绘制 4x6 色卡)
  colorcard_xyz_mea3_python.xlsx                       (多 sheet 数值, 便于和 MATLAB 对比)
"""

from __future__ import annotations

import os
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from scipy.interpolate import RegularGridInterpolator
from PIL import Image, ImageDraw, ImageFont

# 让脚本可以从任意 cwd 运行，import 同目录模块
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from color_utils import xyz2lab, lab2xyz2, deltaE2000  # noqa: E402
from data_io import load_mat, load_lut                  # noqa: E402
from lut_gpu import lut3d_xyz2rgbKDitp1                 # noqa: E402

# ---------------------------------------------------------------------------
# 0. 路径配置（与 MATLAB 版一致）
# ---------------------------------------------------------------------------
SCRIPT_DIR    = HERE
MODEL_INTERP  = Path(r"D:\work\VIVOSkin_phase2\display\model_interp")
MODEL_PHASE1  = Path(r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\A_characterization\display_model")

XYZ_MEA_PATH  = MODEL_INTERP / "XYZ_mea.mat"

# LUT_type -> (正向 datafile, 反向 datai_file)
LUT_TYPES = ["phase1", "phase2"]
DATAFILES  = [
    MODEL_PHASE1 / "data_ipv35_3.mat",
    MODEL_INTERP / "data_ipv30_phase2_3.mat",
]
DATAI_FILES = [
    MODEL_PHASE1 / "datai_ipv35_3.mat",
    MODEL_INTERP / "datai_ipv30_phase2_3.mat",
]


# ---------------------------------------------------------------------------
# 1. lut3d_xyz2rgbNoParitp 的 Python 复刻（算法对齐参考，逐点无去重）
#    MATLAB 源: 3D MODEL\lut3d_xyz2rgbNoParitp.m
# ---------------------------------------------------------------------------
def lut3d_xyz2rgbNoParitp(XYZ: np.ndarray, lut: dict) -> tuple[np.ndarray, float]:
    """逐点 KNN(K=8) + 距离倒数权重，等价 MATLAB NoParitp（无 uniquetol 去重）。"""
    P_labs = np.asarray(lut["P_labs"], dtype=np.float64)   # (N,3)
    rgb    = np.asarray(lut["rgb"],    dtype=np.float64)   # (N,3)
    XYZw   = np.asarray(lut["XYZw"],   dtype=np.float64)   # (1,3)

    XYZ = np.asarray(XYZ, dtype=np.float64)
    if XYZ.ndim == 1:
        XYZ = XYZ.reshape(1, 3)

    Lab = xyz2lab(XYZ, "user", XYZw)                       # (M,3)

    # 用 scipy cKDTree 复刻 knnsearch('K', 8)，欧氏距离
    from scipy.spatial import cKDTree
    tree = cKDTree(P_labs)
    _, idx = tree.query(Lab, k=8)                          # (M,8)

    d = np.linalg.norm(Lab[:, None, :] - P_labs[idx], axis=2)   # (M,8)
    w = 1.0 / d                                            # 距离倒数（0 距 -> inf）
    w = w / w.sum(axis=1, keepdims=True)                   # 归一化（inf/inf -> NaN，同 MATLAB）

    RGB = (w[..., None] * rgb[idx]).sum(axis=1)            # (M,3)

    # out_of_gamut_ratio（clip 前）
    out_of_gamut = int(np.sum(np.any((RGB < 0) | (RGB > 255), axis=1)))
    out_of_gamut_ratio = out_of_gamut / RGB.shape[0]

    # fillmissing 'nearest' 逐列（MATLAB fillmissing nearest）
    for c in range(3):
        col = RGB[:, c]
        mask = np.isnan(col) | np.isinf(col)
        if mask.any():
            valid = np.flatnonzero(~mask)
            miss = np.flatnonzero(mask)
            if valid.size:
                nearest = valid[np.argmin(np.abs(valid[:, None] - miss), axis=0)]
                col = col.copy()
                col[miss] = col[nearest]
            RGB[:, c] = col

    # clip（保持 MATLAB 顺序）
    RGB[(RGB < 0) | np.isnan(RGB) | np.isinf(RGB)] = 0
    RGB[(RGB >= 0) & np.isinf(RGB)] = 255
    RGB[(RGB <= 0) & np.isinf(RGB)] = 0
    RGB[RGB > 255] = 255
    return RGB, out_of_gamut_ratio


# ---------------------------------------------------------------------------
# 2. lut3d_rgb2xyz1 的 Python 复刻（interp3 'linear' + lab2xyz2）
#    MATLAB 源: I_render_stimuli\utils\lut3d_rgb2xyz1.m
# ---------------------------------------------------------------------------
def lut3d_rgb2xyz1(RGB: np.ndarray, datai_file: Path) -> np.ndarray:
    """RGB(0-255, Mx3) -> XYZ。interp3('linear') 等价 RegularGridInterpolator。"""
    d = load_mat(datai_file)
    cubeL = int(np.asarray(d["cubeL"]).flatten()[0])
    lablut = np.asarray(d["lablut"], dtype=np.float64)     # (cubeL^3, 3)
    XYZw = np.asarray(d["XYZw"], dtype=np.float64).reshape(1, 3)

    RGB = np.asarray(RGB, dtype=np.float64)
    if RGB.ndim == 1:
        RGB = RGB.reshape(1, 3)

    grid = np.linspace(0.0, 255.0, cubeL)                  # 与 meshgrid(linspace(0,255,cubeL)) 对齐
    lutL = lablut[:, 0].reshape(cubeL, cubeL, cubeL)
    lutA = lablut[:, 1].reshape(cubeL, cubeL, cubeL)
    lutB = lablut[:, 2].reshape(cubeL, cubeL, cubeL)

    pts = (grid, grid, grid)
    lout = RegularGridInterpolator(pts, lutL, method="linear",
                                   bounds_error=False, fill_value=None)(RGB)
    aout = RegularGridInterpolator(pts, lutA, method="linear",
                                   bounds_error=False, fill_value=None)(RGB)
    bout = RegularGridInterpolator(pts, lutB, method="linear",
                                   bounds_error=False, fill_value=None)(RGB)

    P = np.column_stack([lout, aout, bout])                # (M,3) Lab
    XYZ = lab2xyz2(P, "user", XYZw)
    return XYZ


# ---------------------------------------------------------------------------
# 3. 绘制 4x6 色卡（PIL，布局与 MATLAB plot_colorcard 一致）
# ---------------------------------------------------------------------------
def plot_colorcard(RGB24: np.ndarray, idx: np.ndarray, lut_name: str, out_path: Path):
    """RGB24: 24x3 (0-255)，4 行 x 6 列；第 1 行在最上。"""
    nrow, ncol = 4, 6
    cell_w, cell_h = 120, 120
    pad = 80
    W = ncol * cell_w + 2 * pad
    H = nrow * cell_h + 2 * pad + 60

    img = Image.new("RGB", (W, H), "white")
    draw = ImageDraw.Draw(img)
    try:
        font = ImageFont.truetype("arial.ttf", 14)
    except Exception:
        font = ImageFont.load_default()

    for i in range(24):
        col = (i - 1) % ncol
        row = nrow - 1 - (i - 1) // ncol
        c = np.clip(RGB24[i] / 255.0, 0.0, 1.0)
        color = tuple(int(round(v * 255)) for v in c)
        x0, y0 = pad + col * cell_w, pad + row * cell_h
        x1, y1 = x0 + cell_w, y0 + cell_h
        draw.rectangle([x0, y0, x1, y1], fill=color, outline=(204, 204, 204), width=1)

        lum = 0.299 * RGB24[i, 0] + 0.587 * RGB24[i, 1] + 0.114 * RGB24[i, 2]
        tc = (0, 0, 0) if lum > 128 else (255, 255, 255)
        txt = f"#{idx[i]}\n({int(round(RGB24[i,0]))},{int(round(RGB24[i,1]))},{int(round(RGB24[i,2]))})"
        bbox = draw.multiline_textbbox((0, 0), txt, font=font, align="center", spacing=4)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        draw.multiline_text((x0 + (cell_w - tw) / 2, y0 + (cell_h - th) / 2),
                            txt, fill=tc, font=font, align="center", spacing=4)

    title = f"XYZ_mea{{3}} last 24 -> RGB  (LUT={lut_name})"
    draw.text((pad, H - 40), title, fill=(0, 0, 0), font=font)
    img.save(out_path)
    print(f"已保存: {out_path}")


# ---------------------------------------------------------------------------
# 4. 主流程
# ---------------------------------------------------------------------------
def main():
    # ---- 加载 XYZ_mea{3} ----
    raw = load_mat(XYZ_MEA_PATH)
    XYZ = np.asarray(raw["XYZ_mea"])[0, 2].astype(np.float64)   # 96x3
    assert XYZ.shape == (96, 3), f"XYZ_mea{{3}} 应为 96x3, 实际 {XYZ.shape}"
    print(f"XYZ_mea{{3}}: shape={XYZ.shape}")

    # ---- 两种 LUT 转换 XYZ -> RGB，并反算 RGB -> XYZ ----
    RGB_all, XYZ_all, ratio_all = [], [], []
    for k, (name, df, di) in enumerate(zip(LUT_TYPES, DATAFILES, DATAI_FILES)):
        lut = load_lut(df)
        # ① Python 管线逻辑: lut3d_xyz2rgbKDitp1
        RGB_k, ratio_k = lut3d_xyz2rgbKDitp1(XYZ, lut=lut)
        # ② 算法对齐参考: NoParitp 复刻（逐点无去重）
        RGB_np, ratio_np = lut3d_xyz2rgbNoParitp(XYZ, lut)
        diff = np.abs(RGB_k - RGB_np)
        print(f"\n[{name}] {df.name}")
        print(f"  KDitp1  : out_of_gamut_ratio={ratio_k:.4f}")
        print(f"  NoParitp: out_of_gamut_ratio={ratio_np:.4f}")
        print(f"  KDitp1 vs NoParitp(复刻) 最大差={diff.max():.6f} 平均差={diff.mean():.6f}")

        RGB_all.append(RGB_k)
        ratio_all.append(ratio_k)

        # 反算 RGB -> XYZ
        XYZ_all.append(lut3d_rgb2xyz1(RGB_k, di))
        print(f"  反算 XYZ_all 前3行:\n{XYZ_all[-1][:3]}")

    _, ind_max = np.unravel_index(np.argmax(XYZ[:, 1]), XYZ.shape)  # Y 最大 = 白点
    # 简化：直接取 Y 最大的行索引
    XYZw_meas = XYZ[int(np.argmax(XYZ[:, 1])), :].reshape(1, 3)
    lab1 = xyz2lab(XYZ_all[0], "user", XYZw_meas)
    lab2 = xyz2lab(XYZ_all[1], "user", XYZw_meas)
    de00, _ = deltaE2000(lab1, lab2)
    de00 = de00.ravel()  # 96x1

    print("\n===== XYZ_all{1}(phase1) vs XYZ_all{2}(phase2) 色差 CIEDE2000 =====")
    print(f"全部 96 色:  mean dE00 = {de00.mean():.4f},  max dE00 = {de00.max():.4f}")
    print(f"最后 24 色:  mean dE00 = {de00[73:96].mean():.4f},  max dE00 = {de00[73:96].max():.4f}")

    # ---- 最后 24 色块画两张 4x6 色卡 ----
    last_idx = np.arange(73, 97)
    for k, name in enumerate(LUT_TYPES):
        RGB24 = RGB_all[k][last_idx - 1, :]  # 第 73~96 行（1-based）-> index 72~95
        fname = f"colorcard_xyz_mea3_python_{name}.png"
        plot_colorcard(RGB24, last_idx, name, SCRIPT_DIR / fname)

    # ---- 保存数值 xlsx（多 sheet，便于与 MATLAB 版对比）----
    xlsx_path = SCRIPT_DIR / "colorcard_xyz_mea3_python.xlsx"
    with pd.ExcelWriter(xlsx_path, engine="openpyxl") as writer:
        for k, name in enumerate(LUT_TYPES):
            df_rgb = pd.DataFrame(RGB_all[k], columns=["R", "G", "B"])
            df_rgb.to_excel(writer, sheet_name=f"RGB_{name}", index=False)
            df_xyz = pd.DataFrame(XYZ_all[k], columns=["X", "Y", "Z"])
            df_xyz.to_excel(writer, sheet_name=f"XYZ_{name}", index=False)
        pd.DataFrame({"de00": de00}).to_excel(writer, sheet_name="de00", index=False)
    print(f"\n已保存: {xlsx_path}")

    # ---- 与 MATLAB 版对比的数值打印（若 MATLAB 端有保存 RGB 数值可填）----
    print("\n===== 色块 RGB 值（供与 MATLAB 版对比）=====")
    for k, name in enumerate(LUT_TYPES):
        print(f"\n[{name}] last 24 色块 RGB (0-255):")
        for i in range(24):
            idx_ = 73 + i
            r, g, b = RGB_all[k][idx_ - 1]
            print(f"  #{idx_}: R={r:.2f} G={g:.2f} B={b:.2f}")


if __name__ == "__main__":
    main()
