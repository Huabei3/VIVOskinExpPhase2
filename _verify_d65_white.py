# -*- coding: utf-8 -*-
"""Decisive verify: avg_b is negative purely due to reference-white mismatch?
Recompute the SAME inverse LUT chain but convert absolute XYZ -> Lab with a
standard D65 white point (Y normalized to 100) instead of wd65_scaled."""
import numpy as np
import sys
from pathlib import Path
sys.path.insert(0, r'D:/work/VIVOSkinExpe/PeggySkinBackup/A_code/C_VIVO_skin_project/I_render_stimuli_python')
from data_io import load_mat, imread
from mask import read_bull
from color_utils import xyz2lab, lab2xyz2, deltaE2000

HERE = Path(r'D:/work/VIVOSkinExpe/PeggySkinBackup/A_code/C_VIVO_skin_project/I_render_stimuli_python')
PROJ = HERE.parent / 'I_render_stimuli'
RENDER_I = PROJ / 'rendered_python' / 'phase2' / 'i'
MASK_ROOT = PROJ / 'mask'
DATAI_P1 = HERE.parent / 'A_characterization' / 'display_model' / 'datai_ipv35_3.mat'
DATAI_P2 = Path(r'D:\work\VIVOSkin_phase2\display\model_interp\datai_ipv30_phase2_3.mat')
WD65 = np.array([94.813, 100.0, 107.262], dtype=np.float64)
D65_64 = np.array([94.813, 100.0, 107.262], dtype=np.float64)

sys.path.insert(0, str(HERE))
from compare_phase12 import load_datai, lut3d_rgb2xyz1, wd65_scaled_of

jpg = RENDER_I / 'f01i' / 'HD65_33[58.3819,12.8181,11.8966].jpg'
mask_f = MASK_ROOT / 'f01i' / 'HD65.jpg'
print('jpg exists :', jpg.exists())
print('mask exists:', mask_f.exists())

lab_target = np.array([58.3819, 12.8181, 11.8966])

p1 = load_datai(DATAI_P1)
p2 = load_datai(DATAI_P2)
wd1 = wd65_scaled_of(p1)
wd2 = wd65_scaled_of(p2)
print('wd65_scaled_p1 =', np.round(wd1, 4))
print('wd65_scaled_p2 =', np.round(wd2, 4))

bull = imread(mask_f)
logical_idx, bull_weight = read_bull(bull, if_wei=1)
rgb = imread(jpg).reshape(-1, 3)
idx_keep = ~logical_idx
rgb_keep = rgb[idx_keep]
w = bull_weight[idx_keep]

for name, di, wd in [('p1', p1, wd1), ('p2', p2, wd2)]:
    xyz = lut3d_rgb2xyz1(rgb_keep, di)          # absolute XYZ (Y scale = XYZw[1])
    # (a) script way: Lab with wd65_scaled
    lab_a = xyz2lab(xyz, 'user', wd.reshape(1, 3))
    ave_a = np.sum(lab_a * w[:, None], axis=0) / np.sum(w)
    # (b) standard CIELAB: absolute XYZ, global Y scale -> 100, D65 white
    Yw = float(di['XYZw'][0, 1])
    xyz_n = xyz * (100.0 / Yw)
    lab_b = xyz2lab(xyz_n, 'user', D65_64.reshape(1, 3))
    ave_b = np.sum(lab_b * w[:, None], axis=0) / np.sum(w)
    print()
    print(f'[{name}] target_Lab      = {lab_target.round(3)}')
    print(f'[{name}] script ave_Lab  = {np.round(ave_a, 3)}   (wd65_scaled white)')
    print(f'[{name}] D65-norm ave_Lab= {np.round(ave_b, 3)}   (standard D65 white)')
    print(f'[{name}] dE(target, script) = {deltaE2000(ave_a.reshape(1,3), lab_target.reshape(1,3))[0][0]:.3f}')
    print(f'[{name}] dE(target, D65)    = {deltaE2000(ave_b.reshape(1,3), lab_target.reshape(1,3))[0][0]:.3f}')
