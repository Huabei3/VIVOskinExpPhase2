% ========================================================================
% C_F_14_scatter_hml.m   （phase2 版）
%
% 对应 phase1: B_data_analysis\analyze\C_F_14_scatter_hml.m
%
% 作用:
%   固定 Preference，把 21 个光源 / 14 个实景下拟合出的偏好中心画在 a*-b*
%   平面，点的颜色按该场景的 L*（或背景灰卡亮度）映射，用来观察"亮度 → 偏好
%   色坐标"的走向。i 组用圆点，r 组用文字编号，颜色统一由色条表示。
%
% phase2 差异:
%   nation 变成观察者族裔（数据路径），图按刺激族裔分面；
%   颜色标尺在四个族裔间统一（跨图可比）。
%
% 输出:
%   ellip_pic_p\efit_p\hml\abs\{obsNation}\{obsType}\{iOr}\0X{STIM}_L.jpg
%   documents\{iOr}\XYZw_gray_nations.mat（背景灰卡亮度，附 obsNation 后缀）
% ========================================================================
close all;
clc;
clear;
addpath("utils\")

C = p2_config();

%% ---------- 1. 开关 ----------
iOr     = "i";              % i（21 光源） | r（14 实景）
obsType = "non_model";
ATTRIBUTE = 1;              % Preference
lightness_type = "abs";     % abs（不缩放） | rela（LUT 相对亮度）
color_type     = "lightness"; % lightness（按 L* 上色） | luminance（按背景灰卡亮度）

if iOr == "i"
    indices_target = 1:numel(C.PICNAMES_I);
else
    indices_target = 1:numel(C.PICNAMES_R);
end

if lightness_type == "rela"
    lightness = 'scale';
else
    lightness = 'raw';
end

%% ---------- 2. 逐观察者族裔 ----------
for iObsNation = 1:numel(C.OBS_NATIONS)
    obsNation = C.OBS_NATIONS{iObsNation};

    D = p2_load_labfit(obsNation, iOr, struct('lightness', lightness, ...
        'obsType', obsType, 'verbose', true));

    %% ---------- 3. 颜色标尺范围（四族裔共用） ----------
    colorVals = [];
    for iNat = 1:numel(C.STIM_NATIONS)
        idxSub  = D.stimIdx{iNat};
        labData = D.lab_fit(indices_target, :, idxSub, ATTRIBUTE);
        lab     = mean(labData, 3, 'omitnan');
        if strcmp(color_type, 'lightness')
            v = lab(:, 1);
        else
            v = squeeze(mean(D.XYZw_gray(indices_target, 2, idxSub), 3, 'omitnan'));
        end
        colorVals = [colorVals; v(~isnan(v))]; %#ok<AGROW>
    end
    if isempty(colorVals)
        warning('C_F_14: %s/%s 无数据，跳过', obsNation, iOr);
        continue
    end
    dataMin = min(colorVals);
    dataMax = max(colorVals);
    cmap    = colormap('copper');

    %% ---------- 4. 绘图 ----------
    for iNat = 1:numel(C.STIM_NATIONS)
        stimName   = C.STIM_NATIONS(iNat);
        stimSerial = strcat(sprintf('%02d', iNat), stimName);
        idxSub     = D.stimIdx{iNat};

        labData = D.lab_fit(indices_target, :, idxSub, ATTRIBUTE);
        lab     = mean(labData, 3, 'omitnan');           % nT × 3
        if strcmp(color_type, 'lightness')
            colorData = lab(:, 1);
        else
            colorData = squeeze(mean(D.XYZw_gray(indices_target, 2, idxSub), 3, 'omitnan'));
        end
        validIdx = find(~any(isnan(lab), 2));
        if isempty(validIdx), continue; end
        labValid   = lab(validIdx, :);
        colorValid = colorData(validIdx);

        h = figure('Color', 'white'); hold on;
        colorNorm = (colorValid - dataMin) ./ max(dataMax - dataMin, eps);
        for k = 1:size(labValid, 1)
            cIdx  = round(colorNorm(k) * (size(cmap,1) - 1)) + 1;
            cIdx  = max(min(cIdx, size(cmap,1)), 1);
            pointColor = cmap(cIdx, :);
            if iOr == "i"
                scatter(labValid(k,2), labValid(k,3), 20, 'o', 'filled', ...
                    'MarkerFaceColor', pointColor, 'MarkerEdgeColor', pointColor, ...
                    'LineWidth', 0.5);
            else
                text(labValid(k,2), labValid(k,3), num2str(validIdx(k)), ...
                    'FontSize', 15, 'VerticalAlignment', 'top', ...
                    'Color', pointColor, 'FontWeight', 'bold');
            end
        end

        xlabel('\textit{a}^{*}', 'Interpreter', 'latex', 'FontSize', 24);
        ylabel('\textit{b}^{*}', 'Interpreter', 'latex', 'FontSize', 24);
        title(sprintf('%s | obs %s', C.STIM_NATION_NAMES(iNat), obsNation), 'FontSize', 20);

        % 只在最后一个族裔图上挂色条，其余图共用同一标尺
        if iNat == numel(C.STIM_NATIONS)
            cb = colorbar;
            if strcmp(color_type, 'lightness')
                cb.Label.String = '$L^*$';
            else
                cb.Label.String = 'luminance (cd/m$^2$)';
            end
            cb.Label.Interpreter = 'latex';
            cb.Label.FontSize    = 12;
            caxis([dataMin, dataMax]);
            colormap(cmap);
        end

        axis equal;
        lo = floor(min(min(labValid(:,2)), min(labValid(:,3)))) - 2;
        hi = ceil(max(max(labValid(:,2)), max(labValid(:,3)))) + 2;
        xlim([lo, hi]); ylim([lo, hi]);
        xRef = linspace(lo, hi, 100);
        plot(xRef, xRef, 'k--', 'LineWidth', 0.8);

        saveFolder = fullfile(C.PIC_ROOT, C.Dtype, 'hml', char(lightness_type), ...
            obsNation, char(obsType), char(iOr));
        if ~exist(saveFolder, 'dir'), mkdir(saveFolder); end
        exportgraphics(h, fullfile(saveFolder, ...
            strcat(char(stimSerial), '_L.jpg')), 'Resolution', 300);
        close(h);
    end

    %% ---------- 5. 拼接 + 背景灰卡亮度留存 ----------
    saveFolder = fullfile(C.PIC_ROOT, C.Dtype, 'hml', char(lightness_type), ...
        obsNation, char(obsType), char(iOr));
    concatenate_images1noSerial(saveFolder, 4);

    XYZw_gray_mean      = D.XYZw_gray;                    % nPara × 3 × nSub
    XYZw_gray_all_nations = struct('stimNation', {D.stimNation}, ...
                                   'stimIdx', {D.stimIdx}, ...
                                   'lastParts', {D.lastParts});
    grayFolder = fullfile(C.P2_ROOT, 'documents', char(iOr));
    if ~exist(grayFolder, 'dir'), mkdir(grayFolder); end
    save(fullfile(grayFolder, strcat('XYZw_gray_nations_', obsNation, '.mat')), ...
        'XYZw_gray_mean', 'XYZw_gray_all_nations');
end
