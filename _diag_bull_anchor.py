# -*- coding: utf-8 -*-
"""实证：用 MATLAB 解码的 bull_f04i_H3K.mat 重算 average，判断解码差异 vs 逻辑差异。"""
import numpy as np
from scipy.io import loadmat
from PIL import Image
import cv2

from data_io import load_xyz
from color_utils import xyz2lab
from mask import get_average

# ---- 1) 加载 MATLAB bull ----
d = loadmat(r'..\I_render_stimuli_python\bull_f04i_H3K.mat')
mat_bull = d['bull']
print('MATLAB bull shape:', mat_bull.shape, 'dtype:', mat_bull.dtype)

# ---- 2) 黑像素统计对比 ----
pil_bull = np.asarray(Image.open(r'..\I_render_stimuli\mask\f04i\H3K.JPG'))
cv_bull = cv2.imread(r'..\I_render_stimuli\mask\f04i\H3K.JPG', cv2.IMREAD_COLOR)

for name, b in [('MATLAB', mat_bull), ('PIL', pil_bull), ('OpenCV', cv_bull)]:
    flat = b.reshape(-1, b.shape[-1]) if b.ndim == 3 else b.reshape(-1)
    if flat.ndim == 1:
        all0 = (flat == 0).sum()
        any0 = all0
    else:
        all0 = np.all(flat == 0, axis=1).sum()
        any0 = np.any(flat == 0, axis=1).sum()
    print('%s: all0=%d  any0=%d  non-black=%d' % (name, all0, any0, len(flat) - all0))

# 像素值完全相等吗？
m_pil = pil_bull.astype(np.int16).reshape(-1, 3)
m_mat = mat_bull.astype(np.int16).reshape(-1, 3)
print('MATLAB vs PIL 逐像素 diff 统计: max=%d, 不同像素数=%d' % (
    np.abs(m_pil - m_mat).max(), int((np.abs(m_pil - m_mat).sum(axis=1) != 0).sum())))

# ---- 3) 用 MATLAB bull 重算 average ----
xyz_d = load_xyz(r'D:\work\VIVOSkinExpe\original_image_XYZ\f04i\H3K.mat')
XYZ = xyz_d['XYZ_cropped']
m, n = 2186, 1640
wd65_scaled = np.array([94.813, 100.0, 107.262]) / 100.0 * np.array([331.529, 349.666, 375.059])[1]
lab1 = xyz2lab(XYZ.reshape(m * n, 3), 'user', wd65_scaled)

target_mat = np.array([58.5630675363, 26.3946576212, 49.1587029937])

for name, b in [('MATLAB', mat_bull), ('PIL', pil_bull)]:
    avg = get_average(lab1, b, False)
    print('average(%s) = [%.6f %.6f %.6f]  diff=[%+.4f %+.4f %+.4f]' % (
        name, avg[0], avg[1], avg[2],
        avg[0]-target_mat[0], avg[1]-target_mat[1], avg[2]-target_mat[2]))
print('target(MATLAB) =', target_mat)
