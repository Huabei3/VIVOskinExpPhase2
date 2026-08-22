# -*- coding: utf-8 -*-
r"""verify_render_core.py — 批次5锚点：img_AddRender_simp 1:1 验证

层次：
  A. 合成小图锚点（CI 可跑）：随机 4x4 图 + 真实 LUT，验证形状/范围/背景逻辑
  B. 真实数据端到端（存在才跑）：复现 main_i_test.m 对 f04i/H3K 的预处理，
     对比 MATLAB 基准输出 rendered/phase2/i/f04i/H3K_01[...].jpg
"""
from __future__ import annotations

import sys
import numpy as np
from pathlib import Path

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from data_io import imread, im2double, load_mat, load_xyz, load_avelab, load_points
from color_utils import xyz2lab
from mask import get_average
from cat_adjust import CAT_lab2lab1, adjust_dlabs_shape1
from lut_gpu import lut3d_xyz2rgbKDitp1
from render_core import img_AddRender_simp

DATA_ROOT = ROOT.parent  # C_VIVO_skin_project
I_ROOT = DATA_ROOT / "I_render_stimuli"

PASS = 0
FAIL = 0


def check(name, cond, detail=""):
    global PASS, FAIL
    if cond:
        PASS += 1
        print(f"  [PASS] {name}")
    else:
        FAIL += 1
        print(f"  [FAIL] {name}  {detail}")


# ---------------------------------------------------------------------------
# A. 合成小图锚点
# ---------------------------------------------------------------------------
def test_synthetic():
    print("== A. 合成小图锚点 ==")
    rng = np.random.default_rng(0)
    h, w = 4, 4
    img = rng.integers(0, 256, (h, w, 3)).astype(np.uint8)
    # bull：左上 2x2 全黑背景，其余非黑
    bull = rng.integers(0, 256, (h, w, 3)).astype(np.uint8)
    bull[:2, :2] = 0
    bull[2, 2] = [50, 50, 50]
    # bull_nosd：与 bull 类似，但 (0,0) 恢复非黑（模拟无阴影时该处非背景）
    bull_nosd = bull.copy()
    bull_nosd[0, 0] = [60, 60, 60]
    # XYZ：背景行对应 (0,0,0)，其余已知
    XYZ = rng.random((h, w, 3)) * 100.0
    XYZ[:2, :2] = 0.0

    noFaceRGB_file = ROOT / "_tmp_noFaceRGB_A.mat"
    if noFaceRGB_file.exists():
        noFaceRGB_file.unlink()

    out, dest_lab, _, lab2 = img_AddRender_simp(
        img, bull, bull_nosd, "LUT", np.zeros(3), XYZ,
        str(noFaceRGB_file), if_wei=True, if_2mask=True,
        handle={"LUT_type": "phase2"}, data_root=str(DATA_ROOT))

    check("out 形状", out.shape == (h, w, 3), f"{out.shape}")
    check("out 范围 0~1", float(out.min()) >= 0.0 and float(out.max()) <= 1.0,
          f"min={out.min():.4f} max={out.max():.4f}")
    check("dest_lab 形状", dest_lab.shape == (3,), f"{dest_lab.shape}")
    check("lab2 形状", lab2.shape == (h * w, 3), f"{lab2.shape}")

    # 背景行（logicalIndex True）输出应等于直接 LUT 背景 XYZ 的结果 / 255
    lut = load_mat(str(DATA_ROOT / "A_characterization" / "display_model" / "data_ipv30_phase2_3.mat"))
    bg_xyz = XYZ[:2, :2].reshape(4, 3)
    bg_rgb, _ = lut3d_xyz2rgbKDitp1(bg_xyz, datafile=str(
        DATA_ROOT / "A_characterization" / "display_model" / "data_ipv30_phase2_3.mat"))
    # 背景像素按 C order 展平后位于 idx [0,1,4,5]
    bg_out = np.stack([out[0, 0], out[0, 1], out[1, 0], out[1, 1]])
    check("背景输出=LUT背景", np.allclose(bg_out * 255.0, bg_rgb, atol=1e-9),
          f"maxdiff={(bg_out*255-bg_rgb).max():.2e}")
    check("noFaceRGB 缓存已生成", noFaceRGB_file.exists())

    # 二次调用应复用缓存且结果一致
    out2, _, _, _ = img_AddRender_simp(
        img, bull, bull_nosd, "LUT", np.zeros(3), XYZ,
        str(noFaceRGB_file), if_wei=True, if_2mask=True,
        handle={"LUT_type": "phase2"}, data_root=str(DATA_ROOT))
    check("缓存复用结果一致", np.allclose(out, out2, atol=0.0))

    # if_2mask=False 分支可跑
    out3, dest3, _, _ = img_AddRender_simp(
        img, bull, bull_nosd, "LUT", np.zeros(3), XYZ,
        str(noFaceRGB_file), if_wei=True, if_2mask=False,
        handle={"LUT_type": "phase2"}, data_root=str(DATA_ROOT))
    check("if_2mask=False 可跑", out3.shape == (h, w, 3) and dest3.shape == (3,))

    # 合成 get_average 对照：dest_lab(if_2mask=True) 应等于 get_average(lab2, bull_nosd, True)
    exp_dest = get_average(lab2, bull_nosd, True)
    check("dest_lab == get_average(lab2, bull_nosd, wei)", np.allclose(dest_lab, exp_dest, atol=1e-12),
          f"dest={dest_lab} exp={exp_dest}")

    noFaceRGB_file.unlink(missing_ok=True)


# ---------------------------------------------------------------------------
# B. 真实数据端到端（main_i_test.m f04i/H3K 复现）
# ---------------------------------------------------------------------------
def test_real():
    print("== B. 真实数据端到端（f04i/H3K）==")
    mask_dir = I_ROOT / "mask" / "f04i"
    nosd_dir = I_ROOT / "Shadow" / "mask" / "f04i" / "nosd"
    xyz_dir = Path(r"D:\work\VIVOSkinExpe\original_image_XYZ") / "f04i"
    out_dir = I_ROOT / "rendered" / "phase2" / "i" / "f04i"

    img_p = mask_dir / "H3K.JPG"
    bull_p = img_p
    bull_nosd_p = nosd_dir / "H3K.JPG"
    xyz_p = xyz_dir / "H3K.mat"
    ref_jpg = out_dir / "H3K_01[58.5861,22.4045,44.8393].jpg"

    if not (img_p.exists() and bull_nosd_p.exists() and xyz_p.exists() and ref_jpg.exists()):
        print("  [SKIP] 数据/基准文件缺失，跳过真实锚点")
        return

    # --- main_i_test.m 预处理复现 ---
    # f04i: if_wei=0, if_2mask=0, i_type=select_type('f04')=2
    if_wei, if_2mask = 0, 0
    i_type = 2

    img0 = imread(str(img_p))
    img = im2double(img0)
    m, n = img.shape[0], img.shape[1]

    # main 里 wd65_scaled 用 datai_ipv18_3.mat 的 XYZw（注意不是 phase2 文件！）
    fwd = load_mat(str(DATA_ROOT / "A_characterization" / "display_model" / "datai_ipv18_3.mat"))
    XYZw_main = np.asarray(fwd["XYZw"], dtype=np.float64).reshape(3)
    wd65 = np.array([94.813, 100.000, 107.262])
    wd65_scaled = wd65 / 100.0 * XYZw_main[1]

    bull = imread(str(bull_p))
    bull_nosd = imread(str(bull_nosd_p))
    xyz_d = load_xyz(str(xyz_p))
    XYZ = xyz_d["XYZ_cropped"]

    xyz1 = XYZ.reshape(m * n, 3)
    lab1 = xyz2lab(xyz1, "user", wd65_scaled)
    average = get_average(lab1, bull if not if_2mask else bull_nosd, if_wei)

    # a_CL / C_pre / factor / dlabs（main_i_test.m 逐行复刻）
    a_CL = np.array([6.7421, -9.9816])
    if average[0] > 60:
        C_pre = a_CL[0] * np.log(60) + a_CL[1]
    else:
        C_pre = a_CL[0] * np.log(average[0]) + a_CL[1]

    labC_HD65 = load_avelab(str(I_ROOT / "documents" / "aveSkin" / "i" / f"aveLab_D65_{i_type}.mat"))
    factor = C_pre / labC_HD65[0, 3]

    num_points = load_points(str(I_ROOT / "points_added_33.xlsx"))  # (33,3) [0, da, db]
    dlabs = np.tile(np.array([average[0], labC_HD65[0, 1], labC_HD65[0, 2]]), (len(num_points), 1))
    dlabs = dlabs + num_points
    dlabs[:, 1:3] = dlabs[:, 1:3] * factor

    CCT = 3000  # H3K 对应 CT(1)
    Dtype = "full"
    dlab_CATed = CAT_lab2lab1(dlabs, Dtype, CCT, "fore")
    dlab_CATed = adjust_dlabs_shape1(dlab_CATed)

    # i_type==4 才走 adjust_dlabs，f04 跳过
    delta_Lab = dlab_CATed - np.tile(average, (len(dlabs), 1))

    # i_points=1 的 dlab 应与文件名 [58.5861,22.4045,44.8393] 一致
    dlab = delta_Lab[0] + average
    exp_name = f"[{dlab[0]:.4f},{dlab[1]:.4f},{dlab[2]:.4f}]"
    ref_name = "[58.5861,22.4045,44.8393]"
    check("dlab 与 MATLAB 文件名一致", exp_name == ref_name,
          f"ours={exp_name} ref={ref_name}")

    # 渲染
    noFaceRGB_file = out_dir / "noFaceRGB" / "H3K.mat"
    out, dest_lab, _, lab2 = img_AddRender_simp(
        img, bull, bull_nosd, "LUT", delta_Lab[0], XYZ,
        str(noFaceRGB_file), if_wei=if_wei, if_2mask=if_2mask,
        handle={"LUT_type": "phase2"}, data_root=str(DATA_ROOT))

    # 与 MATLAB 基准 jpg 对比（JPEG 有损，容差）
    ref = imread(str(ref_jpg))  # uint8
    ours = np.clip(out, 0.0, 1.0)
    diff = np.abs(ours * 255.0 - ref.astype(np.float64))
    mae = diff.mean()
    p95 = np.percentile(diff, 95)
    check("输出与 MATLAB 基准 MAE < 1.5/255", mae < 1.5, f"MAE={mae:.4f}")
    check("输出与 MATLAB 基准 P95 < 5/255", p95 < 5.0, f"P95={p95:.3f}")

    # dest_lab 对照
    exp_dest = get_average(lab2, bull if not if_2mask else bull_nosd, if_wei)
    check("dest_lab == get_average(lab2, bull)", np.allclose(dest_lab, exp_dest, atol=1e-12),
          f"dest={dest_lab} exp={exp_dest}")


if __name__ == "__main__":
    test_synthetic()
    test_real()
    print(f"\n结果: {PASS} PASS, {FAIL} FAIL")
    sys.exit(1 if FAIL else 0)
