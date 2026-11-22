% ========================================================================
% scatter_compare_cie.m   （本实验偏好圆心 vs 文献肤色中心，CIE a*b* 平面）
%
% 作用:
%   把 scatter_nation_AS_AF.m 里"4 个刺激模特族裔的椭圆全画在一张图"改成
%   一张图 = 1×4 横排四个子图（每个子图 = 一个 {model nation}），每个子图上叠加：
%     (1) 本实验该 model nation 的 50% 等偏好椭圆 + 圆心（五角星）
%         phase1（观察者 = Asian）  : 颜色 = Asian 观察者
%         phase2（观察者 = {obsNationP2}）: 颜色 = {obsNationP2} 观察者
%     (2) Peng et al. 的肤色中心（方形）
%     (3) Cao  et al. 的肤色中心（三角形）
%   只画 Preference：Peng / Cao 两个库都没有 Healthy 的 fit 结果。
%
% 数据来源（完整绝对路径）:
%   本实验 : 与 scatter_nation_AS_AF.m 完全相同
%            phase1 = <P1_ROOT>\B_data_analysis\analyze\AnalyseResults_p\efit_p\unscaled\
%                     {subject}\non_model\{attr}\labNscore\labNscore_group{subject}{scene}.mat
%            phase2 = D:\work\VIVOSkin_phase2\analyze\AnalyseResults_p\efit_p\unscaled\
%                     {obsNationP2}\{subject}\non_model\{attr}\labNscore\labNscore_group{subject}{scene}.mat
%            每个 model nation = 该族裔全部受试者在该场景的 33 个刺激点合并后重新拟合，
%            50% 等值线圆心 (a*, b*) = par(4:5)（与 AS_AF 版本同一套拟合函数）
%   Peng et al. : D:\work\VIVOSkinExpe\PeggySkinBackup\ZJU_entire_skin\ZJU_skin_database\
%                 B_Tables\Summer_table.mat          (fit_table, 20 行)
%   Cao  et al. : 同目录 Cherry_table.mat            (fit_table, 48 行)
%                 取 model_ethnicity = {model nation} 且 observer_type = {observer nation}
%                 的全部行，对 lab_center(1×3 = [L a b]) 求简单平均，取 a*b* 作图
%
% 编码约定:
%   颜色 = 观察者族裔。Asian / Caucasian / South Asian / African 四种观察者族裔
%          分别使用 scatter_nation_AS_AF.m 中 model nation 为
%          Asian / Caucasian / South Asian / African 时的颜色（同一套 hsv 取色），
%          因此两套图的颜色含义可以互相对照。
%   形状 = 数据来源。五角星 = 本实验（This research），
%          方形 = Summer_table.mat（Peng et al.），三角形 = Cherry_table.mat（Cao et al.）
%   族裔别名: Oriental*（含 Oriental(CY) / Oriental(YO) / Oriental(YY)）与 Chinese
%          都归为 Asian；匹配大小写不敏感。无法识别的取值（如
%          weighted(o:30,s:30,c:31)，是 o/s/c 加权合成观察者，不是族裔）直接跳过。
%
% 重要数据处理（与 naive 平均的差别）:
%   Cherry_table.mat 里有若干行的 lab_center 是椭圆拟合崩掉后的假圆心
%   （a*≈0 / b*≈0，甚至有 a* = 124, b* = 360）。这些行若参与平均会把平均值
%   和坐标范围一起带飞。因此取平均前用 LAB_KEEP 的健康肤色范围做一次物理量级
%   过滤，被剔除的行数会打印到终端（scatter_compare_cie 只做过滤，不改表）。
%
% 输出（每个属性一张图）:
%   ellip_pic_p\efit_p\nation2\rela\cmp_cie\{iOr}\COMPARE_CIE_{scene}_{attr}.jpg
% ========================================================================
close all;
clc;
clear;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
addpath(fullfile(thisDir, 'utils'));

C = p2_config();

%% ---------- 1. 开关 ----------
iOr          = "i";            % 本脚本只支持 i 组（21 个光源）
SCENE        = "hd65";         % 场景名（C.PICNAMES_I 之一）
obsNationP2  = "AF";           % phase2 观察者族裔
obsType      = "non_model";    % 观察者类型
ATTR_LIST    = 1;              % 只画 Preference：Peng / Cao 两个库都没有 Healthy 数据
PANEL_TAGS   = {'(a)', '(b)', '(c)', '(d)'};   % 四个子图（按 AS/CA/SA/AF 顺序）的标号
SEED         = 0;              % 拟合初值随机，固定种子保证可复现
nPtEllipse   = 361;            % 椭圆采样点数
FONT_SIZE    = 15;             % 全局字号（上限值，面板变小时会自动缩）
TICK_STEP    = 5;              % x / y 刻度间隔（两个方向强制一致）
LEGEND_ALIGN = 'center';       % 'center'（块宽度内居中） | 'left'（左对齐）
% 椭圆线型：颜色已经表示观察者族裔，这里两条都用实线；
% 若想回到 scatter_nation_AS_AF.m 的"虚线 = phase1 / 实线 = phase2"，改成 {'--','-'}
ELLIPSE_LS   = {'-', '-'};
% marker 尺寸（pt）。五角星 = 本实验椭圆圆心，方形 = Peng，三角形 = Cao
MK_STAR        = 6.6;          % 原 11 × 0.6
MK_SQ          = 6.3;          % 原 9 × 0.7
MK_TRI         = 5.4;          % 原 9 × 0.6
srcMarkerSize  = [MK_SQ, MK_TRI];   % 与 srcMarkers 一一对应

% 文献表（ZJU 皮肤数据库）
SUMMER_FILE = ['D:\work\VIVOSkinExpe\PeggySkinBackup\ZJU_entire_skin\' ...
    'ZJU_skin_database\B_Tables\Summer_table.mat'];
CHERRY_FILE = ['D:\work\VIVOSkinExpe\PeggySkinBackup\ZJU_entire_skin\' ...
    'ZJU_skin_database\B_Tables\Cherry_table.mat'];

% lab_center 的合理量级（CIE L*a*b*）。超出即判为拟合退化行，取平均前剔除。
LAB_KEEP = struct('L', [20, 90], 'a', [5, 35], 'b', [5, 40]);

if iOr ~= "i"
    error('scatter_compare_cie: 当前只支持 i 组（21 个光源）');
end
iPara = find(strcmp(C.PICNAMES_I, SCENE), 1);
if isempty(iPara)
    error('scatter_compare_cie: 场景 "%s" 不在 C.PICNAMES_I 里', char(SCENE));
end
nAttr = numel(ATTR_LIST);
nNat  = numel(C.STIM_NATIONS);
rng(SEED);

% 观察者族裔下标：phase1 的观察者全是 Asian，phase2 由 obsNationP2 决定
obsIdxP1 = nationIndex('Asian');
obsIdxP2 = nationIndex(obsNationP2);
if isnan(obsIdxP2)
    error('scatter_compare_cie: obsNationP2 = "%s" 无法映射到族裔', char(obsNationP2));
end

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
    fprintf('\n[CIE] ===== %s (%s) =====\n', char(attrSerial), char(SCENE));

    for iNat = 1:nNat
        models = C.STIM_MODELS{iNat};

        % ---- phase1（Asian 观察者）----
        [parP1(iNat, :, iA), statP1.r(iNat, iA), ...
            statP1.nDot(iNat, iA), statP1.nSub(iNat, iA)] = ...
            fitNationDot(models, iOr, P1_ANALYSE, '', obsType, attrSerial, ...
            char(SCENE), iPara, P1_WHITE, XYZw_LUT1, wd65, SEED);

        % ---- phase2（obsNationP2 观察者）----
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
    end
end

%% ---------- 4. 两个文献库：按 (model nation, observer nation) 求 lab_center 平均 ----------
srcFiles   = {SUMMER_FILE, CHERRY_FILE};
srcNames   = {'Peng et al.', 'Cao et al.'};
srcMarkers = {'s', '^'};           % 方形 / 三角形
nSrc   = numel(srcFiles);
litAB  = cell(1, nSrc);            % nModel × nObs × 2，存 [a* b*]
litN   = cell(1, nSrc);            % 每个格子参与平均的行数

for k = 1:nSrc
    [litAB{k}, litN{k}, detail, dropCnt] = tableNationMeans(srcFiles{k}, LAB_KEEP, ...
        C.STIM_NATION_NAMES);
    nKeep = sum(litN{k}(:));
    nDrop = sum(dropCnt(:));
    fprintf('\n[CIE] %-12s : 命中 %d 行（保留 %d 行，剔除 %d 行拟合退化）\n', ...
        srcNames{k}, nKeep + nDrop, nKeep, nDrop);
end

% 图例第二排：形状 = 数据来源。本实验排在最前，五角星
legNames   = [{'This research'}, srcNames];
legMarkers = [{'p'}, srcMarkers];
legSizes   = [MK_STAR, srcMarkerSize];

%% ---------- 5. 统一轴范围（4 个子图 × 所有来源共用） ----------
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
for k = 1:nSrc
    ab = litAB{k};
    allX = [allX, reshape(ab(:, :, 1), 1, [])];   %#ok<AGROW>
    allY = [allY, reshape(ab(:, :, 2), 1, [])];   %#ok<AGROW>
end
allX = allX(isfinite(allX));
allY = allY(isfinite(allY));
if isempty(allX)
    error('scatter_compare_cie: 没有任何可用的椭圆或平均点');
end
lims = [max(0, floor(min([allX, allY]) - 1)), ceil(max([allX, allY]) + 1)];

%% ---------- 6. 配色（一个观察者族裔一个颜色，取法与 AS_AF 版本一致） ----------
hue       = linspace(0, 1, nNat + 1); hue = hue(1:end-1);
natColors = hsv2rgb([hue', 0.80 * ones(nNat, 1), 0.85 * ones(nNat, 1)]);

colP1 = natColors(obsIdxP1, :);     % Asian 观察者
colP2 = natColors(obsIdxP2, :);     % obsNationP2 观察者

%% ---------- 7. 出图：每个属性一张 1×4 横排拼合图 ----------
saveFolder = fullfile(C.PIC_ROOT, C.Dtype, 'nation2', 'rela', 'cmp_cie', char(iOr));
if ~exist(saveFolder, 'dir'), mkdir(saveFolder); end

obsLabels = cell(1, nNat);
for j = 1:nNat
    obsLabels{j} = sprintf('%s observers', C.STIM_NATION_NAMES(j));
end

outFiles = cell(1, nAttr);
for iA = 1:nAttr
    attr      = ATTR_LIST(iA);
    attrName  = char(C.ATTRIBUTE_NAMES(attr));
    attrSerial = strcat(sprintf('%02d', attr), C.ATTRIBUTE_NAMES(attr));

    % 1×4 横排：窗口做成长条形，子图才不会被压小
    h = figure('Color', 'white', 'Position', [30, 150, 1250, 470]);
    drawnow;
    sz = h.Position(3:4);          % 实际窗口像素（小屏会被系统压，必须按实际算）

    % 字号跟着面板大小走：面板小的时候字号不缩就会互相压
    S_GUESS = floor((0.96 * sz(1) - 3 * round(0.045 * sz(1))) / 4);
    fs = max(8, min(FONT_SIZE, round(FONT_SIZE * S_GUESS / 380)));

    % 下方预留区按"像素需求"算：xlabel + 两排图例，不随窗口比例乱变
    EX_PX   = round(3.2 * fs) + 14;                  % xlabel 占位高度
    ROW_H   = round(2.4 * fs) + 8;                   % 单排图例高度
    GAP_R   = round(1.2 * fs);                       % 排间距
    BOT_PX  = max(round(0.22 * sz(2)), EX_PX + 2 * ROW_H + GAP_R + 6);
    TOP_PX  = round(2.8 * fs) + 10;                  % 顶部只留面板标题（没有总标题）
    GX_PX   = round(5.2 * fs);                       % 列间距（要放得下 ylabel + 刻度）

    % 四个子图都按像素算成正方形，axis equal 才不会把 PlotBox 缩进去
    availH  = sz(2) - TOP_PX - BOT_PX;
    availW  = floor((0.96 * sz(1) - 3 * GX_PX) / 4);
    S_PLOT  = max(min(availH, availW), 100);
    BLK_W   = 4 * S_PLOT + 3 * GX_PX;
    LEFT_PX = round((sz(1) - BLK_W) / 2);
    BOT_PX  = BOT_PX + max(0, round((availH - S_PLOT) / 2));   % 竖向居中
    if BOT_PX + S_PLOT > sz(2) - TOP_PX                        % 兜底：别顶出画布
        BOT_PX = sz(2) - TOP_PX - S_PLOT;
    end

    axList = gobjects(1, nNat);
    for iNat = 1:nNat
        xPx = LEFT_PX + (iNat - 1) * (S_PLOT + GX_PX);
        axList(iNat) = axes(h, 'Position', [xPx / sz(1), BOT_PX / sz(2), ...
            S_PLOT / sz(1), S_PLOT / sz(2)]);
        hold(axList(iNat), 'on');
        drawComparePanel(axList(iNat), parP1(iNat, :, iA), parP2(iNat, :, iA), ...
            colP1, colP2, ELLIPSE_LS, MK_STAR, litAB, srcMarkers, srcMarkerSize, ...
            natColors, iNat, lims, ...
            sprintf('%s models', char(C.STIM_NATION_NAMES(iNat))), ...
            PANEL_TAGS{iNat}, fs, TICK_STEP);
    end

    % 图例两排都锚在子图下边缘往下依次排，保证不会撞到 xlabel
    spanRect = [LEFT_PX / sz(1), 0, BLK_W / sz(1), 0];
    y1 = BOT_PX - EX_PX - GAP_R;                          % 第一排顶边
    y2 = y1 - ROW_H - GAP_R - ROW_H / 2;                  % 第二排中心线
    addCompareLegends(h, natColors, obsLabels, legNames, legMarkers, legSizes, ...
        spanRect, y1 / sz(2), y2 / sz(2), [], '', fs, LEGEND_ALIGN);

    outFiles{iA} = fullfile(saveFolder, ...
        sprintf('COMPARE_CIE_%s_%s.jpg', char(SCENE), char(attrSerial)));
    % 用 print 而不是 exportgraphics：图例在坐标框外，exportgraphics 的紧包围盒
    % 会改画布长宽比，归一化坐标被压缩后子图与图例就错位。
    set(h, 'PaperPositionMode', 'auto');
    print(h, outFiles{iA}, '-djpeg', '-r300');
    close(h);
end

%% ---------- 8. 终端小结 ----------
fprintf('\n[CIE] 文献库平均 lab_center 的 a*b*（n = 参与平均的行数，- = 没有该组合）\n');
for k = 1:nSrc
    fprintf('\n  %s（%s）\n', srcNames{k}, srcFiles{k});
    fprintf('  %-16s', 'model \ observer');
    for j = 1:nNat
        fprintf('%-20s', char(C.STIM_NATION_NAMES(j)));
    end
    fprintf('\n');
    for iNat = 1:nNat
        fprintf('  %-16s', char(C.STIM_NATION_NAMES(iNat)));
        for j = 1:nNat
            ab = litAB{k}(iNat, j, :);
            if all(isfinite(ab))
                fprintf('(%5.2f,%5.2f) n=%-2d ', ab(1), ab(2), litN{k}(iNat, j));
            else
                fprintf('%-20s', '-');
            end
        end
        fprintf('\n');
    end
end

fprintf('\n[CIE] 出图:\n');
for iA = 1:nAttr
    fprintf('  %s\n', outFiles{iA});
end

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
function lab = scaleLabToScene(lab, XYZw_LUT, Yscene, wd65)
%SCALELABTOSCENE  相对亮度缩放（与 phase1 rela / phase2 'scale' 完全一致）
%   1) 把 Lab 当作 LUT 参考白（Y = XYZw_LUT(2)）下的坐标转回 XYZ；
%   2) 再用"场景白点（Y = Yscene）"重新转成 Lab。
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
function [abMean, nKeep, detail, dropCnt] = tableNationMeans(matFile, keep, nationNames)
%TABLENATIONMEANS  按 (model_ethnicity, observer_type) 分组求 lab_center 平均
%   matFile     : fit_table 所在 .mat（ZJU 皮肤数据库 B_Tables）
%   keep        : lab_center 的合理范围 struct('L','a','b' 各为 [lo hi])
%   nationNames : 族裔名（顺序 = 下标 1..4：Asian / Caucasian / South Asian / African）
%   abMean      : nNat × nNat × 2，[model nation, observer nation] 的平均 a*b*
%   nKeep       : 每个格子参与平均的行数（0 = 没有该组合）
%   detail      : 每个非空格子的明细（平均 lab、保留行数、剔除行数）
%   dropCnt     : 每个格子被判为拟合退化而剔除的行数
    nNat   = numel(nationNames);
    abMean = nan(nNat, nNat, 2);
    nKeep  = zeros(nNat, nNat);
    detail = struct('modelIdx', {}, 'obsIdx', {}, 'lab', {}, 'nKeep', {}, 'nDrop', {});

    if ~isfile(matFile)
        error('scatter_compare_cie: 找不到文件 %s', matFile);
    end
    S  = load(matFile);
    fn = fieldnames(S);
    T  = [];
    for i = 1:numel(fn)
        if istable(S.(fn{i})), T = S.(fn{i}); break; end
    end
    if isempty(T)
        error('scatter_compare_cie: %s 里没有 table 变量', matFile);
    end
    need = {'model_ethnicity', 'observer_type', 'lab_center'};
    lack = setdiff(need, T.Properties.VariableNames);
    if ~isempty(lack)
        error('scatter_compare_cie: %s 缺少列 %s', matFile, strjoin(lack, ', '));
    end

    me = toTextColumn(T.model_ethnicity);
    ot = toTextColumn(T.observer_type);
    lc = T.lab_center;
    if ~iscell(lc), lc = num2cell(lc, 2); end        % 兜底：数值矩阵 → cell

    bucket  = cell(nNat, nNat);      % 每个格子累积多行 [L a b]
    dropCnt = zeros(nNat, nNat);
    for i = 1:height(T)
        iM = nationIndex(me{i});
        iO = nationIndex(ot{i});
        if isnan(iM) || isnan(iO), continue; end     % 如 weighted(...) 不是族裔，跳过
        v = lc{i};
        if isempty(v), continue; end
        v = double(v(:)');
        if numel(v) ~= 3, continue; end
        if labPlausible(v, keep)
            bucket{iM, iO} = [bucket{iM, iO}; v];    %#ok<AGROW>
        else
            dropCnt(iM, iO) = dropCnt(iM, iO) + 1;
        end
    end

    for iM = 1:nNat
        for iO = 1:nNat
            b = bucket{iM, iO};
            nKeep(iM, iO) = size(b, 1);
            if isempty(b), continue; end
            m = mean(b, 1);
            abMean(iM, iO, :) = m(2:3);
            detail(end+1) = struct('modelIdx', iM, 'obsIdx', iO, 'lab', m, ...
                'nKeep', size(b, 1), 'nDrop', dropCnt(iM, iO));   %#ok<AGROW>
        end
    end
end

% ------------------------------------------------------------------------
function c = toTextColumn(x)
%TOTEXTCOLUMN  把 table 的文本列统一成 1×N cellstr（可能是 cell / string / char）
    if isstring(x)
        c = cellstr(x);
    elseif iscell(x)
        c = cellfun(@(v) char(string(v)), x, 'UniformOutput', false);
    elseif ischar(x)
        c = cellstr(x);
    else
        c = arrayfun(@(v) char(string(v)), x, 'UniformOutput', false);
    end
    c = c(:)';
end

% ------------------------------------------------------------------------
function idx = nationIndex(txt)
%NATIONINDEX  把族裔文本映射到下标 1..4 = Asian / Caucasian / South Asian / African
%   规则: Oriental*（含 Oriental(CY)/(YO)/(YY)）与 Chinese 都算 Asian；
%         大小写不敏感；无法识别（如 weighted(o:30,s:30,c:31)）返回 NaN
    idx = NaN;
    if isempty(txt), return; end
    s = lower(strtrim(char(txt)));
    s = strrep(s, '_', ' ');
    if startsWith(s, 'oriental') || startsWith(s, 'chinese') ...
            || any(strcmp(s, {'asian', 'as'}))
        idx = 1;
    elseif startsWith(s, 'caucas') || any(strcmp(s, {'ca', 'cauc'}))
        idx = 2;
    elseif any(strcmp(s, {'south asian', 'southasian', 'sa'}))
        idx = 3;
    elseif any(strcmp(s, {'african', 'af'}))
        idx = 4;
    end
end

% ------------------------------------------------------------------------
function tf = labPlausible(lab, keep)
%LABPLAUSIBLE  判断一个 lab_center 是否落在健康肤色的物理量级内
%   数据库里少数行的椭圆拟合崩掉，会给出 a*≈0 / b*≈0 甚至 a*>100 的假圆心，
%   这些行必须先剔除，否则平均值和坐标范围都会失真。
    tf = all(isfinite(lab)) ...
        && lab(1) >= keep.L(1) && lab(1) <= keep.L(2) ...
        && lab(2) >= keep.a(1) && lab(2) <= keep.a(2) ...
        && lab(3) >= keep.b(1) && lab(3) <= keep.b(2);
end

% ------------------------------------------------------------------------
function c = darken(c, f)
%DARKEN  同一色相压暗，用作 marker 描边色，保证填充色仍是族裔颜色
    if nargin < 2, f = 0.45; end
    c = max(0, min(1, c * f));
end

% ------------------------------------------------------------------------
function drawComparePanel(ax, parP1, parP2, colP1, colP2, lsPair, mkStar, litAB, ...
    litMarkers, litSizes, natColors, iModel, lims, panelTitle, tag, fontSize, tickStep)
%DRAWCOMPAREPANEL  画一个 model nation 子图
%   parP1 / parP2 : 本实验 Asian / phase2 观察者在该 model nation 上的椭圆参数（1×6）
%   lsPair        : 两条椭圆的线型 {'-','-'}（颜色已经区分观察者，线型可选）
%   mkStar        : 椭圆圆心（五角星）的 marker 尺寸
%   litAB         : cell，每个来源一个 nModel×nObs×2 的 [a* b*] 平均点
%   litSizes      : 各来源的 marker 尺寸（与 litMarkers 一一对应）
%   natColors     : 观察者族裔配色（文献点的颜色由 observer nation 决定）
%   iModel        : 当前子图对应的 model nation 下标
    nObs  = size(natColors, 1);
    range = lims(2) - lims(1);

    % ---- 45° 等色相参考线 ----
    xLine = linspace(lims(1), lims(2), 100);
    plot(ax, xLine, xLine, 'Color', [0.4 0.4 0.4], 'LineStyle', '--');
    text(ax, lims(2) - 0.02 * range, lims(2) - 0.03 * range, '45°', ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', ...
        'FontSize', fontSize - 2, 'Color', [0.3 0.3 0.3]);

    % ---- 本实验：50% 等偏好椭圆 + 圆心（五角星）----
    parSet = {parP1, colP1, lsPair{1}; parP2, colP2, lsPair{2}};
    for p = 1:2
        par = parSet{p, 1};
        col = parSet{p, 2};
        [x, y] = ellipsePoints50(par, 361);
        if ~isempty(x)
            plot(ax, x, y, 'Color', col, 'LineStyle', parSet{p, 3}, 'LineWidth', 1.8);
        end
        if numel(par) >= 5 && all(isfinite(par(4:5)))
            plot(ax, par(4), par(5), 'p', 'MarkerSize', mkStar, ...
                'MarkerEdgeColor', 'none', 'MarkerFaceColor', col);
        end
    end

    % ---- 文献：平均 lab_center 的 a*b*（方形 / 三角形，颜色 = observer nation）----
    for k = 1:numel(litAB)
        abMat = litAB{k};
        for j = 1:nObs
            ab = abMat(iModel, j, :);
            if all(isfinite(ab))
                plot(ax, ab(1), ab(2), litMarkers{k}, 'MarkerSize', litSizes(k), ...
                    'MarkerEdgeColor', darken(natColors(j, :)), ...
                    'MarkerFaceColor', natColors(j, :), 'LineWidth', 0.8);
            end
        end
    end

    % ---- 坐标轴 ----
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
    title(ax, panelTitle, 'FontSize', fontSize, 'FontWeight', 'normal');

    % ---- 右下角 (a) / (b) / (c) / (d) ----
    text(ax, lims(2) - 0.03 * range, lims(1) + 0.03 * range, tag, ...
        'FontSize', fontSize, 'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'bottom', 'Color', [0.15 0.15 0.15]);
end

% ------------------------------------------------------------------------
function addCompareLegends(fig, natColors, obsLabels, srcNames, srcMarkers, srcSizes, ...
    spanRect, top1, top2, yNote, noteStr, fontSize, alignMode)
%ADDCOMPARELEGENDS  三排说明（都在 spanRect 宽度内居中 / 左对齐）
%   第一排: 观察者族裔颜色（legend）
%   第二排: 数据来源形状（手绘 marker + 文字），marker 尺寸与图内一致
%   第三排: 椭圆含义的灰色小字
%   注意: 同一个 axes 只能有一个 legend 对象，所以第二排不用 legend，改为手绘。
    axO = axes(fig, 'Position', [0 0 1 1], 'Visible', 'off', ...
        'XLim', [0 1], 'YLim', [0 1]);
    hold(axO, 'on');

    % ---- 第一排：观察者族裔颜色 ----
    nNat = size(natColors, 1);
    hNat = gobjects(1, nNat);
    for i = 1:nNat
        hNat(i) = plot(axO, nan, nan, 's', 'MarkerSize', 12, ...
            'MarkerEdgeColor', 'none', 'MarkerFaceColor', natColors(i, :), ...
            'LineStyle', 'none');
    end
    lg = legend(axO, hNat, obsLabels, 'Orientation', 'horizontal', ...
        'FontSize', fontSize, 'Box', 'off');
    lg.AutoUpdate    = 'off';
    lg.ItemTokenSize = [18, 10];
    drawnow;

    p1 = lg.Position;
    if strcmpi(alignMode, 'center')
        xLegend = spanRect(1) + (spanRect(3) - p1(3)) / 2;
    else
        xLegend = spanRect(1);
    end
    lg.Position = [xLegend, top1 - p1(4), p1(3), p1(4)];

    % ---- 第二排：数据来源形状 ----
    drawMarkerRow(axO, srcNames, srcMarkers, srcSizes, spanRect, top2, fontSize, ...
        alignMode, fig.Position(3));

    % ---- 第三排：椭圆含义 ----
    if ~isempty(noteStr)
        text(axO, spanRect(1) + spanRect(3) / 2, yNote, noteStr, ...
            'FontSize', fontSize - 2, 'Color', [0.35 0.35 0.35], ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle');
    end
end

% ------------------------------------------------------------------------
function drawMarkerRow(axO, names, markers, sizes, spanRect, yRow, fontSize, alignMode, figW)
%DRAWMARKERROW  形状说明行：marker + 文字，整排在 spanRect 内居中 / 左对齐
%   sizes : 每个 marker 的尺寸（与图内一致，保证图例和图上看起来一样大）
    col  = [0.3 0.3 0.3];
    n    = numel(names);
    gapT = 0.010;                    % marker 与文字间距
    gapM = 0.050;                    % 两组之间的间距
    mk   = 1.4 * cellsizes_px(sizes) / figW;    % 每个 marker 的占位宽度（归一化）

    hM   = gobjects(1, n);
    hT   = gobjects(1, n);
    wT   = zeros(1, n);
    for i = 1:n
        hM(i) = plot(axO, 0, yRow, markers{i}, 'MarkerSize', sizes(i), ...
            'MarkerEdgeColor', col, 'MarkerFaceColor', col, 'LineWidth', 0.8);
        hT(i) = text(axO, 0, yRow, names{i}, 'FontSize', fontSize, ...
            'VerticalAlignment', 'middle', 'Color', [0.15 0.15 0.15]);
        wT(i) = hT(i).Extent(3);     % 文字宽度（figure 归一化）
    end

    blk = sum(mk) + sum(wT) + n * gapT + (n - 1) * gapM;
    if strcmpi(alignMode, 'center')
        x0 = spanRect(1) + (spanRect(3) - blk) / 2;
    else
        x0 = spanRect(1);
    end
    for i = 1:n
        set(hM(i), 'XData', x0 + mk(i) / 2, 'YData', yRow);
        set(hT(i), 'Position', [x0 + mk(i) + gapT, yRow, 0]);
        x0 = x0 + mk(i) + gapT + wT(i) + gapM;
    end
end

% ------------------------------------------------------------------------
function px = cellsizes_px(sizes)
%CELLSIZES_PX  marker 尺寸（pt 数）→ 屏幕像素近似值（1 pt ≈ 1.33 px，再留 40% 余量）
    px = 1.33 * sizes;
end
