# -*- coding: utf-8 -*-
"""分析 3 个差异色块的 KNN 中间结果（距离/权重/邻域）"""
import scipy.io as sio
import numpy as np
from color_utils import xyz2lab

P_DIR = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python"
LUT = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\A_characterization\display_model\data_ipv30_phase2_3.mat"

xyz = sio.loadmat(P_DIR + r"\test96_XYZ10.mat")["XYZ10"]
lut = sio.loadmat(LUT)
XYZw = lut["XYZw"]
P_labs = lut["P_labs"]
rgb = lut["rgb"]

Lab = xyz2lab(xyz, "user", XYZw)

for i in [18, 36, 54]:
    q = Lab[i]
    # 计算到所有 P_labs 的距离
    dist = np.linalg.norm(P_labs - q, axis=1)
    # 最近 8 个
    idx8 = np.argsort(dist)[:8]
    d8 = dist[idx8]
    print(f"\n--- 色块 #{i}  Lab={q} ---")
    print(f"  8 最近邻距离: {d8}")
    print(f"  8 最近邻索引: {idx8}")
    print(f"  是否有 0 距离: {(d8 < 1e-12).any()}")
    print(f"  8 邻域 rgb: {rgb[idx8]}")
    # 权重
    w = 1.0 / d8
    print(f"  权重(未归一): {w}")
    print(f"  权重和: {w.sum()}")
    w_norm = w / w.sum()
    print(f"  归一化权重: {w_norm}")
    rgb_out = (w_norm[:, None] * rgb[idx8]).sum(axis=0)
    print(f"  RGB 加权结果: {rgb_out}")
