% ========================================================================
% C_F_15_compare.m   （phase2 版）
%
% 对应 phase1: B_data_analysis\analyze\C_F_15_compare.m
%
% 作用:
%   把某个观察者族裔对四个刺激族裔的"50% 偏好椭圆"与文献参考肤色
%   （PengCIC / CaoCIC / PMCC / Zeng）画在同一张 a*-b* 图上，看本研究的
%   偏好中心相对文献值偏到哪。
%
% 前置条件:
%   先跑 scatter50_nation2.m 生成
%   AnalyseResults_p\efit_p\50\unscaled\{obsNation}\nation1\scaled\non_model\{iOr}\01Preference\{0XSTIM}\{k}.mat
%   （phase1 里这一层没有 obsNation，phase2 因为族裔挪到观察者层而多了一层）
%
% 输出:
%   ellip_pic_p\efit_p\compare\{obsNation}\0X{STIM}.jpg
% ========================================================================
close all;
clc;
clear;
addpath("utils\")

C = p2_config();

%% ---------- 1. 开关 ----------
iOr        = "r";          % r（14 实景） | i（21 光源）
scale_type = "scaled";     % 与 scatter50_nation2 保持一致
obsType    = "non_model";
ATTRIBUTE  = 1;            % Preference
CLUSTER    = 1;            % 用第几个场景簇（scatter50 的 k）

%% ---------- 2. 参考肤色（文献值，5 列: L, a, b, C, h） ----------
PengCIC = [67, 0, 0, 25.3, 46.0; 65, 0, 0, 25.3, 46.5; ...
           58, 0, 0, 25.1, 46.5; 40, 0, 0, 25.0, 46.5];
PengCIC(:, 2) = PengCIC(:, 4) .* cosd(PengCIC(:, 5));
PengCIC(:, 3) = PengCIC(:, 4) .* sind(PengCIC(:, 5));

CaoCIC = [0, 0, 0, 24.5, 43.7; 0, 0, 0, 25.4, 44.5; ...
          0, 0, 0, 25.7, 48.3; 0, 0, 0, 23.0, 48.0];
CaoCIC(:, 2) = CaoCIC(:, 4) .* cosd(CaoCIC(:, 5));
CaoCIC(:, 3) = CaoCIC(:, 4) .* sind(CaoCIC(:, 5));

Zeng = [0, 18, 21; 0, 17, 16; 0, 0, 0; 0, 21, 29];

nColor = 6;
hues   = linspace(0, 1, nColor + 1); hues = hues(1:end-1);
colors = hsv2rgb([hues', 0.8*ones(nColor,1), 0.8*ones(nColor,1)]);

%% ---------- 3. 逐观察者族裔 ----------
for iObsNation = 1:numel(C.OBS_NATIONS)
    obsNation = C.OBS_NATIONS{iObsNation};

    outDir = fullfile(C.PIC_ROOT, C.Dtype, 'compare', obsNation);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    for iNat = 1:numel(C.STIM_NATIONS)
        stimSerial = strcat(sprintf('%02d', iNat), C.STIM_NATIONS(iNat));
        fitFile = fullfile(C.ANALYSE_ROOT, C.Dtype, '50', C.scale_type_origin, ...
            obsNation, 'nation1', char(scale_type), obsType, char(iOr), ...
            char(strcat(sprintf('%02d', ATTRIBUTE), C.ATTRIBUTE_NAMES(ATTRIBUTE))), ...
            char(stimSerial), strcat(num2str(CLUSTER), '.mat'));
        if ~isfile(fitFile)
            warning('C_F_15: 缺 %s（先跑 scatter50_nation2.m）', fitFile);
            continue
        end

        fitData = load(fitFile, 'par', 'average_indices_curr');
        par = fitData.par;
        center = [fitData.average_indices_curr(1, 1), par(4), par(5)];

        h = figure(iNat);
        set(h, 'Color', 'white');
        grid on; box on; hold on;

        % 50% / 100% 等值线
        a = par;
        d2 = a(4) + (-30:0.2:30);
        d3 = a(5) + (-30:0.2:30);
        [X2, X3] = meshgrid(d2, d3);
        Y = (1 ./ (1 + a(6) * exp(sqrt(a(1)*(X2-a(4)).^2 + a(2)*(X3-a(5)).^2 + ...
            a(3)*(X2-a(4)).*(X3-a(5))))) ) .* ...
            ((a(1)*(X2-a(4)).^2 + a(2)*(X3-a(5)).^2 + a(3)*(X2-a(4)).*(X3-a(5))) >= 0);
        contour(X2, X3, Y, [0.5, 1], 'LineWidth', 1, 'Color', colors(1,:));
        plot(par(4), par(5), 'o', 'MarkerSize', 4, ...
            'MarkerFaceColor', colors(1,:), 'Color', colors(1,:));

        % 文献点
        scatter(PengCIC(iNat,2), PengCIC(iNat,3), 20, '^', 'LineWidth', 1, ...
            'MarkerEdgeColor', colors(2,:));
        scatter(CaoCIC(iNat,2), CaoCIC(iNat,3), 20, '^', 'LineWidth', 1, ...
            'MarkerEdgeColor', colors(3,:));
        scatter(C.LABCH_PMCC(iNat,2), C.LABCH_PMCC(iNat,3), 20, 's', 'LineWidth', 1, ...
            'MarkerEdgeColor', 'm', 'MarkerFaceColor', 'm');
        if Zeng(iNat, 2) ~= 0 || Zeng(iNat, 3) ~= 0
            scatter(Zeng(iNat,2), Zeng(iNat,3), 20, '^', 'LineWidth', 1, ...
                'MarkerEdgeColor', colors(4,:));
        end

        axis equal;
        xlim([0, 32]); ylim([0, 32]);
        xRef = linspace(0, 32, 1000);
        plot(xRef, xRef, 'k-');

        title(sprintf('%s | obs %s', C.STIM_NATION_NAMES(iNat), obsNation), 'FontSize', 30);
        xlabel('{\ita*}'); ylabel('{\itb*}');
        exportgraphics(h, fullfile(outDir, strcat(char(stimSerial), '.jpg')), 'Resolution', 300);
        close(h);

        fprintf('[compare] %s / %-12s 偏好中心 a*=%.2f b*=%.2f（平均肤色 L*=%.2f）\n', ...
            obsNation, C.STIM_NATION_NAMES(iNat), par(4), par(5), center(1));
    end

    concatenate_images1(outDir, 4);
end
