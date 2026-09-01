"""compare_phase12.py — phase1(ipv35) vs phase2(ipv30_phase2_3) LUT 渲染对比。

对比口径（对齐 MATLAB `main_i_test.m` 的 `plot_pic_dE`）：
1. 读取 phase2 渲染输出 jpg（i 组: rendered_python/phase2/i/，rs 组: rendered_python/rs/）
2. 逐像素 RGB -> `lut3d_rgb2xyz1`（phase1/phase2 两个 datai 正向 LUT）-> XYZ
3. XYZ -> Lab（各用本 LUT 的 wd65_scaled 白点）
4. mask 内（~logicalIndex）逐点 dE2000 统计（max/p99/p95/mean/median/min）
5. `get_average` 平均 Lab，输出"两点平均差" dE_avg_p1p2，以及相对目标 Lab 的 dE
6. 结果写 xlsx（sheet: summary + meta）

性能说明：
- `lut3d_rgb2xyz1` 的 interp3('linear') 用手写向量化 trilinear 实现
  （与 scipy RegularGridInterpolator / MATLAB interp3 在 [0,255] 网格内数学等价），
  `--check-rgi` 可抽样对比两种实现，验证一致性后通常无需开启。

用法示例：
    python compare_phase12.py                       # 全部渲染点（i+rs）
    python compare_phase12.py --group i             # 仅 i 组
    python compare_phase12.py --subs f01i f04i      # 仅指定 subject
    python compare_phase12.py --names HD65 rs05     # 仅指定 stimulus 前缀
    python compare_phase12.py --limit 2             # 每 subject 最多 2 个点（快速验证）
    python compare_phase12.py --out compare_phase12.xlsx
"""
from __future__ import annotations

import argparse
import re
import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

from data_io import load_mat, imread              # noqa: E402
from mask import read_bull                        # noqa: E402
from color_utils import xyz2lab, lab2xyz2, deltaE2000   # noqa: E402

# ---------------------------------------------------------------------------
# 路径常量
# ---------------------------------------------------------------------------
PROJ = HERE.parent / "I_render_stimuli"
RENDER_I = PROJ / "rendered_python" / "phase2" / "i"     # i 组渲染输出
RENDER_RS = PROJ / "rendered_python" / "rs"               # rs 组渲染输出
MASK_ROOT = PROJ / "mask"

# phase1 / phase2 正向 LUT（datai：含 lablut/cubeL/XYZw，供 lut3d_rgb2xyz1 用）
DATAI_P1 = HERE.parent / "A_characterization" / "display_model" / "datai_ipv35_3.mat"
DATAI_P2 = Path(r"D:\work\VIVOSkin_phase2\display\model_interp\datai_ipv30_phase2_3.mat")

WD65 = np.array([94.813, 100.0, 107.262], dtype=np.float64)  # D65

# if_wei=0 的 subject 集合（i 与 rs 各自的后缀规则）
NO_WEI_I = {"f04i", "f05i", "f06i", "m04i", "m06i"}
NO_WEI_RS = {"f04r", "f05r", "f06r", "m04r", "m06r"}


# ---------------------------------------------------------------------------
# LUT 加载 / lut3d_rgb2xyz1 复刻（对应 MATLAB utils/lut3d_rgb2xyz1.m）
# ---------------------------------------------------------------------------
_DATAI_CACHE: dict[str, dict] = {}


def load_datai(path: Path | str) -> dict:
    """预载 datai 正向 LUT，缓存 cubeL/lablut/XYZw。"""
    path = str(path)
    if path not in _DATAI_CACHE:
        d = load_mat(path)
        cubeL = int(np.asarray(d["cubeL"]).flatten()[0])
        _DATAI_CACHE[path] = {
            "cubeL": cubeL,
            "lablut": np.asarray(d["lablut"], dtype=np.float64),
            "XYZw": np.asarray(d["XYZw"], dtype=np.float64).reshape(1, 3),
        }
    return _DATAI_CACHE[path]


def _trilinear(vals: np.ndarray, idx_cont: np.ndarray, chunk: int = 1_000_000) -> np.ndarray:
    """向量化 trilinear（等价 interp3 'linear'）。

    vals: (cubeL, cubeL, cubeL, 3) 通道末维
    idx_cont: (N,3) 连续网格索引（0~cubeL-1）
    用扁平索引 gather（vals.reshape(-1,3)[flat_idx]），比 3D fancy indexing 快。
    """
    cubeL = vals.shape[0]
    flat = vals.reshape(-1, 3)
    N = idx_cont.shape[0]
    out = np.empty((N, 3), dtype=np.float64)
    for s in range(0, N, chunk):
        e = min(s + chunk, N)
        f = idx_cont[s:e]
        i0 = np.floor(f).astype(np.int64)
        i1 = np.minimum(i0 + 1, cubeL - 1)
        w = f - i0
        wr, wg, wb = w[:, 0], w[:, 1], w[:, 2]
        r0, g0, b0 = i0[:, 0], i0[:, 1], i0[:, 2]
        r1, g1, b1 = i1[:, 0], i1[:, 1], i1[:, 2]
        # 扁平索引 = (r*cubeL + g)*cubeL + b
        c2 = cubeL * cubeL
        i000 = (r0 * cubeL + g0) * cubeL + b0
        i100 = (r1 * cubeL + g0) * cubeL + b0
        i010 = (r0 * cubeL + g1) * cubeL + b0
        i110 = (r1 * cubeL + g1) * cubeL + b0
        i001 = (r0 * cubeL + g0) * cubeL + b1
        i101 = (r1 * cubeL + g0) * cubeL + b1
        i011 = (r0 * cubeL + g1) * cubeL + b1
        i111 = (r1 * cubeL + g1) * cubeL + b1
        del i0, i1, r0, g0, b0, r1, g1, b1
        o = ((1 - wr) * (1 - wg) * (1 - wb))[:, None] * flat[i000] \
            + (wr * (1 - wg) * (1 - wb))[:, None] * flat[i100] \
            + ((1 - wr) * wg * (1 - wb))[:, None] * flat[i010] \
            + ((1 - wr) * (1 - wg) * wb)[:, None] * flat[i001] \
            + (wr * wg * (1 - wb))[:, None] * flat[i110] \
            + (wr * (1 - wg) * wb)[:, None] * flat[i101] \
            + ((1 - wr) * wg * wb)[:, None] * flat[i011] \
            + (wr * wg * wb)[:, None] * flat[i111]
        out[s:e] = o
    return out


def lut3d_rgb2xyz1(RGB: np.ndarray, datai: dict,
                   check_rgi: bool = False) -> np.ndarray:
    """1:1 复刻 MATLAB `lut3d_rgb2xyz1(rgb, datai_file)`。

    输入 RGB (N,3) uint8（0-255）；返回 XYZ (N,3)。
    内部：RGB -> LUT 网格 trilinear 插值 -> Lab -> lab2xyz2('user', XYZw)。
    """
    cubeL = datai["cubeL"]
    lablut_raw = datai["lablut"]                 # (cubeL^3, 3)，列为 L/a/b
    # MATLAB `lut3d_rgb2xyz1.m` 用列主序 reshape 每列成 cubeL^3 网格；
    # numpy 需按 F 序逐列 reshape，再 stack 到末维，得到 C 序存储的
    # (cubeL,cubeL,cubeL,3)，与 MATLAB 逐点等价。
    # （不能直接 order='F' 整体 reshape：会破坏 _trilinear 的 C 序扁平索引。）
    lablut = np.stack(
        [lablut_raw[:, ch].reshape(cubeL, cubeL, cubeL, order="F") for ch in range(3)],
        axis=-1,
    )
    XYZw = datai["XYZw"]

    rgb = np.clip(RGB.astype(np.float64), 0.0, 255.0)
    # MATLAB `interp3(m,j,k,lutL, R,G,B)` 在 meshgrid 约定下 V 索引为
    # V(dim1=Y, dim2=X, dim3=Z)：j 对应 lutL 第 1 维(G), m 对应第 2 维(R),
    # k 对应第 3 维(B) -> 实际采样 lutL[G, R, B]。
    # 这里交换 R/G 通道后再插值, 使 _trilinear 的 (r,g,b) 命中 lutL[G,R,B]。
    idx_cont = rgb[:, [1, 0, 2]] / 255.0 * (cubeL - 1)   # 连续网格索引 (G,R,B)
    lab = _trilinear(lablut, idx_cont)

    if check_rgi:  # 一致性校验：与 scipy RegularGridInterpolator 对比抽样点
        from scipy.interpolate import RegularGridInterpolator
        grid = np.linspace(0.0, 255.0, cubeL)
        pts = (grid, grid, grid)
        n = min(20_000, rgb.shape[0])
        idx_rnd = np.random.default_rng(0).choice(rgb.shape[0], n, replace=False)
        dmax = 0.0
        for ch in range(3):
            itp = RegularGridInterpolator(pts, lablut[:, :, :, ch], method="linear",
                                          bounds_error=False, fill_value=None)
            ref = itp(rgb[idx_rnd])
            dmax = max(dmax, float(np.abs(ref - lab[idx_rnd, ch]).max()))
        print(f"    [check_rgi] cubeL={cubeL} 抽样 n={n} 最大差={dmax:.3e}")

    return lab2xyz2(lab, "user", XYZw)


def wd65_scaled_of(datai: dict) -> np.ndarray:
    """wd65_scaled = wd65/100*XYZw_LUT(2)，对齐 MATLAB。"""
    return WD65 / 100.0 * datai["XYZw"][0, 1]


# ---------------------------------------------------------------------------
# 文件名解析
# ---------------------------------------------------------------------------
_PAT_LAB = re.compile(r"\[(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)\]")
_PAT_STIM = re.compile(r"^(.+?)_\d+\[.+\]$")


def parse_target_lab(stem: str) -> np.ndarray:
    m = _PAT_LAB.search(stem)
    if not m:
        raise ValueError(f"文件名中未找到目标 Lab 值: {stem}")
    return np.array([float(m.group(1)), float(m.group(2)), float(m.group(3))])


def parse_stimulus(stem: str) -> str:
    """`HD65_33[58.38,...]` -> `HD65`；`rs05_33[...]` -> `rs05`。"""
    m = _PAT_STIM.match(stem)
    return m.group(1) if m else stem


def find_mask_file(last_part: str, stimulus: str) -> Path | None:
    """mask/{lastPart}/{stimulus}.jpg（大小写兼容）。"""
    d = MASK_ROOT / last_part
    if not d.is_dir():
        return None
    target = stimulus.lower()
    for f in d.iterdir():
        if f.is_file() and f.stem.lower() == target and f.suffix.lower() in (".jpg", ".jpeg"):
            return f
    return None


# ---------------------------------------------------------------------------
# 主流程
# ---------------------------------------------------------------------------
def collect_render_files(group: str) -> list[tuple[str, str, Path]]:
    """返回 [(group_tag, lastPart, jpg_path)]。"""
    out: list[tuple[str, str, Path]] = []
    roots: list[tuple[str, Path]] = []
    if group in ("i", "all"):
        roots.append(("i", RENDER_I))
    if group in ("rs", "all"):
        roots.append(("rs", RENDER_RS))
    for tag, root in roots:
        if not root.is_dir():
            print(f"[warn] 渲染输出目录不存在: {root}")
            continue
        for last_part in sorted(p.name for p in root.iterdir() if p.is_dir()):
            d = root / last_part
            # 手动按后缀过滤（glob 在 Windows 上大小写不敏感会重复匹配）
            fs = sorted(f for f in d.iterdir()
                        if f.is_file() and f.suffix.lower() in (".jpg", ".jpeg"))
            out.extend((tag, last_part, f) for f in fs)
    return out


def process_one(jpg: Path, last_part: str, group: str,
                datai_p1: dict, datai_p2: dict,
                wd65_1: np.ndarray, wd65_2: np.ndarray,
                check_rgi: bool) -> dict:
    stem = jpg.stem
    lab_target = parse_target_lab(stem)
    stimulus = parse_stimulus(stem)
    if_wei = 1
    if (group == "i" and last_part in NO_WEI_I) or (group == "rs" and last_part in NO_WEI_RS):
        if_wei = 0

    mask_file = find_mask_file(last_part, stimulus)
    if mask_file is None:
        raise FileNotFoundError(f"mask 文件缺失: {last_part}/{stimulus} (from {jpg.name})")
    bull = imread(mask_file)
    logical_idx, bull_weight = read_bull(bull, if_wei)

    rgb = imread(jpg)                          # (H,W,3) uint8
    rgb_flat = rgb.reshape(-1, 3)

    # 仅对 mask 内（bull_weight>0，即 ~logicalIndex）像素计算 ——
    # 与全图计算数学等价：加权平均中 weight=0 的像素贡献为 0。
    idx_keep = ~logical_idx
    n_keep = int(idx_keep.sum())
    if n_keep == 0:
        raise ValueError(f"mask 无有效像素: {mask_file}")
    rgb_keep = rgb_flat[idx_keep]

    # phase1 / phase2 反算
    xyz1 = lut3d_rgb2xyz1(rgb_keep, datai_p1, check_rgi)
    xyz2 = lut3d_rgb2xyz1(rgb_keep, datai_p2, check_rgi)
    lab1 = xyz2lab(xyz1, "user", wd65_1.reshape(1, 3))
    lab2 = xyz2lab(xyz2, "user", wd65_2.reshape(1, 3))

    # mask 内逐点 dE2000（lab1/lab2 已是 idx_keep 子集）
    de_px = deltaE2000(lab1, lab2)[0]
    stats = {
        "n_mask_px": n_keep,
        "dE_max_px": float(np.max(de_px)) if de_px.size else np.nan,
        "dE_p99_px": float(np.percentile(de_px, 99)) if de_px.size else np.nan,
        "dE_p95_px": float(np.percentile(de_px, 95)) if de_px.size else np.nan,
        "dE_mean_px": float(np.mean(de_px)) if de_px.size else np.nan,
        "dE_median_px": float(np.median(de_px)) if de_px.size else np.nan,
        "dE_min_px": float(np.min(de_px)) if de_px.size else np.nan,
    }

    # get_average 等价实现（对齐 mask.get_average：if_wei 加权 / else 非黑均值）
    if if_wei:
        w = bull_weight[idx_keep]
        ave1 = np.sum(lab1 * w[:, None], axis=0) / np.sum(w)
        ave2 = np.sum(lab2 * w[:, None], axis=0) / np.sum(w)
    else:
        ave1 = np.mean(lab1, axis=0)
        ave2 = np.mean(lab2, axis=0)
    ave1 = ave1.reshape(1, 3)
    ave2 = ave2.reshape(1, 3)
    dE_avg_p1p2 = deltaE2000(ave1, ave2)[0][0]
    dE_target_p1 = deltaE2000(ave1, lab_target.reshape(1, 3))[0][0]
    dE_target_p2 = deltaE2000(ave2, lab_target.reshape(1, 3))[0][0]

    return {
        "group": group,
        "subject": last_part,
        "stimulus": stimulus,
        "file_name": jpg.name,
        "target_L": lab_target[0], "target_a": lab_target[1], "target_b": lab_target[2],
        "avg_L_p1": ave1[0, 0], "avg_a_p1": ave1[0, 1], "avg_b_p1": ave1[0, 2],
        "avg_L_p2": ave2[0, 0], "avg_a_p2": ave2[0, 1], "avg_b_p2": ave2[0, 2],
        "dE_avg_p1p2": dE_avg_p1p2,
        "dE_target_p1": dE_target_p1,
        "dE_target_p2": dE_target_p2,
        "if_wei": if_wei,
        **stats,
    }


def main() -> None:
    ap = argparse.ArgumentParser(description="phase1 vs phase2 LUT 渲染对比（逐点 dE2000 + get_average）")
    ap.add_argument("--group", choices=["i", "rs", "all"], default="all")
    ap.add_argument("--subs", nargs="*", default=None, help="仅处理这些 subject（如 f01i f04i）")
    ap.add_argument("--names", nargs="*", default=None, help="仅处理这些 stimulus 前缀（如 HD65 rs05）")
    ap.add_argument("--limit", type=int, default=None, help="每 subject 最多处理 N 个点")
    ap.add_argument("--check-rgi", action="store_true",
                    help="抽样与 scipy RegularGridInterpolator 对比（校验手写 trilinear）")
    ap.add_argument("--out", type=str, default=str(HERE / "compare_phase12.xlsx"))
    args = ap.parse_args()

    datai_p1 = load_datai(DATAI_P1)
    datai_p2 = load_datai(DATAI_P2)
    wd65_1 = wd65_scaled_of(datai_p1)
    wd65_2 = wd65_scaled_of(datai_p2)
    print(f"[info] phase1 datai: {DATAI_P1.name} cubeL={datai_p1['cubeL']} XYZw={datai_p1['XYZw'][0].round(4)}")
    print(f"[info] phase2 datai: {DATAI_P2.name} cubeL={datai_p2['cubeL']} XYZw={datai_p2['XYZw'][0].round(4)}")
    print(f"[info] wd65_scaled_p1={np.round(wd65_1, 4)}  wd65_scaled_p2={np.round(wd65_2, 4)}")

    files = collect_render_files(args.group)
    if args.subs:
        files = [(g, s, f) for (g, s, f) in files if s in set(args.subs)]
    if args.names:
        pats = tuple(args.names)
        files = [(g, s, f) for (g, s, f) in files
                 if any(f.stem.startswith(p) for p in pats)]
    if args.limit:
        from collections import Counter
        cnt: Counter[str] = Counter()
        kept: list = []
        for item in files:
            if cnt[item[1]] < args.limit:
                kept.append(item)
                cnt[item[1]] += 1
        files = kept
    print(f"[info] 待对比渲染点: {len(files)} 个")

    rows: list[dict] = []
    t0 = time.time()
    for n, (g, s, f) in enumerate(files, 1):
        try:
            row = process_one(f, s, g, datai_p1, datai_p2, wd65_1, wd65_2, args.check_rgi)
            rows.append(row)
            print(f"[{n}/{len(files)}] {g} {s} {f.name} dE_avg={row['dE_avg_p1p2']:.3f} "
                  f"dE_px[mean/max]={row['dE_mean_px']:.3f}/{row['dE_max_px']:.3f} ({time.time()-t0:.0f}s)")
        except Exception as e:  # noqa: BLE001
            print(f"[skip] {g} {s} {f.name} -> {type(e).__name__}: {e}")

    if not rows:
        print("[warn] 无任何有效结果，未写 xlsx")
        return

    df = pd.DataFrame(rows)
    col_order = ["group", "subject", "stimulus", "file_name",
                 "target_L", "target_a", "target_b",
                 "avg_L_p1", "avg_a_p1", "avg_b_p1",
                 "avg_L_p2", "avg_a_p2", "avg_b_p2",
                 "dE_avg_p1p2", "dE_target_p1", "dE_target_p2",
                 "dE_max_px", "dE_p99_px", "dE_p95_px",
                 "dE_mean_px", "dE_median_px", "dE_min_px",
                 "n_mask_px", "if_wei"]
    df = df[col_order]

    meta = pd.DataFrame([
        ["phase1_datai", str(DATAI_P1)],
        ["phase2_datai", str(DATAI_P2)],
        ["phase1_cubeL", datai_p1["cubeL"]],
        ["phase2_cubeL", datai_p2["cubeL"]],
        ["phase1_XYZw", datai_p1["XYZw"][0].tolist()],
        ["phase2_XYZw", datai_p2["XYZw"][0].tolist()],
        ["wd65_scaled_p1", wd65_1.tolist()],
        ["wd65_scaled_p2", wd65_2.tolist()],
        ["n_points", len(rows)],
        ["elapsed_s", round(time.time() - t0, 1)],
    ], columns=["key", "value"])

    out = Path(args.out)
    with pd.ExcelWriter(out, engine="openpyxl") as xw:
        df.to_excel(xw, sheet_name="summary", index=False)
        meta.to_excel(xw, sheet_name="meta", index=False)
    print(f"[done] 已写出 -> {out}")
    print(f"[done] 总耗时 {time.time()-t0:.1f}s")


if __name__ == "__main__":
    main()
