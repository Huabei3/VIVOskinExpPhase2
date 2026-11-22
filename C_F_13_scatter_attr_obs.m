% ========================================================================
% C_F_13_scatter_attr_obs.m   （phase2 版）
%
% 对应 phase1: B_data_analysis\analyze\C_F_13_scatter_attr_obs.m
%
% 作用:
%   (1) 把同一刺激族裔下所有属性的椭圆中心画在一张 a*-b* 图上（属性编号标注），
%       再画一张 C*-h 图，看属性之间在色空间里怎么分开；
%   (2) 计算属性两两之间的 CIEDE2000 距离矩阵，以及"属性中心 vs 平均肤色"
%       的 ΔE，导出 xlsx 供后续统计。
%
% 明度处理:
%   与 phase1 一致，先做 late CAT16（把平均肤色从场景光源迁到 D65），再取
%   椭圆的 a*b*，不做 LUT 缩放。
%
% 输出:
%   ellip_pic_p\efit_p\attr\comparison\{obsNation}\{obsType}\{iOr}\0X{STIM}_scatter_attr_comp_noarrow.jpg
%   ellip_pic_p\efit_p\attr\comparison\{obsNation}\{obsType}\{iOr}\C_h\...jpg
%   ellip_pic_p\efit_p\attr\deltaE2000\{obsNation}\deltaE2000_{iOr}.xlsx
% ========================================================================
close all;
clc;
clear;
addpath("utils\")

C = p2_config();

%% ---------- 1. 开关 ----------
iOr     = "i";              % i（21 光源） | r（14 实景）
obsType = "non_model";      % phase2 只有 non_model
ATTRIBUTES = [1, 5, 6, 7, 9, 10];

% 取"基准场景"：i 组的 hd65（第 5 个）/ r 组的 rs05（第 5 个实景）
indices_target = 5;

%% ---------- 2. 逐观察者族裔 ----------
for iObsNation = 1:numel(C.OBS_NATIONS)
    obsNation = C.OBS_NATIONS{iObsNation};

    D = p2_load_labfit(obsNation, iOr, struct('lightness', 'cat', ...
        'obsType', obsType, 'verbose', true));

    nColor = numel(ATTRIBUTES);
    hues   = linspace(0, 1, nColor + 1); hues = hues(1:end-1);
    colors = hsv2rgb([hues', 0.8*ones(nColor,1), 0.8*ones(nColor,1)]);

    %% ---------- 3. 属性平均 Lab ----------
    attrLab = nan(numel(C.STIM_NATIONS), C.nAttr, 3);   % [stimNation, attr, Lab]
    for iNat = 1:numel(C.STIM_NATIONS)
        idxSub = D.stimIdx{iNat};
        for a = ATTRIBUTES
            if ~any(D.hasAttr(idxSub, a)), continue; end
            labData = D.lab_fit(indices_target, :, idxSub, a);
            labMean = mean(labData, 3, 'omitnan');
            if all(isnan(labMean(:))), continue; end
            attrLab(iNat, a, :) = mean(labMean, 1, 'omitnan');
        end
    end

    %% ---------- 4. 绘图 ----------
    saveFolder = fullfile(C.PIC_ROOT, C.Dtype, 'attr', 'comparison', ...
        obsNation, char(obsType), char(iOr));

    for iNat = 1:numel(C.STIM_NATIONS)
        stimName    = C.STIM_NATIONS(iNat);
        stimSerial  = strcat(sprintf('%02d', iNat), stimName);
        nSubjects   = numel(D.stimIdx{iNat});

        % ---- 4.1 a*-b* ----
        h1 = figure('Color', 'white'); hold on;
        abPts = [];
        for k = 1:nColor
            a = ATTRIBUTES(k);
            v = squeeze(attrLab(iNat, a, :))';
            if all(isnan(v)), continue; end
            abPts = [abPts; v(2), v(3)]; %#ok<AGROW>
            text(v(2), v(3), num2str(a), 'FontSize', 15, ...
                'VerticalAlignment', 'middle', 'Color', colors(k,:), ...
                'FontWeight', 'bold');
        end
        % 平均肤色（全部受试者、全部目标场景的平均）
        aveLab = squeeze(mean(mean(D.average_used(indices_target, :, D.stimIdx{iNat}), 3, 'omitnan'), 1, 'omitnan'));
        if ~any(isnan(aveLab))
            plot(aveLab(2), aveLab(3), 'o', 'MarkerSize', 8, ...
                'MarkerFaceColor', [0.4 0.4 0.4], 'MarkerEdgeColor', 'k');
        end

        xlabel('\textit{a}^{*}', 'Interpreter', 'latex', 'FontSize', 24);
        ylabel('\textit{b}^{*}', 'Interpreter', 'latex', 'FontSize', 24);
        title(sprintf('%s | obs %s | n=%d', C.STIM_NATION_NAMES(iNat), obsNation, nSubjects), ...
            'FontSize', 18);
        axis equal;
        if ~isempty(abPts)
            lo = floor(min(abPts(:))) - 2;
            hi = ceil(max(abPts(:))) + 2;
            xlim([lo, hi]); ylim([lo, hi]);
            xRef = linspace(lo, hi, 100);
            plot(xRef, xRef, 'k--');
        end
        if ~exist(saveFolder, 'dir'), mkdir(saveFolder); end
        exportgraphics(h1, fullfile(saveFolder, ...
            strcat(char(stimSerial), '_scatter_attr_comp_noarrow.jpg')), 'Resolution', 300);
        close(h1);

        % ---- 4.2 C*-h ----
        h2 = figure('Color', 'white'); hold on;
        for k = 1:nColor
            a = ATTRIBUTES(k);
            v = squeeze(attrLab(iNat, a, :))';
            if all(isnan(v)), continue; end
            Cstar = sqrt(v(2)^2 + v(3)^2);
            hAng  = atan2d(v(3), v(2));
            scatter(hAng, Cstar, 36, 'o', 'filled', ...
                'MarkerFaceColor', colors(k,:), 'MarkerEdgeColor', colors(k,:));
            text(hAng, Cstar, num2str(a), 'FontSize', 8, ...
                'VerticalAlignment', 'middle', 'Color', 'k');
        end
        xlabel('{\ith} (deg)');
        ylabel('{\itC*}');
        title(sprintf('%s C-h | obs %s', C.STIM_NATION_NAMES(iNat), obsNation), ...
            'FontSize', 18);
        grid on; box on;

        saveFolderCH = fullfile(saveFolder, 'C_h');
        if ~exist(saveFolderCH, 'dir'), mkdir(saveFolderCH); end
        exportgraphics(h2, fullfile(saveFolderCH, ...
            strcat(char(stimSerial), '_scatter_attr_comp_noarrow.jpg')), 'Resolution', 300);
        close(h2);
    end

    %% ---------- 5. 拼接 ----------
    concatenate_images1(saveFolder, 4);
    concatenate_images1(fullfile(saveFolder, 'C_h'), 4);

    %% ---------- 6. ΔE2000 矩阵 ----------
    deFolder = fullfile(C.PIC_ROOT, C.Dtype, 'attr', 'deltaE2000', obsNation);
    if ~exist(deFolder, 'dir'), mkdir(deFolder); end

    attrLabels = strings(1, numel(ATTRIBUTES));
    for k = 1:numel(ATTRIBUTES)
        attrLabels(k) = D.attrSerial(ATTRIBUTES(k));
    end

    % 6.1 属性两两 ΔE（族裔 × 属性组合，全部写进一个 xlsx 的多个 sheet）
    xlsxFile = fullfile(deFolder, strcat('deltaE2000_', char(iOr), '.xlsx'));
    if isfile(xlsxFile), delete(xlsxFile); end

    for iNat = 1:numel(C.STIM_NATIONS)
        nA = numel(ATTRIBUTES);
        dEMat = nan(nA, nA);
        for i = 1:nA
            for j = i:nA
                if i == j, continue; end
                lab1 = squeeze(attrLab(iNat, ATTRIBUTES(i), :))';
                lab2 = squeeze(attrLab(iNat, ATTRIBUTES(j), :))';
                if any(isnan(lab1)) || any(isnan(lab2)), continue; end
                dE = deltaE2000(lab1, lab2);
                dEMat(i, j) = dE;
                dEMat(j, i) = dE;
            end
        end
        T = array2table(dEMat, 'VariableNames', cellstr(attrLabels), ...
            'RowNames', cellstr(attrLabels));
        writetable(T, xlsxFile, 'Sheet', char(C.STIM_NATIONS(iNat)), 'WriteRowNames', true);

        % 6.2 各属性中心 vs 平均肤色
        aveLab = squeeze(mean(mean(D.average_used(indices_target, :, D.stimIdx{iNat}), 3, 'omitnan'), 1, 'omitnan'));
        dEAve = nan(nA, 1);
        for k = 1:nA
            v = squeeze(attrLab(iNat, ATTRIBUTES(k), :))';
            if any(isnan(v)) || any(isnan(aveLab)), continue; end
            dEAve(k) = deltaE2000(v, aveLab);
        end
        Tave = table(attrLabels(:), dEAve, 'VariableNames', {'Attribute', 'deltaE_to_aveSkin'});
        writetable(Tave, xlsxFile, 'Sheet', char(strcat(C.STIM_NATIONS(iNat), '_vsAve')));

        fprintf('[ΔE] %s / %s : 属性间平均ΔE = %.2f，属性到平均肤色平均ΔE = %.2f\n', ...
            obsNation, C.STIM_NATIONS(iNat), mean(dEMat(~isnan(dEMat))), mean(dEAve, 'omitnan'));
    end
    fprintf('[ΔE] 已写出 %s\n', xlsxFile);
end
