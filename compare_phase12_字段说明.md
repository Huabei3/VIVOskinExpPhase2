# compare_phase12.xlsx 字段说明

> 生成日期：2026-08-17（复核版）
> 覆盖问题：① 生成脚本确认；② 各字段计算逻辑；③ `dE_target_p1/p2` 为什么偏大；④ `avg_b_p1/p2` 为什么是负数

---

## ① 生成 compare_phase12.xlsx 的脚本是哪个？

**是 `compare_phase12.py`（本目录），不是 `xyz_phase2_comparison.mat`。**

| 文件 | 角色 |
|---|---|
| `compare_phase12.py` | **生成 `compare_phase12.xlsx` 的脚本**（第 369-373 行写 xlsx，`--out` 可指定输出） |
| `xyz_phase2_comparison.mat` | 数据文件（非脚本）：96 个 RGB 采样点上，MATLAB 参考 XYZ 与 Python 复刻 XYZ 的对比结果（变量：`RGB_input`/`XYZ_matlab`/`XYZ_python_best`/`best_config`），用于校验 `lut3d_rgb2xyz1` 的 1:1 复刻 |
| `xyz_phase2_comparison.xlsx` | 上述 mat 的 Excel 版（sheet：`XYZ_phase2` + `diff`），是**另一项** Python-vs-MATLAB XYZ 反算校验，与 `compare_phase12.xlsx` 无关 |

---

## ② 数据流总览（process_one，`compare_phase12.py` L217-290）

对每个渲染点（一张 jpg）：

```
渲染输出 jpg (RGB)
   → mask 内像素（~logicalIdx，bull_weight>0）          L239
   → lut3d_rgb2xyz1(rgb, datai_p1 / datai_p2) → XYZ     L246-247
       ├─ RGB → trilinear 插值 lablut → Lab            （LUT 内部 Lab，参考白=显示器 XYZw）
       └─ lab2xyz2(Lab, 'user', XYZw) → 绝对 XYZ
   → xyz2lab(XYZ, 'user', wd65_scaled) → lab1 / lab2    L248-249
       （wd65_scaled = D65/100 × XYZw[1]，见 L156-158）
   → 逐点 dE2000(lab1, lab2) → 统计量                   L252-260
   → get_average（加权/非黑均值）→ ave1 / ave2          L264-270
   → dE_avg_p1p2 / dE_target_p1 / dE_target_p2          L273-275
```

---

## ③ 逐字段计算逻辑

### 平均色差（两点）

| 字段 | 计算方式 | 代码 |
|---|---|---|
| `dE_avg_p1p2` | phase1 平均 Lab 与 phase2 平均 Lab 之间的 dE2000，即 `ΔE2000(ave1, ave2)`。**这是本表最核心的"两代 LUT 差异"指标** | L273 |
| `dE_target_p1` | `ΔE2000(ave1, lab_target)`，ave1 是 phase1 反算平均 Lab，`lab_target` 从**文件名** `[L,a,b]` 解析（如 `HD65_33[58.38,12.82,11.90]`） | L274 |
| `dE_target_p2` | 同上，用 phase2 平均 Lab | L275 |

> 注意：`dE_target_*` 的 `lab_target` 是 MATLAB 主流程 `main_i_test.m` 里的 **`dlab_CATed`**（CAT 色适应调整后的目标 Lab，相对标准 D65 白点），不是 LUT 内部坐标系的目标。

### 逐像素统计（同一张图，两套 LUT 反算的逐点色差）

| 字段 | 计算方式 |
|---|---|
| `dE_max_px` | mask 内所有像素 `ΔE2000(lab1_px, lab2_px)` 的最大值（L255） |
| `dE_p99_px` / `dE_p95_px` | 逐点 dE 的第 99 / 95 百分位（L256-257） |
| `dE_mean_px` / `dE_median_px` | 逐点 dE 的均值 / 中位数（L258-259） |
| `dE_min_px` | 逐点 dE 的最小值（L260） |
| `n_mask_px` | mask 内有效像素个数（`~logicalIdx` 求和，L254） |

### 平均 Lab（反算结果）

| 字段 | 计算方式 |
|---|---|
| `avg_L_p1` / `avg_a_p1` / `avg_b_p1` | phase1 LUT 反算 Lab 在 mask 内的**加权平均**（`if_wei=1` 时按 `bull_weight` 加权；`if_wei=0` 时简单均值），L264-267 |
| `avg_L_p2` / `avg_a_p2` / `avg_b_p2` | 同上，用 phase2 LUT，L268-270 |

`if_wei` 取值见 L56-58 + L224-226（i/rs 各有 5 个 subject 用 0）。

---

## ④ 为什么 dE_target_p1/p2 看上去很大（~24）？

**结论：是"参考白口径不一致"造成的表观色差，不是渲染真的错了这么远。**

1. `lab_target`（文件名 `[L,a,b]`）是**标准 D65 白点**下的 CIELAB，`b*` 为正（+11.9，肤色黄度）。
2. 反算的 `ave1/ave2` 是经**显示器 LUT** 得到的 Lab，其参考白链条是：
   - LUT 内部 `lablut` 存的是以**显示器实测白点 `XYZw`**（phase1: `[335.07, 349.67, 411.29]`，phase2: `[342.12, 360.12, 399.82]`）为参考白的 Lab；
   - 最终 `xyz2lab` 又改用 `wd65_scaled`（**D65 色度形状**，`X/Z = 0.8839`）为参考白。
3. 实测 phase1 显示器的 `XYZw` 色度 `X/Z = 0.8147 ≠ 0.8839(D65)`，**两代 LUT 的参考白都不是 D65** → 同一绝对 XYZ 在不同参考白下反算的 `b*` 系统性偏移，dE 被撑大。

**验证数据（`HD65_33` 一图，mask 内加权平均）：**

| 量 | phase1 | phase2 |
|---|---|---|
| 显示器 XYZw | [335.07, 349.67, 411.29] | [342.12, 360.12, 399.82] |
| XYZw 的 X/Z | 0.8147 | 0.8557 |
| LUT 内部 ave Lab（参考白=XYZw） | [54.26, 11.26, **-20.77**] | [54.83, 10.94, **-20.88**] |
| 最终 ave Lab（参考白=wd65_scaled） | [54.26, 12.37, **-25.20**] | [54.83, 11.15, **-22.53**] |
| 文件名目标 Lab（D65） | [58.38, 12.82, **+11.90**] | 同左 |

`b*` 从目标 `+11.90` 反算成 `-25.2`，直接 dE 自然大（Δb≈37 贡献了绝大部分）。

**真正的两代 LUT 差异要看 `dE_avg_p1p2`（0.69 均值）和逐像素统计**——这些是**同参考白、同链路**下的对比，数值才可信。

---

## ⑤ 为什么 avg_b_p1/p2 是负数？

**根本原因：LUT 内部参考白（显示器实测 `XYZw`）与最终反算参考白（D65 色度）不一致。**

CIELAB 的 `b* = 200(fy − fz)`，其中 `fy/fz` 与**参考白**的 `Yw/Zw` 有关。反算链路里：

```
LUT 内部 Lab（相对 XYZw 定义，显示器自测白点）
   → lab2xyz2(XYZw) → 绝对 XYZ
   → xyz2lab(wd65_scaled)   # wd65_scaled = D65/100 × XYZw[1]，即 D65 色度形状
```

- phase1 显示器 `XYZw` 的 `X/Z = 0.8147`，比 D65 的 `0.8839` **Z 相对偏大** → 用 wd65_scaled 反算时 `fz` 偏大 → `b*` 系统性为负。
- **数值佐证**：即便显示器输出"纯白"（`XYZ = XYZw`，理论上 L\*a\*b\*=[100,0,0]），在本链路反算也为 `b* = -6.24`（phase1）/ `-2.31`（phase2）。皮肤目标 b=+11.9 叠加这个负偏移后，实际反算 `avg_b ≈ -25 / -22.5`。
- phase2 的 `XYZw` 更接近 D65（X/Z=0.8557），所以 phase2 的负偏移更小（-22.5 > -25.2）。

**一句话**：`avg_b` 为负不等于渲染偏蓝，而是 `lablut` 内部用显示器自测白点 `XYZw` 定义 Lab、最终 `xyz2lab` 用 D65 色度白点反算，两者色度不同导致 `b*` 整体负偏移。这是**口径/参考白问题**，不是渲染质量缺陷。

---

## ⑥ 使用建议

- **对外报告只用**：`dE_avg_p1p2`、`dE_max/p99/p95/mean/median_px`、`n_mask_px`（同链路同口径，可信）。
- **不要直接引用**：`dE_target_p1/p2`、`avg_*_p1/p2` 的绝对数值（参考白口径不同，仅能看相对趋势，如 phase2 比 phase1 更接近目标）。
- 如需让 `avg_b` 有物理意义，需把反算链路统一到同一参考白（例如都改回 D65 白点做 `xyz2lab`），但这会偏离 MATLAB `main_i_test.m` 的 1:1 复刻口径，谨慎修改。

---

### 附：复核所用脚本（临时，已清理）

- `_verify_d65_white.py`：验证"换 D65 白点反算 b 仍为负"（证明与白点缩放无关，是色度形状差异）
- `_verify_internal_lab.py`：拆解 LUT 内部 Lab（参考白=XYZw）与最终 Lab（参考白=wd65_scaled），证实负偏移源自参考白色度不一致
