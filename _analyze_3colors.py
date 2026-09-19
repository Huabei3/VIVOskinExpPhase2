# -*- coding: utf-8 -*-
"""分析 3 个差异色块的 Lab 值和去重分组"""
import scipy.io as sio
import numpy as np
from color_utils import xyz2lab
from lut_gpu import _uniquetol_matlab, _uniquetol_round

P_DIR = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python"
M_DIR = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli"

xyz = sio.loadmat(P_DIR + r"\test96_XYZ10.mat")["XYZ10"]
lut = sio.loadmat(r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\A_characterization\display_model\data_ipv30_phase2_3.mat")
XYZw = lut["XYZw"]

# XYZ -> Lab（与 lut3d 内部一致）
Lab = xyz2lab(xyz, "user", XYZw)

# matlab 语义去重
u1, f1, inv1 = _uniquetol_matlab(Lab)
# fast 语义去重
u2, f2, inv2 = _uniquetol_round(Lab, 4)

print("总色块数:", Lab.shape[0])
print("matlab 去重后组数:", len(u1))
print("fast   去重后组数:", len(u2))

# 找出 3 个差异色块（#18, #36, #54）
for i in [18, 36, 54]:
    print(f"\n--- 色块 #{i} ---")
    print(f"  Lab = {Lab[i]}")
    print(f"  matlab 组号 = {inv1[i]}, 组内成员数 = {(inv1==inv1[i]).sum()}")
    print(f"  fast   组号 = {inv2[i]}, 组内成员数 = {(inv2==inv2[i]).sum()}")

# 看看 matlab 语义下，这 3 个色块是否在同一组
print("\n--- 3 个色块的 matlab 组号 ---")
print("  #18 组号:", inv1[18], " #36 组号:", inv1[36], " #54 组号:", inv1[54])
print("  #18 组内所有成员:", np.where(inv1 == inv1[18])[0])
print("  #36 组内所有成员:", np.where(inv1 == inv1[36])[0])
print("  #54 组内所有成员:", np.where(inv1 == inv1[54])[0])

# 计算这 3 个色块的 Lab 两两差异
print("\n--- Lab 两两差异 ---")
print("  #18 vs #36:", np.max(np.abs(Lab[18]-Lab[36])))
print("  #18 vs #54:", np.max(np.abs(Lab[18]-Lab[54])))
print("  #36 vs #54:", np.max(np.abs(Lab[36]-Lab[54])))
print("  tol (0.01/max(max(Lab))) =", 0.01/np.max(np.abs(Lab)))
