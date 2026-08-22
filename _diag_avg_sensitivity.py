# -*- coding: utf-8 -*-
"""临时诊断：对 bull 掩码做阈值敏感性分析，反推 MATLAB average 对应的全黑判定。"""
import sys
import numpy as np
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from data_io import imread, load_xyz
from color_utils import xyz2lab

bull = imread(str(ROOT.parent / "I_render_stimuli" / "mask" / "f04i" / "H3K.JPG"))
xyz_d = load_xyz(r"D:\work\VIVOSkinExpe\original_image_XYZ\f04i\H3K.mat")
XYZ = xyz_d["XYZ_cropped"]
m, n = 2186, 1640
wd65_scaled = np.array([94.813, 100.0, 107.262]) / 100.0 * np.array([331.529, 349.666, 375.059])[1]
lab1 = xyz2lab(XYZ.reshape(m * n, 3), "user", wd65_scaled)

b = bull.reshape(m * n, 3).astype(np.float64) / 255.0
target = np.array([58.5630675363, 26.3946576212, 49.1587029937])

for th in [0, 1, 2, 3, 5, 10]:
    mask = np.all(b * 255 <= th, axis=1)
    avg = lab1[~mask].mean(axis=0)
    print(
        "th<=%2d: bg=%-8d avg=[%.4f %.4f %.4f]  diff=[%+.4f %+.4f %+.4f]"
        % (th, mask.sum(), avg[0], avg[1], avg[2], avg[0] - target[0], avg[1] - target[1], avg[2] - target[2])
    )

mask_all = np.all(b == 0.0, axis=1)
avg = lab1[~mask_all].mean(axis=0)
print("all0: bg=%d avg=[%.4f %.4f %.4f]" % (mask_all.sum(), avg[0], avg[1], avg[2]))

mask_any = np.any(b == 0.0, axis=1)
avg = lab1[~mask_any].mean(axis=0)
print("any0: bg=%d avg=[%.4f %.4f %.4f]" % (mask_any.sum(), avg[0], avg[1], avg[2]))

print("target =", target)
