# -*- coding: utf-8 -*-
"""对比 MATLAB vs Python 的 test96 RGB 结果（详细逐色块差异）"""
import scipy.io as sio
import numpy as np

M_DIR = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli"
P_DIR = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python"

m_rgb = sio.loadmat(M_DIR + r"\test96_RGB.mat")["RGB"]
p_rgb = np.load(P_DIR + r"\test96_RGB_fast.npy")

diff = np.abs(m_rgb - p_rgb)
per_channel = diff.max(axis=1)

print("RGB total: max diff =", diff.max(), "mean =", diff.mean())
print("\nper-color max diff (96 colors):")
print(per_channel)

print("\ntop-5 差异最大的色块索引:")
idx = np.argsort(per_channel)[::-1][:5]
for i in idx:
    print(f"  color {i}: M={m_rgb[i]}  P={p_rgb[i]}  diff={per_channel[i]:.6f}")

# 差异 > 0.001 的色块数
n_big = (per_channel > 0.001).sum()
print(f"\n差异 > 0.001 的色块数: {n_big}/96")
n_tiny = (per_channel < 1e-6).sum()
print(f"差异 < 1e-6 的色块数: {n_tiny}/96")

# 换算成大致 dE 量级（RGB 0-255，dE 大约 = sqrt(3)*dRGB 量级，粗估）
print(f"\n最大 RGB 差 {diff.max():.6f} -> 若按 1/255 量级，约 {diff.max()*255:.4f}/255")
