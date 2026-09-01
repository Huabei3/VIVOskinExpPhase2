# render_debug.md — MATLAB vs Python 渲染链路逐环节差异排查记录

> 目标：让 `I_render_stimuli`（MATLAB）与 `I_render_stimuli_python`（Python）在**除语言外逻辑完全一致**，
> 定位差异从哪一个环节开始。凡因"加速改造"引入的差异，一律回退到 MATLAB 语义（AutoDL 算力充足，不必为速度牺牲一致性）。

---

## 0. 已确认的事实（2026-09-01，基于 .mat 实测）

### 0.1 两套 LUT 文件（不是"版本升级"，是功能分工）

| 文件 | 前缀 | 用途 | 网格 | XYZw |
|---|---|---|---|---|
| `datai_ipv35_3.mat` | `datai_` | **正向** RGB→XYZ（jpg→XYZ 验证用） | cubeL=9 (729) | [335.07, 349.67, 411.29] |
| `datai_ipv30_phase2_3.mat` | `datai_` | 正向 phase2 | cubeL=9 (729) | [342.12, 360.12, 399.82] |
| `data_ipv35_3.mat` | `data_` | **反向** XYZ→RGB（渲染主链路用） | P_labs=35³=42875 | [335.07, 349.67, 411.29] |
| `data_ipv30_phase2_3.mat` | `data_` | 反向 phase2 | P_labs=30³=27000 | [342.12, 360.12, 399.82] |

- **正向**（`datai_`）：含 `lablut`(729,3)、`cubeL`、`XYZw`、`method='linear'`，供 `lut3d_rgb2xyz1` 用。
- **反向**（`data_`）：含 `P_labs`(N,3)、`rgb`(N,3)、`XYZw`，供 `lut3d_xyz2rgbKDitp1` 用。
- `interp3` 的 `method` 字段实测 = `'linear'`（Python 手写 trilinear 对标正确 ✅）。
- **phase1 vs phase2 白点 XYZw 不同** → `wd65_scaled` 不同 → Lab 值不同，这是 phase1/phase2 的固有差异。

### 0.2 主函数确认

- **MATLAB 现役主函数 = `I_render_stimuli\main_i_test.m`**（已用 `handle.LUT_type="phase2"`，走 `data_ipv30_phase2_3.mat`）。
- `main_i.m` 是**旧版**（硬编码 `datai_ipv18_3.mat`，未接 phase2 开关，输出命名也不带 `[L,a,b]`）。
- Python 现役主函数 = `main_i.py`（`LUT_TYPE="phase2"` ✅）。

### 0.3 输出目录（之前找错位置，已纠正）

- Python 渲染输出在 `I_render_stimuli_python\rendered_python\phase2\{i,rs}\`：
  - `i/` = 13860 jpg，`rs/` = 9240 jpg，共 23100 jpg ✅
- MATLAB 渲染输出在 `I_render_stimuli\rendered\phase2\i\`（`f01i/` 下仅空 `noFaceRGB/`，**还没真正跑过**）。

### 0.4 输入命名 vs 输出命名

- 输入（mask）：`I_render_stimuli\mask\f01i\H5K.JPG`（大写刺激名，无 `_17` 后缀）。
- 去年 phase1 输出（`toMax\rendered_2max\f01i\`）：`f01ih5k_17.jpg`（小写 + `_NN` 点号）。
- 现役 `main_i_test.m` 输出：`{stem}_{point:02d}[L,a,b].jpg`（带 `[L,a,b]` 后缀）。

---

## 1. 逐环节差异清单（按风险排序）

### 🔴 P0-1：`lut3d_xyz2rgbKDitp1` 的去重逻辑不一致（加速改造引入）

| | MATLAB `lut3d_xyz2rgbKDitp1.m` | Python `lut_gpu.py` |
|---|---|---|
| 去重 | `uniquetol(Lab, 0.01/max(max(Lab)), 'ByRows', true)`（**相对容差**） | `np.round(Lab, 4)` 后 `np.unique`（**固定 4 位小数**） |

- 两者**数学上不等价**。`uniquetol` 用 `0.01/max(max(Lab))` 这个相对阈值判"是否同组"，而 `round(Lab,4)` 是绝对精度截断。
- 差异后果：两侧"哪些像素共享同一 KNN 结果"的划分不同 → 每个像素查到的 8 邻域加权 RGB 不同 → 逐像素色差放大。
- **结论**：追求 1:1 一致时，必须把去重改回 `uniquetol` 语义。
- **处理方式**：做成开关（见 §3），可切换 `matlab`（uniquetol 语义）/ `fast`（round 加速语义）。

其余细节（KNN=8、权重=1/d、欧氏距离、fillmissing nearest、clip 顺序）两侧已对齐 ✅（仍建议用逐像素 dump 复核）。

### 🔴 P0-2：CCT 下标错位风险（文件排序差异）

- MATLAB `main_i_test.m`：`CCT=CT(i)` 用**文件顺序下标**取色温。
- Python `main_i.py`：改为按 `stem` 查表 `CT_BY_NAME[stem]`（L199-203）。
- MATLAB `dir()` 顺序（文件系统序）≠ Python `sorted(key=p.name.lower())`（显式小写排序）。
- **若两侧文件顺序不同，同一刺激会拿到不同 CCT → 直接改变 `delta_Lab`**。
- 这是"差异可能从这一层开始"的第一嫌疑点，**必须实测两侧文件顺序是否一致**。

### 🟠 P1-1：CAT / CCT 反算精度未验证

- 两侧 `CAT_lab2lab1` 都每次循环重算 CCT（MATLAB L8 / Python L335），逻辑一致 ✅。
- 但 `xyz2CCT`（= `xyY2CCT.m`）内部的 `selectcmf`、`CCTMCAMY`、`checkduvsign`、迭代收敛是否逐位一致，**无验证证据**。
- **验证方式**：跑一次，dump 两侧 CCT 值对比即可（见 §2，用户已确认用此法）。

### 🟠 P1-2：`lab2xyz2` 的 `fy` 计算（MATLAB 侧有可疑写法，但结果正确）

- MATLAB `lab2xyz2.m` L69-71 先算 `fy` 用于判断 `index`，随后**清零重建**，最终结果正确。
- Python `color_utils.py` 直接用 `np.where` 等价实现 ✅。
- 潜在精度点：Python `xyz2lab` 用 `np.cbrt`，`lab2xyz2` 用 `** (1/3)`；对负数前者返回实数根、后者 NaN。此处 Y 恒正，理论不触发，但属于低风险精度差异。

### 🟡 P2-1：最终 jpg imwrite 的舍入

- MATLAB `imwrite(double图)`：自动 `*255` + **四舍五入**。
- Python `np.clip(x*255,0,255).astype(np.uint8)`：**截断（floor）**。
- 会导致 ±1 RGB 差异，放大到 dE 约 0.5~1。

### 🟡 P2-2：`**` vs `cbrt`（见 P1-2，风险极小）

---

## 2. 验证方案（先不改代码，只 dump 中间变量）

对单张 `f01ih5k_17`（刺激 H5K、第 17 点），两侧各自保存中间变量，逐层对比差异从哪层开始：

| 层级 | 变量 | 说明 |
|---|---|---|
| 0 | CCT | CAT 前反算的色温（验证 P1-1） |
| 1 | `delta_Lab` | CAT 后、加色前的 ΔLab（验证 P0-2/P1-1） |
| 2 | `lab2` | 加 delta 后的 Lab（验证 P1-2） |
| 3 | `xyz2` | **没过 LUT 的 XYZ**（lab2xyz2 输出，核心对比） |
| 4 | `outnew` | 过 LUT 的 RGB（验证 P0-1） |
| 5 | `jpg` | imwrite 最终图（验证 P2-1） |

两侧均已具备 dump 能力：
- MATLAB `main_i_test.m` 已存 `xyz2_file`/`outnew_file`，只缺 delta_Lab/lab2。
- Python `main_i.py` 有 `--save-mats`（存 xyz2/outnew），`img_AddRender_simp` 已 return `lab2`。

---

## 3. 待实现：uniquetol 去重开关（P0-1 修复项）

在 `lut_gpu.py` 的 `lut3d_xyz2rgbKDitp1` 增加参数 `dedup_mode`：

- `dedup_mode="matlab"`：复刻 MATLAB `uniquetol(Lab, 0.01/max(max(Lab)), 'ByRows', true)` 语义（默认，1:1 一致）。
- `dedup_mode="fast"`：保留现有 `np.round(Lab, 4)` 加速语义。

> 注：MATLAB `uniquetol` 语义需按其实际实现复刻（容差 `tol=0.01/max(max(Lab))`，
> 按行、以"首个未分组行"为基准吸收容差内的后续行），不能简单用 `round` 替代。

---

## 4. 待办清单

- [ ] 验证 MATLAB `dir()` 文件顺序 vs Python `sorted` 是否一致（P0-2）
- [ ] 跑一次 dump 两侧 CCT（P1-1）
- [ ] 实现 `lut_gpu.py` 的 `dedup_mode` 开关（P0-1）
- [ ] 逐像素 dump `delta_Lab/lab2/xyz2/outnew`，定位差异起始层
- [ ] 若 P2-1 确认，Python imwrite 改四舍五入（`np.rint`）
