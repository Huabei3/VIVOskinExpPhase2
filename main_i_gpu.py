# -*- coding: utf-8 -*-
r"""main_i_gpu.py — main_i.py 的 GPU 版：把「查找 8 个最近邻」的 KNN 逻辑强制放到 CUDA 上。

与 main_i.py 完全相同的参数与输出（复用其 render_subject / NEW_NAMES），唯一区别：
  1) KNN 查找 8 最近邻固定走 CUDA，不再 auto 回退 CPU；
  2) 启动时若无可用 CUDA 直接报错退出（避免静默回退 CPU）。

原理：KNN 由 lut_gpu.lut3d_xyz2rgbKDitp1 用 torch.cdist + topk(8) 实现，
      传入 device="cuda" 即在 GPU 上完成「8 最近邻 + 距离倒数加权」；
      对比 main_i.py 的 device="auto"（有 CUDA 走 GPU，无 CUDA 回退 CPU）。

用法:
  python main_i_gpu.py                                # 全部 20 个 subject
  python main_i_gpu.py --subs f04i --names H3K        # 指定 subject + 刺激名
  python main_i_gpu.py --subs f04i --no-uni           # 不去重（逐行 KNN，全程 GPU）
  python main_i_gpu.py --save-format png --save-mats  # 输出 PNG + 调试 mat
  python main_i_gpu.py --dry-run                      # 只打印计划不渲染
"""
from __future__ import annotations

import argparse
import sys

import torch

import main_i as base


def main():
    if not torch.cuda.is_available():
        raise SystemExit(
            "ERROR: 当前环境没有可用 CUDA，main_i_gpu.py 需要 GPU。\n"
            "若只需 CPU 请改用 main_i.py（device=auto / cpu）。"
        )
    print(f"[main_i_gpu] KNN 设备: CUDA ({torch.cuda.get_device_name(0)})")

    ap = argparse.ArgumentParser(
        description="main_i_gpu.py — main_i.py GPU 版（KNN 8 最近邻固定走 CUDA）")
    ap.add_argument("--subs", nargs="*", default=None, help="subject 列表，默认全部 20 个")
    ap.add_argument("--names", nargs="*", default=None, help="刺激名过滤，如 H3K H4K")
    ap.add_argument("--quality", type=int, default=75, help="JPEG quality（默认 75）")
    ap.add_argument("--dry-run", action="store_true", help="只打印计划不渲染")
    ap.add_argument("--force", action="store_true", help="强制重新渲染（忽略已存在文件）")
    ap.add_argument("--points", type=int, default=None, help="每个刺激只渲染前 N 个点")
    ap.add_argument("--first-only", action="store_true", help="只渲染每个 subject 的第一张图")
    ap.add_argument("--point", type=int, default=None, help="只渲染第 N 个点（1-based）")
    ap.add_argument("--save-mats", action="store_true", help="同时保存调试 mat")
    ap.add_argument("--save-format", choices=["jpg", "png"], default="jpg",
                    help="输出格式：jpg（默认，JPEG quality 同上）/ png（无损；若已存在 *_outnew.mat 则直接导出跳过渲染）")
    ap.add_argument("--dedup-mode", choices=["matlab", "fast"], default="fast",
                    help="LUT 去重语义：matlab=uniquetol 容差 / fast=round 加速（默认）")
    ap.add_argument("--resize-factor", type=float, default=None,
                    help="把 img/bull/bull_nosd/XYZ 缩小到 1/N，默认不缩放")
    ap.add_argument("--uni", action=argparse.BooleanOptionalAction, default=None,
                    help="去重开关：--uni=有去重且 1:1 对齐 MATLAB uniquetol；"
                         "--no-uni=无去重（逐行 KNN）。默认 None=沿用 --dedup-mode")
    args = ap.parse_args()

    subs = args.subs if args.subs else base.NEW_NAMES
    for model in subs:
        if model.endswith("i"):
            model = model[:-1]
        if model not in base.NEW_NAMES:
            print(f"WARN unknown subject {model}, skip")
            continue
        base.render_subject(model, args.names, args.quality, args.dry_run, args.force,
                            args.points, args.first_only, args.point, args.save_mats,
                            args.dedup_mode, args.resize_factor, args.uni,
                            device="cuda", save_format=args.save_format, gpu=True)


if __name__ == "__main__":
    main()
