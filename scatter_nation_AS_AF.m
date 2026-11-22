% ========================================================================
% scatter_nation_AS_AF.m   （phase1 Asian 观察者 × phase2 African 观察者）
%
% 作用:
%   一张图 = 2 个水平拼合的子图（(a) Preference、(b) Healthy），每个子图内画
%   同一场景（默认 hd65）下、按刺激模特族裔（AS / CA / SA / AF）聚合出的
%   50% 等偏好椭圆，共 4 个刺激族裔 × 2 个观察者群体 = 8 个椭圆：
%       phase1（观察者 = Asian）  : 虚线 + 空心圆心
%       phase2（观察者 = African）: 实线 + 实心圆心
%   颜色只表示刺激族裔（一个族裔一个颜色），线型/圆心只表示观察者群体。
%   图例统一放在拼合图下方，在整块拼合宽度内水平居中。
%
% 数据来源（完整绝对路径）:
%   phase1 : <P1_ROOT>\B_data_analysis\analyze\AnalyseResults_p\efit_p\unscaled\
%            {subject}\non_model\{attr}\labNscore\labNscore_group{subject}{scene}.mat
%            = D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\
%              B_data_analysis\analyze\AnalyseResults_p\efit_p\unscaled\...
%   phase2 : D:\work\VIVOSkin_phase2\analyze\AnalyseResults_p\efit_p\unscaled\
%            AF\{subject}\non_model\{attr}\labNscore\labNscore_group{subject}{scene}.mat
%
%   两期都取"该族裔全部受试者在该场景的 33 个刺激点"合并后重新拟合，
%   缩放（相对亮度 rela / scaled）、p_ratio 过滤、拟合函数完全一致，
%   因此两个观察者群体的椭圆可以直接比较。
%   只需要各受试者该场景的 1 个 labNscore 文件（每个约 2 KB），
%   不必把 E 盘整个工程拷过来。
%
% 椭圆模型（my_ellipsoidfit3_dy）:
%   y = 1 / (1 + k6 * exp(sqrt(k1*dx^2 + k2*dy^2 + k3*dx*dy)))
%   50% 等值线:  k1*dx^2 + k2*dy^2 + k3*dx*dy = (ln(1/k6))^2
%   圆心 (a*, b*) = [par(4), par(5)]（拟合时被固定在偏好点评分的加权均值）
%
% 输出:
%   ellip_pic_p\efit_p\nation2\rela\cmp_p1_AF\{iOr}\CMP_NATION_{scene}.jpg
%   AnalyseResults_p\efit_p\50\unscaled\AF\nation1\scaled\non_model\{iOr}\{attr}\{0XSTIM}\scene{NN}.mat
% ========================================================================
close all;
clc;
clear;
addpath("utils\")

C = p2_config();

%% ---------- 1. 开关 ----------
iOr          = "i";            % 本脚本只支持 i 组（21 个光源）
SCENE        = "hd65";         % 场景名（C.PICNAMES_I 之一）
obsNationP2  = "AF";           % phase2 观察者族裔
obsType      = "non_model";    % 观察者类型
ATTR_LIST    = [1, 6];         % 子图属性：1 = Preference，6 = Healthy
PANEL_TAGS   = {'(a)', '(b)'}; % 子图右下角标号
SAVE_P2FIT   = true;           % 是否把 phase2 的族裔级拟合结果落盘
SEED         = 0;              % 拟合初值随机，固定种子保证可复现
nPtEllipse   = 361;            % 椭圆采样点数
FONT_SIZE    = 16;             % 全局字号（轴标签 / 刻度 / 标题 / 图例 / 图内文字）
TICK_STEP    = 5;              % x / y 刻度间隔（两个方向强制一致）
LEGEND_ALIGN = 'center';       % 'center'（拼合图宽度内居中） | 'left'（左对齐）

if iOr ~= "i"
    error('scatter_nation_AS_AF: 当前只支持 i 组（21 个光源）');
end
iPara = find(strcmp(C.PICNAMES_I, SCENE), 1);
if isempty(iPara)
    error('scatter_nation_AS_AF: 场景 "%s" 不在 C.PICNAMES_I 里', char(SCENE));
end
nAttr = numel(ATTR_LIST);
nNat  = numel(C.STIM_NATIONS);
rng(SEED);

%% ---------- 2. 两期的根目录 + 公共资源 ----------
P1_ANALYSE = fullfile(C.P1_ROOT, 'B_data_analysis', 'analyze', 'AnalyseResults_p');
P1_WHITE   = fullfile(C.P1_ROOT, 'B_data_analysis', 'analyze', 'optimizedD', ...
    'whiteSquare', 'XYZw_white');
P2_WHITE   = fullfile(C.P2_ROOT, 'optimizedD', 'whiteSquare', 'XYZw_white');

% phase1 用 ipv18，phase2 用 phase2 自己的显示标定（两者白点不同，不能混用）
lut1     = load(C.LUT18_FILE,  'XYZw');
XYZw_LUT1 = lut1.XYZw;
lut2     = load(C.LUT_P2_FILE, 'XYZw');
XYZw_LUT2 = lut2.XYZw;
wd65     = C.WD65;

%% ---------- 3. 逐属性 × 逐族裔，两期各拟合一个 50% 椭圆 ----------
parP1  = nan(nNat, 6, nAttr);
parP2  = nan(nNat, 6, nAttr);
statP1 = struct('r', nan(nNat, nAttr), 'nDot', zeros(nNat, nAttr), 'nSub', zeros(nNat, nAttr));
statP2 = statP1;

for iA = 1:nAttr
    attr       = ATTR_LIST(iA);
    attrSerial = strcat(sprintf('%02d', attr), C.ATTRIBUTE_NAMES(attr));
    fprintf('\n[NATION] ===== %s (%s) =====\n', char(attrSerial), char(SCENE));

    for iNat = 1:nNat
        models = C.STIM_MODELS{iNat};

        % ---- phase1（Asian 观察者）----
        [parP1(iNat, :, iA), statP1.r(iNat, iA), ...
            statP1.nDot(iNat, iA), statP1.nSub(iNat, iA)] = ...
            fitNationDot(models, iOr, P1_ANALYSE, '', obsType, attrSerial, ...
            char(SCENE), iPara, P1_WHITE, XYZw_LUT1, wd65, SEED);

        % ---- phase2（African 观察者）----
        [parP2(iNat, :, iA), statP2.r(iNat, iA), ...
            statP2.nDot(iNat, iA), statP2.nSub(iNat, iA)] = ...
            fitNationDot(models, iOr, C.ANALYSE_ROOT, obsNationP2, obsType, ...
            attrSerial, char(SCENE), iPara, P2_WHITE, XYZw_LUT2, wd65, SEED);

        fprintf(['  %-3s  p1(%s): %d 人 %3d 点 r=%.2f 圆心(%5.2f,%5.2f) | ' ...
            'p2(%s): %d 人 %3d 点 r=%.2f 圆心(%5.2f,%5.2f)\n'], ...
            char(C.STIM_NATIONS(iNat)), 'AS', statP1.nSub(iNat, iA), ...
            statP1.nDot(iNat, iA), statP1.r(iNat, iA), ...
            parP1(iNat, 4, iA), parP1(iNat, 5, iA), char(obsNationP2), ...
            statP2.nSub(iNat, iA), statP2.nDot(iNat, iA), statP2.r(iNat, iA), ...
            parP2(iNat, 4, iA), parP2(iNat, 5, iA));

        % ---- 落盘（仅 phase2，命名带场景序号，避免和 phase1 的簇编号混淆）----
        if SAVE_P2FIT && ~any(isnan(parP2(iNat, :, iA)))
            outDir = fullfile(C.ANALYSE_ROOT, C.Dtype, '50', C.scale_type_origin, ...
                obsNationP2, 'nation1', 'scaled', obsType, char(iOr), ...
                char(attrSerial), sprintf('%02d%s', iNat, C.STIM_NATIONS(iNat)));
            if ~exist(outDir, 'dir'), mkdir(outDir); end
            par = parP2(iNat, :, iA);  %#ok<NASGU>
            r   = statP2.r(iNat, iA);  %#ok<NASGU>
            save(fullfile(outDir, sprintf('scene%02d.mat', iPara)), 'par', 'r');
        end
    end
end

%% ---------- 4. 统一轴范围（两个子图、两个来源共用） ----------
allX = [];
allY = [];
for iA = 1:nAttr
    for iNat = 1:nNat
        [x1, y1] = ellipsePoints50(parP1(iNat, :, iA), nPtEllipse);
        [x2, y2] = ellipsePoints50(parP2(iNat, :, iA), nPtEllipse);
        allX = [allX, x1, x2, parP1(iNat, 4, iA), parP2(iNat, 4, iA)];   %#ok<AGROW>
        allY = [allY, y1, y2, parP1(iNat, 5, iA), parP2(iNat, 5, iA)];   %#ok<AGROW>
    end
end
allX = allX(isfinite(allX));
allY = allY(isfinite(allY));
if isempty(allX)
    error('scatter_nation_AS_AF: 两个来源都没有可用的椭圆');
end
lims = [max(0, floor(min([allX, allY]) - 1)), ceil(max([allX, allY]) + 1)];

%% ---------- 5. 配色（一个刺激族裔一个颜色） ----------
hue       = linspace(0, 1, nNat + 1); hue = hue(1:end-1);
natColors = hsv2rgb([hue', 0.80 * ones(nNat, 1), 0.85 * ones(nNat, 1)]);

%% ---------- 6. 绘图：两个子图水平拼合 ----------
h = figure('Color', 'white', 'Position', [60, 60, 1250, 900]);
drawnow;
szPx = h.Position(3:4);          % 实际窗口像素（可能被屏幕裁小，按实际算）

% 每个子图的坐标框都按像素算成正方形：axis equal 才不会把 PlotBox 缩进去
S_PLOT    = round(0.60 * szPx(2));                          % 单面板边长（px）
GAP_PX    = round(0.10 * szPx(2));                          % 面板间距（px，要给右侧 ylabel + 刻度留够位置）
BLOCK_PX  = 2 * S_PLOT + GAP_PX;                            % 拼合块总宽
LEFT_PX   = round((szPx(1) - BLOCK_PX) / 2);                % 水平居中
BOTTOM_PX = szPx(2) - S_PLOT - round(0.045 * szPx(2));      % 顶部留标题，下方留 xlabel + 图例

axList = gobjects(1, nAttr);
for iA = 1:nAttr
    xPx = LEFT_PX + (iA - 1) * (S_PLOT + GAP_PX);
    axList(iA) = axes(h, 'Position', [xPx / szPx(1), BOTTOM_PX / szPx(2), ...
        S_PLOT / szPx(1), S_PLOT / szPx(2)]);
    hold(axList(iA), 'on');
    drawPanel(axList(iA), parP1(:, :, iA), parP2(:, :, iA), natColors, lims, ...
        char(C.ATTRIBUTE_NAMES(ATTR_LIST(iA))), PANEL_TAGS{iA}, FONT_SIZE, TICK_STEP);
end

%% ---------- 7. 图 1 的图例（拼合图下方，整块宽度内居中；族裔排成一排） ----------
modelLabels = cell(1, nNat);
for iNat = 1:nNat
    modelLabels{iNat} = sprintf('%s models', C.STIM_NATION_NAMES(iNat));
end
obsLabels = {'Asian observers', 'African observers'};
spanRect  = [LEFT_PX / szPx(1), 0, BLOCK_PX / szPx(1), 0];
top1 = 0.175;                    % 第一排（模特族裔）图例的顶边
top2 = 0.060;                    % 第二排（观察者）图例的中心线
addLegends(h, natColors, modelLabels, obsLabels, spanRect, LEGEND_ALIGN, ...
    top1, top2, FONT_SIZE);

%% ---------- 8. 导出图 1 ----------
saveFolder = fullfile(C.PIC_ROOT, C.Dtype, 'nation2', 'rela', ...
    sprintf('cmp_p1_%s', obsNationP2), char(iOr));
if ~exist(saveFolder, 'dir'), mkdir(saveFolder); end
outFile = fullfile(saveFolder, strcat('CMP_NATION_', char(SCENE), '.jpg'));
% 用 print 而不是 exportgraphics：
%   exportgraphics 按"内容紧包围盒"裁切，图例一旦挤出坐标框，画布长宽比就变，
%   归一化坐标被压缩，子图与图例就错位；print 严格按纸张（= 窗口尺寸）导出，
%   配合 PaperPositionMode='auto' 可以把归一化坐标 1:1 映射到像素。
set(h, 'PaperPositionMode', 'auto');
print(h, outFile, '-djpeg', '-r300');
close(h);

%% ---------- 9. 图 2：Preference 椭圆 + "Preference 圆心 → Healthy 圆心" 位移箭头 ----------
%   只画 Preference 的椭圆；箭头起点 = Preference 圆心，箭尖 = Healthy 圆心
%   （Healthy 的椭圆不画）。Asian 观察者 = 虚线箭头，African 观察者 = 实线箭头。
if nAttr < 2
    warning('scatter_nation_AS_AF: 属性少于 2 个，跳过箭头图');
    outFile2 = '';
else
    iAPref = 1;                  % 椭圆与箭头起点用第 1 个属性（Preference）
    iAHeal = 2;                  % 箭头终点用第 2 个属性（Healthy）

    h2 = figure('Color', 'white', 'Position', [60, 60, 1250, 900]);
    drawnow;
    sz2 = h2.Position(3:4);
    S2  = round(0.60 * sz2(2));
    L2  = round((sz2(1) - S2) / 2);
    B2  = sz2(2) - S2 - round(0.045 * sz2(2));
    ax2 = axes(h2, 'Position', [L2 / sz2(1), B2 / sz2(2), S2 / sz2(1), S2 / sz2(2)]);
    hold(ax2, 'on');
    drawArrowPanel(ax2, parP1(:, :, iAPref), parP2(:, :, iAPref), ...
        parP1(:, :, iAHeal), parP2(:, :, iAHeal), natColors, lims, FONT_SIZE, TICK_STEP);

    % 图例：族裔颜色（一排）+ 说明箭头 Preference → Healthy 在同一排，第二排观察者线型
    span2 = [0.02, 0, 0.96, 0];
    addArrowFigureLegend(h2, natColors, modelLabels, obsLabels, span2, ...
        top1, top2, {'Preference', 'Healthy'}, FONT_SIZE);

    outFile2 = fullfile(saveFolder, strcat('CMP_NATION_', char(SCENE), '_arrow.jpg'));
    set(h2, 'PaperPositionMode', 'auto');
    print(h2, outFile2, '-djpeg', '-r300');
    close(h2);
end

%% ---------- 10. 圆心色度 C* / 色相 h* 的 AS → AF 增量，输出 xlsx ----------
%   C* = sqrt(a*^2 + b*^2)，h* = atan2d(b*, a*)（0~360°，Δh* 取最短角差）
nRowC = nAttr * nNat * 2;
tAttr = strings(nRowC, 1);
tNat  = strings(nRowC, 1);
tObs  = strings(nRowC, 1);
tA    = nan(nRowC, 1);
tB    = nan(nRowC, 1);
tC    = nan(nRowC, 1);
tH    = nan(nRowC, 1);

k = 0;
for iA = 1:nAttr
    for iNat = 1:nNat
        for iObs = 1:2
            if iObs == 1
                parCur  = parP1(iNat, :, iA);
                obsName = "Asian (phase1)";
            else
                parCur  = parP2(iNat, :, iA);
                obsName = "African (phase2 AF)";
            end
            k = k + 1;
            tAttr(k) = string(C.ATTRIBUTE_NAMES(ATTR_LIST(iA)));
            tNat(k)  = string(C.STIM_NATIONS(iNat));
            tObs(k)  = obsName;
            tA(k)    = parCur(4);
            tB(k)    = parCur(5);
            tC(k)    = hypot(parCur(4), parCur(5));
            tH(k)    = mod(atan2d(parCur(5), parCur(4)), 360);
        end
    end
end

TabCenters = table(tAttr, tNat, tObs, tA, tB, tC, tH, 'VariableNames', ...
    {'Attribute', 'ModelNation', 'ObsNation', 'a_star', 'b_star', 'Chroma', 'Hue_deg'});

% ---- 增量表：每个属性 × 每个刺激族裔一行，末尾加各属性的平均行 ----
nRowD  = nAttr * nNat + nAttr + 1;      % + 每属性平均 + 总体平均
dAttr  = strings(nRowD, 1);
dNat   = strings(nRowD, 1);
dC1    = nan(nRowD, 1);
dC2    = nan(nRowD, 1);
dDC    = nan(nRowD, 1);
dH1    = nan(nRowD, 1);
dH2    = nan(nRowD, 1);
dDH    = nan(nRowD, 1);

k = 0;
allDC = [];
allDH = [];
for iA = 1:nAttr
    blkDC = nan(1, nNat);
    blkDH = nan(1, nNat);
    for iNat = 1:nNat
        c1 = hypot(parP1(iNat, 4, iA), parP1(iNat, 5, iA));
        c2 = hypot(parP2(iNat, 4, iA), parP2(iNat, 5, iA));
        h1 = mod(atan2d(parP1(iNat, 5, iA), parP1(iNat, 4, iA)), 360);
        h2 = mod(atan2d(parP2(iNat, 5, iA), parP2(iNat, 4, iA)), 360);
        k = k + 1;
        dAttr(k) = string(C.ATTRIBUTE_NAMES(ATTR_LIST(iA)));
        dNat(k)  = string(C.STIM_NATIONS(iNat));
        dC1(k) = c1;  dC2(k) = c2;  dDC(k) = c2 - c1;
        dH1(k) = h1;  dH2(k) = h2;  dDH(k) = wrapDeg180(h2 - h1);
        blkDC(iNat) = c2 - c1;
        blkDH(iNat) = wrapDeg180(h2 - h1);
        allDC(end+1) = c2 - c1;               %#ok<AGROW>
        allDH(end+1) = wrapDeg180(h2 - h1);   %#ok<AGROW>
    end
    k = k + 1;
    dAttr(k) = string(C.ATTRIBUTE_NAMES(ATTR_LIST(iA)));
    dNat(k)  = "Mean (all model nations)";
    dDC(k)   = mean(blkDC, 'omitnan');
    dDH(k)   = mean(blkDH, 'omitnan');
end

k = k + 1;
dAttr(k) = "All attributes";
dNat(k)  = "Mean (all model nations)";
dDC(k)   = mean(allDC, 'omitnan');
dDH(k)   = mean(allDH, 'omitnan');

TabDelta = table(dAttr, dNat, dC1, dC2, dDC, dH1, dH2, dDH, 'VariableNames', ...
    {'Attribute', 'ModelNation', 'Chroma_Asian', 'Chroma_African', 'dChroma', ...
     'Hue_Asian_deg', 'Hue_African_deg', 'dHue_deg'});

% 便于阅读的圆整版本（另存一个 sheet）
TabDeltaR = TabDelta;
numVars = {'Chroma_Asian', 'Chroma_African', 'dChroma', 'Hue_Asian_deg', ...
    'Hue_African_deg', 'dHue_deg'};
for v = 1:numel(numVars)
    TabDeltaR.(numVars{v}) = round(TabDeltaR.(numVars{v}), 2);
end
TabCentersR = TabCenters;
numVarsC = {'a_star', 'b_star', 'Chroma', 'Hue_deg'};
for v = 1:numel(numVarsC)
    TabCentersR.(numVarsC{v}) = round(TabCentersR.(numVarsC{v}), 2);
end

xlsxFile = fullfile(saveFolder, strcat('CMP_NATION_', char(SCENE), '_dC_dH.xlsx'));
if isfile(xlsxFile), delete(xlsxFile); end
writetable(TabCentersR, xlsxFile, 'Sheet', 'centers');
writetable(TabDeltaR,  xlsxFile, 'Sheet', 'delta_AS_to_AF');

%% ---------- 11. 终端小结 ----------
for iA = 1:nAttr
    fprintf('\n[NATION] %s 场景 / %s，圆心 (a*, b*) 与位移:\n', char(SCENE), ...
        char(strcat(sprintf('%02d', ATTR_LIST(iA)), C.ATTRIBUTE_NAMES(ATTR_LIST(iA)))));
    fprintf('  %-4s  %-18s  %-18s  %s\n', 'NAT', 'Asian (p1)', 'African (p2)', 'dist');
    for iNat = 1:nNat
        p1 = parP1(iNat, 4:5, iA);
        p2 = parP2(iNat, 4:5, iA);
        fprintf('  %-4s  (%6.2f, %6.2f)    (%6.2f, %6.2f)    %6.2f\n', ...
            char(C.STIM_NATIONS(iNat)), p1(1), p1(2), p2(1), p2(2), norm(p2 - p1));
    end
end
fprintf('\n[NATION] dC* / dh* (AS -> AF):\n');
fprintf('  %-14s  %-26s  %8s  %8s\n', 'Attribute', 'ModelNation', 'dC*', 'dh*');
for i = 1:height(TabDeltaR)
    fprintf('  %-14s  %-26s  %8.2f  %8.2f\n', char(TabDeltaR.Attribute(i)), ...
        char(TabDeltaR.ModelNation(i)), TabDeltaR.dChroma(i), TabDeltaR.dHue_deg(i));
end
fprintf('\n[NATION] 出图: %s\n', outFile);
if ~isempty(outFile2)
    fprintf('[NATION] 箭头图: %s\n', outFile2);
end
fprintf('[NATION] 增量表: %s\n', xlsxFile);

% ========================================================================
% 局部函数
% ========================================================================
function [par, r, nDot, nSub] = fitNationDot(models, iOr, analyseRoot, obsNation, ...
    obsType, attrSerial, scene, iPara, whiteDir, XYZw_LUT, wd65, seed)
%FITNATIONDOT  把某族裔全部受试者在某场景的 33 个刺激点合并后拟合 50% 椭圆
%   models     : 该族裔的 model 编号（不含 i/r 后缀）
%   analyseRoot: 结果根目录（phase1 / phase2 各一个）
%   obsNation  : 观察者族裔层；phase1 没有这一层，传 ''
%   whiteDir   : XYZw_white 所在目录（{subject}.mat）
%   返回 par(1×6)、相关系数 r、参与拟合的点数、受试者数
    par  = nan(1, 6);
    r    = NaN;
    nSub = 0;
    labAll = [];
    pAll   = [];

    for m = 1:numel(models)
        lp = char(models(m) + iOr);

        if isempty(obsNation)
            f = fullfile(analyseRoot, 'efit_p', 'unscaled', lp, obsType, ...
                char(attrSerial), 'labNscore', ...
                strcat('labNscore_group', lp, scene, '.mat'));
        else
            f = fullfile(analyseRoot, 'efit_p', 'unscaled', obsNation, lp, obsType, ...
                char(attrSerial), 'labNscore', ...
                strcat('labNscore_group', lp, scene, '.mat'));
        end
        if ~isfile(f), continue; end

        S = load(f, 'lab_group', 'p_group');
        if ~isfield(S, 'lab_group') || ~isfield(S, 'p_group'), continue; end
        labCur = S.lab_group;      % 33×3
        pCur   = S.p_group;        % 33×1
        if size(labCur, 1) ~= size(pCur, 1), continue; end

        % 评分分布过度偏斜的单元不参与（phase1 的经验阈值）
        pRatio = nnz(pCur > 0.5) / numel(pCur);
        if pRatio < 0.1 || pRatio > 0.9
            fprintf('  [skip] %s 评分偏斜 (p_ratio=%.2f)\n', lp, pRatio);
            continue
        end

        % 相对亮度缩放（phase1 的 rela 与 phase2 的 scale 是同一件事）
        wFile = fullfile(whiteDir, [lp '.mat']);
        if ~isfile(wFile), continue; end
        W = load(wFile, 'XYZw_white');
        labCur = scaleLabToScene(labCur, XYZw_LUT, W.XYZw_white(iPara, 2), wd65);

        labAll = [labAll; labCur];   %#ok<AGROW>
        pAll   = [pAll;   pCur];     %#ok<AGROW>
        nSub   = nSub + 1;
    end

    ok = ~any(isnan([labAll, pAll]), 2);
    labAll = labAll(ok, :);
    pAll   = pAll(ok);
    nDot   = numel(pAll);
    if nDot < 10, return; end

    [parMean, ~] = calculate_weighted_or_simple_mean(pAll, labAll);
    meanCen      = [mean(labAll(:, 1), 'omitnan'), parMean(1, 4:5)];
    rng(seed);
    evalc('[parFit, r, y] = my_ellipsoidfit3_dy(labAll, pAll, meanCen);');   %#ok<ASGLU>
    par = parFit(1, 1:6);
end

% ------------------------------------------------------------------------
function d = wrapDeg180(d)
%WRAPDEG180  把角度差折到 [-180, 180)，色相增量取最短转动方向
    d = mod(d + 180, 360) - 180;
end

% ------------------------------------------------------------------------
function lab = scaleLabToScene(lab, XYZw_LUT, Yscene, wd65)
%SCALELABTOSCENE  相对亮度缩放（与 phase1 rela / phase2 'scale' 完全一致）
%   1) 把 Lab 当作 LUT 参考白（Y = XYZw_LUT(2)）下的坐标转回 XYZ；
%   2) 再用"场景白点（Y = Yscene）"重新转成 Lab。
%   lab 可以是 m×3（一次处理全部刺激点），Yscene 是标量。
    xyz = lab2xyz2(lab, 'user', wd65 ./ wd65(2) .* XYZw_LUT(2));
    lab = xyz2lab(xyz, 'user', wd65 ./ wd65(2) .* Yscene);
end

% ------------------------------------------------------------------------
function [X, Y] = ellipsePoints50(par, nPt)
%ELLIPSEPOINTS50  由 6 个椭圆参数解析地画出 50% 等偏好等值线
%   y = 1/(1 + k6*exp(sqrt(Q)))，Q = k1*dx^2 + k2*dy^2 + k3*dx*dy
%   y = 0.5  =>  Q = (ln(1/k6))^2，是一个二次曲线（椭圆）
%   参数非法（k6 不在 (0,1)、二次型非正定）时返回空，调用方跳过即可。
    X = []; Y = [];
    k1 = par(1); k2 = par(2); k3 = par(3); a = par(4); b = par(5); k6 = par(6);
    if any(~isfinite([k1, k2, k3, a, b, k6])), return; end
    if k6 <= 0 || k6 >= 1, return; end

    L = -log(k6);                    % 等值线对应的"半径"（Q 的平方根）
    A = [k1, k3 / 2; k3 / 2, k2];
    if k1 <= 0 || k2 <= 0 || det(A) <= 0, return; end

    [V, D] = eig(A);
    d = diag(D);
    if any(d <= 0), return; end
    Ai = V * diag(1 ./ sqrt(d)) * V';    % A^(-1/2)，把单位圆映射成等值线椭圆

    t = linspace(0, 2 * pi, nPt);
    P = Ai * (L * [cos(t); sin(t)]);
    X = a + P(1, :);
    Y = b + P(2, :);
end

% ------------------------------------------------------------------------
function drawPanel(ax, par1, par2, natColors, lims, panelTitle, tag, fontSize, tickStep)
%DRAWPANEL  画一个子图：8 个椭圆 + 45° 线 + 轴设置 + 标题 + 右下角标号
%   par1 / par2 : nNat×6，Asian / African 观察者的椭圆参数（同一下标 = 同一刺激族裔）
%   tickStep    : x / y 共用的刻度间隔（MATLAB 自动刻度可能给 10 和 5，必须强制统一）
    nNat  = size(par1, 1);
    range = lims(2) - lims(1);

    % ---- 45° 等色相参考线 ----
    xLine = linspace(lims(1), lims(2), 100);
    plot(ax, xLine, xLine, 'Color', [0.4 0.4 0.4], 'LineStyle', '--');
    text(ax, lims(2) - 0.02 * range, lims(2) - 0.03 * range, '45°', ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', ...
        'FontSize', fontSize, 'Color', [0.3 0.3 0.3]);

    for iNat = 1:nNat
        col = natColors(iNat, :);

        % phase1: Asian，虚线 + 空心圆心
        [x1, y1] = ellipsePoints50(par1(iNat, :), 361);
        if ~isempty(x1)
            plot(ax, x1, y1, 'Color', col, 'LineStyle', '--', 'LineWidth', 1.6);
            plot(ax, par1(iNat, 4), par1(iNat, 5), 'o', 'MarkerSize', 6, ...
                'MarkerEdgeColor', col, 'MarkerFaceColor', 'none', 'LineWidth', 1.4);
        end

        % phase2: African，实线 + 实心圆心
        [x2, y2] = ellipsePoints50(par2(iNat, :), 361);
        if ~isempty(x2)
            plot(ax, x2, y2, 'Color', col, 'LineStyle', '-', 'LineWidth', 1.6);
            plot(ax, par2(iNat, 4), par2(iNat, 5), 'o', 'MarkerSize', 6, ...
                'MarkerEdgeColor', col, 'MarkerFaceColor', col, 'LineWidth', 1.4);
        end
    end

    % ---- 坐标轴 ----
    axis(ax, 'equal');
    xlim(ax, lims);
    ylim(ax, lims);
    ticks = lims(1):tickStep:lims(2);
    ax.XTick = ticks;                    % x / y 刻度间隔强制一致
    ax.YTick = ticks;
    ax.XAxis.FontSize = fontSize;        % x / y 刻度字号保持一致
    ax.YAxis.FontSize = fontSize;
    xlabel(ax, '{\ita}^{*}', 'Interpreter', 'tex', 'FontSize', fontSize);
    ylabel(ax, '{\itb}^{*}', 'Interpreter', 'tex', 'FontSize', fontSize);
    box(ax, 'on');
    grid(ax, 'on');
    title(ax, panelTitle, 'FontSize', fontSize, 'FontWeight', 'normal');

    % ---- 右下角 (a) / (b) ----
    text(ax, lims(2) - 0.03 * range, lims(1) + 0.03 * range, tag, ...
        'FontSize', fontSize, 'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'bottom', 'Color', [0.15 0.15 0.15]);
end

% ------------------------------------------------------------------------
function addLegends(fig, natColors, modelLabels, obsLabels, spanRect, alignMode, ...
    top1, top2, fontSize)
%ADDLEGENDS  两排说明：第一排刺激模特族裔颜色（legend），第二排观察者群体（手绘）
%   spanRect    : 对齐参照 [x0 0 w 0]，两排都在这个宽度内居中 / 左对齐
%   alignMode   : 'center' 居中 | 'left' 左对齐
%   top1 / top2 : 第一排图例顶边 / 第二排中心线的 y（figure 归一化坐标）
%   fontSize    : 图例字号（与轴标签、刻度统一）
%   注意: 同一个 axes 只能有一个 legend 对象（第二次调用 legend 会直接覆盖
%         第一个），所以第二排的"虚线/实线 + 空心/实心圆心"改成手绘线段，
%         避免两排图例互相吃掉。
    axO = axes(fig, 'Position', [0 0 1 1], 'Visible', 'off', ...
        'XLim', [0 1], 'YLim', [0 1]);
    hold(axO, 'on');
    padX = 8 / fig.Position(3);      % legend 内部左边距（约 8 px），对齐时扣除

    % ---- 第一排：刺激模特族裔颜色，4 个族裔排成一排 ----
    lg1 = drawNationLegend(axO, natColors, modelLabels, fontSize);
    drawnow;

    p1 = lg1.Position;
    if strcmpi(alignMode, 'center')
        xLegend = spanRect(1) + (spanRect(3) - p1(3)) / 2;   % 在参照宽度内居中
    else
        xLegend = spanRect(1) - padX;                        % 色块左缘对齐参照左缘
    end
    lg1.Position = [xLegend, top1 - p1(4), p1(3), p1(4)];

    % ---- 第二排：观察者群体（手绘：线段 + 圆心 + 文字） ----
    drawObsRow(axO, obsLabels, spanRect, top2, fontSize, alignMode);
end

% ------------------------------------------------------------------------
function lg = drawNationLegend(axO, natColors, modelLabels, fontSize)
%DRAWNATIONLEGEND  族裔颜色图例（横向一排、无边框），返回 legend 对象
    nNat = size(natColors, 1);
    hNat = gobjects(1, nNat);
    for i = 1:nNat
        hNat(i) = plot(axO, nan, nan, 's', 'MarkerSize', 12, ...
            'MarkerEdgeColor', 'none', 'MarkerFaceColor', natColors(i, :), ...
            'LineStyle', 'none');
    end
    lg = legend(axO, hNat, modelLabels, 'Orientation', 'horizontal', ...
        'FontSize', fontSize, 'Box', 'off');
    lg.AutoUpdate    = 'off';
    lg.ItemTokenSize = [18, 10];
    lg.Box           = 'off';
end

% ------------------------------------------------------------------------
function drawObsRow(axO, obsLabels, spanRect, yRow, fontSize, alignMode)
%DRAWObsROW  观察者群体说明行：虚线+空心圆 = Asian，实线+实心圆 = African
%   先建对象量文字宽度，再整体定位，保证在 spanRect 宽度内真正居中。
    col    = [0.25 0.25 0.25];
    segL   = 0.050;                  % 线段长度（figure 归一化）
    gapT   = 0.012;                  % 线段与文字的间距
    gapM   = 0.060;                  % 两组说明之间的间距
    styles = {'--', '-'};
    faces  = {'none', col};

    hLine = gobjects(1, 2);
    hMark = gobjects(1, 2);
    hText = gobjects(1, 2);
    wText = zeros(1, 2);
    for i = 1:2
        hLine(i) = plot(axO, [0, 0], [yRow, yRow], styles{i}, 'Color', col, 'LineWidth', 1.4);
        hMark(i) = plot(axO, 0, yRow, 'o', 'MarkerSize', 8, ...
            'MarkerEdgeColor', col, 'MarkerFaceColor', faces{i}, 'LineWidth', 1.2);
        hText(i) = text(axO, 0, yRow, obsLabels{i}, 'FontSize', fontSize, ...
            'VerticalAlignment', 'middle', 'Color', [0.15 0.15 0.15]);
        wText(i) = hText(i).Extent(3);          % 文字宽度（figure 归一化）
    end

    blk = 2 * (segL + gapT) + sum(wText) + gapM;    % 整排总宽
    if strcmpi(alignMode, 'center')
        x0 = spanRect(1) + (spanRect(3) - blk) / 2;
    else
        x0 = spanRect(1);
    end
    for i = 1:2
        set(hLine(i), 'XData', [x0, x0 + segL], 'YData', [yRow, yRow]);
        set(hMark(i), 'XData', x0 + segL / 2, 'YData', yRow);
        set(hText(i), 'Position', [x0 + segL + gapT, yRow, 0]);
        x0 = x0 + segL + gapT + wText(i) + gapM;
    end
end

% ------------------------------------------------------------------------
function addArrowFigureLegend(fig, natColors, modelLabels, obsLabels, spanRect, ...
    top1, top2, keyLabels, fontSize)
%ADDARROWFIGURELEGEND  箭头图的图例：
%   第一排 = 族裔颜色（legend）+ 一支说明箭头 "Preference → Healthy"（手绘）
%   第二排 = 观察者线型（虚线 = Asian，实线 = African）
%   两排都在 spanRect 宽度内水平居中。
    axO = axes(fig, 'Position', [0 0 1 1], 'Visible', 'off', ...
        'XLim', [0 1], 'YLim', [0 1]);
    hold(axO, 'on');

    lg1 = drawNationLegend(axO, natColors, modelLabels, fontSize);
    drawnow;
    p1 = lg1.Position;

    % 说明箭头先量宽度（临时 text），再和 legend 拼成一组一起居中
    wKey = measureArrowKey(axO, keyLabels, fontSize);
    gap  = 0.035;
    total = p1(3) + gap + wKey;
    x0    = spanRect(1) + (spanRect(3) - total) / 2;
    lg1.Position = [x0, top1 - p1(4), p1(3), p1(4)];

    yMid = lg1.Position(2) + p1(4) / 2;
    drawArrowKey(axO, fig, keyLabels, x0 + p1(3) + gap, yMid, fontSize);

    % 第二排：观察者线型，在整幅宽度内居中
    drawObsRow(axO, obsLabels, spanRect, top2, fontSize, 'center');
end

% ------------------------------------------------------------------------
function w = measureArrowKey(axO, keyLabels, fontSize)
%MEASUREARROWKEY  量出 "文字 + 箭头 + 文字" 这组说明的总宽（figure 归一化）
    gapL = 0.010;
    gapR = 0.010;
    segL = 0.045;
    t1 = text(axO, 0, 0, keyLabels{1}, 'FontSize', fontSize, 'Visible', 'off');
    t2 = text(axO, 0, 0, keyLabels{2}, 'FontSize', fontSize, 'Visible', 'off');
    w1 = t1.Extent(3);
    w2 = t2.Extent(3);
    delete(t1); delete(t2);
    w = w1 + gapL + segL + gapR + w2;
end

% ------------------------------------------------------------------------
function drawArrowKey(axO, fig, keyLabels, xLeft, yMid, fontSize)
%DRAWARROWKEY  画一支图例用的说明箭头：左端文字 = 起点含义，箭尖文字 = 终点含义
    gapL = 0.010;
    gapR = 0.010;
    segL = 0.045;
    col  = [0.25 0.25 0.25];

    t1 = text(axO, 0, yMid, keyLabels{1}, 'FontSize', fontSize, ...
        'VerticalAlignment', 'middle', 'HorizontalAlignment', 'right', ...
        'Color', col);
    w1 = t1.Extent(3);
    t2 = text(axO, 0, yMid, keyLabels{2}, 'FontSize', fontSize, ...
        'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left', ...
        'Color', col);

    xa = xLeft + w1 + gapL;          % 箭尾
    xb = xa + segL;                  % 箭尖
    set(t1, 'Position', [xa - gapL, yMid, 0]);
    set(t2, 'Position', [xb + gapR, yMid, 0]);

    plot(axO, [xa, xb], [yMid, yMid], '-', 'Color', col, 'LineWidth', 1.4);
    hx = 9 / fig.Position(3);
    hy = 9 / fig.Position(4);
    patch(axO, [xb, xb - hx, xb - hx], [yMid, yMid + hy * 0.5, yMid - hy * 0.5], ...
        col, 'EdgeColor', 'none');
end

% ------------------------------------------------------------------------
function drawArrowPanel(ax, parPref1, parPref2, parHeal1, parHeal2, natColors, lims, ...
    fontSize, tickStep)
%DRAWARROWPANEL  图 2 的面板：只画 Preference 椭圆，再用箭头指向 Healthy 圆心
%   parPref1/2 : Asian / African 观察者在 Preference 上的椭圆参数（画椭圆 + 作箭头起点）
%   parHeal1/2 : 同两个观察者在 Healthy 上的椭圆参数（只取圆心作箭尖，不画椭圆）
%   tickStep   : x / y 共用的刻度间隔
    nNat  = size(parPref1, 1);
    range = lims(2) - lims(1);
    headLen = 0.025 * range;         % 箭头头部尺寸（圆心位移一般只有 1~4，头部不能太大）

    % ---- 45° 等色相参考线 ----
    xLine = linspace(lims(1), lims(2), 100);
    plot(ax, xLine, xLine, 'Color', [0.4 0.4 0.4], 'LineStyle', '--');
    text(ax, lims(2) - 0.02 * range, lims(2) - 0.03 * range, '45°', ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', ...
        'FontSize', fontSize, 'Color', [0.3 0.3 0.3]);

    for iNat = 1:nNat
        col = natColors(iNat, :);

        % Preference 椭圆：Asian 虚线空心、African 实线实心
        [x1, y1] = ellipsePoints50(parPref1(iNat, :), 361);
        if ~isempty(x1)
            plot(ax, x1, y1, 'Color', col, 'LineStyle', '--', 'LineWidth', 1.6);
            plot(ax, parPref1(iNat, 4), parPref1(iNat, 5), 'o', 'MarkerSize', 6, ...
                'MarkerEdgeColor', col, 'MarkerFaceColor', 'none', 'LineWidth', 1.4);
        end
        [x2, y2] = ellipsePoints50(parPref2(iNat, :), 361);
        if ~isempty(x2)
            plot(ax, x2, y2, 'Color', col, 'LineStyle', '-', 'LineWidth', 1.6);
            plot(ax, parPref2(iNat, 4), parPref2(iNat, 5), 'o', 'MarkerSize', 6, ...
                'MarkerEdgeColor', col, 'MarkerFaceColor', col, 'LineWidth', 1.4);
        end

        % 箭头：Preference 圆心 -> Healthy 圆心
        drawArrow(ax, parPref1(iNat, 4:5), parHeal1(iNat, 4:5), col, headLen, '--');
        drawArrow(ax, parPref2(iNat, 4:5), parHeal2(iNat, 4:5), col, headLen, '-');
    end

    axis(ax, 'equal');
    xlim(ax, lims);
    ylim(ax, lims);
    ticks = lims(1):tickStep:lims(2);
    ax.XTick = ticks;                    % x / y 刻度间隔强制一致
    ax.YTick = ticks;
    ax.XAxis.FontSize = fontSize;
    ax.YAxis.FontSize = fontSize;
    xlabel(ax, '{\ita}^{*}', 'Interpreter', 'tex', 'FontSize', fontSize);
    ylabel(ax, '{\itb}^{*}', 'Interpreter', 'tex', 'FontSize', fontSize);
    box(ax, 'on');
    grid(ax, 'on');
end

% ------------------------------------------------------------------------
function drawArrow(ax, p0, p1, col, headLen, lineStyle)
%DRAWARROW  画一支箭头，头部尺寸固定（不随箭头长度缩放）
%   p0 : 起点（Preference 圆心）  p1 : 箭尖（Healthy 圆心）
    v = p1 - p0;
    L = norm(v);
    if L < 1e-6, return; end

    u   = v / L;                    % 单位方向
    nrm = [-u(2), u(1)];            % 法向
    pBase = p1 - u * headLen;       % 箭头底面中点
    if dot(pBase - p0, u) < 0       % 箭头比头部还短：轴只留一小段
        pBase = p0 + u * (0.35 * L);
    end

    plot(ax, [p0(1), pBase(1)], [p0(2), pBase(2)], 'Color', col, ...
        'LineStyle', lineStyle, 'LineWidth', 2.0);

    hw  = 0.40 * headLen;           % 半宽
    tri = [p1; pBase + nrm * hw; pBase - nrm * hw];
    patch(ax, tri(:, 1), tri(:, 2), col, 'EdgeColor', 'none');
end
