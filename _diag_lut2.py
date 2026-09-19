# -*- coding: utf-8 -*-
"""诊断2: 单点手算插值 vs _trilinear vs scipy RegularGridInterpolator"""
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from compare_phase12 import load_datai, _trilinear
from data_io import load_mat

LUT1 = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\A_characterization\display_model\datai_ipv35_3.mat"

d = load_datai(LUT1)
cubeL = d["cubeL"]
lablut_raw = d["lablut"]
print("cubeL=", cubeL)

# 复现 compare_phase12.lut3d_rgb2xyz1 里的 lablut 构造
lablut = np.stack(
    [lablut_raw[:, ch].reshape(cubeL, cubeL, cubeL, order="F") for ch in range(3)],
    axis=-1,
)
flat = lablut.reshape(-1, 3)

rgb = np.array([[191.0, 131.0, 77.0]])
idx = rgb / 255.0 * (cubeL - 1)
print("idx_cont=", idx[0])

r0, g0, b0 = 5, 4, 2
r1, g1, b1 = 6, 5, 3
i000 = (r0 * cubeL + g0) * cubeL + b0
print(f"i000={i000}  flat[i000]={flat[i000]}")
print(f"MATLAB row r+g*9+b*81 = {r0 + g0*9 + b0*81}  lablut_raw[203]={lablut_raw[203]}")

# 8 角点 (flat C序索引)
corners_flat = {
    "000": (r0, g0, b0), "100": (r1, g0, b0), "010": (r0, g1, b0), "110": (r1, g1, b0),
    "001": (r0, g0, b1), "101": (r1, g0, b1), "011": (r0, g1, b1), "111": (r1, g1, b1),
}
print("\n--- 8 角点 (flat 索引 vs MATLAB lablut 行) ---")
for name, (r, g, b) in corners_flat.items():
    fi = (r * cubeL + g) * cubeL + b
    mr = r + g * 9 + b * 81
    print(f"  {name}: [{r},{g},{b}]  flat[{fi}]={flat[fi].round(3)}  matlab_row[{mr}]={lablut_raw[mr].round(3)}")

# _trilinear 结果
lab_tri = _trilinear(lablut, idx)
print("\n_trilinear Lab=", lab_tri[0].round(3))

# scipy RegularGridInterpolator 对照 (物理坐标 0-255)
from scipy.interpolate import RegularGridInterpolator
grid = np.linspace(0.0, 255.0, cubeL)
out = np.empty((1, 3))
for ch in range(3):
    itp = RegularGridInterpolator((grid, grid, grid), lablut[:, :, :, ch], method="linear",
                                  bounds_error=False, fill_value=None)
    out[0, ch] = itp(rgb)[0]
print("scipy Lab=", out[0].round(3))

# 手算插值 (用 flat 索引)
wr, wg, wb = 191/255*8 - 5, 131/255*8 - 4, 77/255*8 - 2
print(f"w=({wr:.4f},{wg:.4f},{wb:.4f})")
lab_hand = (
    (1-wr)*(1-wg)*(1-wb)*flat[i000]
    + wr*(1-wg)*(1-wb)*flat[(r1*cubeL+g0)*cubeL+b0]
    + (1-wr)*wg*(1-wb)*flat[(r0*cubeL+g1)*cubeL+b0]
    + (1-wr)*(1-wg)*wb*flat[(r0*cubeL+g0)*cubeL+b1]
    + wr*wg*(1-wb)*flat[(r1*cubeL+g1)*cubeL+b0]
    + wr*(1-wg)*wb*flat[(r1*cubeL+g0)*cubeL+b1]
    + (1-wr)*wg*wb*flat[(r0*cubeL+g1)*cubeL+b1]
    + wr*wg*wb*flat[(r1*cubeL+g1)*cubeL+b1]
)
print("hand Lab=", lab_hand.round(3))

# MATLAB 行索引手算 (r + g*9 + b*81)
m_000 = r0 + g0*9 + b0*81
lab_hand_m = (
    (1-wr)*(1-wg)*(1-wb)*lablut_raw[m_000]
    + wr*(1-wg)*(1-wb)*lablut_raw[r1 + g0*9 + b0*81]
    + (1-wr)*wg*(1-wb)*lablut_raw[r0 + g1*9 + b0*81]
    + (1-wr)*(1-wg)*wb*lablut_raw[r0 + g0*9 + b1*81]
    + wr*wg*(1-wb)*lablut_raw[r1 + g1*9 + b0*81]
    + wr*(1-wg)*wb*lablut_raw[r1 + g0*9 + b1*81]
    + (1-wr)*wg*wb*lablut_raw[r0 + g1*9 + b1*81]
    + wr*wg*wb*lablut_raw[r1 + g1*9 + b1*81]
)
print("hand (MATLAB行索引) Lab=", lab_hand_m.round(3))
