# -*- coding: utf-8 -*-
"""临时：判断新 noFaceRGB.mat 缓存是用哪个 LUT 生成的 + 检查相关文件 mtime"""
import sys
import time
import numpy as np
from pathlib import Path
from scipy.io import loadmat

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from data_io import imread, load_xyz, load_lut
from mask import read_bull
from lut_gpu import lut3d_xyz2rgbKDitp1

PROJ = Path(r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project")
I_ROOT = PROJ / "I_render_stimuli"
XYZ_DIR = Path(r"D:\work\VIVOSkinExpe\original_image_XYZ") / "f04i"
DM = PROJ / "A_characterization" / "display_model"

sub, name = "f04i", "H3K"
noFace_p = I_ROOT / "rendered" / "phase2" / "i" / sub / "noFaceRGB" / f"{name}.mat"
nf_cache = np.asarray(loadmat(str(noFace_p))["noFaceRGB"])

XYZ = load_xyz(str(XYZ_DIR / f"{name}.mat"))["XYZ_cropped"]
m, n = XYZ.shape[0], XYZ.shape[1]
bull = imread(str(I_ROOT / "mask" / sub / f"{name}.JPG"))
logicalIndex, _ = read_bull(bull, 0)
xyz1 = XYZ.reshape(m * n, 3)[logicalIndex]

def mtime(p: Path):
    if p.exists():
        return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(p.stat().st_mtime))
    return "NOT FOUND"

print("=== 相关文件 mtime ===")
for p in [DM / "datai_ipv18_3.mat", DM / "data_ipv30_phase2_3.mat", DM / "data_ipv35_3.mat",
          I_ROOT / "utils" / "lut3d_xyz2rgbKDitp1.m",
          I_ROOT / "utils" / "img_AddRender_simp.m",
          I_ROOT / "main_i_test.m"]:
    print(f"{str(p):92s} {mtime(p)}")

print("\n=== cache vs 各 LUT 现场插值 ===")
for f in ["data_ipv30_phase2_3.mat", "data_ipv35_3.mat"]:
    lut = load_lut(str(DM / f))
    rgb, _ = lut3d_xyz2rgbKDitp1(xyz1, lut=lut, device="cpu", chunk=512, round_digits=4)
    d = np.abs(rgb - nf_cache)
    print(f"{f:28s} MAE={d.mean():8.4f} P95={np.percentile(d,95):7.3f} max={d.max():7.1f}  "
          f"per_ch R={d[:,0].mean():6.3f} G={d[:,1].mean():6.3f} B={d[:,2].mean():6.3f}")
    big = np.flatnonzero(d.max(axis=1) > 5)
    print(f"          diff>5: {len(big)}")
    for i in big[:3]:
        print(f"          cache={nf_cache[i].round(1)} {f[:18]}={rgb[i].round(1)} xyz={xyz1[i].round(1)}")
