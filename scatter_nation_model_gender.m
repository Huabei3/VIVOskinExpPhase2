% ========================================================================
% scatter_nation_model_gender.m   （phase2 African 观察者：female × male 两个性别分组）
%
% 作用:
%   与原脚本 scatter_nation_AS_AF.m 的版式完全一致，只是把"两个观察者群体"
%   从 phase1(Asian) × phase2(African) 换成 phase2(AF) 内部按性别拆分的
%   female × male 两组：
%     一张图 = 2 个水平拼合的子图（(a) Preference、(b) Healthy），每个子图内画
%     同一场景（默认 hd65）下、按刺激模特族裔（AS / CA / SA / AF）聚合出的
%     50% 等偏好椭圆，共 4 个刺激族裔 × 2 个性别组 = 8 个椭圆：
%        female 观察者 : 虚线 + 空心圆心
%        male   观察者 : 实线 + 实心圆心
%   颜色只表示刺激族裔（一个族裔一个颜色），线型/圆心只表示观察者性别。
%   图例统一放在拼合图下方，在整块拼合宽度内水平居中。
%
% 数据来源（完整绝对路径）:
%   <P2_ROOT>\AnalyseResults_p\efit_p\unscaled\AF\{model}{i/r}\non_model\
%       {female|male}\{attribute_serial}\labNscore\labNscore_group{model}{i/r}{scene}.mat
%   例（用户指定的实例路径）:
%     D:\work\VIVOSkin_phase2\analyze\AnalyseResults_p\efit_p\unscaled\AF\
%       f04i\non_model\female\01Preference\labNscore\labNscore_groupf04ihd65.mat
%
%   {female|male} 的语义（见 utils\stressNfit_p.m 的 OBS_GENDER_MODE='split'
%   与 observer_gender_of）:
%     = 同一批 AF 观察者（10 位）按性别拆成的两个子集，各自算平均分、各自
%       生成 labNscore_group。AF: i_obs 1~5 -> male，6~10 -> female。
%     目前只有 AF / SA 定义了性别规则，而落盘的性别子目录只存在于 AF 下；
%     SA / CA / AS 没有 {female|male} 层，因此本脚本固定 obsNation = "AF"。
%     （注意: 这两个目录是"观察者性别"，不是刺激模特性别；刺激模特性别由
%      文件名的 f/m 前缀区分，在本脚本里只用于把 model 归到 4 个刺激族裔。）
%
%   每个子文件夹只存 2 个属性: 01Preference / 06Healthy，所以 ATTR_LIST 只能取 [1 6]。
%
%   两组都用"该族裔全部 model 在该场景的 33 个刺激点"合并后重新拟合，
%   缩放（相对亮度 rela / scaled）、p_ratio 过滤、拟合函数完全一致，
%   因此两个性别组的椭圆可以直接比较。
%
% 与原脚本的差异（其余全部保持不变）:
%   1) 不再读 phase1 工程（P1_ANALYSE）——只读 phase2 的 AF 性别子目录；
%      phase1 目录仍只用来借 LUT18（相对亮度缩放用的标定矩阵）。
%   2) 路径里多一层 {female|male}，位置在 {obsType} 之后、{attr} 之前。
%   3) p_ratio 偏斜过滤默认关闭（USE_PRATIO = false）。原因：
%      性别子集只有 5 位观察者，p_group 的取值只能是 {0, 0.2, ..., 1} 这类
%      粗量化值，原来给 phase1 定的 [0.1, 0.9] 阈值会大量误杀 female 组
%      （01Preference 下 female 被砍 43%、male 只被砍 3%），这种不对称
%      会直接制造出假的"性别差异"。需要复现老口径时把开关打开即可。
%      默认只做"该单元 p 无方差就跳过"的退化保护。
%
% 椭圆模型（my_ellipsoidfit3_dy）:
%   y = 1 / (1 + k6 * exp(sqrt(k1*dx^2 + k2*dy^2 + k3*dx*dy)))
%   50% 等值线:  k1*dx^2 + k2*dy^2 + k3*dx*dy = (ln(1/k6))^2
%   圆心 (a*, b*) = [par(4), par(5)]（拟合时被固定在偏好点评分的加权均值）
%
% 两种绘图模式（开关 DRAW_MODE，见第 1 节）:
%
%   DRAW_MODE = "ellipse"  —— 原逻辑（默认回退用这个）
%     用 {female|male} 的 labNscore 重新拟合 50% 等偏好椭圆，
%     画椭圆 + 椭圆圆心（圆心 = 拟合出的 a*b* = par(4:5)）。
%
%   DRAW_MODE = "mean"     —— MOS 均值版
%     不画椭圆、不画椭圆圆心，只 plot MOS 均值中心点。数据来源换成:
%       <ANALYSE_ROOT>\simple_mean\{Dtype}\{scale}\{obsNation}\
%         {model}{iOr}\non_model\{observer_gender}\{attribute_serial}\ellipPara\fitRes.mat
%     （由 stressNmean_MOS.m 产出）读取其中 parNr_all 的 hd65 行:
%       picname_check = "{model}{iOr}hd65"，iOr='i' 时它正好是第 5 行，
%       取该行的 parNr_all(i_row, 4:5) 作为 (a*, b*)。
%     每个 model 得到一个 mean_center；同一 {attribute} × {model nation} × {i/r}
%     下的全部 {model} 取平均（omitnan），每个 (族裔, 性别, 属性) 只画 1 个点，
%     所以图上的点数与 ellipse 模式一致，两种模式可直接对照。
%     xlim / ylim 不再按椭圆包围盒算，而是按实际用到的中心点范围重新适配，
%     刻度间隔也按该范围自动选（TICK_STEP 只对 ellipse 模式生效）。
%
% phase1 对比系列（开关 USE_PHASE1，见第 1 节）:
%   USE_PHASE1 = true 时，再把第一轮实验（phase1，Asian 观察者）的数据画进同一张图：
%     数据 : <P1_ROOT>\B_data_analysis\analyze\AnalyseResults_p\{Dtype}\{scale}\
%              {model}{iOr}\non_model\{attribute_serial}\labNscore\
%              labNscore_group{model}{iOr}{scene}.mat
%            （phase1 的 lab_group + p_group；p_group 是"高分 observer 比例"）
%     取法 : 每个 model 用 calculate_weighted_or_simple_mean 求质心 (= phase2 mean
%            模式同一套算法)，再对该 {attribute} × {model nation} × {i/r} 下全部
%            {model} 取平均 => 每个族裔 1 个点
%     画法 : 三角形 marker（^. 实心，与 phase2 的圆形区分），箭头用点线 ':'
%            （phase2 是 female 虚线 '--' / male 实线 '-'），颜色仍表示刺激族裔
%   phase1 只有一个观察者群体（没按性别拆分），所以每个族裔只多 1 个点。
%
% 输出:
%   ellip_pic_p\efit_p\nation2\rela\cmp_gender_AF\{iOr}\GENDER_{scene}.jpg
%   ellip_pic_p\efit_p\nation2\rela\cmp_gender_AF\{iOr}\GENDER_{scene}_arrow.jpg
%   ellip_pic_p\efit_p\nation2\rela\cmp_gender_AF\{iOr}\GENDER_{scene}_dC_dH.xlsx
%   DRAW_MODE="mean"    时文件名多加 _mean       （GENDER_{scene}_mean.jpg 等）
%   USE_PHASE1=true     时文件名再加 _with_phase1（放在 _arrow 之后）:
%     GENDER_{scene}{modeTag}_with_phase1.jpg
%     GENDER_{scene}{modeTag}_arrow_with_phase1.jpg
%   即 USE_PHASE1=false 的旧文件不会被覆盖。
%   （SAVE_FIT = true 时再落盘族裔级拟合参数，见第 3 节）
% ========================================================================
close all;
clc;
clear;
addpath("utils\")

C = p2_config();

%% ---------- 1. 开关 ----------
iOr          = "i";            % 本脚本只支持 i 组（21 个光源）
SCENE        = "hd65";         % 场景名（C.PICNAMES_I 之一）
obsNation    = "AF";           % 观察者族裔；只有 AF 有 {female|male} 子目录
obsType      = "non_model";    % 观察者类型
GENDER_LIST  = ["female", "male"];                 % 目录名 = 两组
GENDER_LABEL = {'Female observers', 'Male observers'};  % 图例文字
ATTR_LIST    = [1, 6];         % 子图属性：1 = Preference，6 = Healthy
PANEL_TAGS   = {'(a)', '(b)'}; % 子图右下角标号
USE_PRATIO   = false;          % 是否启用 p_ratio 偏斜过滤（见文件头说明 3）
PRATIO_RANGE = [0.1, 0.9];     % USE_PRATIO = true 时的保留区间
SAVE_FIT     = false;          % 是否把族裔级拟合结果落盘
SEED         = 0;              % 拟合初值随机，固定种子保证可复现
nPtEllipse   = 361;            % 椭圆采样点数
FONT_SIZE    = 16;             % 全局字号（轴标签 / 刻度 / 标题 / 图例 / 图内文字）
TICK_STEP    = 5;              % x / y 刻度间隔（两个方向强制一致）
LEGEND_ALIGN = 'center';       % 'center'（拼合图宽度内居中） | 'left'（左对齐）

% ---- 绘图模式（见文件头"两种绘图模式"）----
%   "ellipse" : 原逻辑 —— 用 labNscore 重新拟合椭圆，画椭圆 + 椭圆圆心
%   "mean"    : 只画 MOS 均值中心点 —— 读 simple_mean 下各 model 的 fitRes.mat，
%               取 parNr_all 的 hd65 行 (i_row, 4:5) 作为该 model 的 mean_center，
%               再对该 {attribute} × {model nation} × {i/r} 下全部 {model} 求平均，
%               每个 (族裔, 性别, 属性) 只画 1 个点；不画椭圆、不画椭圆圆心
DRAW_MODE    = "mean";

% 箭头图（图 2）图例里那支说明箭头的文字：起点 → 终点
%   放在第二排（和 Female/Male observers 同一排），两排条目数 4 : 3 更均衡
ARROW_KEY    = {'Preference', 'Health'};

% ---- 是否把 phase1 数据作为对比系列（见文件头"phase1 对比系列"）----
%   false : 只画 phase2（AF 观察者），输出文件名不带 _with_phase1
%   true  : 额外画 phase1（Asian 观察者）的质心：三角形 marker + 点线箭头，
%           图例多一排 "Phase-1 observers"，输出文件名加 _with_phase1
USE_PHASE1   = true;

if iOr ~= "i"
    error('scatter_nation_model_gender: 当前只支持 i 组（21 个光源）');
end
if ~ismember(lower(DRAW_MODE), ["ellipse", "mean"])
    error('scatter_nation_model_gender: DRAW_MODE 只能是 "ellipse" 或 "mean"（当前 = %s）', ...
        char(DRAW_MODE));
end
isMeanMode = strcmpi(DRAW_MODE, 'mean');
if isMeanMode
    modeTag = '_mean';         % mean 模式文件名加后缀，不覆盖 ellipse 模式的既有结果
else
    modeTag = '';
end
if USE_PHASE1
    p1Tag = '_with_phase1';    % 带 phase1 对比的文件名后缀（放在 _arrow 之后）
else
    p1Tag = '';
end
iPara = find(strcmp(C.PICNAMES_I, SCENE), 1);
if isempty(iPara)
    error('scatter_nation_model_gender: 场景 "%s" 不在 C.PICNAMES_I 里', char(SCENE));
end
nAttr = numel(ATTR_LIST);
nNat  = numel(C.STIM_NATIONS);
nG    = numel(GENDER_LIST);
if nG ~= 2
    error('scatter_nation_model_gender: GENDER_LIST 必须是恰好两个性别（female / male）');
end
rng(SEED);

%% ---------- 2. 根目录 + 公共资源 ----------
% 观察者族裔这一层：AnalyseResults_p\efit_p\unscaled\AF（椭圆拟合结果）
OBS_ROOT = fullfile(C.ANALYSE_ROOT, C.Dtype, C.scale_type_origin, obsNation);
if ~isfolder(OBS_ROOT)
    error('scatter_nation_model_gender: 观察者族裔目录不存在 -> %s', OBS_ROOT);
end

% MOS 均值结果的同层目录：AnalyseResults_p\simple_mean\efit_p\unscaled\AF
% （stressNmean_MOS.m 的产出，只多一层 simple_mean；DRAW_MODE="mean" 时读它）
MEAN_ROOT = fullfile(C.ANALYSE_ROOT, 'simple_mean', C.Dtype, C.scale_type_origin, obsNation);
if isMeanMode && ~isfolder(MEAN_ROOT)
    error(['scatter_nation_model_gender: MOS 均值目录不存在 -> %s\n' ...
        '请先运行 stressNmean_MOS.m 生成 simple_mean 结果，或把 DRAW_MODE 改回 "ellipse"'], ...
        MEAN_ROOT);
end
% 相对亮度缩放用的场景白点
P2_WHITE = fullfile(C.P2_ROOT, 'optimizedD', 'whiteSquare', 'XYZw_white');

% phase1（第一轮实验）的结果根目录：<P1_ROOT>\B_data_analysis\analyze\AnalyseResults_p
%   结构比 phase2 少一层 observer_nation，也没有 {female|male}：
%     {Dtype}\{scale}\{model}{iOr}\non_model\{attrSerial}\labNscore\labNscore_group{lp}{scene}.mat
P1_ANALYSE = fullfile(C.P1_ROOT, 'B_data_analysis', 'analyze', 'AnalyseResults_p');
P1_ROOTDIR = fullfile(P1_ANALYSE, C.Dtype, C.scale_type_origin);
if USE_PHASE1 && ~isfolder(P1_ROOTDIR)
    error(['scatter_nation_model_gender: 打开了 USE_PHASE1 但 phase1 结果目录不存在 -> %s\n' ...
        '把 USE_PHASE1 设为 false 可只画 phase2'], P1_ROOTDIR);
end

lutP2    = load(C.LUT_P2_FILE, 'XYZw');    % phase2 数据 => phase2 自己的显示标定
XYZw_LUT = lutP2.XYZw;
wd65     = C.WD65;

%% ---------- 3. 逐属性 × 逐族裔 × 逐性别：拟合椭圆 或 取 MOS 均值中心 ----------
parG  = nan(nNat, 6, nAttr, nG);     % parG(族裔, 6 参数, 属性, 性别组)
% mean 模式只填 par(4:5) = 该族裔全部 model 的 mean_center 平均值，par(1:3)/par(6) 保持 NaN
statG = struct('r',    nan(nNat, nAttr, nG), ...
               'nDot', zeros(nNat, nAttr, nG), ...
               'nSub', zeros(nNat, nAttr, nG), ...
               'pMin', nan(nNat, nAttr, nG), ...
               'pMax', nan(nNat, nAttr, nG));

% phase1 对比系列: 每个 (族裔, 属性) 一个中心点 (a*, b*) = 该族裔全部 model 质心的平均
cenP1  = nan(nNat, 2, nAttr);
statP1 = struct('nSub', zeros(nNat, nAttr));

for iA = 1:nAttr
    attr       = ATTR_LIST(iA);
    attrSerial = strcat(sprintf('%02d', attr), C.ATTRIBUTE_NAMES(attr));
    fprintf('\n[GENDER] ===== %s (%s) =====\n', char(attrSerial), char(SCENE));

    for iNat = 1:nNat
        models = C.STIM_MODELS{iNat};

        for iG = 1:nG
            if ~isMeanMode
                % ---- 原逻辑: 合并该族裔全部 model 的点, 重新拟合 50% 椭圆 ----
                [parG(iNat, :, iA, iG), statG.r(iNat, iA, iG), ...
                    statG.nDot(iNat, iA, iG), statG.nSub(iNat, iA, iG), ...
                    pRange] = ...
                    fitGroupDot(models, iOr, OBS_ROOT, GENDER_LIST(iG), obsType, ...
                    attrSerial, char(SCENE), iPara, P2_WHITE, XYZw_LUT, wd65, ...
                    SEED, USE_PRATIO, PRATIO_RANGE);

                if ~isempty(pRange)
                    statG.pMin(iNat, iA, iG) = pRange(1);
                    statG.pMax(iNat, iA, iG) = pRange(2);
                end
            else
                % ---- mean 模式: 读 simple_mean 的 fitRes.mat, 取 hd65 行的 4:5 ----
                % cenModel 为 nModel×2（每行 = 一个 model 的 mean_center, 缺文件则该行 NaN）
                cenModel = loadMeanCenters(models, iOr, MEAN_ROOT, GENDER_LIST(iG), ...
                    obsType, attrSerial, char(SCENE), iPara);

                okM = all(isfinite(cenModel), 2);          % 真正读到 mean_center 的 model
                statG.nSub(iNat, iA, iG) = nnz(okM);       % 复用 nSub 记"有效 model 数"
                if any(okM)
                    % 该 {attribute} × {model nation} × {i/r} 下全部 model 取平均
                    parG(iNat, 4:5, iA, iG) = mean(cenModel(okM, :), 1);
                end
            end
        end

        % ---- phase1 对比系列: 每个 model 求质心, 再对族裔内 model 取平均 ----
        if USE_PHASE1
            [cenModelP1, nP1] = loadPhase1Centers(models, iOr, P1_ROOTDIR, obsType, ...
                attrSerial, char(SCENE));
            statP1.nSub(iNat, iA) = nP1;
            okP1 = all(isfinite(cenModelP1), 2);
            if any(okP1)
                cenP1(iNat, :, iA) = mean(cenModelP1(okP1, :), 1);
            end
        end

        if ~isMeanMode
            fprintf(['  %-3s  female: %d 单元 %3d 点 r=%5.2f 圆心(%6.2f,%6.2f) p=[%.2f,%.2f] | ' ...
                'male: %d 单元 %3d 点 r=%5.2f 圆心(%6.2f,%6.2f) p=[%.2f,%.2f]\n'], ...
                char(C.STIM_NATIONS(iNat)), ...
                statG.nSub(iNat, iA, 1), statG.nDot(iNat, iA, 1), ...
                statG.r(iNat, iA, 1), parG(iNat, 4, iA, 1), parG(iNat, 5, iA, 1), ...
                statG.pMin(iNat, iA, 1), statG.pMax(iNat, iA, 1), ...
                statG.nSub(iNat, iA, 2), statG.nDot(iNat, iA, 2), ...
                statG.r(iNat, iA, 2), parG(iNat, 4, iA, 2), parG(iNat, 5, iA, 2), ...
                statG.pMin(iNat, iA, 2), statG.pMax(iNat, iA, 2));
        else
            fprintf(['  %-3s  female: %d/%d model 均值(%6.2f,%6.2f) | ' ...
                'male: %d/%d model 均值(%6.2f,%6.2f)\n'], ...
                char(C.STIM_NATIONS(iNat)), ...
                statG.nSub(iNat, iA, 1), numel(models), ...
                parG(iNat, 4, iA, 1), parG(iNat, 5, iA, 1), ...
                statG.nSub(iNat, iA, 2), numel(models), ...
                parG(iNat, 4, iA, 2), parG(iNat, 5, iA, 2));
        end
        if USE_PHASE1
            fprintf('        phase1: %d/%d model 均值(%6.2f,%6.2f)\n', ...
                statP1.nSub(iNat, iA), numel(models), ...
                cenP1(iNat, 1, iA), cenP1(iNat, 2, iA));
        end
    end
end

% ---- 可选：族裔级拟合结果落盘（默认不走，避免污染 AnalyseResults_p）----
if SAVE_FIT
    for iA = 1:nAttr
        attrSerial = strcat(sprintf('%02d', ATTR_LIST(iA)), ...
            C.ATTRIBUTE_NAMES(ATTR_LIST(iA)));
        for iG = 1:nG
            for iNat = 1:nNat
                if any(isnan(parG(iNat, :, iA, iG))), continue; end
                outDir = fullfile(C.ANALYSE_ROOT, C.Dtype, '50', C.scale_type_origin, ...
                    obsNation, sprintf('nation_gender_%s', char(GENDER_LIST(iG))), ...
                    'scaled', obsType, char(iOr), char(attrSerial), ...
                    sprintf('%02d%s', iNat, C.STIM_NATIONS(iNat)));
                if ~exist(outDir, 'dir'), mkdir(outDir); end
                par = parG(iNat, :, iA, iG);  %#ok<NASGU>
                r   = statG.r(iNat, iA, iG);  %#ok<NASGU>
                save(fullfile(outDir, sprintf('scene%02d.mat', iPara)), 'par', 'r');
            end
        end
    end
end

%% ---------- 4. 统一轴范围（两个子图、两个性别组共用） ----------
%   ellipse 模式: 范围 = 全部椭圆包围盒 ∪ 圆心
%   mean    模式: 范围 = 实际用到的 mean_center（各族裔 model 平均值）的最小/最大值
allX = [];
allY = [];
for iA = 1:nAttr
    for iNat = 1:nNat
        for iG = 1:nG
            if ~isMeanMode
                [xc, yc] = ellipsePoints50(parG(iNat, :, iA, iG), nPtEllipse);
                allX = [allX, xc, parG(iNat, 4, iA, iG)];   %#ok<AGROW>
                allY = [allY, yc, parG(iNat, 5, iA, iG)];   %#ok<AGROW>
            else
                allX = [allX, parG(iNat, 4, iA, iG)];       %#ok<AGROW>
                allY = [allY, parG(iNat, 5, iA, iG)];       %#ok<AGROW>
            end
        end
    end
end
% phase1 系列也要落在同一套轴范围里
if USE_PHASE1
    for iA = 1:nAttr
        for iNat = 1:nNat
            allX = [allX, cenP1(iNat, 1, iA)];   %#ok<AGROW>
            allY = [allY, cenP1(iNat, 2, iA)];   %#ok<AGROW>
        end
    end
end
allX = allX(isfinite(allX));
allY = allY(isfinite(allY));
if isempty(allX)
    if isMeanMode
        error(['scatter_nation_model_gender: 所有 mean_center 都读不到，请检查 simple_mean ' ...
            '结果是否存在（%s）'], MEAN_ROOT);
    end
    error('scatter_nation_model_gender: 两个性别组都没有可用的椭圆');
end

if ~isMeanMode
    lims    = [max(0, floor(min([allX, allY]) - 1)), ceil(max([allX, allY]) + 1)];
    tickUse = TICK_STEP;
else
    % mean 模式的点云范围通常只有几个单位（本处 ≈ 9.3~17.5）:
    %   先按跨度自动选刻度步长，再把轴范围对齐到步长的整数倍，
    %   这样刻度是干净的整数（8,10,...,18），不会出现 8,13,18 这种稀疏刻度。
    lo   = min([allX, allY]);
    hi   = max([allX, allY]);
    span = hi - lo;
    if span <= 0, span = 1; end
    tickUse = chooseTickStep(span);
    lims = [tickUse * floor((lo - 0.08 * span) / tickUse), ...
            tickUse * ceil((hi + 0.08 * span) / tickUse)];
    lims = round(lims, 6);        % 消掉浮点误差（0.5 步长时尤其明显）
end
fprintf('[GENDER] DRAW_MODE=%s | 轴范围 = [%g, %g] | 刻度间隔 = %g\n', ...
    char(DRAW_MODE), lims(1), lims(2), tickUse);

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
    drawPanel(axList(iA), parG(:, :, iA, 1), parG(:, :, iA, 2), natColors, lims, ...
        char(C.ATTRIBUTE_NAMES(ATTR_LIST(iA))), PANEL_TAGS{iA}, FONT_SIZE, tickUse, ...
        ~isMeanMode, USE_PHASE1, cenP1(:, :, iA));
end

%% ---------- 7. 图 1 的图例（拼合图下方，整块宽度内居中；族裔排成一排） ----------
modelLabels = cell(1, nNat);
for iNat = 1:nNat
    modelLabels{iNat} = sprintf('%s models', C.STIM_NATION_NAMES(iNat));
end
spanRect  = [LEFT_PX / szPx(1), 0, BLOCK_PX / szPx(1), 0];
if USE_PHASE1
    % 有 phase1 对比时多一排，整块上移并把三排的间距压匀
    top1 = 0.205;                % 第一排（模特族裔）图例的顶边
    top2 = 0.125;                % 第二排（性别组）图例的中心线
    top3 = 0.050;                % 第三排（phase1）图例的中心线
else
    top1 = 0.175;
    top2 = 0.060;
    top3 = [];
end
addLegends(h, natColors, modelLabels, GENDER_LABEL, spanRect, LEGEND_ALIGN, ...
    top1, top2, FONT_SIZE, USE_PHASE1, top3);

%% ---------- 8. 导出图 1 ----------
saveFolder = fullfile(C.PIC_ROOT, C.Dtype, 'nation2', 'rela', ...
    sprintf('cmp_gender_%s', obsNation), char(iOr));
if ~exist(saveFolder, 'dir'), mkdir(saveFolder); end
outFile = fullfile(saveFolder, strcat('GENDER_', char(SCENE), modeTag, p1Tag, '.jpg'));
% 用 print 而不是 exportgraphics：
%   exportgraphics 按"内容紧包围盒"裁切，图例一旦挤出坐标框，画布长宽比就变，
%   归一化坐标被压缩，子图与图例就错位；print 严格按纸张（= 窗口尺寸）导出，
%   配合 PaperPositionMode='auto' 可以把归一化坐标 1:1 映射到像素。
set(h, 'PaperPositionMode', 'auto');
print(h, outFile, '-djpeg', '-r300');
close(h);

%% ---------- 9. 图 2：Preference 中心 + "Preference 圆心 → Healthy 圆心" 位移箭头 ----------
%   ellipse 模式: 画 Preference 椭圆，箭头起点 = Preference 圆心，箭尖 = Healthy 圆心
%                 （Healthy 的椭圆不画）。female = 虚线箭头，male = 实线箭头。
%   mean    模式: 不画椭圆，只画 Preference 的 mean_center 点 + 同一支箭头
if nAttr < 2
    warning('scatter_nation_model_gender: 属性少于 2 个，跳过箭头图');
    outFile2 = '';
else
    iAPref = 1;                  % 椭圆 / 起点用第 1 个属性（Preference）
    iAHeal = 2;                  % 箭头终点用第 2 个属性（Healthy）

    h2 = figure('Color', 'white', 'Position', [60, 60, 1250, 900]);
    drawnow;
    sz2 = h2.Position(3:4);
    S2  = round(0.60 * sz2(2));
    L2  = round((sz2(1) - S2) / 2);
    B2  = sz2(2) - S2 - round(0.045 * sz2(2));
    ax2 = axes(h2, 'Position', [L2 / sz2(1), B2 / sz2(2), S2 / sz2(1), S2 / sz2(2)]);
    hold(ax2, 'on');
    drawArrowPanel(ax2, parG(:, :, iAPref, 1), parG(:, :, iAPref, 2), ...
        parG(:, :, iAHeal, 1), parG(:, :, iAHeal, 2), natColors, lims, ...
        FONT_SIZE, tickUse, ~isMeanMode, USE_PHASE1, ...
        cenP1(:, :, iAPref), cenP1(:, :, iAHeal));

    % 图例：第一排族裔颜色；第二排 = 性别线型 + 说明箭头（Preference → Health）
    %       USE_PHASE1 时第三排 = phase1 三角形 + 点线箭头说明
    span2 = [0.02, 0, 0.96, 0];
    addArrowFigureLegend(h2, natColors, modelLabels, GENDER_LABEL, span2, ...
        top1, top2, ARROW_KEY, FONT_SIZE, USE_PHASE1, top3);

    outFile2 = fullfile(saveFolder, strcat('GENDER_', char(SCENE), modeTag, '_arrow', p1Tag, '.jpg'));
    set(h2, 'PaperPositionMode', 'auto');
    print(h2, outFile2, '-djpeg', '-r300');
    close(h2);
end

%% ---------- 10. 圆心色度 C* / 色相 h* 的 female → male 增量，输出 xlsx ----------
%   C* = sqrt(a*^2 + b*^2)，h* = atan2d(b*, a*)（0~360°，Δh* 取最短角差）
nRowC = nAttr * nNat * nG;
tAttr = strings(nRowC, 1);
tNat  = strings(nRowC, 1);
tGen  = strings(nRowC, 1);
tA    = nan(nRowC, 1);
tB    = nan(nRowC, 1);
tC    = nan(nRowC, 1);
tH    = nan(nRowC, 1);
tNd   = nan(nRowC, 1);
tNs   = nan(nRowC, 1);
tPmin = nan(nRowC, 1);
tPmax = nan(nRowC, 1);

k = 0;
for iA = 1:nAttr
    for iNat = 1:nNat
        for iG = 1:nG
            parCur = parG(iNat, :, iA, iG);
            k = k + 1;
            tAttr(k) = string(C.ATTRIBUTE_NAMES(ATTR_LIST(iA)));
            tNat(k)  = string(C.STIM_NATIONS(iNat));
            tGen(k)  = string(GENDER_LIST(iG));
            tA(k)    = parCur(4);
            tB(k)    = parCur(5);
            tC(k)    = hypot(parCur(4), parCur(5));
            tH(k)    = mod(atan2d(parCur(5), parCur(4)), 360);
            tNd(k)   = statG.nDot(iNat, iA, iG);
            tNs(k)   = statG.nSub(iNat, iA, iG);
            tPmin(k) = statG.pMin(iNat, iA, iG);
            tPmax(k) = statG.pMax(iNat, iA, iG);
            if isMeanMode
                % mean 模式没有拟合点数 / p 取值范围；N_cells 此时含义是"参与平均的 model 数"
                tNd(k)   = NaN;
                tNs(k)   = statG.nSub(iNat, iA, iG);
                tPmin(k) = NaN;
                tPmax(k) = NaN;
            end
        end
    end
end

TabCenters = table(tAttr, tNat, tGen, tA, tB, tC, tH, tNd, tNs, tPmin, tPmax, ...
    'VariableNames', {'Attribute', 'ModelNation', 'ObsGender', 'a_star', 'b_star', ...
    'Chroma', 'Hue_deg', 'N_points', 'N_cells', 'p_min', 'p_max'});

% ---- 附加 phase1 对比列：同一 (属性, 族裔) 的 phase1 质心 ----
if USE_PHASE1
    p1A = nan(nRowC, 1);
    p1B = nan(nRowC, 1);
    k = 0;
    for iA = 1:nAttr
        for iNat = 1:nNat
            for iG = 1:nG
                k = k + 1;
                p1A(k) = cenP1(iNat, 1, iA);   % phase1 不分性别, 两行填同一值
                p1B(k) = cenP1(iNat, 2, iA);
            end
        end
    end
    TabCenters.a_star_phase1 = p1A;
    TabCenters.b_star_phase1 = p1B;
    TabCenters.dist_phase1_to_phase2 = hypot(tA - p1A, tB - p1B);
end

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
dDist  = nan(nRowD, 1);

k = 0;
allDC = [];
allDH = [];
for iA = 1:nAttr
    blkDC = nan(1, nNat);
    blkDH = nan(1, nNat);
    for iNat = 1:nNat
        p1 = parG(iNat, 4:5, iA, 1);      % female
        p2 = parG(iNat, 4:5, iA, 2);      % male
        c1 = hypot(p1(1), p1(2));
        c2 = hypot(p2(1), p2(2));
        h1 = mod(atan2d(p1(2), p1(1)), 360);
        h2 = mod(atan2d(p2(2), p2(1)), 360);
        k = k + 1;
        dAttr(k) = string(C.ATTRIBUTE_NAMES(ATTR_LIST(iA)));
        dNat(k)  = string(C.STIM_NATIONS(iNat));
        dC1(k) = c1;  dC2(k) = c2;  dDC(k) = c2 - c1;
        dH1(k) = h1;  dH2(k) = h2;  dDH(k) = wrapDeg180(h2 - h1);
        dDist(k) = norm(p2 - p1);
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

TabDelta = table(dAttr, dNat, dC1, dC2, dDC, dH1, dH2, dDH, dDist, 'VariableNames', ...
    {'Attribute', 'ModelNation', 'Chroma_Female', 'Chroma_Male', 'dChroma', ...
     'Hue_Female_deg', 'Hue_Male_deg', 'dHue_deg', 'CenterDist'});

% 便于阅读的圆整版本（另存一个 sheet）
TabDeltaR = TabDelta;
numVars = {'Chroma_Female', 'Chroma_Male', 'dChroma', 'Hue_Female_deg', ...
    'Hue_Male_deg', 'dHue_deg', 'CenterDist'};
for v = 1:numel(numVars)
    TabDeltaR.(numVars{v}) = round(TabDeltaR.(numVars{v}), 2);
end
TabCentersR = TabCenters;
numVarsC = {'a_star', 'b_star', 'Chroma', 'Hue_deg', 'p_min', 'p_max', ...
    'a_star_phase1', 'b_star_phase1', 'dist_phase1_to_phase2'};
for v = 1:numel(numVarsC)
    if ismember(numVarsC{v}, TabCentersR.Properties.VariableNames)
        TabCentersR.(numVarsC{v}) = round(TabCentersR.(numVarsC{v}), 2);
    end
end

xlsxFile = fullfile(saveFolder, strcat('GENDER_', char(SCENE), modeTag, p1Tag, '_dC_dH.xlsx'));
if isfile(xlsxFile), delete(xlsxFile); end
writetable(TabCentersR, xlsxFile, 'Sheet', 'centers');
writetable(TabDeltaR,  xlsxFile, 'Sheet', 'delta_female_to_male');

%% ---------- 11. 终端小结 ----------
for iA = 1:nAttr
    fprintf('\n[GENDER] %s 场景 / %s，圆心 (a*, b*) 与位移:\n', char(SCENE), ...
        char(strcat(sprintf('%02d', ATTR_LIST(iA)), C.ATTRIBUTE_NAMES(ATTR_LIST(iA)))));
    if USE_PHASE1
        fprintf('  %-4s  %-18s  %-18s  %-18s  %s\n', 'NAT', 'female', 'male', ...
            'phase1', 'dist f-m');
    else
        fprintf('  %-4s  %-18s  %-18s  %s\n', 'NAT', 'female', 'male', 'dist');
    end
    for iNat = 1:nNat
        p1 = parG(iNat, 4:5, iA, 1);
        p2 = parG(iNat, 4:5, iA, 2);
        if USE_PHASE1
            fprintf('  %-4s  (%6.2f, %6.2f)    (%6.2f, %6.2f)    (%6.2f, %6.2f)    %6.2f\n', ...
                char(C.STIM_NATIONS(iNat)), p1(1), p1(2), p2(1), p2(2), ...
                cenP1(iNat, 1, iA), cenP1(iNat, 2, iA), norm(p2 - p1));
        else
            fprintf('  %-4s  (%6.2f, %6.2f)    (%6.2f, %6.2f)    %6.2f\n', ...
                char(C.STIM_NATIONS(iNat)), p1(1), p1(2), p2(1), p2(2), norm(p2 - p1));
        end
    end
end
fprintf('\n[GENDER] dC* / dh* (female -> male):\n');
fprintf('  %-14s  %-26s  %8s  %8s\n', 'Attribute', 'ModelNation', 'dC*', 'dh*');
for i = 1:height(TabDeltaR)
    fprintf('  %-14s  %-26s  %8.2f  %8.2f\n', char(TabDeltaR.Attribute(i)), ...
        char(TabDeltaR.ModelNation(i)), TabDeltaR.dChroma(i), TabDeltaR.dHue_deg(i));
end
if isMeanMode
    fprintf('\n[GENDER] 数据源: %s\n', MEAN_ROOT);
else
    fprintf('\n[GENDER] 数据源: %s\n', OBS_ROOT);
end
fprintf('[GENDER] 出图: %s\n', outFile);
if ~isempty(outFile2)
    fprintf('[GENDER] 箭头图: %s\n', outFile2);
end
fprintf('[GENDER] 增量表: %s\n', xlsxFile);

% ========================================================================
% 局部函数
% ========================================================================
function [par, r, nDot, nSub, pRange] = fitGroupDot(models, iOr, obsRoot, gender, ...
    obsType, attrSerial, scene, iPara, whiteDir, XYZw_LUT, wd65, seed, ...
    usePratio, pRatioRange)
%FITGROUPDOT  把某族裔全部 model 在某场景的 33 个刺激点合并后拟合 50% 椭圆
%   models     : 该刺激族裔的 model 编号（不含 i/r 后缀）
%   obsRoot    : 观察者族裔根目录 ...\{Dtype}\{scale}\AF
%   gender     : 'female' | 'male'（观察者性别子目录名）
%   whiteDir   : XYZw_white 所在目录（{lp}.mat）
%   返回 par(1×6)、相关系数 r、参与拟合的点数、合并的 model 数、p 的取值范围
%   数据文件:
%     obsRoot\{lp}\{obsType}\{gender}\{attrSerial}\labNscore\
%         labNscore_group{lp}{scene}.mat
    par    = nan(1, 6);
    r      = NaN;
    nSub   = 0;
    pRange = [];
    labAll = [];
    pAll   = [];

    for m = 1:numel(models)
        lp = char(models(m) + iOr);

        f = fullfile(obsRoot, lp, obsType, char(gender), char(attrSerial), ...
            'labNscore', strcat('labNscore_group', lp, scene, '.mat'));
        if ~isfile(f), continue; end

        S = load(f, 'lab_group', 'p_group');
        if ~isfield(S, 'lab_group') || ~isfield(S, 'p_group'), continue; end
        labCur = S.lab_group;      % 33×3
        pCur   = S.p_group;        % 33×1
        if size(labCur, 1) ~= size(pCur, 1), continue; end

        % 统计退化保护：该单元 33 个点的 p 完全一致时椭圆无法定义
        if numel(unique(pCur)) < 2
            fprintf('  [skip] %s/%s p 无方差（全部 = %.2f）\n', lp, gender, pCur(1));
            continue
        end

        % 评分分布过度偏斜的单元不参与（老口径，默认关闭，见文件头说明 3）
        if usePratio
            pRatio = nnz(pCur > 0.5) / numel(pCur);
            if pRatio < pRatioRange(1) || pRatio > pRatioRange(2)
                fprintf('  [skip] %s/%s 评分偏斜 (p_ratio=%.2f)\n', lp, gender, pRatio);
                continue
            end
        end

        % 相对亮度缩放（phase2 的 scale 与 phase1 的 rela 是同一件事）
        wFile = fullfile(whiteDir, [lp '.mat']);
        if ~isfile(wFile), continue; end
        W = load(wFile, 'XYZw_white');
        labCur = scaleLabToScene(labCur, XYZw_LUT, W.XYZw_white(iPara, 2), wd65);

        labAll = [labAll; labCur];   %#ok<AGROW>
        pAll   = [pAll;   pCur];     %#ok<AGROW>
        nSub   = nSub + 1;
    end

    if nSub == 0
        warning('scatter_nation_model_gender: %s / %s 一个文件都没读到 -> %s', ...
            char(attrSerial), char(gender), ...
            fullfile(obsRoot, obsType, char(gender), char(attrSerial), 'labNscore'));
        return
    end

    ok = ~any(isnan([labAll, pAll]), 2);
    labAll = labAll(ok, :);
    pAll   = pAll(ok);
    nDot   = numel(pAll);
    if nDot < 10, return; end
    pRange = [min(pAll), max(pAll)];

    [parMean, ~] = calculate_weighted_or_simple_mean(pAll, labAll);
    meanCen      = [mean(labAll(:, 1), 'omitnan'), parMean(1, 4:5)];
    rng(seed);
    evalc('[parFit, r, y] = my_ellipsoidfit3_dy(labAll, pAll, meanCen);');   %#ok<ASGLU>
    par = parFit(1, 1:6);
end

% ------------------------------------------------------------------------
function cen = loadMeanCenters(models, iOr, meanRoot, gender, obsType, attrSerial, scene, iPara)
%LOADMEANCENTERS  读 simple_mean 的 fitRes.mat，取每个 model 的 MOS 均值中心
%   meanRoot   : ...\AnalyseResults_p\simple_mean\{Dtype}\{scale}\{obsNation}
%   gender     : 'female' | 'male'（观察者性别子目录名）
%   返回 cen = nModel×2，每行 = 一个 model 在该 {attribute}{scene} 上的 (a*, b*)
%       数据文件:
%         meanRoot\{lp}\{obsType}\{gender}\{attrSerial}\ellipPara\fitRes.mat
%       取值: parNr_all 中 picname_check = "{lp}{scene}" 的那一行（i 组的 hd65 = 第 5 行）
%             的 (i_row, 4:5)；该行缺数据（NaN）或文件不存在 => 该行记 NaN
    cen = nan(numel(models), 2);
    for m = 1:numel(models)
        lp = char(models(m) + iOr);
        f  = fullfile(meanRoot, lp, obsType, char(gender), char(attrSerial), ...
            'ellipPara', 'fitRes.mat');
        if ~isfile(f)
            fprintf('  [miss] %s/%s/%s: fitRes.mat 不存在\n', lp, char(gender), char(attrSerial));
            continue
        end
        S = load(f, 'parNr_all', 'picname_check');
        if ~isfield(S, 'parNr_all') || isempty(S.parNr_all), continue; end

        iRow = findSceneRow(S, lp, scene, iPara);
        if isempty(iRow), continue; end
        v = S.parNr_all(iRow, 4:5);
        if any(~isfinite(v))
            fprintf('  [miss] %s/%s/%s: %s 行的 (4:5) 是 NaN\n', ...
                lp, char(gender), char(attrSerial), char(strcat(lp, scene)));
            continue
        end
        cen(m, :) = v;
    end
end

% ------------------------------------------------------------------------
function iRow = findSceneRow(S, lp, scene, iPara)
%FINDSCENEROW  在 fitRes.mat 的 picname_check 里找 "{lp}{scene}" 对应行号
%   正常情况下 picname_check 长度 = 场景数（i 组 21 行），hd65 是第 5 行；
%   这里按名字匹配而不是硬编码行号，遇到 r 组 / 改名也能对上。
%   picname_check 缺失或匹配不到时才退回"行号 = 场景序号"（iPara）。
    iRow   = [];
    target = string(strcat(lp, scene));      % 例 "f04ihd65"
    if isfield(S, 'picname_check') && ~isempty(S.picname_check)
        pc = S.picname_check;
        if ischar(pc) || isstring(pc), pc = cellstr(pc); end
        for k = 1:numel(pc)
            % stressNmean_MOS.m 落盘时 picname_check 的元素是 string（strcat 字符串拼出），
            % 所以这里统一转 string 再比较，不能只判 ischar
            if ischar(pc{k}) || isstring(pc{k})
                if strcmpi(string(pc{k}), target)
                    iRow = k;
                    return
                end
            end
        end
        warning('scatter_nation_model_gender:rowFallback', ...
            '%s: picname_check 里没有 %s，退回按场景序号取第 %d 行', ...
            lp, char(target), iPara);
    end
    if isempty(iRow) && iPara <= size(S.parNr_all, 1)
        iRow = iPara;
    end
end

% ------------------------------------------------------------------------
function [cen, nSub] = loadPhase1Centers(models, iOr, p1RootDir, obsType, attrSerial, scene)
%LOADPHASE1CENTERS  读 phase1 的 labNscore，算每个 model 的偏好质心（对比系列用）
%   p1RootDir : <P1_ROOT>\B_data_analysis\analyze\AnalyseResults_p\{Dtype}\{scale}
%   phase1 的结构比 phase2 少两层（没有 observer_nation，也没有 {female|male}）:
%     p1RootDir\{lp}\{obsType}\{attrSerial}\labNscore\labNscore_group{lp}{scene}.mat
%   phase1 没有 simple_mean 结果，所以这里用与 phase2 mean 模式完全相同的算法:
%     calculate_weighted_or_simple_mean(p_group, lab_group) -> 质心 (a*, b*) = par(4:5)
%   注意: phase1 的 p_group 是"打高分 observer 的比例"（0,0.1,...,1），
%         phase2 mean 模式的 p_group 是 MOS；两者都按 p 加权求质心，口径一致。
%   返回 cen = nModel×2（缺失记 NaN）；nSub = 真正读到的 model 数
    cen  = nan(numel(models), 2);
    nSub = 0;
    for m = 1:numel(models)
        lp = char(models(m) + iOr);
        f  = fullfile(p1RootDir, lp, obsType, char(attrSerial), 'labNscore', ...
            strcat('labNscore_group', lp, scene, '.mat'));
        if ~isfile(f), continue; end

        S = load(f, 'lab_group', 'p_group');
        if ~isfield(S, 'lab_group') || ~isfield(S, 'p_group'), continue; end
        labCur = S.lab_group;
        pCur   = S.p_group;
        if size(labCur, 1) ~= size(pCur, 1), continue; end

        ok = ~any(isnan([labCur, pCur]), 2);
        if nnz(ok) < 10, continue; end
        [parMean, ~] = calculate_weighted_or_simple_mean(pCur(ok), labCur(ok, :));
        v = parMean(1, 4:5);
        if any(~isfinite(v)), continue; end

        cen(m, :) = v;
        nSub = nSub + 1;
    end
end

% ------------------------------------------------------------------------
function step = chooseTickStep(span)
%CHOOSETICKSTEP  按轴跨度自动选刻度间隔（mean 模式点云跨度小，固定 5 会只剩 1~2 条刻度）
%   目标: 大约 4~6 个间隔；从常用步长里挑第一个 >= span/5 的
%   span : 数据本身的跨度（不含留边）
    cand = [0.5, 1, 2, 5, 10, 20, 50, 100];
    idx  = find(cand >= span / 5, 1);
    if isempty(idx)
        step = span / 5;
    else
        step = cand(idx);
    end
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
function drawPanel(ax, parF, parM, natColors, lims, panelTitle, tag, fontSize, tickStep, ...
    showEllipse, showP1, cenP1)
%DRAWPANEL  画一个子图：椭圆（可选）+ 圆心/均值中心 + phase1 三角（可选）+ 45° 线 + 轴设置
%   parF / parM : nNat×6，female / male 观察者的参数（同一下标 = 同一刺激族裔）
%                 ellipse 模式 = 拟合出的 6 个椭圆参数
%                 mean    模式 = 只填 par(4:5)（该族裔全部 model 的 mean_center 平均）
%   tickStep    : x / y 共用的刻度间隔（MATLAB 自动刻度可能给 10 和 5，必须强制统一）
%   showEllipse : true = 画 50% 椭圆（ellipse 模式）；false = 只画中心点（mean 模式）
%   showP1      : true = 再画 phase1 对比点（三角形）
%   cenP1       : nNat×2，phase1 每个族裔的质心 (a*, b*)；showP1=false 时可为空
    nNat  = size(parF, 1);
    range = lims(2) - lims(1);
    if showEllipse
        mSize = 6;                   % 椭圆圆心
    else
        mSize = 9;                   % mean_center 单独一个点，画大一点
    end
    if nargin < 12 || isempty(cenP1)
        cenP1 = nan(nNat, 2);
    end

    % ---- 45° 等色相参考线 ----
    xLine = linspace(lims(1), lims(2), 100);
    plot(ax, xLine, xLine, 'Color', [0.4 0.4 0.4], 'LineStyle', '--');
    text(ax, lims(2) - 0.02 * range, lims(2) - 0.03 * range, '45°', ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', ...
        'FontSize', fontSize, 'Color', [0.3 0.3 0.3]);

    for iNat = 1:nNat
        col = natColors(iNat, :);

        % ---- 50% 椭圆: 只有 ellipse 模式才画 ----
        if showEllipse
            [x1, y1] = ellipsePoints50(parF(iNat, :), 361);
            if ~isempty(x1)
                plot(ax, x1, y1, 'Color', col, 'LineStyle', '--', 'LineWidth', 1.6);
            end
            [x2, y2] = ellipsePoints50(parM(iNat, :), 361);
            if ~isempty(x2)
                plot(ax, x2, y2, 'Color', col, 'LineStyle', '-', 'LineWidth', 1.6);
            end
        end

        % ---- 圆心 / mean_center: 两种模式都画 ----
        % female: 空心圆（ellipse 模式 = 椭圆圆心，mean 模式 = 各族裔 model 中心的平均）
        if all(isfinite(parF(iNat, 4:5)))
            plot(ax, parF(iNat, 4), parF(iNat, 5), 'o', 'MarkerSize', mSize, ...
                'MarkerEdgeColor', col, 'MarkerFaceColor', 'none', 'LineWidth', 1.4);
        end
        % male: 实心圆
        if all(isfinite(parM(iNat, 4:5)))
            plot(ax, parM(iNat, 4), parM(iNat, 5), 'o', 'MarkerSize', mSize, ...
                'MarkerEdgeColor', col, 'MarkerFaceColor', col, 'LineWidth', 1.4);
        end

        % ---- phase1 对比点: 三角形（实心），与 phase2 的圆形区分 ----
        if showP1 && all(isfinite(cenP1(iNat, :)))
            plot(ax, cenP1(iNat, 1), cenP1(iNat, 2), '^', 'MarkerSize', mSize + 2, ...
                'MarkerEdgeColor', 0.55 * col, 'MarkerFaceColor', col, 'LineWidth', 1.2);
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
function addLegends(fig, natColors, modelLabels, genderLabels, spanRect, alignMode, ...
    top1, top2, fontSize, showP1, top3)
%ADDLEGENDS  说明行：第一排族裔颜色（legend），第二排观察者性别，第三排可选 phase1
%   spanRect    : 对齐参照 [x0 0 w 0]，每排都在这个宽度内居中 / 左对齐
%   alignMode   : 'center' 居中 | 'left' 左对齐
%   top1 / top2 : 第一排图例顶边 / 第二排中心线的 y（figure 归一化坐标）
%   fontSize    : 图例字号（与轴标签、刻度统一）
%   showP1      : true = 再加第三排（phase1 三角）
%   top3        : 第三排中心线的 y
%   注意: 同一个 axes 只能有一个 legend 对象（第二次调用 legend 会直接覆盖
%         第一个），所以第二/三排的"线型 + marker + 文字"改成手绘，避免互相吃掉。
    if nargin < 10 || isempty(showP1), showP1 = false; end
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

    % ---- 第二排：观察者性别（手绘：线段 + 圆心 + 文字） ----
    drawGenderRow(axO, genderLabels, spanRect, top2, fontSize, alignMode);

    % ---- 第三排：phase1（点线 + 实心三角） ----
    if showP1 && ~isempty(top3)
        drawPhase1Row(axO, 'Phase-1 observers (Asian)', spanRect, top3, fontSize, alignMode);
    end
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
function xEnd = drawStyleRow(axO, labels, spanRect, yRow, fontSize, alignMode, extraW, ...
    styles, faces, marker)
%DRAWSTYLEROW  画一行"线段 + marker + 文字"的图例条目（数量任意）
%   labels  : 1×n cellstr 文字
%   extraW  : 本行右侧还要接着画的另一块内容的宽度（箭头图里是 Preference → Health），
%             只参与居中计算；返回的 xEnd 就是那块内容的起点
%   styles  : 1×n cellstr 线型（'--' / '-' / ':' ...）
%   faces   : 1×n cell  marker 填充色；空 [] 表示用文字同色的实心
%   marker  : marker 形状（'o' / '^' ...）
    if nargin < 7 || isempty(extraW)
        extraW = 0;
    end
    col  = [0.25 0.25 0.25];
    segL = 0.050;                    % 线段长度（figure 归一化）
    gapT = 0.012;                    % 线段与文字的间距
    gapM = 0.060;                    % 相邻两组说明之间的间距
    n    = numel(labels);

    hLine = gobjects(1, n);
    hMark = gobjects(1, n);
    hText = gobjects(1, n);
    wText = zeros(1, n);
    for i = 1:n
        fc = faces{i};
        if isempty(fc), fc = col; end
        hLine(i) = plot(axO, [0, 0], [yRow, yRow], styles{i}, 'Color', col, 'LineWidth', 1.4);
        hMark(i) = plot(axO, 0, yRow, marker, 'MarkerSize', 8, ...
            'MarkerEdgeColor', col, 'MarkerFaceColor', fc, 'LineWidth', 1.2);
        hText(i) = text(axO, 0, yRow, labels{i}, 'FontSize', fontSize, ...
            'VerticalAlignment', 'middle', 'Color', [0.15 0.15 0.15]);
        wText(i) = hText(i).Extent(3);          % 文字宽度（figure 归一化）
    end

    blk   = n * (segL + gapT) + sum(wText) + gapM;   % 本行自身宽度（含末尾 gapM）
    total = blk + extraW;                            % 加上右侧那块内容后再居中
    if strcmpi(alignMode, 'center')
        x0 = spanRect(1) + (spanRect(3) - total) / 2;
    else
        x0 = spanRect(1);
    end
    for i = 1:n
        set(hLine(i), 'XData', [x0, x0 + segL], 'YData', [yRow, yRow]);
        set(hMark(i), 'XData', x0 + segL / 2, 'YData', yRow);
        set(hText(i), 'Position', [x0 + segL + gapT, yRow, 0]);
        x0 = x0 + segL + gapT + wText(i) + gapM;
    end
    xEnd = x0;      % 循环结束后 x0 已越过末尾的 gapM，正好是右侧内容的起点
end

% ------------------------------------------------------------------------
function xEnd = drawGenderRow(axO, genderLabels, spanRect, yRow, fontSize, alignMode, extraW)
%DRAWGENDERROW  观察者性别说明行：虚线+空心圆 = female，实线+实心圆 = male
    if nargin < 7, extraW = 0; end
    xEnd = drawStyleRow(axO, genderLabels, spanRect, yRow, fontSize, alignMode, extraW, ...
        {'--', '-'}, {'none', []}, 'o');
end

% ------------------------------------------------------------------------
function xEnd = drawPhase1Row(axO, label, spanRect, yRow, fontSize, alignMode, extraW)
%DRAWPHASE1ROW  phase1 说明行：点线 + 实心三角形 = phase1 观察者（不按性别拆分）
    if nargin < 7, extraW = 0; end
    xEnd = drawStyleRow(axO, {label}, spanRect, yRow, fontSize, alignMode, extraW, ...
        {':'}, {[]}, '^');
end

% ------------------------------------------------------------------------
function addArrowFigureLegend(fig, natColors, modelLabels, genderLabels, spanRect, ...
    top1, top2, keyLabels, fontSize, showP1, top3)
%ADDARROWFIGURELEGEND  箭头图的图例（每排各自居中）：
%   第一排 = 族裔颜色（4 个族裔，legend）
%   第二排 = 性别线型（虚线 = female，实线 = male）+ 说明箭头 "Preference → Health"
%   第三排 = 仅 USE_PHASE1 时出现：phase1 三角 + 点线箭头说明
%   把箭头说明从第一排挪到第二排，两排条目数接近（4 : 3），视觉上更均衡。
    if nargin < 10 || isempty(showP1), showP1 = false; end
    axO = axes(fig, 'Position', [0 0 1 1], 'Visible', 'off', ...
        'XLim', [0 1], 'YLim', [0 1]);
    hold(axO, 'on');

    % ---- 第一排：族裔颜色，单独在 spanRect 内居中 ----
    lg1 = drawNationLegend(axO, natColors, modelLabels, fontSize);
    drawnow;
    p1 = lg1.Position;
    lg1.Position = [spanRect(1) + (spanRect(3) - p1(3)) / 2, top1 - p1(4), p1(3), p1(4)];

    % ---- 第二排：性别（手绘）+ 说明箭头，作为一整块一起居中 ----
    %   先量箭头说明的宽度（临时 text），把它计入居中计算，再把它的起点交给 genderRow 返回
    wKey = measureArrowKey(axO, keyLabels, fontSize);
    xKey = drawGenderRow(axO, genderLabels, spanRect, top2, fontSize, 'center', wKey);
    drawArrowKey(axO, fig, keyLabels, xKey, top2, fontSize, '-');

    % ---- 第三排：phase1 三角 + 点线箭头说明 ----
    if showP1 && ~isempty(top3)
        xKey1 = drawPhase1Row(axO, 'Phase-1 observers (Asian)', spanRect, top3, ...
            fontSize, 'center', wKey);
        drawArrowKey(axO, fig, keyLabels, xKey1, top3, fontSize, ':');
    end
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
function drawArrowKey(axO, fig, keyLabels, xLeft, yMid, fontSize, lineStyle)
%DRAWARROWKEY  画一支图例用的说明箭头：左端文字 = 起点含义，箭尖文字 = 终点含义
%   lineStyle : 箭杆线型（phase2 用 '-'，phase1 用 ':'）
    if nargin < 7 || isempty(lineStyle), lineStyle = '-'; end
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

    plot(axO, [xa, xb], [yMid, yMid], lineStyle, 'Color', col, 'LineWidth', 1.4);
    hx = 9 / fig.Position(3);
    hy = 9 / fig.Position(4);
    patch(axO, [xb, xb - hx, xb - hx], [yMid, yMid + hy * 0.5, yMid - hy * 0.5], ...
        col, 'EdgeColor', 'none');
end

% ------------------------------------------------------------------------
function drawArrowPanel(ax, parPrefF, parPrefM, parHealF, parHealM, natColors, lims, ...
    fontSize, tickStep, showEllipse, showP1, cenP1Pref, cenP1Heal)
%DRAWARROWPANEL  图 2 的面板：Preference 中心 + 指向 Healthy 中心的箭头
%   parPrefF/M : female / male 观察者在 Preference 上的参数（ellipse 模式下才画椭圆）
%   parHealF/M : 同两个性别组在 Healthy 上的参数（只取中心作箭尖，不画椭圆）
%   tickStep   : x / y 共用的刻度间隔
%   showEllipse: true = 画 Preference 椭圆；false = 只画中心点（mean 模式）
%   showP1     : true = 再画 phase1 系列（三角形 + 点线箭头）
%   cenP1Pref  : nNat×2，phase1 在 Preference 上的质心
%   cenP1Heal  : nNat×2，phase1 在 Healthy 上的质心（只作箭尖）
    nNat  = size(parPrefF, 1);
    range = lims(2) - lims(1);
    headLen = 0.025 * range;         % 箭头头部尺寸（圆心位移一般只有 1~4，头部不能太大）
    if showEllipse
        mSize = 6;
    else
        mSize = 9;
    end
    % 形参一共 13 个（ax + 12 个），缺省兜底只看第 12/13 个是否真的传进来。
    % 注意: 原写成 nargin < 14 会把正常传入的 cenP1Pref/cenP1Heal 覆盖成 NaN，
    %       导致 phase1 的三角形和点线箭头一个都画不出来（图 1 的参数个数刚好对上，未受影响）。
    if nargin < 12 || isempty(cenP1Pref), cenP1Pref = nan(nNat, 2); end
    if nargin < 13 || isempty(cenP1Heal), cenP1Heal = nan(nNat, 2); end

    % ---- 45° 等色相参考线 ----
    xLine = linspace(lims(1), lims(2), 100);
    plot(ax, xLine, xLine, 'Color', [0.4 0.4 0.4], 'LineStyle', '--');
    text(ax, lims(2) - 0.02 * range, lims(2) - 0.03 * range, '45°', ...
        'VerticalAlignment', 'top', 'HorizontalAlignment', 'right', ...
        'FontSize', fontSize, 'Color', [0.3 0.3 0.3]);

    for iNat = 1:nNat
        col = natColors(iNat, :);

        % ---- Preference 椭圆：只有 ellipse 模式才画（female 虚线、male 实线）----
        if showEllipse
            [x1, y1] = ellipsePoints50(parPrefF(iNat, :), 361);
            if ~isempty(x1)
                plot(ax, x1, y1, 'Color', col, 'LineStyle', '--', 'LineWidth', 1.6);
            end
            [x2, y2] = ellipsePoints50(parPrefM(iNat, :), 361);
            if ~isempty(x2)
                plot(ax, x2, y2, 'Color', col, 'LineStyle', '-', 'LineWidth', 1.6);
            end
        end

        % ---- Preference 中心：两种模式都画（female 空心、male 实心）----
        if all(isfinite(parPrefF(iNat, 4:5)))
            plot(ax, parPrefF(iNat, 4), parPrefF(iNat, 5), 'o', 'MarkerSize', mSize, ...
                'MarkerEdgeColor', col, 'MarkerFaceColor', 'none', 'LineWidth', 1.4);
        end
        if all(isfinite(parPrefM(iNat, 4:5)))
            plot(ax, parPrefM(iNat, 4), parPrefM(iNat, 5), 'o', 'MarkerSize', mSize, ...
                'MarkerEdgeColor', col, 'MarkerFaceColor', col, 'LineWidth', 1.4);
        end

        % ---- 箭头：Preference 中心 -> Healthy 中心 ----
        drawArrow(ax, parPrefF(iNat, 4:5), parHealF(iNat, 4:5), col, headLen, '--');
        drawArrow(ax, parPrefM(iNat, 4:5), parHealM(iNat, 4:5), col, headLen, '-');

        % ---- phase1 对比: 三角形点 + 点线箭头（与 phase2 的虚线/实线区分）----
        if showP1 && all(isfinite(cenP1Pref(iNat, :)))
            plot(ax, cenP1Pref(iNat, 1), cenP1Pref(iNat, 2), '^', ...
                'MarkerSize', mSize + 2, 'MarkerEdgeColor', 0.55 * col, ...
                'MarkerFaceColor', col, 'LineWidth', 1.2);
            drawArrow(ax, cenP1Pref(iNat, :), cenP1Heal(iNat, :), col, headLen, ':');
        end
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
%   p0 : 起点（Preference 中心）  p1 : 箭尖（Healthy 中心）
%   任一端点缺失（NaN）就不画，避免 mean 模式下个别 model 缺数据时报错
    if any(~isfinite(p0)) || any(~isfinite(p1)), return; end
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
