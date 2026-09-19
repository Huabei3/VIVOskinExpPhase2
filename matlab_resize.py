# -*- coding: utf-8 -*-
"""精确复现 MATLAB imresize(A, [outH outW]) —— bicubic(Keys a=-0.5) + 抗锯齿。

逐行照抄 MATLAB R2024a 源码：
- toolbox/matlab/images/imresize.m
- +matlab/+images/+internal/+resize/contributions.m
- +matlab/+images/+internal/+resize/cubic.m
- +matlab/+images/+internal/+resize/dimensionOrder.m
- +matlab/+images/+internal/+resize/deriveScaleFromSize.m
"""
import numpy as np


def cubic(x):
    """Keys cubic convolution kernel, a=-0.5 (cubic.m)。

    f = (1.5|x|^3 - 2.5|x|^2 + 1) * (|x|<=1)
      + (-0.5|x|^3 + 2.5|x|^2 - 4|x| + 2) * (1<|x|<=2)
    """
    x = np.asarray(x, dtype=np.float64)
    absx = np.abs(x)
    absx2 = absx ** 2
    absx3 = absx ** 3
    f = (1.5 * absx3 - 2.5 * absx2 + 1.0) * (absx <= 1.0) + \
        (-0.5 * absx3 + 2.5 * absx2 - 4.0 * absx + 2.0) * \
        ((1.0 < absx) & (absx <= 2.0))
    return f


def contributions(in_length, out_length, scale, kernel_width=4.0):
    """复现 contributions.m，返回 (weights, indices)，均 0-based。

    weights[k, :] / indices[k, :] 对应第 k 个输出像素（k 从 0 计）。
    """
    scale = float(scale)
    assert 0.0 < scale < 1.0, "本复现只覆盖缩小(scale<1)且抗锯齿的场景"

    # ---- 抗锯齿：修正核 + 加宽核宽 (contributions.m L10-18) ----
    kernel_width = kernel_width / scale

    # ---- 输出空间坐标 x = 1..out_length (1-based) ----
    x = np.arange(1, out_length + 1, dtype=np.float64)

    # ---- 输入空间坐标 (contributions.m L26) ----
    u = x / scale + 0.5 * (1.0 - 1.0 / scale)

    # ---- 左端像素 (L29) ----
    left = np.floor(u - kernel_width / 2.0)

    # ---- 参与像素数 P = ceil(kernel_width) + 2 (L35) ----
    P = int(np.ceil(kernel_width)) + 2

    # ---- indices (1-based) (L39) ----
    idx = left[:, None] + np.arange(P, dtype=np.float64)[None, :]

    # ---- weights = h(u - idx) = scale*cubic(scale*(u-idx)) (L43) ----
    d = u[:, None] - idx
    w = scale * cubic(scale * d)

    # ---- 行归一化到 1 (L46) ----
    w = w / w.sum(axis=1, keepdims=True)

    # ---- whole-sample 对称镜像 (L48-50) ----
    aux = np.concatenate([
        np.arange(1, in_length + 1, dtype=np.float64),
        np.arange(in_length, 0, -1, dtype=np.float64),
    ])  # 长度 2*in_length
    idx = aux[np.mod(idx - 1.0, 2.0 * in_length).astype(np.int64)]

    # ---- 删除全零列 (L52-57) ----
    keep = np.any(w != 0.0, axis=0)
    w = w[:, keep]
    idx = idx[:, keep]

    # ---- 转 0-based ----
    idx = idx.astype(np.int64) - 1
    return w, idx


def resize_along_dim(arr, dim, weights, indices):
    """复现 resizeAlongDim 的加权求和（dim: 0=行, 1=列）。"""
    # 把目标维度移到最后一维，方便 gather
    arr_moved = np.moveaxis(arr, dim, -1)
    gathered = arr_moved[..., indices]          # (..., out_len, P)
    out = np.einsum('...kp,kp->...k', gathered, weights)
    out = np.moveaxis(out, -1, dim)
    return out


def imresize_matlab(A, output_size):
    """复现 MATLAB imresize(A, [outH outW])，bicubic + 抗锯齿（默认）。

    A: np.ndarray, float64 / uint8 / float32, shape (H,W) 或 (H,W,C)
    返回与输入同 dtype。
    """
    A = np.asarray(A)
    in_h, in_w = A.shape[0], A.shape[1]
    out_h = int(output_size[0])
    out_w = int(output_size[1])

    # deriveScaleFromSize.m: scale = output_size ./ size(A)
    scale = np.array([out_h / in_h, out_w / in_w], dtype=np.float64)

    # dimensionOrder.m: scale 小的维度先 resize
    order = np.argsort(scale)

    was_uint8 = A.dtype == np.uint8
    work = A.astype(np.float64)

    weights, indices = {}, {}
    for dim in (0, 1):
        in_len = work.shape[dim]
        out_len = out_h if dim == 0 else out_w
        w, idx = contributions(in_len, out_len, scale[dim])
        weights[dim] = w
        indices[dim] = idx

    B = work
    for dim in order:
        B = resize_along_dim(B, dim, weights[dim], indices[dim])
        if was_uint8:
            # MATLAB uint8 路径：imresizemex 每步返回 uint8，即 round + clip 到 [0,255]。
            # 关键：bicubic 的负 overshoot 在每步末尾被 clip 到 0，
            # 下一步再用这个 0 参与加权（double 路径则保留负数），这是两者差异的根源。
            B = np.clip(np.round(B), 0.0, 255.0)

    if was_uint8:
        B = B.astype(np.uint8)
    else:
        B = B.astype(A.dtype)
    return B
