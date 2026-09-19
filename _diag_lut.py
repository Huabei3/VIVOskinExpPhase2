# -*- coding: utf-8 -*-
"""诊断 lut3d_rgb2xyz1: 对皮肤色 RGB 检查输出 Lab 是否合理。
期望: RGB(191,131,77) 经 phase1 LUT -> Lab ~ (59.8, 24.1, 43.5)
"""
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from compare_phase12 import load_datai, lut3d_rgb2xyz1
from color_utils import xyz2lab
from data_io import load_mat

LUT1 = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\A_characterization\display_model\datai_ipv35_3.mat"
LUT2 = r"D:\work\VIVOSkin_phase2\display\model_interp\datai_ipv30_phase2_3.mat"

for name, p in [("phase1", LUT1), ("phase2", LUT2)]:
    d = load_datai(p)
    cubeL = d["cubeL"]
    lablut_raw = d["lablut"]
    XYZw = d["XYZw"]
    print(f"=== {name}: cubeL={cubeL}, lablut shape={lablut_raw.shape}, "
          f"lablut[0]={lablut_raw[0]}, XYZw={XYZw.ravel().round(4)}")
    # 原始 mat 检查
    raw = load_mat(p)
    print(f"    raw keys: {list(raw.keys())}")
    for k in ('cubeL', 'lablut', 'XYZw'):
        if k in raw:
            v = np.asarray(raw[k])
            print(f"    raw[{k}] shape={v.shape} dtype={v.dtype}")
    if 'lablut' in raw:
        r = np.asarray(raw['lablut'])
        print(f"    raw lablut[0]={r.ravel()[:3].round(4)}  [end]={r.ravel()[-3:].round(4)}")
        # 行列方向检查: MATLAB reshape 列主序, 第一维变化最快
        flat = np.asarray(r)
        Lcol = np.asarray(flat).reshape(-1)[:9] if flat.ndim == 2 else flat.ravel()[:9]
        print(f"    lablut 第一列前9个值: {Lcol.round(4)}")

    rgb = np.array([[191.0, 131.0, 77.0]])
    xyz = lut3d_rgb2xyz1(rgb, d)
    wd = 94.813 / 100.0 * XYZw[0, 1], 100.0 * XYZw[0, 1] / 100.0, 107.262 / 100.0 * XYZw[0, 1]
    wd65 = np.array([94.813, 100.0, 107.262]) / 100.0 * XYZw[0, 1]
    lab = xyz2lab(xyz, 'user', white=wd65)
    print(f"    RGB(191,131,77) -> XYZ={xyz[0].round(4)}  Lab={lab[0].round(3)}")
