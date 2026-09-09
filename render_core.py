# -*- coding: utf-8 -*-
r"""render_core.py — 批次5：img_AddRender_simp 1:1 还原 MATLAB

MATLAB 源: utils\img_AddRender_simp.m, utils\xyz2srgb.m
依赖: color_utils(xyz2lab/lab2xyz2), mask(read_bull/get_average),
      lut_gpu(lut3d_xyz2rgbKDitp1), data_io(load_lut)
主链路 render_type='LUT'（matrix==3）。
"""
from __future__ import annotations

import numpy as np
from pathlib import Path
from scipy.io import loadmat, savemat

from color_utils import xyz2lab, lab2xyz2
from mask import read_bull, get_average
from lut_gpu import lut3d_xyz2rgbKDitp1


_XYZ2SRGB_M = np.array([
    [3.2406, -1.5372, -0.4986],
    [-0.9689, 1.8758, 0.0415],
    [0.0557, -0.2040, 1.0570],
])


def xyz2srgb(XYZ):
    """等价 MATLAB xyz2srgb(XYZ) -> RGB, flag, outofgamut（0~1）。"""
    xyz = np.asarray(XYZ, dtype=np.float64).reshape(-1, 3)
    sRGB = (xyz / 100.0) @ _XYZ2SRGB_M.T
    channel = (sRGB > 1) | (sRGB < 0)
    outofgamut = float(np.sum(channel[:, 0] | channel[:, 1] | channel[:, 2]) / len(sRGB))
    flag = 1 if outofgamut != 0 else 0
    sRGB = np.clip(sRGB, 0.0, 1.0)
    g = 1.0 / 2.4
    RGB = 1.055 * np.power(sRGB, g) - 0.055
    RGB[sRGB <= 0.0031308] = sRGB[sRGB <= 0.0031308] * 12.92
    return RGB, flag, outofgamut


def img_AddRender_simp(img, bull, bull_nosd, render_type, delta_Lab, XYZ,
                       noFaceRGB_file, if_wei, if_2mask, handle=None,
                       data_root=None, xyz2_file=None, outnew_file=None,
                       delta_lab_file=None, lab2_file=None):
    """等价 MATLAB img_AddRender_simp。

    Args:
        img: (m,n,3) float
        bull / bull_nosd: (m,n,3) uint8 mask
        render_type: 'srgb' | 'polynomial' | 'LUT'
        delta_Lab: (3,) 或 (1,3)
        XYZ: (m,n,3) 或 (m*n,3)
        noFaceRGB_file: 背景 LUT 缓存 .mat（变量名 noFaceRGB，与 MATLAB 兼容）
        if_wei, if_2mask: bool
        handle: dict 含 LUT_type（"phase1"/"phase2"）与可选 dedup_mode
                （"matlab"/"fast"/"none"），None=phase1
        data_root: C_VIVO_skin_project 根，默认本文件上上级
        xyz2_file / outnew_file: 可选，保存 LUT 映射前 XYZ / 映射后 RGB 的 .mat
        delta_lab_file / lab2_file: 可选，保存 delta_Lab / lab2 的 .mat（调试用）

    Returns:
        outnew (m,n,3) float, dest_lab (3,), bull_nosd, lab2 (m*n,3)
    """
    if handle is None or not isinstance(handle, dict) or "LUT_type" not in handle:
        LUT_type = "phase1"
    else:
        LUT_type = handle["LUT_type"]
    # dedup_mode 透传给 lut3d_xyz2rgbKDitp1（matlab/fast/none），默认 fast（保持既有加速语义）
    dedup_mode = "fast"
    if isinstance(handle, dict) and "dedup_mode" in handle:
        dedup_mode = handle["dedup_mode"]
    # device 透传给 lut3d_xyz2rgbKDitp1（auto/cuda/cpu），默认 auto（有 CUDA 自动走 GPU）
    device = "auto"
    if isinstance(handle, dict) and "device" in handle:
        device = handle["device"]
    matrix = {"srgb": 1, "polynomial": 2, "LUT": 3}[render_type]

    img = np.asarray(img, dtype=np.float64)
    m, n = img.shape[0], img.shape[1]

    logicalIndex, bull_weight = read_bull(bull, if_wei)
    logicalIndex_nosd, _ = read_bull(bull_nosd, if_wei)

    if data_root is None:
        data_root = Path(__file__).resolve().parent.parent
    data_root = Path(data_root)
    if LUT_type == "phase2":
        datai_file = data_root / "A_characterization" / "display_model" / "data_ipv30_phase2_3.mat"
    else:
        datai_file = data_root / "A_characterization" / "display_model" / "data_ipv35_3.mat"

    wd65 = np.array([94.813, 100.000, 107.262])
    lut = loadmat(str(datai_file))
    XYZw_LUT = np.asarray(lut["XYZw"], dtype=np.float64).reshape(1, 3)
    wd65_scaled = wd65 / 100.0 * XYZw_LUT[0, 1]

    XYZ = np.asarray(XYZ, dtype=np.float64)
    if XYZ.ndim == 3:
        xyz1 = XYZ.reshape(m * n, 3)
    else:
        xyz1 = XYZ.reshape(m * n, 3)

    lab1 = xyz2lab(xyz1, "user", wd65_scaled)
    delta_lab_vec = np.asarray(delta_Lab, dtype=np.float64).reshape(1, 3)
    # 保存 delta_Lab（可选；调试用，与 MATLAB 侧对齐）
    if delta_lab_file is not None:
        savemat(str(delta_lab_file), {"delta_lab": delta_lab_vec})
        print(f"  delta_lab saved: {delta_lab_file}")
    lab2 = lab1 + delta_lab_vec * bull_weight.reshape(-1, 1)
    sd_idx = (~logicalIndex) & logicalIndex_nosd
    lab2[sd_idx, 1] = np.maximum(0, lab2[sd_idx, 1])
    lab2[sd_idx, 2] = np.maximum(0, lab2[sd_idx, 2])
    if if_2mask:
        dest_lab = get_average(lab2, bull_nosd, if_wei)
    else:
        dest_lab = get_average(lab2, bull, if_wei)

    # 保存 lab2（可选；调试用，与 MATLAB 侧对齐）
    if lab2_file is not None:
        lab2_img = lab2.reshape(m, n, 3)
        savemat(str(lab2_file), {"lab2_img": lab2_img})
        print(f"  lab2 saved: {lab2_file}")

    xyz2 = lab2xyz2(lab2, "user", wd65_scaled)
    xyz2[logicalIndex, :] = xyz1[logicalIndex, :]

    # 保存 LUT 映射前的中间变量 xyz2（可选；与输出 jpg 同名 .mat，变量名 xyz2_img 与 MATLAB 对齐）
    if xyz2_file is not None:
        xyz2_img = xyz2.reshape(m, n, 3)
        savemat(str(xyz2_file), {"xyz2_img": xyz2_img})
        print(f"  xyz2 saved: {xyz2_file}")

    if matrix == 1:
        xyz2_s = xyz2 / XYZw_LUT[0, 1] * 100.0
        rgbnew, _, _ = xyz2srgb(xyz2_s)
    elif matrix == 2:
        raise NotImplementedError("matrix==2 (polynomial) 分支原 MATLAB 未用")
    else:
        datafile = datai_file
        noFaceRGB_file = Path(noFaceRGB_file)
        n_face = int(np.count_nonzero(logicalIndex))
        noFaceRGB = None
        if noFaceRGB_file.exists():
            cached = np.asarray(loadmat(str(noFaceRGB_file))["noFaceRGB"], dtype=np.float64)
            if cached.ndim == 2 and cached.shape[0] == n_face:
                noFaceRGB = cached
        if noFaceRGB is None:
            noFaceRGB, _ = lut3d_xyz2rgbKDitp1(xyz2[logicalIndex, :], datafile=str(datafile),
                                                dedup_mode=dedup_mode, device=device)
            savemat(str(noFaceRGB_file), {"noFaceRGB": noFaceRGB})
        rgbnew_bull1, _ = lut3d_xyz2rgbKDitp1(xyz2[~logicalIndex, :], datafile=str(datafile),
                                              dedup_mode=dedup_mode, device=device)
        rgbnew = np.zeros_like(xyz2)
        if noFaceRGB is not None and noFaceRGB.size > 0:
            rgbnew[logicalIndex, :] = noFaceRGB
        if rgbnew_bull1 is not None and rgbnew_bull1.size > 0:
            rgbnew[~logicalIndex, :] = rgbnew_bull1
        rgbnew = rgbnew / 255.0

    outxyz = xyz2.reshape(m, n, 3)
    outnew = rgbnew.reshape(m, n, 3)

    # 保存 LUT 映射后的 RGB outnew（可选；用于和 MATLAB 管线逐像素对比）
    if outnew_file is not None:
        outnew_img = outnew
        savemat(str(outnew_file), {"outnew_img": outnew_img})
        print(f"  outnew saved: {outnew_file}")

    return outnew, dest_lab, bull_nosd, lab2
