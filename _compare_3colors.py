# -*- coding: utf-8 -*-
"""精确对比 3 个差异色块的 M vs P RGB"""
import scipy.io as sio
import numpy as np

M_DIR = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli"
P_DIR = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python"

m_rgb = sio.loadmat(M_DIR + r"\test96_RGB.mat")["RGB"]
p_fast = np.load(P_DIR + r"\test96_RGB_fast.npy")
p_matlab = np.load(P_DIR + r"\test96_RGB_matlab.npy")

for i in [18, 36, 54]:
    print(f"color #{i}:")
    print(f"  MATLAB    = {m_rgb[i]}")
    print(f"  Python-fast    = {p_fast[i]}")
    print(f"  Python-matlab  = {p_matlab[i]}")

print("\n--- MATLAB 这3个色块是否完全相同? ---")
print("m[18]==m[36]:", np.allclose(m_rgb[18], m_rgb[36]))
print("m[18]==m[54]:", np.allclose(m_rgb[18], m_rgb[54]))
print("m[36]==m[54]:", np.allclose(m_rgb[36], m_rgb[54]))

print("\n--- 全部 96 色块的 MATLAB RGB 唯一值统计 ---")
# 看 MATLAB 里有没有重复的 RGB（去重生效的证据）
_, inverse = np.unique(np.round(m_rgb, 6), axis=0, return_inverse=True)
print("MATLAB 96色块去重后唯一RGB数:", len(np.unique(inverse, axis=0)) if False else len(np.unique(inverse)))
