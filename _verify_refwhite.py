# -*- coding: utf-8 -*-
"""Temp verify: contribution of reference-white mismatch to avg_b being negative"""
import numpy as np
import pandas as pd
from scipy.io import loadmat
import sys
sys.path.insert(0, r'D:/work/VIVOSkinExpe/PeggySkinBackup/A_code/C_VIVO_skin_project/I_render_stimuli_python')
from color_utils import xyz2lab, lab2xyz2

P1 = r'D:/work/VIVOSkinExpe/PeggySkinBackup/A_code/C_VIVO_skin_project/A_characterization/display_model/datai_ipv35_3.mat'
P2 = r'D:\work\VIVOSkin_phase2\display\model_interp\datai_ipv30_phase2_3.mat'
WD65 = np.array([94.813, 100.0, 107.262])
D65_XYZ_lab2xyz = np.array([94.811, 100.0, 107.304])  # lab2xyz2 d65_64 white

df = pd.read_excel(r'D:/work/VIVOSkinExpe/PeggySkinBackup/A_code/C_VIVO_skin_project/I_render_stimuli_python/compare_phase12.xlsx', 'summary')

for name, p in [('p1', P1), ('p2', P2)]:
    XYZw = np.asarray(loadmat(p)['XYZw']).reshape(1, 3)
    wd65 = WD65 / 100.0 * XYZw[0, 1]
    t = df[['target_L', 'target_a', 'target_b']].to_numpy()
    # target Lab (D65) -> absolute XYZ -> Lab at wd65_scaled white (expected inverse if render were perfect)
    xyz_abs = lab2xyz2(t, 'user', D65_XYZ_lab2xyz)
    lab_pred = xyz2lab(xyz_abs, 'user', wd65.reshape(1, 3))
    print(f'[{name}] wd65_scaled = {np.round(wd65, 3)}')
    print(f'  target_b   mean = {df.target_b.mean():+.2f}')
    print(f'  pred_b(perfect render, inverse) mean = {lab_pred[:, 2].mean():+.2f}')
    print(f'  => ref-white shift pred_b - target_b = {lab_pred[:, 2].mean() - df.target_b.mean():+.2f}')
    print(f'  avg_b actual mean = {df["avg_b_" + name].mean():+.2f}')
    print(f'  => render residual (actual - pred) = {df["avg_b_" + name].mean() - lab_pred[:, 2].mean():+.2f}')
    print(f'  L: target={df.target_L.mean():.2f} pred={lab_pred[:, 0].mean():.2f} actual={df["avg_L_" + name].mean():.2f}')
    print(f'  a: target={df.target_a.mean():.2f} pred={lab_pred[:, 1].mean():.2f} actual={df["avg_a_" + name].mean():.2f}')
    print()
