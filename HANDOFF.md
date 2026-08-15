# 交接文档 — I_render_stimuli → Python 迁移（供下一个会话接续）

> 项目路径（本地）：`D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python`
> 原版 MATLAB：`D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli`
> 远程仓库：`https://github.com/Huabei3/VIVOskinExpPhase2.git`，分支 `I_render_stimuli_python`
> 更新日期：2026-08-13

---

## 一、项目目标（一句话）

把 MATLAB 渲染链路 `I_render_stimuli` 1:1 迁移成 GPU Python 项目 `I_render_stimuli_python`，核心是加速 `lut3d_xyz2rgbKDitp1.m` 里的 KNN 插值，部署到云端 GPU 实例（inst1）跑。迁移按「自底向上批次 + 每批数值锚点」推进，保证逐点与 MATLAB 一致。

---

## 二、用户三条铁律（每次动手前必看）⚠️

1. **绝不改动原版 MATLAB `.m` 文件**——所有写入只发生在 `I_render_stimuli_python` 目录内。
2. **每次修改代码前**，先 git push 到远程 `I_render_stimuli_python` 分支，commit message 写「该批次操作目的」；**只推代码脚本，绕开大文件**（`.mat/.npy/.jpg/.xlsx/输出` 等，见 `.gitignore`）。
3. 继续按批次推进，当前进度在「批次 2 完成、待提交」，下一步是批次 3。

---

## 三、已完成进度（含验证结果）

| 批次 | 模块 | 产物文件 | 锚点验证 | git 状态 |
|---|---|---|---|---|
| 0 | `data_io.py` | `.mat/.xlsx/.jpg` 读取 + 路径映射 | `verify_dataio.py` **20/20 PASS** | 已提交（随批次1 commit 一起） |
| 1 | `color_utils.py` | `xyz2lab` `lab2xyz2` `deltaE2000` | `verify_color_utils.py` **5/5 PASS** | ✅ 已 commit `8dc8872` + push |
| 2 | `cat_adjust.py` | CAT/色温/色适应 + `adjust_dlabs*` | `verify_cat_adjust.py` **12/12 PASS** | ❌ **未提交**（待清理临时文件后 commit+push） |

批次 2 还依赖自动生成的 `_cmf_data.py`（CMF/SPD 常量表，从 MATLAB 内嵌数据提取）。

---

## 四、当前 git 状态（关键！下一个会话要先收尾批次 2）

当前分支 `I_render_stimuli_python`，日志仅一条：`8dc8872 批次1：色彩空间转换 color_utils…`。

**未跟踪（批次 2 待提交）：**
- `cat_adjust.py`（主实现）
- `_cmf_data.py`（CMF/SPD 数据，自动生成，勿手改）
- `verify_cat_adjust.py`（锚点）

**应删除的临时文件（用完即删，勿提交）：**
- `.gitmessage.txt`（上一次 commit message 的 UTF-8 中转文件）
- `.msg_dump.txt`
- `_dump_mfiles.py`（打印 `.m` 结构的临时脚本）
- `_extract_cmf.py`（提取 CMF/SPD 数据的临时脚本）

### 收尾批次 2 的推荐顺序（下一个会话第一步）
```powershell
cd D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python
# 1) 删临时文件
Remove-Item -Force .gitmessage.txt,.msg_dump.txt,_dump_mfiles.py,_extract_cmf.py -ErrorAction SilentlyContinue
# 2) 写 UTF-8 的 commit message 文件（PowerShell 直接 commit 中文会变 GBK 乱码）
#    把中文 message 写到 .gitmessage.txt（UTF-8 编码）
git add cat_adjust.py _cmf_data.py verify_cat_adjust.py
git commit -F .gitmessage.txt
Remove-Item .gitmessage.txt -ErrorAction SilentlyContinue
git push -u origin I_render_stimuli_python
```
> ⚠️ **中文乱码坑**：Windows PowerShell 下 `git commit -m "中文"` 会按 GBK 传参导致乱码。必须先把 message 用 UTF-8 写入 `.gitmessage.txt`，再 `git commit -F .gitmessage.txt`。

### 通用 push 流程（每个新批次开工前执行，铁律② 的执行细则）
```powershell
cd D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python
# 1) 确认 .gitignore 已生效：临时脚本 _*.py 和 .gitmessage.txt 已被排除（已配好）
git add -A
# 2) 检查暂存区，确认没有 .mat/.npy/.xlsx/图片等大文件被误加：
git status --short
#    若发现误加的大文件/临时文件：git reset -- <路径> 移出暂存
# 3) 写 UTF-8 中文 commit message 到 .gitmessage.txt（示例：「批次3：read_bull/get_average mask 1:1 还原」）
git commit -F .gitmessage.txt
Remove-Item .gitmessage.txt -ErrorAction SilentlyContinue
git push origin I_render_stimuli_python
```
> 分支已用 `-u` 建立上游跟踪，后续 push 无需再带分支名；若换新克隆需先 `git push -u origin I_render_stimuli_python`。

---

## 五、关键文件职责速览

| 文件 | 职责 |
|---|---|
| `data_io.py` | 读 `.mat`（`scipy.io.loadmat`，v5 格式可直接读）、`.xlsx`（`pandas`）、`.jpg`（`imageio`/`cv2`），含 `points_added_33.xlsx` → 33×3 前置零列 |
| `color_utils.py` | `xyz2lab` / `lab2xyz2` / `deltaE2000`（批次 1） |
| `_cmf_data.py` | 471×4 CMF 表（2°/10°/2006_2°/2006_10°）+ 401×2 SPD（D65/A/F4/C/B/D50），**自动生成勿手改** |
| `cat_adjust.py` | `blackbodySPD` `selectcmf` `XYZcal` `xyz2uvY` `uv2xy` `xyY2xyz` `uvY2xyz` `CCT2xyz` `xyz2CCT` `CAT16_D` `CAT_lab2lab1` `adjust_dlabs` `adjust_dlabs_shape1` `adjust_dlabs_shape`（批次 2） |
| `render_spec.md` | **唯一对照规格表**（函数 I/O + 算法一句话 + 依赖拓扑），写代码前先查它，勿再回头读 `.m` 原文 |
| `render_strategy.md` | 防爆上下文的批次拆分策略 + 落地批次表 |
| `refrastructure.md` | 最初的项目可行性讨论结论 |

---

## 六、待办批次（3–6）

| 批次 | 模块 | 迁移函数 | MATLAB 源 | 数值锚点 |
|---|---|---|---|---|
| 3 | `mask.py` | `read_bull` `get_average` | `utils\read_bull.m` `utils\get_average.m` | 逻辑索引 mask 一致 |
| 4 | `lut_gpu.py` | `lut3d_xyz2rgbKDitp1` **GPU 版** | `utils\lut3d_xyz2rgbKDitp1.m` | 同 xyz2 输入 vs MATLAB 逐像素一致 |
| 5 | `render_core.py` | `img_AddRender_simp` | `utils\img_AddRender_simp.m` | 单图单点输出 jpg 一致 |
| 6 | `main_i.py` | 主循环（去 imshow） | `main_i_test.m` `main_i.m` | f04i 单 subject 跑通 |

> 批次 4 是核心瓶颈：`uniquetol` 去重 + KDTree 8 近邻 + 距离倒数加权 → 向量化为 `torch.cdist + topk(8) + 加权求和`（或 faiss-gpu `IndexFlatL2`）。参考 `refrastructure.md` 第三节。

---

## 七、1:1 还原的「坑」清单（避免下一个会话重踩）

1. **白点差异（原作者笔误，必须保留）**：`xyz2lab` 用 `d65_64=[94.813,100,107.262]`，`lab2xyz2` 用 `d65_64=[94.811,100,107.304]`。往返一致性锚点因此设 `atol=0.05`。
2. **阈值差异**：MATLAB 用 `(6/29)^3`，不要换成 `0.008856`，否则边界数值不一致。
3. **负值开立方**：`xyz_w ** (1/3)` 遇负值产生 NaN，用 `np.cbrt()` 替代（正数结果一致，负值走 else 分支被丢弃）。
4. **`csapi`（not-a-knot 样条）** → SciPy `CubicSpline(x, y, bc_type='not-a-knot')`（`XYZcal`、`blackbodySPD` 积分用）。
5. **大表提取**：`XYZcal.m` / `selectcmf.m` 内嵌超大数据表，正则需先删除 `=\s*\[.*\];\s*$` 结尾的代码表达式行（如 `case 'E'` 的 `Ld_S=[(380:780)',ones(401,1)];`、`Mxyz2lms_HPE=[..];`），否则把代码行与大表串在一起导致数字不可整除。
6. **`np.array2string` 省略号**：生成 `_cmf_data.py` 时设 `threshold=a.size+1` 关闭省略，否则数组超 1000 元素被写成 `...` 导致 `inhomogeneous shape`。
7. **`_checkduvsign` 索引**：`y[x == ux]` 返回数组，取 `[0]` 转标量再比较，否则 `if lx != ux` 报「多元素真值歧义」。
8. **光度常数**：`selectcmf` 返回 2°/10° 用 683 / 683.6；`XYZcal` 内联用 683（已与 MATLAB 对齐）。

---

## 八、环境信息

- **本地**：Windows / PowerShell，Python 3.13（`C:\Users\17762\AppData\Roaming\Python\Python313`）。
- **云端 inst1**（GPU 部署目标）：`ssh -p 54536 root@connect.westc.seetacloud.com`，密码 `HfzVla8XwNaD`（见 `refrastructure.md`；此前记忆里另有多台实例，以最新沟通为准）。
- **数据上云**：先只传 1 个 subject（`f04i`，`original_image_XYZ\f04i` 约 4.5GB）跑通验证，再批量。
- **依赖**：`numpy`、`scipy`、`pandas`、`torch`（批次 4 起）；`.mat` 用 `scipy.io.loadmat`。
- 注意 `pandas` 会提示 numexpr 版本 warning（`2.10.1` < 要求 `2.10.2`），不影响功能，可忽略或升级。

---

## 九、下一步建议（接续会话的第一动作）

1. 按「第四节」收尾批次 2：删临时文件 → 写 UTF-8 commit message → `git commit -F` → `git push`（commit message 示例：「批次2：CAT/色温/色适应 + adjust_dlabs 1:1 还原 MATLAB」）。
2. 开始批次 3：先查 `render_spec.md` 里 `read_bull` / `get_average` 的规格，用 code-explorer 子代理只读 `utils\read_bull.m`、`utils\get_average.m` 回传摘要，主上下文写 `mask.py`，再写 `verify_mask.py` 锚点（对比同一 bull 图的 logicalIndex 与 bull_weight）。
3. 每批完成后跑锚点 → 通过 → 再 push，再进下一批。
