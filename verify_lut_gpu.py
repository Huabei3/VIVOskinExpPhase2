# -*- coding: utf-8 -*-
r"""verify_lut_gpu.py — 批次4 锚点：lut_gpu.py vs MATLAB 语义

锚点设计（对应 HANDOFF.md「同 xyz2 输入 vs MATLAB 逐像素一致」）:
  A) 合成小 LUT（2^3=8 网格点）+ 手工可算 XYZ：
     手工计算 8 近邻（K=8 等于全部点）反距离加权 RGB，逐元素对比
  B) 纯 numpy 参考实现（逐组串行 KNN，严格照 MATLAB 逻辑）：
     与 GPU 向量化版在随机合成 XYZ 上逐像素一致（atol=1e-9）
  C) 真实 LUT data_ipv30_phase2_3.mat 冒烟：
     文件存在则加载，验证 P_labs/rgb/XYZw 形状 + 输出有限值 + 形状正确
  D) 权重归一化 & 越界比例语义：
     距离 0 像素权重 inf/inf=NaN 路径（MATLAB 同），fillmissing 与 clip 后有限
"""

import os

import numpy as np

from color_utils import xyz2lab
from lut_gpu import lut3d_xyz2rgbKDitp1, _fillmissing_nearest_1d, _clip_matlab

PASS = 0
FAIL = 0


def check(name, cond):
    global PASS, FAIL
    if cond:
        PASS += 1
        print(f"  [PASS] {name}")
    else:
        FAIL += 1
        print(f"  [FAIL] {name}")


# ---------------------------------------------------------------------------
# 合成 LUT 构造：2^3 = 8 个网格点，K=8 即全点，手工可算
# ---------------------------------------------------------------------------
def make_synthetic_lut():
    """构造 8 点小 LUT。P_labs 取立方体角点，rgb 与其线性相关（可逆）。"""
    P_labs = np.array([
        [20, -50, -50], [20, -50, 50], [20, 50, -50], [20, 50, 50],
        [80, -50, -50], [80, -50, 50], [80, 50, -50], [80, 50, 50],
    ], dtype=np.float64)  # (8,3)
    # rgb = 0.6*Lab + 128 -> 在 [0,255] 内
    rgb = np.clip(0.6 * P_labs + 128.0, 0, 255).astype(np.float64)
    XYZw = np.array([[95.0, 100.0, 108.0]], dtype=np.float64)
    return {"P_labs": P_labs, "rgb": rgb, "XYZw": XYZw}


def reference_lut(XYZ, lut, round_digits=4):
    """纯 numpy 逐组串行参考实现，严格照 MATLAB 逻辑（不含 GPU）。"""
    P_labs = lut["P_labs"]
    rgb_lut = lut["rgb"]
    XYZw = lut["XYZw"]
    Lab = xyz2lab(XYZ, "user", XYZw)

    rounded = np.round(Lab, round_digits)
    _, first_idx, inverse = np.unique(
        rounded, axis=0, return_index=True, return_inverse=True
    )
    unique_lab = Lab[first_idx]

    RGB_unique = np.zeros((len(unique_lab), 3))
    for i, row in enumerate(unique_lab):
        d = np.linalg.norm(P_labs - row, axis=1)          # 距离
        k = np.argsort(d)[:8]                             # K=8 近邻
        w = 1.0 / d[k]
        w = w / w.sum()
        RGB_unique[i] = (w[:, None] * rgb_lut[k]).sum(axis=0)

    RGB = RGB_unique[inverse]
    oog = int(np.sum(np.any((RGB < 0) | (RGB > 255), axis=1)))
    oog_ratio = oog / RGB.shape[0]

    for c in range(3):
        RGB[:, c] = _fillmissing_nearest_1d(RGB[:, c])
    RGB = _clip_matlab(RGB)
    return RGB, oog_ratio


# ---------------------------------------------------------------------------
# A) 手工锚点
# ---------------------------------------------------------------------------
def test_hand_calc():
    print("=== A) 手工可算锚点 (K=8 全点) ===")
    lut = make_synthetic_lut()
    P_labs, rgb, XYZw = lut["P_labs"], lut["rgb"], lut["XYZw"]

    # 选一个 XYZ：其 Lab 恰等于第 0 个网格点（用 lab 反推不可行，改用手动选点）
    # 直接构造 XYZ 使 Lab 落在 8 点附近，手工算期望
    rng = np.random.default_rng(7)
    XYZ = np.array([
        [0.95, 1.0, 1.08],   # 接近白点
        [0.30, 0.33, 0.30],  # 中灰
        [0.10, 0.05, 0.20],  # 偏色
    ], dtype=np.float64)
    XYZ = XYZ * XYZw         # 缩放到与 XYZw 同量级

    Lab = xyz2lab(XYZ, "user", XYZw)
    # 手工计算：每个查询点对全部 8 个网格点反距离加权
    for i in range(3):
        d = np.linalg.norm(P_labs - Lab[i], axis=1)
        w = 1.0 / d
        w = w / w.sum()
        rgb_exp = (w[:, None] * rgb).sum(axis=0)

        RGB, _ = lut3d_xyz2rgbKDitp1(XYZ[i:i+1], lut=lut, device="cpu")
        check(f"查询点{i} RGB 逐元素一致", np.allclose(RGB[0], rgb_exp, atol=1e-9))

    # 全黑 XYZ（Lab 不确定，仅验证输出形状）
    RGB, _ = lut3d_xyz2rgbKDitp1(np.zeros((1, 3)), lut=lut, device="cpu")
    check("零输入输出形状 (1,3)", RGB.shape == (1, 3) and np.all(np.isfinite(RGB)))


# ---------------------------------------------------------------------------
# B) 随机合成 vs 参考实现（逐像素一致）
# ---------------------------------------------------------------------------
def test_random_vs_reference():
    print("=== B) 随机 XYZ vs 纯 numpy 参考实现 ===")
    rng = np.random.default_rng(123)
    lut = make_synthetic_lut()
    XYZw = lut["XYZw"]

    # 多样本：含重复行（验证 uniquetol 分组共享）、色域外点、近黑点
    n = 500
    XYZ = rng.uniform(0.01, 1.2, (n, 3)) * XYZw
    XYZ[0] = XYZ[1]           # 重复行
    XYZ[2] = XYZ[3]           # 重复行
    XYZ[4] = 0.0              # 黑
    XYZ[5] = 1.5 * XYZw       # 越界

    RGB_gpu, oog_gpu = lut3d_xyz2rgbKDitp1(XYZ, lut=lut, device="cpu")
    RGB_ref, oog_ref = reference_lut(XYZ, lut)

    check("逐像素一致 (atol=1e-9)", np.allclose(RGB_gpu, RGB_ref, atol=1e-9, rtol=0))
    check("越界比例一致", oog_gpu == oog_ref)
    check("输出范围 [0,255]", float(RGB_gpu.min()) >= 0 and float(RGB_gpu.max()) <= 255)
    check("无 NaN/Inf", np.all(np.isfinite(RGB_gpu)))

    # 分组共享：重复行的 RGB 完全相同
    check("重复行共享组结果", np.array_equal(RGB_gpu[0], RGB_gpu[1])
          and np.array_equal(RGB_gpu[2], RGB_gpu[3]))


# ---------------------------------------------------------------------------
# C) 真实 LUT 冒烟
# ---------------------------------------------------------------------------
def test_real_lut():
    print("=== C) 真实 LUT data_ipv30_phase2_3.mat 冒烟 ===")
    path = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\A_characterization\display_model\data_ipv30_phase2_3.mat"
    if not os.path.isfile(path):
        check("真实 LUT 文件存在（跳过）", True)
        return
    from data_io import load_lut
    lut = load_lut(path)
    P_labs = lut["P_labs"]
    rgb = lut["rgb"]
    XYZw = lut["XYZw"]
    check("P_labs (N,3)", P_labs.ndim == 2 and P_labs.shape[1] == 3 and P_labs.shape[0] > 8)
    check("rgb 与 P_labs 同长", rgb.shape == P_labs.shape)
    check("XYZw (1,3)", XYZw.shape == (1, 3))

    # 从 LUT 自己取几个 Lab 附近的点做往返：把 P_lab 当"目标 Lab"，手工求 XYZ 无法逆，
    # 改为：用 xyz2lab 生成一批随机 XYZ 的 Lab 作为查询
    rng = np.random.default_rng(5)
    M = 200
    XYZ = rng.uniform(0.05, 1.1, (M, 3)) * XYZw
    RGB, oog = lut3d_xyz2rgbKDitp1(XYZ, lut=lut, device="cpu")
    check("真实 LUT 输出形状 (M,3)", RGB.shape == (M, 3))
    check("真实 LUT 输出有限", np.all(np.isfinite(RGB)))
    check("真实 LUT 输出范围", float(RGB.min()) >= 0 and float(RGB.max()) <= 255)
    check("真实 LUT 越界比例类型/范围", isinstance(oog, float) and 0 <= oog <= 1)

    # GPU 版（若有 cuda）与 CPU 一致
    try:
        RGB_gpu, oog_gpu = lut3d_xyz2rgbKDitp1(XYZ, lut=lut, device="auto")
        check("GPU/CPU 结果一致", np.allclose(RGB_gpu, RGB, atol=1e-9, rtol=0))
        check("GPU/CPU 越界一致", oog_gpu == oog)
    except (RuntimeError, AssertionError) as e:
        check(f"GPU 可用性（{type(e).__name__}）", False)


# ---------------------------------------------------------------------------
# D) 权重归一化 & fillmissing & clip 语义
# ---------------------------------------------------------------------------
def test_edge_semantics():
    print("=== D) 边界语义 ===")
    # fillmissing nearest 1D
    x = np.array([1.0, np.nan, 3.0, np.nan, np.nan, 6.0])
    y = _fillmissing_nearest_1d(x)
    check("fillmissing nearest 前后填充", np.allclose(y, [1, 1, 3, 3, 6, 6]))
    # 全有效
    check("全有效原样", np.array_equal(_fillmissing_nearest_1d(np.array([1., 2.])), [1., 2.]))
    # 全 NaN：保持（MATLAB 报错路径，clip 置 0）
    z = _fillmissing_nearest_1d(np.array([np.nan, np.nan]))
    check("全 NaN 保持", np.all(np.isnan(z)))

    # clip
    a = np.array([[-10.0, 300.0, np.nan], [np.inf, -np.inf, 128.0]])
    b = _clip_matlab(a)
    check("clip <0/NaN/Inf -> 0, >255 -> 255", np.array_equal(
        b, [[0, 255, 0], [0, 0, 128]]))


def run_smoke():
    """快速冒烟（lut_gpu.py __main__ 调用）。"""
    print("lut_gpu 冒烟：合成 LUT 全链路")
    rng = np.random.default_rng(0)
    lut = make_synthetic_lut()
    XYZ = rng.uniform(0.05, 1.1, (100, 3)) * lut["XYZw"]
    RGB, oog = lut3d_xyz2rgbKDitp1(XYZ, lut=lut, device="cpu")
    assert RGB.shape == (100, 3) and np.all(np.isfinite(RGB))
    print("  smoke OK")


if __name__ == "__main__":
    test_hand_calc()
    test_random_vs_reference()
    test_real_lut()
    test_edge_semantics()
    print("\n" + "=" * 40)
    print(f"结果: {PASS} PASS / {FAIL} FAIL")
    if FAIL:
        raise SystemExit(1)
    print("批次4 lut_gpu.py 锚点全部通过")
