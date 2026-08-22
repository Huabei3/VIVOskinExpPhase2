# -*- coding: utf-8 -*-
"""临时诊断：B 层像素 diff 定位 —— 背景 vs 前景、各通道统计、空间分布"""
import sys
import numpy as np
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from data_io import imread, im2double, load_xyz, load_lut
from color_utils import xyz2lab
from mask import read_bull
from lut_gpu import lut3d_xyz2rgbKDitp1

DATA_ROOT = ROOT.parent
I_ROOT = DATA_ROOT / "I_render_stimuli"
XYZ_DIR = Path(r"D:\work\VIVOSkinExpe\original_image_XYZ") / "f04i"

img_p = I_ROOT / "mask" / "f04i" / "H3K.JPG"
bull_p = img_p
bull_nosd_p = I_ROOT / "Shadow" / "mask" / "f04i" / "nosd" / "H3K.JPG"
xyz_p = XYZ_DIR / "H3K.mat"
ref_p = I_ROOT / "rendered" / "phase2" / "i" / "f04i" / "H3K_01[58.5861,22.4045,44.8393].jpg"
lut_p = DATA_ROOT / "A_characterization" / "display_model" / "data_ipv30_phase2_3.mat"

img0 = imread(str(img_p))
img = im2double(img0)
m, n = img.shape[0], img.shape[1]

bull = imread(str(bull_p))
bull_nosd = imread(str(bull_nosd_p))
ref = imread(str(ref_p)).astype(np.float64)

xyz_d = load_xyz(str(xyz_p))
XYZ = xyz_d["XYZ_cropped"]
xyz1 = XYZ.reshape(m * n, 3)

# 与 img_AddRender_simp 一致的 wd65_scaled（phase2 LUT 的 XYZw）
lut = load_lut(str(lut_p))
XYZw = np.asarray(lut["XYZw"], dtype=np.float64).reshape(3)
wd65 = np.array([94.813, 100.000, 107.262])
wd65_scaled = wd65 / 100.0 * XYZw[1]

lab1 = xyz2lab(xyz1, "user", wd65_scaled)

if_wei, if_2mask = 0, 0
logicalIndex, bull_weight = read_bull(bull, if_wei)
print("logicalIndex(背景) 像素数:", int(logicalIndex.sum()), "/", logicalIndex.size)
print("bull_weight 唯一值:", np.unique(bull_weight))

# 前景 LUT 输出（直接复现 render_core 中前景分支）
rgb_fg, _ = lut3d_xyz2rgbKDitp1(xyz1[~logicalIndex, :], lut=lut, device="cpu", chunk=512, round_digits=4)
rgb_bg, _ = lut3d_xyz2rgbKDitp1(xyz1[logicalIndex, :], lut=lut, device="cpu", chunk=512, round_digits=4)

# 重建整图 0-255
ours = np.zeros((m * n, 3))
ours[~logicalIndex, :] = rgb_fg
ours[logicalIndex, :] = rgb_bg
ours = ours.reshape(m, n, 3)

# MATLAB ref 与 ours 的 diff
diff = np.abs(ours - ref)
print("\n=== 全图 diff 统计 ===")
print("MAE(全图):", diff.mean().round(4))
print("MAE 每通道:", diff.reshape(-1, 3).mean(axis=0).round(4))
print("P95(全图):", np.percentile(diff, 95).round(3))

# 背景/前景分别统计（用 MATLAB 语义的 logicalIndex，bull 自身作 mask）
bg_mask = logicalIndex.reshape(m, n)
diff_bg = diff[bg_mask]
diff_fg = diff[~bg_mask]
print("\n=== 背景 diff（LUT 直接输出 vs MATLAB）===")
print(f"背景像素数={diff_bg.size}, MAE={diff_bg.mean():.4f}, P95={np.percentile(diff_bg, 95):.3f}, max={diff_bg.max():.1f}")
print(f"前景像素数={diff_fg.size}, MAE={diff_fg.mean():.4f}, P95={np.percentile(diff_fg, 95):.3f}, max={diff_fg.max():.1f}")

# 大 diff 像素坐标分布
big = np.argwhere(diff.max(axis=2) > 20)
print(f"\n大 diff(>20) 像素数: {len(big)}")
if len(big) > 0:
    print("行范围:", big[:, 0].min(), "-", big[:, 0].max(), " 列范围:", big[:, 1].min(), "-", big[:, 1].max())
    print("行均值/中位:", big[:, 0].mean().round(1), np.median(big[:, 0]))
    print("列均值/中位:", big[:, 1].mean().round(1), np.median(big[:, 1]))

# 输出 RGB 通道直方图对比（采样前 20000 个前景像素）
sample = np.random.default_rng(0).choice(diff_fg.size, size=min(20000, diff_fg.size), replace=False)
print("\n=== 前景 diff 直方图（采样 20000）===")
hist, edges = np.histogram(diff_fg.ravel()[sample], bins=[0, 1, 2, 5, 10, 20, 40, 80, 160, 256])
for i in range(len(hist)):
    print(f"  [{edges[i]:>3},{edges[i+1]:>3}): {hist[i]}")

# ours vs ref 在几个前景点的具体值
fg_idx = np.flatnonzero(~logicalIndex)
print("\n=== 前景采样点对比 ===")
print(f"{'idx':>8} {'ours':>18} {'ref':>18} {'diff':>8}")
for idx in fg_idx[:: max(1, len(fg_idx) // 5)][:5]:
    r, c = idx // n, idx % n
    print(f"({r:>4},{c:>4}) {str(ours[r,c].round(1)):>18} {str(ref[r,c].round(1)):>18} {str(diff[r,c].round(1)):>8}")
