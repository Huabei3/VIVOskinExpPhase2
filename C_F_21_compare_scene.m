% ========================================================================
% C_F_21_compare_scene.m   （phase2 版）
%
% 对应 phase1: B_data_analysis\analyze\C_F_21_compare_scene.m
%
% 作用:
%   同一个刺激族裔、同一观察者，把 4 个场景簇（scatter50_nation2 的 k=1..4）
%   各自的 50% 偏好椭圆叠在一张图上，并叠加 OPPO 手机实测的四个场景肤色，
%   看"场景"对偏好中心的拉扯幅度。
%
% 前置条件:
%   scatter50_nation2.m 已跑过，生成
%   AnalyseResults_p\efit_p\50\unscaled\{obsNation}\nation1\scaled\non_model\{iOr}\01Preference\{0XSTIM}\{k}.mat
%
% 输出:
%   ellip_pic_p\efit_p\compare_scene\{obsNation}\0X{STIM}.jpg
% ========================================================================
close all;
clc;
clear;
addpath("utils\")

C = p2_config();

%% ---------- 1. 开关 ----------
iOr        = "r";          % r（14 实景，场景簇才有意义） | i
scale_type = "scaled";
obsType    = "non_model";
ATTRIBUTE  = 1;            % Preference
ETH_LIST   = 1;            % 要画的刺激族裔（1=AS, 2=CA, 3=SA, 4=AF）

%% ---------- 2. 参考点（OPPO 实测四场景 + PMCC） ----------
scenesOPPO = [59.22, 0, 0, 26.81, 46.85;   % 室内
              57.49, 0, 0, 23.66, 46.81;   % 室外
              62.87, 0, 0, 22.02, 42.75;   % 黄昏
              61.78, 0, 0, 25.84, 49.74];  % 夜景
scenesOPPO(:, 2) = scenesOPPO(:, 4) .* cosd(scenesOPPO(:, 5));
scenesOPPO(:, 3) = scenesOPPO(:, 4) .* sind(scenesOPPO(:, 5));

nColor = 4;
hues   = linspace(0, 1, nColor + 1); hues = hues(1:end-1);
colors = hsv2rgb([hues', 0.8*ones(nColor,1), 0.8*ones(nColor,1)]);

%% ---------- 3. 逐观察者族裔 ----------
for iObsNation = 1:numel(C.OBS_NATIONS)
    obsNation = C.OBS_NATIONS{iObsNation};

    outDir = fullfile(C.PIC_ROOT, C.Dtype, 'compare_scene', obsNation);
    if ~exist(outDir, 'dir'), mkdir(outDir); end

    for iNat = ETH_LIST
        stimSerial = strcat(sprintf('%02d', iNat), C.STIM_NATIONS(iNat));
        srcDir = fullfile(C.ANALYSE_ROOT, C.Dtype, '50', C.scale_type_origin, ...
            obsNation, 'nation1', char(scale_type), obsType, char(iOr), ...
            char(strcat(sprintf('%02d', ATTRIBUTE), C.ATTRIBUTE_NAMES(ATTRIBUTE))), ...
            char(stimSerial));

        h = figure(iNat);
        set(h, 'Color', 'white');
        grid on; box on; hold on;

        nPlotted = 0;
        for k = 1:nColor
            fitFile = fullfile(srcDir, strcat(num2str(k), '.mat'));
            if ~isfile(fitFile), continue; end
            fitData = load(fitFile, 'par');
            par = fitData.par;
            nPlotted = nPlotted + 1;

            a  = par;
            d2 = a(4) + (-30:0.2:30);
            d3 = a(5) + (-30:0.2:30);
            [X2, X3] = meshgrid(d2, d3);
            Y = (1 ./ (1 + a(6) * exp(sqrt(a(1)*(X2-a(4)).^2 + a(2)*(X3-a(5)).^2 + ...
                a(3)*(X2-a(4)).*(X3-a(5))))) ) .* ...
                ((a(1)*(X2-a(4)).^2 + a(2)*(X3-a(5)).^2 + a(3)*(X2-a(4)).*(X3-a(5))) >= 0);
            contour(X2, X3, Y, [0.5, 1], 'LineWidth', 1, 'Color', colors(k, :));
            plot(par(4), par(5), 'o', 'MarkerSize', 4, ...
                'MarkerFaceColor', colors(k,:), 'Color', colors(k,:));

            if k <= size(scenesOPPO, 1)
                scatter(scenesOPPO(k,2), scenesOPPO(k,3), 20, '^', 'LineWidth', 1, ...
                    'MarkerEdgeColor', colors(k,:));
            end
        end

        if nPlotted == 0
            warning('C_F_21: %s / %s 没有可用的 50 椭圆（先跑 scatter50_nation2.m）', ...
                obsNation, char(stimSerial));
            close(h);
            continue
        end

        scatter(C.LABCH_PMCC(iNat, 2), C.LABCH_PMCC(iNat, 3), 20, 's', 'LineWidth', 1, ...
            'MarkerEdgeColor', 'm', 'MarkerFaceColor', 'm');

        axis equal;
        xlim([-5, 40]); ylim([-5, 40]);
        xRef = linspace(-5, 40, 1000);
        plot(xRef, xRef, 'k-');

        title(sprintf('%s | obs %s | scene clusters', C.STIM_NATION_NAMES(iNat), obsNation));
        xlabel('{\ita*}'); ylabel('{\itb*}');
        exportgraphics(h, fullfile(outDir, strcat(char(stimSerial), '.jpg')), 'Resolution', 300);
        close(h);

        fprintf('[compare_scene] %s / %-12s 画出 %d 个场景簇椭圆\n', ...
            obsNation, C.STIM_NATION_NAMES(iNat), nPlotted);
    end

    if numel(ETH_LIST) > 1
        concatenate_images1(outDir, 4);
    end
end
