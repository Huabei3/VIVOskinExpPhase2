% ========================================================================
% C_F_12_scatter_scene2.m   （phase2 版）
%
% 对应 phase1: B_data_analysis\analyze\C_F_12_scatter_scene2.m
%
% 作用:
%   固定 Preference 属性，把同一族裔刺激在不同场景（r 组 14 个实景 /
%   i 组 21 个光源）下拟合出的椭圆中心画在 a*-b* 平面上，看"场景"把
%   同一张脸的偏好色坐标推到哪里。场景按类型着色（室内/草地/夜景）。
%
% phase2 差异:
%   nation 变成观察者族裔（数据路径），图仍按刺激族裔分面；
%   明度处理沿用 phase1 的 rela（按 LUT 相对亮度缩放）。
%
% 输出:
%   ellip_pic_p\efit_p\scene2\rela\{obsNation}\{obsType}\{iOr}\0X{STIM}_L.jpg
% ========================================================================
close all;
clc;
clear;
addpath("utils\")

C = p2_config();

%% ---------- 1. 开关 ----------
iOr     = "r";              % r（14 实景，默认） | i（21 光源）
obsType = "non_model";
ATTRIBUTE = 1;              % Preference
lightness_type = "rela";    % rela（LUT 相对亮度缩放）

if iOr == "i"
    indices_target = 1:numel(C.PICNAMES_I);
else
    indices_target = 1:numel(C.PICNAMES_R);
end

%% ---------- 2. 逐观察者族裔 ----------
for iObsNation = 1:numel(C.OBS_NATIONS)
    obsNation = C.OBS_NATIONS{iObsNation};

    D = p2_load_labfit(obsNation, iOr, struct('lightness', 'scale', ...
        'obsType', obsType, 'verbose', true));

    % 场景分色：室内(1-6) / 草地(7-12) / 夜景(13-14)；i 组按 h/m/l 三档
    nColor = 3;
    hues   = linspace(0, 1, nColor + 1); hues = hues(1:end-1);
    colors = hsv2rgb([hues', 0.8*ones(nColor,1), 0.8*ones(nColor,1)]);

    %% ---------- 3. 统一轴范围 ----------
    pts = [];
    for iNat = 1:numel(C.STIM_NATIONS)
        idxSub  = D.stimIdx{iNat};
        labData = D.lab_fit(indices_target, :, idxSub, ATTRIBUTE);
        lab     = mean(labData, 3, 'omitnan');        % nT × 3
        ok      = ~all(isnan(lab), 2);
        pts     = [pts; lab(ok, 2), lab(ok, 3)];      %#ok<AGROW>
    end
    if isempty(pts)
        warning('C_F_12: %s/%s 无 Preference 数据，跳过', obsNation, iOr);
        continue
    end
    limMax = max(ceil(max(pts(:)) + 2), 10);
    limMin = max(0, floor(min(pts(:)) - 2));

    %% ---------- 4. 绘图 ----------
    for iNat = 1:numel(C.STIM_NATIONS)
        stimName   = C.STIM_NATIONS(iNat);
        stimSerial = strcat(sprintf('%02d', iNat), stimName);
        idxSub     = D.stimIdx{iNat};

        labData = D.lab_fit(indices_target, :, idxSub, ATTRIBUTE);
        lab     = mean(labData, 3, 'omitnan');        % 受试者平均，nT × 3
        if all(isnan(lab(:))), continue; end
        % 保留原场景编号，避免有效点被压缩后编号错位
        validIdx  = find(~all(isnan(lab), 2));
        labValid  = lab(validIdx, :);

        h = figure('Color', 'white'); hold on;
        for k = 1:size(labValid, 1)
            iPoint = validIdx(k);                     % 真实场景编号
            if iOr == "r"
                if ismember(iPoint, 1:6)
                    pointColor = colors(1, :);
                elseif ismember(iPoint, 7:12)
                    pointColor = colors(2, :);
                else
                    pointColor = colors(3, :);
                end
            else
                if iPoint <= 7
                    pointColor = colors(1, :);        % 高亮度 h*
                elseif iPoint <= 14
                    pointColor = colors(2, :);        % 中亮度 m*
                else
                    pointColor = colors(3, :);        % 低亮度 l*
                end
            end
            text(labValid(k, 2), labValid(k, 3), num2str(iPoint), ...
                'FontSize', 15, 'VerticalAlignment', 'middle', ...
                'Color', pointColor, 'FontWeight', 'bold');
        end

        % 注: MATLAB 的 latex 解释器不支持 \textit{}，也不接受 a^{*} 这种写法，
        %     会整串按字面输出（图上就出现 "\textit{a}^{*}"）。改用 tex 解释器,
        %     {\ita}^{*} = 斜体 a + 上标星号。
        xlabel('{\ita}^{*}', 'Interpreter', 'tex', 'FontSize', 24);
        ylabel('{\itb}^{*}', 'Interpreter', 'tex', 'FontSize', 24);
        title(sprintf('%s (observer %s)', C.STIM_NATION_NAMES(iNat), obsNation), ...
            'FontSize', 20);
        axis equal;
        xlim([limMin, limMax]);
        ylim([limMin, limMax]);

        % 45° 等色相参考线
        xLine = linspace(0, limMax, 100);
        plot(xLine, xLine, 'Color', 'k', 'LineStyle', '--');
        text(limMax, limMax * 0.98, '45°', 'VerticalAlignment', 'top', ...
            'HorizontalAlignment', 'right', 'FontSize', 10, 'Color', 'k');

        saveFolder = fullfile(C.PIC_ROOT, C.Dtype, 'scene2', char(lightness_type), ...
            obsNation, char(obsType), char(iOr));
        if ~exist(saveFolder, 'dir'), mkdir(saveFolder); end
        exportgraphics(h, fullfile(saveFolder, ...
            strcat(char(stimSerial), '_L.jpg')), 'Resolution', 300);
        close(h);
    end

    %% ---------- 5. 拼接 ----------
    saveFolder = fullfile(C.PIC_ROOT, C.Dtype, 'scene2', char(lightness_type), ...
        obsNation, char(obsType), char(iOr));
    concatenate_images1(saveFolder, 4);
end
