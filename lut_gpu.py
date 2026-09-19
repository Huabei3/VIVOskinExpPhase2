# -*- coding: utf-8 -*-
r"""lut_gpu.py — 批次4：lut3d_xyz2rgbKDitp1 GPU 向量化版（核心瓶颈）

MATLAB 源: utils\lut3d_xyz2rgbKDitp1.m

1:1 语义要点:
  1) Lab = xyz2lab(XYZ, 'user', XYZw1)
  2) uniquetol(Lab, 0.01/max(max(Lab)), 'ByRows', true) 按行去重
     -> 复刻（refrastructure.md 第三节拍板）: np.unique(round(Lab,4),
        return_index=True, return_inverse=True)，组内共享组首行 KNN 结果
  3) 每唯一行 knnsearch(K=8)：距离倒数权重 -> 归一化 -> 加权平均 rgb
  4) broadcast 回组内像素: RGB = RGB_unique[inverse]
  5) out_of_gamut_ratio 在 clip 前算（NaN 比较 false，不计入）
  6) fillmissing 'nearest' 逐列填充 NaN/Inf
  7) clip：RGB<0|isnan|isinf -> 0；RGB>255 -> 255（保留 MATLAB 顺序）

GPU: torch.cdist + topk(8, largest=False)，分块控制显存。
注意：MATLAB 全程 double，GPU 也用 float64 保证逐像素一致。
"""

from typing import Dict, Optional

import numpy as np
import torch

from color_utils import xyz2lab
from data_io import load_lut


def _fillmissing_nearest_1d(x: np.ndarray) -> np.ndarray:
    """等价 MATLAB fillmissing(x, 'nearest')：用最近的非缺失值填充 NaN/Inf。"""
    mask = np.isnan(x) | np.isinf(x)
    if not mask.any():
        return x
    x = x.copy()
    valid_idx = np.flatnonzero(~mask)
    if valid_idx.size == 0:
        return x  # 全列缺失：MATLAB 报错，clip 阶段最终置 0
    miss_idx = np.flatnonzero(mask)
    nearest = valid_idx[np.argmin(np.abs(valid_idx[:, None] - miss_idx), axis=0)]
    x[miss_idx] = x[nearest]
    return x


def _clip_matlab(RGB: np.ndarray) -> np.ndarray:
    """按 MATLAB 原始 clip 顺序执行。"""
    RGB = RGB.copy()
    RGB[(RGB < 0) | np.isnan(RGB) | np.isinf(RGB)] = 0
    RGB[(RGB >= 0) & np.isinf(RGB)] = 255
    RGB[(RGB <= 0) & np.isinf(RGB)] = 0
    RGB[RGB > 255] = 255
    return RGB


def _uniquetol_round(Lab: np.ndarray, round_digits: int = 4):
    """【fast 语义】round 到固定小数位后按行去重（加速改造版，非 MATLAB 原语义）。

    返回 (unique_lab, first_idx, inverse)：
      unique_lab: (U,3) 唯一行的原始 Lab 值
      first_idx:  (U,) 每组在原始 Lab 中第一个出现的索引
      inverse:    (M,) 每个像素所属组号
    """
    rounded = np.round(Lab, round_digits)
    _, first_idx, inverse = np.unique(
        rounded, axis=0, return_index=True, return_inverse=True
    )
    unique_lab = Lab[first_idx]  # 组首行的原始 Lab（非 round 值）
    return unique_lab, first_idx, inverse


def _uniquetol_matlab(Lab: np.ndarray):
    """【matlab 语义】1:1 复刻 MATLAB
    `uniquetol(Lab, 0.01/max(max(Lab)), 'ByRows', true, 'OutputAllIndices', true)`。

    MATLAB uniquetol 真实语义（R2024a 实测确认）：
      1) DataScale 默认 = max(abs(Lab), [], 1)，**按列**取最大绝对值（每列一个 scale）。
         实测 Lab=[60 10 0; 60 10.005 0; 60 0 0] 三行全分开：
         a 通道容差 = 0.01*10.005/60 ≈ 0.00167 < 0.005，证明不是全局标量。
      2) 实际容差 = tol * DataScale（逐元素），判断 = all(abs(row-anchor) <= 实际容差)。
      3) 分组算法 = **排序贪心**（先按行字典序排序，anchor=当前组最小值）：
         实测 Lab=[100.006 0 0; 100.000 0 0; 100.011 0 0] 分出 2 组
         {100.000,100.006} 与 {100.011}；而"顺序贪心"会链式合并成 1 组（错误）。
      4) 组代表行 = 组内**原始顺序第一个**（= MATLAB 代码 Lab(idx(1),:)，idx=IA{i}）。

    返回 (unique_lab, first_idx, inverse)：
      unique_lab: (U,3) 每组代表行的原始 Lab 值（= 组内原始顺序首行）
      first_idx:  (U,) 每组在原始 Lab 中第一个出现的索引
      inverse:    (M,) 每个像素所属组号
    """
    # DataScale = 按列 max(abs)，等价 MATLAB max(abs(Lab), [], 1)
    data_scale = np.max(np.abs(Lab), axis=0)  # (3,)
    tol_scalar = 0.01 / float(np.max(np.abs(Lab)))  # 0.01/max(max(Lab))
    actual_tol = tol_scalar * data_scale  # (3,) 逐元素容差

    M = Lab.shape[0]

    # 1) 按行字典序排序（先 L 再 a 再 b），等价 MATLAB sortrows
    order = np.lexsort((Lab[:, 2], Lab[:, 1], Lab[:, 0]))
    sorted_Lab = Lab[order]

    # 2) 排序贪心聚类：anchor = 当前组最小值（排序后第一个），只与 anchor 比较
    group_of_sorted = np.empty(M, dtype=np.int64)
    n_groups = 0
    anchor = None
    for i in range(M):
        row = sorted_Lab[i]
        if i == 0 or not np.all(np.abs(row - anchor) <= actual_tol):
            anchor = row
            n_groups += 1
        group_of_sorted[i] = n_groups - 1

    # 3) 映射回原始顺序
    inverse = np.empty(M, dtype=np.int64)
    inverse[order] = group_of_sorted

    # 4) 每组原始顺序第一个索引（= MATLAB IA{i}(1)）
    first_idx = np.full(n_groups, M, dtype=np.int64)
    np.minimum.at(first_idx, inverse, np.arange(M, dtype=np.int64))

    unique_lab = Lab[first_idx]
    return unique_lab, first_idx, inverse


def _knn_weighted_block(unique_lab_t: torch.Tensor, P_labs_t: torch.Tensor,
                        rgb_lut_t: torch.Tensor, chunk: int) -> torch.Tensor:
    """分块 cdist + topk(8) + 距离倒数加权，返回 (U,3) RGB_unique。"""
    U = unique_lab_t.shape[0]
    out = torch.empty((U, 3), dtype=torch.float64, device=unique_lab_t.device)
    for s in range(0, U, chunk):
        e = min(s + chunk, U)
        block = unique_lab_t[s:e]                      # (b,3)
        dist = torch.cdist(block, P_labs_t)            # (b,N) float64
        d, idx = dist.topk(8, dim=1, largest=False)    # (b,8)
        w = 1.0 / d                                   # 距离倒数（0 距 -> inf）
        w = w / w.sum(dim=1, keepdim=True)            # 归一化（inf/inf -> NaN，同 MATLAB）
        rgb_neigh = rgb_lut_t[idx]                    # (b,8,3)
        out[s:e] = (w.unsqueeze(-1) * rgb_neigh).sum(dim=1)
    return out


def lut3d_xyz2rgbKDitp1(
    XYZ: np.ndarray,
    datafile: Optional[str] = None,
    lut: Optional[Dict[str, np.ndarray]] = None,
    device: str = "auto",
    chunk: int = 8192,
    round_digits: int = 4,
    dedup_mode: str = "fast",
):
    """等价 MATLAB lut3d_xyz2rgbKDitp1(XYZ, datafile)。

    Args:
        dedup_mode: 去重语义开关
            "matlab" -> 1:1 复刻 MATLAB `uniquetol(Lab, 0.01/max(max(Lab)), 'ByRows', true)`
                        （无穷范数容差贪心聚类，追求逐像素一致，较慢）
            "fast"   -> round 到 round_digits 位小数后 np.unique（加速改造语义，默认）
            "none"   -> 不去重：逐行独立 KNN(K=8)，等价 MATLAB lut3d_xyz2rgbNoParitp_noUni

    Returns: (RGB (M,3) float64, out_of_gamut_ratio float)
    """
    if lut is None:
        if datafile is None:
            raise ValueError("lut3d_xyz2rgbKDitp1: 需要 datafile 或 lut 之一")
        lut = load_lut(datafile)

    P_labs = np.asarray(lut["P_labs"], dtype=np.float64)   # (N,3)
    rgb_lut = np.asarray(lut["rgb"], dtype=np.float64)     # (N,3)
    XYZw = np.asarray(lut["XYZw"], dtype=np.float64)       # (1,3)

    XYZ = np.asarray(XYZ, dtype=np.float64)
    if XYZ.ndim == 1:
        XYZ = XYZ.reshape(1, 3)

    # ---- 1) XYZ -> Lab ----
    Lab = xyz2lab(XYZ, "user", XYZw)                       # (M,3) float64

    # ---- 2) 去重（matlab 语义 / fast 语义 / none 不去重，见 dedup_mode）----
    if dedup_mode == "matlab":
        unique_lab, _, inverse = _uniquetol_matlab(Lab)
    elif dedup_mode == "fast":
        unique_lab, _, inverse = _uniquetol_round(Lab, round_digits)
    elif dedup_mode == "none":
        # 不去重：每一行都独立做 KNN(K=8)，等价 MATLAB lut3d_xyz2rgbNoParitp_noUni
        unique_lab = Lab
        inverse = np.arange(Lab.shape[0], dtype=np.int64)
    else:
        raise ValueError(f"lut3d_xyz2rgbKDitp1: unknown dedup_mode '{dedup_mode}'")

    # ---- 3) GPU KNN + 加权 ----
    if device == "auto":
        device = "cuda" if torch.cuda.is_available() else "cpu"
    # CPU 内存自适应：cdist 分块 b x N x 8B，b=8192、N=27000 时 ~1.8GB 会爆，
    # 本机无 CUDA（锚点验证走 CPU），自动降 chunk 保证可跑。
    if device.startswith("cpu") and chunk > 512:
        chunk = 512
    dev = torch.device(device)
    u_t = torch.from_numpy(unique_lab).to(dev)
    p_t = torch.from_numpy(P_labs).to(dev)
    r_t = torch.from_numpy(rgb_lut).to(dev)
    RGB_unique_t = _knn_weighted_block(u_t, p_t, r_t, chunk)   # (U,3)
    RGB_unique = RGB_unique_t.cpu().numpy()

    # ---- 4) broadcast 回所有像素 ----
    RGB = RGB_unique[inverse]                                  # (M,3)

    # ---- 5) out_of_gamut_ratio（clip 前，MATLAB 语义）----
    out_of_gamut = int(np.sum(np.any((RGB < 0) | (RGB > 255), axis=1)))
    out_of_gamut_ratio = out_of_gamut / RGB.shape[0]

    # ---- 6) fillmissing nearest（逐列）----
    for c in range(3):
        RGB[:, c] = _fillmissing_nearest_1d(RGB[:, c])

    # ---- 7) clip ----
    RGB = _clip_matlab(RGB)

    return RGB, out_of_gamut_ratio


if __name__ == "__main__":
    # 快速冒烟：合成小 LUT（无真实数据也可运行）
    from verify_lut_gpu import make_synthetic_lut, run_smoke
    run_smoke()
