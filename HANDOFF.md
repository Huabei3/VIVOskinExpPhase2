# 交接文档 — I_render_stimuli → Python 迁移（供下一个会话接续）

> 项目路径（本地）：`D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python`
> 原版 MATLAB：`D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli`
> 远程仓库：`https://github.com/Huabei3/VIVOskinExpPhase2.git`，分支 `I_render_stimuli_python`
> 更新日期：2026-08-16

---

## 一、项目目标（一句话）

把 MATLAB 渲染链路 `I_render_stimuli` 1:1 迁移成 GPU Python 项目 `I_render_stimuli_python`，核心是加速 `lut3d_xyz2rgbKDitp1.m` 里的 KNN 插值，部署到云端 GPU 实例跑。迁移按「自底向上批次 + 每批数值锚点」推进，保证逐点与 MATLAB 一致。

---

## 二、用户三条铁律（每次动手前必看）⚠️

1. **绝不改动原版 MATLAB `.m` 文件**——所有写入只发生在 `I_render_stimuli_python` 目录内。
2. **每次修改代码前**，先 git push 到远程 `I_render_stimuli_python` 分支，commit message 写「该批次操作目的」；**只推代码脚本，绕开大文件**（`.mat/.npy/.jpg/.xlsx/输出` 等，见 `.gitignore`）。
3. 继续按批次推进，每批跑数值锚点通过后再 push。

---

## 三、已完成进度（含验证结果）

| 批次 | 模块 | 产物文件 | 锚点验证 | git 状态 |
|---|---|---|---|---|
| 0 | `data_io.py` | `.mat/.xlsx/.jpg` 读取 + 路径映射 | `verify_dataio.py` **20/20 PASS** | ✅ 已提交（随批次1） |
| 1 | `color_utils.py` | `xyz2lab` `lab2xyz2` `deltaE2000` | `verify_color_utils.py` **5/5 PASS** | ✅ commit `8dc8872` + push |
| 2 | `cat_adjust.py` + `_cmf_data.py` | CAT/色温/色适应 + `adjust_dlabs*` | `verify_cat_adjust.py` **12/12 PASS** | ✅ commit `4ce790b` + push |
| 3 | `mask.py` | `read_bull` `get_average` | `verify_mask.py` **25/25 PASS** | ✅ commit `fb715e0` + push |
| 4 | `lut_gpu.py` | `lut3d_xyz2rgbKDitp1` GPU 向量化版 | `verify_lut_gpu.py` **22/22 PASS** | ✅ commit `c0b218d` + push |
| 5 | `render_core.py` | `img_AddRender_simp` | `verify_render_core.py` 合成 **9/9 PASS**；**真实锚点未过（见第五节）** | ⚠️ 未提交（3 个文件在工作区） |

---

## 四、当前 git 状态（下一个会话第一件事）

当前分支 `I_render_stimuli_python`，HEAD = `c0b218d`（批次4）。工作区未提交：

```
 M lut_gpu.py            ← CPU 设备自适应 chunk 修复（chunk>512 时降为 512）
?? render_core.py        ← 批次 5 主实现（未提交）
?? verify_render_core.py ← 批次 5 锚点（未提交）
?? _diag_dlab_result.txt ← 诊断输出，临时文件，最终删除
```

**临时文件（用完即删，勿提交）：** `_diag_dlab.py`、`_diag_lut_bg.py`、`_diag_dlab_result.txt`、MATLAB 目录下的 `_diag_dlab_intermediates.m`、`.gitmessage.txt`。
`_cmf_data.py` 是**正式依赖**（批次2 自动生成），**勿删**。

### 批次 5 收尾的推荐顺序（接续会话第一步）
```powershell
cd D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python
# 1) 重跑 LUT 背景验证（scale bug 已修）：
python _diag_lut_bg.py
# 2) 拿到 MATLAB 端 _diag_dlab_intermediates.m 的中间量后，定位 dlab 偏差（见第五节）
# 3) 锚点全 PASS 后提交批次 5：
git add lut_gpu.py render_core.py verify_render_core.py
#    写 UTF-8 commit message 到 .gitmessage.txt（PowerShell 中文 commit 必须用 -F 中转）
git commit -F .gitmessage.txt
Remove-Item .gitmessage.txt -ErrorAction SilentlyContinue
git push origin I_render_stimuli_python
# 4) 删临时诊断文件，进批次 6 main_i.py
```

> ⚠️ **中文乱码坑**：Windows PowerShell 下 `git commit -m "中文"` 按 GBK 传参导致乱码。必须先把 message 用 UTF-8 写入 `.gitmessage.txt`，再 `git commit -F .gitmessage.txt`。

---

## 五、批次 5 卡点（本会话全部已知事实，直接接续）

### 5.1 锚点现状
- **A 层（合成 4×4 小图 + 真实 LUT）9/9 PASS**：形状/范围/背景=LUT背景/缓存复用/`dest_lab==get_average` 全部正确 → **证明 `img_AddRender_simp` 核心逻辑正确**。
- **B 层（真实 f04i/H3K 端到端）FAIL 两处**：

**① dlab 与 MATLAB 基准文件名不一致**
```
ours = [57.3909, 22.1078, 44.1882]   (L 差 1.2)
ref  = [58.5861, 22.4045, 44.8393]   (MATLAB 渲染输出 jpg 文件名)
```

**② CPU 内存不足**（已修 `lut_gpu.py`：`device.startswith("cpu")` 时 chunk 强制 ≤512）
```
RuntimeError: DefaultCPUAllocator: not enough memory: tried to allocate 1769472000 bytes
（torch.cdist float64 8192×27000 = 1.77GB，本机无 CUDA）
```

### 5.2 已排查并确认无问题的环节（不要再重查）
- `i_type=2` 正确；`load_points/load_avelab/load_mat/load_xyz` 实现正确
- `points_added_33.xlsx` 加载正确（33×2 数值，无表头）
- `xyz2lab`/`lab2xyz2` 实现与 MATLAB 逐行一致（含两套白点差异，勿统一）
- `blackbodySPD`/`CCT2xyz` 两边完全一致（`c1=3.74183e-16, c2=1.4388e-2`，λ=360–830）
- `CAT16_D` 一致；`adjust_dlabs_shape1` 一致；`mask.py` 的 `read_bull`/`get_average` 正确
- `num_points[0] = [0, -2.54, -4.89]`（非零），squeeze=1.30>1.19 → adjust 分支不触发
- **两套白点**：`datai_ipv18_3.mat`（lab1 用）→ `wd65_scaled=[331.53,...]`；`data_ipv30_phase2_3.mat`（渲染 LUT 用）→ `[341.44,...]`。`img_AddRender_simp` 内部用逆向 LUT 的 XYZw
- **`main_i_test.m` 关键语义**：`CCT=CT(i)` 按 `dir` 返回的**文件顺序**取值，`i=1` **未必是 H3K**；`num_points` 在模型循环**外**读取（每模型重置）；`i_points=1` 的文件名用 `dlab(1,1)`

### 5.3 最可疑的偏差来源（按优先级）
1. **dlab 预处理链**：`labC_HD65` 读取 → CAT → `adjust_dlabs_shape1` → `dlabs[0]` 与 `XYZw_pre` 的 CAT 链。诊断脚本 `_diag_dlab.py` 已打印全链路中间量（结果在 `_diag_dlab_result.txt`），结论：偏差出现在 CAT 链**输入**处，即 `average`/`labC_HD65` 加载或 `get_average`。
2. **MATLAB 端中间量未知**：已写好 `I_render_stimuli/_diag_dlab_intermediates.m`，需用户在 MATLAB 跑一次，对比 `average`、`labC_HD65`、`dlab(1,:)` 中间量 → 定位是 `get_average` 还是 CAT 链。
3. **`XYZcal.m` 积分精度**：MATLAB 版是 160KB 内嵌 CMF 表文件，与 Python 的 `XYZcal`（从 `selectcmf` 提取）可能略有差异。`verify_cat_adjust.py` 的锚点只对照标准色度（容差 1e-4），**没有直接对照 MATLAB `CCT2xyz(3000)` 输出**——建议让用户在 MATLAB 打印 `CCT2xyz(3000)` 与 Python 对比。

### 5.4 LUT 背景验证（独立于 dlab 的链路验证）
- 发现：MATLAB 渲染输出 `rendered\phase2\i\f04i\H3K_01[58.5861,22.4045,44.8393].jpg` 是真实基准，**背景像素（黑色 XYZ）MATLAB 输出 `[80,63,43]`**，我们曾输出 clip 后 `[255,0,255]`。
- 已修正 `_diag_lut_bg.py` 的 scale bug：`lut_gpu.py` 输出是 **0–255 尺度**（MATLAB 语义），不是 0–1。**修正后尚未重跑**，接续会话第一件事就是重跑确认。
- MATLAB 背景也走 LUT（黑 XYZ → [80,63,43] 是 LUT 插值结果，非特判），故 LUT 对极端点行为必须与 MATLAB 逐像素一致。

---

## 六、待办批次

| 批次 | 模块 | 迁移函数 | MATLAB 源 | 数值锚点 |
|---|---|---|---|---|
| 5 | `render_core.py` | `img_AddRender_simp` | `utils\img_AddRender_simp.m` | 单图单点输出 jpg 一致（**收尾中**） |
| 6 | `main_i.py` | 主循环（去 imshow） | `main_i_test.m` `main_i.m` | f04i 单 subject 跑通 |

> 批次 6 关键点：复刻 `main_i_test.m` 主循环，**去掉 imshow**；注意 `CCT=CT(i)` 按文件顺序取值、`num_points` 循环外读取、文件名格式 `[%.4f,%.4f,%.4f]`（dlab 三维）。

---

## 七、1:1 还原的「坑」清单（避免下一个会话重踩）

1. **白点差异（原作者笔误，必须保留）**：`xyz2lab` 用 `d65_64=[94.813,100,107.262]`，`lab2xyz2` 用 `d65_64=[94.811,100,107.304]`。往返一致性锚点因此设 `atol=0.05`。渲染链路另有两套 datai/datap 白点（见 5.2）。
2. **阈值差异**：MATLAB 用 `(6/29)^3`，不要换成 `0.008856`，否则边界数值不一致。
3. **负值开立方**：`xyz_w ** (1/3)` 遇负值产生 NaN，用 `np.cbrt()` 替代。
4. **`csapi`（not-a-knot 样条）** → SciPy `CubicSpline(x, y, bc_type='not-a-knot')`。
5. **大表提取**：`XYZcal.m` / `selectcmf.m` 内嵌超大数据表，正则需先删除 `=\s*\[.*\];\s*$` 结尾的代码表达式行，否则数字不可整除。
6. **`np.array2string` 省略号**：生成 `_cmf_data.py` 时设 `threshold=a.size+1` 关闭省略。
7. **`_checkduvsign` 索引**：`y[x == ux]` 返回数组，取 `[0]` 转标量再比较。
8. **光度常数**：`selectcmf` 返回 2°/10° 用 683 / 683.6；`XYZcal` 内联用 683。
9. **`lut_gpu.py` 输出尺度是 0–255**（MATLAB 语义），诊断脚本勿再乘 255。
10. **CPU 无 CUDA**：锚点验证走 CPU，`cdist` 分块必须设备自适应（CPU chunk=512）。
11. **顺序语义**：MATLAB 列优先 vs numpy 行优先展平——`read_bull` 已确认 C-order，全链路自洽（背景像素恒 0 掩盖差异）。

---

## 八、环境信息

- **本地**：Windows / PowerShell，Python 3.13（`C:\Users\17762\AppData\Roaming\Python\Python313`）。**本机无 CUDA**（`torch.cuda.is_available()=False`），真实数据锚点必须用 CPU 小 chunk。
- **云端**（GPU 部署目标）：见记忆里的 inst1/inst5 等实例（端口会变，以最新记忆为准）。批次 5/6 全部锚点 PASS 后再上云。
- **数据**：`rendered_2max/`（40 子文件夹，f/m01-10 的 i/r）、GT 在 `gt/toMax_gt_{attr}.xlsx`。渲染项目数据在 `I_render_stimuli\rendered\phase2\i\f04i\`（MATLAB 基准输出）。
- **依赖**：`numpy`、`scipy`、`pandas`、`torch`（批次 4 起）；`.mat` 用 `scipy.io.loadmat`。

---

## 九、下一步建议（接续会话的第一动作，按序执行）

1. **重跑 `_diag_lut_bg.py`**（scale bug 已修）→ 确认 LUT 链路对真实 f04i 背景/前景与 MATLAB jpg 一致。
2. **请用户在 MATLAB 跑 `I_render_stimuli\_diag_dlab_intermediates.m`**，拿回 `average`/`labC_HD65`/`dlab(1,:)`/`CCT2xyz(3000)` 中间量 → 对比 Python 侧（`_diag_dlab.py` + `_diag_dlab_result.txt`），定位 dlab 偏差在 `get_average` 还是 CAT 链。
3. **批次 5 锚点全 PASS 后**：commit+push（`lut_gpu.py` + `render_core.py` + `verify_render_core.py`），删临时诊断文件。
4. **批次 6**：写 `main_i.py`（复刻 `main_i_test.m` 主循环，去 imshow，注意文件顺序取值 + dlab 文件名格式），跑 f04i 单 subject 锚点，通过后 commit+push。
5. 全部完成确认工作区干净、无临时文件残留。
