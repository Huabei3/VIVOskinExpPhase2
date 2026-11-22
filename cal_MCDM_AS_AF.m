% ========================================================================
% cal_MCDM_AS_AF.m   （phase1 Asian 观察者 × phase2 African 观察者：MCDM 对比）
%
% 作用:
%   MCDM = 每个观察者单独拟合出的偏好中心，与该属性整体加权平均中心之间的
%   CIEDE2000 距离；数值越大说明该类观察者的判断越分散。
%   本脚本把 phase1（观察者 = Asian）与 phase2（观察者族裔 = AF，African）
%   的 MCDM 画进同一张柱状图，只画 {attribute} = Preference(01) 与 Healthy(06)。
%
% 图元编码:
%   颜色 = 属性（Preference 蓝 / Healthy 橙）
%   填充 = 观察者群体：phase2 AF = 纯色，phase1 = 斜杠（hatch）
%   横轴 = 4 个组（Asian / Caucasian / South Asian / African）
%
% 数据来源（只读已算好的 MCDM 汇总，不重跑椭圆拟合）:
%   phase1 : <P1_ROOT>\B_data_analysis\analyze\AnalyseResults_p\efit_p\unscaled\
%            sum_list\MCDM\non_model\{i|r}\MCDMdata.mat 的 MCDM_global
%            维度 20×10×nScene×20（行 = 刺激组，顺序见局部函数 phase1Order）
%   phase2 : <P2_ROOT>\AnalyseResults_p\efit_p\unscaled\sum_list\MCDM\AF\{i}\
%            MCDMdata.mat 的 MCDM_global（维度相同，行序 = p2_config 的
%            STIM_NATIONS × STIM_MODELS 顺序，与 phase1 完全一致）
%
% ② 依赖搬运（只在本地镜像上工作，不读 E 盘）:
%   phase1 侧真正需要的只有 4 个 MCDMdata.mat（non_model/{i,r} 与
%   model_group/{i,r}，合计约 600 KB），已从
%     E:\PeggySkinBackup\A_code\C_VIVO_skin_project\B_data_analysis\analyze\...
%   复制到
%     D:\work\VIVOskinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\B_data_analysis\analyze\...
%   本脚本不依赖 expRes / aveSkin / dlabsNpicname / LUT 等原始数据。
%
% ③ LUT 口径（两期各用各的显示标定）:
%   phase1 -> C.LUT18_FILE  (datai_ipv18_3)
%   phase2 -> C.LUT_P2_FILE (datai_ipv30_phase2_3)
%   注意: MCDM 链条里 LUT 只在 process_data_MCDM 里被载入，真正参与计算的是
%   CAT16（XYZw_pre / wd65_64），XYZw_LUT 载入后并未被使用；因此 MCDM 数值
%   与 LUT 无关，本脚本读到的 phase1/phase2 汇总不需要因为换 LUT 而重算。
%
% 输出:
%   ellip_pic_p\efit_p\MCDM\cmp_p1_AF\MCDM_P1_vs_P2AF.jpg
%   ellip_pic_p\efit_p\MCDM\cmp_p1_AF\MCDM_compare.mat
%   ellip_pic_p\efit_p\MCDM\cmp_p1_AF\MCDM_compare.xlsx
% ========================================================================
close all;
clc;
clear;
addpath("utils\")

C = p2_config();

%% ---------- 1. 开关 ----------
iOr          = "i";           % phase2 场景集：i（21 光源） | r（14 实景，无 MCDM 汇总）
obsNationP2  = "AF";          % phase2 观察者族裔（本机有 MCDM 汇总的：AF / SA）
ATTRS        = [1, 6];        % ① 01Preference  ② 06Healthy
P1_SCENE_SET = "i";           % phase1 取哪套场景：i | r | ir（两套合并平均）
P1_OBS_TYPE  = "non_model";   % phase1 汇总目录名（观察者类型）
X_LABEL      = 'Observer ethnic groups';   % 需要时改成 'Stimulus ethnic groups'
SHOW_P1_IR   = true;          % 控制台额外汇总 phase1 的 i / r / i+r 三个口径
FONT         = 18;            % 轴标签 / 刻度 / 图例统一字号

%% ---------- 2. 路径与存在性检查 ----------
P1_MCDM_DIR = fullfile(C.P1_ROOT, 'B_data_analysis', 'analyze', 'AnalyseResults_p', ...
    C.Dtype, C.scale_type_origin, 'sum_list', 'MCDM', char(P1_OBS_TYPE));
P2_MCDM_DIR = fullfile(C.ANALYSE_ROOT, C.Dtype, C.scale_type_origin, ...
    'sum_list', 'MCDM', char(obsNationP2));

p1FileI = fullfile(P1_MCDM_DIR, 'i', 'MCDMdata.mat');
p1FileR = fullfile(P1_MCDM_DIR, 'r', 'MCDMdata.mat');
p2File  = fullfile(P2_MCDM_DIR, char(iOr), 'MCDMdata.mat');

needP1R = any(strcmp(char(P1_SCENE_SET), {'r', 'ir'})) || SHOW_P1_IR;
mustHave = {p1FileI, p2File};
if needP1R, mustHave{end+1} = p1FileR; end
for k = 1:numel(mustHave)
    if ~isfile(mustHave{k})
        error(['cal_MCDM_AS_AF: 找不到 MCDM 汇总文件\n  %s\n' ...
            'phase1 侧请从 E:\\PeggySkinBackup\\A_code\\C_VIVO_skin_project\\' ...
            'B_data_analysis\\analyze\\... 的同名路径复制这一个 .mat 到本地镜像'], ...
            mustHave{k});
    end
end

G1_i = loadGlobal(p1FileI);
G2   = loadGlobal(p2File);
fprintf('[CMP] phase1 汇总: %s\n', p1FileI);
fprintf('[CMP] phase2 汇总: %s（观察者 = %s）\n', p2File, char(obsNationP2));

%% ---------- 3. 场景集选择 ----------
switch char(P1_SCENE_SET)
    case 'i'
        G1 = G1_i;
    case 'r'
        G1 = loadGlobal(p1FileR);
    case 'ir'
        G1_r = loadGlobal(p1FileR);
        G1 = mean(cat(3, G1_i, G1_r), 3, 'omitnan');       % 场景维拼接后平均（21+14 个场景）
    otherwise
        error('cal_MCDM_AS_AF: P1_SCENE_SET 只能是 i / r / ir');
end

%% ---------- 4. 维度与行序校验 ----------
p1Order = phase1Order(char(iOr));
if size(G1, 1) ~= numel(p1Order)
    error('cal_MCDM_AS_AF: phase1 MCDM_global 行数 %d ≠ 预期 20 组', size(G1, 1));
end
if size(G1, 2) ~= C.nAttr || size(G2, 2) ~= C.nAttr
    error('cal_MCDM_AS_AF: 属性维不等于 %d', C.nAttr);
end

nNat = numel(C.STIM_NATIONS);
stimIdx = cell(1, nNat);
k = 0;
for iNat = 1:nNat
    n = numel(C.STIM_MODELS{iNat});
    stimIdx{iNat} = (k + 1):(k + n);
    k = k + n;
end
if size(G1, 1) ~= k || size(G2, 1) ~= k
    error('cal_MCDM_AS_AF: phase1/phase2 的行数（%d / %d）与 40 组结构（%d）不符', ...
        size(G1, 1), size(G2, 1), k);
end

% phase2 的汇总文件自带 lastParts，可直接核对行序；phase1 的 .mat 没存，
% 已用逐组 MCDMdata.mat 逐行核对过（20 组 × 2 属性全部一致）
S2 = load(p2File, 'lastParts');
if isfield(S2, 'lastParts') && ~isequal(cellstr(S2.lastParts(:))', p1Order)
    warning('cal_MCDM_AS_AF: phase2 的 lastParts 与 phase1 行序不一致，请先核对再出图');
end

%% ---------- 5. 组 × 属性 的族裔均值 ----------
M1 = nationMean(G1, stimIdx, ATTRS);     % phase1（Asian 观察者）
M2 = nationMean(G2, stimIdx, ATTRS);     % phase2（AF 观察者）

if SHOW_P1_IR
    G1_r = loadGlobal(p1FileR);
    M1r  = nationMean(G1_r, stimIdx, ATTRS);
    M1ir = nationMean(mean(cat(3, G1_i, G1_r), 3, 'omitnan'), stimIdx, ATTRS);
    fprintf('\n[CMP] phase1 三种场景口径的族裔均值（用于核对，不作为出图数据）:\n');
    fprintf('  %-12s %10s %10s %10s\n', 'group', 'i', 'r', 'i+r');
    for iNat = 1:nNat
        for ia = 1:numel(ATTRS)
            fprintf('  %-12s %10.3f %10.3f %10.3f   (%s)\n', ...
                sprintf('%s/%s', char(C.STIM_NATIONS(iNat)), ...
                char(strcat(sprintf('%02d', ATTRS(ia)), C.ATTRIBUTE_NAMES(ATTRS(ia))))), ...
                M1(iNat, ia), M1r(iNat, ia), M1ir(iNat, ia), 'phase1');
        end
    end
end

%% ---------- 6. 绘图 ----------
nAttr   = numel(ATTRS);
nSrc    = 2;                                  % 1 = phase1(Asian)，2 = phase2(AF)
barW    = 0.80 / (nAttr * nSrc);              % 单根柱宽
attrColors = [0.17 0.42 0.72;                 % Preference 蓝
              0.90 0.46 0.14];                % Health    橙

% 图例/控制台用的显示名（与 ATTRS 一一对应；06Healthy 按需求显示为 Health）
attrLabels = cell(1, nAttr);
for ia = 1:nAttr
    switch ATTRS(ia)
        case 1, attrLabels{ia} = 'Preference';
        case 6, attrLabels{ia} = 'Health';
        otherwise, attrLabels{ia} = char(C.ATTRIBUTE_NAMES(ATTRS(ia)));
    end
end

% 结果文件里保留 phase1/phase2 的属性目录名，便于回溯（01Preference / 06Healthy）
attrKeys = cell(1, nAttr);
for ia = 1:nAttr
    attrKeys{ia} = char(strcat(sprintf('%02d', ATTRS(ia)), C.ATTRIBUTE_NAMES(ATTRS(ia))));
end

h = figure('Color', 'white', 'Position', [80, 40, 1500, 1000]);
ax = axes(h, 'Position', [0.095, 0.225, 0.875, 0.725]);
hold(ax, 'on');
box(ax, 'on');
grid(ax, 'on');

yTop = max([M1(:); M2(:)], [], 'omitnan');
if ~isfinite(yTop) || yTop <= 0, yTop = 1; end
yLimTop = yTop * 1.12;
xlim(ax, [0.45, nNat + 0.55]);
ylim(ax, [0, yLimTop]);

for ia = 1:nAttr
    for isrc = 1:nSrc
        idx = (ia - 1) * nSrc + (isrc - 1);
        off = (idx - (nAttr * nSrc - 1) / 2) * barW;
        for iNat = 1:nNat
            if isrc == 1, v = M1(iNat, ia); else, v = M2(iNat, ia); end
            if ~isfinite(v) || v <= 0, continue; end
            xc = iNat + off;
            if isrc == 1
                drawHatchedRect(ax, xc, 0, barW * 0.92, v, attrColors(ia, :), 0.045, 1.0);
            else
                drawSolidRect(ax, xc, 0, barW * 0.92, v, attrColors(ia, :), 1.0);
            end
        end
    end
end

%% ---------- 7. 轴标签 / 刻度 ----------
set(ax, 'XTick', 1:nNat);
set(ax, 'XTickLabel', cellstr(C.STIM_NATION_NAMES));
set(ax, 'FontSize', FONT);
xlabel(ax, X_LABEL, 'FontSize', FONT);
ylabel(ax, 'MCDM (\DeltaE_{00})', 'FontSize', FONT);

%% ---------- 8. 图例（整图正下方、水平居中，手绘在独立的整图坐标轴上） ----------
Wpx = h.Position(3);
Hpx = h.Position(4);
axL = axes(h, 'Position', [0 0 1 1], 'Visible', 'off', 'XLim', [0 1], 'YLim', [0 1]);
hold(axL, 'on');

keyW  = 26 / Wpx;                     % 色块 26 px 见方（换算成 figure 归一化单位）
keyH  = 26 / Hpx;
yRow  = 0.046;                        % 单排图例的中心（整图归一化）

% 单排四项：前两项颜色 = 属性，后两项填充 = 观察者群体（顺序与柱子左右一致）
grayKey = [0.35 0.35 0.35];
drawLegendRow(axL, {attrLabels{1}, attrLabels{2}, ...
    sprintf('%s observers', obsNameOf('AS')), ...
    sprintf('%s observers', obsNameOf(obsNationP2))}, ...
    {attrColors(1, :), attrColors(2, :), grayKey, grayKey}, ...
    {'solid', 'solid', 'hatch', 'solid'}, ...
    yRow, keyW, keyH, FONT);

% exportgraphics 按内容紧包围盒裁切：这里用白色细线撑出四周白边（白底上不可见）
plot(axL, [0.02, 0.98], [0.008, 0.008], 'Color', 'w', 'LineWidth', 0.5);
plot(axL, [0.02, 0.98], [0.996, 0.996], 'Color', 'w', 'LineWidth', 0.5);
plot(axL, [0.006, 0.006], [0.02, 0.98], 'Color', 'w', 'LineWidth', 0.5);

%% ---------- 9. 导出 ----------
saveFolder = fullfile(C.PIC_ROOT, C.Dtype, 'MCDM', ...
    char(sprintf('cmp_p1_%s', obsNationP2)));
if ~exist(saveFolder, 'dir'), mkdir(saveFolder); end
outJpg = fullfile(saveFolder, 'MCDM_P1_vs_P2AF.jpg');
exportgraphics(h, outJpg, 'Resolution', 300);
close(h);

save(fullfile(saveFolder, 'MCDM_compare.mat'), 'M1', 'M2', 'ATTRS', ...
    'attrLabels', 'attrKeys', 'p1FileI', 'p2File', 'P1_SCENE_SET', 'obsNationP2');

xlsxFile = fullfile(saveFolder, 'MCDM_compare.xlsx');
if isfile(xlsxFile), delete(xlsxFile); end
grpNames = cellstr(C.STIM_NATIONS);
for ia = 1:nAttr
    T = table(grpNames(:), M1(:, ia), M2(:, ia), M2(:, ia) - M1(:, ia), ...
        'VariableNames', {'Group', 'Phase1_Asian', 'Phase2_African', 'Diff_P2_minus_P1'});
    writetable(T, xlsxFile, 'Sheet', attrLabels{ia});
end
meta = table({'phase1 file'; 'phase2 file'; 'phase1 scene set'; 'phase2 obsNation'; ...
    'attribute code'}, ...
    {p1FileI; p2File; char(P1_SCENE_SET); char(obsNationP2); strjoin(attrKeys, ', ')}, ...
    'VariableNames', {'Item', 'Value'});
writetable(meta, xlsxFile, 'Sheet', 'meta');

%% ---------- 10. 控制台核对 ----------
fprintf('\n=== MCDM（行 = 组，列 = 属性）；phase1 = Asian 观察者，phase2 = %s 观察者 ===\n', ...
    char(obsNationP2));
fprintf('%10s', 'group');
for ia = 1:nAttr
    fprintf('%22s', attrLabels{ia});
end
fprintf('\n');
fprintf('%10s', '');
for ia = 1:nAttr
    fprintf('%10s%12s', 'P1', 'P2');
end
fprintf('\n');
for iNat = 1:nNat
    fprintf('%10s', char(C.STIM_NATIONS(iNat)));
    for ia = 1:nAttr
        fprintf('%10.3f%12.3f', M1(iNat, ia), M2(iNat, ia));
    end
    fprintf('\n');
end
fprintf('%10s', 'mean');
for ia = 1:nAttr
    fprintf('%10.3f%12.3f', mean(M1(:, ia), 'omitnan'), mean(M2(:, ia), 'omitnan'));
end
fprintf('\n');
fprintf('[CMP] 出图: %s\n', outJpg);
fprintf('[CMP] 数据: %s\n', fullfile(saveFolder, 'MCDM_compare.xlsx'));

% ========================================================================
% 局部函数
% ========================================================================
function G = loadGlobal(f)
%LOADGLOBAL  读出 MCDMdata.mat 里的 MCDM_global（缺变量时明确报错）
    S = load(f, 'MCDM_global');
    if ~isfield(S, 'MCDM_global')
        error('loadGlobal: %s 里没有 MCDM_global 变量', f);
    end
    G = double(S.MCDM_global);
end

% ------------------------------------------------------------------------
function order = phase1Order(iOr)
%PHASE1ORDER  phase1 C_F_06 写 MCDM_global 时的行序（= 按族裔分块的 40 组）
%   顺序: AS(f04,f05,f06,m04,m05,m06) -> CA(f01..m03) -> SA(f07,f08,m07,m08)
%         -> AF(f09,f10,m09,m10)，与 p2_config.STIM_MODELS 完全一致。
    models = {'f04','f05','f06','m04','m05','m06', ...
              'f01','f02','f03','m01','m02','m03', ...
              'f07','f08','m07','m08', ...
              'f09','f10','m09','m10'};
    order = cell(1, numel(models));
    for i = 1:numel(models)
        order{i} = [models{i}, iOr];
    end
end

% ------------------------------------------------------------------------
function M = nationMean(G, stimIdx, attrList)
%NATIONMEAN  组 × 属性 的均值（对该族裔全部刺激组 × 全部场景 × 全部观察者取平均）
%   G        : nSub×nAttr×nPara×nObs（NaN = 缺测）
%   stimIdx  : 1×nNat cell，每个元素是该族裔的刺激组行下标
%   attrList : 要统计的属性列下标
    nNat = numel(stimIdx);
    M = nan(nNat, numel(attrList));
    for iNat = 1:nNat
        for k = 1:numel(attrList)
            sub = G(stimIdx{iNat}, attrList(k), :, :);
            v = sub(:);
            if all(isnan(v)), continue; end
            M(iNat, k) = mean(v, 'omitnan');
        end
    end
end

% ------------------------------------------------------------------------
function name = obsNameOf(code)
%OBSNAMEOF  把观察者族裔缩写映射成图例用的英文全名
    switch upper(char(code))
        case 'AS', name = 'Asian';
        case 'CA', name = 'Caucasian';
        case 'SA', name = 'South Asian';
        case 'AF', name = 'African';
        otherwise, name = upper(char(code));
    end
end

% ------------------------------------------------------------------------
function drawSolidRect(ax, xc, y0, w, hgt, col, lw)
%DRAWSOLIDRECT  纯色矩形（phase2 / 图例的纯色键）
    x0 = xc - w / 2; x1 = xc + w / 2;
    patch(ax, [x0, x1, x1, x0], [y0, y0, y0 + hgt, y0 + hgt], col, ...
        'EdgeColor', col, 'LineWidth', lw);
end

% ------------------------------------------------------------------------
function drawLegendRow(ax, labels, colors, styles, yc, keyW, keyH, fs)
%DRAWLEGENDROW  在整图坐标轴上画一排图例，并相对整图水平居中
%   labels : 文字（cellstr），colors : 每项色块颜色，styles : 'solid' | 'hatch'
%   yc     : 该排的中心 y（figure 归一化）
%   keyW/keyH : 色块宽高（figure 归一化，按像素换算）
%   先量出每段文字的真实宽度，再按总宽反算起点，保证整体以 x = 0.5 居中。
    n = numel(labels);
    gapKeyText = 0.007;                     % 色块与文字的间距
    gapItem    = 0.030;                     % 相邻两项的间距
    fig = ancestor(ax, 'figure');
    slope = fig.Position(4) / fig.Position(3);   % 归一化坐标里视觉 45° 对应的斜率

    textW = zeros(1, n);
    for i = 1:n
        hT = text(ax, 0, yc, labels{i}, 'FontSize', fs);
        drawnow;
        textW(i) = hT.Extent(3);
        delete(hT);
    end

    itemW  = keyW + gapKeyText + textW;
    totalW = sum(itemW) + gapItem * (n - 1);
    x = 0.5 - totalW / 2;
    for i = 1:n
        if strcmp(styles{i}, 'hatch')
            drawHatchedRect(ax, x + keyW / 2, yc - keyH / 2, keyW, keyH, ...
                colors{i}, 0.0070, 1.0, slope);
        else
            drawSolidRect(ax, x + keyW / 2, yc - keyH / 2, keyW, keyH, colors{i}, 1.0);
        end
        text(ax, x + keyW + gapKeyText, yc, labels{i}, 'FontSize', fs, ...
            'VerticalAlignment', 'middle', 'HorizontalAlignment', 'left');
        x = x + itemW(i) + gapItem;
    end
end

% ------------------------------------------------------------------------
function drawHatchedRect(ax, xc, y0, w, hgt, col, spacing, lw, slope)
%DRAWHATCHEDRECT  斜杠填充矩形（phase1 柱体 / 图例的斜杠键）
%   只画边框，内部画斜率为 slope 的平行线（数据单位）；
%   每条线解析裁剪：y - y0 = slope*(x - c)，只在矩形 [x0,x1]×[y0,y0+hgt] 内取段。
    if nargin < 9 || isempty(slope), slope = 1; end
    x0 = xc - w / 2; x1 = xc + w / 2;
    patch(ax, [x0, x1, x1, x0], [y0, y0, y0 + hgt, y0 + hgt], col, ...
        'FaceColor', 'none', 'EdgeColor', col, 'LineWidth', lw);
    if ~(hgt > 0), return; end
    dy = hgt / slope;                       % 一条线在矩形内跨越的 x 长度
    cc = (x0 - dy):spacing:x1;
    for k = 1:numel(cc)
        xs = max(x0, cc(k));
        xe = min(x1, cc(k) + dy);
        if xe > xs
            plot(ax, [xs, xe], y0 + slope * ([xs, xe] - cc(k)), ...
                'Color', col, 'LineWidth', lw);
        end
    end
end
