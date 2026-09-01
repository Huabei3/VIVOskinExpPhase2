# 完整渲染运行指令 — main_i.py / main_rs.py

本文件记录**覆盖每一个 model、每一个 scene、每一个 point** 的完整运行指令。
代码位置：`I_render_stimuli_python/main_i.py`（i 组，批次6）、`main_rs.py`（rs 组，批次7）。

---

## 0. 脚本概览

| 脚本 | 组别 | model 数 | scene 数 | point 数 | 单 model 输出量 | 全量输出量 | 输出目录 |
|---|---|---|---|---|---|---|---|
| `main_i.py` | i（室内/实验室） | 20（f01~m10） | 21（H3K~MD65） | 33 | 21 × 33 = 693 张 | 13,860 张 | `I_render_stimuli/rendered_python/phase2/i/{model}i/` |
| `main_rs.py` | r（实景） | 20（f01~m10） | 14（rs01~rs14） | 33 | 14 × 33 = 462 张 | 9,240 张 | `I_render_stimuli/rendered_python/rs/{model}r/` |
| **合计** | — | 40 | 35 | 33 | — | **23,100 张 jpg** | — |

> 说明：全量 23,100 张与 GT（`toMax_gt.xlsx` 23,100 条目）一一对应，即完整渲染 = 全部刺激。

### 20 个 model（`NEW_NAMES`，main_i.py L65-68 / main_rs.py L62-65）

```
f04 f05 f06 m04 m05 m06 f01 f02 f03 m01 m02 m03 f07 f08 m07 m08 f09 f10 m09 m10
```

### scene 与 point

- **i 组 21 个 scene（CT 名，main_i.py L58-62）**：`H3K H4K H5K H6K H7K H8K HD65 L3K L4K L5K L6K L7K L8K LD65 M3K M4K M5K M6K M7K M8K MD65`
- **rs 组 14 个 scene（main_rs.py `scene_idx = int(stem[-2:]) - 1`）**：`rs01` ~ `rs14`
- **point：33 个**（`points_added_33.xlsx`，(33,3)，`--point N` 为 1-based，即 1~33）

---

## 1. 前置条件

### 1.1 数据与目录结构（相对 `C_VIVO_skin_project/`）

```
I_render_stimuli/
├── mask/{model}{i|r}/*.jpg        # 原图 + bull（同名）
├── mask/{model}i/nosd/            # 仅 i 组需要（bull_nosd，缺则回退 bull）
├── documents/aveSkin/             # aveLab_D65_{i_type}.mat、C_Lpara
├── documents/aveSkin/{model}i/autoNhand_scaleoverLUT.mat   # 仅 rs 组 i_type=4
├── light_r/model_tcp/{model}.mat  # 仅 rs 组（model_tcp_mean, 14 行 CCT）
├── points_added_33.xlsx           # 33 个点
├── rendered_python/               # 输出（Python 独立目录，不覆盖 MATLAB 结果）
├── Shadow/mask/{model}i/nosd/     # i 组 nosd 掩码
A_characterization/display_model/  # data_ipv30_phase2_3.mat（i）、data_ipv18_3.mat（rs）
original_image_XYZ/{model}{i|r}/*.mat   # XYZ 输入（路径由环境变量 XYZ_BASE 指定）
```

### 1.2 依赖与路径

- 依赖：`numpy`、`Pillow`；云端读取 v7.3 mat 需要 `h5py`（`pip install h5py`）。
- **环境激活（云端必须）**：先 `conda activate deepskin`。shell 提示符是 `(base)` 就说明没激活，
  直接跑会找不到依赖或 Python 版本不对；也可以不激活，用完整解释器路径
  `/root/miniconda3/envs/deepskin/bin/python` 代替 `python`。
- **云端是 Linux，不要粘贴 Windows 路径**（如 `cd D:\work\...`，会报
  `No such file or directory`）。云端代码目录是 `/root/autodl-tmp/render_code/I_render_stimuli_python`。
- `XYZ_BASE`：脚本默认 `D:\work\VIVOSkinExpe\original_image_XYZ`（main_i.py L55 / main_rs.py L55）；
  在云端用环境变量覆盖：`export XYZ_BASE=/root/autodl-tmp/original_image_XYZ`。

### 1.3 幂等性

已存在的输出 jpg **默认跳过**（不重渲染，`out_path.exists() and not force`，main_i.py L235 / main_rs.py L239）。
重跑是安全的；要强制重渲染加 `--force`。

---

## 2. 完整运行（覆盖全部 40 model × 35 scene × 33 point）

默认参数即全量：不传 `--subs` 时遍历全部 20 个 model（main_i.py L286 / main_rs.py L291）。

### 2.1 本地 Windows（先进入脚本目录）

```bash
cd D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python

python main_i.py        # 13,860 张（20 model × 21 scene × 33 point）
python main_rs.py       #  9,240 张（20 model × 14 scene × 33 point）
```

### 2.2 云端（先激活环境，再设置 XYZ_BASE）

```bash
conda activate deepskin                          # ① 激活渲染环境（必须，否则停留在 base）
cd /root/autodl-tmp/render_code/I_render_stimuli_python   # ② 云端代码目录（不要粘 Windows 路径）
export XYZ_BASE=/root/autodl-tmp/original_image_XYZ        # ③ 数据根目录

python main_i.py        # 13,860 张（20 model × 21 scene × 33 point）
python main_rs.py       #  9,240 张（20 model × 14 scene × 33 point）
```

> 建议先 `--dry-run` 核对计划，再正式跑；全量耗时取决于单点渲染速度（LUT 查找表逐点），可分段按 model 跑（见 §3）。

---

## 3. 按 model 运行（每一个 model 一条命令，自动覆盖该 model 全部 scene × point）

### 3.1 main_i.py — 20 条（`--subs` 可带 `i` 后缀，脚本自动去掉，main_i.py L288）

```bash
python main_i.py --subs f04i
python main_i.py --subs f05i
python main_i.py --subs f06i
python main_i.py --subs m04i
python main_i.py --subs m05i
python main_i.py --subs m06i
python main_i.py --subs f01i
python main_i.py --subs f02i
python main_i.py --subs f03i
python main_i.py --subs m01i
python main_i.py --subs m02i
python main_i.py --subs m03i
python main_i.py --subs f07i
python main_i.py --subs f08i
python main_i.py --subs m07i
python main_i.py --subs m08i
python main_i.py --subs f09i
python main_i.py --subs f10i
python main_i.py --subs m09i
python main_i.py --subs m10i
```

### 3.2 main_rs.py — 20 条（`--subs` 可带 `r` 后缀，main_rs.py L293）

```bash
python main_rs.py --subs f04r
python main_rs.py --subs f05r
python main_rs.py --subs f06r
python main_rs.py --subs m04r
python main_rs.py --subs m05r
python main_rs.py --subs m06r
python main_rs.py --subs f01r
python main_rs.py --subs f02r
python main_rs.py --subs f03r
python main_rs.py --subs m01r
python main_rs.py --subs m02r
python main_rs.py --subs m03r
python main_rs.py --subs f07r
python main_rs.py --subs f08r
python main_rs.py --subs m07r
python main_rs.py --subs m08r
python main_rs.py --subs f09r
python main_rs.py --subs f10r
python main_rs.py --subs m09r
python main_rs.py --subs m10r
```

### 3.3 云端 bash 循环版（一次跑完 40 个 model）

```bash
conda activate deepskin
export XYZ_BASE=/root/autodl-tmp/original_image_XYZ
PY=/root/miniconda3/envs/deepskin/bin/python
cd /root/autodl-tmp/render_code/I_render_stimuli_python

for m in f04 f05 f06 m04 m05 m06 f01 f02 f03 m01 m02 m03 f07 f08 m07 m08 f09 f10 m09 m10; do
  $PY main_i.py --subs ${m}i
done

for m in f04 f05 f06 m04 m05 m06 f01 f02 f03 m01 m02 m03 f07 f08 m07 m08 f09 f10 m09 m10; do
  $PY main_rs.py --subs ${m}r
done
```

---

## 4. 按 model + scene 运行（单 scene 调试）

### 4.1 指令模板

```bash
# i 组（scene 用 21 个 CT 名之一）
python main_i.py --subs {model}i --names {CT_NAME}
# 例：只渲染 f04i 的 H3K 场景（33 张）
python main_i.py --subs f04i --names H3K

# rs 组（scene 用 rs01~rs14 之一）
python main_rs.py --subs {model}r --names {SCENE}
# 例：只渲染 f04r 的 rs01 场景（33 张）
python main_rs.py --subs f04r --names rs01
```

> `--names` 可传多个，空格分隔，如 `--names H3K H4K HD65`（main_i.py L271 / main_rs.py L276）。

### 4.2 i 组 21 个 scene 名（CT_NAMES）

```
H3K H4K H5K H6K H7K H8K HD65
L3K L4K L5K L6K L7K L8K LD65
M3K M4K M5K M6K M7K M8K MD65
```

### 4.3 rs 组 14 个 scene 名

```
rs01 rs02 rs03 rs04 rs05 rs06 rs07
rs08 rs09 rs10 rs11 rs12 rs13 rs14
```

---

## 5. 按 model + scene + point 运行（单点调试）

```bash
# i 组：只渲染 f04i / H3K 场景 / 第 1 个点
python main_i.py --subs f04i --names H3K --point 1

# rs 组：只渲染 f04r / rs01 场景 / 第 5 个点
python main_rs.py --subs f04r --names rs01 --point 5
```

- `--point N` 为 **1-based**（1 ~ 33），对应 `points_added_33.xlsx` 第 N 行（main_i.py L280 / main_rs.py L285）。
- 输出文件名 `{stem}_{NN}[L,a,b].jpg`，`NN` 即 point 序号（如 `H3K_01[...].jpg`）。

---

## 6. 常用参数速查

| 参数 | 作用 | 代码位置 |
|---|---|---|
| `--subs {model}{i\|r} ...` | 指定 subject（可多个，空格分隔） | main_i.py L270 / main_rs.py L275 |
| `--names {scene} ...` | scene 过滤（i: CT 名 / rs: rsXX，可多个） | main_i.py L271 / main_rs.py L276 |
| `--point N` | 只渲染第 N 个点（1-based） | main_i.py L280 / main_rs.py L285 |
| `--points N` | 每个 scene 只渲染前 N 个点 | main_i.py L276 / main_rs.py L281 |
| `--dry-run` | 只打印计划，不渲染 | main_i.py L273 / main_rs.py L278 |
| `--force` | 强制重渲染（忽略已存在文件） | main_i.py L274 / main_rs.py L279 |
| `--first-only` | 只渲染每个 model 的第一张图（对齐测试模式） | main_i.py L278 / main_rs.py L283 |
| `--quality N` | JPEG 质量（MATLAB 默认 75） | main_i.py L272 / main_rs.py L277 |
| `--save-mats` | 额外保存调试 mat（xyz2/outnew） | main_i.py L282 / main_rs.py L287 |

---

## 7. 校验与数量核对

1. **dry-run 先行**：`python main_i.py --dry-run` / `python main_rs.py --dry-run`，核对每个 model 的
   `files=21`（i 组）/ `files=14`（rs 组）。
2. **输出统计**：每跑完一个 model，结尾会打印 `done: rendered=N existing_skip=M`。
3. **全量核对**（bash）：

```bash
# i 组应 13,860 张，rs 组应 9,240 张，合计 23,100 张
find I_render_stimuli/rendered_python/phase2/i -name "*.jpg" | wc -l
find I_render_stimuli/rendered_python/rs -name "*.jpg" | wc -l
```

4. **已知例外**：`f04i` 目录含 22 个 jpg、`m05i` 含 34 个 jpg（比 21 多），多出的文件 stem 不在
   `CT_NAMES` 中，会打印 `WARN stem 不在 CT_NAMES，skip`，属正常行为，不影响全量结果。

---

## 8. 云端常见报错排查

| 报错 | 原因 | 解决 |
|---|---|---|
| `bash: cd: D:workVIVOSkinExpe...: No such file or directory` | 把 Windows 路径粘到了云端（Linux 不认 `D:\`、反斜杠） | 用云端路径 `cd /root/autodl-tmp/render_code/I_render_stimuli_python` |
| `python: can't open file 'main_i.py': No such file or directory` | 上一步 cd 失败，shell 还停留在 `~/autodl-tmp`，目录里没有该脚本 | 先成功 cd 到代码目录，再 `ls` 确认有 `main_i.py` |
| 提示符是 `(base)` | 没激活环境 | `conda activate deepskin`，或改用 `/root/miniconda3/envs/deepskin/bin/python main_i.py` |
| `ModuleNotFoundError: numpy / PIL / h5py` | 环境不对或 h5py 缺失 | 确认 `conda activate deepskin`；h5py 缺失时 `pip install h5py`（读取 v7.3 mat 必需） |
| `WARN no XYZ file, skip` / `noFaceRGB` 相关错误 | `XYZ_BASE` 未设置或指向错误 | `export XYZ_BASE=/root/autodl-tmp/original_image_XYZ` |

---

## 9. 并行跑「某几个模特」的指令写法

### 9.1 核心语法：`--subs` 一次传多个模特

```bash
# 只跑 f04i、f05i 两个模特（一个命令内串行处理完这两个）
python main_i.py --subs f04i f05i

# rs 组同理（`r` 后缀）
python main_rs.py --subs f04r f05r

# 任意个数、任意顺序都可以，空格分隔
python main_i.py --subs m05i f09i f04i

# 先 dry-run 核对分片计划再正式跑
python main_i.py --subs f04i f05i m05i --dry-run
```

> ⚠️ **关键**：一个终端里传多个 `--subs` 是**同一个进程内串行**，不会变快。
> 要真正并行，必须**开多个终端 / 多个后台进程**，每个进程各跑不同的一组模特（见 §9.2）。

### 9.2 云端并行：开 4 个后台任务（每个跑 5 个模特）

按 `NEW_NAMES` 顺序把 20 个 i 模特均分 4 组，每组一条 `nohup ... &` 命令即可并行：

```bash
conda activate deepskin
export XYZ_BASE=/root/autodl-tmp/original_image_XYZ
cd /root/autodl-tmp/render_code/I_render_stimuli_python

# 任务1：f 组 01-05
nohup python main_i.py --subs f01i f02i f03i f04i f05i > run_f01_05i.log 2>&1 &

# 任务2：m 组 01-05
nohup python main_i.py --subs m01i m02i m03i m04i m05i > run_m01_05i.log 2>&1 &

# 任务3：f 组 06-10
nohup python main_i.py --subs f06i f07i f08i f09i f10i > run_f06_10i.log 2>&1 &

# 任务4：m 组 06-10
nohup python main_i.py --subs m06i m07i m08i m09i m10i > run_m06_10i.log 2>&1 &
```

rs 组同理，把 `i` 换成 `r`、输出目录换成 `rendered_python/rs`：

| 后台任务 | rs 组指令（同样 4 条并行） |
|---|---|
| 任务1 | `nohup python main_rs.py --subs f01r f02r f03r f04r f05r > run_f01_05r.log 2>&1 &` |
| 任务2 | `nohup python main_rs.py --subs m01r m02r m03r m04r m05r > run_m01_05r.log 2>&1 &` |
| 任务3 | `nohup python main_rs.py --subs f06r f07r f08r f09r f10r > run_f06_10r.log 2>&1 &` |
| 任务4 | `nohup python main_rs.py --subs m06r m07r m08r m09r m10r > run_m06_10r.log 2>&1 &` |

> 为什么这样分是安全的：每个 model 的输出目录、`noFaceRGB` 缓存彼此独立（main_i.py L220-228），
> 分片之间不会写冲突；已存在的 jpg 默认自动跳过，就算分组重叠或重跑也安全。

### 9.3 查看并行进度

```bash
tail -f run_f01_05i.log          # 实时看某个任务的日志
ps aux | grep main_i.py          # 看还有哪些渲染进程在跑
grep -c "done:" run_*.log        # 数每个任务完成了几个 model
find I_render_stimuli/rendered_python/phase2/i -name "*.jpg" | wc -l   # 已产出图数（i 组全量=13,860）
find I_render_stimuli/rendered_python/rs -name "*.jpg" | wc -l          # rs 组全量=9,240
```

### 9.4 任意组合速查

| 想要的效果 | 指令 |
|---|---|
| 跑任意几个模特（i 组） | `python main_i.py --subs f04i m05i f09i` |
| 跑任意几个模特（rs 组） | `python main_rs.py --subs f04r m05r f09r` |
| 先验证分片计划不渲染 | 上面指令末尾加 `--dry-run` |
| 某几个模特 + 只跑某几个 scene | 加 `--names`（见 §4） |
| 某几个模特 + 只跑某几个 point | 加 `--point` / `--points`（见 §5） |
| 强制重渲染（忽略已存在） | 末尾加 `--force` |

### 9.5 云端 tmux 一键开 16 块（每块一个模特，前台实时输出）

不用 screen、不用 nohup，一条脚本创建 16 个 pane，每块前台跑一个模特、实时滚日志。

```bash
#!/bin/bash
MODELS=(f01i f02i f03i f04i f05i f06i f07i f08i f09i f10i m01i m02i m03i m04i m05i m06i)

tmux kill-session -t render 2>/dev/null
tmux new-session -d -s render

for i in "${!MODELS[@]}"; do
  if [ "$i" -gt 0 ]; then
    tmux select-layout -t render tiled
    tmux split-window -t render -h
  fi
  tmux send-keys -t render \
    "cd /root/autodl-tmp/render_code/I_render_stimuli_python && export XYZ_BASE=/root/autodl-tmp/original_image_XYZ && /root/miniconda3/envs/deepskin/bin/python main_i.py --subs ${MODELS[$i]}" Enter
done

tmux select-layout -t render tiled
tmux attach -t render
```

**用法**：把上面脚本存成 `start16.sh` 后 `bash start16.sh`，或直接在终端整段粘贴回车。

**查看/操作**（都在 tmux 会话内）：

| 操作 | 按键 |
|---|---|
| 切换 pane | `Ctrl-b` 然后按方向键 |
| 放大当前 pane 全屏 / 恢复 | `Ctrl-b` 再按 `z` |
| 离开会话（任务继续跑） | `Ctrl-b` 再按 `d` |
| 回来看进度 | `tmux attach -t render` |
| 滚动看某个 pane 历史输出 | `Ctrl-b` 再按 `[`，方向键/翻页，`q` 退出 |

**3 个注意点**：

1. **脚本已改用完整解释器路径 `/root/miniconda3/envs/deepskin/bin/python`**，不依赖 `conda activate`。
   但换新实例时请先确认该路径存在：`ls /root/miniconda3/envs/deepskin/bin/python`。
2. **网页终端窗口小（约 36 行）时，`split-window` 默认上下分割会报 `no space for new pane`**，
   所以脚本用 `-h` 左右分割 + 每次 split 前先 `select-layout tiled` 平铺，已规避此坑。
   16 格平铺后每格很小，看某格全屏按 `Ctrl-b z`。
3. **`MODELS` 数组只覆盖 i 组前 16 个**，`m07i m08i m09i m10i` 未包含；跑完改数组补跑即可
   （已渲染的 jpg 会自动跳过）。rs 组同理，把数组元素换成 `f01r ... m10r`、脚本里 `main_i.py` 换成 `main_rs.py`。



# 一键开16个
#!/bin/bash
MODELS=(f01i f02i f03i f04i f05i f06i f07i f08i f09i f10i m01i m02i m03i m04i m05i m06i)

tmux kill-session -t render 2>/dev/null
tmux new-session -d -s render

for i in "${!MODELS[@]}"; do
  if [ "$i" -gt 0 ]; then
    tmux select-layout -t render tiled
    tmux split-window -t render -h
  fi
  tmux send-keys -t render \
    "cd /root/autodl-tmp/render_code/I_render_stimuli_python && export XYZ_BASE=/root/autodl-tmp/original_image_XYZ && /root/miniconda3/envs/deepskin/bin/python main_i.py --subs ${MODELS[$i]}" Enter
done

tmux select-layout -t render tiled
tmux attach -t render
