%% EXPORT_STRESS_BY_OBSERVER  按 observer 汇总 STRESS_intra，每个 observer 一个 sheet（降序）
%
%   独立脚本，无入参，直接运行即可：
%     >> cd('D:\work\VIVOSkin_phase2\analyze\single_folder_STRESS')
%     >> export_STRESS_by_observer
%   或直接在编辑器里点 Run（会把工作目录切到本脚本所在目录）。
%
%   对每个 csv 路径调用 cal_STRESS_ind.m 取 STRESS_intra：
%     D:\work\VIVOSkin_phase2\ExpRes\renamed\{model}{i/r}\obs_{i_obs}\obs{i_obs}_{i_attribute}.csv
%
%   然后把同一个 observer 在【所有组 x 所有属性】上的 stress_value 合并，
%   从高到低排序，每个 observer 写一个 sheet。
%
%   输出 xlsx 三列:
%     Group          = {model}{i/r}     例如 f03i / m10r
%     Attribute      = Preference / Attractiveness / ... / Ruddy
%     STRESS_intra   = cal_STRESS_ind 的返回值（无重复评分时为 NaN，排在最后）
%
%   15 个 observer 分三批，各批做的组不同、且 obs 编号各自独立计数
%   （obs 编号 -> 人名 的映射已用源文件名 MD5 反查逐一核实）:
%     batch A : f01 f04 f07 f08 f09 f10    obs_01..05 = Malvin / Jerome / moussa / viva / philippe
%     batch B : f03 f06 m07 m08 m09 m10    obs_01..05 = NIWE / Luke Marrion Marufu /
%                                                     Balima Miguel / Tanatswa Mukokanduku /
%                                                     Tanatswa gwabda
%     batch C : f02 f05 m04                obs_01..05 = atascopy / placide / Bevin /
%                                                     sherlington / brian
%              （m04r 无数据时该组自动跳过；本批目前只采到 Preference / Healthy 两属性）
%
%   输出: ...\analyze\single_folder_STRESS\STRESS_intra_by_observer.xlsx

%% ---------------- 配置 ----------------
DATA_ROOT = 'D:\work\VIVOSkin_phase2\ExpRes\renamed';

% i_attribute 01..10 -> 名称，与 ExpRes\_copy_to_renamed.py 第 26-27 行一致
ATTR_NAMES = {'Preference', 'Attractiveness', 'Feminine', 'Cooperative', ...
              'Youth', 'Healthy', 'Fidelity', 'Harmony', 'Fair', 'Ruddy'};
n_attr = numel(ATTR_NAMES);

SIDES = {'i', 'r'};

% 三批采集者：obs 编号含义随批次变化，批次顺序不能调换
%   BATCHES(b).models = 该批 observer 评过的组（i/r 由 SIDES 展开）
%   BATCHES(b).names  = 该批 obs_01..obs_0N 对应的人名，顺序即 obs 编号
BATCHES = struct( ...
    'models', { ...
        {'f01', 'f04', 'f07', 'f08', 'f09', 'f10'}, ...   % batch A
        {'f03', 'f06', 'm07', 'm08', 'm09', 'm10'}, ...   % batch B
        {'f02', 'f05', 'm04','m01','m05',	'm02',...
            'm06',	'm03'} }, ...                      % batch C
    'names', { ...
        {'Malvin', 'Jerome', 'moussa', 'viva', 'philippe', ...
        'Divine',	'uneza',	'DANIELLA',	'Shanly',	'Ongama', ...
        'Areeba',	'Alishba', 	'Eman', 	'Alisha',	'Jenny'}, ...                % batch A: obs01..05
        {'NIWE NSHIME AMOS GYUY', 'Luke Marrion Marufu', 'Balima Miguel', ...  % batch B: obs01..05
         'Tanatswa Mukokanduku', 'Tanatswa gwabda', ...
         'Mercy',	'Axelle',	'natasha',	'tanya',	'chelsea', ...
         'raz sadia',	'sarwar', 'malaika',	'meenal',	'minahil'}, ... %'meenal babar',	'Arooha	minahil'
        {'atascopy', 'placide', 'Bevin', ...                                   % batch C: obs01..05
         'sherlington', 'brian', ...
         'Kirsty',	'noluthando',	'Samara',	'paballo',	'vanessa'} });

OBS_NAME    = [BATCHES.names];                             % 1 x 15，按批次拼接
OBS_PER_BATCH = cellfun(@numel, {BATCHES.names});          % 每批 observer 个数
BATCH_START = cumsum([1, OBS_PER_BATCH(1:end - 1)]);       % 每批首个 observer 的全局下标
n_obs        = sum(OBS_PER_BATCH);                         % 合计 observer 数

%% ---------------- 路径与环境 ----------------
here = fileparts(mfilename('fullpath'));       % 本脚本所在目录
if isempty(here)
    here = pwd;
end
OUT_XLSX = fullfile(here, 'STRESS_intra_by_observer.xlsx');

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

fprintf('数据源 : %s\n', DATA_ROOT);
fprintf('输出   : %s\n\n', OUT_XLSX);

%% ---------------- 逐组逐 observer 逐属性计算 ----------------
n_csv  = 0;
n_fail = 0;

for b = 1:numel(BATCHES)
    b_models = BATCHES(b).models;
    b_names  = BATCHES(b).names;

    for mi = 1:numel(b_models)
        model = b_models{mi};

        for si = 1:numel(SIDES)
            group   = [model SIDES{si}];                  % 例如 f03i
            grp_dir = fullfile(DATA_ROOT, group);

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

    fprintf('%-24s %6d %6d %10.4f\n', name, numel(v), sum(isnan(v)), ...
            max(v, [], 'omitnan'));
end

fprintf('\n共计算 %d 个 csv（失败 %d 个）-> %s\n', n_csv, n_fail, OUT_XLSX);

%% ---------------- 收尾 ----------------
warning(prev_warn);
cd(old_dir);
clear here old_dir prev_warn
