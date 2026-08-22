# -*- coding: utf-8 -*-
"""临时诊断：用 MATLAB 渲染输出 jpg 的背景像素验证 Python LUT 链路。
背景区域不参与 delta_Lab 渲染（img_AddRender_simp 中背景保持原 xyz1），
所以背景 RGB = LUT(XYZ_cropped[背景]) 的直接结果（lut3d_xyz2rgbKDitp1
内部用 LUT 自身 XYZw 做 xyz2lab），与 dlab 无关 —— 是独立的 LUT+XYZ 数据链验证。
"""
import sys
import numpy as np
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from data_io import imread, load_xyz, load_lut
from color_utils import xyz2lab
from lut_gpu import lut3d_xyz2rgbKDitp1

I_ROOT = ROOT.parent / "I_render_stimuli"
XYZ_DIR = Path(r"D:\work\VIVOSkinExpe\original_image_XYZ") / "f04i"

img_p = I_ROOT / "mask" / "f04i" / "H3K.JPG"
xyz_p = XYZ_DIR / "H3K.mat"
ref_p = I_ROOT / "rendered" / "phase2" / "i" / "f04i" / "H3K_01[58.5861,22.4045,44.8393].jpg"
lut_p = ROOT.parent / "A_characterization" / "display_model" / "data_ipv30_phase2_3.mat"

img = imread(str(img_p))
ref = imread(str(ref_p))
print("H3K.JPG shape =", img.shape, "| MATLAB jpg shape =", ref.shape)

xyz_d = load_xyz(str(xyz_p))
XYZ = xyz_d["XYZ_cropped"]
m, n = XYZ.shape[0], XYZ.shape[1]

fwd = load_lut(str(lut_p))
XYZw_lut = fwd["XYZw"].reshape(3)
wd65 = np.array([94.813, 100.000, 107.262])
wd65_scaled = wd65 / 100.0 * XYZw_lut[1]
print("wd65_scaled =", wd65_scaled)

# 背景采样点（远离中心的角落 + 边缘中点）
pts = [(8, 8), (m - 8, 8), (8, n - 8), (m - 8, n - 8), (m // 2, 8), (m // 2, n - 8),
       (8, n // 2), (m - 8, n // 2)]
print(f"{'pos':>12} {'src_rgb':>18} {'ref_rgb':>18} {'our_rgb':>18} {'diff':>8}")

# 单次转换全链：取这些点的 XYZ 直接进 LUT（LUT 内部用自身 XYZw 转 lab）
pix_xyz = XYZ[tuple(zip(*pts))].reshape(-1, 3)          # (K,3) 列优先等价 MATLAB 行
rgb, oog = lut3d_xyz2rgbKDitp1(pix_xyz, lut=fwd, device="cpu", chunk=512, round_digits=4)  # 0-255

for k, (r, c) in enumerate(pts):
    src = img[r, c].astype(int)
    refv = ref[r, c].astype(int)
    ourv = np.round(np.clip(rgb[k], 0, 255)).astype(int)
    diff = int(np.abs(ourv - refv).max())
    print(f"({r:>4},{c:>4}) {str(src):>18} {str(refv):>18} {str(ourv):>18} {diff:>8}")

# 如果 src 背景是黑、ref 是非黑 -> 验证 MATLAB 确实做了 LUT 背景映射
print("\n说明：src=H3K.JPG 原图，ref=MATLAB渲染jpg，our=Python LUT 输出")
