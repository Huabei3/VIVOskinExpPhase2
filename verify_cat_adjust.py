# -*- coding: utf-8 -*-
"""批次 2 锚点验证：CCT/色适应/adjust_dlabs。运行后应全部 PASS。"""
import numpy as np
import cat_adjust as c

PASS = 0
TOTAL = 0


def check(name, cond, detail=""):
    global PASS, TOTAL
    ok = bool(cond)
    PASS += ok
    TOTAL += 1
    print(f"[{'PASS' if ok else 'FAIL'}] {name} {detail}")


def xy_of(xyz):
    xyz = np.asarray(xyz, float).ravel()
    return xyz[0] / xyz.sum(), xyz[1] / xyz.sum()


# ---- 1. CCT2xyz 黑体轨迹锚点（标准 Planckian locus 色度）----
locus = {3000.: (0.4369, 0.4041), 4000.: (0.3805, 0.3768),
         5000.: (0.3451, 0.3516), 6500.: (0.3135, 0.3236),
         10000.: (0.2807, 0.2882)}
for k, (xr, yr) in locus.items():
    x, y = xy_of(c.CCT2xyz(k))
    check(f"CCT2xyz({k:.0f}) xy", abs(x - xr) < 1e-4 and abs(y - yr) < 1e-4,
          f"got=({x:.5f},{y:.5f}) ref=({xr},{yr})")

# ---- 2. CCT2xyz <-> xyz2CCT 往返（obs 一致）----
for k in (3000., 6500., 10000.):
    cct_back = c.xyz2CCT(c.CCT2xyz(k), 2)[0][0]
    check(f"往返 CCT {k:.0f}", abs(cct_back - k) < 0.5, f"got={cct_back:.3f}")

# ---- 3. CAT16_D 恒等（D=0）----
w1 = np.array([94.811, 100., 107.304])
w2 = c.CCT2xyz(5000.).ravel()
xyz = np.array([[50., 60., 70.], [20., 30., 40.]])
out = c.CAT16_D(xyz, w1, w2, 0.0)
check("CAT16_D D=0 恒等", np.allclose(out, xyz, atol=1e-10))

# ---- 4. CAT_lab2lab1 往返（full, D=1）----
lab = np.array([[60., 20., 10.], [50., -15., 25.]])
labf = c.CAT_lab2lab1(lab, 'full', 5000., 'fore')
labb = c.CAT_lab2lab1(labf, 'full', 5000., 'back')
check("CAT_lab2lab1 fore/back 往返", np.allclose(labb, lab, atol=0.05),
      f"max_err={np.abs(labb - lab).max():.4f}")

# ---- 5. adjust_dlabs 缩放 ----
dlabs = np.zeros((33, 3))
dlabs[32] = [50., 10., 5.]          # 锚点 = 第 33 行 (MATLAB 1-based)
dlabs[0] = [60., 20., 15.]          # delta = [10,10,10]
aft = c.adjust_dlabs(dlabs, 0.5)
check("adjust_dlabs factor=0.5", np.allclose(aft[0], [55., 15., 10.]),
      f"got={aft[0]}")

# ---- 6. adjust_dlabs_shape1 角度阈值 ----
dlabs = np.zeros((33, 3))
dlabs[32] = [0., 0., 0.]
dlabs[28] = [0., 10., 5.]           # a=10, b=5 -> squeeze=0.5 < tan(50)
dlabs[0] = [10., 10., 5.]           # 相对锚点 delta=[10,10,5]
aft = c.adjust_dlabs_shape1(dlabs)
dest_h = 10. * np.tan(np.deg2rad(50))
b_scale = dest_h / 5.
check("adjust_dlabs_shape1 b 缩放", np.allclose(aft[0, 2], 5. * b_scale),
      f"got_b={aft[0,2]:.4f} ref={5.*b_scale:.4f}")

print(f"\n===== {PASS}/{TOTAL} 通过 =====")
