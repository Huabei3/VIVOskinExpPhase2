function D = p2_load_labfit(obsNation, iOr, opts)
%P2_LOAD_LABFIT  加载 phase2 的椭圆拟合结果，组装成与 phase1 同构的张量
%
%   模块: utils / 数据加载（所有出图脚本共用）
%   用法: D = p2_load_labfit('AF', 'i')
%         D = p2_load_labfit('AF', 'r', struct('lightness','scale'))
%
%   输入:
%     obsNation : 观察者族裔 'AF' / 'SA' ...（数据路径上的那一层）
%     iOr       : 'i'（21 个光源）或 'r'（14 个实景）
%     opts      : 结构体，可含字段
%                 .obsType   观察者类型，默认 'non_model'
%                 .lightness 'raw' | 'scale' | 'cat' | 'cat_scale'，默认 'raw'
%                 .verbose   是否打印进度，默认 true
%
%   输出 D 的关键字段:
%     .lastParts  1×nSub  20 个刺激组（{f/m}01..10 + i/r）
%     .stimNation 1×nSub  每组所属刺激族裔（AS/CA/SA/AF）
%     .stimIdx    1×4    各族裔在 lastParts 中的下标（与 config.STIM_NATIONS 同序）
%     .attributes 1×nAttr 实际请求的属性槽位（1..10）
%     .par        nPara×6×nSub×10  椭圆 6 参数（缺测为 NaN）
%     .lab_fit    nPara×3×nSub×10  [L*, a*, b*]，按 lightness 选项变换后
%     .average    nPara×3×nSub     平均肤色（原始 aveSkin，未变换）
%     .average_mean nPara×3        对受试者求平均
%     .hasAttr    nSub×10  logical 该组该属性是否真的有数据
%     .CT         nPara×1           场景色温（i 组统一，r 组按族裔给在 .CT_stim）
%     .XYZw_pre   nPara×3           场景白点（同上）
%     .missing    cell              缺测清单 {subject, attrSerial}
%
%   说明: phase2 的拟合产物路径为
%         AnalyseResults_p\efit_p\unscaled\{obsNation}\{subject}\non_model\{attr}\ellipPara\fitRes.mat
%         其 par_all 行数 = 该组的场景数（i:21, r:14），因此 nPara 由 iOr 决定。

    if nargin < 3, opts = struct(); end
    if ~isfield(opts, 'obsType'),   opts.obsType   = 'non_model'; end
    if ~isfield(opts, 'lightness'), opts.lightness = 'raw';       end
    if ~isfield(opts, 'verbose'),   opts.verbose   = true;        end

    C = p2_config();

    D = struct();
    D.obsNation = obsNation;
    D.iOr       = iOr;
    D.obsType   = opts.obsType;
    D.lightness = opts.lightness;

    %% ---------- 1. 场景数与场景列表 ----------
    if strcmp(iOr, 'i')
        D.nPara     = numel(C.PICNAMES_I);   % 21
        D.picnames  = C.PICNAMES_I;
    else
        D.nPara     = numel(C.PICNAMES_R);   % 14
        D.picnames  = C.PICNAMES_R;
    end
    nPara = D.nPara;

    %% ---------- 2. 刺激组列表 + 族裔分组 ----------
    [D.lastParts, D.stimNation, D.stimIdx] = p2_local_build_lastparts(C, iOr);
    nSub = numel(D.lastParts);
    D.nSub = nSub;

    %% ---------- 3. 场景光源（CT / 白点） ----------
    [D.CT, D.XYZw_pre, D.CT_stim, D.XYZw_stim] = p2_local_scene_light(C, iOr, D);

    %% ---------- 4. 标定 LUT（phase2 一律用 phase2 自己的显示标定） ----------
    lut = load(C.LUT_P2_FILE, 'XYZw');
    D.XYZw_LUT = lut.XYZw;
    wd65 = C.WD65;

    %% ---------- 5. 逐组加载 ----------
    D.attributes = 1:C.nAttr;                    % 先扫全部槽位，实际有无由 hasAttr 决定
    D.attrSerial = strings(1, C.nAttr);
    for a = D.attributes
        D.attrSerial(a) = strcat(sprintf('%02d', a), C.ATTRIBUTE_NAMES(a));
    end

    D.par           = nan(nPara, 6, nSub, C.nAttr);
    D.lab_fit       = nan(nPara, 3, nSub, C.nAttr);
    D.average       = nan(nPara, 3, nSub);        % 原始 aveSkin 的 Lab
    D.average_used  = nan(nPara, 3, nSub);        % 变换（CAT/scale）后的平均肤色
    D.XYZw_white    = nan(nPara, 3, nSub);
    D.XYZw_gray     = nan(nPara, 3, nSub);
    D.hasAttr       = false(nSub, C.nAttr);
    D.missing       = {};

    tStart = tic;
    for iSub = 1:nSub
        lp = D.lastParts{iSub};

        % ---- 5.1 平均肤色 ----
        aveFile = fullfile(C.P2_ROOT, 'aveSkin', lp, 'autoNhand_scaleoverLUT.mat');
        if isfile(aveFile)
            aveData = load(aveFile, 'average_lab_all');
            labAve  = aveData.average_lab_all(:, 1:3);
        else
            labAve  = nan(nPara, 3);
        end
        % 场景数不一致时补齐/截断（正常不会发生）
        labAve = p2_local_fit_rows(labAve, nPara);
        D.average(:, :, iSub) = labAve;

        % ---- 5.2 白色方块的 XYZw（scaled 用） ----
        whiteFile = fullfile(C.P2_ROOT, 'optimizedD', 'whiteSquare', 'XYZw_white', [lp '.mat']);
        if isfile(whiteFile)
            wData = load(whiteFile, 'XYZw_white');
            D.XYZw_white(:, :, iSub) = p2_local_fit_rows(wData.XYZw_white, nPara);
        end

        % ---- 5.3 背景灰卡的 xyz_gray（明度映射 / 对比度用） ----
        grayFile = fullfile(C.P2_ROOT, 'optimizedD', 'backGroundGray', [lp '.mat']);
        if isfile(grayFile)
            gData = load(grayFile, 'xyz_gray');
            xyzGray = gData.xyz_gray;
            if strcmp(iOr, 'i') && size(xyzGray, 1) == 21
                % i 组的 xyz_gray 存的是采集顺序，需重排成 h3k..l8k
                order = [1,2,3,4,7,5,6, 15,16,17,18,21,19,20, 8,9,10,11,14,12,13];
                xyzGray = xyzGray(order, :);
            end
            D.XYZw_gray(:, :, iSub) = p2_local_fit_rows(xyzGray, nPara);
        end

        % ---- 5.4 平均肤色先做 late CAT（仅 cat / cat_scale 需要） ----
        labAveUsed = labAve;
        if ismember(opts.lightness, {'cat', 'cat_scale'})
            labAveUsed = p2_local_apply_cat(labAve, C, iOr, D, iSub);
        end
        D.average_used(:, :, iSub) = labAveUsed;

        % ---- 5.5 逐属性读取拟合参数 ----
        for a = D.attributes
            f = fullfile(C.ANALYSE_ROOT, C.Dtype, C.scale_type_origin, obsNation, lp, ...
                opts.obsType, char(D.attrSerial(a)), 'ellipPara', 'fitRes.mat');
            if ~isfile(f), continue; end

            fit = load(f, 'par_all');
            parAll = fit.par_all;
            if isempty(parAll), continue; end
            parAll = p2_local_fit_rows(parAll, nPara);

            D.par(:, :, iSub, a) = parAll;
            D.hasAttr(iSub, a)   = true;

            % 椭圆中心 = 平均肤色的 L* + 拟合出的 a*b*
            labBF = [labAveUsed(:, 1), parAll(:, 4:5)];

            switch opts.lightness
                case {'raw', 'cat'}
                    D.lab_fit(:, :, iSub, a) = labBF;
                case {'scale', 'rela', 'cat_scale'}
                    wWhite = D.XYZw_white(:, :, iSub);
                    labScaled = nan(nPara, 3);
                    for iPara = 1:nPara
                        if any(isnan(labBF(iPara, :))) || any(isnan(wWhite(iPara, :)))
                            continue
                        end
                        xyzFit = lab2xyz2(labBF(iPara, :), 'user', ...
                            wd65 ./ wd65(2) .* D.XYZw_LUT(2));
                        labScaled(iPara, :) = xyz2lab(xyzFit, 'user', ...
                            wd65 ./ wd65(2) .* wWhite(iPara, 2));
                    end
                    D.lab_fit(:, :, iSub, a) = labScaled;
                otherwise
                    error('p2_load_labfit: 未知 lightness 选项 "%s"', opts.lightness);
            end
        end

        if opts.verbose
            fprintf('[p2_load] %s/%s 组 %2d/%2d  %s\n', obsNation, iOr, iSub, nSub, lp);
        end
    end

    D.average_mean = mean(D.average_used, 3, 'omitnan');

    if opts.verbose
        fprintf('[p2_load] %s/%s 完成：%d 组 × %d 场景，用时 %.1f s；有数据的属性 = %s\n', ...
            obsNation, iOr, nSub, nPara, toc(tStart), ...
            mat2str(find(any(D.hasAttr, 1))));
    end
end

% ========================================================================
function [lastParts, stimNation, stimIdx] = p2_local_build_lastparts(C, iOr)
%P2_LOCAL_BUILDPARTPARTS  按族裔顺序生成 20 个刺激组，并给出族裔分组下标
    lastParts  = {};
    stimNation = {};
    stimIdx    = cell(1, numel(C.STIM_NATIONS));
    for iNat = 1:numel(C.STIM_NATIONS)
        models = C.STIM_MODELS{iNat};
        stimIdx{iNat} = [];
        for m = 1:numel(models)
            lp = char(models(m) + iOr);
            lastParts{end+1}  = lp;                            %#ok<AGROW>
            stimNation{end+1} = char(C.STIM_NATIONS(iNat));    %#ok<AGROW>
            stimIdx{iNat}(end+1) = numel(lastParts);           %#ok<AGROW>
        end
    end
    stimNation = stimNation(:)';
end

% ========================================================================
function [CT, XYZw_pre, CT_stim, XYZw_stim] = p2_local_scene_light(C, iOr, D)
%P2_LOCAL_SCENE_LIGHT  取场景的色温与白点
%   i 组：21 个光源共用一套（optimizedD\neutral_gray\combi_XYZw_i.mat）
%   r 组：按刺激族裔，把该族裔各 model 的 model_light_mean 平均
    nNat = numel(C.STIM_NATIONS);
    CT_stim    = cell(1, nNat);
    XYZw_stim  = cell(1, nNat);

    if strcmp(iOr, 'i')
        f = fullfile(C.P2_ROOT, 'optimizedD', 'neutral_gray', 'combi_XYZw_i.mat');
        s = load(f, 'XYZ_combi', 'CCT_combi');
        CT       = s.CCT_combi(:);
        XYZw_pre = s.XYZ_combi;
        for iNat = 1:nNat
            CT_stim{iNat}   = CT;
            XYZw_stim{iNat} = XYZw_pre;
        end
    else
        for iNat = 1:nNat
            models = C.STIM_MODELS{iNat};
            xyzAcc = [];
            ctAcc  = [];
            for m = 1:numel(models)
                f = fullfile(C.LIGHT_R_MEAN_DIR, [char(models(m)) '.mat']);
                if ~isfile(f)
                    warning('p2_load_labfit: 缺光源参考 %s', f);
                    continue
                end
                s = load(f, 'model_tcp_mean', 'XYZwpre_mea');
                xyzAcc(:, :, end+1) = s.XYZwpre_mea;   %#ok<AGROW>
                ctAcc(:, end+1)     = s.model_tcp_mean; %#ok<AGROW>
            end
            if isempty(xyzAcc)
                CT_stim{iNat}   = nan(D.nPara, 1);
                XYZw_stim{iNat} = nan(D.nPara, 3);
            else
                XYZw_stim{iNat} = mean(xyzAcc, 3, 'omitnan');
                CT_stim{iNat}   = mean(ctAcc, 2, 'omitnan');
            end
        end
        % 全族裔平均作为"全局"光源（用于 fig 标题/色条）
        nPara = size(XYZw_stim{1}, 1);
        xyzAll = nan(nPara, 3, nNat);
        ctAll  = nan(nPara, nNat);
        for iNat = 1:nNat
            xyzAll(:, :, iNat) = XYZw_stim{iNat};
            ctAll(:, iNat)     = CT_stim{iNat};
        end
        XYZw_pre = mean(xyzAll, 3, 'omitnan');
        CT       = mean(ctAll, 2, 'omitnan');
    end
end

% ========================================================================
function labAft = p2_local_apply_cat(labBF, C, iOr, D, iSub)
%P2_LOCAL_APPLY_CAT  late CAT16：把平均肤色从场景光源迁到 D65
    labAft = nan(size(labBF));
    if strcmp(iOr, 'i')
        XYZwUse = D.XYZw_pre;
        ctUse   = D.CT;
    else
        iNat    = find(strcmp(D.stimNation{iSub}, C.STIM_NATIONS), 1);
        XYZwUse = D.XYZw_stim{iNat};
        ctUse   = D.CT_stim{iNat};
    end
    XYZbf = lab2xyz2(labBF, 'd65_64');
    for iPara = 1:size(labBF, 1)
        if any(isnan(XYZbf(iPara, :))) || any(isnan(XYZwUse(iPara, :)))
            continue
        end
        Dpre = calculateD(ctUse(iPara), 0, 'efit_p');
        XYZt = CAT16_D(XYZbf(iPara, :), XYZwUse(iPara, :), C.WD65, Dpre);
        labAft(iPara, :) = xyz2lab(XYZt, 'd65_64');
    end
end

% ========================================================================
function X = p2_local_fit_rows(X, n)
%P2_LOCAL_FIT_ROWS  把矩阵行数补齐/截断到 n
    r = size(X, 1);
    if r == n, return; end
    if r > n
        X = X(1:n, :);
    else
        pad = nan(n - r, size(X, 2));
        X = [X; pad];
    end
end
