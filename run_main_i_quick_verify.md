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
python main_i.py --subs f01 f02 f03 m01 m02 m03 f07 f08 m07 m08 f09 f10 m09 m10 --first-only --point 1 --resize-factor 6
```

说明：

- `--subs` 后 16 个 subject 与 main_i_test.m 的 `new_names` 一一对应（Python 默认 `NEW_NAMES` 是 20 个，含 f04-f06/m04-m06，故需显式指定 16 个）。
- `--first-only` + `--point 1` 等价 `for i=[1]` + `for i_points=[startCenter]`。
- `--resize-factor 6` 等价 4 行 `./6` resize。
- 输出目录：`rendered_python/phase2/i/{lastPart}/`（Python 独立目录，不覆盖 MATLAB 的 `rendered_*` 结果）。

## 4. 还原成非快速验证（跑全量）

```powershell
python main_i.py --subs f01 f02 f03 m01 m02 m03 f07 f08 m07 m08 f09 f10 m09 m10
```

（去掉 `--first-only` / `--point 1` / `--resize-factor 6`，即跑全部图、全部点、不缩放）

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

# 有去重（1:1 对齐 MATLAB）
python main_i.py --subs f01 --first-only --point 1 --resize-factor 6 --uni

# 无去重
python main_i.py --subs f01 --first-only --point 1 --resize-factor 6 --no-uni
```

## 6. 完整运行指令（含 cd，当前 main_i_test.m 逻辑 1:1 复跑）

### 6.1 一键复制（PowerShell）

```powershell
cd "D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python"
python main_i.py --subs f01 f02 f03 m01 m02 m03 f07 f08 m07 m08 f09 f10 m09 m10 --first-only --point 1 --resize-factor 6 --uni
```

### 6.2 参数 ↔ 当前 main_i_test.m 对照

| main_i_test.m（当前） | Python 参数 | 说明 |
|---|---|---|
| `new_names` = 16 个（f04-f06/m04-m06 已注释） | `--subs f01 f02 f03 m01 m02 m03 f07 f08 m07 m08 f09 f10 m09 m10` | 16 个 i subject |
| `for i=[1]` | `--first-only` | 只跑每个 subject 第 1 张图 |
| `for i_points=[startCenter]`（startCenter=1） | `--point 1` | 只跑第 1 个点 |
| 4 行 `imresize ./6`（L83/96/103/113） | `--resize-factor 6` | 缩小 6 倍 |
| `lut3d_xyz2rgbKDitp1.m`（uniquetol 有去重） | `--uni` | 有去重，1:1 对齐 |

### 6.3 resize 现况（已更新，重要）

- 4 处 resize 现已全部走 `imresize_matlab`（`matlab_resize.py`），精确复现 MATLAB `imresize` 的 bicubic（Keys a=-0.5）+ 抗锯齿 + scale 计算 + 维度顺序 + 边界反射。
- double 路径逐像素对齐 2.6e-13；uint8 路径已对齐「每步 round+clip」（bicubic 负 overshoot 每步 clip 到 0，而非最后一次性 clip）。
- 因此 `--resize-factor 6` 下 `get_average` 整条链路（resize → lab1 → read_bull → get_average）已与 MATLAB 逐位一致（实测 average 10 位小数完全一致）。
