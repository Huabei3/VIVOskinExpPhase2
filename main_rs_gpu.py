# -*- coding: utf-8 -*-
r"""main_rs_gpu.py — main_rs.py 的 GPU 版（结构对齐 main_i_gpu.py）。

与 main_rs.py 完全相同的参数与输出（复用其 render_subject / NEW_NAMES），区别：
  1) 强制 device="cuda"，输出到 rendered_python/gpu/phase2/rs/{lastPart} 独立目录（与 CPU 版区分）；
  2) 启动时若无可用 CUDA 直接报错退出（避免静默回退 CPU）。

说明：
  rs 组与 i 组渲染逻辑完全对齐：img_AddRender_simp('LUT', phase2)，
  走 lut3d_xyz2rgbKDitp1 的「3D LUT 8 最近邻 KNN」（torch.cdist + topk(8)），
  故 device="cuda" 会真正把 KNN 放到 GPU 上加速。

用法:
  python main_rs_gpu.py                                # 全部 20 个 subject
  python main_rs_gpu.py --subs f04r --first-only --point 1   # 单 subject 第1张图第1点
  python main_rs_gpu.py --dry-run                      # 只打印计划不渲染
"""
from __future__ import annotations

import argparse

import torch

import main_rs as base


def main():
    if not torch.cuda.is_available():
        raise SystemExit(
            "ERROR: 当前环境没有可用 CUDA，main_rs_gpu.py 需要 GPU。\n"
            "若只需 CPU 请改用 main_rs.py。"
        )
    print(f"[main_rs_gpu] 设备: CUDA ({torch.cuda.get_device_name(0)})")

    ap = argparse.ArgumentParser(
        description="main_rs_gpu.py — main_rs.py GPU 版（device=cuda + 输出隔离）")
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
    ap.add_argument("--dedup-mode", choices=["matlab", "fast"], default="fast",
                    help="LUT 去重语义：matlab=uniquetol 容差（1:1 一致）/ fast=round 加速（默认）")
    args = ap.parse_args()

    subs = args.subs if args.subs else base.NEW_NAMES
    for model in subs:
        if model.endswith("r"):
            model = model[:-1]
        if model not in base.NEW_NAMES:
            print(f"WARN unknown subject {model}, skip")
            continue
        base.render_subject(model, args.names, args.quality, args.dry_run, args.force,
                            args.points, args.first_only, args.point, args.save_mats,
                            args.dedup_mode, device="cuda", gpu=True)


if __name__ == "__main__":
    main()
