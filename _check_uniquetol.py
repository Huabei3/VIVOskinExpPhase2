# -*- coding: utf-8 -*-
"""验证 MATLAB uniquetol 的距离度量（欧氏 vs 无穷范数）"""
import numpy as np
import scipy.io as sio
from color_utils import xyz2lab

P_DIR = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python"
LUT = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\A_characterization\display_model\data_ipv30_phase2_3.mat"

xyz = sio.loadmat(P_DIR + r"\test96_XYZ10.mat")["XYZ10"]
lut = sio.loadmat(LUT)
XYZw = lut["XYZw"]
Lab = xyz2lab(xyz, "user", XYZw)

# 3 个差异色块
labs = {18: Lab[18], 36: Lab[36], 54: Lab[54]}

tol = 0.01 / np.max(np.abs(Lab))
print(f"tol = 0.01/max(max(Lab)) = {tol:.10f}")
print(f"max(max(Lab)) = {np.max(np.abs(Lab)):.6f}")

print("\nLab 值:")
for k, v in labs.items():
    print(f"  #{k}: {v}")

print("\n两两距离对比:")
pairs = [(18, 36), (18, 54), (36, 54)]
for a, b in pairs:
    diff = labs[a] - labs[b]
    inf_norm = np.max(np.abs(diff))
    euclid = np.sqrt(np.sum(diff**2))
    print(f"  #{a} vs #{b}: 无穷范数={inf_norm:.8f}  欧氏={euclid:.8f}  <= tol? 无穷:{inf_norm<=tol} 欧氏:{euclid<=tol}")

# 检查：如果欧氏距离 <= tol，则 3 个色块应归同一组
print("\n结论:")
e1 = np.sqrt(np.sum((labs[18]-labs[36])**2))
e2 = np.sqrt(np.sum((labs[18]-labs[54])**2))
e3 = np.sqrt(np.sum((labs[36]-labs[54])**2))
print(f"  欧氏距离: #18-36={e1:.8f}, #18-54={e2:.8f}, #36-54={e3:.8f}")
print(f"  若 MATLAB 用欧氏且 tol={tol:.8f}，则都 > tol，不应归一组")
print(f"  若 MATLAB 用 max(max(Lab)) 取的是'按列'而非全局，需重新算 tol")
