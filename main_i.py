# -*- coding: utf-8 -*-
r"""main_i.py — 批次6：main_i_test.m 主循环 1:1 Python 复刻（i 组，去 imshow）。

MATLAB 源: I_render_stimuli\main_i_test.m
依赖: data_io / color_utils / mask / cat_adjust / render_core

逐行对应：
  ct/CT            -> 21 刺激名 + 色温         (main_i_test.m L7-12)
  handle.LUT_type  -> "phase2"(data_ipv30_phase2_3.mat)   L15-20
  wd65_scaled      -> wd65./100.*XYZw_LUT(2)   L21-24
  new_names/Dtype  -> 20 个 i subject, Dtype="full"  L27-32
  i_type/if_wei/if_2mask -> select_type.m + L42-52
  files/dir_mask/dir_mask_nosd/dir_XYZfile -> L54-60
  labC_HD65        -> documents/aveSkin/i/aveLab_D65_{i_type}.mat  L63
  num_points       -> points_added_33.xlsx 前置零列 (33,3)，文件循环外读一次  L72-73
  CCT=CT(i)        -> 按文件顺序取色温         L144
  dlab_CATed       -> CAT_lab2lab1(dlabs,Dtype,CCT,"fore") + adjust_dlabs_shape1  L145-148
  i_type==4        -> adjust_dlabs(adj)        L149-158
  delta_Lab        -> dlab_CATed - average     L170
  search_name      -> {stem}_{02d}[%.4f,%.4f,%.4f].jpg   L177-179 (num2str 默认4位小数)
  已存在则跳过(默认) -> L180-183；--force 强制重渲染
  noFaceRGB 缓存    -> save_folder/noFaceRGB/{stem}.mat  L187-192
  渲染             -> img_AddRender_simp('LUT', phase2)  L198-200
  保存             -> imwrite jpg（MATLAB 默认 quality=75）  L210-212

用法:
  python main_i.py                      # 全部 20 个 subject
  python main_i.py --subs f04i f05i     # 指定 subject
  python main_i.py --subs f04i --names H3K H4K   # 指定 subject+文件名(可选)
  python main_i.py --dry-run            # 只打印计划不渲染
  python main_i.py --force --subs f04i --names H3K   # 强制重渲染（忽略已存在文件）
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

from data_io import imread, im2double, load_xyz, load_points, load_avelab, load_c_lpara, load_lut
from color_utils import xyz2lab
from mask import get_average
from cat_adjust import CAT_lab2lab1, adjust_dlabs_shape1, adjust_dlabs
from render_core import img_AddRender_simp

I_ROOT = ROOT.parent / "I_render_stimuli"
PROJ = I_ROOT.parent
XYZ_BASE = Path(os.environ.get("XYZ_BASE", r"D:\work\VIVOSkinExpe\original_image_XYZ"))

# ---------- main_i_test.m L7-12 ----------
CT_NAMES = ["H3K", "H4K", "H5K", "H6K", "H7K", "H8K", "HD65",
            "L3K", "L4K", "L5K", "L6K", "L7K", "L8K", "LD65",
            "M3K", "M4K", "M5K", "M6K", "M7K", "M8K", "MD65"]
CT_VALUES = np.array([3000, 4000, 5000, 6000, 7000, 8000, 6500] * 3, dtype=np.float64)
CT_BY_NAME = {name: float(cct) for name, cct in zip(CT_NAMES, CT_VALUES)}

# ---------- L27-30 ----------
NEW_NAMES = ['f04', 'f05', 'f06', 'm04', 'm05', 'm06',
             'f01', 'f02', 'f03', 'm01', 'm02', 'm03',
             'f07', 'f08', 'm07', 'm08',
             'f09', 'f10', 'm09', 'm10']

Dtype = "full"
LUT_TYPE = "phase2"  # 对齐用户最新修改：data_ipv30_phase2_3.mat

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


def render_subject(model: str, names: list[str] | None = None,
                   quality: int = 75, dry_run: bool = False,
                   force: bool = False, points: int | None = None,
                   first_only: bool = False, point: int | None = None,
                   save_mats: bool = False) -> dict:
    lastPart = model + "i"
    if_wei = 0 if lastPart in ["f04i", "f05i", "f06i", "m04i", "m06i"] else 1
    if_2mask = 1 if lastPart in ["m02i", "m03i"] else 0
    i_type = select_type(model)

    # ---------- wd65_scaled L21-24 ----------
    if LUT_TYPE == "phase2":
        datai_file = PROJ / "A_characterization" / "display_model" / "data_ipv30_phase2_3.mat"
    else:
        datai_file = PROJ / "A_characterization" / "display_model" / "data_ipv35_3.mat"
    wd65 = np.array([94.813, 100.000, 107.262])
    lut = load_lut(datai_file)
    XYZw_LUT = lut["XYZw"].reshape(1, 3)
    wd65_scaled = wd65 / 100.0 * XYZw_LUT[0, 1]

    # ---------- 文件列表 L54-60 ----------
    mask_dir = I_ROOT / "mask" / lastPart
    files = sorted([p for p in mask_dir.iterdir()
                    if p.suffix.lower() == ".jpg"], key=lambda p: p.name.lower())
    nosd_dir = I_ROOT / "Shadow" / "mask" / lastPart / "nosd"
    dir_mask_nosd = sorted([p for p in nosd_dir.iterdir()
                            if p.suffix.lower() == ".jpg"], key=lambda p: p.name.lower())
    xyz_dir = XYZ_BASE / lastPart
    dir_XYZfile = sorted([p for p in xyz_dir.iterdir()
                          if p.suffix.lower() == ".mat"], key=lambda p: p.name.lower())
    if names:
        files = [p for p in files if p.stem in names]
        if not files:
            print(f"[{lastPart}] no matched files for {names}, skip")
            return {"lastPart": lastPart, "skipped": True}
    if first_only:  # 对齐 main_i_test.m: for i =[1]
        files = files[:1]

    labC_HD65 = load_avelab(I_ROOT / "documents" / "aveSkin" / "i" / f"aveLab_D65_{i_type}.mat")
    save_folder = I_ROOT / "rendered_python" / LUT_TYPE / "i" / lastPart  # Python 独立目录，避免覆盖 MATLAB 结果
    save_folder.mkdir(parents=True, exist_ok=True)

    # ---------- num_points 循环外读 L72-73 ----------
    num_points = load_points(I_ROOT / "points_added_33.xlsx")  # (33,3) [0,da,db]

    # ---------- a_CL L125-131 ----------
    if i_type in (1, 2):
        a_CL = np.array([6.7421, -9.9816])
    else:
        a_CL = np.asarray(load_c_lpara(I_ROOT / "aveSkinByHand2" / "i" / "C_Lpara"
                                       / f"{i_type}C_L_para.mat")).ravel()

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

        # ---------- 找 bull/bull_nosd/XYZ L88-113 ----------
        bull = imread(str(fp))  # dir_mask 与 files 同目录同名
        bull_nosd_p = _match_by_stem(stem, dir_mask_nosd)
        if bull_nosd_p is None:
            print(f"[{lastPart}/{stem}] WARN no bull_nosd, use bull")
            bull_nosd = bull
        else:
            bull_nosd = imread(str(bull_nosd_p))
        xyz_p = _match_by_stem(stem, dir_XYZfile)
        if xyz_p is None:
            print(f"[{lastPart}/{stem}] WARN no XYZ file, skip")
            continue
        XYZ = load_xyz(str(xyz_p))["XYZ_cropped"]

        xyz1 = XYZ.reshape(m * n, 3)
        lab1 = xyz2lab(xyz1, 'user', wd65_scaled)
        if if_2mask:
            average = get_average(lab1, bull_nosd, if_wei)
        else:
            average = get_average(lab1, bull, if_wei)

        # ---------- C_pre/factor/dlabs L133-141 ----------
        if average[0] > 60:
            C_pre = a_CL[0] * np.log(60) + a_CL[1]
        else:
            C_pre = a_CL[0] * np.log(average[0]) + a_CL[1]
        factor = C_pre / labC_HD65[0, 3]
        rep = np.tile(np.array([average[0], labC_HD65[0, 1], labC_HD65[0, 2]]),
                      (len(num_points), 1))
        dlabs = rep + num_points
        dlabs[:, 1:3] = dlabs[:, 1:3] * factor

        # ---------- CCT=CT(i) L144 ----------
        # 按 stem 查色温：--names 过滤后文件列表被截断，下标取 CCT 会错位（如 HD65 会被当 3000K）
        if stem not in CT_BY_NAME:
            print(f"[{lastPart}/{stem}] WARN stem 不在 CT_NAMES，skip")
            continue
        CCT = CT_BY_NAME[stem]

        # ---------- dlab_CATed L145-158 ----------
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

        # ---------- delta_Lab L170 ----------
        delta_Lab = dlab_CATed - np.tile(average, (len(dlabs), 1))

        handle = {"LUT_type": LUT_TYPE}
        noFaceRGB_folder = save_folder / "noFaceRGB"
        noFaceRGB_folder.mkdir(exist_ok=True)
        noFaceRGB_file = noFaceRGB_folder / f"{stem}.mat"

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
            out_rendering, dest_lab, _, _ = img_AddRender_simp(
                img, bull, bull_nosd, 'LUT', delta_Lab[i_points],
                XYZ, noFaceRGB_file, if_wei, if_2mask, handle, data_root=PROJ,
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
    ap = argparse.ArgumentParser(description="main_i.py — 批次6 主循环（等价 main_i_test.m）")
    ap.add_argument("--subs", nargs="*", default=None, help="subject 列表，默认全部 20 个")
    ap.add_argument("--names", nargs="*", default=None, help="刺激名过滤，如 H3K H4K")
    ap.add_argument("--quality", type=int, default=75, help="JPEG quality（MATLAB imwrite 默认 75）")
    ap.add_argument("--dry-run", action="store_true", help="只打印计划")
    ap.add_argument("--force", action="store_true",
                    help="强制重新渲染（忽略已存在的文件）")
    ap.add_argument("--points", type=int, default=None,
                    help="每个刺激只渲染前 N 个点（默认全部）")
    ap.add_argument("--first-only", action="store_true",
                    help="只渲染每个 subject 的第一张图（对齐 main_i_test.m 的 for i=[1]）")
    ap.add_argument("--point", type=int, default=None,
                    help="只渲染第 N 个点（1-based，对齐 for i_points=[startCenter]）")
    ap.add_argument("--save-mats", action="store_true",
                    help="同时保存调试 mat（xyz2/outnew，默认只出 jpg）")
    args = ap.parse_args()

    subs = args.subs if args.subs else NEW_NAMES
    for model in subs:
        if model.endswith("i"):
            model = model[:-1]
        if model not in NEW_NAMES:
            print(f"WARN unknown subject {model}, skip")
            continue
        render_subject(model, args.names, args.quality, args.dry_run, args.force,
                       args.points, args.first_only, args.point, args.save_mats)


if __name__ == "__main__":
    main()
