# -*- coding: utf-8 -*-
"""批次 2：CAT / 色温 / 色适应 + adjust_dlabs*，1:1 还原 MATLAB。"""
import numpy as np
from scipy.interpolate import CubicSpline

from color_utils import xyz2lab, lab2xyz2
from _cmf_data import (
    XYZ_CMF_2, XYZ_CMF_10, XYZ_CMF_20062, XYZ_CMF_200610,
    SPD_D65, SPD_A, SPD_F4, SPD_C, SPD_B, SPD_D50,
    CMF2, CMF10, CMF2006_2, CMF2006_10,
)

_M_HPE = np.array([[0.38971, 0.68898, -0.07868],
                   [-0.22981, 1.1834, 0.04641],
                   [0.0, 0.0, 1.0]])
_M_CIE2006_2 = np.linalg.inv(np.array([[1.94735469, -1.41445123, 0.36476327],
                                       [0.68990272, 0.34832189, 0.0],
                                       [0.0, 0.0, 1.93485343]]))
_M_CIE2006_10 = np.linalg.inv(np.array([[1.93986443, -1.34664359, 0.43044935],
                                        [0.69283932, 0.34967567, 0.0],
                                        [0.0, 0.0, 2.14687945]]))


# ---------------- CIE 坐标互转 ----------------
def xyz2uvY(XYZ):
    XYZ = np.asarray(XYZ, float).reshape(-1, 3)
    d = XYZ[:, 0] + 15 * XYZ[:, 1] + 3 * XYZ[:, 2]
    return np.column_stack([4 * XYZ[:, 0] / d, 9 * XYZ[:, 1] / d, XYZ[:, 1]])


def uv2xy(uvp):
    uvp = np.asarray(uvp, float).reshape(-1, 2)
    den = 12 - 16 * uvp[:, 1] + 6 * uvp[:, 0]
    return np.column_stack([9 * uvp[:, 0] / den, 4 * uvp[:, 1] / den])


def xyY2xyz(xyY):
    xyY = np.asarray(xyY, float)
    if xyY.ndim == 1:
        xyY = xyY.reshape(1, -1)
    x, y = xyY[:, 0], xyY[:, 1]
    if xyY.shape[1] == 3:
        Y = xyY[:, 2]
    else:
        Y = np.full(x.shape, 100.0)
    X = (x / y) * Y
    Z = ((1 - x - y) / y) * Y
    return np.column_stack([X, Y, Z])


def uvY2xyz(uvY):
    uvY = np.asarray(uvY, float).reshape(-1, 3)
    xy = uv2xy(uvY[:, 0:2])
    return xyY2xyz(np.column_stack([xy, uvY[:, 2]]))


# ---------------- 黑体光谱 ----------------
def blackbodySPD(T, lb=None, le=None, stepsize=None):
    T = np.asarray(T, float)
    if lb is None:
        lamb = np.arange(360, 831, 1).astype(float).reshape(-1, 1)
    else:
        if le is None:
            lbv = np.asarray(lb, float)
            if lbv.size > 1:
                lamb = lbv.reshape(-1, 1)
            else:
                lamb = np.arange(360, 831, 1).astype(float).reshape(-1, 1)
        else:
            if stepsize is None:
                stepsize = 1
            lamb = np.arange(lb, le + stepsize, stepsize).astype(float).reshape(-1, 1)

    duv = None
    if T.ndim == 2 and T.shape[0] == 2:  # case 2: CIExy 列向量 -> CCTa(xyY2xyz(T'))
        cct_est, duv_est, _ = xyz2CCT(xyY2xyz(T.T), 2)
        T = np.asarray(cct_est, float).reshape(1, -1)
        duv = np.asarray(duv_est, float).reshape(1, -1)
    elif T.ndim == 2 and T.shape[0] == 3:  # case 3: XYZ 列向量 -> CCTa(T')
        cct_est, duv_est, _ = xyz2CCT(T.T, 2)
        T = np.asarray(cct_est, float).reshape(1, -1)
        duv = np.asarray(duv_est, float).reshape(1, -1)

    c1, c2, n = 3.74183e-16, 1.4388e-2, 1.0
    lam_m = np.repeat(lamb, T.size, axis=1)            # N x m
    T_m = np.repeat(T.reshape(1, -1), lamb.shape[0], axis=0)  # N x m
    S = (1 / np.pi) * c1 * (lam_m * 1e-9) ** (-5) * (n ** (-2)) * \
        (np.exp(c2 * ((n * lam_m * 1e-9 * T_m) ** (-1))) - 1) ** (-1)
    S560 = (1 / np.pi) * c1 * (560e-9) ** (-5) * (n ** (-2)) * \
        (np.exp(c2 * ((n * 560e-9 * T.reshape(1, -1)) ** (-1))) - 1) ** (-1)
    S2 = S / np.repeat(S560, lamb.shape[0], axis=0)
    Sr = np.column_stack([lamb[:, 0], S2])
    return Sr, duv


# ---------------- CMF / XYZ 积分 ----------------
def selectcmf(observer):
    obs = int(observer)
    if obs == 2 or obs == 1931:
        return CMF2, 683.0, _M_HPE
    if obs == 10 or obs == 1964:
        return CMF10, 683.6, _M_HPE
    if obs == 2006 or obs == 200610:
        return CMF2006_10, 683.0, _M_CIE2006_10
    if obs == 200602:
        return CMF2006_2, 683.0, _M_CIE2006_2
    raise ValueError(f"selectcmf: unknown observer {observer}")


def XYZcal(Ld_S, Ld_R=1, obs=2):
    obs_arr = np.asarray(obs, float)
    if obs_arr.size == 1:
        o = int(obs_arr.item())
        if o == 2:
            C = XYZ_CMF_2
        elif o == 10:
            C = XYZ_CMF_10
        elif o == 20062:
            C = XYZ_CMF_20062
        elif o == 200610:
            C = XYZ_CMF_200610
        else:
            raise ValueError(f"XYZcal: unknown obs {obs}")
    else:
        C = obs_arr.reshape(-1, 4)

    if not isinstance(Ld_S, str):
        spd = np.asarray(Ld_S, float).reshape(-1, 2)
    else:
        key = Ld_S
        if key == 'E':
            spd = np.column_stack([np.arange(380, 781, 1), np.ones(401)])
        elif key == 'D65':
            spd = SPD_D65
        elif key == 'A':
            spd = SPD_A
        elif key == 'F4':
            spd = SPD_F4
        elif key == 'C':
            spd = SPD_C
        elif key == 'B':
            spd = SPD_B
        elif key == 'D50':
            spd = SPD_D50
        else:
            raise ValueError(f"XYZcal: unknown Ld_S '{Ld_S}'")

    lS, S = spd[:, 0], spd[:, 1]
    lC = C[:, 0]
    lmin = max(lS[0], lC[0])
    lmax = min(lS[-1], lC[-1])
    lp = np.arange(lmin, lmax + 1, 1)
    Sb = CubicSpline(lS, S, bc_type='not-a-knot')(lp)
    mask = (lC >= lp[0]) & (lC <= lp[-1])
    xb = C[mask, 1]
    yb = C[mask, 2]
    zb = C[mask, 3]

    if np.asarray(Ld_R).size == 1:
        XYZ = 683 * np.array([[np.sum(Sb * xb), np.sum(Sb * yb), np.sum(Sb * zb)]])
    else:
        rfl = np.asarray(Ld_R, float).reshape(-1, 2)
        lR, R = rfl[:, 0], rfl[:, 1]
        lm = np.arange(lR[0], lR[-1] + 1, 1)
        Rb = CubicSpline(lR, R, bc_type='not-a-knot')(lm)
        Px, Py, Pz = Sb * xb, Sb * yb, Sb * zb
        px = np.concatenate([[np.sum(Px[lp <= lm[0]])],
                             Px[(lp > lm[0]) & (lp < lm[-1])],
                             [np.sum(Px[lp >= lm[-1]])]])
        py = np.concatenate([[np.sum(Py[lp <= lm[0]])],
                             Py[(lp > lm[0]) & (lp < lm[-1])],
                             [np.sum(Py[lp >= lm[-1]])]])
        pz = np.concatenate([[np.sum(Pz[lp <= lm[0]])],
                             Pz[(lp > lm[0]) & (lp < lm[-1])],
                             [np.sum(Pz[lp >= lm[-1]])]])
        XYZ = 683 * np.array([[np.sum(Rb * px), np.sum(Rb * py), np.sum(Rb * pz)]])
    return XYZ


# ---------------- CCT <-> XYZ ----------------
def CCT2xyz(CCT, Duv=0.0, cieob=2, Y=100.0, deltaT=0.01):
    BB0spd, _ = blackbodySPD(CCT)
    BB1spd, _ = blackbodySPD(CCT + abs(deltaT))
    BB0xyz = XYZcal(BB0spd, 1, cieob)
    BB1xyz = XYZcal(BB1spd, 1, cieob)
    upvpY0 = xyz2uvY(BB0xyz)
    upvpY1 = xyz2uvY(BB1xyz)
    u0, v0 = upvpY0[0, 0], (2.0 / 3.0) * upvpY0[0, 1]
    u1, v1 = upvpY1[0, 0], (2.0 / 3.0) * upvpY1[0, 1]
    du, dv = u0 - u1, v0 - v1
    duv = (du ** 2 + dv ** 2) ** 0.5
    Du = Duv * (dv / duv)
    Dv = Duv * (du / duv)
    u, v = u0 - Du, v0 + Dv
    upvp = np.array([[u, (3.0 / 2.0) * v]])
    return uvY2xyz(np.column_stack([upvp, np.array([[Y]])]))


def _CCTMCAMY(xyz):
    xyz = np.asarray(xyz, float).reshape(-1, 3)
    xyY = xyz / xyz.sum(axis=1, keepdims=True)
    n = (xyY[:, 0] - 0.3320) / (xyY[:, 1] - 0.1858)
    return -449 * n ** 3 + 3525 * n ** 2 - 6823.3 * n + 5520.33


def _checkduvsign(p, uvm):
    p = np.asarray(p, float).reshape(2)
    uvm = np.asarray(uvm, float).reshape(3, 2)
    p = p - uvm[1, :]
    uvm = uvm - np.tile(uvm[1, :], (3, 1))
    alpha = -np.arctan((uvm[0, 1] - uvm[2, 1]) / (uvm[0, 0] - uvm[2, 0]))
    R1 = np.array([[np.cos(alpha), -np.sin(alpha)], [np.sin(alpha), np.cos(alpha)]])
    uvm = (R1 @ uvm.T).T
    p = R1 @ p
    x, y = uvm[:, 0], uvm[:, 1]
    gt = x[x > p[0]]
    lt = x[x < p[0]]
    if gt.size == 0 or lt.size == 0:
        return float(np.sign(p[1]))
    ux, lx = gt.min(), lt.max()
    uy = y[x == ux][0]
    ly = y[x == lx][0]
    if lx != ux:
        s = (uy - ly) / (ux - lx) * (p[0] - lx) + ly
    else:
        s = uy
    return float(np.sign(p[1] - s))


def xyz2CCT(xyz_, obs=2):
    """对应 xyY2CCT.m（文件名 xyz2CCT.m，主函数名 xyY2CCT）。返回 (CCT, duv, S_out)。"""
    xyz_ = np.asarray(xyz_, float)
    if xyz_.ndim == 1:
        xyz_ = xyz_.reshape(1, -1)
    if xyz_.shape[1] == 2:
        raise NotImplementedError("xyz2CCT: spectrum input requires spd2xyz (未在本批次实现)")

    cmf, _, _ = selectcmf(obs)
    lamb = cmf[:, 0].reshape(-1, 1)  # 471x1
    c1, c2 = 3.74183e-16, 1.4388 * 0.01

    n = xyz_.shape[0]
    CCT_out = np.full(n, np.nan)
    duv_out = np.full(n, np.nan)

    for cct_i in range(n):
        xyz = xyz_[cct_i, :]
        uvt = xyz2uvY(xyz.reshape(1, -1))
        ut = uvt[0, 0]
        vt = (2.0 / 3.0) * uvt[0, 1]

        CCTtemp = _CCTMCAMY(xyz.reshape(1, -1))[0]
        deltaT, dT = 100.0, 100.0
        delT = 2 * dT / 10.0
        signduv = None

        while (deltaT > 1e-6) or (delT > 0.001):
            n_T = int(round(2 * dT / delT + 1))
            T = np.linspace(CCTtemp - dT, CCTtemp + dT, n_T)
            S = (lamb * 1e-9) ** (-5) * \
                (np.exp(c2 * ((lamb * 1e-9 * T.reshape(1, -1)) ** (-1))) - 1) ** (-1)
            XYZS = np.column_stack([(cmf[:, 1:2] * S).sum(axis=0),
                                    (cmf[:, 2:3] * S).sum(axis=0),
                                    (cmf[:, 3:4] * S).sum(axis=0)])
            denom = XYZS[:, 0] + 15 * XYZS[:, 1] + 3 * XYZS[:, 2]
            uv = np.column_stack([4 * XYZS[:, 0] / denom, 6 * XYZS[:, 1] / denom])
            dc = np.sqrt((ut - uv[:, 0]) ** 2 + (vt - uv[:, 1]) ** 2)

            if not np.isnan(dc.min()):
                eps = 1e-12
                q_idx = np.where((dc >= dc.min() - eps) & (dc <= dc.min() + eps))[0]
                if q_idx.size > 1:
                    CCT = np.median(T[q_idx])
                    duv = np.median(dc[q_idx])
                    q = int(round(np.median(q_idx)))
                else:
                    q = q_idx[0]
                    CCT = T[q]
                    duv = dc[q]
                if q != (n_T - 1) and q != 0:
                    dT = 2 * dT / 10.0
                    delT = 2 * dT / 10.0
                    signduv = _checkduvsign(np.array([ut, vt]), uv[[q - 1, q, q + 1], :])
                deltaT = 100.0 * abs(CCT - CCTtemp) / CCTtemp
                CCTtemp = CCT
            else:
                CCT, duv = np.nan, np.nan

        if np.isnan(duv):
            duv_final = np.nan
        else:
            duv_final = signduv * abs(duv) if signduv is not None else np.nan
        CCT_out[cct_i] = CCT
        duv_out[cct_i] = duv_final

    # nargout==3 分支：生成参考黑体光谱
    S_out = np.full((lamb.shape[0], n), np.nan)
    last_S = None
    for i in range(n):
        S, _ = blackbodySPD(CCT_out[i])
        last_S = S
        S_out[:, i] = S[:, 1]
    S_out = np.column_stack([last_S[:, 0], S_out])
    return CCT_out, duv_out, S_out


# ---------------- CAT / Lab ----------------
def CAT16_D(XYZ, XYZw, XYZwt, D):
    M = np.array([[0.401288, 0.650173, -0.051461],
                  [-0.250268, 1.204414, 0.045854],
                  [-0.002079, 0.048952, 0.953127]])
    invM = np.linalg.inv(M)
    XYZ = np.asarray(XYZ, float).reshape(-1, 3)
    XYZw = np.asarray(XYZw, float).reshape(3)
    XYZwt = np.asarray(XYZwt, float).reshape(3)
    RGB = M @ XYZ.T              # 3 x n
    RGBw = M @ XYZw              # 3
    RGBwr = M @ XYZwt            # 3
    alpha = D * XYZw[1] / XYZwt[1]
    scale = alpha * (RGBwr / RGBw) + (1 - D)   # 3
    RGBc = scale.reshape(3, 1) * RGB
    return (invM @ RGBc).T


def CAT_lab2lab1(lab_bf, Dtype, CCT, direction):
    """对应 I_render_stimuli/utils/CAT_lab2lab1.m（Dtype: full/zhai/summer/OPPO）。"""
    lab_bf = np.asarray(lab_bf, float).reshape(-1, 3)
    wd65_64 = np.array([94.811, 100.00, 107.304])
    XYZw_pre = CCT2xyz(CCT).reshape(3)

    n = lab_bf.shape[0]
    lab_aft = np.empty_like(lab_bf)
    for i in range(n):
        XYZ_bf = lab2xyz2(lab_bf[i:i + 1], 'd65_64').reshape(3)
        CCT_val, duv, _S_out = xyz2CCT(XYZw_pre.reshape(1, -1), 10)  # MATLAB 覆盖 CCT
        CCT_val = float(np.asarray(CCT_val).reshape(-1)[0])
        duv = float(np.asarray(duv).reshape(-1)[0])
        if Dtype == 'full':
            D = 1.0
        elif Dtype == 'zhai':
            D = 0.723 * (1 - 1116 / CCT_val + 8.64 * duv - 49266 * duv / CCT_val)
        elif Dtype == 'summer':
            D = 0.239 * 0.723 * (1 - 1116 / CCT_val)
        elif Dtype == 'OPPO':
            D = 0.00005 * CCT_val + 0.1977
        else:
            raise ValueError(f"CAT_lab2lab1: unknown Dtype '{Dtype}'")
        if direction == "fore":
            XYZ_aft = CAT16_D(XYZ_bf, wd65_64, XYZw_pre, D)
        elif direction == "back":
            XYZ_aft = CAT16_D(XYZ_bf, XYZw_pre, wd65_64, D)
        else:
            raise ValueError(f"CAT_lab2lab1: unknown direction '{direction}'")
        lab_aft[i:i + 1] = xyz2lab(XYZ_aft.reshape(1, -1), 'd65_64')
    return lab_aft


# ---------------- adjust_dlabs ----------------
def adjust_dlabs(dlabs_bf, factor):
    dlabs_bf = np.asarray(dlabs_bf, float).reshape(-1, 3)
    anchor = np.tile(dlabs_bf[32:33, :], (dlabs_bf.shape[0], 1))
    delta = (dlabs_bf - anchor) * factor
    return anchor + delta


def adjust_dlabs_shape1(dlabs_bf):
    dlabs_bf = np.asarray(dlabs_bf, float).reshape(-1, 3)
    shift2933 = dlabs_bf[28, :] - dlabs_bf[32, :]
    squeeze = shift2933[2] / shift2933[1]  # b / a
    if squeeze < np.tan(np.deg2rad(50)):
        dest_height = shift2933[1] * np.tan(np.deg2rad(50))
        anchor = np.tile(dlabs_bf[32:33, :], (dlabs_bf.shape[0], 1))
        delta = dlabs_bf - anchor
        delta[:, 2] = delta[:, 2] / shift2933[2] * dest_height
        return anchor + delta
    return dlabs_bf


def adjust_dlabs_shape(dlabs_bf):
    dlabs_bf = np.asarray(dlabs_bf, float).reshape(-1, 3)
    shift2933 = dlabs_bf[28, :] - dlabs_bf[32, :]
    squeeze = shift2933[2] / shift2933[1]
    length = np.sqrt(shift2933[1] ** 2 + shift2933[2] ** 2)
    if squeeze < np.tan(np.deg2rad(50)):
        target = np.array([0, length * np.cos(np.deg2rad(50)),
                           length * np.sin(np.deg2rad(50))])
        anchor = np.tile(dlabs_bf[32:33, :], (dlabs_bf.shape[0], 1))
        delta = dlabs_bf - anchor
        delta[:, 1] = delta[:, 1] / shift2933[1] * target[1]
        delta[:, 2] = delta[:, 2] / shift2933[2] * target[2]
        return anchor + delta
    return dlabs_bf
