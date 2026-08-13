# -*- coding: utf-8 -*-
"""批次 1：色彩空间转换。1:1 还原 xyz2lab.m / lab2xyz2.m / deltaE2000.m。

关键差异（勿"统一"）：
- xyz2lab  d65_64 = [94.813,100,107.262]
- lab2xyz2 d65_64 = [94.811,100,107.304]
- xyz2lab  阈值 (6/29)^3；lab2xyz2 阈值 0.008856 / 7.9996
"""
import numpy as np

_XYZ2LAB_WHITE = {
    "We": [100.000, 100.000, 100.000],
    "d65_31": [95.047, 100.000, 108.883],
    "d65_64": [94.813, 100.000, 107.262],
}

_LAB2XYZ_WHITE = {
    "a_64": [111.144, 100.00, 35.200], "a_31": [109.850, 100.00, 35.585],
    "c_64": [97.285, 100.00, 116.145], "c_31": [98.074, 100.00, 118.232],
    "d50_64": [96.720, 100.00, 81.427], "d50_31": [96.422, 100.00, 82.521],
    "d55_64": [95.799, 100.00, 90.926], "d55_31": [95.682, 100.00, 92.149],
    "d65_64": [94.811, 100.00, 107.304], "d65_31": [95.047, 100.00, 108.883],
    "d75_64": [94.416, 100.00, 120.641], "d75_31": [94.072, 100.00, 122.638],
    "f2_64": [103.279, 100.00, 69.027], "f2_31": [99.186, 100.00, 67.393],
    "f7_64": [95.792, 100.00, 107.686], "f7_31": [95.041, 100.00, 108.747],
    "f11_64": [103.863, 100.00, 65.607], "f11_31": [100.962, 100.00, 64.350],
}


def _as_nx3(arr, name):
    arr = np.asarray(arr, dtype=np.float64)
    if arr.ndim == 1:
        arr = arr.reshape(1, 3)
    if arr.ndim != 2 or arr.shape[1] != 3:
        raise ValueError(f"{name} must be N x 3")
    return arr


def xyz2lab(xyz, obs, white=None):
    xyz = _as_nx3(xyz, "xyz")
    if obs == "user":
        if white is None:
            raise ValueError("xyz2lab: obs='user' requires white")
        white = np.asarray(white, dtype=np.float64).reshape(1, 3)
    elif obs in _XYZ2LAB_WHITE:
        white = np.array(_XYZ2LAB_WHITE[obs], dtype=np.float64).reshape(1, 3)
    else:
        raise ValueError(f"xyz2lab: unknown obs '{obs}'")

    xyz_w = xyz / white
    thr = (6.0 / 29.0) ** 3
    # np.cbrt 对正数与 **(1/3) 一致；对负数返回实数根（不产生 NaN 警告），
    # 而负值必然走 else 分支被丢弃，结果与 MATLAB 相同。
    fx = np.where(xyz_w > thr, np.cbrt(xyz_w),
                  (841.0 / 108.0) * xyz_w + 4.0 / 29.0)
    lab = np.empty_like(xyz)
    lab[:, 0] = 116.0 * fx[:, 1] - 16.0
    lab[:, 1] = 500.0 * (fx[:, 0] - fx[:, 1])
    lab[:, 2] = 200.0 * (fx[:, 1] - fx[:, 2])
    return lab


def lab2xyz2(lab, obs, xyzw=None):
    lab = _as_nx3(lab, "lab")
    if obs == "user":
        if xyzw is None:
            raise ValueError("lab2xyz2: obs='user' requires xyzw")
        white = np.asarray(xyzw, dtype=np.float64).reshape(1, 3)
    elif obs in _LAB2XYZ_WHITE:
        white = np.array(_LAB2XYZ_WHITE[obs], dtype=np.float64).reshape(1, 3)
    else:
        raise ValueError(f"lab2xyz2: unknown obs '{obs}'")

    xyz = np.empty_like(lab)
    L = lab[:, 0]
    # Y
    idx = L > 7.9996
    xyz[:, 1] = np.where(idx, white[0, 1] * ((L + 16.0) / 116.0) ** 3,
                         white[0, 1] * L / 903.3)
    # fy
    Yn = xyz[:, 1] / white[0, 1]
    idx = Yn > 0.008856
    fy = np.where(idx, Yn ** (1.0 / 3.0), 7.787 * Yn + 16.0 / 116.0)
    # X
    fx = lab[:, 1] / 500.0 + fy
    idx = fx ** 3 > 0.008856
    xyz[:, 0] = np.where(idx, white[0, 0] * fx ** 3,
                         white[0, 0] * (fx - 16.0 / 116.0) / 7.787)
    # Z
    fz = fy - lab[:, 2] / 200.0
    idx = fz ** 3 > 0.008856
    xyz[:, 2] = np.where(idx, white[0, 2] * fz ** 3,
                         white[0, 2] * (fz - 16.0 / 116.0) / 7.787)
    return xyz


def deltaE2000(Labstd, Labsample, KLCH=None):
    """CIEDE2000 色差，返回 (de00, de00c)，与 MATLAB 逐点一致。"""
    Labstd = _as_nx3(Labstd, "Labstd")
    Labsample = _as_nx3(Labsample, "Labsample")
    if Labstd.shape != Labsample.shape:
        raise ValueError("deltaE2000: size mismatch")

    if KLCH is None:
        kl = kc = kh = 1.0
    else:
        kl, kc, kh = (float(v) for v in np.asarray(KLCH).reshape(3))

    Lstd, astd, bstd = Labstd[:, 0], Labstd[:, 1], Labstd[:, 2]
    Lsmp, asmp, bsmp = Labsample[:, 0], Labsample[:, 1], Labsample[:, 2]

    Cabstd = np.sqrt(astd ** 2 + bstd ** 2)
    Cabsample = np.sqrt(asmp ** 2 + bsmp ** 2)
    Cabarithmean = (Cabstd + Cabsample) / 2.0
    G = 0.5 * (1.0 - np.sqrt(Cabarithmean ** 7 / (Cabarithmean ** 7 + 25.0 ** 7)))

    apstd = (1.0 + G) * astd
    apsample = (1.0 + G) * asmp
    Cpstd = np.sqrt(apstd ** 2 + bstd ** 2)
    Cpsample = np.sqrt(apsample ** 2 + bsmp ** 2)
    Cpprod = Cpsample * Cpstd
    zcidx = Cpprod == 0.0

    hpstd = np.arctan2(bstd, apstd)
    hpstd = hpstd + 2.0 * np.pi * (hpstd < 0)
    hpstd = np.where((np.abs(apstd) + np.abs(bstd)) == 0, 0.0, hpstd)
    hpsample = np.arctan2(bsmp, apsample)
    hpsample = hpsample + 2.0 * np.pi * (hpsample < 0)
    hpsample = np.where((np.abs(apsample) + np.abs(bsmp)) == 0, 0.0, hpsample)

    dL = Lsmp - Lstd
    dC = Cpsample - Cpstd
    dhp = hpsample - hpstd
    dhp = dhp - 2.0 * np.pi * (dhp > np.pi)
    dhp = dhp + 2.0 * np.pi * (dhp < -np.pi)
    dhp = np.where(zcidx, 0.0, dhp)
    dH = 2.0 * np.sqrt(Cpprod) * np.sin(dhp / 2.0)

    Lp = (Lsmp + Lstd) / 2.0
    Cp = (Cpstd + Cpsample) / 2.0
    hp = (hpstd + hpsample) / 2.0
    hp = hp - (np.abs(hpstd - hpsample) > np.pi) * np.pi
    hp = hp + (hp < 0) * 2.0 * np.pi
    hp = np.where(zcidx, hpsample + hpstd, hp)

    Lpm502 = (Lp - 50.0) ** 2
    Sl = 1.0 + 0.015 * Lpm502 / np.sqrt(20.0 + Lpm502)
    Sc = 1.0 + 0.045 * Cp
    T = (1.0 - 0.17 * np.cos(hp - np.pi / 6.0) + 0.24 * np.cos(2.0 * hp)
         + 0.32 * np.cos(3.0 * hp + np.pi / 30.0)
         - 0.20 * np.cos(4.0 * hp - 63.0 * np.pi / 180.0))
    Sh = 1.0 + 0.015 * Cp * T
    delthetarad = (30.0 * np.pi / 180.0) * np.exp(-((180.0 / np.pi * hp - 275.0) / 25.0) ** 2)
    Rc = 2.0 * np.sqrt(Cp ** 7 / (Cp ** 7 + 25.0 ** 7))
    RT = -np.sin(2.0 * delthetarad) * Rc

    klSl, kcSc, khSh = kl * Sl, kc * Sc, kh * Sh
    dLt = dL / klSl
    dCt = dC / kcSc
    dHt = dH / khSh
    de00 = np.sqrt(dLt ** 2 + dCt ** 2 + dHt ** 2 + RT * dCt * dHt)
    de00c = np.sqrt(dCt ** 2 + dHt ** 2 + RT * dCt * dHt)
    return de00, de00c
