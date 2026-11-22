% ========================================================================
% C_F_20_scatter_CT.m   （phase2 版）
%
% 对应 phase1: B_data_analysis\analyze\C_F_20_scatter_CT.m
%
% 作用:
%   固定 Preference，把每个场景拟合出的偏好中心画在 a*-b* 平面，点的颜色按
%   该场景的色温（CCT）映射，用来回答"光源越冷，偏好往哪偏"。
%
% phase2 差异（重要）:
%   phase1 这张图会同时载入 noCAT 结果做"色适应前后"对照；
%   phase2 的 AnalyseResults_p 下只有 efit_p（没有 noCAT 分支），所以本版
%   只画 efit_p / unscaled 的结果，色适应对照部分整段去掉。
%
% 输出:
%   ellip_pic_p\efit_p\CT\{scale_type}\{obsNation}\{obsType}\{iOr}\{iOr}{obsType}{serial}_CT.jpg
% ========================================================================
close all;
clc;
clear;
addpath("utils\")

C = p2_config();

%% ---------- 1. 开关 ----------
iOr     = "i";                % i（21 光源） | r（14 实景）
obsType = "non_model";
ATTRIBUTE = 1;                % Preference
scale_type = "scaled";        % scaled | unscaled（是否按 LUT 相对亮度缩放）

if iOr == "i"
    indices_target = 1:numel(C.PICNAMES_I);
else
    indices_target = 1:numel(C.PICNAMES_R);
end

if scale_type == "scaled"
    lightness = 'scale';
else
    lightness = 'raw';
end

%% ---------- 2. 逐观察者族裔 ----------
for iObsNation = 1:numel(C.OBS_NATIONS)
    obsNation = C.OBS_NATIONS{iObsNation};

    D = p2_load_labfit(obsNation, iOr, struct('lightness', lightness, ...
        'obsType', obsType, 'verbose', true));

    % 色温色标：jet 翻转，暖色(低 CCT) -> 冷色(高 CCT)
    cmap = flipud(colormap('jet'));

    %% ---------- 3. 统一轴范围 ----------
    pts = [];
    for iNat = 1:numel(C.STIM_NATIONS)
        idxSub  = D.stimIdx{iNat};
        labData = D.lab_fit(indices_target, :, idxSub, ATTRIBUTE);
        lab     = mean(labData, 3, 'omitnan');
        ok      = ~all(isnan(lab), 2);
        pts     = [pts; lab(ok, 2), lab(ok, 3)]; %#ok<AGROW>
    end
    if isempty(pts)
        warning('C_F_20: %s/%s 无 Preference 数据，跳过', obsNation, iOr);
        continue
    end
    lo = max(0, floor(min(pts(:))) - 2);
    hi = ceil(max(pts(:))) + 2;

    %% ---------- 4. 绘图 ----------
    for iNat = 1:numel(C.STIM_NATIONS)
        stimName   = C.STIM_NATIONS(iNat);
        stimSerial = strcat(sprintf('%02d', iNat), stimName);
        idxSub     = D.stimIdx{iNat};

        labData = D.lab_fit(indices_target, :, idxSub, ATTRIBUTE);
        lab     = mean(labData, 3, 'omitnan');        % nT × 3
        validIdx = find(~all(isnan(lab), 2));
        if isempty(validIdx), continue; end
        labValid = lab(validIdx, :);

        if strcmp(iOr, 'i')
            ctAll = D.CT;
        else
            ctAll = D.CT_stim{iNat};
        end
        ctValid = ctAll(validIdx);

        h = figure('Color', 'white'); hold on;
        ctMin = min(ctValid); ctMax = max(ctValid);
        for k = 1:size(labValid, 1)
            cNorm = (ctValid(k) - ctMin) ./ max(ctMax - ctMin, eps);
            cIdx  = round(cNorm * (size(cmap,1) - 1)) + 1;
            cIdx  = max(min(cIdx, size(cmap,1)), 1);
            pointColor = cmap(cIdx, :);
            scatter(labValid(k,2), labValid(k,3), 36, 'o', 'filled', ...
                'MarkerFaceColor', pointColor, 'MarkerEdgeColor', pointColor, ...
                'LineWidth', 0.5);
        end

        % PMCC 参考点
        plot(C.LABCH_PMCC(iNat, 2), C.LABCH_PMCC(iNat, 3), 's', 'MarkerSize', 8, ...
            'MarkerFaceColor', 'm', 'MarkerEdgeColor', 'm');

        xlabel('\textit{a}^{*}', 'Interpreter', 'latex', 'FontSize', 24);
        ylabel('\textit{b}^{*}', 'Interpreter', 'latex', 'FontSize', 24);
        title(sprintf('%s | obs %s | %s', C.STIM_NATION_NAMES(iNat), obsNation, char(iOr)), ...
            'FontSize', 20);

        if iNat == numel(C.STIM_NATIONS)
            cb = colorbar;
            cb.Label.String      = 'CCT (K)';
            cb.Label.Interpreter = 'latex';
            cb.Label.FontSize    = 12;
            caxis([ctMin, ctMax]);
            colormap(cmap);
        end

        axis equal;
        xlim([lo, hi]); ylim([lo, hi]);
        xRef = linspace(lo, hi, 100);
        plot(xRef, xRef, 'k--', 'LineWidth', 0.8);

        saveFolder = fullfile(C.PIC_ROOT, C.Dtype, 'CT', char(scale_type), ...
            obsNation, char(obsType), char(iOr));
        if ~exist(saveFolder, 'dir'), mkdir(saveFolder); end
        exportgraphics(h, fullfile(saveFolder, ...
            strcat(char(iOr), char(obsType), char(stimSerial), '_CT.jpg')), ...
            'Resolution', 300);
        close(h);

        % 色相统计（供论文引用）
        hAng = atan2d(labValid(:,3), labValid(:,2));
        fprintf('[CT] %s / %-12s 色相 h* = %.1f° (min %.1f, max %.1f)\n', ...
            obsNation, C.STIM_NATION_NAMES(iNat), mean(hAng, 'omitnan'), ...
            min(hAng), max(hAng));
    end

    %% ---------- 5. 拼接 ----------
    saveFolder = fullfile(C.PIC_ROOT, C.Dtype, 'CT', char(scale_type), ...
        obsNation, char(obsType), char(iOr));
    concatenate_images1(saveFolder, 4);
    close all
end
