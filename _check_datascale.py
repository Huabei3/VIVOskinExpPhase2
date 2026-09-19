# -*- coding: utf-8 -*-
"""验证 MATLAB uniquetol 的 DataScale 默认语义"""
import numpy as np
import scipy.io as sio
from color_utils import xyz2lab

P_DIR = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python"
LUT = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\A_characterization\display_model\data_ipv30_phase2_3.mat"

xyz = sio.loadmat(P_DIR + r"\test96_XYZ10.mat")["XYZ10"]
lut = sio.loadmat(LUT)
XYZw = lut["XYZw"]
Lab = xyz2lab(xyz, "user", XYZw)

# MATLAB uniquetol 默认 DataScale = max(abs(A), [], 1) 按列
DataScale = np.max(np.abs(Lab), axis=0)
print("DataScale (按列 max abs):", DataScale)

tol = 0.01 / np.max(np.abs(Lab))  # 0.01/max(max(Lab))
print(f"tol = 0.01/max(max(Lab)) = {tol:.8f}")

# 实际容差 = tol * DataScale（按元素）
actual_tol = tol * DataScale
print(f"实际容差 (tol * DataScale) = {actual_tol}")

labs = {18: Lab[18], 36: Lab[36], 54: Lab[54]}
print("\n3 色块逐元素差 vs 实际容差:")
pairs = [(18, 36), (18, 54), (36, 54)]
for a, b in pairs:
    diff = np.abs(labs[a] - labs[b])
    ok = diff <= actual_tol
    print(f"  #{a} vs #{b}: diff={diff}  全部<=tol? {ok.all()}")

# 结论：若按元素 abs(diff) <= tol*DataScale 判断，3 色块应归一组
print("\nMATLAB uniquetol 语义:")
print("  'DataScale' 默认 = max(abs(A), [], 1) (按列)")
print("  判断: abs(A(i,:)-A(j,:)) <= tol * DataScale  (逐元素)")
print(f"  => 实际容差 ≈ {actual_tol[0]:.6f} (L通道), 3色块L差只有0.0002~0.0004 << 容差, 故归一组")
