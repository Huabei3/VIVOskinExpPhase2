# main_i.py 对齐 main_i_test.m 快速验证（./6 resize）

## 1. 已加逻辑：`--resize-factor`（对应 main_i_test.m 的 4 行 ./6 resize）

main_i_test.m 新加的 4 行：

```matlab
img0      = imresize(img0,      [size(img0,1)./6,      size(img0,2)./6]);   % L83
bull      = imresize(bull,      [size(bull,1)./6,      size(bull,2)./6]);   % L96
bull_nosd = imresize(bull_nosd, [size(bull_nosd,1)./6, size(bull_nosd,2)./6]); % L103
XYZ       = imresize(XYZ,       [size(XYZ,1)./6,       size(XYZ,2)./6]);    % L113
```

main_i.py 已加入 `_imresize_div()`，并在 `render_subject()` 的 4 个对应位置调用：

| main_i.py 位置 | 对应 MATLAB 行 |
|---|---|
| `img0`（`im2double` 之前） | L83 |
| `bull` | L96 |
| `bull_nosd`（仅当存在 nosd 文件；否则复用已 resized 的 `bull`） | L103 |
| `XYZ`（`load_xyz` 之后） | L113 |

关键对齐点（已实测 MATLAB R2024a）：

- **尺寸 = `ceil(H/6) × ceil(W/6)`**：MATLAB `imresize(A,[2186/6,1640/6])` 实测输出 `365×274`，是**向上取整**，不是 round/floor。
- **插值 = bicubic（Keys a=-0.5）+ 抗锯齿**：Python 现已改用 `imresize_matlab`（`matlab_resize.py`）精确复现 MATLAB `imresize`，不再用 cv2；double 路径逐像素对齐 2.6e-13，uint8 路径已对齐「每步 round+clip」（见第 6 节）。

## 2. main_i_test.m 当前「快速验证」配置 → Python 参数对照

| MATLAB (main_i_test.m) | 含义 | Python 参数 |
|---|---|---|
| `new_names`（16 个，无 f04-f06/m04-m06） | 只跑这 16 个 subject | `--subs ...` |
| `for i =[1]` | 只跑第 1 张图 | `--first-only` |
| `for i_points=[startCenter]`（startCenter=1） | 只跑第 1 个点 | `--point 1` |
| 4 行 `imresize ./6` | 缩小 6 倍 | `--resize-factor 6` |

## 3. 运行指令（在 `I_render_stimuli_python` 目录下执行）

```powershell
python main_i.py --subs f01 f02 f03 m01 m02 m03 f07 f08 m07 m08 f09 f10 m09 m10 --first-only --point 1 --resize-factor 6 --no-uni --save-mats
```

说明：

- `--subs` 后 16 个 subject 与 main_i_test.m 的 `new_names` 一一对应（Python 默认 `NEW_NAMES` 是 20 个，含 f04-f06/m04-m06，故需显式指定 16 个）。
- `--first-only` + `--point 1` 等价 `for i=[1]` + `for i_points=[startCenter]`。
- `--resize-factor 6` 等价 4 行 `./6` resize。
- `--no-uni` 对应 `main_i_test.m` 的 `handle.uni_mode="False"`（不去重）。**不传时默认是 `fast`（round 加速去重），会与 MATLAB 不一致。**
- `--save-mats` 额外存 `xyz2/outnew/delta_lab/lab2` 四个 `.mat`（MATLAB 侧每次都存，逐像素对比只能靠这些 `.mat`，jpg 两侧编码器不同必然非逐位一致）。
- 输出目录：`rendered_python/phase2/i/{lastPart}/small/no_uni/`（Python 独立目录，不覆盖 MATLAB 的 `rendered_*` 结果）。

## 4. 还原成非快速验证（跑全量）

```powershell
python main_i.py --subs f01 f02 f03 m01 m02 m03 f07 f08 m07 m08 f09 f10 m09 m10 --no-uni --save-mats
```

（去掉 `--first-only` / `--point 1` / `--resize-factor 6`，即跑全部图、全部点、不缩放；`--no-uni --save-mats` 与当前 MATLAB 口径保持一致）

## 5. 去重开关 `--uni`（有去重 vs 无去重）

main_i_test.m 当前调用的 `lut3d_xyz2rgbKDitp1.m` **有去重**（`uniquetol`）。
注意：`lut3d_xyz2rgbKDitp1_nopar.m` 只是「无并行」版（nopar = no parallel），**仍然有去重**；
真正无去重的是 `lut3d_xyz2rgbKDitp.m`（parfor）或 `lut3d_xyz2rgbNoPar.m`（for）。

Python 端 `main_i.py` 加了布尔开关 `--uni`：

| 开关 | 等价底层 dedup_mode | 语义 |
|---|---|---|
| `--uni` | `matlab` | 有去重，1:1 对齐 MATLAB `uniquetol`（排序贪心） |
| `--no-uni` | `none` | 无去重，逐行独立 KNN |
| 不传（默认） | 沿用 `--dedup-mode`（默认 `fast`） | round 加速去重 |

### 5.1 对齐修复（关键，已实测 R2024a）

发现 Python 旧版 `_uniquetol_matlab` 是「顺序贪心」，与 MATLAB `uniquetol` 的「排序贪心」
在链式场景下分组不同，已修正：

| 用例 `[100.006,0,0; 100.000,0,0; 100.011,0,0]` | 分组 |
|---|---|
| MATLAB `uniquetol`（排序贪心） | 2 组：`{100.000,100.006}` / `{100.011}` |
| Python 旧版（顺序贪心） | 1 组（链式误合并）❌ |
| Python 修正后（排序贪心） | 2 组 ✅ |

MATLAB `uniquetol` 三个实测确认点（Python 已逐条对齐）：

1. DataScale = `max(abs(Lab),[],1)` **按列**（非全局标量）。
2. 分组 = **排序贪心**（先按行字典序排序，anchor = 组内最小值）。
3. 组代表 = 组内**原始顺序第一个**（MATLAB 代码 `Lab(idx(1),:)`）。

### 5.2 运行示例

```powershell
# 进入 Python 渲染目录
cd "D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python"

# 【当前口径】无去重（= main_i_test.m 的 handle.uni_mode="False"）
python main_i.py --subs f01 --first-only --point 1 --resize-factor 6 --no-uni --save-mats

# 有去重（仅用于对照 --uni 分支；MATLAB 侧需把 handle.uni_mode 改成 "True" 才对齐）
python main_i.py --subs f01 --first-only --point 1 --resize-factor 6 --uni --save-mats
```

## 6. 完整运行指令（含 cd，当前 main_i_test.m 逻辑 1:1 复跑）

### 6.1 一键复制（PowerShell）

```powershell
cd "D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python"
python main_i.py --subs f01 f02 f03 m01 m02 m03 f07 f08 m07 m08 f09 f10 m09 m10 --first-only --point 1 --resize-factor 6 --no-uni --save-mats



cd "D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python"
python main_rs_gpu.py --dedup-mode none --save-mats
```

### 6.2 参数 ↔ 当前 main_i_test.m 对照

| main_i_test.m（当前） | Python 参数 | 说明 |
|---|---|---|
| `new_names` = 16 个（f04-f06/m04-m06 已注释） | `--subs f01 f02 f03 m01 m02 m03 f07 f08 m07 m08 f09 f10 m09 m10` | 16 个 i subject |
| `for i=[1]` | `--first-only` | 只跑每个 subject 第 1 张图 |
| `for i_points=[startCenter]`（startCenter=1） | `--point 1` | 只跑第 1 个点 |
| 4 行 `imresize ./6`（L83/96/103/113） | `--resize-factor 6` | 缩小 6 倍 |
| `handle.uni_mode="False"` → `lut3d_xyz2rgbKDitp1_noUni`（不去重） | `--no-uni` | 不去重，与 MATLAB 当前口径一致 |
| `handle.force_rerender="True"`（忽略已存在图） | `--force` | 强制重渲染 |
| 每次都存 `xyz2_file` / `outnew_file` | `--save-mats` | 存调试 mat |

### 6.3 resize 现况（已更新，重要）

- 4 处 resize 现已全部走 `imresize_matlab`（`matlab_resize.py`），精确复现 MATLAB `imresize` 的 bicubic（Keys a=-0.5）+ 抗锯齿 + scale 计算 + 维度顺序 + 边界反射。
- double 路径逐像素对齐 2.6e-13；uint8 路径已对齐「每步 round+clip」（bicubic 负 overshoot 每步 clip 到 0，而非最后一次性 clip）。
- 因此 `--resize-factor 6` 下 `get_average` 整条链路（resize → lab1 → read_bull → get_average）已与 MATLAB 逐位一致（实测 average 10 位小数完全一致）。




cd /root/autodl-tmp/render_code/I_render_stimuli_python
export XYZ_BASE=/root/autodl-tmp/original_image_XYZ
source /root/miniconda3/bin/activate deepskin
python main_rs_gpu.py --dedup-mode none --save-mats

## 7. main_rs.py ↔ main_rs_test.m 一致性核对 + rs05/point 33 快速验证指令

> **2026-09-18 更新（当前口径，优先于下文旧记录）**
>
> - 两个 test 脚本都已加开关 `handle.force_rerender`，当前值 **`"True"` = 强制重渲染**，对应 Python 的 `--force`。
> - `handle.uni_mode` 两侧均为 **`"False"` = 不去重**：`main_i*.py` 用 `--no-uni`，`main_rs*.py` 用 `--dedup-mode none`。
>   （`main_rs*.py` 的 `--dedup-mode` 已支持 `none`；MATLAB 的 `uni_mode="False"` 调的是 `lut3d_xyz2rgbKDitp1_noUni`。）
> - `main_rs_test.m` 的 `handle.LUT_type="phase2"`，且 `handle` 已传入 `img_AddRender_simp`，
>   **外层白点与内层 LUT 都用 `data_ipv30_phase2_3.mat`**。因此 7.1 表格里「外层 ipv18 / 内层 phase1」两行已作废。
> - 下文所有 Python 指令已统一为「**不去重 + `--save-mats`**」。

### 7.1 结论

链路主体**逐环等价**（`num_points` / `if_wei` 列表 / `i_type` / `C_pre`+`factor` / `CCT=model_tcp_mean(rs05→行5)` /
后 CAT / `adjust_dlabs_shape1` / `adjust_dlabs` / `delta_Lab` / 文件名 `num2str` / `imwrite` quality=75 / 跳过已存在），
LUT 白点与去重语义已于 2026-09-18 对齐，**当前仅剩 1 处次要差异**（逐点 dE 打印：MATLAB `deltaE2000` vs Python `_rough_dE`=dE76，仅日志不影响像素）。

| 环节 | main_rs_test.m | main_rs.py（L73 当前值） | 一致? |
|---|---|---|---|
| 外层 `wd65_scaled`（算 `average`） | `handle.LUT_type="phase2"` → `data_ipv30_phase2_3.mat` Yw=360.1208 | `LUT_TYPE="phase2"` → 同一文件（L137-143） | ✅（2026-09-18 已修，原为 ipv18） |
| 内层 LUT（真正渲染）+ 内层白点 | 同一个 `handle` 传入 → phase2 文件 | 同一个 `LUT_TYPE` → phase2 文件 | ✅（2026-09-18 已修） |
| 去重语义 | `handle.uni_mode="False"` → `lut3d_xyz2rgbKDitp1_noUni`（不去重） | `--dedup-mode none`（不去重） | ✅ 已对齐 |
| 强制重渲染 | `handle.force_rerender="True"`（不加时=已存在即跳过） | `--force` | ✅ 已对齐 |
| 逐点 dE 打印 | `deltaE2000(dest_lab,dlab)` | `_rough_dE` = dE76 | ⚠ 仅日志，不影响像素 |
| `for i=[5]` ↔ rs05 | 第 5 个文件 = `rs05`（mask 下 rs01…rs14） | `--names rs05` + `scene_idx=int(stem[-2:])-1` 取 `model_tcp_mean(5,1)`（L227-231） | ✅ |
| `for i_points=[33]` | `i_points=33` | `--point 33`（L256 用 `i_points != point-1 -> continue`） | ✅ |
| 其余（if_wei、CAT 逐行等价、文件名格式、jpeg75、force/skip） | — | — | ✅ |

**实测证据**（本机 `original_image_XYZ\f05r\female41r_rs05.mat` + `mask\f05r\rs05.JPG`，`if_wei=0`，CCT=4536.472，point 33）：

> ⚠ 下表是 **2026-09-18 之前**的实测（当时 `main_rs_test.m` 还是 ipv18/ipv35 语义）。现在两侧都走 phase2，
> 所以「第 1 行」已不代表 MATLAB 当前输出，仅作历史对照保留。

| 白点 | Yw | `get_average` Lab | 生成的 dlab 文件名 |
|---|---|---|---|
| ipv18 / ipv35（= main_rs_test.m 语义） | 349.6662 | 43.7314, 12.9157, 23.7599 | `rs05_33[43.7398,12.5176,23.2922].jpg` |
| phase2（= main_rs.py 当前 L73） | 360.1208 | 43.1477, 12.7895, 23.5253 | `rs05_33[43.156,12.4283,23.1133].jpg` |

- 第 1 行的文件名与 `I_render_stimuli\rendered\rs\f05r\rs05_33[43.7398,12.5176,23.2922].mat` **完全一致**
  → Python 链路本身没问题，**只要白点回到 ipv18/ipv35 就能 1:1 复现 MATLAB**。
- `datai_ipv18_3.mat` 与 `data_ipv35_3.mat` 的 `XYZw` 完全相同（335.0658 / 349.6662 / 411.2852），
  所以 MATLAB 里「外层 ipv18 + 内层缺省 phase1」是自洽的，不矛盾。
- `rendered_python\phase2_cloud\rs\{lastPart}\` 里已有的 rs05_33 产物也是 `[43.7398,12.5176,23.2922]`
  → 说明那批产物用的白点是 ipv18/ipv35（phase1 语义），**不是**现在代码里的 phase2。rs 组到底要哪一档需要确认。

### 7.2 两个必须先知道的细节

1. `main_rs.py` / `main_rs_gpu.py` **没有 `--lut` 开关**，白点只能改 `main_rs.py` L73：
   `LUT_TYPE = "phase2"` ↔ `LUT_TYPE = "phase1"`（phase1 同时对齐 MATLAB 的内层 LUT 与外层 ipv18 白点）。
2. `--first-only` 等价 `for i=[1]`（= rs01），**不等于** `for i=[5]`。要 rs05 必须用 `--names rs05`。

### 7.3 指令：每个 model 只跑 rs05 的 point 33（本地 Windows）

主循环本身覆盖 `NEW_NAMES` 全部 20 个 subject，所以一条命令即「每个 model 都跑」。

```powershell
cd "D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python"

# CPU 版：对齐 main_rs_test.m 的 for i=[5] + for i_points=[33]
python main_rs.py --names rs05 --point 33 --dedup-mode none --save-mats --force

# GPU 版（输出到 rendered_python\gpu\phase2\rs\{lastPart}\no_uni\，与 CPU 版隔离）
python main_rs_gpu.py --names rs05 --point 33 --dedup-mode none --save-mats --force
```

参数 ↔ MATLAB 对照：

| main_rs_test.m | Python 参数 | 说明 |
|---|---|---|
| `for i =[5]` | `--names rs05` | 只跑每个 subject 的 rs05（`model_tcp_mean(5,1)` 的 CCT 自动对上） |
| `for i_points=[33]` | `--point 33` | 只渲染第 33 个点（1-based） |
| `handle.uni_mode="False"` → `lut3d_xyz2rgbKDitp1_noUni`（不去重） | `--dedup-mode none` | 不去重（逐行独立 KNN）；去重版是 `--dedup-mode matlab` |
| `handle.force_rerender="True"` | `--force` | 强制重渲染（不加时两侧都是「已存在即跳过」） |
| 全 20 个 `new_names` | 不传 `--subs`（默认全部） | 主循环自带 20 个 subject |
| 每次都存 `xyz2_file`/`outnew_file` | `--save-mats` | MATLAB 每次都存，Python 默认只出 jpg；逐像素对比必须加 |

输出位置（与 MATLAB 的 `rendered\rs\{lastPart}\` 隔离，不会互相覆盖）：

- CPU：`I_render_stimuli_python\rendered_python\{phase1|phase2}\rs\{lastPart}\{uni|no_uni}\rs05_33[...].jpg`
- GPU：`I_render_stimuli_python\rendered_python\gpu\{phase1|phase2}\rs\{lastPart}\{uni|no_uni}\rs05_33[...].jpg`
- MATLAB：`I_render_stimuli\rendered\phase2\rs\{lastPart}\no_uni\rs05_33[...].jpg`（+ `no_uni\noFaceRGB\rs05.mat`）

### 7.4 云端（AutoDL）同款指令

```bash
ssh -p 41087 root@connect.westc.seetacloud.com
cd /root/autodl-tmp/render_code/I_render_stimuli_python
export XYZ_BASE=/root/autodl-tmp/original_image_XYZ
source /root/miniconda3/bin/activate deepskin

# 每个 model 的 rs05 + point 33
python main_rs_gpu.py --names rs05 --point 33 --dedup-mode none --save-mats --force
```

注意：

- 输出目录现在是 `rendered_python\gpu\phase2\rs\{lastPart}\no_uni\`（新增 `uni|no_uni` 一级）。
- `--force` ↔ MATLAB 的 `handle.force_rerender="True"`。
- `--force` **不会**重算 `no_uni\noFaceRGB\rs05.mat` 缓存（两侧一致：文件存在且行数匹配就复用）；
  要重算缓存请手动删掉那个 `.mat`。

### 7.5 与 main_rs_test.m 数值 1:1 的做法（**已完成，采用做法 2**）

做法 2 = 两侧都走 phase2、都不去重。当前开关对照：

| 开关 | MATLAB（`main_rs_test.m` 当前值） | Python 参数 |
|---|---|---|
| LUT 类型（外层白点 + 内层 LUT） | `handle.LUT_type="phase2"` | `main_rs.py` L73 `LUT_TYPE="phase2"` |
| 去重 | `handle.uni_mode="False"` → `lut3d_xyz2rgbKDitp1_noUni` | `--dedup-mode none` |
| 已存在输出图 | `handle.force_rerender="True"` → 强制重渲染 | `--force` |
| 中间量 `xyz2_img`/`outnew_img` | 每次都存（`img_AddRender_simp.m` L93-97/L146-150） | `--save-mats` |

> 若改回做法 1（Python 侧 `LUT_TYPE="phase1"`，对齐旧的 ipv18/ipv35 白点），
> 需同时把 `main_rs_test.m` 的 `handle.LUT_type` 改回 `"phase1"`，
> 并注意 `rendered\{LUT_type}\` 一级目录会随之变化（两边都要换目录才有意义）。

> 对比口径统一后，再用 `test_debug.m`（`iOr='rs'` 时已禁用 CardMask）逐像素核对 ΔE2000 才算有效。

