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
    """复刻 uniquetol('ByRows',true)：round 到 4 位后按行去重。

    返回 (unique_lab, group_first_lab, inverse)：
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
):
    """等价 MATLAB lut3d_xyz2rgbKDitp1(XYZ, datafile)。

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

    # ---- 2) uniquetol 复刻 ----
    unique_lab, _, inverse = _uniquetol_round(Lab, round_digits)

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
