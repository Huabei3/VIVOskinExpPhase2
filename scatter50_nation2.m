% ========================================================================
% scatter50_nation2.m   （phase2 版）
%
% 对应 phase1: B_data_analysis\analyze\scatter50_nation2.m
%
% 作用:
%   把同一族裔下多个受试者、多个场景的评分点合并，重新拟合"50% 等值线"
%   椭圆，得到比单个受试者更稳的族裔级偏好椭圆，并把 par 落盘给
%   C_F_15_compare / C_F_21_compare_scene 使用。
%
% phase2 差异:
%   1) 数据路径多一层观察者族裔 obsNation；
%   2) phase1 调用的 my_ellipsoidfit3_free 在工程里并不存在（只有调用、没有
%      定义），本版改用 phase2 utils 里确实存在的 my_ellipsoidfit3_dy，
%      接口相同 (lab_group, p_group, mean_cen) -> [par, r, y]；
%   3) 权重 p_group 直接用 labNscore 里已经 CAT 过的评分，不再重复做色适应。
%
% 输出:
%   AnalyseResults_p\efit_p\50\unscaled\{obsNation}\nation1\{scale_type}\{obsType}\{iOr}\{attr}\{0XSTIM}\{k}.mat
%   ellip_pic_p\efit_p\50\{scale_type}\nation1\{obsNation}\{iOr}\{obsType}\{attr}{k}.jpg
% ========================================================================
close all;
clc;
clear;
addpath("utils\")

C = p2_config();

%% ---------- 1. 开关 ----------
iOr        = "r";              % r（14 实景） | i（21 光源）
obsType    = "non_model";
scale_type = "scaled";         % 合并时是否按 LUT 相对亮度缩放
ATTRIBUTE  = 1;                % Preference

if iOr == "i"
    nPara = numel(C.PICNAMES_I);
else
    nPara = numel(C.PICNAMES_R);
end

% 场景簇：r 组把 14 个实景分成 4 簇（同一天气/时段），i 组取 3 个基准色温
if iOr == "r"
    targetIndices = {[1,2,4,5,6], [7,8,9,10], [11,12], [13,14]};
    picnames = C.PICNAMES_R;
else
    targetIndices = {5, 12, 19};       % h6k / m6k / l6k
    picnames = C.PICNAMES_I;
end
nCluster = numel(targetIndices);

%% ---------- 2. 标定 LUT（phase2 数据 => phase2 自己的显示标定） ----------
lut = load(C.LUT_P2_FILE, 'XYZw');
XYZw_LUT = lut.XYZw;
wd65 = C.WD65;

%% ---------- 3. 逐观察者族裔 ----------
for iObsNation = 1:numel(C.OBS_NATIONS)
    obsNation = C.OBS_NATIONS{iObsNation};

    % 3.1 先取平均肤色与白色方块（scaled 要用）
    [lastParts, stimNation, stimIdx] = p2_local_lastparts(C, iOr);
    nSub = numel(lastParts);

    average   = nan(nPara, 3, nSub);
    XYZwWhite = nan(nPara, 3, nSub);
    for iSub = 1:nSub
        lp = lastParts{iSub};
        aveFile = fullfile(C.P2_ROOT, 'aveSkin', lp, 'autoNhand_scaleoverLUT.mat');
        if isfile(aveFile)
            s = load(aveFile, 'average_lab_all');
            average(:, :, iSub) = p2_local_rows(s.average_lab_all(:, 1:3), nPara);
        end
        wFile = fullfile(C.P2_ROOT, 'optimizedD', 'whiteSquare', 'XYZw_white', [lp '.mat']);
        if isfile(wFile)
            s = load(wFile, 'XYZw_white');
            XYZwWhite(:, :, iSub) = p2_local_rows(s.XYZw_white, nPara);
        end
    end

    % 3.2 逐场景簇 × 族裔：合并评分点并拟合
    parNrAll = nan(nCluster, 7);

    for iCluster = 1:nCluster
        hFig = figure(iCluster * 10 + ATTRIBUTE); hold on;
        set(hFig, 'Color', 'white');

        for iNat = 1:numel(C.STIM_NATIONS)
            idxSub = stimIdx{iNat};
            labAll = [];
            pAll   = [];
            nUsed  = 0;

            for iSub = idxSub
                lp = lastParts{iSub};
                for iPara = targetIndices{iCluster}
                    f = fullfile(C.ANALYSE_ROOT, C.Dtype, C.scale_type_origin, obsNation, ...
                        lp, obsType, char(strcat(sprintf('%02d', ATTRIBUTE), ...
                        C.ATTRIBUTE_NAMES(ATTRIBUTE))), 'labNscore', ...
                        strcat('labNscore_group', lp, picnames(iPara), '.mat'));
                    if ~isfile(f), continue; end
                    s = load(f);
                    if ~isfield(s, 'lab_group') || ~isfield(s, 'p_group'), continue; end
                    labCur = s.lab_group;      % 33×3（每个场景 33 个刺激点）
                    pCur   = s.p_group;        % 33×1
                    if size(labCur, 1) ~= size(pCur, 1), continue; end

                    if strcmp(scale_type, 'scaled')
                        wWhite = XYZwWhite(:, :, iSub);
                        for iRow = 1:nPara
                            if any(isnan(labCur(iRow, :))) || any(isnan(wWhite(iRow, :)))
                                continue
                            end
                            xyzFit = lab2xyz2(labCur(iRow, :), 'user', ...
                                wd65 ./ wd65(2) .* XYZw_LUT(2));
                            labCur(iRow, :) = xyz2lab(xyzFit, 'user', ...
                                wd65 ./ wd65(2) .* wWhite(iRow, 2));
                        end
                    end

                    % 评分分布过于偏斜的单元不参与（phase1 的经验阈值）
                    pRatio = nnz(pCur > 0.5) / numel(pCur);
                    if pRatio < 0.1 || pRatio > 0.9
                        continue
                    end
                    labAll = [labAll; labCur];      %#ok<AGROW>
                    pAll   = [pAll;   pCur];        %#ok<AGROW>
                    nUsed  = nUsed + 1;
                end
            end

            if nUsed == 0 || isempty(labAll)
                fprintf('[skip] %s %s 簇%d：无可用 labNscore\n', ...
                    obsNation, C.STIM_NATIONS(iNat), iCluster);
                continue
            end

            % 去掉 NaN 行
            ok = ~any(isnan([labAll, pAll]), 2);
            labAll = labAll(ok, :);
            pAll   = pAll(ok);
            if numel(pAll) < 10, continue; end

            [parMean, ~] = calculate_weighted_or_simple_mean(pAll, labAll);
            meanCen    = [mean(labAll(:,1), 'omitnan'), parMean(1, 4:5)];
            [par, r, y] = my_ellipsoidfit3_dy(labAll, pAll, meanCen); %#ok<ASGLU>

            if numel(par) < 6, continue; end
            parNrAll(iCluster, :) = [par(:)', r];

            % 族裔平均肤色（当前簇）
            aveCur = squeeze(mean(mean(average(targetIndices{iCluster}, :, idxSub), 3, 'omitnan'), 1, 'omitnan'));
            aveCur = reshape(aveCur, 1, 3);

            % 落盘
            stimSerial = strcat(sprintf('%02d', iNat), C.STIM_NATIONS(iNat));
            outDir = fullfile(C.ANALYSE_ROOT, C.Dtype, '50', C.scale_type_origin, ...
                obsNation, 'nation1', char(scale_type), obsType, char(iOr), ...
                char(strcat(sprintf('%02d', ATTRIBUTE), C.ATTRIBUTE_NAMES(ATTRIBUTE))), ...
                char(stimSerial));
            if ~exist(outDir, 'dir'), mkdir(outDir); end
            average_indices_curr = aveCur; %#ok<NASGU>
            save(fullfile(outDir, strcat(num2str(iCluster), '.mat')), ...
                'par', 'r', 'y', 'average_indices_curr');

            % 画 50 椭圆
            try
                hue = linspace(0, 1, numel(C.STIM_NATIONS) + 1);
                hue = hue(1:end-1);
                colors = hsv2rgb([hue', 0.8*ones(numel(C.STIM_NATIONS),1), ...
                                  0.8*ones(numel(C.STIM_NATIONS),1)]);
                Contour50(par, labAll, pAll, 'nation1', aveCur, ...
                    colors(iNat, :), '-', 'o', '');
            catch ME
                warning('Contour50 绘图失败（%s/%s 簇%d）：%s', ...
                    obsNation, C.STIM_NATIONS(iNat), iCluster, ME.message);
            end

            plot(C.LABCH_PMCC(iNat, 2), C.LABCH_PMCC(iNat, 3), 's', 'MarkerSize', 5, ...
                'MarkerFaceColor', 'none', 'MarkerEdgeColor', [0 0 0]);
            fprintf('[50] %s / %-12s 簇%d：合并 %d 个单元，%d 个点\n', ...
                obsNation, C.STIM_NATION_NAMES(iNat), iCluster, nUsed, numel(pAll));
        end

        % ---- 参考线 + 导出 ----
        limMin = -5;
        limMax = 40;
        line([0, 0], [limMin, limMax], 'Color', 'k', 'LineStyle', '--');
        line([limMin, limMax], [0, 0], 'Color', 'k', 'LineStyle', '--');
        href = refline(1, 0);
        set(href, 'Color', 'k', 'LineStyle', '--');
        xlim([limMin, limMax]); ylim([limMin, limMax]);
        axis equal;
        xlabel('\textit{a*}', 'Interpreter', 'latex', 'FontSize', 20);
        ylabel('\textit{b*}', 'Interpreter', 'latex', 'FontSize', 20);
        title(sprintf('%s | obs %s | cluster %d', ...
            char(strcat(sprintf('%02d', ATTRIBUTE), C.ATTRIBUTE_NAMES(ATTRIBUTE))), ...
            obsNation, iCluster), 'FontSize', 16);

        picDir = fullfile(C.PIC_ROOT, C.Dtype, '50', char(scale_type), 'nation1', ...
            obsNation, char(iOr), obsType);
        if ~exist(picDir, 'dir'), mkdir(picDir); end
        exportgraphics(hFig, fullfile(picDir, ...
            strcat(char(strcat(sprintf('%02d', ATTRIBUTE), C.ATTRIBUTE_NAMES(ATTRIBUTE))), ...
            num2str(iCluster), '.jpg')), 'Resolution', 150);
    end

    % ---- 汇总 par ----
    picDir = fullfile(C.PIC_ROOT, C.Dtype, '50', char(scale_type), 'nation1', ...
        obsNation, char(iOr), obsType);
    save(fullfile(picDir, 'fitRes.mat'), 'parNrAll');
    concatenate_images1(picDir, 5);
    close all
end

% ========================================================================
function [lastParts, stimNation, stimIdx] = p2_local_lastparts(C, iOr)
    lastParts  = {};
    stimNation = {};
    stimIdx    = cell(1, numel(C.STIM_NATIONS));
    for iNat = 1:numel(C.STIM_NATIONS)
        stimIdx{iNat} = [];
        for m = C.STIM_MODELS{iNat}
            lastParts{end+1}  = char(m + iOr);              %#ok<AGROW>
            stimNation{end+1} = char(C.STIM_NATIONS(iNat)); %#ok<AGROW>
            stimIdx{iNat}(end+1) = numel(lastParts);        %#ok<AGROW>
        end
    end
end

function X = p2_local_rows(X, n)
    r = size(X, 1);
    if r == n, return; end
    if r > n
        X = X(1:n, :);
    else
        X = [X; nan(n - r, size(X, 2))];
    end
end
