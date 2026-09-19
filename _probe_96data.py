# -*- coding: utf-8 -*-
"""临时探查 VIVO_CS2000_96_x200_3_mode96*.mat 的数据结构"""
import scipy.io as sio
import numpy as np

f = r"D:\work\VIVOSkin_phase2\display\x200\VIVO_CS2000_96_x200_3_mode962026_08_06_11_30_07.mat"
d = sio.loadmat(f)
print("顶层字段:", [k for k in d if not k.startswith("__")])

DA = d["DATAs"]
print("DATAs shape:", DA.shape, "dtype:", DA.dtype)

# 第 0 行（要删掉的表头）
print("\n--- 第0行(表头) ---")
for c in range(4):
    v = DA[0, c]
    if isinstance(v, np.ndarray):
        print(f"col{c}: ndarray shape={v.shape} dtype={v.dtype} val={v.reshape(-1)[:8]}")
    else:
        print(f"col{c}: {type(v).__name__} = {v}")

# 第 1 行（第一个色块）
print("\n--- 第1行(第1个色块) ---")
for c in range(4):
    v = DA[1, c]
    if isinstance(v, np.ndarray):
        print(f"col{c}: ndarray shape={v.shape} dtype={v.dtype} val={v.reshape(-1)[:8]}")
    else:
        print(f"col{c}: {type(v).__name__} = {v}")

# 检查 SPD 列的长度
print("\n--- SPD 列长度分布 ---")
spd_lens = []
for r in range(1, DA.shape[0]):
    v = DA[r, 3]
    if isinstance(v, np.ndarray):
        spd_lens.append(v.size)
print("SPD sizes (unique):", sorted(set(spd_lens)), "总行数:", DA.shape[0] - 1)

# 收集 col0/col1/col2
col0 = [str(DA[r, 0][0]) for r in range(1, DA.shape[0])]
col1 = np.vstack([DA[r, 1].reshape(1, -1) for r in range(1, DA.shape[0])])
col2 = np.vstack([DA[r, 2].reshape(1, -1) for r in range(1, DA.shape[0])])
print("\ncol0 前3个:", col0[:3])
print("col1 shape:", col1.shape, "range:", col1.min(axis=0), "~", col1.max(axis=0))
print("col1 前5行:\n", col1[:5])
print("col2 shape:", col2.shape, "range:", col2.min(axis=0), "~", col2.max(axis=0))
print("col2 前5行:\n", col2[:5])
print("col1 vs col2 差(前3行):\n", np.abs(col1[:3] - col2[:3]))
