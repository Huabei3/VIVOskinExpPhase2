% ========================================================================
% scatter_scene_AS_AF.m   （phase1 × phase2 对比版）
%
% 作用:
%   把 phase1（观察者 = Asian）与 phase2（观察者 = African）拟合出的 Preference
%   偏好中心画在同一张 a*-b* 平面上，按刺激模特族裔 AS / CA / SA / AF 分 4 个
%   面板（同时另存 4 张单图）。每个场景画一支箭头：起点 = Asian observers
%   （标场景号），箭尖 = African observers，箭头长度即两个观察者群体把偏好中心
%   推开的距离。
%   i 组的 hd65（D65 标准光源、实验室）作为 indoor/outdoor/night 之外的第 4 类
%   场景，用黑色单独画出：同样有箭头，但起点只画一个黑点、不标数字。
%
% 数据来源（完整绝对路径）:
%   phase1 : <P1_ROOT>\B_data_analysis\analyze\ellip_pic_p\efit_p\data_reshaped_r.mat
%            = D:\work\VIVOskinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\
%              B_data_analysis\analyze\ellip_pic_p\efit_p\data_reshaped_r.mat
%            （phase1 C_F_12 的保存结果，lab_fit_reshaped{1,nation} = non_model 观察者）
%   phase2 : D:\work\VIVOSkin_phase2\analyze\AnalyseResults_p\efit_p\unscaled\
%            AF\{subject}\non_model\{attr}\ellipPara\fitRes.mat
%            （经 p2_load_labfit 组装，lightness = 'scale' 即 rela 相对亮度缩放）
%
% 标记约定:
%   颜色 : 每个场景一种颜色，同族场景共用色相，只改明度/色相小偏移
%          室内 1-6 红 / 室外草地 7-12 绿 / 夜景 13-14 蓝 / i 组 hd65 黑
%   箭头 : 起点 = Asian observers，箭尖 = African observers，所有箭头共用同一个头部尺寸
%   编号 : 实景 1..14 只在箭头起点标数字；hd65 起点画点
%   图例 : 一排 —— 四类场景色 + 一条 "Asian observers -> African observers" 说明箭头
%
% 输出:
%   ellip_pic_p\efit_p\scene2\rela\cmp_p1_AF\{iOr}\0X{STIM}_L.jpg       （4 张单图）
%   ellip_pic_p\efit_p\scene2\rela\cmp_p1_AF\{iOr}\CMP_P1_P2AF_L.jpg     （一行四列合并图）
%   ellip_pic_p\efit_p\scene2\rela\cmp_p1_AF\{iOr}\AF_vs_AS_delta_Chroma_hue.xlsx
%       （每个 scene 的椭圆中心，以及 AF 相对 AS 的 Chroma / hue 增量与平均）
% ========================================================================
close all;
clc;
clear;
addpath("utils\")

C = p2_config();

%% ---------- 1. 开关 ----------
iOr            = "r";            % 主图场景组：r（14 实景，默认） | i（21 光源）
obsNationP2    = "AF";           % phase2 观察者族裔（当前 phase2 只有 AF / SA）
ATTRIBUTE      = 1;              % 1 = Preference（画图用的属性）
lightness_type = "rela";         % 与 p2_load_labfit 的 'scale' 等价

if iOr == "i"
    indices_target = 1:numel(C.PICNAMES_I);
else
    indices_target = 1:numel(C.PICNAMES_R);
end

% i 组的 hd65 单独作为第 4 类场景（主图用 r 时才加，避免和 i 组自身重复）
addHd65 = (iOr == "r");
hd65Name = "hd65";
idxHd65  = find(C.PICNAMES_I == hd65Name, 1);

%% ---------- 2. phase1 数据（只依赖 .mat，不再跑 phase1 全流程） ----------
P1_MAT_R = fullfile(C.P1_ROOT, 'B_data_analysis', 'analyze', 'ellip_pic_p', ...
    C.Dtype, 'data_reshaped_r.mat');
P1_MAT_I = fullfile(C.P1_ROOT, 'B_data_analysis', 'analyze', 'ellip_pic_p', ...
    C.Dtype, 'data_reshaped_i.mat');
p1Files = {P1_MAT_R, P1_MAT_I};
for ii = 1:numel(p1Files)
    f = p1Files{ii};
    if ~isfile(f)
        error('scatter_scene_AS_AF: 找不到 phase1 结果文件 %s（请先从 E 盘复制该 .mat）', f);
    end
end
S1  = load(P1_MAT_R, 'lab_fit_reshaped');    % 14 实景
S1i = load(P1_MAT_I, 'lab_fit_reshaped');    % 21 光源（只用到 hd65）
fprintf('[CMP] phase1 数据: %s\n', P1_MAT_R);
fprintf('[CMP] phase1 数据: %s\n', P1_MAT_I);

%% ---------- 3. phase2 数据 ----------
D2 = p2_load_labfit(obsNationP2, 'r', struct('lightness', 'scale', ...
    'obsType', 'non_model', 'verbose', true));
fprintf('[CMP] phase2 数据: %s / r\n', D2.obsNation);
D2i = p2_load_labfit(obsNationP2, 'i', struct('lightness', 'scale', ...
    'obsType', 'non_model', 'verbose', false));
fprintf('[CMP] phase2 数据: %s / i\n', D2i.obsNation);

%% ---------- 4. 逐族裔取"受试者平均"中心 ----------
nNat  = numel(C.STIM_NATIONS);
nSceneR = numel(C.PICNAMES_R);

labP1    = cell(1, nNat);      % nSceneR × 3
labP2    = cell(1, nNat);
labP1_hd = cell(1, nNat);      % 1 × 3（hd65）
labP2_hd = cell(1, nNat);
nMissP1  = zeros(1, nNat);
nMissP2  = zeros(1, nNat);

for iNat = 1:nNat
    labP1{iNat} = mean(S1.lab_fit_reshaped{1, iNat}(indices_target, :, :, ATTRIBUTE), 3, 'omitnan');
    labP2{iNat} = mean(D2.lab_fit(indices_target, :, D2.stimIdx{iNat}, ATTRIBUTE), 3, 'omitnan');
    nMissP1(iNat) = sum(all(isnan(labP1{iNat}), 2));
    nMissP2(iNat) = sum(all(isnan(labP2{iNat}), 2));

    labP1_hd{iNat} = nan(1, 3);
    labP2_hd{iNat} = nan(1, 3);
    if addHd65
        labP1_hd{iNat} = mean(S1i.lab_fit_reshaped{1, iNat}(idxHd65, :, :, ATTRIBUTE), 3, 'omitnan');
        labP2_hd{iNat} = mean(D2i.lab_fit(idxHd65, :, D2i.stimIdx{iNat}, ATTRIBUTE), 3, 'omitnan');
    end
end

%% ---------- 5. 统一轴范围（4 个面板、两个来源、含 hd65 共用） ----------
pts = [];
for iNat = 1:nNat
    pts = [pts; labP1{iNat}(:, 2:3); labP2{iNat}(:, 2:3); ...
        labP1_hd{iNat}(:, 2:3); labP2_hd{iNat}(:, 2:3)]; %#ok<AGROW>
end
pts = pts(~any(isnan(pts), 2), :);
if isempty(pts)
    error('scatter_scene_AS_AF: 两个来源都没有可用的 Preference 数据');
end
limMax = max(ceil(max(pts(:)) + 2), 10);
limMin = max(0, floor(min(pts(:)) - 2));
lims   = [limMin, limMax];

%% ---------- 6. 配色 + 图例文字 ----------
[colors, famColor, famLabels] = makeSceneColors(iOr);
if addHd65                                     % 第 4 类场景：黑色
    famColor  = [famColor; 0 0 0];             %#ok<AGROW>
    famLabels = [famLabels, {'In-lab'}];        %#ok<AGROW>
end
hdColor = [0 0 0];
obsPair = {'Asian observers', 'African observers'};   % 箭头两端：起点 / 箭尖

saveFolder = fullfile(C.PIC_ROOT, C.Dtype, 'scene2', char(lightness_type), ...
    char(sprintf('cmp_p1_%s', obsNationP2)), char(iOr));
if ~exist(saveFolder, 'dir'), mkdir(saveFolder); end

FS      = 16;                    % 轴标签 / 刻度 / 标题 / 图例 / 子图标号 统一字号
NUM     = 12;                    % 单图上的场景编号字号（面板大，可以稍大一点）
NUM_CMP = 9;                     % 合并图上的场景编号字号（面板小，特批用小字）

%% ---------- 7. 单族裔单图 ----------
for iNat = 1:nNat
    stimSerial = strcat(sprintf('%02d', iNat), C.STIM_NATIONS(iNat));

    h  = figure('Color', 'white', 'Position', [100, 100, 1260, 660]);
    % 0.3810×1260 = 0.7273×660 = 480 px，坐标框保持正方且水平居中
    ax = axes(h, 'Position', [0.3095, 0.2227, 0.3810, 0.7273]);
    hold(ax, 'on');
    drawPanel(ax, labP1{iNat}, labP2{iNat}, colors, lims, ...
        C.STIM_NATION_NAMES(iNat), NUM, FS, '', ...
        labP1_hd{iNat}(2:3), labP2_hd{iNat}(2:3), hdColor);

    addLegends(h, famColor, famLabels, obsPair, 0.5, 0.098, FS);

    saveFig(h, fullfile(saveFolder, strcat(char(stimSerial), '_L.jpg')));
    close(h);
end

%% ---------- 8. 四个子图排成一行的合并图 ----------
hc = figure('Color', 'white', 'Position', [60, 80, 1260, 360]);
W  = 0.1608;  H = 0.5639;                % 203×203 px
gapX = 0.0750;                           % 子图间隔约 95 px
x0   = 0.0660;                           % 左右留白 83 px（左侧要放得下第一个图的 b*）
y0   = 0.3611;                           % 顶部留 27 px 放子图标题
panelPos = cell(1, nNat);
for iNat = 1:nNat
    panelPos{iNat} = [x0 + (iNat - 1) * (W + gapX), y0, W, H];
end
for iNat = 1:nNat
    ax = axes(hc, 'Position', panelPos{iNat});
    hold(ax, 'on');
    drawPanel(ax, labP1{iNat}, labP2{iNat}, colors, lims, ...
        C.STIM_NATION_NAMES(iNat), NUM_CMP, FS, sprintf('(%c)', 'a' + iNat - 1), ...
        labP1_hd{iNat}(2:3), labP2_hd{iNat}(2:3), hdColor);
end
addLegends(hc, famColor, famLabels, obsPair, 0.5, 0.095, FS);

saveFig(hc, fullfile(saveFolder, 'CMP_P1_P2AF_L.jpg'));
close(hc);

%% ---------- 9. 终端小结 ----------
fprintf('\n[CMP] 缺测场景数（共 %d 个场景）:\n', numel(indices_target));
for iNat = 1:nNat
    fprintf('  %-4s  Asian = %d, African = %d\n', ...
        char(C.STIM_NATIONS(iNat)), nMissP1(iNat), nMissP2(iNat));
end
fprintf('[CMP] 出图: %s\n', saveFolder);

%% ---------- 10. 每个 scene 的椭圆中心 + AF 相对 AS 的 C*/h* 增量（xlsx） ----------
% 中心 = [平均肤色 L*, 拟合出的 a*, b*]；Chroma C* = hypot(a*,b*)，hue h* = atan2d(b*,a*)
% "AS 观察者" = phase1 的 non_model 结果（与图上 "Asian observers" 一致）；
% "AF 观察者" = phase2 的 AF 结果。逐 model nation × attribute × scene 计算，
% 再对 scene 求平均。
attrNames = C.ATTRIBUTE_NAMES;
nAttr     = numel(attrNames);

mScene = nSceneR + double(addHd65);        % 实景 + hd65

dC = nan(nNat, nAttr, mScene);             % ΔC*
dh = nan(nNat, nAttr, mScene);             % Δh*
Cas = nan(nNat, nAttr, mScene);
has = nan(nNat, nAttr, mScene);
Caf = nan(nNat, nAttr, mScene);
haf = nan(nNat, nAttr, mScene);
was = nan(nNat, nAttr, mScene, 3);         % AS 的 Lab
waf = nan(nNat, nAttr, mScene, 3);         % AF 的 Lab

for iNat = 1:nNat
    for a = 1:nAttr
        for k = 1:mScene
            if k <= nSceneR                    % 14 个实景（r 组）
                lAS = mean(S1.lab_fit_reshaped{1, iNat}(k, :, :, a), 3, 'omitnan');
                lAF = mean(D2.lab_fit(k, :, D2.stimIdx{iNat}, a), 3, 'omitnan');
            else                               % i 组的 hd65
                lAS = mean(S1i.lab_fit_reshaped{1, iNat}(idxHd65, :, :, a), 3, 'omitnan');
                lAF = mean(D2i.lab_fit(idxHd65, :, D2i.stimIdx{iNat}, a), 3, 'omitnan');
            end
            lAS = lAS(:)';  lAF = lAF(:)';
            if any(isnan(lAS)) || any(isnan(lAF)), continue; end

            was(iNat, a, k, :) = lAS;
            waf(iNat, a, k, :) = lAF;

            Cas(iNat, a, k) = hypot(lAS(2), lAS(3));
            has(iNat, a, k) = mod(atan2d(lAS(3), lAS(2)), 360);
            Caf(iNat, a, k) = hypot(lAF(2), lAF(3));
            haf(iNat, a, k) = mod(atan2d(lAF(3), lAF(2)), 360);

            dC(iNat, a, k)  = Caf(iNat, a, k) - Cas(iNat, a, k);
            dh(iNat, a, k)  = wrap180(haf(iNat, a, k) - has(iNat, a, k));
        end
    end
end

% ---- 明细表 ----
rowsNat = strings(0, 1); rowsAttr = strings(0, 1); rowsGrp = strings(0, 1);
rowsIdx = zeros(0, 1);   rowsName = strings(0, 1);
rowsL = zeros(0, 2); rowsC = zeros(0, 2); rowsH = zeros(0, 2); rowsD = zeros(0, 2);

sceneNameAll = [C.PICNAMES_R(:)', C.PICNAMES_I(idxHd65)];
for iNat = 1:nNat
    for a = 1:nAttr
        for k = 1:mScene
            if isnan(dC(iNat, a, k)), continue; end
            rowsNat(end+1, 1)  = C.STIM_NATIONS(iNat);            %#ok<*SAGROW>
            rowsAttr(end+1, 1) = sprintf('%02d%s', a, attrNames(a));
            if k <= nSceneR
                rowsGrp(end+1, 1) = "r";
            else
                rowsGrp(end+1, 1) = "i";
            end
            rowsIdx(end+1, 1)  = k;
            rowsName(end+1, 1) = sceneNameAll(k);
            rowsL(end+1, :)    = [was(iNat, a, k, 1), waf(iNat, a, k, 1)];
            rowsC(end+1, :)    = [Cas(iNat, a, k), Caf(iNat, a, k)];
            rowsH(end+1, :)    = [has(iNat, a, k), haf(iNat, a, k)];
            rowsD(end+1, :)    = [dC(iNat, a, k), dh(iNat, a, k)];
        end
    end
end

tScene = table(rowsNat, rowsAttr, rowsGrp, rowsIdx, rowsName, ...
    rowsL(:, 1), rowsL(:, 2), rowsC(:, 1), rowsC(:, 2), rowsH(:, 1), rowsH(:, 2), ...
    rowsD(:, 1), rowsD(:, 2), ...
    'VariableNames', {'ModelNation', 'Attribute', 'SceneGroup', 'SceneIndex', 'SceneName', ...
    'L_AS', 'L_AF', 'Chroma_AS', 'Chroma_AF', 'Hue_AS_deg', 'Hue_AF_deg', ...
    'deltaChroma', 'deltaHue_deg'});

% ---- 平均表（每个 nation × attribute 对 scene 求平均） ----
mNat = strings(0, 1); mAttr = strings(0, 1);
mN = zeros(0, 1); mC = zeros(0, 2); mH = zeros(0, 2); mD = zeros(0, 2);

for iNat = 1:nNat
    for a = 1:nAttr
        vC = squeeze(dC(iNat, a, :));  vC = vC(~isnan(vC));
        vH = squeeze(dh(iNat, a, :));  vH = vH(~isnan(vH));
        if isempty(vC), continue; end
        mNat(end+1, 1)  = C.STIM_NATIONS(iNat);
        mAttr(end+1, 1) = sprintf('%02d%s', a, attrNames(a));
        mN(end+1, 1)    = numel(vC);
        mC(end+1, :)    = [mean(squeeze(Cas(iNat, a, :)), 'omitnan'), ...
                           mean(squeeze(Caf(iNat, a, :)), 'omitnan')];
        mH(end+1, :)    = [mean(squeeze(has(iNat, a, :)), 'omitnan'), ...
                           mean(squeeze(haf(iNat, a, :)), 'omitnan')];
        mD(end+1, :)    = [mean(vC), mean(vH)];
    end
end

tMean = table(mNat, mAttr, mN, mC(:, 1), mC(:, 2), mH(:, 1), mH(:, 2), mD(:, 1), mD(:, 2), ...
    'VariableNames', {'ModelNation', 'Attribute', 'nScene', ...
    'meanChroma_AS', 'meanChroma_AF', 'meanHue_AS_deg', 'meanHue_AF_deg', ...
    'meanDeltaChroma', 'meanDeltaHue_deg'});

% ---- 说明页 ----
tNote = table( ...
    ["AS baseline"; "AF source"; "Centre definition"; "Chroma"; "Hue"; ...
     "deltaChroma"; "deltaHue_deg"; "Averaging"; "Note"], ...
    [string(P1_MAT_R) + " (phase1, non_model)"; ...
     "phase2 AnalyseResults_p\efit_p\unscaled\" + obsNationP2 + "\...\fitRes.mat"; ...
     "[mean L*, fitted a*, fitted b*] per nation/scene"; ...
     "C* = sqrt(a*^2 + b*^2)"; ...
     "h* = atan2d(b*, a*), in [0,360)"; ...
     "C*_AF - C*_AS"; ...
     "h*_AF - h*_AS, wrapped to (-180,180]"; ...
     "mean over scenes with both sources available"; ...
     "Attributes missing in phase2 (e.g. some only have 01/06) appear only where data exist"], ...
    'VariableNames', {'Item', 'Description'});

xlsxFile = fullfile(saveFolder, 'AF_vs_AS_delta_Chroma_hue.xlsx');
if isfile(xlsxFile), delete(xlsxFile); end
writetable(tMean,  xlsxFile, 'Sheet', 'mean_by_nation_attr');
writetable(tScene, xlsxFile, 'Sheet', 'per_scene');
writetable(tNote,  xlsxFile, 'Sheet', 'notes');
fprintf('[DELTA] 输出: %s\n', xlsxFile);

% 终端也打印一份平均结果（Preference 与 Healthy 两个最常用的属性）
fprintf('\n[DELTA] mean delta (AF - AS)：Chroma / hue(deg)\n');
for iNat = 1:nNat
    for a = [1, 6]
        idx = find(mNat == C.STIM_NATIONS(iNat) & mAttr == sprintf('%02d%s', a, attrNames(a)), 1);
        if isempty(idx), continue; end
        fprintf('  %-4s %-12s n=%2d  dC=%+6.2f  dh=%+7.2f\n', ...
            char(mNat(idx)), char(mAttr(idx)), mN(idx), mD(idx, 1), mD(idx, 2));
    end
end

% ========================================================================
% 局部函数
% ========================================================================
function y = wrap180(x)
%WRAP180  把角度差折算到 (-180, 180]
    y = mod(x + 180, 360) - 180;
    y(y == -180) = 180;
end

% ------------------------------------------------------------------------
function saveFig(fig, fname)
%SAVEFIG  按画布实际尺寸 1:1 导出整幅图（不裁剪、不拉伸，保留四周留白）
    Wp = fig.Position(3) / 96;
    Hp = fig.Position(4) / 96;
    set(fig, 'PaperUnits', 'inches', 'PaperSize', [Wp, Hp], ...
        'PaperPosition', [0, 0, Wp, Hp]);
    print(fig, fname, '-djpeg', '-r600');    % 600 dpi：1260 px 画布 => 7875 px 输出
end

% ------------------------------------------------------------------------
function drawPanel(ax, lab1, lab2, colors, lims, nationName, numSize, labSize, ...
    panelLabel, hdStart, hdEnd, hdColor)
%DRAWPANEL  在一个坐标轴上画 Asian observers -> African observers 的箭头
%   lab1/lab2  : Asian / African 的 nScene×3 Lab（箭头起点 / 箭尖）
%   numSize    : 场景编号字号
%   labSize    : 坐标轴标签 / 刻度 / 标题 / 面板标号字号
%   panelLabel : 右下角面板标号，如 '(a)'；传 '' 则不加
%   hdStart/hdEnd : i 组 hd65 的起点 / 箭尖（1×2，a* b*）；传 [] 则不画
%   hdColor    : hd65 的颜色（黑）
    range   = lims(2) - lims(1);
    headLen = 0.045 * range;        % 固定箭头头部尺寸（数据单位，与箭长无关）
    dText   = 0.015 * range;        % 编号相对起点的偏移

    % ---- 45° 等色相参考线 ----
    xLine = linspace(max(0, lims(1)), lims(2), 100);
    plot(ax, xLine, xLine, 'Color', [0.4 0.4 0.4], 'LineStyle', '--');
    xLab = 0.80 * lims(2);
    text(ax, xLab, xLab - 0.02 * range, '45°', 'VerticalAlignment', 'top', ...
        'HorizontalAlignment', 'left', 'FontSize', labSize, ...
        'Color', [0.3 0.3 0.3]);

    % ---- 逐场景箭头：起点 Asian -> 箭尖 African ----
    for k = 1:size(lab1, 1)
        p1 = lab1(k, 2:3);
        p2 = lab2(k, 2:3);
        if any(isnan(p1)) || any(isnan(p2)), continue; end

        u = (p2 - p1) / norm(p2 - p1);       % 单位方向
        drawArrow(ax, p1, p2, colors(k, :), headLen);

        % 起点编号（Asian 的位置）：放在箭头尾部的反方向，避开箭头本体
        pLab = p1 - u * dText;
        text(ax, pLab(1), pLab(2), num2str(k), ...
            'FontSize', numSize, 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
            'Color', colors(k, :));
    end

    % ---- 第 4 类场景（i 组 hd65）：黑色箭头，起点只画点、不标数字 ----
    if ~isempty(hdStart) && ~any(isnan([hdStart(:); hdEnd(:)]))
        drawArrow(ax, hdStart(:)', hdEnd(:)', hdColor, headLen);
        plot(ax, hdStart(1), hdStart(2), 'o', 'MarkerSize', max(4, numSize * 0.55), ...
            'MarkerFaceColor', hdColor, 'MarkerEdgeColor', 'none');
    end

    % ---- 坐标轴 ----
    axis(ax, 'equal');
    xlim(ax, lims);
    ylim(ax, lims);
    xlabel(ax, '{\ita}^{*}', 'Interpreter', 'tex', 'FontSize', labSize);
    ylabel(ax, '{\itb}^{*}', 'Interpreter', 'tex', 'FontSize', labSize);
    title(ax, nationName, 'FontSize', labSize);
    set(ax, 'FontSize', labSize);          % 刻度与轴标签同字号
    box(ax, 'on');
    grid(ax, 'on');

    % ---- 右下角的子图标号 (a) (b) ... ----
    if ~isempty(panelLabel)
        text(ax, lims(2) - 0.035 * range, lims(1) + 0.035 * range, panelLabel, ...
            'FontSize', labSize, 'HorizontalAlignment', 'right', ...
            'VerticalAlignment', 'bottom', 'Color', [0.15 0.15 0.15]);
    end
end

% ------------------------------------------------------------------------
function drawArrow(ax, p0, p1, col, headLen)
%DRAWARROW  画一支给定颜色的箭头，头部尺寸固定（不随箭头长度缩放）
    v = p1 - p0;
    L = norm(v);
    if L < 1e-6, return; end

    u   = v / L;                    % 单位方向
    nrm = [-u(2), u(1)];            % 法向

    pBase = p1 - u * headLen;       % 箭头底面中点
    if dot(pBase - p0, u) < 0       % 箭头比头部还短：轴只留一小段
        pBase = p0 + u * (0.35 * L);
    end

    plot(ax, [p0(1), pBase(1)], [p0(2), pBase(2)], 'Color', col, 'LineWidth', 1.4);

    hw  = 0.40 * headLen;           % 半宽
    tri = [p1; pBase + nrm * hw; pBase - nrm * hw];
    patch(ax, tri(:, 1), tri(:, 2), col, 'EdgeColor', 'none');
end

% ------------------------------------------------------------------------
function addLegends(fig, famColor, famLabels, obsPair, centerX, yRow1, FS)
%ADDLEGENDS  手画一排图例（无边框）：N 类场景色 + 一条说明箭头
    axO = axes(fig, 'Position', [0 0 1 1], 'Visible', 'off', ...
        'XLim', [0 1], 'YLim', [0 1]);
    hold(axO, 'on');

    W  = fig.Position(3);
    Hh = fig.Position(4);
    sw = 13 / W;
    sh = 13 / Hh;
    nFam = numel(famLabels);

    % ---- 先量出每个字符串的真实宽度，再排版 ----
    allStr = [famLabels(:)', obsPair(:)'];
    hMea   = gobjects(1, numel(allStr));
    for i = 1:numel(allStr)
        hMea(i) = text(axO, 0, 0.5, allStr{i}, 'FontSize', FS);
    end
    drawnow;
    wStr = zeros(1, numel(allStr));
    for i = 1:numel(allStr), wStr(i) = hMea(i).Extent(3); end
    delete(hMea);
    wFamLab = wStr(1:nFam);
    wObs    = wStr(nFam + 1:nFam + 2);

    % ---- N 段 "色块 + 文字" ----
    arrowLen = 0.030;
    gapFam   = 0.032;
    wFam     = sw + 0.008 + wFamLab;
    wArrow   = wObs(1) + 0.008 + arrowLen + 0.008 + wObs(2);

    totalW = sum(wFam) + nFam * gapFam + 0.010 + wArrow;
    xCur   = centerX - totalW / 2;

    for c = 1:nFam
        patch(axO, [xCur, xCur + sw, xCur + sw, xCur], ...
            [yRow1 - sh / 2, yRow1 - sh / 2, yRow1 + sh / 2, yRow1 + sh / 2], ...
            famColor(c, :), 'EdgeColor', 'none');
        xText = xCur + sw + 0.008;
        text(axO, xText, yRow1, famLabels{c}, 'FontSize', FS, ...
            'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left');
        xCur = xText + wFamLab(c) + gapFam;
    end

    % ---- 说明箭头 ----
    col = [0.25 0.25 0.25];
    xCur = xCur + 0.010;
    x0 = xCur + wObs(1) + 0.008;
    x1 = x0 + arrowLen;
    y  = yRow1;

    plot(axO, [x0, x1], [y, y], 'Color', col, 'LineWidth', 1.3);
    hLen = 10 / W;
    hWid = 10 / Hh;
    patch(axO, [x1, x1 - hLen, x1 - hLen], [y, y + hWid * 0.5, y - hWid * 0.5], ...
        col, 'EdgeColor', 'none');

    text(axO, x0 - 0.008, y, obsPair{1}, 'HorizontalAlignment', 'right', ...
        'VerticalAlignment', 'middle', 'FontSize', FS);
    text(axO, x1 + 0.008, y, obsPair{2}, 'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', 'FontSize', FS);
end

% ------------------------------------------------------------------------
function [colors, famColor, famLabels] = makeSceneColors(iOr)
%MAKESCENECOLORS  逐场景配色：同类场景共用色相，靠明度/色相小偏移区分
    if iOr == "r"
        groups    = {1:6, 7:12, 13:14};
        famLabels = {'Indoor (1-6)', 'Outdoor (7-12)', 'Night (13-14)'};
    else
        groups    = {1:7, 8:14, 15:21};
        famLabels = {'High L (1-7)', 'Medium L (8-14)', 'Low L (15-21)'};
    end
    hue0 = [0.00, 0.33, 0.66];

    nScene = sum(cellfun(@numel, groups));
    colors = zeros(nScene, 3);
    famColor = zeros(3, 3);
    for g = 1:3
        idx = groups{g};
        n   = numel(idx);

        nLev = max(2, ceil(n / 2));
        lev  = linspace(1.00, 0.58, nLev);
        val  = zeros(n, 1);
        hue  = zeros(n, 1);
        for i = 1:n
            val(i) = lev(ceil(i / 2));
            if mod(i, 2) == 1
                hue(i) = hue0(g) + 0.025;
            else
                hue(i) = hue0(g) - 0.030;
            end
        end
        sat = 0.95 - 0.10 * (1 - val);

        colors(idx, :) = hsv2rgb([mod(hue, 1), sat, val]);
        famColor(g, :) = colors(idx(ceil(n / 2)), :);
    end
end
