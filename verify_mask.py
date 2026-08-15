# -*- coding: utf-8 -*-
"""verify_mask.py — 批次3 数值锚点：read_bull / get_average vs MATLAB 语义

锚点设计（对应 HANDOFF.md 第六节「逻辑索引 mask 一致」）:
  1) 彩色 bull 图: logicalIndex 全黑标记 + bull_weight 逐像素通道均值
     用手工构造的 2×2 彩色图逐值核对（含全黑、部分黑、灰、白）
  2) 灰度 bull 图: if_wei=True/False 两种分支，分别验证 reshape 顺序
  3) get_average 加权分支: sum(lab*bull_weight)/sum(bull_weight) 手工计算
  4) get_average 非加权分支: mean(lab[非黑像素]) 手工计算
  5) 真实图像冒烟测试: 用随机生成的"伪 bull"（模拟 0~255 uint8 含黑底人脸）
     验证 read_bull 输出形状 (H*W,), 类型 bool / float64
"""

import numpy as np

from mask import read_bull, get_average

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


def manual_bull_weight_color(img):
    """手动计算彩色图每像素通道均值（等价 MATLAB mean(bull_reshaped,2)）"""
    h, w, c = img.shape
    flat = img.reshape(h * w, c).astype(np.float64) / 255.0
    return np.mean(flat, axis=1)


# ---------------- 1) 彩色 bull: logicalIndex + bull_weight ----------------
print("=== 1) 彩色 bull read_bull ===")
# 2×2 彩色图: [全黑, 纯红(255,0,0), 灰(128,128,128), 白(255,255,255)]
color_bull = np.array([
    [[0, 0, 0], [255, 0, 0]],
    [[128, 128, 128], [255, 255, 255]],
], dtype=np.uint8)

logical, weight = read_bull(color_bull, if_wei=True)
check("logicalIndex[0]=True (全黑背景)", bool(logical[0]) is True)
check("logicalIndex[1]=False (纯红非黑)", bool(logical[1]) is False)
check("logicalIndex[2]=False (灰非黑)", bool(logical[2]) is False)
check("logicalIndex[3]=False (白非黑)", bool(logical[3]) is False)

exp_w = manual_bull_weight_color(color_bull)
check("bull_weight 逐像素通道均值一致", np.allclose(weight, exp_w, atol=1e-9))
check("bull_weight[0]=0 (全黑)", weight[0] == 0.0)
check("bull_weight[1]=1/3 (纯红)", np.isclose(weight[1], 1 / 3))
check("bull_weight[2]=128/255 (灰)", np.isclose(weight[2], 128 / 255))
check("bull_weight[3]=1 (白)", weight[3] == 1.0)

# ---------------- 2) 灰度 bull: if_wei 两种分支 ----------------
print("=== 2) 灰度 bull read_bull (if_wei 分支) ===")
gray_bull = np.array([
    [0, 0],
    [0, 255],
], dtype=np.uint8)  # 2×2

logical_g, weight_g = read_bull(gray_bull, if_wei=True)
check("灰度 if_wei=True logicalIndex 全黑标记", logical_g.tolist() == [True, True, True, False])
check("灰度 if_wei=True weight[3]=1 (255/255)", weight_g[3] == 1.0)

logical_g2, weight_g2 = read_bull(gray_bull, if_wei=False)
check("灰度 if_wei=False logicalIndex 全黑标记", logical_g2.tolist() == [True, True, True, False])
check("灰度 if_wei=False weight[3]=1", weight_g2[3] == 1.0)

# 两种分支数值应一致（同输入同输出，仅实现顺序不同）
check("if_wei True/False 结果一致", np.array_equal(logical_g, logical_g2)
      and np.allclose(weight_g, weight_g2, atol=1e-12))

# ---------------- 3) get_average 加权分支 ----------------
print("=== 3) get_average 加权 ===")
lab = np.array([
    [50.0, 10.0, 20.0],
    [60.0, 15.0, 25.0],
    [70.0, 20.0, 30.0],
    [80.0, 25.0, 35.0],
], dtype=np.float64)

_, w = read_bull(color_bull, if_wei=True)  # [0, 1/3, 128/255, 1]
avg_wei = get_average(lab, color_bull, if_wei=True)
exp_avg_wei = np.sum(lab * w[:, None], axis=0) / np.sum(w)
check("加权平均逐元素一致", np.allclose(avg_wei, exp_avg_wei, atol=1e-9))
# 手工计算: 全黑 weight=0 不参与
num = (lab[1] * (1 / 3)) + (lab[2] * (128 / 255)) + (lab[3] * 1.0)
den = (1 / 3) + (128 / 255) + 1.0
check("加权平均手工值一致", np.allclose(avg_wei, num / den, atol=1e-9))

# ---------------- 4) get_average 非加权分支 ----------------
print("=== 4) get_average 非加权 ===")
avg_nw = get_average(lab, color_bull, if_wei=False)
non_black = lab[1:, :]  # 首像素全黑被剔除
check("非加权均值 = 非黑像素均值", np.allclose(avg_nw, np.mean(non_black, axis=0), atol=1e-9))

# ---------------- 5) 真实形状冒烟测试 ----------------
print("=== 5) 冒烟测试: 真实尺寸伪 bull ===")
rng = np.random.default_rng(42)
h, w = 60, 80
# 模拟真实 bull: 黑底 + 随机非黑人脸区域
real_bull = np.zeros((h, w, 3), dtype=np.uint8)
face = rng.integers(40, 255, (30, 40, 3)).astype(np.uint8)
real_bull[15:45, 20:60, :] = face

logical_r, weight_r = read_bull(real_bull, if_wei=True)
check("real logicalIndex 形状 (H*W,)", logical_r.shape == (h * w,))
check("real bull_weight 形状 (H*W,)", weight_r.shape == (h * w,))
check("real logicalIndex dtype bool", logical_r.dtype == np.bool_)
check("real bull_weight dtype float64", weight_r.dtype == np.float64)
check("real 非黑像素数 = 30*40", np.sum(~logical_r) == 30 * 40)
check("real 全黑区域权重全 0", np.all(weight_r[logical_r] == 0.0))

# get_average 真实尺寸冒烟
lab_real = rng.uniform(20, 90, (h * w, 3))
avg_r = get_average(lab_real, real_bull, if_wei=True)
check("real 加权平均形状 (3,)", avg_r.shape == (3,))
check("real 加权平均无 NaN", not np.any(np.isnan(avg_r)))

print("\n" + "=" * 40)
print(f"结果: {PASS} PASS / {FAIL} FAIL")
if FAIL:
    raise SystemExit(1)
print("批次3 mask.py 锚点全部通过")
