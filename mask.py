# -*- coding: utf-8 -*-
r"""mask.py — 批次3：read_bull / get_average 1:1 还原 MATLAB

MATLAB 源:
    utils\read_bull.m   -> read_bull(bull, if_wei) -> [logicalIndex, bull_weight]
    utils\get_average.m -> get_average(lab, bull, if_wei) -> average

1:1 还原要点（见 HANDOFF.md 第七节坑清单）:
    - bull 输入为 uint8 图像（H×W×3 或 H×W）
    - logicalIndex: all(reshaped == 0, axis=1) —— 全黑像素为 True（背景）
    - bull_weight: mean(reshaped, axis=1)
    - if_wei=True:  先 double/255 再 reshape（彩色按像素展平成 N×3，灰度 N×1）
    - if_wei=False: 先 reshape 再 /255（注意 MATLAB 顺序：reshape()./255）
    - get_average 加权时: sum(lab*bull_weight)/sum(bull_weight)（逐列加权）
    - get_average 非加权时: mean(lab[~logicalIndex, :])（非黑像素均值）
"""

import numpy as np


def read_bull(bull, if_wei=True):
    """read_bull 1:1 还原。

    Args:
        bull: np.ndarray uint8，H×W×3（彩色）或 H×W（灰度）
        if_wei: bool，True 用权重模式（bull_weight 参与后续加权平均）

    Returns:
        logicalIndex: (N,) bool，N=H*W，全黑像素 True（背景）
        bull_weight:  (N,) float，每像素通道均值（0~1 权重）
    """
    bull = np.asarray(bull)
    sz = bull.shape

    if if_wei:
        # MATLAB: double(bull)./255 再 reshape
        bull_float = bull.astype(np.float64) / 255.0
        if bull_float.ndim == 3:
            bull_reshaped = bull_float.reshape(sz[0] * sz[1], sz[2])
        else:  # ndim == 2
            bull_reshaped = bull_float.reshape(sz[0] * sz[1], 1)
    else:
        # MATLAB: 先 reshape 再 ./255（顺序与 if_wei 分支不同，需保留）
        if bull.ndim == 3:
            bull_reshaped = bull.reshape(sz[0] * sz[1], sz[2]) / 255.0
        else:  # ndim == 2
            bull_reshaped = bull.reshape(sz[0] * sz[1], 1) / 255.0
        bull_reshaped = bull_reshaped.astype(np.float64)

    # MATLAB: all(bull_reshaped == 0, 2)
    logicalIndex = np.all(bull_reshaped == 0.0, axis=1)
    # MATLAB: mean(bull_reshaped, 2)
    bull_weight = np.mean(bull_reshaped, axis=1)

    return logicalIndex, bull_weight


def get_average(lab, bull, if_wei=True):
    """get_average 1:1 还原。

    Args:
        lab: (N, 3) float，CIELAB（N = H*W，像素按行优先展平）
        bull: np.ndarray uint8，H×W×3 或 H×W，与 lab 同尺寸
        if_wei: bool，True 加权平均，False 非黑像素均值

    Returns:
        average: (3,) float 平均 Lab
    """
    lab = np.asarray(lab, dtype=np.float64)
    logicalIndex, bull_weight = read_bull(bull, if_wei)

    if if_wei:
        # MATLAB: sum(lab.*bull_weight)./sum(bull_weight)
        # 注意 lab (N,3) 与 bull_weight (N,1) 广播，MATLAB 逐列加权
        average = np.sum(lab * bull_weight[:, None], axis=0) / np.sum(bull_weight)
    else:
        # MATLAB: mean(lab(~logicalIndex, :))
        average = np.mean(lab[~logicalIndex, :], axis=0)

    return average
