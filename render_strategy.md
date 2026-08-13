# I_render_stimuli → Python 迁移：省 Token / 防爆上下文策略

> 目标：把 MATLAB 渲染项目 `I_render_stimuli` 迁移为 GPU Python 项目 `I_render_stimuli_python`，
> 核心是加速 `lut3d_xyz2rgbKDitp1.m` 里的 KNN 插值，部署到云端 GPU 实例（inst1）。

## 一、上一会话为什么爆上下文（证据）

| 事实 | 证据 |
|---|---|
| utils 有 46 个 `.m` 文件 | `I_render_stimuli\utils\` 目录列表 |
| 两个入口合计 500+ 行 | `main_i_test.m` 259 行 + `main_i.m` 257 行 |
| 核心文件也不小 | `img_AddRender_simp.m` 110 行、`lut3d_xyz2rgbKDitp1.m` 94 行 |

**根因**：上一会话试图「一次性读完所有 .m + 一次性生成 8 个 .py + 大段讨论」，
46 个 MATLAB 函数原文 + 8 个 Python 源码 + 反复讨论塞进同一上下文，必然超限。

**关键事实**：真正需要迁移的只有约 11 个函数（主链路），不是 46 个。

## 二、核心原则（一句话）

**MATLAB 源码永远不进主上下文，由 code-explorer 子代理读完后只回传「函数规格摘要」（I/O + 算法一句话）。主上下文只维护一份规格表 `render_spec.md`，以后每轮只对照这张表写代码，不再回头读 .m 原文。**

## 三、三步策略

1. **先产出「依赖调用图 + 函数规格表」**（用子代理做，成本隔离在主上下文外）
   - 子代理逐个读依赖链上的函数，回传每个函数的：入参 / 出参 / 内部调用了谁 / 算法一句话 / 依赖的 .mat 数据文件
   - 主上下文只落一份约 1 页的规格表（`render_spec.md`）

2. **按依赖自底向上，一个模块 = 一个独立任务单元**
   - 每个单元：子代理读 1 个 `.m` + 主上下文写 1 个 `.py`
   - 单元之间靠规格表衔接，互不依赖源码

3. **每个模块配一个「数值锚点」**（增量验证，防止最后一次性崩盘）
   - 迁移完一个函数，立刻用同一份输入对比 MATLAB 输出 vs Python 输出是否逐点一致
   - 一致了再进下一模块

## 四、落地批次表

| 批次 | 模块 | 迁移函数 | 数值锚点 |
|---|---|---|---|
| 0 | `data_io.py` | 读 .mat / .xlsx / .jpg | `XYZ.shape == MATLAB size` |
| 1 | `color_utils.py` | `xyz2lab` `lab2xyz2` `deltaE2000`（含 `selectcmf`） | 同 Lab 输入逐点一致 |
| 2 | `cat_adjust.py` | `CAT_lab2lab1` `adjust_dlabs*` | 同 dlab 输入一致 |
| 3 | `mask.py` | `read_bull` `get_average` | 逻辑索引 mask 一致 |
| 4 | `lut_gpu.py` | `lut3d_xyz2rgbKDitp1` GPU 版 | 同 xyz2 输入 vs MATLAB 逐像素一致 |
| 5 | `render_core.py` | `img_AddRender_simp` | 单图单点输出 jpg 一致 |
| 6 | `main_i.py` | 主循环（去 imshow） | f04i 单 subject 跑通 |

- 批次 0-3 纯函数、无 GPU 依赖、本地可验证
- 批次 4 是核心瓶颈（GPU KNN）
- 批次 5-6 是组装

## 五、每批执行规则（防再爆）

- 一个批次 = 一个任务单元，只读 1 个 .m（子代理读），主上下文只写 1 个 .py
- 写代码前先看 `render_spec.md` 里对应函数的规格，**不再读 .m 原文**
- 每批完成后立即跑「数值锚点」对比，记录结果，再进下一批
- 遇到依赖缺失的函数，先补进 spec 再迁移，不要临时硬读源码
