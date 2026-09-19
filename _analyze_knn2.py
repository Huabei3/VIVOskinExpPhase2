# -*- coding: utf-8 -*-
"""对比 torch.topk vs scipy.cKDTree 对 3 个色块的 KNN 邻居选择差异"""
import scipy.io as sio
import numpy as np
from scipy.spatial import cKDTree
from color_utils import xyz2lab

P_DIR = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python"
LUT = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\A_characterization\display_model\data_ipv30_phase2_3.mat"

xyz = sio.loadmat(P_DIR + r"\test96_XYZ10.mat")["XYZ10"]
lut = sio.loadmat(LUT)
XYZw = lut["XYZw"]
P_labs = lut["P_labs"]
rgb = lut["rgb"]

Lab = xyz2lab(xyz, "user", XYZw)

# torch 方式：cdist + topk（lut_gpu.py 的实现）
# 这里用 numpy 等价：full distance + argsort
def knn_topk(q, k=8):
    d = np.linalg.norm(P_labs - q, axis=1)
    idx = np.argsort(d)[:k]
    return idx, d[idx]

# scipy KD-tree（等价 MATLAB knnsearch KDTreeSearcher）
tree = cKDTree(P_labs)

for i in [18, 36, 54]:
    q = Lab[i]
    idx_topk, d_topk = knn_topk(q, 8)
    d_tree, idx_tree = tree.query(q, k=8)
    print(f"\n=== 色块 #{i}  Lab={q} ===")
    print(f"  topk    idx: {idx_topk}")
    print(f"  kdtree  idx: {idx_tree}")
    print(f"  索引是否一致: {np.array_equal(idx_topk, idx_tree)}")
    if not np.array_equal(idx_topk, idx_tree):
        print(f"  topk   dist: {d_topk}")
        print(f"  kdtree dist: {d_tree}")
    # 用 topk 结果算 RGB
    w = 1.0 / d_topk
    w = w / w.sum()
    rgb_topk = (w[:, None] * rgb[idx_topk]).sum(axis=0)
    # 用 kdtree 结果算 RGB
    w2 = 1.0 / d_tree
    w2 = w2 / w2.sum()
    rgb_tree = (w2[:, None] * rgb[idx_tree]).sum(axis=0)
    print(f"  RGB(topk)   = {rgb_topk}")
    print(f"  RGB(kdtree) = {rgb_tree}")
    print(f"  RGB 差异 = {np.abs(rgb_topk - rgb_tree).max():.8f}")
