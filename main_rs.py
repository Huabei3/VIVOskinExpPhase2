# -*- coding: utf-8 -*-
r"""main_rs.py — 批次7：main_rs_test.m 主循环 1:1 Python 复刻（rs 组，去 imshow）。

MATLAB 源: I_render_stimuli\main_rs_test.m（基于 main_rs.m，应用 i_test 测试模式）
依赖: data_io / color_utils / mask / cat_adjust / render_core

逐行对应（main_rs.m 行号）：
  datai_file        -> data_ipv18_3.mat（正向 LUT，仅取 XYZw）  L9-13
  new_names/Dtype   -> 20 个 r subject, Dtype="full"            L17-22
  i_type            -> select_type.m（f01-03=1,f04-06=2,f07-08=3,f09-10=4）
  if_wei            -> 修正：原 main_rs.m 误写 "f04i" 等，rs 组 lastPart 为 r 后缀  L37-41
  files/dir_mask    -> mask/{lastPart}/*.jpg（同名即 bull）      L30-31
  dir_XYZfile       -> original_image_XYZ/{lastPart}/*.mat      L32-34
  labC_HD65         -> documents/aveSkin/i/aveLab_D65_{i_type}.mat  L43-44
  num_points        -> points_added_33.xlsx 前置零列 (33,3)     L7-8
  a_CL              -> i_type 1/2 固定；3/4 从 documents/aveSkin/i/C_Lpara  L91-98
  C_pre/factor      -> 亮度公式 + factor                         L100-115
  i_type==4         -> autoNhand_scaleoverLUT.mat 求 C_HD65_ind 缩放 labC_HD65（幂等，subject 级一次） L107-112
  CCT               -> light_r/model_tcp/{model}.mat 的 model_tcp_mean(i,1)  L52,118
  后 CAT            -> CAT_lab2lab1(dlabs,Dtype,CCT,"fore") + adjust_dlabs_shape1  L119-122
  i_type==4         -> adjust_dlabs(adj)                         L123-132
  delta_Lab         -> dlab - average                            L138-139
  search_name       -> {stem}_{02d}[%.4f,%.4f,%.4f].jpg          L141-143
  渲染              -> img_AddRender_simp('srgb', 无 handle=phase1)  L160-162
  保存              -> imwrite jpg（MATLAB 默认 quality=75）

用法:
  python main_rs.py                      # 全部 20 个 subject
  python main_rs.py --subs f04r f05r     # 指定 subject（可带 r 后缀）
  python main_rs.py --dry-run            # 只打印计划不渲染
  python main_rs.py --first-only --point 1   # 对齐测试模式：第1张图第1个点
"""
from __future__ import annotations

import argparse
import os
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))

from data_io import imread, im2double, load_xyz, load_points, load_avelab, load_c_lpara, load_forward_lut, load_mat
from color_utils import xyz2lab
from mask import get_average
from cat_adjust import CAT_lab2lab1, adjust_dlabs_shape1, adjust_dlabs
from render_core import img_AddRender_simp

I_ROOT = ROOT.parent / "I_render_stimuli"
PROJ = I_ROOT.parent
XYZ_BASE = Path(os.environ.get("XYZ_BASE", r"D:\work\VIVOSkinExpe\original_image_XYZ"))

# ---------- main_rs.m L9-13 ----------
DATA_FORWARD = "data_ipv18_3.mat"  # 正向 LUT，仅用 XYZw
wd65 = np.array([94.813, 100.000, 107.262])

# ---------- L17-22 ----------
NEW_NAMES = ['f04', 'f05', 'f06', 'm04', 'm05', 'm06',
             'f01', 'f02', 'f03', 'm01', 'm02', 'm03',
             'f07', 'f08', 'm07', 'm08',
             'f09', 'f10', 'm09', 'm10']

Dtype = "full"

# ---------- select_type.m ----------
_TYPE_MAP = {
    1: ["f01", "f02", "f03", "m01", "m02", "m03"],
    2: ["f04", "f05", "f06", "m04", "m05", "m06"],
    3: ["f07", "f08", "m07", "m08"],
    4: ["f09", "f10", "m09", "m10"],
}


def select_type(model: str) -> int:
    for t, models in _TYPE_MAP.items():
        if model in models:
            return t
    raise ValueError(f"model doesn't exist: {model}")


def _mnum(x: float) -> str:
    """对齐 MATLAB num2str 默认：最多4位小数，去尾零。57.8574->'57.8574', 100->'100'。"""
    s = f"{x:.4f}".rstrip('0').rstrip('.')
    return s if s not in ('', '-') else '0'


def _match_by_stem(stem: str, paths: list[Path]) -> Path | None:
    for p in paths:
        if p.stem == stem:
            return p
    return None


def _match_rs_xyz(stem: str, paths: list[Path]) -> Path | None:
    """对齐 main_rs.m L75-83：dir_XYZfile(i_xyz).name(end-7:end-4) 提取场景名。

    XYZ 文件名如 female78r_rs01.mat，name(end-7:end-4)=rs01（stem 后 4 字符）。
    """
    for p in paths:
        if len(p.stem) >= 4 and p.stem[-4:] == stem:
            return p
    return None


def render_subject(model: str, names: list[str] | None = None,
                   quality: int = 75, dry_run: bool = False,
                   force: bool = False, points: int | None = None,
                   first_only: bool = False, point: int | None = None,
                   save_mats: bool = False) -> dict:
    lastPart = model + "r"
    # 修正：原 main_rs.m L37 误写 "f04i" 等（i 后缀，rs 组恒不匹配→if_wei 恒 1）
    if_wei = 0 if lastPart in ["f04r", "f05r", "f06r", "m04r", "m06r"] else 1
    if_2mask = 0  # rs 组无 2mask（main_rs.m 直接用 bull，无 nosd）
    i_type = select_type(model)

    # ---------- wd65_scaled L9-13 ----------
    lut = load_forward_lut(PROJ / "A_characterization" / "display_model" / DATA_FORWARD)
    XYZw_LUT = lut["XYZw"].reshape(1, 3)
    wd65_scaled = wd65 / 100.0 * XYZw_LUT[0, 1]

    # ---------- 文件列表 L30-34 ----------
    mask_dir = I_ROOT / "mask" / lastPart
    files = sorted([p for p in mask_dir.iterdir()
                    if p.suffix.lower() == ".jpg"], key=lambda p: p.name.lower())
    xyz_dir = XYZ_BASE / lastPart
    dir_XYZfile = sorted([p for p in xyz_dir.iterdir()
                          if p.suffix.lower() == ".mat"], key=lambda p: p.name.lower())
    if names:
        files = [p for p in files if p.stem in names]
        if not files:
            print(f"[{lastPart}] no matched files for {names}, skip")
            return {"lastPart": lastPart, "skipped": True}
    if first_only:  # 对齐 main_rs_test.m: for i =[1]
        files = files[:1]

    labC_HD65 = load_avelab(I_ROOT / "documents" / "aveSkin" / "i" / f"aveLab_D65_{i_type}.mat")
    save_folder = I_ROOT / "rendered_python" / "rs" / lastPart  # Python 独立目录，避免覆盖 MATLAB 结果
    save_folder.mkdir(parents=True, exist_ok=True)

    # ---------- num_points 循环外读 L7-8 ----------
    num_points = load_points(I_ROOT / "points_added_33.xlsx")  # (33,3) [0,da,db]

    # ---------- a_CL L91-98 ----------
    if i_type in (1, 2):
        a_CL = np.array([6.7421, -9.9816])
    else:
        a_CL = np.asarray(load_c_lpara(I_ROOT / "documents" / "aveSkin" / "i" / "C_Lpara"
                                       / f"{i_type}C_L_para.mat")).ravel()

    # ---------- i_type==4: C_HD65_ind 缩放 labC_HD65 L107-112（幂等，subject 级一次） ----------
    if i_type == 4:
        an = load_mat(I_ROOT / "documents" / "aveSkin" / f"{model}i" / "autoNhand_scaleoverLUT.mat")
        average_lab_all = an["average_lab_all"]
        C_HD65_ind = np.sqrt(average_lab_all[6, 1] ** 2 + average_lab_all[6, 2] ** 2)
        labC_HD65[0, 1:4] = labC_HD65[0, 1:4] / labC_HD65[0, 3] * C_HD65_ind

    # ---------- CCT: light_r/model_tcp/{model}.mat L52 ----------
    tcp = load_mat(I_ROOT / "light_r" / "model_tcp" / f"{model}.mat")
    model_tcp_mean = tcp["model_tcp_mean"]  # (14,1)

    stats = {"lastPart": lastPart, "n_files": len(files),
             "if_wei": if_wei, "if_2mask": if_2mask, "i_type": i_type,
             "rendered": 0, "skipped_existing": 0, "skipped": False}
    print(f"\n=== {lastPart}  i_type={i_type} if_wei={if_wei} if_2mask={if_2mask} "
          f"files={len(files)} ===")

    for i, fp in enumerate(files):
        stem = fp.stem
        img0 = imread(str(fp))
        img = im2double(img0)
        m, n = img.shape[0], img.shape[1]

        # ---------- 找 bull/XYZ L67-83 ----------
        bull = imread(str(fp))  # dir_mask 与 files 同目录同名
        xyz_p = _match_rs_xyz(stem, dir_XYZfile)
        if xyz_p is None:
            print(f"[{lastPart}/{stem}] WARN no XYZ file, skip")
            continue
        XYZ = load_xyz(str(xyz_p))["XYZ_cropped"]

        xyz1 = XYZ.reshape(m * n, 3)
        lab1 = xyz2lab(xyz1, 'user', wd65_scaled)
        average = get_average(lab1, bull, if_wei)  # rs 组无 if_2mask，直接用 bull

        # ---------- C_pre/factor/dlabs L100-115 ----------
        if average[0] > 60:
            C_pre = a_CL[0] * np.log(60) + a_CL[1]
        else:
            C_pre = a_CL[0] * np.log(average[0]) + a_CL[1]
        factor = C_pre / labC_HD65[0, 3]
        rep = np.tile(np.array([average[0], labC_HD65[0, 1], labC_HD65[0, 2]]),
                      (len(num_points), 1))
        dlabs = rep + num_points
        dlabs[:, 1:3] = dlabs[:, 1:3] * factor

        # ---------- CCT=model_tcp_mean(i,1) L118 ----------
        # 修正：不能用枚举 i 索引 model_tcp_mean。--names/--first-only 过滤后
        # files 顺序错位（enumerate 从 0 起），必须按 scene 名 rsXX 映射行号，
        # 对齐 MATLAB for i=[5] 时 model_tcp_mean(5,1) 取 rs05 的 CCT。
        scene_idx = int(stem[-2:]) - 1  # 'rs05' -> 4
        if not (0 <= scene_idx < len(model_tcp_mean)):
            print(f"[{lastPart}/{stem}] WARN scene_idx={scene_idx} out of range, skip")
            continue
        CCT = float(model_tcp_mean[scene_idx, 0])

        # ---------- 后 CAT L119-122 ----------
        dlab_CATed = CAT_lab2lab1(dlabs, Dtype, CCT, "fore")
        dlab_CATed = adjust_dlabs_shape1(dlab_CATed)
        if i_type == 4:
            if model in ("f09", "m09"):
                adj = 0.55
            elif model == "f10":
                adj = 0.54
            elif model == "m10":
                adj = 0.5
            else:
                adj = 1.0
            dlab_CATed = adjust_dlabs(dlab_CATed, adj)

        # ---------- delta_Lab L138-139 ----------
        delta_Lab = dlab_CATed - np.tile(average, (len(dlabs), 1))

        noFaceRGB_folder = save_folder / "noFaceRGB"
        noFaceRGB_folder.mkdir(exist_ok=True)
        noFaceRGB_file = noFaceRGB_folder / f"{stem}.mat"  # 'srgb' 分支不使用，保持与 MATLAB 一致

        n_pts = len(num_points) if points is None else min(points, len(num_points))
        for i_points in range(n_pts):
            if point is not None and i_points != point - 1:  # --point N: 只渲染第 N 个点
                continue
            dlab = delta_Lab[i_points] + average
            search_name = (f"{stem}_{i_points + 1:02d}"
                           f"[{_mnum(dlab[0])},{_mnum(dlab[1])},{_mnum(dlab[2])}].jpg")
            out_path = save_folder / search_name
            if out_path.exists() and not force:
                stats["skipped_existing"] += 1
                continue

            if dry_run:
                continue

            t0 = time.time()
            xyz2_file = out_path.with_suffix(".mat") if save_mats else None
            outnew_file = out_path.with_name(out_path.stem + "_outnew.mat") if save_mats else None
            # rs 组：'srgb' 分支，无 handle（=phase1），if_2mask=0，bull_nosd=bull
            out_rendering, dest_lab, _, _ = img_AddRender_simp(
                img, bull, bull, 'srgb', delta_Lab[i_points],
                XYZ, noFaceRGB_file, if_wei, if_2mask, data_root=PROJ,
                xyz2_file=xyz2_file, outnew_file=outnew_file)
            out8 = np.clip(out_rendering * 255.0, 0, 255).astype(np.uint8)
            Image.fromarray(out8).save(out_path, "JPEG", quality=quality)
            stats["rendered"] += 1
            dt = time.time() - t0
            dE = _rough_dE(dest_lab, dlab)
            print(f"  {lastPart}/{search_name}  dE={dE:.3f}  {dt:.1f}s")

    print(f"[{lastPart}] done: rendered={stats['rendered']} "
          f"existing_skip={stats['skipped_existing']}")
    return stats


def _rough_dE(lab1, lab2) -> float:
    """粗略 dE76，仅用于进度提示（严格 dE2000 未在 Python 侧实现）。"""
    l1 = np.asarray(lab1, dtype=np.float64).reshape(1, 3)
    l2 = np.asarray(lab2, dtype=np.float64).reshape(1, 3)
    return float(np.sqrt(((l1 - l2) ** 2).sum(axis=1))[0])


def main():
    ap = argparse.ArgumentParser(description="main_rs.py — 批次7 主循环（等价 main_rs_test.m）")
    ap.add_argument("--subs", nargs="*", default=None, help="subject 列表，默认全部 20 个")
    ap.add_argument("--names", nargs="*", default=None, help="刺激名过滤，如 rs01 rs02")
    ap.add_argument("--quality", type=int, default=75, help="JPEG quality（MATLAB imwrite 默认 75）")
    ap.add_argument("--dry-run", action="store_true", help="只打印计划")
    ap.add_argument("--force", action="store_true",
                    help="强制重新渲染（忽略已存在的文件）")
    ap.add_argument("--points", type=int, default=None,
                    help="每个刺激只渲染前 N 个点（默认全部）")
    ap.add_argument("--first-only", action="store_true",
                    help="只渲染每个 subject 的第一张图（对齐 main_rs_test.m 的 for i=[1]）")
    ap.add_argument("--point", type=int, default=None,
                    help="只渲染第 N 个点（1-based，对齐 for i_points=[startCenter]）")
    ap.add_argument("--save-mats", action="store_true",
                    help="同时保存调试 mat（xyz2/outnew，默认只出 jpg）")
    args = ap.parse_args()

    subs = args.subs if args.subs else NEW_NAMES
    for model in subs:
        if model.endswith("r"):
            model = model[:-1]
        if model not in NEW_NAMES:
            print(f"WARN unknown subject {model}, skip")
            continue
        render_subject(model, args.names, args.quality, args.dry_run, args.force,
                       args.points, args.first_only, args.point, args.save_mats)


if __name__ == "__main__":
    main()
