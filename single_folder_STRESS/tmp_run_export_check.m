function tmp_run_export_check(groups_override, skip_fit)
%RUN_ALL_STRESS_AND_EXPORT
%   批量对每个 {model}{i/r} 运行 cal_STRESS.m，并汇总每个 obs 的
%   STRESS_inter_mean / STRESS_intra_mean 到一个 xlsx。
%
% -------------------------------------------------------------------------
% 做什么
%   步骤1 对 D:\work\VIVOSkin_phase2\ExpRes\renamed 下的每个 {model}{i/r} 组：
%         令 source_folder = 'D:\work\VIVOSkin_phase2\ExpRes\renamed\{model}{i/r}';
%         然后运行 cal_STRESS.m
%         => 对组内每个 obs_XX 子文件夹调用 process_data_stress，
%            产出 {group}\obs_XX\stress_mat\STRESS.mat
%   步骤2 读取所有 STRESS.mat，汇总成一个 xlsx：
%           行 = 一个 {model}{i/r}（只列磁盘上真实存在的组）
%           列 = obs01 .. obs05
%         缺失的 (组, obs) 组合写 NaN
%   步骤3 按“是哪一批 observer 做的”把行拆到不同 sheet：
%           sheet 'STRESS_inter_mean_B1' / 'STRESS_inter_mean_B2'
%           sheet 'STRESS_intra_mean_B1' / 'STRESS_intra_mean_B2'
%         为什么拆：两批人的 observer 不是同一组人，obs01..obs05 在两批里
%         对应的不是同一个人（批1: Malvin/Jerome/moussa/viva/philippe；
%         批2: NIWE/LUKE MARRION MARUFU/Balima Miguel/TANATSWA ...），
%         混在一张表里按列比较会误读。批次名单见配置区的 BATCHES。
%
% -------------------------------------------------------------------------
% 为什么循环里不能直接 run('cal_STRESS.m')
%   cal_STRESS.m 第 8-9 行是 clc / clear，而脚本(script)是在“调用者的工作区”
%   里执行的，所以在 for 循环里 run 它，clear 会把循环变量和结果矩阵一起清掉
%   （已实测：run 之后外层变量消失，循环直接崩）。
%
%   本文件的做法：
%       ① fileread 读出 cal_STRESS.m 的源码
%       ② 只把 `source_folder = '...' ;` 这一行替换成当前组的路径
%       ③ evalin('base', 替换后的源码)  —— 在 base 工作区执行
%      base 被 clear 无所谓，本函数的局部变量（循环、结果矩阵）不受影响。
%      cal_STRESS.m 仍然是唯一的计算来源，改它不需要同步改本文件。
%
% -------------------------------------------------------------------------
% 用法
%   >> run_all_STRESS_and_export              % 全部组（重跑拟合 + 导出）
%   >> run_all_STRESS_and_export({'m10r'})    % 只跑指定组（调试用）
%   >> run_all_STRESS_and_export([], true)    % 跳过步骤1，只用已有的 STRESS.mat
%                                             % 重新汇总导出（改表格式时用，几秒跑完）
%
%   也可以在编辑器里直接按 F5（无入参 = 全部组）。
% -------------------------------------------------------------------------

%% ================= 配置 =================
    ROOT         = 'D:\work\VIVOSkin_phase2\ExpRes\renamed';
    ANALYZE      = 'D:\work\VIVOSkin_phase2\analyze';
    STRESS_DIR   = fullfile(ANALYZE, 'single_folder_STRESS');

    CAL_STRESS_M = fullfile(STRESS_DIR, 'cal_STRESS.m');   % 被驱动的脚本（唯一计算来源）
    OUT_XLSX     = fullfile(STRESS_DIR, 'tmp_STRESS_check.xlsx');

    MAX_OBS      = 5;      % 列固定为 obs_01..obs_05

    % --- 两批 observer 各自做了哪些组（写文件夹名，不带结尾的 i/r）---
    % 拆 sheet 的唯一依据；以后要改批次归属，只改这里
    BATCHES = { ...
        'B1', {'f04', 'f01', 'f07', 'f09', 'f08', 'f10'}; ...   % 批1
        'B2', {'f06', 'f03', 'm07', 'm09', 'm08', 'm10'} };     % 批2

    SHEET_INTER  = 'STRESS_inter_mean';   % 实际 sheet 名 = 该前缀 + '_B1' / '_B2'
    SHEET_INTRA  = 'STRESS_intra_mean';

%% ================= 依赖路径 =================
    if exist(CAL_STRESS_M, 'file') ~= 2
        error('找不到 cal_STRESS.m: %s', CAL_STRESS_M);
    end
    addpath(STRESS_DIR);                          % process_data_stress.m
    addpath(fullfile(ANALYZE, 'utils'));          % mapMatrixValues.m / STRESS.m

%% ================= 组列表 =================
    d = dir(ROOT);
    d = d([d.isdir] & ~ismember({d.name}, {'.', '..'}));
    groups = sort({d.name});

    if nargin >= 1 && ~isempty(groups_override)
        groups = groups_override;                 % 调试：只跑指定组
    end

    fprintf('数据根目录 : %s\n', ROOT);
    fprintf('输出 xlsx  : %s\n', OUT_XLSX);
    fprintf('待处理组数 : %d\n\n', numel(groups));

%% ================= 步骤1：逐组运行 cal_STRESS.m =================
    if nargin < 2 || isempty(skip_fit)
        skip_fit = false;     % 默认：重跑拟合，再汇总导出
    end
    n_ok     = 0;
    fail_msg = {};

    if skip_fit
        fprintf('[skip_fit=true] 跳过步骤1，直接用已有的 STRESS.mat 重新汇总导出\n\n');
    else

    src = fileread(CAL_STRESS_M);

    % 定位 cal_STRESS.m 里 `source_folder = '...';` 的那个字符串字面量
    % 用锚点 + 单引号定位，而不是 regexprep：Windows 路径里的 \ 在替换串里会被当转义
    anchor = 'source_folder = ''';
    n_anchor = numel(strfind(src, anchor));
    if n_anchor ~= 1
        error(['cal_STRESS.m 里 ''source_folder = ''...'''';'' 出现了 %d 次，' ...
               '本脚本要求恰好 1 次（第16行那一处），请检查文件后再运行。'], n_anchor);
    end
    p  = strfind(src, anchor);
    q1 = p + numel(anchor) - 1;                 % 左引号的下标
    r  = strfind(src(q1 + 1:end), '''');
    q2 = q1 + r(1);                             % 右引号的下标
    len_old = q2 - q1 - 1;                      % 原路径长度

    old_dir  = cd(ANALYZE);   % 让 cal_STRESS.m 里相对的 addpath("utils\") 能命中

    for g = 1:numel(groups)
        group   = groups{g};
        grp_dir = fullfile(ROOT, group);

        if exist(grp_dir, 'dir') ~= 7
            fprintf('[跳过] %s：目录不存在\n', group);
            continue
        end

        % --- 只把 source_folder 的取值换成当前组的绝对路径，其余源码一字不动 ---
        code = [src(1:q1), grp_dir, src(q2:end)];
        assert(numel(code) == numel(src) - len_old + numel(grp_dir), ...
               '源码替换长度校验失败，已中止以免跑错目录。');

        fprintf('=== [%d/%d] 运行 cal_STRESS.m -> %s ===\n', g, numel(groups), group);
        try
            evalin('base', code);     % base 里的 clear 影响不到本函数局部变量
            n_ok = n_ok + 1;
        catch ME
            fail_msg{end+1} = sprintf('%s : %s', group, ME.message); %#ok<AGROW>
            warning('组 %s 运行失败，已跳过：%s', group, ME.message);
        end
    end

    cd(old_dir);                  % 还原用户原来的工作目录

    end   % if skip_fit

%% ================= 步骤2：汇总 =================
    M_inter = nan(numel(groups), MAX_OBS);
    M_intra = nan(numel(groups), MAX_OBS);

    for g = 1:numel(groups)
        for o = 1:MAX_OBS
            mat_path = fullfile(ROOT, groups{g}, sprintf('obs_%02d', o), ...
                                'stress_mat', 'STRESS.mat');
            if exist(mat_path, 'file') ~= 2
                continue                              % 无该 obs -> 保持 NaN
            end
            try
                S = load(mat_path, 'STRESS_inter_mean', 'STRESS_intra_mean');
            catch ME
                warning('读取失败 %s : %s', mat_path, ME.message);
                continue
            end
            if isfield(S, 'STRESS_inter_mean'), M_inter(g, o) = S.STRESS_inter_mean; end
            if isfield(S, 'STRESS_intra_mean'), M_intra(g, o) = S.STRESS_intra_mean; end
        end
    end

    obs_names = arrayfun(@(o) sprintf('obs%02d', o), 1:MAX_OBS, 'UniformOutput', false);

    % 第一列 Group + 5 个数值列（保持 double，写进 xlsx 里是数字不是文本）
    T_inter = addvars(array2table(M_inter, 'VariableNames', obs_names), ...
                      groups(:), 'Before', 1, 'NewVariableNames', 'Group');
    T_intra = addvars(array2table(M_intra, 'VariableNames', obs_names), ...
                      groups(:), 'Before', 1, 'NewVariableNames', 'Group');

%% ================= 步骤3：按批次拆行 =================
    % groups{g} 形如 'f04i' / 'f04r'：去掉结尾的 i/r 再与 BATCHES 的名单比对
    batch_id = zeros(numel(groups), 1);
    for b = 1:size(BATCHES, 1)
        for g = 1:numel(groups)
            if ismember(strip_ir(groups{g}), BATCHES{b, 2})
                batch_id(g) = b;
            end
        end
    end

    unassigned = groups(batch_id == 0);
    if ~isempty(unassigned)
        warning(['以下组不在任何批次名单里，会单独写进 *_unassigned sheet：\n  %s\n' ...
                 '（如果是有意漏掉的，请把组名补进配置区的 BATCHES）'], ...
                strjoin(unassigned, ' '));
    end

    if exist(OUT_XLSX, 'file') == 2
        delete(OUT_XLSX);      % 先删掉，避免上一次运行的旧 sheet 残留
    end

    metric_specs = {SHEET_INTER, T_inter; SHEET_INTRA, T_intra};
    n_metric     = size(metric_specs, 1);
    n_batch      = size(BATCHES, 1);
    has_other    = any(batch_id == 0);
    sheet_names  = cell(1, n_metric * (n_batch + 1));   % 预分配：实际用几个截几个，供报告打印
    n_sheet      = 0;

    for s = 1:n_metric
        base = metric_specs{s, 1};
        T    = metric_specs{s, 2};

        for b = 1:n_batch
            sel = (batch_id == b);
            if ~any(sel), continue; end
            n_sheet = n_sheet + 1;
            sheet_names{n_sheet} = sprintf('%s_%s', base, BATCHES{b, 1});
            writetable(T(sel, :), OUT_XLSX, 'Sheet', sheet_names{n_sheet});
        end

        if has_other
            n_sheet = n_sheet + 1;
            sheet_names{n_sheet} = sprintf('%s_unassigned', base);
            writetable(T(batch_id == 0, :), OUT_XLSX, 'Sheet', sheet_names{n_sheet});
        end
    end
    sheet_names = sheet_names(1:n_sheet);

%% ================= 报告 =================
    fprintf('\n成功运行 cal_STRESS.m 的组数: %d / %d\n', n_ok, numel(groups));
    if ~isempty(fail_msg)
        fprintf('失败组:\n');
        for k = 1:numel(fail_msg)
            fprintf('  - %s\n', fail_msg{k});
        end
    end

    fprintf('\n--- 批次归属 ---\n');
    for b = 1:size(BATCHES, 1)
        sel = (batch_id == b);
        fprintf('  [%s] %2d 组: %s\n', BATCHES{b, 1}, sum(sel), ...
                strjoin(groups(sel), ' '));
    end
    if ~isempty(unassigned)
        fprintf('  [未分配] %2d 组: %s\n', numel(unassigned), strjoin(unassigned, ' '));
    end

    fprintf('\n--- %s ---\n', SHEET_INTER);
    disp(T_inter);
    fprintf('--- %s ---\n', SHEET_INTRA);
    disp(T_intra);
    fprintf('已写出 %d 个 sheet: %s\n', numel(sheet_names), strjoin(sheet_names, ', '));
    fprintf('文件: %s\n', OUT_XLSX);
end

%% ---------- 局部函数 ----------
function s = strip_ir(s)
%STRIP_IR 'f04i' / 'f04r' -> 'f04'（去掉结尾的 i 或 r，用来查批次）
if ~isempty(s) && (s(end) == 'i' || s(end) == 'r')
    s = s(1:end-1);
end
end
