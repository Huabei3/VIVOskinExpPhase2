% ========================================================================
% C_T_02_scene_CCT.m   （phase2 版）
%
% 对应 phase1: B_data_analysis\analyze\C_T_02_scene_CCT.m
%
% 作用:
%   汇总 21 个光源 / 14 个实景的"客观光源参数"：色温 CCT、平均肤色在渲染
%   结果里的位置（ave / ave_scaled / ave_aft）、背景灰卡亮度。这是纯光源侧的
%   表，和观察者族裔无关（phase2 的刺激与 phase1 完全同一批），因此逻辑与
%   phase1 一致，仅把 20 组的列表改为由 p2_config 统一生成。
%
% 输出:
%   documents\{iOr}\ave_CCT_N_XYZgray.mat
%   documents\{iOr}\scene_CCT_summary.xlsx
% ========================================================================
clc;
clear;
close all;
addpath("utils\")

C = p2_config();

%% ---------- 1. 开关 ----------
iOr = "r";              % r（14 实景，默认） | i（21 光源）

if iOr == "i"
    nPara      = numel(C.PICNAMES_I);
    picnames   = C.PICNAMES_I;
    indices_target = [5, 12, 19];            % h6k / m6k / l6k
else
    nPara      = numel(C.PICNAMES_R);
    picnames   = C.PICNAMES_R;
    indices_target = 1:numel(C.PICNAMES_R);  % 全部实景
end

% 20 个刺激组（顺序 = AS, CA, SA, AF，与 phase1 完全一致）
lastParts = {};
for iNat = 1:numel(C.STIM_NATIONS)
    for m = C.STIM_MODELS{iNat}
        lastParts{end+1} = char(m + iOr); %#ok<AGROW>
    end
end

%% ---------- 2. 渲染记录表（phase1 渲染阶段产出，phase2 直接复用） ----------
renderFile = fullfile(C.P2_ROOT, 'documents', char(iOr), 'render_data2.mat');
if ~isfile(renderFile)
    error('C_T_02: 缺渲染记录表 %s（该表由渲染流程产出，不在 fitting 流程里）', renderFile);
end
S = load(renderFile, 'render_map');
render_map = S.render_map;
Keys = keys(render_map);

grayFolder = fullfile(C.P2_ROOT, 'optimizedD', 'backGroundGray');

%% ---------- 3. 逐组汇总 ----------
ave_CCT     = nan(numel(lastParts), nPara, 1);
ave         = nan(numel(lastParts), nPara, 3);
ave_scaled  = nan(numel(lastParts), nPara, 3);
ave_aft     = nan(numel(lastParts), nPara, 3);
ave_gray    = nan(numel(lastParts), nPara, 3);
missKey     = {};

order = [1,2,3,4,7,5,6, 15,16,17,18,21,19,20, 8,9,10,11,14,12,13];   % i 组采集顺序 -> h3k..l8k

for iLast = 1:numel(lastParts)
    lp = lastParts{iLast};

    grayFile = fullfile(grayFolder, [lp '.mat']);
    if isfile(grayFile)
        g = load(grayFile, 'xyz_gray');
        xyz_gray = g.xyz_gray;
        if strcmp(iOr, "i") && size(xyz_gray, 1) == numel(order)
            xyz_gray = xyz_gray(order, :);
        end
        ave_gray(iLast, :, :) = xyz_gray;
    end

    for iPara = indices_target
        keyStr = strcat(lp, picnames(iPara));
        if ~isKey(render_map, char(keyStr))
            missKey{end+1} = char(keyStr); %#ok<AGROW>
            continue
        end
        curr = render_map(char(keyStr));
        ave_CCT(iLast, iPara, :)    = curr.CCT_val;
        ave(iLast, iPara, :)        = curr.average;
        ave_scaled(iLast, iPara, :) = curr.ave_scaled_val;
        ave_aft(iLast, iPara, :)    = curr.average_aft_val;
    end
end

if ~isempty(missKey)
    warning('C_T_02: 有 %d 个 key 不在 render_data2.mat 里，例如 %s', ...
        numel(missKey), strjoin(missKey(1:min(5, numel(missKey))), ', '));
end

%% ---------- 4. 汇总（按刺激族裔） ----------
% 族裔分组下标与 lastParts 的顺序一致：AS(1:6) CA(7:12) SA(13:16) AF(17:20)
stimIdx = cell(1, numel(C.STIM_NATIONS));
k = 0;
for iNat = 1:numel(C.STIM_NATIONS)
    n = numel(C.STIM_MODELS{iNat});
    stimIdx{iNat} = (k+1):(k+n);
    k = k + n;
end

ave_mean        = nan(numel(C.STIM_NATIONS), nPara, 3);
ave_scaled_mean = nan(numel(C.STIM_NATIONS), nPara, 3);
ave_aft_mean    = nan(numel(C.STIM_NATIONS), nPara, 3);
gray_mean       = nan(numel(C.STIM_NATIONS), nPara);
cct_mean        = nan(numel(C.STIM_NATIONS), nPara);

for iNat = 1:numel(C.STIM_NATIONS)
    idx = stimIdx{iNat};
    ave_mean(iNat, :, :)        = squeeze(mean(ave(idx, :, :), 1, 'omitnan'));
    ave_scaled_mean(iNat, :, :) = squeeze(mean(ave_scaled(idx, :, :), 1, 'omitnan'));
    ave_aft_mean(iNat, :, :)    = squeeze(mean(ave_aft(idx, :, :), 1, 'omitnan'));
    gray_mean(iNat, :)          = squeeze(mean(ave_gray(idx, :, 2), 1, 'omitnan'));
    cct_mean(iNat, :)           = squeeze(mean(ave_CCT(idx, :, 1), 1, 'omitnan'));
end

% 全族裔平均（phase1 的 ave_mean 用 AS 前 6 组；这里给全平均更稳）
ave_all_mean        = squeeze(mean(ave(1:numel(lastParts), :, :), 1, 'omitnan'));
ave_scaled_all_mean = squeeze(mean(ave_scaled(1:numel(lastParts), :, :), 1, 'omitnan'));
ave_aft_all_mean    = squeeze(mean(ave_aft(1:numel(lastParts), :, :), 1, 'omitnan'));
gray_all_mean       = squeeze(mean(ave_gray(1:numel(lastParts), :, 2), 1, 'omitnan'));
cct_all_mean        = squeeze(mean(ave_CCT(1:numel(lastParts), :, 1), 1, 'omitnan'));

scene_results = [cct_all_mean(:), gray_all_mean(:)];

%% ---------- 5. 保存 ----------
save(fullfile(C.P2_ROOT, 'documents', char(iOr), 'ave_CCT_N_XYZgray.mat'), ...
    'ave_CCT', 'ave_gray', 'ave', 'ave_scaled', 'ave_aft', ...
    'ave_mean', 'ave_scaled_mean', 'ave_aft_mean', 'gray_mean', 'cct_mean', ...
    'ave_all_mean', 'ave_scaled_all_mean', 'ave_aft_all_mean', ...
    'gray_all_mean', 'cct_all_mean', 'scene_results', 'lastParts');

% 场景汇总表：一行一个场景
sceneCol = picnames(indices_target)';
T = table(sceneCol, ...
    reshape(cct_all_mean(indices_target), [], 1), ...
    reshape(gray_all_mean(indices_target), [], 1), ...
    reshape(ave_aft_all_mean(indices_target, 1), [], 1), ...
    reshape(ave_aft_all_mean(indices_target, 2), [], 1), ...
    reshape(ave_aft_all_mean(indices_target, 3), [], 1), ...
    'VariableNames', {'Scene', 'CCT_K', 'GrayY', 'L_star', 'a_star', 'b_star'});

xlsxFile = fullfile(C.P2_ROOT, 'documents', char(iOr), 'scene_CCT_summary.xlsx');
if isfile(xlsxFile), delete(xlsxFile); end
writetable(T, xlsxFile, 'Sheet', 'allStim');

% 分族裔 sheet
for iNat = 1:numel(C.STIM_NATIONS)
    Tn = table(picnames(indices_target)', ...
        reshape(cct_mean(iNat, indices_target), [], 1), ...
        reshape(gray_mean(iNat, indices_target), [], 1), ...
        reshape(ave_aft_mean(iNat, indices_target, 1), [], 1), ...
        reshape(ave_aft_mean(iNat, indices_target, 2), [], 1), ...
        reshape(ave_aft_mean(iNat, indices_target, 3), [], 1), ...
        'VariableNames', {'Scene', 'CCT_K', 'GrayY', 'L_star', 'a_star', 'b_star'});
    writetable(Tn, xlsxFile, 'Sheet', char(C.STIM_NATIONS(iNat)));
end

fprintf('[C_T_02] %s 组：%d 个场景，CCT 范围 %.0f–%.0f K，已写出 %s\n', ...
    char(iOr), numel(indices_target), ...
    min(cct_all_mean(indices_target)), max(cct_all_mean(indices_target)), xlsxFile);
disp(scene_results(indices_target, :))
