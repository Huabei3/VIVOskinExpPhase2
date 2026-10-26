function export_STRESS_intra_by_attribute(source_folder_type)
%EXPORT_STRESS_INTRA_BY_ATTRIBUTE 汇总 observer x attribute 的 STRESS_intra 到一个 xlsx
%
%   开关 : SOURCE_FOLDER_TYPE（见下方配置区）
%          直接运行   -> 用配置区里的默认值
%          命令行覆盖 -> export_STRESS_intra_by_attribute('phase1')
%
%   源目录由开关 SOURCE_FOLDER_TYPE 决定：
%     'phase2' -> D:\work\VIVOSkin_phase2\ExpRes\renamed\{nation}   (nation 见配置区 NATION)
%                 路径形如 {model}{i/r}\obs_%02d\obs%02d_%02d.csv
%                 group 自动扫描 {nation} 下全部子文件夹，observer 行数按实际 obs_XX 目录决定
%     'phase1' -> D:\work\VIVOSkin_phase2\ExpRes\phase1_renamed
%                 只处理 f09i/f09r/f10i/f10r 四个 group，且只取 non_model 分支
%                 路径形如 {model}{i/r}\non_model\obs_%02d\obs%02d_%02d.csv
%                 non_model\discarded\ 视为废弃数据，不参与计算
%                 observer 行数按该组实际出现的 obs_XX 目录动态决定
%
%   计算方式 : 对每个 csv 调用 cal_STRESS_ind.m，取其 STRESS_intra
%   输出结构 : 一个 xlsx，每个 sheet = 一个 {model}{i/r} 组
%                行   = obs01 .. obsNN
%                列   = attribute (Preference/Youth/Healthy/Fidelity/Fair/Ruddy ..)
%                单元格 = 该组 该 observer 该 attribute 的 STRESS_intra
%              缺失的 (observer, attribute) 组合填 NaN
%   输出路径 : ...\analyze\single_folder_STRESS\STRESS_intra_by_attribute_{phase}.xlsx
%
%   用法: >> cd('D:\work\VIVOSkin_phase2\analyze\single_folder_STRESS')
%         >> export_STRESS_intra_by_attribute

%% ---------------- 配置 ----------------
    % ★ 总开关：'phase2' 或 'phase1'
    SOURCE_FOLDER_TYPE = 'phase1';                 % <- 默认相位，改这一行即可切换
    if nargin >= 1 && ~isempty(source_folder_type)
        SOURCE_FOLDER_TYPE = source_folder_type;   % 命令行入参优先
    end

    OUT_DIR = 'D:\work\VIVOSkin_phase2\analyze\single_folder_STRESS';

    % ★ phase2 的 nation 维度：目录结构 renamed\{nation}\{model}{i/r}\obs_XX\obsXX_YY.csv
    %   一次只算一个 nation —— 同名组（f04i / f07i / ...）在 AF 与 SA 下是不同的人，
    %   混在一张表里按行号比较会误读
    NATION = 'AF';                                 % 'AF' 或 'SA'

    % attribute 编号(1..10) -> 名称，与 ExpRes\_copy_to_renamed.py 第 26-27 行一致
    ATTR_NAMES = {'Preference', 'Attractiveness', 'Feminine', 'Cooperative', ...
                  'Youth', 'Healthy', 'Fidelity', 'Harmony', 'Fair', 'Ruddy'};
    n_attr = numel(ATTR_NAMES);

    switch lower(SOURCE_FOLDER_TYPE)
        case 'phase2'
            DATA_ROOT   = fullfile('D:\work\VIVOSkin_phase2\ExpRes\renamed', NATION);
            GROUP_NAMES = {};              % {} = 自动扫描 {nation} 下全部组目录
            L2_NAME     = '';              % phase2 无分支层
            OBS_IDS     = [];              % [] = 按实际 obs_XX 目录动态决定
                                           %      （AF 每批最多 10 个；SA 只有 5 个）
        case 'phase1'
            DATA_ROOT   = 'D:\work\VIVOSkin_phase2\ExpRes\phase1_renamed';
            GROUP_NAMES = {'f09i', 'f09r', 'f10i', 'f10r'};
            L2_NAME     = 'non_model';     % 只取 non_model 分支
            OBS_IDS     = [];              % [] = 按实际 obs_XX 目录动态决定
        otherwise
            error('SOURCE_FOLDER_TYPE 只能是 ''phase2'' 或 ''phase1''，当前值: %s', ...
                  SOURCE_FOLDER_TYPE);
    end

    if strcmpi(SOURCE_FOLDER_TYPE, 'phase2')
        OUT_XLSX = fullfile(OUT_DIR, sprintf('STRESS_intra_by_attribute_%s_%s.xlsx', ...
                                             lower(SOURCE_FOLDER_TYPE), NATION));
    else
        OUT_XLSX = fullfile(OUT_DIR, sprintf('STRESS_intra_by_attribute_%s.xlsx', ...
                                             lower(SOURCE_FOLDER_TYPE)));
    end

    if exist(OUT_DIR, 'dir') ~= 7
        mkdir(OUT_DIR);
    end

%% ---------------- 保证依赖在路径上 ----------------
    here = fileparts(mfilename('fullpath'));
    addpath(here);                                 % cal_STRESS_ind.m 所在目录
    addpath(fullfile(fileparts(here), 'utils'));   % mapMatrixValues.m 所在目录

    % cal_STRESS_ind 内部有 addpath("utils\") 相对路径，会刷屏警告，这里临时静音
    prev_warn  = warning('off', 'MATLAB:mpath:nameNonexistentOrNotADirectory');
    cleanupObj = onCleanup(@() warning(prev_warn)); %#ok<NASGU>

%% ---------------- 扫描 group ----------------
    if isempty(GROUP_NAMES)
        d       = dir(DATA_ROOT);
        is_sub  = [d.isdir] & ~ismember({d.name}, {'.', '..'});
        groups  = sort({d(is_sub).name});
    else
        groups  = GROUP_NAMES;         % 用户在配置区指定的 group 列表（保持顺序）
    end

    if exist(OUT_XLSX, 'file') == 2
        delete(OUT_XLSX);              % 先删除，避免上一次运行的旧 sheet 残留
    end

    fprintf('数据源(%s): %s\n', lower(SOURCE_FOLDER_TYPE), DATA_ROOT);
    if ~isempty(L2_NAME)
        fprintf('分支层     : %s   (discarded/ 已排除)\n', L2_NAME);
    end
    fprintf('输出文件   : %s\n\n', OUT_XLSX);

%% ---------------- 逐 group 计算 ----------------
    for g = 1:numel(groups)
        group = groups{g};

        if isempty(L2_NAME)
            grp_dir = fullfile(DATA_ROOT, group);
            label   = group;
        else
            grp_dir = fullfile(DATA_ROOT, group, L2_NAME);
            label   = sprintf('%s/%s', group, L2_NAME);
        end

        if exist(grp_dir, 'dir') ~= 7
            fprintf('[%s] 目录不存在，跳过: %s\n', label, grp_dir);
            continue;
        end

        if isempty(OBS_IDS)
            [obs_ids, obs_dirs] = scan_obs_ids(grp_dir);   % 动态：目录名直接取自磁盘
        else
            obs_ids  = OBS_IDS(:)';                        % 固定：obs_01..obs_05
            obs_dirs = arrayfun(@(o) sprintf('obs_%02d', o), obs_ids, ...
                                'UniformOutput', false);
        end

        if isempty(obs_ids)
            fprintf('[%s] 未找到任何 obs_XX 目录，跳过\n', label);
            continue;
        end

        M      = nan(numel(obs_ids), n_attr);         % 行 = observer, 列 = attribute
        n_used = 0;

        for oi = 1:numel(obs_ids)
            o       = obs_ids(oi);
            obs_dir = fullfile(grp_dir, obs_dirs{oi});

            for a = 1:n_attr
                csv_path = fullfile(obs_dir, sprintf('obs%02d_%02d.csv', o, a));
                if exist(csv_path, 'file') ~= 2
                    continue;          % 该 (observer, attribute) 无数据 -> 保持 NaN
                end
                try
                    M(oi, a) = cal_STRESS_ind(csv_path);
                    n_used   = n_used + 1;
                catch ME
                    warning('计算失败: %s\n  -> %s', csv_path, ME.message);
                end
            end
        end

        % 只保留至少有一个有效值的 attribute 列
        col_idx   = find(any(~isnan(M), 1));
        col_names = ATTR_NAMES(col_idx);
        M         = M(:, col_idx);

        if isempty(col_names)
            fprintf('[%s] 未找到任何可用数据，跳过\n', label);
            continue;
        end

        row_labels = arrayfun(@(o) sprintf('obs%02d', o), obs_ids, 'UniformOutput', false);

        T = array2table(M, 'VariableNames', col_names);
        T = addvars(T, row_labels(:), 'Before', 1, 'NewVariableNames', {'Observer'});

        writetable(T, OUT_XLSX, 'Sheet', group);   % sheet 名用 group（f09i 等）

        fprintf('[%s] 有效 csv = %2d 个 | 行 = %2d | 列 = %s\n', ...
                label, n_used, numel(obs_ids), strjoin(col_names, ', '));
    end

    fprintf('\n全部完成 -> %s\n', OUT_XLSX);
end

% ------------------------------------------------------------------------
function [ids, dirs] = scan_obs_ids(grp_dir)
%SCAN_OBS_IDS 扫描 grp_dir 下形如 obs_XX / obsXX 的子文件夹
%   返回: ids  = 升序 observer 编号向量
%         dirs = 与之对应的真实目录名
%                (phase1 命名为 obs02，phase2 命名为 obs_02，两者都要兼容)
%   只匹配 ^obs_?\d+$，所以 non_model\discarded\ 等其它子目录会被自动忽略
    d    = dir(fullfile(grp_dir, 'obs*'));
    d    = d([d.isdir]);
    ids  = [];
    dirs = {};
    for k = 1:numel(d)
        tk = regexp(d(k).name, '^obs_?(\d+)$', 'tokens', 'once');
        if ~isempty(tk)
            ids(end + 1)  = str2double(tk{1});   %#ok<AGROW>
            dirs{end + 1} = d(k).name;           %#ok<AGROW>
        end
    end
    [ids, si] = sort(ids);
    dirs = dirs(si);
end
