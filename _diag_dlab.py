# -*- coding: utf-8 -*-
"""临时诊断：dlab 全链路中间量打印（定位与 MATLAB 基准 [58.5861,22.4045,44.8393] 的偏差）"""
import sys
import numpy as np
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from data_io import imread, im2double, load_mat, load_xyz, load_avelab, load_points
from color_utils import xyz2lab, lab2xyz2
from mask import get_average, read_bull
from cat_adjust import CAT_lab2lab1, CAT16_D, CCT2xyz, adjust_dlabs_shape1

DATA_ROOT = ROOT.parent
I_ROOT = DATA_ROOT / "I_render_stimuli"

mask_dir = I_ROOT / "mask" / "f04i"
nosd_dir = I_ROOT / "Shadow" / "mask" / "f04i" / "nosd"
xyz_dir = Path(r"D:\work\VIVOSkinExpe\original_image_XYZ") / "f04i"

if_wei, if_2mask = 0, 0
i_type = 2

img_p = mask_dir / "H3K.JPG"
bull_p = img_p
bull_nosd_p = nosd_dir / "H3K.JPG"
xyz_p = xyz_dir / "H3K.mat"

img0 = imread(str(img_p))
img = im2double(img0)
m, n = img.shape[0], img.shape[1]

fwd = load_mat(str(DATA_ROOT / "A_characterization" / "display_model" / "datai_ipv18_3.mat"))
XYZw_main = np.asarray(fwd["XYZw"], dtype=np.float64).reshape(3)
print("XYZw_main =", XYZw_main)
wd65 = np.array([94.813, 100.000, 107.262])
wd65_scaled = wd65 / 100.0 * XYZw_main[1]
print("wd65_scaled =", wd65_scaled)

bull = imread(str(bull_p))
bull_nosd = imread(str(bull_nosd_p))
xyz_d = load_xyz(str(xyz_p))
XYZ = xyz_d["XYZ_cropped"]
print("XYZ shape =", XYZ.shape, "img shape =", img0.shape)

xyz1 = XYZ.reshape(m * n, 3)
lab1 = xyz2lab(xyz1, "user", wd65_scaled)
print("lab1 mean(all) =", lab1.mean(axis=0))   # 与 MATLAB _diag_dlab_intermediates.m 第4步对照
average = get_average(lab1, bull if not if_2mask else bull_nosd, if_wei)
print("average =", average)

# read_bull 内部检查
idx, w = read_bull(bull, if_wei)
print("read_bull: mask nonzero =", int(np.sum(~idx)), "bull min/max =", bull.min(), bull.max())

a_CL = np.array([6.7421, -9.9816])
if average[0] > 60:
    C_pre = a_CL[0] * np.log(60) + a_CL[1]
else:
    C_pre = a_CL[0] * np.log(average[0]) + a_CL[1]
print("C_pre =", C_pre, " (avgL>60?", average[0] > 60, ")")

labC_HD65 = load_avelab(str(I_ROOT / "documents" / "aveSkin" / "i" / f"aveLab_D65_{i_type}.mat"))
print("labC_HD65 =", labC_HD65, "shape =", labC_HD65.shape)
factor = C_pre / labC_HD65[0, 3]
print("factor =", factor)

num_points = load_points(str(I_ROOT / "points_added_33.xlsx"))
print("num_points shape =", num_points.shape)
print("num_points[0] =", num_points[0])
print("num_points[28] =", num_points[28])
print("num_points[32] =", num_points[32])

dlabs = np.tile(np.array([average[0], labC_HD65[0, 1], labC_HD65[0, 2]]), (len(num_points), 1))
dlabs = dlabs + num_points
dlabs[:, 1:3] = dlabs[:, 1:3] * factor
print("dlabs[0]  =", dlabs[0])
print("dlabs[28] =", dlabs[28])
print("dlabs[32] =", dlabs[32])

XYZw_pre = CCT2xyz(3000)
print("XYZw_pre(CCT2xyz 3000) =", np.asarray(XYZw_pre).reshape(-1))

# ---- CAT 链单步（第 0 点）----
wd65_64 = np.array([94.811, 100.00, 107.304])
lab_bf = dlabs[0:1]
XYZ_bf = lab2xyz2(lab_bf, "d65_64")
print("XYZ_bf =", XYZ_bf.reshape(-1))
XYZ_aft = CAT16_D(XYZ_bf, wd65_64, np.asarray(XYZw_pre).reshape(3), 1.0)
print("XYZ_aft =", np.asarray(XYZ_aft).reshape(-1))
lab_aft = xyz2lab(XYZ_aft, "d65_64")
print("lab_aft(CAT链第0点) =", np.asarray(lab_aft).reshape(-1))

# ---- CAT_lab2lab1 整体 + adjust ----
dlab_CATed = CAT_lab2lab1(dlabs, "full", 3000, "fore")
print("dlab_CATed[0]  =", dlab_CATed[0])
print("dlab_CATed[28] =", dlab_CATed[28])
print("dlab_CATed[32] =", dlab_CATed[32])
shift2933 = dlab_CATed[28] - dlab_CATed[32]
print("shift2933 =", shift2933, "squeeze =", shift2933[2] / shift2933[1], "tan50 =", np.tan(np.deg2rad(50)))
adj = adjust_dlabs_shape1(dlab_CATed)
print("adjust后[0] =", adj[0])

dlab = adj[0]
print("\n最终 dlab(1,:) =", dlab)
print("MATLAB 基准     = [58.5861,22.4045,44.8393]")
print("diff =", dlab - np.array([58.5861, 22.4045, 44.8393]))
