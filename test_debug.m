%% test_debug.m
% 逐像素比较 MATLAB 管线与 Python 管线渲染的 .png 差异
% 输出：差值(diff)与绝对差值(|diff|)的最大值、最小值、平均值（整体 + RGB 三通道）
% 以及逐像素 ΔE2000 统计
% 注：iOr='rs'（实景）时 CardMask 逻辑整体禁用，全部像素参与统计
clear; clc;

% ===================== 比较源开关 =====================
% 'gpu_vs_matlab'    : A 侧 = MATLAB 管线 (rendered/phase2/i)，B 侧 = Python GPU
% 'gpu_vs_phase1'    : A 侧 = phase1 (rendered_2max)，B 侧 = Python GPU，每个 model 只比 H3K_01 一张
% 'gpu_vs_phase_all' : A 侧 = phase1 (rendered_2max)，B 侧 = Python GPU (phase2_cloud)，
%                      no_uni 下全部 png 与 rendered_2max 下对应 jpg 逐张比较
% 'gpu_vs_phase_jpg' : A 侧 = phase1 (rendered_2max)，B 侧 = E:\VIVOphase2\rendered_python\gpu\phase2
%                      下 {model}{i/r} 目录中的 jpg（无 no_uni 子层），其余逻辑与 gpu_vs_phase_all 相同，
%                      遇到不存在的文件直接跳过
compare_source = 'gpu_vs_phase_jpg';
store_folder='E:\VIVOphase2\';
% store_folder='D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli';
iOr='rs';
% iOr='i';
% ===================== 待比较的 model 与路径模板 =====================
% models = {'f01', 'm10'};
models = [cellstr(compose('f%02d',1:10)), cellstr(compose('m%02d',1:10))];

switch compare_source
    case 'gpu_vs_matlab'
        base_matlab = fullfile( ...
            store_folder, ...
            'rendered', 'phase2', iOr);
        base_python = fullfile( ...
            store_folder, ...
            'rendered_python', 'gpu', 'phase2', iOr);
    case 'gpu_vs_phase1'
        base_matlab = 'D:\work\VIVOSkinExpe\toMax\rendered_2max';
        base_python = fullfile( ...
            store_folder, ...
            'rendered_python', 'gpu', 'phase2', iOr);
    case 'gpu_vs_phase_all'
        base_matlab = 'D:\work\VIVOSkinExpe\toMax\rendered_2max';
        base_python = fullfile( ...
            'D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli_python', ...
            'rendered_python', 'phase2_cloud', 'gpu', 'phase2', iOr);
    case 'gpu_vs_phase_jpg'
        base_matlab = 'D:\work\VIVOSkinExpe\toMax\rendered_2max';
        base_python = fullfile( ...
            'E:\VIVOphase2', 'rendered_python', 'gpu', 'phase2', iOr);
    otherwise
        error('未知 compare_source: %s', compare_source);
end

% ===================== CardMask 遮罩根目录（二值化=1 的区域不参与 |diff|/ΔE 计算） =====================
stimuli_root = 'D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli';
% iOr='rs'（实景）时，CardMask 相关逻辑整体禁用：不读掩膜、不排除任何像素
use_cardmask = ~strcmp(iOr, 'rs');
if use_cardmask
    fprintf('CardMask: 启用（iOr=%s）\n', iOr);
else
    fprintf('CardMask: 禁用（iOr=%s，实景图像不扣掩膜）\n', iOr);
end

% ============ 依赖函数目录（lut3d_rgb2xyz1 / xyz2lab / lab2xyz / deltaE2000） ============
build_dir = fullfile( ...
    'D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project', ...
    'A_characterization', 'display_model', 'build');
addpath(build_dir);
addpath(fullfile(stimuli_root, 'utils'));   % get_average / read_bull

% LUTfore_file：RGB→XYZ 的前向 3D-LUT
% 注意：文件实际在 display_model\ 顶层，不在 build\model_interp\ 下，故做路径回退
LUTfore_file = resolve_existing({ ...
    fullfile(build_dir, 'model_interp', 'datai_ipv30_phase2_3.mat'), ...   % 用户原始路径
    fullfile(fileparts(build_dir), 'datai_ipv30_phase2_3.mat')});          % 实际存放路径
fprintf('使用 LUTfore_file: %s\n', LUTfore_file);

% LUTfore_file_A：A 侧（file_matlab）所用的 RGB→XYZ 前向 3D-LUT
% gpu_vs_phase1 / gpu_vs_phase_all 的 A 侧是 phase1（rendered_2max）数据，需用 ipv35 LUT
% 其余模式（gpu_vs_matlab）A 侧沿用 ipv30 LUT
if strcmp(compare_source, 'gpu_vs_phase1') || strcmp(compare_source, 'gpu_vs_phase_all') || strcmp(compare_source, 'gpu_vs_phase_jpg')
    LUTfore_file_A = resolve_existing({ ...
        fullfile(build_dir, 'model_interp', 'datai_ipv35_3.mat'), ...   % build 下副本
        fullfile(fileparts(build_dir), 'datai_ipv35_3.mat')});          % display_model 顶层
else
    LUTfore_file_A = LUTfore_file;
end
fprintf('使用 LUTfore_file_A: %s\n', LUTfore_file_A);

% ===================== 结果收集（每对 png 一行） =====================
is_phase_all = strcmp(compare_source, 'gpu_vs_phase_all') || strcmp(compare_source, 'gpu_vs_phase_jpg');
results = struct();
row = 1;

for mi = 1:numel(models)
    model = models{mi};
    % model 子文件夹/文件名后缀：iOr='rs' 时用 'r'（实景），iOr='i' 时用 'i'（实验室）
    if strcmp(iOr, 'rs')
        model_dir = strcat(model, 'r');
    else
        model_dir = strcat(model, 'i');
    end
    fprintf('\n############################################################\n');
    fprintf('##########  model = %s  ##########\n', model);
    fprintf('############################################################\n');

    % ===================== 定位待比较文件（构造成对列表） =====================
    py_files = {};
    m_files  = {};
    switch compare_source
        case 'gpu_vs_matlab'
            d_p = dir(fullfile(base_python, model_dir, 'no_uni', 'H3K_01*.png'));
            assert(~isempty(d_p), 'Python 侧未找到 H3K_01*.png: %s', model_dir);
            d_m = dir(fullfile(base_matlab, model_dir, 'no_uni', 'H3K_01*.png'));
            assert(~isempty(d_m), 'MATLAB 侧未找到 H3K_01*.png: %s', model_dir);
            py_files{1} = fullfile(d_p(1).folder, d_p(1).name);
            m_files{1}  = fullfile(d_m(1).folder, d_m(1).name);
        case 'gpu_vs_phase1'
            d_p = dir(fullfile(base_python, model_dir, 'no_uni', 'H3K_01*.png'));
            assert(~isempty(d_p), 'Python 侧未找到 H3K_01*.png: %s', model_dir);
            py_files{1} = fullfile(d_p(1).folder, d_p(1).name);
            m_files{1}  = fullfile(base_matlab, model_dir, [model_dir 'h3k_01.jpg']);
            assert(exist(m_files{1}, 'file') == 2, 'phase1 侧未找到文件: %s', m_files{1});
        case 'gpu_vs_phase_all'
            d_p = dir(fullfile(base_python, model_dir, 'no_uni', '*.png'));
            assert(~isempty(d_p), 'Python 侧未找到任何 png: %s', model_dir);
            for k = 1:numel(d_p)
                toks = regexp(d_p(k).name, '^([^_]+)_(\d+)', 'tokens', 'once');
                assert(~isempty(toks), '无法解析 Python 文件名: %s', d_p(k).name);
                scene = toks{1};                       % 'H3K'
                idx   = toks{2};                       % '01'
                py_files{k} = fullfile(d_p(k).folder, d_p(k).name);
                m_files{k}  = fullfile(base_matlab, model_dir, ...
                    [model_dir lower(scene) '_' idx '.jpg']);
                assert(exist(m_files{k}, 'file') == 2, ...
                    'phase1 侧未找到文件: %s', m_files{k});
            end
        case 'gpu_vs_phase_jpg'
            d_p = dir(fullfile(base_python, model_dir, '*.jpg'));
            if isempty(d_p)
                fprintf('Python 侧未找到任何 jpg（跳过该 model）: %s\n', model_dir);
                continue;
            end
            n_pair = 0;
            for k = 1:numel(d_p)
                toks = regexp(d_p(k).name, '^([^_]+)_(\d+)', 'tokens', 'once');
                if isempty(toks)
                    fprintf('无法解析 Python 文件名（跳过）: %s\n', d_p(k).name);
                    continue;
                end
                scene = toks{1};                       % 'H3K' / 'rs01' 等
                idx   = toks{2};                       % '01'
                m_file = fullfile(base_matlab, model_dir, ...
                    [model_dir lower(scene) '_' idx '.jpg']);
                if exist(m_file, 'file') ~= 2
                    fprintf('phase1 侧未找到文件（跳过）: %s\n', m_file);
                    continue;
                end
                n_pair = n_pair + 1;
                py_files{n_pair} = fullfile(d_p(k).folder, d_p(k).name);
                m_files{n_pair}  = m_file;
            end
        otherwise
            error('未知 compare_source: %s', compare_source);
    end
    fprintf('本 model 共 %d 对图像待比较\n', numel(py_files));

    for fi = 1:numel(py_files)
        file_matlab = m_files{fi};
        file_python = py_files{fi};
        fprintf('\n---------- [%d/%d] ----------\n', fi, numel(py_files));
        fprintf('MATLAB: %s\n', file_matlab);
        fprintf('Python: %s\n', file_python);

        % ===================== 读取 PNG（imread → uint8 → 0~1 double） =====================
        A = im2double(imread(file_matlab));
        B = im2double(imread(file_python));

    % ===================== 尺寸检查 =====================
    if ~isequal(size(A), size(B))
        error('尺寸不一致: MATLAB=%s, Python=%s', ...
            mat2str(size(A)), mat2str(size(B)));
    end

    fprintf('图像尺寸: %d x %d x %d\n\n', size(A,1), size(A,2), size(A,3));

    % ===================== 读取 CardMask 遮罩（二值化=1 的区域不参与计算） =====================
    % iOr='rs' 时 use_cardmask=false：跳过整套掩膜逻辑，exclude_mask 全 0
    [~, py_name, py_ext] = fileparts(file_python);
    if use_cardmask
        scene = regexp([py_name py_ext], '^[^_]+', 'match', 'once');   % 'H3K_01[...].png' -> 'H3K'
        cardmask_path = fullfile(stimuli_root, 'CardMask', model, [scene '.JPG']);
        assert(exist(cardmask_path, 'file') == 2, '未找到 CardMask 遮罩: %s', cardmask_path);
        cardmask = imread(cardmask_path);
        if size(cardmask, 3) == 3
            cardmask = rgb2gray(cardmask);
        end
        cardmask_bw = imbinarize(cardmask);                                     % 二值化：1 = 前景（卡片）区域
        cardmask_bw = imresize(cardmask_bw, [size(A,1) size(A,2)], 'nearest'); % 对齐 A/B 尺寸
        exclude_mask = logical(cardmask_bw);                                    % 1 = 不参与计算的像素
        n_valid = nnz(~exclude_mask);                                           % 有效像素数（单通道）
        fprintf('CardMask: %s  排除像素=%d (%.2f%%)\n', ...
            cardmask_path, numel(exclude_mask) - n_valid, ...
            100 * (numel(exclude_mask) - n_valid) / numel(exclude_mask));
    else
        exclude_mask = false(size(A,1), size(A,2));                             % 实景：不排除任何像素
        n_valid = nnz(~exclude_mask);
        fprintf('CardMask: 已禁用，排除像素=0 (0.00%%)\n');
    end

    if ~is_phase_all
    % ===================== 逐像素计算差异 =====================
    diff_img  = A - B;        % 带符号差值
    abs_diff  = abs(diff_img); % 绝对差值
    diff_img(repmat(exclude_mask, [1 1 3])) = NaN;

    % 排除 CardMask =1 的像素（置 NaN，后续统计忽略）
    abs_diff_m = abs_diff;
    abs_diff_m(repmat(exclude_mask, [1 1 3])) = NaN;

    % ===================== 整体统计 =====================
    fprintf('==================== 整体（所有像素、所有通道） ====================\n');
    print_stats('diff (A - B)', diff_img);
    print_stats('|diff|all',   abs_diff);
    print_stats('|diff|mask',  abs_diff_m);

    % ===================== 分通道统计 =====================
    channel_names = {'R', 'G', 'B'};
    fprintf('\n==================== 分通道（diff = A - B） ====================\n');
    for c = 1:3
        fprintf('--- 通道 %s ---\n', channel_names{c});
        print_stats('diff',      diff_img(:, :, c));
        print_stats('|diff|all', abs_diff(:, :, c));
        print_stats('|diff|mask',abs_diff_m(:, :, c));
    end

    % ===================== 定位极值位置 =====================
    [abs_max, lin_idx] = max(abs_diff_m(:), [], 'omitnan');
    fprintf('\n==================== 极值位置 ====================\n');
    if isnan(abs_max)
        fprintf('（所有像素均被 CardMask 排除）\n');
    else
        [px_row, col, ch] = ind2sub(size(abs_diff_m), lin_idx);
        fprintf('最大 |diff| = %.6g  @ (row=%d, col=%d, channel=%s)\n', ...
            abs_max, px_row, col, channel_names{ch});
        fprintf('该像素 MATLAB=%.6g, Python=%.6g, diff=%.6g\n', ...
            A(px_row, col, ch), B(px_row, col, ch), diff_img(px_row, col, ch));
    end

    % ===================== 百分比误差（相对 0~1 值域） =====================
    fprintf('\n==================== 占比统计 ====================\n');
    fprintf('像素总数(全部): %d, 有效像素(排除 CardMask 后): %d\n', numel(A), 3 * n_valid);
    for th = [1e-6, 1e-4, 1e-3, 1e-2, 1e-1]
        n = sum(abs_diff_m(:) > th);   % NaN > th 为 false，自动排除
        fprintf('|diff| > %.0e : %d 像素 (%.4f%%)\n', th, n, 100 * n / (3 * n_valid));
    end
    end

    % ============ RGB(0~255) → XYZ → Lab → 逐像素 ΔE2000 ============
    % RGB 0~1 → 0~255，展平成 (N x 3)
    RGB_A = reshape(A, [], 3) * 255;
    RGB_B = reshape(B, [], 3) * 255;

    % RGB → XYZ（逐像素 3D-LUT 插值）
    XYZ_A = lut3d_rgb2xyz1(RGB_A, LUTfore_file_A);
    XYZ_B = lut3d_rgb2xyz1(RGB_B, LUTfore_file);

    % 白点：从该 RGB 算得的 XYZ 中取 Y 最大的像素（最白像素），与待比较图像自洽
    [~, ind_white] = max(XYZ_A);
    XYZw = XYZ_A(ind_white(2), :);
    fprintf('\n白点 XYZw = [%.4f %.4f %.4f]\n', XYZw);

    % XYZ → Lab
    lab_A = xyz2lab(XYZ_A, 'user', XYZw);
    lab_B = xyz2lab(XYZ_B, 'user', XYZw);

    if ~is_phase_all
    % 逐像素 ΔE2000（返回 1 x N 行向量）
    de00 = deltaE2000(lab_A, lab_B);
    de00 = de00(:);
    de00(exclude_mask(:)) = NaN;   % 排除 CardMask =1 的像素

    % NaN 检查（含 CardMask 排除像素 + RGB 越界导致 interp3 外推失败的 NaN）
    n_nan = sum(isnan(de00));
    n_valid_de = nnz(~isnan(de00));
    fprintf('\n==================== ΔE2000 统计（有效像素=%d，排除/NaN=%d） ====================\n', ...
        n_valid_de, n_nan);
    print_de_stats('ΔE2000', de00);

    fprintf('\n==================== ΔE2000 阈值占比 ====================\n');
    for th = [1, 2, 3, 5, 10]
        n = sum(de00 > th);   % NaN > th 为 false，自动排除
        fprintf('ΔE2000 > %d : %d 像素 (%.4f%%)\n', th, n, 100 * n / n_valid_de);
    end
    end

    % ===================== 收集本行统计（每对 png 一行） =====================
    results(row).model       = model;
    [~, m_name, m_ext] = fileparts(file_matlab);
    results(row).matlab_file = [m_name m_ext];
    results(row).python_file = [py_name py_ext];

    if ~is_phase_all
        % 对应像素 RGB 绝对差值（0~255 尺度，|diff| = |A - B|，排除 CardMask =1 区域）
        diff_255 = abs_diff * 255;
        diff_255_m = diff_255;
        diff_255_m(repmat(exclude_mask, [1 1 3])) = NaN;
        results(row).rgb_diff_max  = max(diff_255_m(:), [], 'omitnan');
        results(row).rgb_diff_min  = min(diff_255_m(:), [], 'omitnan');
        results(row).rgb_diff_mean = mean(diff_255_m(:), 'omitnan');
        results(row).rgb_gt1_pct   = 100 * sum(diff_255_m(:) > 1) / (3 * n_valid);

        % 对应像素 ΔE2000
        de00_valid = de00(~isnan(de00));
        if isempty(de00_valid)
            de_max = NaN; de_min = NaN; de_mean = NaN;
        else
            de_max  = max(de00_valid);
            de_min  = min(de00_valid);
            de_mean = mean(de00_valid);
        end
        results(row).de00_max  = de_max;
        results(row).de00_min  = de_min;
        results(row).de00_mean = de_mean;
        de_den = numel(de00) - n_nan;
        if de_den > 0
            results(row).de00_gt1_pct = 100 * sum(de00 > 1) / de_den;
        else
            results(row).de00_gt1_pct = NaN;
        end
    end

    % ===================== 皮肤平均 Lab 及 average 间色差（参考 test.m: get_average + CardMask） =====================
    lastPart = [model 'i'];
    if ismember(lastPart, ["f04i", "f05i", "f06i", "m04i", "m06i"])
        if_wei = 0;
    else
        if_wei = 1;
    end
    skin_bull = uint8(~exclude_mask) * 255;   % 皮肤=255(白) 参与平均，卡片=0(黑) 排除
    ave_lab_A = get_average(lab_A, skin_bull, if_wei);   % 1x3 平均 Lab
    ave_lab_B = get_average(lab_B, skin_bull, if_wei);
    ave_de00  = deltaE2000(ave_lab_A, ave_lab_B);         % 两个平均 Lab 间的 ΔE2000
    [de,dl,dc,dh] = cielabde(ave_lab_A, ave_lab_B);       % average 间 CIE76 色差分解
    fprintf('\n==================== average 间色差 ====================\n');
    fprintf('avg Lab  MATLAB = [%.4f %.4f %.4f]\n', ave_lab_A);
    fprintf('avg Lab  Python = [%.4f %.4f %.4f]\n', ave_lab_B);
    fprintf('average 间 ΔE2000 = %.4f\n', ave_de00(1));
    fprintf('average 间 CIE76  de=%.4f, dl=%.4f, dc=%.4f, dh=%.4f\n', de, dl, dc, dh);

    results(row).ave_de00 = ave_de00(1);
    if is_phase_all
        results(row).de = de;
        results(row).dl = dl;
        results(row).dc = dc;
        results(row).dh = dh;
    end
    row = row + 1;
    end
end

% ===================== 汇总写入 xlsx（每对 png 一行） =====================
T = struct2table(results);
script_dir = fileparts(mfilename('fullpath'));
if isempty(script_dir)
    script_dir = pwd;
end
out_xlsx = fullfile(script_dir, sprintf('test_debug_report_%s.xlsx', compare_source));
writetable(T, out_xlsx);
fprintf('\n报告已写入: %s\n', out_xlsx);


%% ===================== 局部函数 =====================
function print_stats(name, x)
    x = x(:);
    x = x(~isnan(x));
    if isempty(x)
        fprintf('%-10s : (全部被排除/NaN)\n', name);
        return;
    end
    fprintf('%-10s : max = % .6g , min = % .6g , mean = % .6g\n', ...
        name, max(x), min(x), mean(x));
end

function p = resolve_existing(candidates)
    % 返回第一个实际存在的文件路径
    for k = 1:numel(candidates)
        if exist(candidates{k}, 'file') == 2
            p = candidates{k};
            return;
        end
    end
    error('未找到 LUT 文件，以下候选路径均不存在:\n%s', ...
        strjoin(candidates, newline));
end

function print_de_stats(name, x)
    x = x(:);
    x = x(~isnan(x));
    if isempty(x)
        fprintf('%s: (全部为 NaN)\n', name);
        return;
    end
    fprintf('%-8s : max = %.4f , min = %.4f , mean = %.4f , std = %.4f , median = %.4f\n', ...
        name, max(x), min(x), mean(x), std(x), median(x));
end
