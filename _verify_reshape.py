import numpy as np
from scipy.io import loadmat

P1 = r'D:/work/VIVOSkinExpe/PeggySkinBackup/A_code/C_VIVO_skin_project/A_characterization/display_model/datai_ipv35_3.mat'
d = loadmat(P1)
print('keys:', [k for k in d.keys() if not k.startswith('__')])

lablut = np.asarray(d['lablut'], dtype=np.float64)      # (729, 3)
XYZ9   = np.asarray(d['XYZ9'], dtype=np.float64) if 'XYZ9' in d else None
XYZw   = np.asarray(d['XYZw'], dtype=np.float64).reshape(-1)
cubeL  = int(np.asarray(d['cubeL']).flatten()[0])
print('cubeL =', cubeL, ' lablut.shape =', lablut.shape)

# 1) 找 XYZ9 里 Y 最大的行（= 白色 RGB=255,255,255 对应行）
if XYZ9 is not None:
    idx_white = int(np.argmax(XYZ9[:, 1]))
    print('XYZ9 Y-max row index =', idx_white)
    print('lablut[that row] =', lablut[idx_white].round(4), '  (should be ~[100,0,0])')

# 2) 两种 reshape 顺序下，RGB=[255,255,255] 插值出的 Lab
def trilinear(vals, rgb):
    # vals: (9,9,9,3)  rgb: (N,3) 0..255
    c = vals.shape[0]
    f = rgb / 255.0 * (c - 1)
    i0 = np.floor(f).astype(int)
    i1 = np.minimum(i0 + 1, c - 1)
    w = f - i0
    out = np.empty((rgb.shape[0], 3))
    for ch in range(3):
        V = vals[:, :, :, ch]
        c000 = V[i0[:,0], i0[:,1], i0[:,2]]
        c100 = V[i1[:,0], i0[:,1], i0[:,2]]
        c010 = V[i0[:,0], i1[:,1], i0[:,2]]
        c110 = V[i1[:,0], i1[:,1], i0[:,2]]
        c001 = V[i0[:,0], i0[:,1], i1[:,2]]
        c101 = V[i1[:,0], i0[:,1], i1[:,2]]
        c011 = V[i0[:,0], i1[:,1], i1[:,2]]
        c111 = V[i1[:,0], i1[:,1], i1[:,2]]
        wr, wg, wb = w[:,0], w[:,1], w[:,2]
        out[:, ch] = ((1-wr)*(1-wg)*(1-wb))*c000 + (wr*(1-wg)*(1-wb))*c100 \
                   + ((1-wr)*wg*(1-wb))*c010 + (wr*wg*(1-wb))*c110 \
                   + ((1-wr)*(1-wg)*wb)*c001 + (wr*(1-wg)*wb)*c101 \
                   + ((1-wr)*wg*wb)*c011 + (wr*wg*wb)*c111
    return out

# C order（Python 版当前做法）
vC = lablut.reshape(cubeL, cubeL, cubeL, 3, order='C')
# F order（MATLAB reshape 列主序等价）
vF = lablut.reshape(cubeL, cubeL, cubeL, 3, order='F')

rgb_white = np.array([[255.0, 255.0, 255.0]])
rgb_skin  = np.array([[200.0, 150.0, 130.0]])
rgb_gray  = np.array([[128.0, 128.0, 128.0]])

for name, v in [('C-order (Python current)', vC), ('F-order (MATLAB equiv)', vF)]:
    print(f'\n=== {name} ===')
    for tag, r in [('white', rgb_white), ('gray', rgb_gray), ('skin', rgb_skin)]:
        lab = trilinear(v, r)[0]
        print(f'  RGB={r[0].astype(int)} -> Lab = {np.round(lab, 3)}')
