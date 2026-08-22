# -*- coding: utf-8 -*-
"""临时：用 Python render_core 渲染 f04i/H3K 第01点，输出 jpg 并与 MATLAB ref 对比。

流程复刻 main_i_test.m：
  average: lab1 用 datai_ipv18_3.mat 的 XYZw 算 wd65_scaled（主循环逻辑）
  delta_Lab = dlab(文件名) - average
  渲染: img_AddRender_simp('LUT', phase2, if_wei=0, if_2mask=0)
"""
import sys
import numpy as np
from pathlib import Path
from scipy.io import loadmat
from PIL import Image

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from data_io import imread, load_xyz
from color_utils import xyz2lab
from mask import get_average
from render_core import img_AddRender_simp

I_ROOT = ROOT.parent / "I_render_stimuli"          # I_render_stimuli
PROJ = I_ROOT.parent                                # C_VIVO_skin_project
XYZ_DIR = Path(r"D:\work\VIVOSkinExpe\original_image_XYZ") / "f04i"

sub = "f04i"
name = "H3K"
dlab = np.array([57.8574, 22.2237, 44.4424])        # 文件名 [L,a,b] = 目标平均 Lab

# ---------- 输入 ----------
img_p = I_ROOT / "mask" / sub / f"{name}.JPG"
bull = imread(str(img_p))
nosd_glob = sorted((I_ROOT / "Shadow" / "mask" / sub / "nosd").glob(f"{name}.*"))
assert nosd_glob, f"no bull_nosd for {sub}/{name}"
bull_nosd = imread(str(nosd_glob[0]))
XYZ = load_xyz(str(XYZ_DIR / f"{name}.mat"))["XYZ_cropped"]
m, n = bull.shape[0], bull.shape[1]
xyz1 = XYZ.reshape(m * n, 3)
print(f"img {m}x{n}, XYZ {XYZ.shape}")

# ---------- average（对齐用户修改后的 main_i_test.m：统一用 data_ipv30_phase2_3.mat）----------
wd65 = np.array([94.813, 100.000, 107.262])
lut30 = loadmat(str(PROJ / "A_characterization" / "display_model" / "data_ipv30_phase2_3.mat"))
XYZw30 = np.asarray(lut30["XYZw"]).reshape(1, 3)
wd65_scaled_main = wd65 / 100.0 * XYZw30[0, 1]
lab1 = xyz2lab(xyz1, "user", wd65_scaled_main)
average = get_average(lab1, bull, if_wei=0)
print(f"average = {average.round(4)}")
print(f"dlab    = {dlab}")
delta_Lab = dlab - average
print(f"delta_Lab = {delta_Lab.round(4)}")

# ---------- 渲染 ----------
tmp = ROOT / "_tmp_out"
tmp.mkdir(exist_ok=True)
noFace_p = tmp / f"noFaceRGB_{sub}_{name}.mat"
handle = {"LUT_type": "phase2"}
out, dest_lab, _, _ = img_AddRender_simp(
    bull, bull, bull_nosd, "LUT", delta_Lab, XYZ,
    noFace_p, if_wei=0, if_2mask=0, handle=handle, data_root=PROJ)
print(f"dest_lab = {np.asarray(dest_lab).round(4)}")

# ---------- 保存 ----------
out8 = np.clip(out * 255.0, 0, 255).astype(np.uint8)
out_jpg = tmp / f"{name}_01_python.jpg"
Image.fromarray(out8).save(out_jpg, "JPEG", quality=100)
print(f"saved -> {out_jpg}")

# ---------- 与 MATLAB ref 对比 ----------
ref_p = I_ROOT / "rendered" / "phase2" / "i" / sub / \
    f"{name}_01[57.8574,22.2237,44.4424].jpg"
assert ref_p.exists(), f"ref not found: {ref_p}"
ref = imread(str(ref_p)).astype(np.float64)
d = np.abs(out * 255.0 - ref)
from mask import read_bull
logicalIndex, _ = read_bull(bull, 0)
fg = d.reshape(-1, 3)[~logicalIndex]
bg = d.reshape(-1, 3)[logicalIndex]
print(f"\nPython vs MATLAB ref:")
print(f"  全图  MAE={d.mean():.4f} P95={np.percentile(d,95):.3f} max={d.max():.1f}")
print(f"  前景  MAE={fg.mean():.4f} P95={np.percentile(fg,95):.3f} max={fg.max():.1f}")
print(f"  背景  MAE={bg.mean():.4f} P95={np.percentile(bg,95):.3f} max={bg.max():.1f}")
print(f"  分通道 R={d[:,:,0].mean():.4f} G={d[:,:,1].mean():.4f} B={d[:,:,2].mean():.4f}")
