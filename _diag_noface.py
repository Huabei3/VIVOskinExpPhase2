# -*- coding: utf-8 -*-
"""_diag_noface.py - compare MATLAB vs Python noFaceRGB (mask-out LUT result)"""
import os
import numpy as np
from scipy.io import loadmat

BASE = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli"
MT_NOFACE = os.path.join(BASE, "rendered", "phase2", "i", "f01i", "noFaceRGB", "H3K.mat")
PY_NOFACE = os.path.join(BASE, "rendered_python", "phase2", "i", "f01i", "noFaceRGB", "H3K_r6.mat")


def main():
    mt = loadmat(MT_NOFACE)
    py = loadmat(PY_NOFACE)
    print("MT keys:", [k for k in mt if not k.startswith('__')])
    print("PY keys:", [k for k in py if not k.startswith('__')])
    for k in mt:
        if not k.startswith('__'):
            print("  MT %s: shape=%s dtype=%s" % (k, mt[k].shape, mt[k].dtype))
    for k in py:
        if not k.startswith('__'):
            print("  PY %s: shape=%s dtype=%s" % (k, py[k].shape, py[k].dtype))

    # 取 noFaceRGB 变量
    def get_noface(d):
        for k in d:
            if not k.startswith('__'):
                v = np.asarray(d[k], dtype=np.float64)
                if v.ndim == 2 and v.shape[1] == 3:
                    return v
        return None

    a = get_noface(mt)
    b = get_noface(py)
    if a is None or b is None:
        print("noFaceRGB var not found")
        return
    print("\nMT noFaceRGB shape=%s  PY shape=%s" % (a.shape, b.shape))
    if a.shape != b.shape:
        print("shape mismatch, cannot align")
        return

    diff = np.abs(a - b)
    pix_diff = diff.max(axis=1)
    maxd = pix_diff.max()
    n_gt1 = int(np.sum(pix_diff > 1.0 / 255.0))
    n_gt_half = int(np.sum(pix_diff > 0.5 / 255.0))
    print("noFaceRGB diff (0~1 scale):")
    print("  max_abs_diff     = %.6f (= %.4f gray)" % (maxd, maxd * 255))
    print("  rows > 1   gray  = %d" % n_gt1)
    print("  rows > 0.5 gray  = %d" % n_gt_half)
    print("  mean_abs_diff     = %.8f" % pix_diff.mean())

    rows = np.where(pix_diff > 0.5 / 255.0)[0]
    print("\nrows > 0.5 gray:", rows.tolist())
    for r in rows[:20]:
        print("  row %d: MT=%s PY=%s" % (r, a[r].round(6), b[r].round(6)))


if __name__ == "__main__":
    main()
