# -*- coding: utf-8 -*-
"""_diag_knn.py - diagnose whether outnew diff pixels are caused by KNN tie (8th/9th neighbor)"""
import os
import numpy as np
from scipy.io import loadmat
from data_io import load_lut
from color_utils import xyz2lab

BASE = r"D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project"
MT_DIR = os.path.join(BASE, "I_render_stimuli", "rendered", "phase2", "i", "f01i")
PY_DIR = os.path.join(BASE, "I_render_stimuli", "rendered_python", "phase2", "i", "f01i")
LUT_FILE = os.path.join(BASE, "A_characterization",
                        "display_model", "data_ipv30_phase2_3.mat")

STEM = "H3K_01[59.0378,23.8328,43.1617]"


def main():
    mt = loadmat(os.path.join(MT_DIR, STEM + "_outnew.mat"))["outnew_img"].astype(np.float64)
    py = loadmat(os.path.join(PY_DIR, STEM + "_outnew.mat"))["outnew_img"].astype(np.float64)
    diff = np.abs(mt - py).max(axis=2)

    xyz2 = loadmat(os.path.join(PY_DIR, STEM + ".mat"))["xyz2_img"].astype(np.float64)

    lut = load_lut(LUT_FILE)
    P_labs = lut["P_labs"]
    XYZw = lut["XYZw"]

    ys, xs = np.where(diff > 0.5 / 255.0)
    print("diff pixels (>0.5 gray):", list(zip(ys.tolist(), xs.tolist())))

    for y, x in zip(ys, xs):
        xyz = xyz2[y, x, :]
        lab = xyz2lab(xyz.reshape(1, 3), "user", XYZw)[0]
        print("\n=== pixel (%d,%d) ===" % (y, x))
        print("  xyz2 = %s" % xyz)
        print("  lab  = %s" % lab)
        print("  MT outnew = %s" % mt[y, x, :])
        print("  PY outnew = %s" % py[y, x, :])
        print("  diff(gray) = %.4f" % (diff[y, x] * 255))

        dist = np.linalg.norm(P_labs - lab, axis=1)
        order = np.argsort(dist, kind="stable")
        d = dist[order]
        print("  top10 dist: %s" % ["%.12f" % v for v in d[:10]])
        gap89 = d[8] - d[7]
        gap910 = d[9] - d[8]
        print("  gap d9-d8 = %.3e   gap d10-d9 = %.3e" % (gap89, gap910))
        print("  topk(8) idx   = %s" % order[:8].tolist())
        print("  9th idx(excl) = %s" % order[8].tolist())
        # tie 判断：第 8 和第 9 距离相等（浮点下 < 1e-12 视为 tie）
        if gap89 < 1e-12:
            print("  >>> TIE detected at 8/9 boundary <<<")
        else:
            print("  no tie at 8/9 (gap %.3e)" % gap89)


if __name__ == "__main__":
    main()
