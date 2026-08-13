"""data_io.py — 批次 0：数据加载层，1:1 对齐 MATLAB 读取语义。

MATLAB 原文对照：
- load(file)                         -> load_mat / 各专用 load_* 函数
- imread(filename)                   -> imread()     返回 uint8
- im2double(img0)                    -> im2double()  uint8 -> /255 的 float64
- readmatrix('points_added_33.xlsx') -> load_points()

实测结论（2026-08-13 探查，所有 .mat 均为纯数值矩阵，无嵌套 struct）：
- data_ipv30_phase2_3.mat : P_labs(27000,3), rgb(27000,3), XYZw(1,3), cubeL(1,1), cubeL_ext(1,1)
- data_ipv35_3.mat        : P_labs(42875,3), rgb(42875,3), XYZw(1,3), cubeL(1,1), cubeL_ext(1,1)
- datai_ipv18_3.mat       : XYZw(1,3)（正向 LUT，主链路只用 XYZw）
- {type}C_L_para.mat      : a_CL(1,2)
- aveLab_D65_{type}.mat   : labC_HD65(1,4)
- XYZ 文件 H3K.mat 等     : XYZ_cropped(2186,1640,3), XYZw(1,3)
- points_added_33.xlsx    : 33x2 -> load_points 前置零列 -> 33x3 [0, da, db]
"""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict

import numpy as np
import pandas as pd
import scipy.io as sio
from PIL import Image


# ---------------------------------------------------------------------------
# 通用 .mat
# ---------------------------------------------------------------------------
def load_mat(path: str | Path) -> Dict[str, Any]:
    """等价 MATLAB `load(file)`：返回字段 dict，跳过 __header__/__version__/__globals__。

    本项目所有 .mat 均为纯数值矩阵（非 struct/cell），scipy 直接返回 ndarray，
    无需做 0-d struct 拆包。含 `__function_workspace__` 等 MATLAB 内部字段也会被跳过。
    """
    raw = sio.loadmat(str(path), squeeze_me=False, struct_as_record=True)
    return {k: v for k, v in raw.items() if not k.startswith("__")}


def _f64(a: Any) -> np.ndarray:
    """确保 float64（对齐 MATLAB double）。"""
    return np.asarray(a, dtype=np.float64)


# ---------------------------------------------------------------------------
# LUT / 参数文件
# ---------------------------------------------------------------------------
def load_lut(path: str | Path) -> Dict[str, np.ndarray]:
    """逆向 LUT：data_ipv30_phase2_3.mat / data_ipv35_3.mat。

    返回 {P_labs(N,3), rgb(N,3), XYZw(1,3), cubeL(1,1), cubeL_ext(1,1)}，全 float64。
    """
    d = load_mat(path)
    return {
        "P_labs": _f64(d["P_labs"]),
        "rgb": _f64(d["rgb"]),
        "XYZw": _f64(d["XYZw"]),
        "cubeL": _f64(d["cubeL"]),
        "cubeL_ext": _f64(d["cubeL_ext"]),
    }


def load_forward_lut(path: str | Path) -> Dict[str, np.ndarray]:
    """正向 LUT：datai_ipv18_3.mat，主链路只用 XYZw(1,3)。"""
    return {"XYZw": _f64(load_mat(path)["XYZw"])}


def load_c_lpara(path: str | Path) -> np.ndarray:
    """aveSkinByHand2/i/C_Lpara/{type}C_L_para.mat -> a_CL(1,2)。"""
    return _f64(load_mat(path)["a_CL"])


def load_avelab(path: str | Path) -> np.ndarray:
    """documents/aveSkin/i/aveLab_D65_{type}.mat -> labC_HD65(1,4)。"""
    return _f64(load_mat(path)["labC_HD65"])


def load_xyz(path: str | Path) -> Dict[str, np.ndarray]:
    """original_image_XYZ/{sub}/*.mat -> {XYZ_cropped(H,W,3), XYZw(1,3)}。"""
    d = load_mat(path)
    return {"XYZ_cropped": _f64(d["XYZ_cropped"]), "XYZw": _f64(d["XYZw"])}


def load_points(path: str | Path) -> np.ndarray:
    """points_added_33.xlsx -> 33x3 [0, da, db]。

    对齐 MATLAB：`num_points = readmatrix(...); num_points = [zeros(n,1), num_points]`。
    """
    a = pd.read_excel(path, header=None).to_numpy(dtype=np.float64)  # (33,2)
    return np.hstack([np.zeros((a.shape[0], 1)), a])  # (33,3)


# ---------------------------------------------------------------------------
# 图像
# ---------------------------------------------------------------------------
def imread(path: str | Path) -> np.ndarray:
    """等价 MATLAB `imread`：返回 uint8。

    - 灰度 jpg（mode 'L'）-> (H, W)
    - 彩色 jpg（mode 'RGB'）-> (H, W, 3)
    """
    im = Image.open(path)
    if im.mode == "L":
        return np.asarray(im)                      # uint8 (H,W)
    return np.asarray(im.convert("RGB"))           # uint8 (H,W,3)


def im2double(a: Any) -> np.ndarray:
    """等价 MATLAB `im2double`：uint8 -> /255 的 float64；已为 float 则原样转 float64。"""
    a = np.asarray(a)
    if a.dtype == np.uint8:
        return a.astype(np.float64) / 255.0
    return a.astype(np.float64)
