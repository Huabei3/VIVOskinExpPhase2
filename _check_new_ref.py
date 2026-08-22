# -*- coding: utf-8 -*-
"""临时：新 ref jpg（用户重渲染后） vs MATLAB noFaceRGB.mat 缓存 vs Python 现场 LUT 三路对比"""
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

I_ROOT = Path(r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli")
XYZ_DIR = Path(r"D:\work\VIVOSkinExpe\original_image_XYZ") / "f04i"

sub = "f04i"
name = "H3K"
dlab = np.array([57.8574, 22.2237, 44.4424])   # 用户新渲染的 dlab

ref_p = I_ROOT / "rendered" / "phase2" / "i" / sub / f"{name}_01[{dlab[0]},{dlab[1]},{dlab[2]}].jpg"
noFace_p = I_ROOT / "rendered" / "phase2" / "i" / sub / "noFaceRGB" / f"{name}.mat"
print("ref exists   :", ref_p.exists(), ref_p)
print("noFace cache :", noFace_p.exists())
t = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(noFace_p.stat().st_mtime))
print("noFace mtime :", t)
t2 = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(ref_p.stat().st_mtime))
print("ref jpg mtime:", t2)

ref = imread(str(ref_p)).astype(np.float64)
m, n = ref.shape[0], ref.shape[1]
bull = imread(str(I_ROOT / "mask" / sub / f"{name}.JPG"))
logicalIndex, _ = read_bull(bull, 0)
ref_bg = ref.reshape(-1, 3)[logicalIndex]

nf_cache = np.asarray(loadmat(str(noFace_p))["noFaceRGB"])

XYZ = load_xyz(str(XYZ_DIR / f"{name}.mat"))["XYZ_cropped"]
xyz1 = XYZ.reshape(m * n, 3)
lut = load_lut(str(I_ROOT.parent / "A_characterization" / "display_model" / "data_ipv30_phase2_3.mat"))
nf_ours, _ = lut3d_xyz2rgbKDitp1(xyz1[logicalIndex], lut=lut, device="cpu", chunk=512, round_digits=4)

print("\n=== A) MATLAB cache vs Python live LUT ===")
d = np.abs(nf_cache - nf_ours)
print("MAE=%.4f P95=%.3f max=%.1f  per_ch R=%.4f G=%.4f B=%.4f" % (
    d.mean(), np.percentile(d, 95), d.max(), d[:, 0].mean(), d[:, 1].mean(), d[:, 2].mean()))

print("\n=== B) MATLAB cache vs NEW ref jpg bg ===")
d2 = np.abs(nf_cache - ref_bg)
print("MAE=%.4f P95=%.3f max=%.1f  per_ch R=%.4f G=%.4f B=%.4f" % (
    d2.mean(), np.percentile(d2, 95), d2.max(), d2[:, 0].mean(), d2[:, 1].mean(), d2[:, 2].mean()))
big = np.flatnonzero(d2.max(axis=1) > 5)
print("diff>5: %d" % len(big))
for i in big[:5]:
    print("  cache=%s ref=%s xyz=%s" % (nf_cache[i].round(1), ref_bg[i].round(1), xyz1[logicalIndex][i].round(1)))

print("\n=== C) Python live LUT vs NEW ref jpg bg ===")
d3 = np.abs(nf_ours - ref_bg)
print("MAE=%.4f P95=%.3f max=%.1f  per_ch R=%.4f G=%.4f B=%.4f" % (
    d3.mean(), np.percentile(d3, 95), d3.max(), d3[:, 0].mean(), d3[:, 1].mean(), d3[:, 2].mean()))

# 背景差异的方向性：ref 相对 cache 是偏亮还是偏暗
diff = ref_bg - nf_cache
print("\nref - cache 方向: 均值 %s" % diff.mean(axis=0).round(2))
