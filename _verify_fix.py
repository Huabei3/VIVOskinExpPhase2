# -*- coding: utf-8 -*-
"""_verify_fix.py - compare MATLAB vs Python outnew for f01i/H3K_01"""
import os
import glob
import numpy as np
from scipy.io import loadmat

BASE = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli"
MT_DIR = os.path.join(BASE, "rendered", "phase2", "i", "f01i")
PY_DIR = os.path.join(BASE, "rendered_python", "phase2", "i", "f01i")


def find_stem(d, key):
    for f in sorted(glob.glob(os.path.join(d, "*.mat"))):
        if key in os.path.basename(f):
            return f
    return None


def img_var(d):
    for k in d:
        if not k.startswith('__'):
            v = d[k]
            if v.ndim >= 2 and v.shape[-1] == 3:
                return k
    return None


def load_img(path):
    d = loadmat(path)
    k = img_var(d)
    if k is None:
        return None, None, [x for x in d if not x.startswith('__')]
    return np.asarray(d[k], dtype=np.float64), k, [x for x in d if not x.startswith('__')]


def main():
    mt_out = find_stem(MT_DIR, "_outnew.mat")
    py_out = None
    if mt_out:
        stem = os.path.basename(mt_out).replace("_outnew.mat", "")
        py_out = find_stem(PY_DIR, stem + "_outnew.mat")
    print("MATLAB outnew:", mt_out)
    print("Python outnew:", py_out)

    if mt_out:
        a, mk, mkeys = load_img(mt_out)
        print("  MT var=%s shape=%s min=%.6f max=%.6f" % (mk, a.shape, a.min(), a.max()))
    if py_out:
        b, pk, pkeys = load_img(py_out)
        print("  PY var=%s shape=%s min=%.6f max=%.6f" % (pk, b.shape, b.min(), b.max()))

    if not (mt_out and py_out):
        print("[info] python-side outnew not generated yet, render first.")
        return

    if a.shape != b.shape:
        print("shape mismatch: MT=%s PY=%s" % (a.shape, b.shape))
        return

    diff = np.abs(a - b)
    pix_diff = diff.max(axis=2)
    maxd = pix_diff.max()
    n_gt1 = int(np.sum(pix_diff > 1.0 / 255.0))
    n_gt_half = int(np.sum(pix_diff > 0.5 / 255.0))
    n_gt_eps = int(np.sum(pix_diff > 1e-6))
    print("=== outnew diff (0~1 scale) ===")
    print("max_abs_diff      = %.6f  (= %.4f gray-level)" % (maxd, maxd * 255))
    print("pixels > 1   gray = %d" % n_gt1)
    print("pixels > 0.5 gray = %d" % n_gt_half)
    print("pixels > 1e-6     = %d" % n_gt_eps)
    print("mean_abs_diff      = %.8f" % pix_diff.mean())

    idx = np.unravel_index(np.argmax(pix_diff), pix_diff.shape)
    print("max diff pos (row,col) = %s" % (idx,))
    print("  MT = %s" % (a[idx[0], idx[1], :],))
    print("  PY = %s" % (b[idx[0], idx[1], :],))

    for c, name in enumerate("RGB"):
        dc = diff[:, :, c]
        print("  ch %s: max=%.6f  >1gray=%d" % (name, dc.max(), int(np.sum(dc > 1.0 / 255.0))))


if __name__ == "__main__":
    main()
