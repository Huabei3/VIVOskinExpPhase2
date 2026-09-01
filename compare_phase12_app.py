# -*- coding: utf-8 -*-
r"""compare_phase12_app.py — app_test 的 Python 版（多进程加速）

对比 phase1(rendered_2max) 与 phase2，逐帧输出与 MATLAB compare_phase12.m 的
app_test 模式完全相同的 22 列统计，每 model 一个 sheet。

phase1 图:  P1_ROOT/{model}/{model}{scene}_{frame}.jpg   (model=f01i..m10r, scene 小写)
phase2 图:  支持两种结构, 自动检测:
  A) AndroidStudio:  P2_ROOT/{model}/app/src/main/res/drawable/{同名}.jpg
  B) rendered_python: P2_ROOT/phase2/i/{model}/{SCENE}_{frame}[Lab].jpg (i 组)
                      P2_ROOT/rs/{model}/{scene}_{frame}[Lab].jpg        (rs 组)
                      (scene 大小写不敏感, 去掉 [Lab] 后缀后与 phase1 匹配)

算法(与 MATLAB 逐点一致):
  mask = read_bull -> idx_keep = ~logicalIndex
  xyz  = lut3d_rgb2xyz1(rgb_keep, LUT)          # phase1 图用 phase1 LUT, phase2 图用 phase2 LUT
  lab  = xyz2lab(xyz, 'user', wd65_scaled)      # wd65 = WD65/100 * XYZw(2)
  de_px = deltaE2000(lab1, lab2)
  if_wei: ave = sum(lab * w)/sum(w), w=bull_weight(idx_keep)   else: mean(lab,0)

图像解码: 必须用 OpenCV(cv2.imread), 与 MATLAB imread 解码器等价(libjpeg-turbo)。
  PIL 解码在约 5% 像素上差 1-18, 导致 dE_max 偏大 ~0.5 (已验证 cv2 与 MATLAB
  verify_app_test_out.xlsx 全 22 列 4 位小数一致, PIL 不行)。

用法:
  python compare_phase12_app.py \
      --p1-root /root/autodl-tmp/rendered_2max \
      --p2-root /root/autodl-tmp/render_code/I_render_stimuli/rendered_python \
      --mask-root /root/autodl-tmp/mask \
      --lut1 /root/autodl-tmp/render_code/A_characterization/display_model/datai_ipv35_3.mat \
      --lut2 /root/autodl-tmp/render_code/A_characterization/display_model/datai_ipv30_phase2_3.mat \
      --out /root/autodl-tmp/render_code/I_render_stimuli_python/compare_phase12_app_test.xlsx \
      --jobs 12
"""
import argparse
import re
import sys
from concurrent.futures import ProcessPoolExecutor, as_completed
from pathlib import Path

import numpy as np
import pandas as pd
import cv2

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from compare_phase12 import (NO_WEI_I, NO_WEI_RS, load_datai, lut3d_rgb2xyz1,
                             wd65_scaled_of)
from color_utils import deltaE2000, xyz2lab
from mask import read_bull

WD65 = np.array([94.813, 100.0, 107.262], dtype=np.float64)  # D65 白点

COLS = ['group', 'subject', 'stimulus', 'file_name',
        'target_L', 'target_a', 'target_b',
        'avg_L_p1', 'avg_a_p1', 'avg_b_p1',
        'avg_L_p2', 'avg_a_p2', 'avg_b_p2',
        'dE_avg_p1p2',
        'dE_max_px', 'dE_p99_px', 'dE_p95_px', 'dE_mean_px', 'dE_median_px', 'dE_min_px',
        'n_mask_px', 'if_wei']


def find_mask_file(mask_root: Path, last_part: str, stimulus: str) -> Path | None:
    """与 MATLAB find_mask_file 一致：目录内 strcmpi 匹配文件名(不含扩展名)。"""
    d = Path(mask_root) / last_part
    if not d.is_dir():
        return None
    for f in d.iterdir():
        if f.is_file() and f.suffix.lower() in ('.jpg', '.jpeg', '.png', '.bmp') \
                and f.stem.lower() == stimulus.lower():
            return f
    return None


def detect_p2_struct(p2_root: Path, model: str) -> str | None:
    """检测 phase2 目录结构: 'android' | 'rendered_python' | None"""
    if (p2_root / model / 'app' / 'src' / 'main' / 'res' / 'drawable').is_dir():
        return 'android'
    if (p2_root / 'phase2' / 'i' / model).is_dir() or (p2_root / 'rs' / model).is_dir():
        return 'rendered_python'
    return None


def build_p2_index(p2_root: Path) -> dict:
    """构建 phase2 文件索引: {(model, key): path}，key = 去 [Lab] 后缀后的小写 stem。
    覆盖 rendered_python 结构 (phase2/i/{model} + rs/{model})。Android 结构不需要索引。"""
    idx: dict = {}
    for group_dir in ('phase2/i', 'rs'):
        gd = p2_root / group_dir
        if not gd.is_dir():
            continue
        for model_dir in gd.iterdir():
            if not model_dir.is_dir() or not re.fullmatch(r'[fm]\d{2}[ir]', model_dir.name):
                continue
            for f in model_dir.glob('*.jpg'):
                stem = f.stem.split('[')[0]          # 去 [Lab] 目标后缀
                idx[(model_dir.name, stem.lower())] = f
    return idx


def collect_app_files(p1_root: Path, p2_root: Path, subs=None, limit=None):
    """返回 list[dict]: {model, group, p1, p2, p2_struct}。逐 model 收集。"""
    out = []
    p2_index = build_p2_index(p2_root)   # rendered_python 用; android 结构下为空 dict
    p1_root = Path(p1_root)
    p2_root = Path(p2_root)
    models = sorted([d for d in p1_root.iterdir()
                     if d.is_dir() and re.fullmatch(r'[fm]\d{2}[ir]', d.name)])
    for md in models:
        model = md.name
        if subs and model not in subs:
            continue
        p2_struct = detect_p2_struct(p2_root, model)
        if p2_struct is None:
            print(f'[warn] {model}: p2 结构无法识别, 跳过')
            continue
        group = 'i' if model.endswith('i') else 'rs'
        imgs = sorted(md.glob('*.jpg'))
        if limit:
            imgs = imgs[:limit]
        for img in imgs:
            stem = img.stem                      # f01ih3k_01
            rest = stem[len(model):] if stem.startswith(model) else stem  # h3k_01
            if p2_struct == 'android':
                p2 = p2_root / model / 'app' / 'src' / 'main' / 'res' / 'drawable' / (stem + '.jpg')
                if not p2.is_file():
                    print(f'[warn] p2 缺图: {p2}')
                    continue
            else:
                p2 = p2_index.get((model, rest.lower()))
                if p2 is None:
                    print(f'[warn] p2 缺图: {model}/{rest}')
                    continue
            out.append({'model': model, 'group': group, 'p1': str(img), 'p2': str(p2)})
    return out


def process_app_one(p1_jpg: str, p2_jpg: str, model: str, group: str,
                    mask_root: Path, datai_p1: dict, datai_p2: dict,
                    wd65_1: np.ndarray, wd65_2: np.ndarray, if_wei: bool,
                    dbg: bool = False):
    """单帧处理，输出 dict(22 列)。与 MATLAB process_app_one 逐点一致。"""
    stem = Path(p1_jpg).stem
    rest = stem[len(model):] if stem.startswith(model) else stem
    stimulus = re.sub(r'_\d+$', '', rest)        # 去 _NN 帧号
    lab_target = [np.nan, np.nan, np.nan]        # phase1 图无 [Lab] 后缀 -> NaN

    mask_file = find_mask_file(mask_root, model, stimulus)
    if mask_file is None:
        raise FileNotFoundError(f'mask not found: {model}/{stimulus}')

    bull = cv2.cvtColor(cv2.imread(str(mask_file)), cv2.COLOR_BGR2RGB)
    if bull is None:
        raise FileNotFoundError(f'cv2 cannot read mask: {mask_file}')
    logicalIndex, bull_weight = read_bull(bull, bool(if_wei))
    idx_keep = ~logicalIndex

    rgb1 = cv2.cvtColor(cv2.imread(p1_jpg), cv2.COLOR_BGR2RGB).astype(np.float64)
    rgb2 = cv2.cvtColor(cv2.imread(p2_jpg), cv2.COLOR_BGR2RGB).astype(np.float64)
    if rgb1.shape != rgb2.shape:
        raise ValueError(f'size mismatch: {p1_jpg} vs {p2_jpg} '
                         f'({rgb1.shape} vs {rgb2.shape})')
    rgb1_keep = rgb1.reshape(-1, 3)[idx_keep]
    rgb2_keep = rgb2.reshape(-1, 3)[idx_keep]

    xyz1 = lut3d_rgb2xyz1(rgb1_keep, datai_p1)   # phase1 图用 phase1 LUT
    xyz2 = lut3d_rgb2xyz1(rgb2_keep, datai_p2)   # phase2 图用 phase2 LUT
    lab1 = xyz2lab(xyz1, 'user', white=wd65_1)
    lab2 = xyz2lab(xyz2, 'user', white=wd65_2)

    de_px, _ = deltaE2000(lab1, lab2)

    if if_wei:
        w = bull_weight[idx_keep]
        w = w / w.sum()
        ave1 = (lab1 * w[:, None]).sum(axis=0)
        ave2 = (lab2 * w[:, None]).sum(axis=0)
    else:
        ave1 = lab1.mean(axis=0)
        ave2 = lab2.mean(axis=0)

    de_avg, _ = deltaE2000(ave1[None, :], ave2[None, :])
    de_avg = float(de_avg[0])

    if dbg:
        print(f'\n--- DEBUG 第1个点(app_test): {stem} ---')
        print(f'  mask={mask_file}  if_wei={if_wei}  n_mask_px={idx_keep.sum()}')
        print(f'  p1 RGB(mask内) mean={rgb1_keep.mean(axis=0).round(1)}')
        print(f'  p2 RGB(mask内) mean={rgb2_keep.mean(axis=0).round(1)}')
        print(f'  phase1 Lab mean={ave1.round(2)}  <-- avg_L/a/b_p1')
        print(f'  phase2 Lab mean={ave2.round(2)}  <-- avg_L/a/b_p2')
        print(f'  dE_avg_p1p2={de_avg:.3f}  dE_px[mean/max]={de_px.mean():.3f}/{de_px.max():.3f}')

    row = {
        'group': group, 'subject': model, 'stimulus': stimulus,
        'file_name': stem + '.jpg',
        'target_L': lab_target[0], 'target_a': lab_target[1], 'target_b': lab_target[2],
        'avg_L_p1': ave1[0], 'avg_a_p1': ave1[1], 'avg_b_p1': ave1[2],
        'avg_L_p2': ave2[0], 'avg_a_p2': ave2[1], 'avg_b_p2': ave2[2],
        'dE_avg_p1p2': de_avg,
        'dE_max_px': float(de_px.max()),
        'dE_p99_px': float(np.percentile(de_px, 99)),
        'dE_p95_px': float(np.percentile(de_px, 95)),
        'dE_mean_px': float(de_px.mean()),
        'dE_median_px': float(np.median(de_px)),
        'dE_min_px': float(de_px.min()),
        'n_mask_px': int(idx_keep.sum()),
        'if_wei': int(if_wei),
    }
    return row


def process_model(model_files, mask_root, lut1, lut2, dbg_first):
    """worker: 处理单个 model 的所有帧。返回 (model, rows)。每进程加载 LUT 一次。"""
    datai_p1 = load_datai(lut1)
    datai_p2 = load_datai(lut2)
    xyz1 = datai_p1['XYZw'].ravel()
    xyz2 = datai_p2['XYZw'].ravel()
    wd65_1 = WD65 / 100.0 * xyz1[1]
    wd65_2 = WD65 / 100.0 * xyz2[1]
    mask_root = Path(mask_root)
    no_wei = NO_WEI_I | NO_WEI_RS

    model = model_files[0]['model']
    rows = []
    n = 0
    for f in model_files:
        if_wei = int(not (f['model'] in no_wei))
        row = process_app_one(f['p1'], f['p2'], f['model'], f['group'],
                              mask_root, datai_p1, datai_p2, wd65_1, wd65_2,
                              bool(if_wei), dbg=(dbg_first and n == 0))
        rows.append(row)
        n += 1
        if n % 50 == 0 or n == len(model_files):
            print(f'  [{model}] {n}/{len(model_files)}  '
                  f'{row["file_name"]}  dE_avg_p1p2={row["dE_avg_p1p2"]:.3f} '
                  f'dE_px[mean/max]={row["dE_mean_px"]:.3f}/{row["dE_max_px"]:.3f}', flush=True)
    return model, rows


def main():
    ap = argparse.ArgumentParser(description='app_test: phase1(rendered_2max) vs phase2, 每 model 一个 sheet')
    ap.add_argument('--p1-root', required=True)
    ap.add_argument('--p2-root', required=True)
    ap.add_argument('--mask-root', required=True)
    ap.add_argument('--lut1', required=True)
    ap.add_argument('--lut2', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--subs', default='', help='逗号分隔的 model 过滤, 如 f01i,m01r')
    ap.add_argument('--limit', type=int, default=0, help='每 model 限前 N 张(调试)')
    ap.add_argument('--jobs', type=int, default=4)
    ap.add_argument('--dbg-first', action='store_true')
    args = ap.parse_args()

    subs = set(args.subs.split(',')) if args.subs else None
    p1_root = Path(args.p1_root)
    p2_root = Path(args.p2_root)

    files = collect_app_files(p1_root, p2_root, subs=subs, limit=args.limit or None)
    if not files:
        print('[error] 未收集到任何文件, 请检查 p1/p2 路径'); return
    print(f'[info] 共收集 {len(files)} 帧, model 数={len({f["model"] for f in files})}')

    by_model = {}
    for f in files:
        by_model.setdefault(f['model'], []).append(f)
    model_list = sorted(by_model)

    n_jobs = min(args.jobs, len(model_list), 16)
    print(f'[info] jobs={n_jobs}, models={len(model_list)}')

    all_rows = []
    with ProcessPoolExecutor(max_workers=n_jobs) as ex:
        futs = {ex.submit(process_model, by_model[m], args.mask_root,
                          args.lut1, args.lut2, args.dbg_first): m for m in model_list}
        for fu in as_completed(futs):
            m = futs[fu]
            try:
                model, rows = fu.result()
                all_rows.extend(rows)
                print(f'[done] {model}: {len(rows)} 帧', flush=True)
            except Exception as e:
                print(f'[fail] {m}: {e}', flush=True)

    T = pd.DataFrame(all_rows, columns=COLS)
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    with pd.ExcelWriter(out, engine='openpyxl') as xw:
        for model in model_list:
            T[T['subject'] == model].to_excel(xw, sheet_name=model, index=False)
        meta = pd.DataFrame([{'mode': 'app_test', 'p1_root': str(p1_root),
                              'p2_root': str(p2_root), 'mask_root': args.mask_root,
                              'lut1': args.lut1, 'lut2': args.lut2,
                              'n_files': len(files), 'jobs': n_jobs}])
        meta.to_excel(xw, sheet_name='meta', index=False)
    print(f'[info] 输出: {out}  ({len(all_rows)} 行, {len(model_list) + 1} sheets)')


if __name__ == '__main__':
    main()
