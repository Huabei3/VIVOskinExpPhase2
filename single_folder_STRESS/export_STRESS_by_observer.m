%% EXPORT_STRESS_BY_OBSERVER  按 nation + observer 汇总 STRESS_intra，每个 observer 一个 sheet（降序）
%
%   独立脚本，无入参，直接运行即可：
%     >> cd('D:\work\VIVOSkin_phase2\analyze\single_folder_STRESS')
%     >> export_STRESS_by_observer
%   或直接在编辑器里点 Run（会把工作目录切到本脚本所在目录）。
%
%   数据源（先按 nation 分目录，obs 编号在 nation 内部各自从 01 计数）:
%     D:\work\VIVOSkin_phase2\ExpRes\renamed\{nation}\{model}{i/r}\obs_{i_obs}\obs{i_obs}_{i_attribute}.csv
%   其中 nation = 'AF' | 'SA'，由下面【配置区】的 NATION 选择。
%
%   对每个 csv 路径调用 cal_STRESS_ind.m 取 STRESS_intra，
%   然后把同一个 observer 在【所有组 x 所有属性】上的 stress_value 合并，
%   从高到低排序，每个 observer 写一个 sheet。
%
%   输出 xlsx 三列:
%     Group          = {model}{i/r}     例如 f03i / m10r
%     Attribute      = Preference / Attractiveness / ... / Ruddy
%     STRESS_intra   = cal_STRESS_ind 的返回值（无重复评分时为 NaN，排在最后）
%
%   每个 sheet 的数据区下方额外追加一行汇总（写死数值，不是 Excel 公式）:
%     A = 空   B = 'AVERAGE'   C = 上方所有有限值的均值（NaN 不参与；全 NaN 则留空）
%
%   输出: ...\analyze\single_folder_STRESS\STRESS_intra_by_observer_{nation}.xlsx
%
%   observer 分三批，各批做的组不同、且 obs 编号各自独立计数
%   （obs 编号 -> 人名 的映射已用源文件名 MD5 反查逐一核实）:
%     batch A : f01 f04 f07 f08 f09 f10
%     batch B : f03 f06 m07 m08 m09 m10
%     batch C : f02 f05 m04 m01 m05 m02 m06 m03
%               （组目录不存在时自动跳过；本批目前只采到 Preference / Healthy 两属性）
%
%   nation 只改变【人名表】和【obs 根目录】，批次划分与组清单两者共用:
%     AF : 每批 10 人 -> obs_01..obs_10
%     SA : batch A/B 各 5 人 -> obs_01..obs_05；batch C 暂空（以后可能补充）
%
%   目录结构前提（由 copy_to_renamed.m 生成）:
%     renamed\{nation}\{model}{i/r}\obs_{i_obs}\obs{i_obs}_{i_attribute}.csv

%% ---------------- 配置 ----------------
DATA_ROOT = 'D:\work\VIVOSkin_phase2\ExpRes\renamed';

NATION = 'SA';          % <<< 要分析的 nation：'AF' 或 'SA'

% i_attribute 01..10 -> 名称，与 ExpRes\_copy_to_renamed.py 第 26-27 行一致
ATTR_NAMES = {'Preference', 'Attractiveness', 'Feminine', 'Cooperative', ...
              'Youth', 'Healthy', 'Fidelity', 'Harmony', 'Fair', 'Ruddy'};
n_attr = numel(ATTR_NAMES);

SIDES = {'i', 'r'};

% 三批采集者：obs 编号含义随批次变化，批次顺序不能调换
%   BATCH_MODELS{b} = 该批 observer 评过的组（i/r 由 SIDES 展开）
%   名单为空 {} 的批次 (目前只有 SA 的 batch C) 会自动跳过
BATCH_MODELS = { ...
    {'f01', 'f04', 'f07', 'f08', 'f09', 'f10'}, ...              % batch A
    {'f03', 'f06', 'm07', 'm08', 'm09', 'm10'}, ...              % batch B
    {'f02', 'f05', 'm04', 'm01', 'm05', 'm02', 'm06', 'm03'} };  % batch C

% 每个 nation 各自的 observer 名单（顺序即 obs 编号，位置 1 -> obs_01）
OBS_SETS = struct();
OBS_SETS.AF = { ...
    {'Malvin', 'Jerome', 'moussa', 'viva', 'philippe', ...
     'Divine', 'uneza', 'DANIELLA', 'Shanly', 'Ongama'}, ...              % batch A: obs01..10
    {'NIWE', 'Luke Marrion Marufu', 'Balima Miguel', ...
     'Tanatswa Mukokanduku', 'Tanatswa gwabda', ...
     'Mercy', 'Axelle', 'natasha', 'tanya', 'chelsea'}, ...               % batch B: obs01..10
    {'atascopy', 'placide', 'Bevin', 'sherlington', 'brian', ...
     'Kirsty', 'noluthando', 'Samara', 'paballo', 'vanessa'} };           % batch C: obs01..10
OBS_SETS.SA = { ...
    {'Areeba', 'Alishba', 'Eman', 'Alisha', 'Jenny'}, ...                 % batch A: obs01..05
    {'raz sadia', 'sarwar malaika', 'meenal babar', 'Arooha', 'minahil'}, ...          % batch B: obs01..05
    {}};                                                                   % batch C: 暂空

NATION = upper(strtrim(NATION));
if ~isfield(OBS_SETS, NATION)
    error('NATION 只能是 AF 或 SA，当前给的是: %s', NATION);
end

% 注意: 这里不能包一层 {} —— struct() 用 cell 的尺寸决定结构体数组大小,
%       包一层会退化成 1x1 标量, BATCHES(b).models 取到的是整个 cell-of-cell,
%       后面 fullfile 得到 cell, exist 就会报"第一个输入必须为字符串标量或字符向量"
BATCHES = struct('models', BATCH_MODELS, ...
                 'names',  OBS_SETS.(NATION));   % 1 x 3，字段即各批的组清单 / 人名表

OBS_NAME      = [BATCHES.names];                           % 1 x n_obs，按批次拼接
OBS_PER_BATCH = cellfun(@numel, {BATCHES.names});          % 每批 observer 个数（可为 0）
BATCH_START   = cumsum([1, OBS_PER_BATCH(1:end - 1)]);     % 每批首个 observer 的全局下标
n_obs         = sum(OBS_PER_BATCH);                        % 合计 observer 数

%% ---------------- 路径与环境 ----------------
here = fileparts(mfilename('fullpath'));       % 本脚本所在目录
if isempty(here)
    here = pwd;
end
OUT_XLSX = fullfile(here, sprintf('STRESS_intra_by_observer_%s.xlsx', NATION));

addpath(here);                                 % cal_STRESS_ind.m
addpath(fullfile(fileparts(here), 'utils'));   % mapMatrixValues.m

old_dir = cd(here);                            % cal_STRESS_ind 内部用的是相对 "utils\"
prev_warn = warning('off', 'MATLAB:mpath:nameNonexistentOrNotADirectory');

if exist(OUT_XLSX, 'file') == 2
    delete(OUT_XLSX);                          % 先删除，避免上一次 run 的旧 sheet 残留
end

%% ---------------- 建立 n_obs 个 observer 的空桶 ----------------
G = cell(n_obs, 1);   % group  名
A = cell(n_obs, 1);   % attribute 名
V = cell(n_obs, 1);   % stress 值
for k = 1:n_obs
    G{k} = cell(0, 1);
    A{k} = cell(0, 1);
    V{k} = zeros(0, 1);
end

fprintf('nation : %s\n', NATION);
fprintf('数据源 : %s\n', fullfile(DATA_ROOT, NATION));
fprintf('输出   : %s\n\n', OUT_XLSX);

%% ---------------- 逐批逐组逐 observer 逐属性计算 ----------------
n_csv  = 0;
n_fail = 0;

for b = 1:numel(BATCHES)
    b_models = BATCHES(b).models;
    b_names  = BATCHES(b).names;

    if isempty(b_names)
        fprintf('[batch %d] 名单为空，跳过\n', b);
        continue;
    end

    for mi = 1:numel(b_models)
        model = b_models{mi};

        for si = 1:numel(SIDES)
            group   = [model SIDES{si}];                  % 例如 f03i
            grp_dir = fullfile(DATA_ROOT, NATION, group); % 先 nation 再组

            if exist(grp_dir, 'dir') ~= 7
                fprintf('[%-5s] 组目录不存在，跳过\n', group);
                continue;
            end

            n_used = 0;
            for oi = 1:numel(b_names)
                obs_dir = fullfile(grp_dir, sprintf('obs_%02d', oi));

                for ai = 1:n_attr
                    csv_path = fullfile(obs_dir, sprintf('obs%02d_%02d.csv', oi, ai));
                    if exist(csv_path, 'file') ~= 2
                        continue;                          % 该 (observer, attribute) 无数据
                    end

                    try
                        v = cal_STRESS_ind(csv_path);
                    catch ME
                        warning('计算失败: %s\n  -> %s', csv_path, ME.message);
                        n_fail = n_fail + 1;
                        continue;
                    end

                    k = BATCH_START(b) + oi - 1;           % 全局 observer 下标
                    G{k}{end + 1, 1} = group;
                    A{k}{end + 1, 1} = ATTR_NAMES{ai};
                    V{k}(end + 1, 1) = v;

                    n_csv  = n_csv + 1;
                    n_used = n_used + 1;
                end
            end

            fprintf('[%-5s] 有效 csv = %2d 个\n', group, n_used);
        end
    end
end

%% ---------------- 每个 observer 降序排序 + 写 sheet ----------------
fprintf('\n%-24s %6s %6s %10s\n', 'Observer', 'N', 'NaN', 'Max');
fprintf('%s\n', repmat('-', 1, 50));

for k = 1:n_obs
    name = OBS_NAME{k};

    if isempty(V{k})
        fprintf('%-24s %6d  无数据，跳过\n', name, 0);
        continue;
    end

    v = V{k};
    % 从高到低；NaN（无重复评分）统一排到最后
    [v_sorted, ord] = sort(v, 'descend', 'MissingPlacement', 'last');

    T = table(G{k}(ord), A{k}(ord), v_sorted, ...
              'VariableNames', {'Group', 'Attribute', 'STRESS_intra'});

    % Excel sheet 名限制：<= 31 字符，且不能含 : \ / ? * [ ]
    sheet_name = regexprep(name, '[:\\/?*\[\]]', '_');
    if numel(sheet_name) > 31
        sheet_name = sheet_name(1:31);
    end

    writetable(T, OUT_XLSX, 'Sheet', sheet_name);

    % ---- 末尾追加一行汇总: A 空 / B 写 'AVERAGE' / C 放均值 (只统计有限值, NaN 跳过) ----
    v_fin  = v_sorted(~isnan(v_sorted));
    v_mean = mean(v_fin);                       % 空 -> NaN
    if isnan(v_mean)
        mean_cell = {''};                       % 全 NaN 时留空白, 不写 'NaN' 文本
        mean_txt  = '   NaN';
    else
        mean_cell = {v_mean};
        mean_txt  = sprintf('%10.4f', v_mean);
    end
    % 表头占 1 行, 数据占 numel(v_sorted) 行, 汇总行紧随其后
    writecell([{''}, {'AVERAGE'}, mean_cell], OUT_XLSX, ...
              'Sheet', sheet_name, 'Range', sprintf('A%d', numel(v_sorted) + 2));

    fprintf('%-24s %6d %6d %10.4f   mean=%s\n', name, numel(v), sum(isnan(v)), ...
            max(v, [], 'omitnan'), mean_txt);
end

fprintf('\n共计算 %d 个 csv（失败 %d 个）-> %s\n', n_csv, n_fail, OUT_XLSX);

%% ---------------- 收尾 ----------------
warning(prev_warn);
cd(old_dir);
clear here old_dir prev_warn
