% ========================================================================
% C_F_06_cal_MCDM.m   （phase2 版）
%
% 对应 phase1: B_data_analysis\analyze\C_F_06_cal_MCDM.m
%
% 作用:
%   MCDM（Multi-Criteria Decision Making 距离）= 每个观察者单独拟合出的
%   偏好中心，与该属性整体的加权平均中心之间的 CIEDE2000 距离。
%   距离越大说明该类观察者的判断越分散。本脚本负责
%     (1) 对每个 {组, 属性} 调 process_data_MCDM 计算 MCDM 并落盘；
%     (2) 汇总成 MCDM_global，按刺激族裔 × 属性画柱状图。
%
% phase2 差异:
%   1) 原始评分在 D:\work\VIVOSkin_phase2\ExpRes\renamed\{AF}\{组}\obs_XX\obsXX_AA.csv，
%      不在 analyze\expRes 下，所以 source_folder 要用 C.RENAMED 拼；
%   2) 输出路径插入观察者族裔层，避免将来 SA 结果覆盖 AF；
%   3) phase2 只有 non_model，原来的 model_group（Fidelity 专用）分支去掉；
%   4) 属性集不再固定 1..10，而是"目录里真实存在哪些就画哪些"。
%
% 输出:
%   AnalyseResults_p\efit_p\unscaled\{obsNation}\{组}\non_model\{attr}\MCDM\MCDMdata.mat
%   AnalyseResults_p\efit_p\unscaled\sum_list\MCDM\{obsNation}\{iOr}\MCDMdata.mat
%   ellip_pic_p\efit_p\MCDM\{obsNation}\MCDM_{iOr}.jpg
% ========================================================================
% rehash toolboxcache
close all;
clc;
clear;
addpath("utils\")

C = p2_config();

%% ---------- 1. 开关 ----------
iOr        = "i";          % i（21 光源） | r（14 实景）
obsType    = "non_model";
ATTRIBUTES = 1:C.nAttr;    % 扫全部槽位，缺数据的自动跳过

if iOr == "i"
    nPara = numel(C.PICNAMES_I);
else
    nPara = numel(C.PICNAMES_R);
end
nObsMax = 20;              % observer 上限（AF 实际 10 人）

%% ---------- 2. 逐观察者族裔 ----------
for iObsNation = 1:numel(C.OBS_NATIONS)
    obsNation = C.OBS_NATIONS{iObsNation};

    renameRoot = fullfile(C.RENAMED, obsNation);
    if ~isfolder(renameRoot)
        warning('C_F_06: 找不到原始评分目录 %s，跳过', renameRoot);
        continue
    end

    % 2.1 组列表
    lastParts = {};
    for iNat = 1:numel(C.STIM_NATIONS)
        for m = C.STIM_MODELS{iNat}
            lastParts{end+1} = char(m + iOr); %#ok<AGROW>
        end
    end
    nSub = numel(lastParts);

    % 2.2 族裔分组下标
    stimIdx = cell(1, numel(C.STIM_NATIONS));
    k = 0;
    for iNat = 1:numel(C.STIM_NATIONS)
        n = numel(C.STIM_MODELS{iNat});
        stimIdx{iNat} = (k+1):(k+n);
        k = k + n;
    end

    MCDM_global = nan(nSub, C.nAttr, nPara, nObsMax);

    startTime = datetime('now');
    for iSub = 1:nSub
        lp = lastParts{iSub};
        sourceFolder = fullfile(renameRoot, lp);
        if ~isfolder(sourceFolder), continue; end

        for a = ATTRIBUTES
            attrSerial = strcat(sprintf('%02d', a), C.ATTRIBUTE_NAMES(a));

            dirRes = findSpecificFiles(sourceFolder, a);
            if isempty(dirRes), continue; end

            outFolder = fullfile(C.ANALYSE_ROOT, C.Dtype, C.scale_type_origin, ...
                obsNation, lp, obsType, char(attrSerial));
            if ~isfolder(fullfile(outFolder, 'ellipPara'))
                fprintf('[skip] %s / %s：还没有椭圆拟合结果\n', lp, char(attrSerial));
                continue
            end
            if ~isfolder(outFolder), mkdir(outFolder); end

            fprintf('Processing MCDM: %s  %s  %s\n', obsNation, lp, char(attrSerial));
            MCDM = process_data_MCDM(dirRes, outFolder, lp, C.Dtype);

            % 填进汇总张量（observer 维按 nObsMax 截断/补齐）
            nObs = min(size(MCDM, 2), nObsMax);
            nRow = min(size(MCDM, 1), nPara);
            MCDM_global(iSub, a, 1:nRow, 1:nObs) = MCDM(1:nRow, 1:nObs);
        end
        fprintf('[MCDM] %s 组 %2d/%2d %s 完成\n', obsNation, iSub, nSub, lp);
    end

    % 2.3 汇总落盘
    sumDir = fullfile(C.ANALYSE_ROOT, C.Dtype, C.scale_type_origin, ...
        'sum_list', 'MCDM', obsNation, char(iOr));
    if ~exist(sumDir, 'dir'), mkdir(sumDir); end
    MCDM_global_mean = mean(MCDM_global(:), 'omitnan');
    save(fullfile(sumDir, 'MCDMdata.mat'), 'MCDM_global', 'MCDM_global_mean', ...
        'lastParts', 'stimIdx');
    fprintf('[MCDM] %s/%s 全局平均 = %.3f，用时 %s\n', ...
        obsNation, iOr, MCDM_global_mean, string(datetime('now') - startTime));

    %% ---------- 3. 族裔 × 属性 柱状图 ----------
    MCDM_nation = nan(numel(C.STIM_NATIONS), C.nAttr);
    for iNat = 1:numel(C.STIM_NATIONS)
        for a = ATTRIBUTES
            sub = MCDM_global(stimIdx{iNat}, a, :, :);
            if all(isnan(sub(:))), continue; end
            MCDM_nation(iNat, a) = mean(sub(:), 'omitnan');
        end
    end

    % 只画有数据的属性
    attrOK = find(any(~isnan(MCDM_nation), 1));
    if isempty(attrOK)
        warning('C_F_06: %s/%s 没有任何 MCDM 结果，跳过绘图', obsNation, iOr);
        continue
    end

    nColor = numel(attrOK);
    hues   = linspace(0, 1, nColor + 1); hues = hues(1:end-1);
    colors = hsv2rgb([hues', 0.8*ones(nColor,1), 0.8*ones(nColor,1)]);

    h = figure('Color', 'white'); hold on; box on; grid on;
    barWidth = 0.8 / nColor;
    for kk = 1:nColor
        a = attrOK(kk);
        x = (1:numel(C.STIM_NATIONS)) + (kk - 1)*barWidth - barWidth*(nColor-1)/2;
        bar(x, MCDM_nation(:, a), barWidth, 'FaceColor', colors(kk,:), ...
            'DisplayName', char(strcat(sprintf('%02d', a), C.ATTRIBUTE_NAMES(a))));
    end
    set(gca, 'XTick', 1:numel(C.STIM_NATIONS));
    set(gca, 'XTickLabel', cellstr(C.STIM_NATION_NAMES));
    ylabel('MCDM (\DeltaE_{00})');
    title(sprintf('MCDM by stimuli ethnicity | observer %s | %s', obsNation, char(iOr)));
    if numel(attrOK) <= 10
        legend('Location', 'eastoutside');
    end
    yLimMax = max(MCDM_nation(:), [], 'omitnan');
    ylim([0, max(1, yLimMax * 1.2)]);

    picDir = fullfile(C.PIC_ROOT, C.Dtype, 'MCDM', obsNation);
    if ~exist(picDir, 'dir'), mkdir(picDir); end
    exportgraphics(h, fullfile(picDir, strcat('MCDM_', char(iOr), '.jpg')), ...
        'Resolution', 300);
    close(h);

    % 控制台核对
    fprintf('\n=== %s / %s：MCDM（行=刺激族裔，列=属性） ===\n', obsNation, iOr);
    fprintf('%8s', 'nation');
    for a = attrOK, fprintf('%10s', sprintf('%02d', a)); end
    fprintf('\n');
    for iNat = 1:numel(C.STIM_NATIONS)
        fprintf('%8s', C.STIM_NATIONS(iNat));
        for a = attrOK, fprintf('%10.3f', MCDM_nation(iNat, a)); end
        fprintf('\n');
    end

    % 导出 xlsx（每族裔一个 sheet + 汇总）
    xlsxFile = fullfile(picDir, strcat('MCDM_', char(iOr), '.xlsx'));
    if isfile(xlsxFile), delete(xlsxFile); end
    attrNames = cell(1, numel(attrOK));
    for kk = 1:numel(attrOK)
        a = attrOK(kk);
        attrNames{kk} = char(strcat(sprintf('%02d', a), C.ATTRIBUTE_NAMES(a)));
    end
    T = array2table(MCDM_nation(:, attrOK), 'VariableNames', attrNames, ...
        'RowNames', cellstr(C.STIM_NATIONS));
    writetable(T, xlsxFile, 'Sheet', 'allNations', 'WriteRowNames', true);
    for iNat = 1:numel(C.STIM_NATIONS)
        Ts = table(attrNames(:), MCDM_nation(iNat, attrOK)', ...
            'VariableNames', {'Attribute', 'MCDM'});
        writetable(Ts, xlsxFile, 'Sheet', char(C.STIM_NATIONS(iNat)));
    end
    fprintf('[MCDM] 已写出 %s\n', xlsxFile);
end
