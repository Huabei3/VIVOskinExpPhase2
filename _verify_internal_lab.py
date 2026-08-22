# -*- coding: utf-8 -*-
"""Final verify: LUT-internal Lab (before reference-white conversion) vs target.
Shows that the negative b comes from the lablut-internal reference white (XYZw
of the display) differing from D65 chromaticity used at the xyz2lab step."""
import numpy as np
import sys
from pathlib import Path
sys.path.insert(0, r'D:/work/VIVOSkinExpe/PeggySkinBackup/A_code/C_VIVO_skin_project/I_render_stimuli_python')
from data_io import load_mat, imread
from mask import read_bull
from color_utils import xyz2lab, lab2xyz2

HERE = Path(r'D:/work/VIVOSkinExpe/PeggySkinBackup/A_code/C_VIVO_skin_project/I_render_stimuli_python')
PROJ = HERE.parent / 'I_render_stimuli'
RENDER_I = PROJ / 'rendered_python' / 'phase2' / 'i'
MASK_ROOT = PROJ / 'mask'
DATAI_P1 = HERE.parent / 'A_characterization' / 'display_model' / 'datai_ipv35_3.mat'
DATAI_P2 = Path(r'D:\work\VIVOSkin_phase2\display\model_interp\datai_ipv30_phase2_3.mat')

sys.path.insert(0, str(HERE))
from compare_phase12 import load_datai, wd65_scaled_of, _trilinear

jpg = RENDER_I / 'f01i' / 'HD65_33[58.3819,12.8181,11.8966].jpg'
mask_f = MASK_ROOT / 'f01i' / 'HD65.jpg'
lab_target = np.array([58.3819, 12.8181, 11.8966])

bull = imread(mask_f)
logical_idx, bull_weight = read_bull(bull, if_wei=1)
rgb = imread(jpg).reshape(-1, 3)
idx_keep = ~logical_idx
rgb_keep = rgb[idx_keep]
w = bull_weight[idx_keep]

p1 = load_datai(DATAI_P1)
p2 = load_datai(DATAI_P2)

for name, di in [('p1', p1), ('p2', p2)]:
    cubeL = di['cubeL']
    lablut = di['lablut'].reshape(cubeL, cubeL, cubeL, 3)
    XYZw = di['XYZw'][0]
    idx_cont = np.clip(rgb_keep.astype(np.float64), 0.0, 255.0) / 255.0 * (cubeL - 1)
    lab_lut = _trilinear(lablut, idx_cont)                     # LUT-internal Lab (ref = XYZw)
    ave_lut = np.sum(lab_lut * w[:, None], axis=0) / np.sum(w)
    xyz = lab2xyz2(lab_lut, 'user', XYZw.reshape(1, 3))        # absolute XYZ (Y scale = XYZw[1])
    wd = wd65_scaled_of(di)
    lab_out = xyz2lab(xyz, 'user', wd.reshape(1, 3))           # final Lab (ref = D65 chromaticity)
    ave_out = np.sum(lab_out * w[:, None], axis=0) / np.sum(w)
    print(f'[{name}] XYZw(display)        = {np.round(XYZw, 3)}  X/Z={XYZw[0]/XYZw[2]:.4f} (D65 X/Z=0.8839)')
    print(f'[{name}] LUT-internal ave Lab = {np.round(ave_lut, 3)}   (ref white = XYZw)')
    print(f'[{name}] final     ave Lab    = {np.round(ave_out, 3)}   (ref white = D65 chr.)')
    print(f'[{name}] target Lab           = {lab_target.round(3)}')
    print()
