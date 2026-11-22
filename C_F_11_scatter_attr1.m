% ========================================================================
% C_F_11_scatter_attr1.m   （phase2 版）
%
% 对应 phase1: B_data_analysis\analyze\C_F_11_scatter_attr1.m
%
% 作用:
%   把 10 个属性各自的"偏好椭圆中心"画在同一张色度图上，看每个属性的
%   肤色往哪个方向偏。两张图:
%     (1) a*-b* 平面 —— 色相/饱和度位置，属性用编号标注
%     (2) C*-L*  平面 —— 彩度/明度位置
%
% phase2 与 phase1 的结构差异（重要）:
%   phase1 的 nation = 刺激模特族裔，一图一族裔，每族裔 4~6 个刺激；
%   phase2 的族裔挪到了观察者一层 (AnalyseResults_p\...\{AF}\{subject}\...)。
%   所以本脚本用两层维度:
%     obs_nations  —— 观察者族裔（数据路径），目前只有 AF
%     stim_nations —— 刺激模特族裔（图上分面），仍然是 AS/CA/SA/AF 四个
%
% 输出:
%   ellip_pic_p\efit_p\{scale_type}\attr1\{obsNation}\{obsType}\{iOr}\0X{STIM}_scatter_attr.jpg
%   ellip_pic_p\efit_p\{scale_type}\attr1\{obsNation}\{obsType}\{iOr}\C_h\...jpg
%   ellip_pic_p\efit_p\{scale_type}\attr\{obsNation}\data_reshaped_{iOr}.mat （供后续脚本复用）
% ========================================================================
close all;
clc;
clear;
addpath("utils\")

C = p2_config();

%% ---------- 1. 开关 ----------
scale_type = "unscaled";      % unscaled | scaled
iOr        = "i";             % i（21 光源） | r（14 实景）
obsType    = "non_model";     % phase2 只有 non_model

% 有意义的属性槽位（phase2 只拟合了这些；ATTRIBUTES 之外的槽位全 NaN）
ATTRIBUTES = [1, 5, 6, 7, 9, 10];

if iOr == "i"
    indices_target = 5;               % hd65 这一档作为"标准光源"
    nPara = numel(C.PICNAMES_I);
else
    indices_target = 5;               % rs05
    nPara = numel(C.PICNAMES_R);
end

if scale_type == "scaled"
    lightness = 'scale';              % LUT 相对亮度缩放
else
    lightness = 'raw';
end

%% ---------- 2. 逐观察者族裔加载 ----------
for iObsNation = 1:numel(C.OBS_NATIONS)
    obsNation = C.OBS_NATIONS{iObsNation};

    D = p2_load_labfit(obsNation, iOr, struct('lightness', lightness, ...
        'obsType', obsType, 'verbose', true));

    % 属性平均点: nSub × 3（对受试者、对场景求平均）
    attri_lab   = nan(numel(C.STIM_NATIONS), C.nAttr, 3);   % [stimNation, attr, Lab]
    attri_count = zeros(numel(C.STIM_NATIONS), C.nAttr);    % 该属性有多少个受试者

    for iNat = 1:numel(C.STIM_NATIONS)
        idxSub = D.stimIdx{iNat};
        for a = ATTRIBUTES
            if ~any(D.hasAttr(idxSub, a)), continue; end
            labData = D.lab_fit(indices_target, :, idxSub, a);   % nT × 3 × nSub
            labMean = mean(labData, 3, 'omitnan');               % nT × 3
            if all(isnan(labMean(:))), continue; end
            attri_lab(iNat, a, :)   = mean(labMean, 1, 'omitnan');
            attri_count(iNat, a)    = nnz(D.hasAttr(idxSub, a));
        end
    end

    % 保存中间数据（与 phase1 同名，方便逐脚本接力调试）
    saveFolder = fullfile(C.PIC_ROOT, C.Dtype, char(scale_type), 'attr', obsNation);
    if ~exist(saveFolder, 'dir'), mkdir(saveFolder); end
    par_mean       = D.par;
    average_mean   = D.average_mean;
    lab_fit_reshaped = D.lab_fit;
    par_reshaped   = D.par;
    average_reshaped = D.average;
    file_missing   = D.missing;
    hasAttr        = D.hasAttr;
    stimNation     = D.stimNation;
    stimIdx        = D.stimIdx;
    lastParts      = D.lastParts;
    save(fullfile(saveFolder, strcat("data_reshaped_", iOr, ".mat")), ...
        "par_mean", "average_mean", "lab_fit_reshaped", "file_missing", ...
        "par_reshaped", "average_reshaped", "hasAttr", "stimNation", "stimIdx", "lastParts");

    %% ---------- 3. 统一坐标轴范围（4 个族裔共用，便于横向比较） ----------
    abAll = [];
    for iNat = 1:numel(C.STIM_NATIONS)
        for a = ATTRIBUTES
            v = squeeze(attri_lab(iNat, a, :))';
            if all(isnan(v)), continue; end
            abAll = [abAll; v(2), v(3)]; %#ok<AGROW>
        end
    end
    if isempty(abAll)
        warning('C_F_11: %s/%s 没有可画的数据，跳过', obsNation, iOr);
        continue
    end
    abPad  = 1.5;
    xLimAb = [floor(min(abAll(:,1))) - abPad, ceil(max(abAll(:,1))) + abPad];
    yLimAb = [floor(min(abAll(:,2))) - abPad, ceil(max(abAll(:,2))) + abPad];
    spanAb = max(xLimAb(2)-xLimAb(1), yLimAb(2)-yLimAb(1));
    xLimAb = mean(xLimAb) + [-spanAb, spanAb]/2;
    yLimAb = mean(yLimAb) + [-spanAb, spanAb]/2;

    % C*-L* 平面的范围
    Lall = [];
    for iNat = 1:numel(C.STIM_NATIONS)
        for a = ATTRIBUTES
            v = squeeze(attri_lab(iNat, a, :))';
            if all(isnan(v)), continue; end
            Lall = [Lall; sqrt(v(2)^2+v(3)^2), v(1)]; %#ok<AGROW>
        end
    end
    xLimC = [floor(min(Lall(:,1)))-2, ceil(max(Lall(:,1)))+2];
    yLimL = [floor(min(Lall(:,2)))-3, ceil(max(Lall(:,2)))+3];

    %% ---------- 4. 绘图 ----------
    nColor = numel(ATTRIBUTES);
    hues   = linspace(0, 1, nColor + 1); hues = hues(1:end-1);
    colors = hsv2rgb([hues', 0.8*ones(nColor,1), 0.8*ones(nColor,1)]);

    for iNat = 1:numel(C.STIM_NATIONS)
        stimName   = C.STIM_NATIONS(iNat);
        stimSerial = strcat(sprintf('%02d', iNat), stimName);

        % ---- 4.1 a*-b* 平面 ----
        h1 = figure(1); hold on; set(gcf, 'Color', 'white');
        for k = 1:nColor
            a = ATTRIBUTES(k);
            v = squeeze(attri_lab(iNat, a, :))';
            if all(isnan(v)), continue; end
            text(v(2), v(3), num2str(a), 'FontSize', 15, ...
                'VerticalAlignment', 'middle', 'Color', colors(k,:), ...
                'FontWeight', 'bold');
        end
        % PMCC 参考点（phase1 备查，默认不画）
        % plot(C.LABCH_PMCC(iNat,2), C.LABCH_PMCC(iNat,3), 's', 'MarkerSize', 8, ...
        %     'MarkerFaceColor', 'm', 'MarkerEdgeColor', 'm');

        xlabel('\textit{a}^{*}', 'Interpreter', 'latex', 'FontSize', 24);
        ylabel('\textit{b}^{*}', 'Interpreter', 'latex', 'FontSize', 24);
        title(sprintf('%s (observer %s)', C.STIM_NATION_NAMES(iNat), obsNation), ...
            'FontSize', 20);
        axis equal;
        xlim(xLimAb); ylim(yLimAb);
        set(gca, 'XTick', ceil(xLimAb(1)):3:floor(xLimAb(2)));
        set(gca, 'YTick', ceil(yLimAb(1)):3:floor(yLimAb(2)));
        xRef = linspace(xLimAb(1), xLimAb(2), 100);
        plot(xRef, xRef, 'Color', 'k', 'LineStyle', '--');

        saveFolderAb = fullfile(C.PIC_ROOT, C.Dtype, char(scale_type), 'attr1', ...
            obsNation, char(obsType), char(iOr));
        if ~exist(saveFolderAb, 'dir'), mkdir(saveFolderAb); end
        exportgraphics(h1, fullfile(saveFolderAb, ...
            strcat(char(stimSerial), '_scatter_attr.jpg')), 'Resolution', 300);
        close(h1);

        % ---- 4.2 C*-L* 平面 ----
        h2 = figure(2); hold on; set(gcf, 'Color', 'white');
        for k = 1:nColor
            a = ATTRIBUTES(k);
            v = squeeze(attri_lab(iNat, a, :))';
            if all(isnan(v)), continue; end
            Cstar = sqrt(v(2)^2 + v(3)^2);
            text(Cstar, v(1), num2str(a), 'FontSize', 15, ...
                'VerticalAlignment', 'middle', 'Color', colors(k,:), ...
                'FontWeight', 'bold');
        end
        % PMCC 点：先按亮度对齐再回到 Lab
        labPre = mean(squeeze(attri_lab(iNat, 1, :))', 1, 'omitnan');
        if ~any(isnan(labPre))
            xyzMean = lab2xyz2(labPre, 'd65_64');
            xyzPMCC = lab2xyz2(C.LABCH_PMCC(iNat, 1:3), 'd65_64');
            xyzPMCC = xyzPMCC ./ xyzPMCC(2) .* xyzMean(2);
            labPMCC = xyz2lab(xyzPMCC, 'd65_64');
            Cpmcc   = sqrt(labPMCC(2)^2 + labPMCC(3)^2);
            plot(Cpmcc, labPMCC(1), 's', 'MarkerSize', 8, ...
                'MarkerFaceColor', 'none', 'MarkerEdgeColor', 'm');
        end

        xlabel('\textit{C}^{*}_{ab}', 'Interpreter', 'latex', 'FontSize', 24);
        ylabel('\textit{L*}', 'Interpreter', 'latex', 'FontSize', 24);
        title(sprintf('%s (observer %s)', C.STIM_NATION_NAMES(iNat), obsNation), ...
            'FontSize', 20);
        axis equal;
        xlim(xLimC); ylim(yLimL);

        saveFolderCL = fullfile(saveFolderAb, 'C_h');
        if ~exist(saveFolderCL, 'dir'), mkdir(saveFolderCL); end
        exportgraphics(h2, fullfile(saveFolderCL, ...
            strcat(char(stimSerial), '_scatter_attr.jpg')), 'Resolution', 300);
        close(h2);
    end

    % ---- 4.3 拼接 ----
    concatenate_images1(saveFolderAb, 4);

    % ---- 4.4 控制台核对表 ----
    fprintf('\n=== %s / %s：每族裔每属性的有效受试者数 ===\n', obsNation, iOr);
    fprintf('%8s', 'attr');
    for iNat = 1:numel(C.STIM_NATIONS)
        fprintf('%8s', C.STIM_NATIONS(iNat));
    end
    fprintf('\n');
    for a = ATTRIBUTES
        fprintf('%8s', char(D.attrSerial(a)));
        for iNat = 1:numel(C.STIM_NATIONS)
            fprintf('%8d', attri_count(iNat, a));
        end
        fprintf('\n');
    end
end
