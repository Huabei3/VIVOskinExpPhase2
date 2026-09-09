# -*- coding: utf-8 -*-
"""test_lut_96color.py — 96 色块 XYZ -> phase2 LUT -> RGB（Python 侧，无并行）

数据流（与 MATLAB DiffLUT729pre96backKDVall1.m 对齐）：
  1. load VIVO_CS2000_96_x200_3_mode96*.mat 的 DATAs
  2. DATAs(1,:) = [] 删表头
  3. SPD = reshape(cell2mat(DATAs(:,4)), 401, 96)   # 380:1:780 nm
  4. XYZ10 = spd2xyz([SPDname SPD], 10)              # 96x3 XYZ (10° observer)
  5. RGB = lut3d_xyz2rgbKDitp1_nopar(XYZ10, data_ipv30_phase2_3.mat)

输出（全部 dump 到本目录，与 MATLAB 侧对齐对比）：
  - test96_XYZ10.npy / .mat   (96x3)
  - test96_RGB.npy  / .mat    (96x3)

用法：
  python test_lut_96color.py
  python test_lut_96color.py --dedup-mode matlab   # 或 fast
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import scipy.io as sio

HERE = Path(__file__).resolve().parent

# ---- 路径 ----
DATA96 = Path(r"D:\work\VIVOSkin_phase2\display\x200\VIVO_CS2000_96_x200_3_mode962026_08_06_11_30_07.mat")
LUT_BACK = Path(r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\A_characterization\display_model\data_ipv30_phase2_3.mat")


# =====================================================================
# spd2xyz 复刻（对齐 MATLAB utils/spd2xyz.m，obs=10，AorR=1 默认，rfldata=0）
# =====================================================================
def _selectcmf10():
    """等价 selectcmf(10)：返回 (cmf, k)。cmf 为 (N,4)，列 = [lambda, xbar, ybar, zbar]。"""
    from _cmf_data import CMF10
    cmf = np.asarray(CMF10, dtype=np.float64)
    return cmf, 683.6


def _cieinterp(X, Y, Xnew):
    """等价 MATLAB CIEinterp(...,'linear')：interp1 线性插值 + 负值归零。

    X: (N,) 原波长；Y: (N,) 原值；Xnew: (M,) 目标波长（均落在 [X[0], X[-1]] 内，不 extrap）。
    """
    return np.interp(Xnew, X, Y)


def spd2xyz(spd, obs=10):
    """等价 MATLAB spd2xyz(spd, obs)。spd: (N, 1+numSpds)，第1列波长，其余 SPD 列。

    返回 XYZ: (numSpds, 3)。（本测试 AorR 默认 1=absolute，rfldata=0=selfluminous）
    """
    spd = np.asarray(spd, dtype=np.float64)
    lambdas = spd[:, 0]
    spd = spd[:, 1:]  # (N, numSpds)

    cmf, k = _selectcmf10()  # cmf: (471,4) 360:1:830

    # MATLAB L37: 只保留 360<=lambda<=830（SPD 380:1:780 全在范围内）
    # L43-47: 计算 dl（对等间隔 380:1:780，dl 全 1）
    d = np.diff(lambdas)
    d1 = np.concatenate([[d[0]], d[:-1] / 2.0, [d[-1]]])
    d2 = np.concatenate([[0.0], d[1:] / 2.0, [0.0]])
    dl = d1 + d2

    # L51: 快速路径判断（380:1:780 步长1 满足 dl(1)=1, lambdas(1)=380, lambdas(end)=780）
    # 但注意 MATLAB 条件是 abs(dl(1)-dl(2))==abs(mean(dl))，dl 全 1 时 0==1 为 false
    # -> 走 else 分支，用 CIEinterp 把 cmf 插值到 lambdas
    # （严谨起见，此处直接按 MATLAB else 分支复刻：CIEinterp 到 lambdas）
    cmf_interp = np.empty((lambdas.shape[0], 3))
    for c in range(3):
        cmf_interp[:, c] = _cieinterp(cmf[:, 0], cmf[:, c + 1], lambdas)

    # L60-65: AorR==1（absolute），k = k * ones(numSpds)
    # L93-105: rfldata==0 -> rfl=ones，selfluminous
    # XYZ = k * sum(spd .* cmf .* dl)
    num_spds = spd.shape[1]
    XYZ = np.empty((num_spds, 3))
    for j in range(num_spds):
        s = spd[:, j]
        for c in range(3):
            XYZ[j, c] = k * np.sum(s * cmf_interp[:, c] * dl)
    return XYZ


# =====================================================================
# 无并行 KDitp1（复用 lut_gpu.lut3d_xyz2rgbKDitp1，device='cpu'，本身无并行）
# =====================================================================
def lut3d_xyz2rgbKDitp1_nopar(XYZ, datafile, dedup_mode="fast"):
    from lut_gpu import lut3d_xyz2rgbKDitp1
    RGB, ratio = lut3d_xyz2rgbKDitp1(XYZ, datafile=str(datafile),
                                     device="cpu", dedup_mode=dedup_mode)
    return RGB, ratio


def main():
    ap = argparse.ArgumentParser(description="96 色块 XYZ -> phase2 LUT -> RGB（Python）")
    ap.add_argument("--dedup-mode", choices=["matlab", "fast"], default="fast")
    args = ap.parse_args()

    # 1-3. 读 DATAs -> 删表头 -> SPD (401x96)
    d = sio.loadmat(str(DATA96))
    DA = d["DATAs"]
    DA = DA[1:, :]  # 删表头
    spd_cols = [DA[r, 3].reshape(-1) for r in range(DA.shape[0])]
    SPD = np.stack(spd_cols, axis=1)  # (401, 96)
    SPDname = np.arange(380, 781, 1.0).reshape(-1, 1)  # (401,1)
    spd_matrix = np.hstack([SPDname, SPD])  # (401, 97)

    # 4. XYZ10 (96x3)
    XYZ10 = spd2xyz(spd_matrix, 10)
    print(f"[info] XYZ10 shape={XYZ10.shape}")
    print("XYZ10 前3行:\n", XYZ10[:3])

    # 5. RGB (96x3)
    RGB, ratio = lut3d_xyz2rgbKDitp1_nopar(XYZ10, LUT_BACK, dedup_mode=args.dedup_mode)
    print(f"[info] RGB shape={RGB.shape}  out_of_gamut_ratio={ratio:.6f}")
    print("RGB 前3行:\n", RGB[:3])

    # 输出
    tag = args.dedup_mode
    np.save(str(HERE / f"test96_XYZ10.npy"), XYZ10)
    np.save(str(HERE / f"test96_RGB_{tag}.npy"), RGB)
    sio.savemat(str(HERE / f"test96_XYZ10.mat"), {"XYZ10": XYZ10})
    sio.savemat(str(HERE / f"test96_RGB_{tag}.mat"), {"RGB": RGB})
    print(f"[done] 已写出 test96_XYZ10.mat / test96_RGB_{tag}.mat")


if __name__ == "__main__":
    main()
