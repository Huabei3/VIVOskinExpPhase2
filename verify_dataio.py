"""verify_dataio.py — 批次 0 数值锚点：确认 data_io 读出的 shape/dtype 与 MATLAB 一致。

锚点来源（MATLAB 实测）：
- 各 .mat 的 whosmat 输出
- XYZ_cropped size = [2186 1640 3]
- points_added_33.xlsx = 33x2，第 33 行 [0 0] -> 前置零列后 [0 0 0]
- mask JPG = RGB 2186x1640，nosd JPG = L 灰度 2186x1640
"""
import numpy as np

import data_io as dio

BASE = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project"
DM = BASE + r"\A_characterization\display_model"
RS = BASE + r"\I_render_stimuli"

passed, failed = [], []


def check(name, cond, detail=""):
    (passed if cond else failed).append(name)
    print(f"  [{'PASS' if cond else 'FAIL'}] {name}  {detail}")


print("== 1. 逆向 LUT ==")
lut = dio.load_lut(DM + r"\data_ipv30_phase2_3.mat")
check("P_labs  (27000,3)", lut["P_labs"].shape == (27000, 3), str(lut["P_labs"].shape))
check("rgb     (27000,3)", lut["rgb"].shape == (27000, 3), str(lut["rgb"].shape))
check("XYZw    (1,3)    ", lut["XYZw"].shape == (1, 3), str(lut["XYZw"].shape))
check("cubeL   (1,1)    ", lut["cubeL"].shape == (1, 1), str(lut["cubeL"].shape))
check("dtype float64    ", lut["P_labs"].dtype == np.float64, str(lut["P_labs"].dtype))

lut35 = dio.load_lut(DM + r"\data_ipv35_3.mat")
check("P_labs35 (42875,3)", lut35["P_labs"].shape == (42875, 3), str(lut35["P_labs"].shape))
check("rgb35    (42875,3)", lut35["rgb"].shape == (42875, 3), str(lut35["rgb"].shape))

print("== 2. 正向 LUT ==")
fl = dio.load_forward_lut(DM + r"\datai_ipv18_3.mat")
check("XYZw (1,3)", fl["XYZw"].shape == (1, 3), str(fl["XYZw"].shape))

print("== 3. 参数文件 ==")
cl = dio.load_c_lpara(RS + r"\aveSkinByHand2\i\C_Lpara\1C_L_para.mat")
check("a_CL (1,2)", cl.shape == (1, 2), str(cl.shape))
al = dio.load_avelab(RS + r"\documents\aveSkin\i\aveLab_D65_1.mat")
check("labC_HD65 (1,4)", al.shape == (1, 4), str(al.shape))

print("== 4. XYZ ==")
xyz = dio.load_xyz(r"D:\work\VIVOSkinExpe\original_image_XYZ\f01i\H3K.mat")
check("XYZ_cropped (2186,1640,3)", xyz["XYZ_cropped"].shape == (2186, 1640, 3),
      str(xyz["XYZ_cropped"].shape))
check("XYZw (1,3)", xyz["XYZw"].shape == (1, 3), str(xyz["XYZw"].shape))
check("XYZ dtype float64", xyz["XYZ_cropped"].dtype == np.float64, str(xyz["XYZ_cropped"].dtype))

print("== 5. points_added_33.xlsx ==")
pts = dio.load_points(RS + r"\points_added_33.xlsx")
check("shape (33,3)", pts.shape == (33, 3), str(pts.shape))
check("第33行原点 [0,0,0]", np.allclose(pts[32], [0, 0, 0]), str(pts[32]))
check("首行 [0,-2.5433,-4.89]", np.allclose(pts[0], [0, -2.543333, -4.89], atol=1e-5), str(pts[0]))

print("== 6. 图像 ==")
img = dio.imread(RS + r"\mask\f01i\H3K.JPG")
check("img (2186,1640,3) uint8", img.shape == (2186, 1640, 3) and img.dtype == np.uint8,
      f"{img.shape} {img.dtype}")
nosd = dio.imread(RS + r"\Shadow\mask\f01i\nosd\H3K.JPG")
check("nosd (2186,1640) uint8", nosd.shape == (2186, 1640) and nosd.dtype == np.uint8,
      f"{nosd.shape} {nosd.dtype}")
imd = dio.im2double(img)
check("im2double -> float64 [0,1]", imd.dtype == np.float64 and imd.max() <= 1.0,
      f"{imd.dtype} max={imd.max():.4f}")

print("== 7. 核心锚点：img reshape 与 XYZ reshape 一致 ==")
m, n, p = img.shape
xyz1 = xyz["XYZ_cropped"].reshape(m * n, p)
check("reshape(XYZ,[m*n,3])", xyz1.shape == (2186 * 1640, 3), str(xyz1.shape))

print(f"\n结果: {len(passed)} PASS / {len(failed)} FAIL")
if failed:
    print("失败项:", failed)
    raise SystemExit(1)
print("批次 0 锚点全部通过。")
