# -*- coding: utf-8 -*-
"""临时诊断：完整 img_AddRender_simp 链路（含 delta_Lab）vs MATLAB 基准
对比 lab1/lab2/xyz2 中间量统计 + 背景 noFaceRGB 缓存 + 前景 diff 定位
"""
import sys
import numpy as np
from pathlib import Path
from scipy.io import loadmat

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from data_io import imread, im2double, load_xyz, load_mat
from color_utils import xyz2lab, lab2xyz2
from mask import read_bull, get_average
from lut_gpu import lut3d_xyz2rgbKDitp1

DATA_ROOT = ROOT.parent
I_ROOT = DATA_ROOT / "I_render_stimuli"
XYZ_DIR = Path(r"D:\work\VIVOSkinExpe\original_image_XYZ") / "f04i"

img_p = I_ROOT / "mask" / "f04i" / "H3K.JPG"
bull_p = img_p
bull_nosd_p = I_ROOT / "Shadow" / "mask" / "f04i" / "nosd" / "H3K.JPG"
xyz_p = XYZ_DIR / "H3K.mat"
ref_p = I_ROOT / "rendered" / "phase2" / "i" / "f04i" / "H3K_01[58.5861,22.4045,44.8393].jpg"
noFace_p = I_ROOT / "rendered" / "phase2" / "i" / "f04i" / "noFaceRGB" / "H3K.mat"
lut_p = DATA_ROOT / "A_characterization" / "display_model" / "data_ipv30_phase2_3.mat"
lut_main_p = DATA_ROOT / "A_characterization" / "display_model" / "datai_ipv18_3.mat"

if_wei, if_2mask = 0, 0
delta_Lab = np.array([58.5861 - 58.56306754, 22.40449548 - 26.39465762, 44.83925421 - 49.15870299])

img0 = imread(str(img_p))
img = im2double(img0)
m, n = img.shape[0], img.shape[1]
bull = imread(str(bull_p))
bull_nosd = imread(str(bull_nosd_p))
ref = imread(str(ref_p)).astype(np.float64)

XYZ = load_xyz(str(xyz_p))["XYZ_cropped"]
xyz1 = XYZ.reshape(m * n, 3)

# ---- render 内部白点（phase2 LUT 的 XYZw）----
lut = load_mat(str(lut_p))
XYZw = np.asarray(lut["XYZw"], dtype=np.float64).reshape(1, 3)
wd65 = np.array([94.813, 100.000, 107.262])
wd65_scaled = wd65 / 100.0 * XYZw[0, 1]
print(f"[render内部] XYZw_LUT={XYZw[0]}  wd65_scaled={wd65_scaled}")

lab1 = xyz2lab(xyz1, "user", wd65_scaled)
print(f"[lab1] mean={lab1.mean(axis=0)}")

logicalIndex, bull_weight = read_bull(bull, if_wei)
logicalIndex_nosd, _ = read_bull(bull_nosd, if_wei)
print(f"[bull] 背景像素={logicalIndex.sum()}  bull_weight唯一值={np.unique(bull_weight)}")

lab2 = lab1 + delta_Lab.reshape(1, 3) * bull_weight.reshape(-1, 1)
sd_idx = (~logicalIndex) & logicalIndex_nosd
lab2[sd_idx, 1] = np.maximum(0, lab2[sd_idx, 1])
lab2[sd_idx, 2] = np.maximum(0, lab2[sd_idx, 2])
print(f"[lab2] mean={lab2.mean(axis=0)}  sd_idx 数={sd_idx.sum()}")
print(f"[lab2] 前景 mean={lab2[~logicalIndex].mean(axis=0)}")

xyz2 = lab2xyz2(lab2, "user", wd65_scaled)
xyz2[logicalIndex, :] = xyz1[logicalIndex, :]
print(f"[xyz2] 前景 mean={xyz2[~logicalIndex].mean(axis=0)}")

# ---- 背景：MATLAB 缓存的 noFaceRGB vs Python LUT ----
if noFace_p.exists():
    noFace_mat = np.asarray(loadmat(str(noFace_p))["noFaceRGB"], dtype=np.float64)
    print(f"\n[noFaceRGB 缓存] MATLAB 生成, shape={noFace_mat.shape}")
    py_bg, _ = lut3d_xyz2rgbKDitp1(xyz2[logicalIndex, :], lut=lut, device="cpu", chunk=512, round_digits=4)
    bg_diff = np.abs(py_bg - noFace_mat)
    print(f"[背景 LUT] Python vs MATLAB 缓存: MAE={bg_diff.mean():.4f} max={bg_diff.max():.2f}")
    # MATLAB 缓存本身 vs ref 背景像素
    bg_ref = ref.reshape(-1, 3)[logicalIndex]
    m_diff = np.abs(noFace_mat - bg_ref)
    print(f"[背景] MATLAB缓存 vs ref jpg: MAE={m_diff.mean():.4f} max={m_diff.max():.2f}")
else:
    print("\n[noFaceRGB 缓存] 不存在")

# ---- 完整渲染输出 vs MATLAB ref ----
rgb_fg, _ = lut3d_xyz2rgbKDitp1(xyz2[~logicalIndex, :], lut=lut, device="cpu", chunk=512, round_digits=4)
if noFace_p.exists():
    rgb_bg = noFace_mat
else:
    rgb_bg, _ = lut3d_xyz2rgbKDitp1(xyz2[logicalIndex, :], lut=lut, device="cpu", chunk=512, round_digits=4)
ours = np.zeros((m * n, 3))
ours[~logicalIndex, :] = rgb_fg
ours[logicalIndex, :] = rgb_bg
ours = ours.reshape(m, n, 3)

diff = np.abs(ours - ref)
print(f"\n[完整链路] 全图 MAE={diff.mean():.4f} P95={np.percentile(diff, 95):.3f}")
diff_fg = diff.reshape(-1, 3)[~logicalIndex]
diff_bg = diff.reshape(-1, 3)[logicalIndex]
print(f"[完整链路] 前景 MAE={diff_fg.mean():.4f} P95={np.percentile(diff_fg, 95):.3f} max={diff_fg.max():.1f}")
print(f"[完整链路] 背景 MAE={diff_bg.mean():.4f} P95={np.percentile(diff_bg, 95):.3f} max={diff_bg.max():.1f}")

# 大 diff 前景像素的 XYZ/ref/ours
big = np.flatnonzero(diff.reshape(-1, 3).max(axis=1) > 30)
print(f"\n[大 diff>30] 像素数={len(big)}")
for idx in big[:10]:
    r, c = idx // n, idx % n
    print(f"  ({r},{c}) xyz1={xyz1[idx].round(1)} lab2={lab2[idx].round(2)} "
          f"ours={ours[r, c].round(1)} ref={ref[r, c].round(1)}")
