function check_data_integrity_by_nation(nations)
%CHECK_DATA_INTEGRITY_BY_NATION  按 nation 检查 renamed 下 csv 的完整性
% -------------------------------------------------------------------------
% 检查对象:
%   D:\work\VIVOSkin_phase2\ExpRes\renamed\{nation}\{model}{i/r}\obs_{i_obs}\obs{i_obs}_{i_attr}.csv
%
% 输出:
%   D:\work\VIVOSkin_phase2\analyze\data_integrity_{nation}.xlsx
%
%   ① 每个 {model}{i/r} 一个 sheet:
%        行  = observer，行头 "{i_obs}{obs name}"      例如 01Malvin / 02Jerome
%        列  = attribute，列头 "{i_attr}{attribute name}" 例如 01Preference / 06Healthy
%        单元格 = 该 csv 是否存在 + 大小是否与同类文件相当:
%            OK         存在，且 >= 同组同属性中位数的 50%，且 >= 8KB，且行数一致
%            SMALL xx%  存在但偏小，xx% = 该文件 / 同组同属性中位数
%            SMALL xxKB 存在但偏小，且同组同属性没有可比对象（按 8KB 绝对下限判断）
%            ROWS n/m   行数 n 与同组同属性中位数 m 不一致（截断/多写，比字节数更锐利）
%            MISSING    不存在
%        （ROWS 判定可用配置区 CHECK_ROWS=false 关掉）
%
%   ② 最后一个 sheet "MISSING"，一行一个缺失 csv:
%         Group | Observer | Attribute | Reason
%      整个组目录都不存在时只写一行 (Observer/Attribute 记 '-')，否则会刷出
%      10 obs x 10 attr = 100 行噪音
%
% 行头里为什么带人名:
%   obs 编号对应的人名随批次 (A/B/C) 变化，而每个组只属于一个批次，
%   所以按 BATCH_MODELS 找到该组的批次后，取该 nation 对应批次的人名表即可
%
% 用法:
%   >> check_data_integrity_by_nation            % AF/SA/CA/AS 全查，缺目录的自动跳过
%   >> check_data_integrity_by_nation('AF')
%   >> check_data_integrity_by_nation({'AF','SA'})
% -------------------------------------------------------------------------

%% ---------------- 配置 ----------------
DATA_ROOT   = 'D:\work\VIVOSkin_phase2\ExpRes\renamed';
OUT_DIR     = 'D:\work\VIVOSkin_phase2\analyze';

MIN_BYTES   = 8 * 1024;      % 绝对下限：小于 8KB 一定算偏小（与 copy_to_renamed 的规则一致）
SMALL_RATIO = 0.5;           % 相对下限：小于同组同属性中位数的 50% 算偏小

% 只比字节数的话，实测同列内文件大小波动只有 0.4%~3.9%，几乎抓不到截断文件；
% 而同一 (组, 属性) 的行数是完全固定的（i 组 780 行 / r 组 521 行）。
% 所以额外加一条“行数必须等于同列中位数”的判定，把它作为比字节数更锐利的指标。
CHECK_ROWS  = true;

if nargin < 1 || isempty(nations)
    nations = {'AF', 'SA', 'CA', 'AS'};
elseif ischar(nations) || (isstring(nations) && isscalar(nations))
    nations = {char(nations)};
end

% i_attr 01..10 -> 名称（与 copy_to_renamed.m / ExpRes 一致）
ATTR_NAMES = {'Preference', 'Attractiveness', 'Feminine', 'Cooperative', 'Youth', ...
              'Healthy', 'Fidelity', 'Harmony', 'Fair', 'Ruddy'};
nAttr = numel(ATTR_NAMES);

% 三批 observer：obs 编号的含义随批次变化
BATCH_MODELS = { ...
    {'f01', 'f04', 'f07', 'f08', 'f09', 'f10'}, ...              % batch A
    {'f03', 'f06', 'm07', 'm08', 'm09', 'm10'}, ...              % batch B
    {'f02', 'f05', 'm04', 'm01', 'm05', 'm02', 'm06', 'm03'} };  % batch C

% 每个 nation 三批 observer 名单（顺序即 obs 编号；空 {} = 该批暂无）
OBS_SETS = struct();
OBS_SETS.AF = { ...
    {'Malvin', 'Jerome', 'moussa', 'viva', 'philippe', ...
     'Divine', 'uneza', 'DANIELLA', 'Shanly', 'Ongama'}, ...
    {'NIWE', 'LUKE MARRION MARUFU', 'Balima Miguel', ...
     'TANATSWA MUKOKANDUKU', 'TANATSWA GWABADA', ...
     'Mercy', 'Axelle', 'natasha', 'tanya', 'chelsea'}, ...
    {'atascopy', 'placide', 'Bevin', 'sherlington', 'brian', ...
     'Kirsty', 'noluthando', 'Samara', 'paballo', 'vanessa'} };
OBS_SETS.SA = { ...
    {'Areeba', 'Alishba', 'Eman', 'Alisha', 'Jenny'}, ...
    {'raz sadia', 'sarwar', 'malaika', 'meenal', 'minahil'}, ...
    {} };

% 40 个组：f/m 01..10 × i/r
MODELS = cell(0, 1);
for pre = {'f', 'm'}
    for k = 1:10
        for suf = {'i', 'r'}
            MODELS{end + 1, 1} = sprintf('%s%02d%s', pre{1}, k, suf{1}); %#ok<SAGROW>
        end
    end
end

if exist(OUT_DIR, 'dir') ~= 7
    mkdir(OUT_DIR);
end

%% ---------------- 逐 nation ----------------
for ni = 1:numel(nations)
    nat = upper(strtrim(char(nations{ni})));
    nat_dir = fullfile(DATA_ROOT, nat);
    outFile = fullfile(OUT_DIR, sprintf('data_integrity_%s.xlsx', nat));

    fprintf('\n===== nation %s =====\n', nat);
    if ~isfield(OBS_SETS, nat)
        fprintf('[跳过] OBS_SETS 里没有 nation "%s" 的名单\n', nat);
        continue
    end
    if ~isfolder(nat_dir)
        fprintf('[跳过] 目录不存在: %s\n', nat_dir);
        continue
    end

    outFile = ensure_writable(outFile);
    fprintf('输出: %s\n', outFile);

    missRows = cell(0, 4);     % Group | Observer | Attribute | Reason
    nFile = 0; nSmall = 0; nMiss = 0; nGroupOk = 0;

    for mi = 1:numel(MODELS)
        model   = MODELS{mi};
        grp_dir = fullfile(nat_dir, model);

        if ~isfolder(grp_dir)
            missRows(end + 1, :) = {model, '-', '-', '组目录不存在'}; %#ok<SAGROW>
            fprintf('  [%-5s] 组目录不存在\n', model);
            continue
        end
        nGroupOk = nGroupOk + 1;

        % ---- 该组属于哪一批 -> 人名表 ----
        base  = model(1:end - 1);          % 'f04i' -> 'f04'
        batch = 0;
        for b = 1:numel(BATCH_MODELS)
            if any(strcmp(BATCH_MODELS{b}, base))
                batch = b;
                break
            end
        end
        if batch == 0
            names = {};
        else
            names = OBS_SETS.(nat){batch};
        end

        % ---- 决定要检查哪些 obs 编号 ----
        if ~isempty(names)
            obsIds = 1:numel(names);
        else
            d = dir(fullfile(grp_dir, 'obs_*'));
            obsIds = [];
            for k = 1:numel(d)
                tk = regexp(d(k).name, '^obs_(\d+)$', 'tokens', 'once');
                if ~isempty(tk)
                    obsIds(end + 1) = str2double(tk{1}); %#ok<SAGROW>
                end
            end
            obsIds = sort(obsIds);
        end
        if isempty(obsIds)
            fprintf('  [%-5s] 没有任何 obs_XX 目录\n', model);
            continue
        end

        nO = numel(obsIds);
        sz = nan(nO, nAttr);               % 每个 (obs, attr) 的字节数, NaN = 不存在
        nr = nan(nO, nAttr);               % 每个 (obs, attr) 的行数
        for oi = 1:nO
            for ai = 1:nAttr
                fp = fullfile(grp_dir, sprintf('obs_%02d', obsIds(oi)), ...
                              sprintf('obs%02d_%02d.csv', obsIds(oi), ai));
                if isfile(fp)
                    info = dir(fp);
                    sz(oi, ai) = info.bytes;
                    if CHECK_ROWS
                        nr(oi, ai) = count_lines(fp);
                    end
                end
            end
        end

        % ---- 同类参照：同组同属性的 字节数中位数 / 行数中位数 ----
        ref = nan(1, nAttr);
        refRow = nan(1, nAttr);
        for ai = 1:nAttr
            v = sz(:, ai);
            v = v(~isnan(v));
            if ~isempty(v)
                ref(ai) = median(v);
            end
            if CHECK_ROWS
                r = nr(:, ai);
                r = r(~isnan(r));
                if ~isempty(r)
                    refRow(ai) = round(median(r));
                end
            end
        end

        % ---- 拼 cell 矩阵（行头 obs，列头 attr）----
        C = cell(nO + 1, nAttr + 1);
        C{1, 1} = 'Observer';
        for ai = 1:nAttr
            C{1, ai + 1} = sprintf('%02d%s', ai, ATTR_NAMES{ai});
        end

        nMissG = 0; nOkG = 0; nSmallG = 0;
        for oi = 1:nO
            o = obsIds(oi);
            if ~isempty(names) && o <= numel(names)
                obsLabel = sprintf('%02d%s', o, names{o});
            else
                obsLabel = sprintf('%02d', o);
            end
            C{oi + 1, 1} = obsLabel;

            for ai = 1:nAttr
                b = sz(oi, ai);
                if isnan(b)
                    C{oi + 1, ai + 1} = 'MISSING';
                    missRows(end + 1, :) = {model, obsLabel, C{1, ai + 1}, 'csv 不存在'}; %#ok<SAGROW>
                    nMissG = nMissG + 1;
                else
                    if isnan(ref(ai))
                        isSmall = b < MIN_BYTES;
                        pct     = NaN;
                    else
                        pct     = 100 * b / ref(ai);
                        isSmall = (b < MIN_BYTES) || (pct < 100 * SMALL_RATIO);
                    end
                    badRows = CHECK_ROWS && ~isnan(refRow(ai)) && nr(oi, ai) ~= refRow(ai);

                    if badRows
                        % 行数不对 => 文件被截断/多写了一部分, 比字节数更能说明问题
                        C{oi + 1, ai + 1} = sprintf('ROWS %d/%d', nr(oi, ai), refRow(ai));
                        nSmallG = nSmallG + 1;
                    elseif isSmall
                        if isnan(pct)
                            C{oi + 1, ai + 1} = sprintf('SMALL %.0fKB', b / 1024);
                        else
                            C{oi + 1, ai + 1} = sprintf('SMALL %.0f%%', pct);
                        end
                        nSmallG = nSmallG + 1;
                    else
                        C{oi + 1, ai + 1} = 'OK';
                        nOkG = nOkG + 1;
                    end
                end
            end
        end

        write_cell_sheet(C, outFile, model);
        nMiss  = nMiss + nMissG;
        nSmall = nSmall + nSmallG;
        nFile  = nFile + nOkG;
        fprintf('  [%-5s] obs=%2d  OK=%3d  SMALL=%2d  MISSING=%3d  (batch %s, %d 列属性)\n', ...
            model, nO, nOkG, nSmallG, nMissG, batch_tag(batch), nAttr);
    end

    % ---- MISSING sheet ----
    if isempty(missRows)
        missT = table("(无缺失)", "(无缺失)", "(无缺失)", "(无缺失)", ...
            'VariableNames', {'Group', 'Observer', 'Attribute', 'Reason'});
    else
        missT = cell2table(missRows, 'VariableNames', ...
            {'Group', 'Observer', 'Attribute', 'Reason'});
    end
    writetable(missT, outFile, 'Sheet', 'MISSING');

    fprintf('  汇总: 组目录存在 %d/40, OK %d 个, SMALL %d 个, 缺失 %d 个\n', ...
        nGroupOk, nFile, nSmall, nMiss);
    fprintf('  已写出: %s\n', outFile);
end

fprintf('\n全部完成。\n');
end

%% =====================================================================
function n = count_lines(fp)
%COUNT_LINES 数一个文本文件的有效行数（丢弃末尾空行）
n = NaN;
fid = fopen(fp, 'r', 'n', 'UTF-8');
if fid < 0
    return
end
txt = fread(fid, Inf, '*char')';
fclose(fid);
if isempty(txt)
    n = 0;
    return
end
parts = regexp(txt, '\r\n|\n|\r', 'split');
if ~isempty(parts) && isempty(parts{end})
    parts(end) = [];
end
n = numel(parts);
end

%% =====================================================================
function tag = batch_tag(b)
%BATCH_TAG 0/1/2/3 -> '-'/'A'/'B'/'C'
if b >= 1 && b <= 3
    tag = char('A' + b - 1);
else
    tag = '-';
end
end

%% =====================================================================
function f = ensure_writable(f)
%ENSURE_WRITABLE 文件被 Excel/WPS 占用时, 退到带时间戳的备用名
if isfile(f)
    ws = warning('off', 'all');
    delete(f);
    warning(ws);
    if isfile(f)
        [p, nm, ext] = fileparts(f);
        f2 = fullfile(p, sprintf('%s_%s%s', nm, datestr(now, 'yyyymmdd_HHMMSS'), ext));
        fprintf(2, '[提示] %s 被占用(可能已在 Excel 中打开), 本次改写到: %s\n', f, f2);
        f = f2;
    end
end
end

%% =====================================================================
function write_cell_sheet(C, outFile, sheetName)
%WRITE_CELL_SHEET 写一个 cell 矩阵到指定 sheet（优先 writecell, 老版本退回 xlswrite）
if exist('writecell') > 0
    writecell(C, outFile, 'Sheet', sheetName);
else
    xlswrite(outFile, C, sheetName);
end
end
