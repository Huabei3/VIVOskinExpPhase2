# -*- coding: utf-8 -*-
"""临时诊断：判断剩余 diff 是否为 JPEG 噪声 + 定位大 diff 像素特征。"""
import sys
import io
import numpy as np
from pathlib import Path
from scipy.io import loadmat
from PIL import Image

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from data_io import imread, load_xyz, load_mat
from color_utils import xyz2lab
from mask import read_bull
from lut_gpu import lut3d_xyz2rgbKDitp1

I_ROOT = ROOT.parent / "I_render_stimuli"
XYZ_DIR = Path(r"D:\work\VIVOSkinExpe\original_image_XYZ") / "f04i"

img_p = I_ROOT / "mask" / "f04i" / "H3K.JPG"
xyz_p = XYZ_DIR / "H3K.mat"
ref_p = I_ROOT / "rendered" / "phase2" / "i" / "f04i" / "H3K_01[58.5861,22.4045,44.8393].jpg"
noFace_p = I_ROOT / "rendered" / "phase2" / "i" / "f04i" / "noFaceRGB" / "H3K.mat"
lut_p = ROOT.parent / "A_characterization" / "display_model" / "data_ipv30_phase2_3.mat"

ref = imread(str(ref_p)).astype(np.float64)
m, n = ref.shape[0], ref.shape[1]
bull = imread(str(img_p))
logicalIndex, _ = read_bull(bull, 0)

def jpeg_recompress(arr, quality):
    im = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=quality)
    buf.seek(0)
    return np.asarray(Image.open(buf)).astype(np.float64)

print("=== JPEG 噪声量级估计（ref vs 重新压缩）===")
for q in [85, 90, 95, 98]:
    recon = jpeg_recompress(ref, q)
    d = np.abs(recon - ref)
    print(f"quality={q}: MAE={d.mean():.4f} P95={np.percentile(d, 95):.3f} max={d.max():.1f}")

# ---- Python 完整链路（与 verify 相同：缓存存在则用缓存）----
XYZ = load_xyz(str(xyz_p))["XYZ_cropped"]
xyz1 = XYZ.reshape(m * n, 3)
lut = load_mat(str(lut_p))
XYZw = np.asarray(lut["XYZw"], dtype=np.float64).reshape(1, 3)
wd65 = np.array([94.813, 100.000, 107.262])
wd65_scaled = wd65 / 100.0 * XYZw[0, 1]
lab1 = xyz2lab(xyz1, "user", wd65_scaled)

if noFace_p.exists():
    noFace = np.asarray(loadmat(str(noFace_p))["noFaceRGB"], dtype=np.float64)
else:
    noFace, _ = lut3d_xyz2rgbKDitp1(xyz1[logicalIndex, :], lut=lut, device="cpu", chunk=512, round_digits=4)
rgb_fg, _ = lut3d_xyz2rgbKDitp1(xyz1[~logicalIndex, :], lut=lut, device="cpu", chunk=512, round_digits=4)

ours = np.zeros((m * n, 3))
ours[~logicalIndex, :] = rgb_fg
ours[logicalIndex, :] = noFace
ours = ours.reshape(m, n, 3)
d_all = np.abs(ours - ref)
fg_flat = d_all.reshape(-1, 3)[~logicalIndex]
bg_flat = d_all.reshape(-1, 3)[logicalIndex]
print(f"\nPython vs ref: 前景 MAE={fg_flat.mean():.4f} P95={np.percentile(fg_flat, 95):.3f} max={fg_flat.max():.1f}")
print(f"Python vs ref: 背景 MAE={bg_flat.mean():.4f} P95={np.percentile(bg_flat, 95):.3f} max={bg_flat.max():.1f}")

# ---- 背景大 diff 像素特征 ----
big_bg = np.flatnonzero(bg_flat.max(axis=1) > 20)
print(f"\n背景 diff>20 像素数={len(big_bg)} / {bg_flat.shape[0]}")
if len(big_bg) > 0:
    bg_idx = np.flatnonzero(logicalIndex)[big_bg]
    rows, cols = bg_idx // n, bg_idx % n
    xyz_big = xyz1[bg_idx]
    lab_big = lab1[bg_idx]
    ours_big = ours.reshape(-1, 3)[bg_idx]
    ref_big = ref.reshape(-1, 3)[bg_idx]
    print(f"位置: 行 {rows.min()}-{rows.max()} 列 {cols.min()}-{cols.max()}")
    print(f"XYZ 统计: mean={xyz_big.mean(axis=0).round(2)}  min={xyz_big.min(axis=0).round(2)}  max={xyz_big.max(axis=0).round(2)}")
    print(f"Lab 统计: mean={lab_big.mean(axis=0).round(2)}")
    print("前 10 个 (row,col) xyz1 | ours | ref | diff:")
    for i in range(min(10, len(big_bg))):
        r, c = rows[i], cols[i]
        print(f"  ({r},{c}) xyz={xyz_big[i].round(1)} ours={ours_big[i].round(1)} ref={ref_big[i].round(1)} d={np.abs(ours_big[i]-ref_big[i]).round(1)}")
    # 检查这些像素是否 LUT 超色域（RGB 越界）
    gamut = ((ours_big < 0) | (ours_big > 255)).any(axis=1)
    print(f"其中 LUT 输出越界像素比例: {gamut.mean():.2%}")

# ---- 前景大 diff 像素特征 ----
big_fg = np.flatnonzero(fg_flat.max(axis=1) > 20)
print(f"\n前景 diff>20 像素数={len(big_fg)} / {fg_flat.shape[0]}")
if len(big_fg) > 0:
    fg_idx = np.flatnonzero(~logicalIndex)[big_fg]
    rows, cols = fg_idx // n, fg_idx % n
    xyz_big = xyz1[fg_idx]
    lab_big = lab1[fg_idx]
    ours_big = ours.reshape(-1, 3)[fg_idx]
    ref_big = ref.reshape(-1, 3)[fg_idx]
    print(f"位置: 行 {rows.min()}-{rows.max()} 列 {cols.min()}-{cols.max()}")
    print(f"XYZ 统计: mean={xyz_big.mean(axis=0).round(2)}")
    print("前 10 个 (row,col) xyz1 | ours | ref | diff:")
    for i in range(min(10, len(big_fg))):
        r, c = rows[i], cols[i]
        print(f"  ({r},{c}) xyz={xyz_big[i].round(1)} ours={ours_big[i].round(1)} ref={ref_big[i].round(1)} d={np.abs(ours_big[i]-ref_big[i]).round(1)}")
