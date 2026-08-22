% compare_phase12.m — phase1(ipv35) vs phase2(ipv30_phase2_3) LUT 渲染对比 (MATLAB 版)
%
% 1:1 复刻 Python 版 compare_phase12.py（对齐 main_i_test.m 的 plot_pic_dE）：
%   读 phase2 渲染 jpg -> lut3d_rgb2xyz1(正向LUT) -> XYZ -> xyz2lab(wd65_scaled)
%   -> mask 内逐点 dE2000 + get_average -> 写 xlsx(summary + meta)
%
% 关键差异（avg_b 为负的根因）：
%   Python 版 lablut.reshape(cubeL,cubeL,cubeL,3) 是 numpy C 序（行主序）；
%   MATLAB 原生 reshape(lablut(:,1),cubeL,cubeL,cubeL) 是列主序（Fortran 序）。
%   两者对 729 行 lablut 展开成 9x9x9 的 R/G/B 维度顺序相反，导致 Python 把肉色
%   算成 b*<0。数值验证：RGB=[200 150 130] -> MATLAB 列主序 b*=+32.5；Python C 序 b*=-32.2。
%   本脚本用原生列主序，b* 为正确正值。先跑 CHECK_SANITY=1 自检确认。
%
% 依赖 ../utils/：lut3d_rgb2xyz1.m xyz2lab.m lab2xyz2.m deltaE2000.m get_average.m read_bull.m
% 用法：改下面参数后直接 Run。

% ---------------- 模块 0：参数 ----------------
mode  = 'local_test'; % 'local_test'(逻辑与现在完全一样) | 'cloud_test'(额外读云端渲染图, 输出 compare_phase12_cloud.xlsx)
GROUP = 'all';        % 'all' | 'i' | 'rs'
SUBS  = {};           % 空=全部；例如 {'f04i'}
LIMIT = [];           % 空=不限；例如 2
CHECK_SANITY = 1;     % 1=跑 RGB 肉色自检
DEBUG_FIRST = 1;      % 1=对第 1 个点打印逐步中间值

% ---------------- 模块 1：路径 ----------------
PROJ      = 'D:/work/VIVOSkinExpe/PeggySkinBackup/A_code/C_VIVO_skin_project';
RENDER_I  = fullfile(PROJ,'I_render_stimuli','rendered_python','phase2','i');
RENDER_RS = fullfile(PROJ,'I_render_stimuli','rendered_python','rs');
MASK_ROOT = fullfile(PROJ,'I_render_stimuli','mask');
DATAI_P1  = fullfile(PROJ,'A_characterization','display_model','datai_ipv35_3.mat');
DATAI_P2  = 'D:/work/VIVOSkin_phase2/display/model_interp/datai_ipv30_phase2_3.mat';
% cloud_test: 云端渲染图根目录(任务②下载到 I_render_stimuli_python/rendered_python, 结构与本地一致)
CLOUD_I   = fullfile(PROJ,'I_render_stimuli_python','rendered_python','phase2','i');
CLOUD_RS  = fullfile(PROJ,'I_render_stimuli_python','rendered_python','rs');
if strcmp(mode,'cloud_test')
    OUT_XLSX = fullfile(PROJ,'I_render_stimuli','compare_phase12_cloud.xlsx');
else
    OUT_XLSX = fullfile(PROJ,'I_render_stimuli','compare_phase12_matlab.xlsx');
end

WD65 = [94.813 100.000 107.262];
NO_WEI_I  = {'f04i','f05i','f06i','m04i','m06i'};
NO_WEI_RS = {'f04r','f05r','f06r','m04r','m06r'};

addpath(fullfile(PROJ,'utils'));

% ---------------- 模块 2：自检 ----------------
if CHECK_SANITY
    fprintf('=== CHECK_SANITY: RGB -> lut3d_rgb2xyz1 -> xyz2lab(wd65_scaled) ===\n');
    check_lut_sanity(DATAI_P1, WD65);
    check_lut_sanity(DATAI_P2, WD65);
    fprintf('=== 期望：肉色 RGB=[200 150 130] 的 b* 应为正值（Python 版误为负）===\n\n');
end

% ---------------- 模块 3：加载 LUT ----------------
S1 = load(DATAI_P1);  S2 = load(DATAI_P2);
XYZw1 = S1.XYZw(:)';  XYZw2 = S2.XYZw(:)';
wd65_1 = WD65/100 * XYZw1(2);
wd65_2 = WD65/100 * XYZw2(2);
fprintf('[info] phase1 cubeL=%d XYZw=[%.4f %.4f %.4f]\n', S1.cubeL, XYZw1);
fprintf('[info] phase2 cubeL=%d XYZw=[%.4f %.4f %.4f]\n', S2.cubeL, XYZw2);
fprintf('[info] wd65_scaled_p1=[%.4f %.4f %.4f]  wd65_scaled_p2=[%.4f %.4f %.4f]\n', ...
    wd65_1, wd65_2);

% ---------------- 模块 4：收集渲染文件 ----------------
files = collect_render_files(GROUP, RENDER_I, RENDER_RS);
if ~isempty(SUBS)
    keep = cellfun(@(x) ismember(x, SUBS), files(:,2));
    files = files(keep,:);
end
if ~isempty(LIMIT)
    subjects = unique(files(:,2));  keep = false(size(files,1),1);
    for s = 1:numel(subjects)
        idx = find(strcmp(files(:,2), subjects{s}));
        idx = idx(1:min(LIMIT, numel(idx)));  keep(idx) = true;
    end
    files = files(keep,:);
end
n_files = size(files,1);
fprintf('[info] 待对比渲染点: %d 个\n', n_files);

% ---------------- 模块 5：主循环 ----------------
rows = struct([]);  t0 = tic;  n_done = 0;
for n = 1:n_files
    group = files{n,1};  lastPart = files{n,2};  jpg_path = files{n,3};
    try
        if strcmp(mode,'cloud_test')
            if strcmp(group,'i'), cloud_root = CLOUD_I; else, cloud_root = CLOUD_RS; end
        else
            cloud_root = '';
        end
        row = process_one(jpg_path, lastPart, group, ...
            DATAI_P1, DATAI_P2, wd65_1, wd65_2, NO_WEI_I, NO_WEI_RS, MASK_ROOT, cloud_root, (n==1 && DEBUG_FIRST));
        n_done = n_done + 1;
        if isempty(rows), rows = row; else, rows(end+1) = row; end %#ok<AGROW>
        [~,fname,ext] = fileparts(jpg_path);
        fprintf('[%d/%d] %s %s %s%s dE_avg_p1p2=%.3f dE_px[mean/max]=%.3f/%.3f (%.0fs)\n', ...
            n, n_files, group, lastPart, fname, ext, ...
            row.dE_avg_p1p2, row.dE_mean_px, row.dE_max_px, toc(t0));
    catch ME
        fprintf('[skip] %s %s %s -> %s: %s\n', group, lastPart, jpg_path, ME.identifier, ME.message);
    end
end

% ---------------- 模块 6：写 xlsx ----------------
if n_done == 0
    fprintf('[warn] 无有效结果，未写 xlsx\n'); return;
end
T = struct2table(rows);
if strcmp(mode,'cloud_test')
    % cloud_test: 15 列 —— 本地图 p1/p2 + 云端图 p2_cloud + 两个 dE
    T = T(:, {'group','subject','stimulus','file_name', ...
        'target_L','target_a','target_b', ...
        'avg_L_p1','avg_a_p1','avg_b_p1', ...
        'avg_L_p2','avg_a_p2','avg_b_p2', ...
        'avg_L_p2_cloud','avg_a_p2_cloud','avg_b_p2_cloud', ...
        'dE_avg_p1p2','dE_avg_p1p2_cloud'});
else
    T = T(:, {'group','subject','stimulus','file_name', ...
        'target_L','target_a','target_b', ...
        'avg_L_p1','avg_a_p1','avg_b_p1', ...
        'avg_L_p2','avg_a_p2','avg_b_p2', ...
        'dE_avg_p1p2','dE_target_p1','dE_target_p2', ...
        'dE_max_px','dE_p99_px','dE_p95_px','dE_mean_px','dE_median_px','dE_min_px', ...
        'n_mask_px','if_wei'});
end
writetable(T, OUT_XLSX, 'Sheet', 'summary');

meta = {
    'phase1_datai',     DATAI_P1;
    'phase2_datai',     DATAI_P2;
    'phase1_cubeL',     S1.cubeL;
    'phase2_cubeL',     S2.cubeL;
    'phase1_XYZw',      sprintf('[%.4f %.4f %.4f]', XYZw1);
    'phase2_XYZw',      sprintf('[%.4f %.4f %.4f]', XYZw2);
    'wd65_scaled_p1',   sprintf('[%.4f %.4f %.4f]', wd65_1);
    'wd65_scaled_p2',   sprintf('[%.4f %.4f %.4f]', wd65_2);
    'n_points',         n_done;
    'elapsed_s',        round(toc(t0),1);
    'reshape_order',    'MATLAB column-major (Fortran) -- Python版误用C序导致avg_b为负' };
writecell(meta, OUT_XLSX, 'Sheet', 'meta');
fprintf('[done] 写出 -> %s\n', OUT_XLSX);
fprintf('[done] 总耗时 %.1fs\n', toc(t0));

% =========================================================================
% 本地函数
% =========================================================================
function row = process_one(jpg_path, lastPart, group, DATAI_P1, DATAI_P2, ...
        wd65_1, wd65_2, NO_WEI_I, NO_WEI_RS, MASK_ROOT, cloud_root, dbg)
    [~, stem, ~] = fileparts(jpg_path);
    lab_target = parse_target_lab(stem);       % 1x3
    stimulus   = parse_stimulus(stem);
    if_wei = double(~(ismember(lastPart, NO_WEI_I) || ismember(lastPart, NO_WEI_RS)));

    mask_file = find_mask_file(lastPart, stimulus, MASK_ROOT);
    if isempty(mask_file)
        error('mask not found: %s/%s', lastPart, stimulus);
    end

    bull = imread(mask_file);
    [logicalIndex, bull_weight] = read_bull(bull, if_wei);
    idx_keep = ~logicalIndex;

    rgb = imread(jpg_path);                    % uint8 HxWx3
    rgb_flat = double(reshape(rgb, [], 3));
    rgb_keep = rgb_flat(idx_keep, :);

    xyz1 = lut3d_rgb2xyz1(rgb_keep, DATAI_P1);
    xyz2 = lut3d_rgb2xyz1(rgb_keep, DATAI_P2);
    lab1 = xyz2lab(xyz1, 'user', wd65_1);
    lab2 = xyz2lab(xyz2, 'user', wd65_2);

    de_px = deltaE2000(lab1, lab2);

    if if_wei
        w = bull_weight(idx_keep);
        w = w / sum(w);
        ave1 = sum(lab1 .* w, 1);
        ave2 = sum(lab2 .* w, 1);
    else
        w = [];
        ave1 = mean(lab1, 1);
        ave2 = mean(lab2, 1);
    end

    % ---- cloud_test: 对云端渲染图(任务②下载)用同一 mask 权重再算 p1/p2 平均 ----
    if isempty(cloud_root)
        ave2_cloud = [NaN NaN NaN];
        de_p1p2_cloud = NaN;
    else
        cloud_jpg = fullfile(cloud_root, lastPart, [stem '.jpg']);
        if isfile(cloud_jpg)
            rgb_c = double(reshape(imread(cloud_jpg), [], 3));
            rgb_c_keep = rgb_c(idx_keep, :);
            lab1_c = xyz2lab(lut3d_rgb2xyz1(rgb_c_keep, DATAI_P1), 'user', wd65_1);
            lab2_c = xyz2lab(lut3d_rgb2xyz1(rgb_c_keep, DATAI_P2), 'user', wd65_2);
            if if_wei
                ave1_c = sum(lab1_c .* w, 1);
                ave2_c = sum(lab2_c .* w, 1);
            else
                ave1_c = mean(lab1_c, 1);
                ave2_c = mean(lab2_c, 1);
            end
            ave2_cloud = ave2_c;
            de_p1p2_cloud = deltaE2000(ave1_c, ave2_c);
        else
            ave2_cloud = [NaN NaN NaN];
            de_p1p2_cloud = NaN;
        end
    end

    if dbg
        fprintf('\n--- DEBUG 第1个点: %s ---\n', stem);
        fprintf('  mask=%s  if_wei=%d  n_mask_px=%d\n', mask_file, if_wei, size(rgb_keep,1));
        fprintf('  渲染图 RGB(mask内) mean=[%.1f %.1f %.1f]\n', mean(rgb_keep,1));
        fprintf('  phase1 XYZ mean=[%.3f %.3f %.3f]\n', mean(xyz1,1));
        fprintf('  phase2 XYZ mean=[%.3f %.3f %.3f]\n', mean(xyz2,1));
        fprintf('  phase1 Lab mean=[%.2f %.2f %.2f]  <-- avg_b_p1\n', ave1);
        fprintf('  phase2 Lab mean=[%.2f %.2f %.2f]  <-- avg_b_p2\n', ave2);
        fprintf('  target Lab=[%.2f %.2f %.2f]\n', lab_target);
        fprintf('  期望：avg_b_p1/p2 应为正值（肉色），Python 版误为负\n');
    end

    row = struct( ...
        'group', group, 'subject', lastPart, 'stimulus', stimulus, ...
        'file_name', [stem '.jpg'], ...
        'target_L', lab_target(1), 'target_a', lab_target(2), 'target_b', lab_target(3), ...
        'avg_L_p1', ave1(1), 'avg_a_p1', ave1(2), 'avg_b_p1', ave1(3), ...
        'avg_L_p2', ave2(1), 'avg_a_p2', ave2(2), 'avg_b_p2', ave2(3), ...
        'avg_L_p2_cloud', ave2_cloud(1), 'avg_a_p2_cloud', ave2_cloud(2), 'avg_b_p2_cloud', ave2_cloud(3), ...
        'dE_avg_p1p2', deltaE2000(ave1, ave2), ...
        'dE_avg_p1p2_cloud', de_p1p2_cloud, ...
        'dE_target_p1', deltaE2000(ave1, lab_target), ...
        'dE_target_p2', deltaE2000(ave2, lab_target), ...
        'dE_max_px', max(de_px), 'dE_p99_px', prctile(de_px,99), 'dE_p95_px', prctile(de_px,95), ...
        'dE_mean_px', mean(de_px), 'dE_median_px', median(de_px), 'dE_min_px', min(de_px), ...
        'n_mask_px', size(rgb_keep,1), 'if_wei', if_wei);
end

function check_lut_sanity(datai_path, WD65)
    S = load(datai_path);
    cubeL = S.cubeL;  lablut = S.lablut;  XYZw = S.XYZw(:)';
    lutL = reshape(lablut(:,1), cubeL, cubeL, cubeL);
    lutA = reshape(lablut(:,2), cubeL, cubeL, cubeL);
    lutB = reshape(lablut(:,3), cubeL, cubeL, cubeL);
    [m,j,k] = meshgrid(linspace(0,255,cubeL));
    test_rgb = [255 255 255; 128 128 128; 200 150 130];
    wd65_scaled = WD65/100 * XYZw(2);
    for t = 1:size(test_rgb,1)
        R = test_rgb(t,1); G = test_rgb(t,2); B = test_rgb(t,3);
        L  = interp3(m,j,k,lutL, R,G,B, 'linear');
        A  = interp3(m,j,k,lutA, R,G,B, 'linear');
        Bb = interp3(m,j,k,lutB, R,G,B, 'linear');
        xyz = lab2xyz2([L A Bb], 'user', XYZw);
        lab = xyz2lab(xyz, 'user', wd65_scaled);
        [~, fname] = fileparts(datai_path);
        fprintf('  [%s] RGB=[%3d %3d %3d] -> Lab=[%.2f %.2f %.2f] (b*=%+.2f)\n', ...
            fname, R, G, B, lab(1), lab(2), lab(3), lab(3));
    end
end

function files = collect_render_files(GROUP, RENDER_I, RENDER_RS)
    roots = {};
    if any(strcmp(GROUP, {'i','all'})),   roots{end+1} = {'i',   RENDER_I};  end
    if any(strcmp(GROUP, {'rs','all'})),  roots{end+1} = {'rs',  RENDER_RS}; end
    files = cell(0,3);
    for r = 1:numel(roots)
        tag  = roots{r}{1};
        root = roots{r}{2};
        subs = dir(root);  subs = subs([subs.isdir] & ~startsWith({subs.name},'.'));
        for s = 1:numel(subs)
            lastPart = subs(s).name;
            d = fullfile(root, lastPart);
            imgs = dir(fullfile(d, '*.jp*g'));   % .jpg/.jpeg/.JPG/.JPEG
            for k = 1:numel(imgs)
                files(end+1,:) = {tag, lastPart, fullfile(d, imgs(k).name)}; %#ok<AGROW>
            end
        end
    end
end

function mask_file = find_mask_file(lastPart, stimulus, MASK_ROOT)
    mask_file = '';
    d = fullfile(MASK_ROOT, lastPart);
    if ~isfolder(d), return; end
    files = dir(d);
    for k = 1:numel(files)
        [~, name, ext] = fileparts(files(k).name);
        if strcmpi(name, stimulus) && any(strcmpi(ext, {'.jpg','.jpeg','.png','.bmp'}))
            mask_file = fullfile(d, files(k).name);
            return;
        end
    end
end

function lab = parse_target_lab(stem)
    tok = regexp(stem, '\[(-?[\d.]+),(-?[\d.]+),(-?[\d.]+)\]', 'tokens', 'once');
    lab = [str2double(tok{1}), str2double(tok{2}), str2double(tok{3})];
end

function stimulus = parse_stimulus(stem)
    tok = regexp(stem, '^(.+?)_\d+\[.+\]$', 'tokens', 'once');
    stimulus = tok{1};
end
