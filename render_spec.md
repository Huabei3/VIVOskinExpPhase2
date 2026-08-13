# I_render_stimuli 主链路函数规格表（Python 迁移唯一对照物）

> 来源：code-explorer 子代理对 `main_i_test.m` 调用链的只读梳理。
> 目录约定：
> - `utils\` = `I_render_stimuli\utils\`
> - `父级utils` = `C_VIVO_skin_project\utils\`（被传递调用，不在本目录，迁移时需一并读取）
>
> 已确认：`xyz2lab` / `lab2xyz2` **均不**调用 `selectcmf` / `cie_cmfs.mat` / `RGB96.mat`；
> `cie_cmfs.mat`、`RGB96.mat` 在本 utils 目录中无人引用。

## 主入口 `main_i_test.m` 主流程
1. 遍历 20 个 subject（`new_names`），按 model 定 `i_type`（`select_type`）。
2. 读 `mask\{sub}i\*.jpg`（bull）、`Shadow\mask\{sub}\nosd\*.jpg`（bull_nosd）、`original_image_XYZ\{sub}\*.mat`（XYZ）。
3. `XYZ → lab1`（`xyz2lab`，白点 `wd65_scaled`）；`get_average` 求人脸平均 Lab。
4. 由 `a_CL` 与 `labC_HD65` 算 `dlabs` 目标点（Lab 偏移，来自 `points_added_33.xlsx`）。
5. `CAT_lab2lab1` 把目标 Lab 从 D65 映射到当前 CCT，再 `adjust_dlabs_shape1` / `adjust_dlabs` 整形。
6. `delta_Lab = 目标 Lab − 平均 Lab`，调用 `img_AddRender_simp` 渲染，`deltaE2000` 校验，`imwrite` 输出。

---

## 一级函数（main 直接/间接调用）

### select_type
- 签名：`select_type(model) -> i_type`
- 算法：按 model 名归类返回 1/2/3/4（四组人脸），否则报错。
- 依赖函数：无
- 依赖数据文件：无

### xyz2lab
- 签名：`xyz2lab(xyz, obs, white) -> lab (Nx3)`
- 算法：标准 CIELAB 正变换；`obs` 支持 `d65_31/d65_64/user` 等硬编码白点；`user` 用传入 `white`。
- 依赖函数：无（纯公式，不 load 任何 .mat，不调用 selectcmf）
- 依赖数据文件：无

### get_average
- 签名：`get_average(lab, bull, if_wei) -> average (1x3)`
- 算法：`read_bull` 得到掩膜；`if_wei` 时按权重加权平均，否则对非黑像素求均值。
- 依赖函数：`read_bull`
- 依赖数据文件：无

### read_bull
- 签名：`read_bull(bull, if_wei) -> [logicalIndex, bull_weight]`
- 算法：bull 灰度/彩色图归一化到 0~1；`logicalIndex` = 全黑像素（背景），`bull_weight` = 每像素通道均值（0~1 权重）。
- 依赖函数：无
- 依赖数据文件：无

### CAT_lab2lab1
- 签名：`CAT_lab2lab1(lab_bf, Dtype, CCT, direction) -> lab_aft (Nx3)`
- 算法：Lab(D65) → XYZ（`lab2xyz2`）；`CCT2xyz` 求目标白点 XYZw_pre；`xyz2CCT` 求 duv；按 `Dtype` 算适应度 D；`CAT16_D` 做色适应；再 `xyz2lab` 回 Lab。
- 依赖函数：`lab2xyz2`、`CCT2xyz`、`xyz2CCT`（父级 utils，文件实际定义 `xyY2CCT`）、`CAT16_D`、`xyz2lab`
- 依赖数据文件：无

### adjust_dlabs_shape1
- 签名：`adjust_dlabs_shape1(dlabs_bf) -> dlabs_aft`
- 算法：用第 29、33 点在 a-b 平面斜率控制形状；若 b/a 斜率 < tan(50°)，把 b 轴压缩到 50° 高度（绕第 33 点缩放 b 分量）。
- 依赖函数：无
- 依赖数据文件：无
- 备注：存在未用的 `adjust_dlabs_shape.m`（同时缩放 a、b），本链路用 shape1（只缩 b）。

### adjust_dlabs
- 签名：`adjust_dlabs(dlabs_bf, factor) -> dlabs_aft`
- 算法：以第 33 点为中心，对 delta_Lab 整体乘 `factor` 缩放（i_type==4 时按 model 取 0.5~0.55）。
- 依赖函数：无
- 依赖数据文件：无

### img_AddRender_simp
- 签名：`img_AddRender_simp(img, bull, bull_nosd, string, delta_Lab, XYZ, noFaceRGB_file, if_wei, if_2mask, handle) -> [outnew, dest_lab, bull_nosd, lab2]`
- 算法：① 由 `handle.LUT_type` 选 datafile；② `xyz2lab`(XYZ,user,wd65_scaled) 得 lab1；③ `lab2 = lab1 + delta_Lab * bull_weight`，对无阴影区 sd 修正 a/b ≥ 0；④ `get_average` 求目标平均 dest_lab；⑤ `lab2xyz2` 回 XYZ，背景区保持原 xyz1；⑥ `lut3d_xyz2rgbKDitp1` 把 XYZ 转 RGB（背景与前景分开插值并缓存 noFaceRGB）；⑦ reshape 回图像。
- 依赖函数：`read_bull`、`xyz2lab`、`get_average`、`lab2xyz2`、`lut3d_xyz2rgbKDitp1`
- 依赖数据文件：`data_ipv30_phase2_3.mat`（phase2）或 `data_ipv35_3.mat`（phase1）—— 字段 `XYZw`；`noFaceRGB_file`（缓存 .mat，字段 `noFaceRGB`）

### deltaE2000
- 签名：`deltaE2000(Labstd, Labsample, KLCH) -> [de00, de00c]`
- 算法：标准 CIEDE2000 色差（含 G、a'、hue、SL/SC/SH、RT 项），KLCH 可选权重默认 [1,1,1]。
- 依赖函数：无
- 依赖数据文件：无

### lab2xyz2
- 签名：`lab2xyz2(lab, obs, xyzw) -> xyz (Nx3)`
- 算法：标准 CIELAB 逆变换，硬编码多种标准白点；`user` 用传入 `xyzw`。注意其 `d65_64` = [94.811,100,107.304] 与 `xyz2lab` 的 d65_64 [94.813,100,107.262] 略有差异（迁移时统一）。
- 依赖函数：无（不调用 selectcmf / 不 load .mat）
- 依赖数据文件：无

### lut3d_xyz2rgbKDitp1  ← 核心瓶颈
- 签名：`lut3d_xyz2rgbKDitp1(XYZ, datafile) -> [RGB, out_of_gamut_ratio]`
- 算法：load 逆向 LUT；`xyz2lab`(user,XYZw) 转 Lab；KDTree 对 `P_labs` 找每行 Lab 的 8 近邻，按距离倒数加权平均 `rgb` 得 RGB（先 `uniquetol` 去重，串行 for 循环）；NaN/Inf 用 nearest 填充，裁剪到 [0,255]；返回越界比例。
- 依赖函数：`xyz2lab`（及 MATLAB `KDTreeSearcher`/`knnsearch`/`parpool`）
- 依赖数据文件：`data_ipv30_phase2_3.mat` / `data_ipv35_3.mat`，字段：`P_labs`、`rgb`、`cubeL`、`XYZw`（`cubeL` load 后实际未使用）

---

## 传递依赖（叶子 / 辅助函数，迁移时一并处理）

### CCT2xyz（本 utils）
- 签名：`CCT2xyz(CCT, Duv, cieob, Y, deltaT) -> XYZ (1x3)`
- 算法：黑体 SPD（`blackbodySPD`）→ `XYZcal` → uvY → 按 Duv 偏移 → `uvY2xyz`。
- 依赖函数：`blackbodySPD`、`XYZcal`（本 utils）、`xyz2uvY`、`uvY2xyz`（父级 utils）
- 依赖数据文件：无

### xyz2CCT（父级 utils，函数名 `xyY2CCT`）
- 签名：`xyY2CCT(xyz_, obs) -> [CCT_out, duv_out, S_out]`
- 算法：MCAMY 初估 CCT → 在普朗克轨迹上迭代搜索最小 uv 距离，得 CCT/duv，并可返回参考黑体 SPD。
- 依赖函数：`selectcmf`、`xyz2uvY`、`blackbodySPD`、子函数 `CCTMCAMY`/`checkduvsign`
- 依赖数据文件：无（`selectcmf` 硬编码 CMF 表，不 load .mat）

### CAT16_D（本 utils）
- 签名：`CAT16_D(XYZ, XYZw, XYZwt, D) -> XYZt (Nx3)`
- 算法：CAT02 矩阵色适应（M_CAT02 硬编码），按 D 与白点亮度比做部分/完全适应。
- 依赖函数：无
- 依赖数据文件：无

### XYZcal（本 utils）
- 签名：`XYZcal(Ld_S, Ld_R, obs) -> XYZ (Nx3)`
- 算法：SPD（+可选反射谱）× 内嵌 CMF 表数值积分得 XYZ（683 光度常数）。
- 依赖函数：无（CMF 数据内嵌，不调用 selectcmf）
- 依赖数据文件：无

### 父级 utils 待补函数（迁移时需读取源码确认）
- `blackbodySPD`
- `xyz2uvY`
- `uvY2xyz`
- `selectcmf`（CMF 硬编码）

---

## 外部资源与关键字段（main_i_test.m）

- `points_added_33.xlsx`：`readmatrix` → 33×2（a、b 偏移）；代码前置零列 → 33×3 `[0, Δa, Δb]`（Lab 增量）。
- `aveSkinByHand2\i\C_Lpara\{type}C_L_para.mat`：字段 `a_CL`（1×2），仅 i_type∈{3,4} 时 load；i_type∈{1,2} 直接硬编码 `a_CL=[6.7421,-9.9816]`。
- `documents\aveSkin\i\aveLab_D65_{type}.mat`：字段 `labC_HD65`（矩阵；用 `labC_HD65(1,2:3)` 和 `labC_HD65(1,4)` 计算 factor）。
- `..\A_characterization\display_model\datai_ipv18_3.mat`（正向 LUT）：仅用字段 `XYZw`（1×3，显示白点），算 `wd65_scaled = wd65/100*XYZw(2)`。
- `..\A_characterization\display_model\data_ipv30_phase2_3.mat` / `data_ipv35_3.mat`（逆向 LUT，`lut3d_xyz2rgbKDitp1` 用）：
  - `rgb`：`meshgrid(linspace(0,255,grid))` → **grid³×3**；grid = `cubeL_ext` = 30（→27000×3）或 35（→42875×3）。
  - `P_labs`：同形状 **grid³×3**，是对 9×9×9 测量 Lab（`lablut`）在 RGB 网格上 `interp3` 得到的 Lab 值。
  - `cubeL`：保存值 = 9（原始测量网格），在 `lut3d_xyz2rgbKDitp1` 中 load 但**未使用**；实际 grid 由 `nthroot(size(rgb,1),3)` 推出。
  - `XYZw`：1×3，显示白点（测量 XYZ9 中 Y 最大行）。
- `mask\{sub}i\*.jpg`：bull 掩膜（imread），供 `read_bull` 生成 `logicalIndex`（背景）与 `bull_weight`（权重）。
- `Shadow\mask\{sub}\nosd\*.jpg`：bull_nosd 无阴影掩膜，`if_2mask` 时用于 `get_average` 及 `img_AddRender_simp` 中 sd 区域修正。
- XYZ 数据 `D:\work\VIVOSkinExpe\original_image_XYZ\{subject}\*.mat`：字段 `XYZ_cropped`（H×W×3），reshape 成 (m·n)×3 使用。

---

## 依赖拓扑图

```
main_i_test.m
├─ select_type                                (叶子)
├─ xyz2lab                                    (叶子)
├─ get_average
│  └─ read_bull                              (叶子)
├─ CAT_lab2lab1
│  ├─ lab2xyz2                               (叶子)
│  ├─ CCT2xyz
│  │  ├─ blackbodySPD                        (父级utils)
│  │  ├─ XYZcal                              (本utils，CMF内嵌)
│  │  ├─ xyz2uvY                             (父级utils)
│  │  └─ uvY2xyz                             (父级utils)
│  ├─ xyz2CCT  (=xyY2CCT, 父级utils)
│  │  ├─ selectcmf                           (CMF硬编码)
│  │  ├─ xyz2uvY
│  │  └─ blackbodySPD
│  ├─ CAT16_D                                (叶子)
│  └─ xyz2lab                                (叶子)
├─ adjust_dlabs_shape1                        (叶子)
├─ adjust_dlabs                               (叶子)
├─ img_AddRender_simp
│  ├─ read_bull                              (叶子)
│  ├─ xyz2lab                                (叶子)
│  ├─ get_average ── read_bull
│  ├─ lab2xyz2                               (叶子)
│  └─ lut3d_xyz2rgbKDitp1
│     └─ xyz2lab                             (叶子)
└─ deltaE2000                                 (叶子)
```
