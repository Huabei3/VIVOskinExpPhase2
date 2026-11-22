clear;clc;close all;

%% ================= 路径设置 =================
script_dir    = 'D:\work\VIVOSkin_phase2\analyze\single_folder_STRESS';
source_folder = 'D:\work\VIVOSkin_phase2\ExpRes\com.example.f07ip2\ma yi an';

% 保证 cal_STRESS_ind / mapMatrixValues 可被找到（不依赖当前工作目录）
addpath(script_dir);
addpath(fullfile(script_dir, '..', 'utils'));   % mapMatrixValues.m
if exist('STRESS.m', 'file') ~= 2
    warning('未在当前 MATLAB path 上找到 STRESS.m，请确认 D:\work\MATLABlib 已加入 path');
end

%% ================= 配置 =================
attrs_all = {'Preference', 'Fidelity', 'Healthy', 'Youth', 'Fair', 'Ruddy'};
MIN_ROWS  = 20;   % 有效评分行数下限，低于此值判为导出中断

%% ================= 收集待分析文件 =================
if ~isfolder(source_folder)
    error('目录不存在: %s', source_folder);
end
files = dir(fullfile(source_folder, '*.csv'));
if isempty(files)
    error('目录下没有找到 csv 文件: %s', source_folder);
end
fprintf('待分析文件数: %d\n\n', numel(files));

%% ================= 逐个文件计算 STRESS =================
n      = numel(files);
records = {};   % 累积：file, attr, value, status

for i = 1:n
    fname     = string(files(i).name);
    file_path = fullfile(files(i).folder, fname);
    attr      = parse_attr(fname, attrs_all);

    % 预检：跳过导出中断/未完成的 csv
    [ok, n_row, reason] = check_score_file(file_path, MIN_ROWS);
    if ~ok
        status = "跳过: " + reason;
        fprintf('%-58s | %-10s | %s (有效数据行=%d)\n', fname, attr, status, n_row);
        records(end+1, :) = {fname, attr, NaN, status};
        continue;
    end

    value = NaN;
    try
        value = cal_STRESS_ind(file_path);
        if isnan(value)
            status = "无重复评分(NaN)";
        else
            status = "OK";
        end
    catch ME
        status = "ERROR: " + string(ME.message);
    end

    fprintf('%-58s | %-10s | STRESS=%s | %s\n', ...
        fname, attr, num2str(value, '%.4f'), status);
    records(end+1, :) = {fname, attr, value, status};
end

%% ================= 汇总 =================
R = cell2table(records, 'VariableNames', {'File', 'Attribute', 'STRESS', 'Status'});
R.Attribute = string(R.Attribute);

fprintf('\n==================== 明细 ====================\n');
disp(R);

valid = ~isnan(R.STRESS);
if any(valid)
    T_mean = groupsummary(R(valid, :), 'Attribute', 'mean', 'STRESS');
    fprintf('==================== 按属性汇总 ====================\n');
    disp(T_mean);
    fprintf('有效文件 %d / %d，全局 STRESS 均值 = %.4f\n', ...
        sum(valid), height(R), mean(R.STRESS(valid)));
else
    T_mean = table();
    fprintf('没有任何文件得到有效 STRESS 值。\n');
end

%% ================= 属性覆盖检查 =================
have = unique(R.Attribute(valid));
miss = setdiff(string(attrs_all), have);
if isempty(miss)
    fprintf('属性覆盖: 6/6 齐全\n');
else
    fprintf('属性覆盖: 缺 %s\n', strjoin(cellstr(miss), ', '));
end

% 同一属性存在多个文件时提示（便于人工取舍）
[uniq_attr, ~, grp] = unique(R.Attribute(valid));
cnt = accumarray(grp, 1);
multi = uniq_attr(cnt > 1);
if ~isempty(multi)
    fprintf('注意: 以下属性有多个 csv，汇总时已取均值 -> %s\n', strjoin(cellstr(multi), ', '));
end

%% ================= 写出 xlsx =================
[~, folder_name] = fileparts(source_folder);
safe_name = regexprep(folder_name, '\s+', '_');   % 目录名含空格则替换为下划线
out_xlsx  = fullfile(script_dir, sprintf('STRESS_%s_%s.xlsx', safe_name, datestr(now, 'yyyymmdd_HHMMSS')));
writetable(R, out_xlsx, 'Sheet', 'detail');
if ~isempty(T_mean)
    writetable(T_mean, out_xlsx, 'Sheet', 'by_attribute');
end
fprintf('结果已保存到: %s\n', out_xlsx);


%% ================= 局部函数 =================
function attr = parse_attr(fname, attrs_all)
    % 从文件名中识别属性词（不区分大小写），比按 "_" 切分更稳
    attr = "UNKNOWN";
    for k = 1:numel(attrs_all)
        if contains(fname, attrs_all{k}, 'IgnoreCase', true)
            attr = string(attrs_all{k});
            return;
        end
    end
end

function [ok, n_row, reason] = check_score_file(file_path, MIN_ROWS)
    % 预检评分 csv：是否为完整的 {label, picname, score} 三列数值数据
    % 导出中断的文件通常数据行极少，且尾部混入 "File Created Time" 等文本行
    ok = false; n_row = 0; reason = "";

    try
        M = readmatrix(file_path);   % 文本/空行会被处理成 NaN 行
    catch
        reason = "无法解析为数值矩阵";
        return;
    end

    if isempty(M) || size(M, 2) < 3
        reason = "列数不足 3 列";
        return;
    end

    valid_row = ~all(isnan(M), 2) & ~isnan(M(:, 1)) & ~isnan(M(:, 3));
    n_row = sum(valid_row);

    if n_row < MIN_ROWS
        reason = "数据不完整(导出中断)";
    else
        ok = true;
    end
end
