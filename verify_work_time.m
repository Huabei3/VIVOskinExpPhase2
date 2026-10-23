function verify_work_time(srcXlsx, outXlsx, reportXlsx)
%VERIFY_WORK_TIME  校验 work time_filled.xlsx 与 ExpRes CSV 的一致性并输出修正版
%
% 校验规则
%   ① 表内 File Created Time / Last Score Time / Time Difference (hours)
%      是否与 ExpRes\renamed\{model}\obs_{XX}\obs{XX}_{YY}.csv 尾三行一致，
%      并用 ExpRes\com.example.{model}{i/r}p2\*.csv 交叉验证（同一 created/last 的原始输出）
%   ② 每列 Added Time 是否等于该列所有 Time Difference (hours) 之和；
%      Added Time with Rest 是否等于 Added Time + n/6（每个 file 多计 10 分钟）
%   ③ 不满足规则的内容写入修正版 xlsx（仅改动 E:I 数据区）+ xlsx 报告
%
% 用法
%   verify_work_time                                   % 默认输入，输出到 analyze
%   verify_work_time('D:\...\work time_filled.xlsx')   % 指定输入
%   verify_work_time(src, outXlsx, reportXlsx)         % 全指定

%% ================= 配置 =================
ANALYZE_DIR  = 'D:\work\VIVOSkin_phase2\analyze';
RENAMED_ROOT = 'D:\work\VIVOSkin_phase2\ExpRes\renamed';
EXPRES_ROOT  = 'D:\work\VIVOSkin_phase2\ExpRes';

TOL_DIFF  = 0.005;   % 小时（表内两位小数）
TOL_SUM   = 0.006;   % Added Time 容差
TOL_REST  = 0.02;    % Added Time with Rest 容差
REST_HOUR = 1/6;     % 每个 file 额外 10 分钟（与 fill_work_time.m 一致）

if nargin < 1 || isempty(srcXlsx)
    cand = {fullfile(ANALYZE_DIR, 'work time_filled.xlsx'), ...
            fullfile(EXPRES_ROOT, 'work time_filled.xlsx')};
    srcXlsx = '';
    for i = 1:numel(cand)
        if isfile(cand{i})
            srcXlsx = cand{i};
            break;
        end
    end
    if isempty(srcXlsx)
        error('找不到输入表，候选路径: %s', strjoin(cand, ' | '));
    end
end
if ~isfile(srcXlsx)
    error('找不到输入表: %s', srcXlsx);
end
[~, baseName] = fileparts(srcXlsx);
if nargin < 2 || isempty(outXlsx)
    outXlsx = fullfile(ANALYZE_DIR, [baseName '_corrected.xlsx']);
end
if nargin < 3 || isempty(reportXlsx)
    reportXlsx = fullfile(ANALYZE_DIR, 'work_time_verify_report.xlsx');
end
outXlsx    = ensure_writable(outXlsx);
reportXlsx = ensure_writable(reportXlsx);

fprintf('输入表 : %s\n', srcXlsx);
fprintf('修正版 : %s\n', outXlsx);
fprintf('报告   : %s\n', reportXlsx);

%% ================= 1-2 扫描 CSV =================
fprintf('==== 1/6 扫描 renamed CSV ====\n');
R = scan_renamed(RENAMED_ROOT);
fprintf('   renamed 记录: %d\n', numel(R));

fprintf('==== 2/6 扫描源码 CSV (com.example.*p2) ====\n');
S = scan_source(EXPRES_ROOT);
fprintf('   源码记录: %d\n', numel(S));

renT = build_time_map(R);
srcT = build_time_map(S);
renK = build_key_map(R);
[attrMap, nameMap] = build_attr_name_map(R, S, renT);

%% ================= 3 读表逐格取证 =================
fprintf('==== 3/6 读取表格并逐格取证 ====\n');
sheets = sheetnames(srcXlsx);
cells  = collect_cells(srcXlsx, sheets, attrMap);
nNonBlank = sum(~[cells.isBlank]);
fprintf('   单元格: %d（非空 %d）\n', numel(cells), nNonBlank);

[cells, colMap] = build_column_map(cells, R, renT);
[cells, repCell, chgCell, stat] = resolve_cells(cells, R, S, renT, srcT, renK, colMap, TOL_DIFF);
fprintf('   OK:%d 已修正:%d 空白:%d 无证据:%d 冲突:%d\n', ...
    stat.OK, stat.FIXED, stat.EMPTY, stat.UNVERIFIED, stat.CONFLICT);

%% ================= 4 汇总行校验 =================
fprintf('==== 4/6 校验 Added Time / Added Time with Rest ====\n');
[totRows, totStat, chgTot] = check_totals(srcXlsx, sheets, cells, TOL_SUM, TOL_REST, REST_HOUR);
fprintf('   列: %d 通过:%d 已修正:%d\n', totStat.n, totStat.OK, totStat.FIXED);

%% ================= 5 写修正版 =================
fprintf('==== 5/6 写修正版 xlsx ====\n');
allChg = [chgCell; chgTot];
write_corrected(srcXlsx, outXlsx, allChg);
fprintf('   改动单元格: %d\n', size(allChg, 1));

%% ================= 6 写报告 =================
fprintf('==== 6/6 写 xlsx 报告 ====\n');
orphans = find_orphans(R, cells);
write_report(reportXlsx, srcXlsx, outXlsx, stat, totStat, repCell, allChg, ...
    totRows, colMap, orphans, R, nameMap, TOL_DIFF, TOL_SUM, TOL_REST, REST_HOUR);
fprintf('完成:\n   %s\n   %s\n', outXlsx, reportXlsx);
end

%% =====================================================================
function R = scan_renamed(root)
% 扫描 {model}\obs_{XX}\obs{XX}_{YY}.csv 的元信息
R = struct('model', {}, 'xx', {}, 'yy', {}, 'c', {}, 'l', {}, 'd', {}, 'file', {});
if ~isfolder(root)
    warning('renamed 目录不存在: %s', root);
    return;
end
models = dir(root);
for i = 1:numel(models)
    if ~models(i).isdir || startsWith(models(i).name, '.')
        continue;
    end
    model = models(i).name;
    obsDirs = dir(fullfile(root, model, 'obs_*'));
    for j = 1:numel(obsDirs)
        if ~obsDirs(j).isdir
            continue;
        end
        xx   = regexprep(obsDirs(j).name, '^obs_', '');
        csvs = dir(fullfile(root, model, obsDirs(j).name, 'obs*_*.csv'));
        for k = 1:numel(csvs)
            tok = regexp(csvs(k).name, '^obs(\d{2})_(\d{2})\.csv$', 'tokens', 'once');
            if isempty(tok)
                continue;
            end
            fp   = fullfile(csvs(k).folder, csvs(k).name);
            info = read_csv_meta(fp);
            if ~info.ok
                continue;
            end
            R(end+1) = struct('model', model, 'xx', tok{1}, 'yy', tok{2}, ...
                'c', info.c, 'l', info.l, 'd', info.d, 'file', fp); %#ok<AGROW>
        end
    end
end
end

%% =====================================================================
function S = scan_source(root)
% 扫描 com.example.{model}{i/r}p2\*.csv；文件名给出 observer 名与属性名
S = struct('model', {}, 'obs', {}, 'attr', {}, 'c', {}, 'l', {}, 'd', {}, 'file', {});
patStrict = '^(.+?)_([A-Za-z]+)_(\d{8})_(\d{6})_result_com\.example\.([fm]\d{2})([ir])p2\.csv$';
patLoose  = '^(.+?)_([A-Za-z]+)_(\d{8})_(\d{6})_result_com\.example\..*\.csv$';
dirPat    = 'com\.example\.([fm]\d{2})([ir])p2$';
models = dir(root);
for i = 1:numel(models)
    if ~models(i).isdir
        continue;
    end
    dm = regexp(models(i).name, dirPat, 'tokens', 'once');
    if isempty(dm)
        continue;
    end
    folder  = fullfile(root, models(i).name);
    defModel = [dm{1} dm{2}];
    csvs = dir(fullfile(folder, '*.csv'));
    for k = 1:numel(csvs)
        fn  = csvs(k).name;
        tok = regexp(fn, patStrict, 'tokens', 'once');
        if ~isempty(tok)
            model = [tok{5} tok{6}];
            obsN  = tok{1};
            attrN = tok{2};
        else
            tok = regexp(fn, patLoose, 'tokens', 'once');
            if isempty(tok)
                continue;
            end
            model = defModel;
            obsN  = tok{1};
            attrN = tok{2};
        end
        fp   = fullfile(folder, fn);
        info = read_csv_meta(fp);
        if ~info.ok
            continue;
        end
        S(end+1) = struct('model', model, 'obs', obsN, 'attr', attrN, ...
            'c', info.c, 'l', info.l, 'd', info.d, 'file', fp); %#ok<AGROW>
    end
end
end

%% =====================================================================
function info = read_csv_meta(fp)
% 只读文件末尾 4KB，提取 File Created Time / Last Score Time / Time Difference
info = struct('c', '', 'l', '', 'd', '', 'ok', false);
fid = fopen(fp, 'r');
if fid < 0
    return;
end
try
    fseek(fid, 0, 'eof');
    sz = ftell(fid);
    nb = min(4096, sz);
    fseek(fid, -nb, 'eof');
    raw = fread(fid, [1 nb], '*uint8');
catch
    fclose(fid);
    return;
end
fclose(fid);
txt = char(raw);
txt = regexprep(txt, '\r', '');
tc = regexp(txt, 'File Created Time:\s*([0-9\-]{8,10} [0-9:]{8})', 'tokens', 'once');
tl = regexp(txt, 'Last Score Time:\s*([0-9\-]{8,10} [0-9:]{8})', 'tokens', 'once');
td = regexp(txt, 'Time Difference \(hours\):\s*([0-9]+\.[0-9]+)', 'tokens', 'once');
if isempty(tc)
    return;
end
info.c = strtrim(tc{1});
if ~isempty(tl)
    info.l = strtrim(tl{1});
end
if ~isempty(td)
    info.d = strtrim(td{1});
end
info.ok = true;
end

%% =====================================================================
function M = build_time_map(X)
% key: model|created|last  ->  记录索引数组
M = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(X)
    key = sprintf('%s|%s|%s', X(k).model, X(k).c, X(k).l);
    if isKey(M, key)
        v = M(key);
    else
        v = [];
    end
    v(end+1) = k; %#ok<AGROW>
    M(key) = v;
end
end

%% =====================================================================
function M = build_key_map(R)
% key: model|xx|yy  ->  记录索引
M = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(R)
    key = sprintf('%s|%s|%s', R(k).model, R(k).xx, R(k).yy);
    if ~isKey(M, key)
        M(key) = k;
    end
end
end

%% =====================================================================
function [attrMap, nameMap] = build_attr_name_map(R, S, renT)
% 用「同一 created/last」把源码文件名里的属性名/observer 名 与 renamed 的 YY/XX 对齐
% attrMap: 'model|attrname' -> YY；'attrname' -> YY（全局兜底）
% nameMap: 'model|XX'       -> 最常见的 observer 名
globC = containers.Map('KeyType', 'char', 'ValueType', 'any');
modC  = containers.Map('KeyType', 'char', 'ValueType', 'any');
nameC = containers.Map('KeyType', 'char', 'ValueType', 'any');
for s = 1:numel(S)
    key = sprintf('%s|%s|%s', S(s).model, S(s).c, S(s).l);
    if ~isKey(renT, key)
        continue;
    end
    idxs = renT(key);
    for t = idxs
        la = lower(strtrim(S(s).attr));
        globC = inc_counter(globC, la, R(t).yy);
        modC  = inc_counter(modC, sprintf('%s|%s', S(s).model, la), R(t).yy);
        nameC = inc_counter(nameC, sprintf('%s|%s', S(s).model, R(t).xx), lower(strtrim(S(s).obs)));
    end
end
attrMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
ks = keys(globC);
for i = 1:numel(ks)
    attrMap(ks{i}) = pick_max(globC(ks{i}));
end
ks = keys(modC);
for i = 1:numel(ks)
    attrMap(ks{i}) = pick_max(modC(ks{i}));
end
fb = {'preference', '01'; 'youth', '05'; 'healthy', '06'; ...
      'fidelity', '07'; 'fair', '09'; 'ruddy', '10'};
for i = 1:size(fb, 1)
    if ~isKey(attrMap, fb{i, 1})
        attrMap(fb{i, 1}) = fb{i, 2};
    end
end
nameMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
ks = keys(nameC);
for i = 1:numel(ks)
    nameMap(ks{i}) = pick_max(nameC(ks{i}));
end
end

%% =====================================================================
function M = inc_counter(M, key, val)
if isKey(M, key)
    c = M(key);
else
    c = containers.Map('KeyType', 'char', 'ValueType', 'double');
end
if isKey(c, val)
    c(val) = c(val) + 1;
else
    c(val) = 1;
end
M(key) = c;
end

%% =====================================================================
function v = pick_max(c)
v = '';
best = -1;
ks = keys(c);
for i = 1:numel(ks)
    if c(ks{i}) > best
        best = c(ks{i});
        v = ks{i};
    end
end
end

%% =====================================================================
function yy = resolve_yy(attrMap, model, attr)
% 属性名 -> YY（先按 model 精确，再全局，再忽略非字母数字比较）
yy = '';
la = lower(strtrim(attr));
k1 = sprintf('%s|%s', model, la);
if isKey(attrMap, k1)
    yy = attrMap(k1);
    return;
end
if isKey(attrMap, la)
    yy = attrMap(la);
    return;
end
na = regexprep(la, '[^a-z0-9]', '');
ks = keys(attrMap);
for i = 1:numel(ks)
    k = ks{i};
    if contains(k, '|')
        continue;
    end
    if strcmp(regexprep(k, '[^a-z0-9]', ''), na)
        yy = attrMap(k);
        return;
    end
end
end

%% =====================================================================
function cells = collect_cells(f, sheets, attrMap)
% 逐 sheet 逐 block 采集 5 列的 created/last/diff 文本
cells = struct('sheet', {}, 'si', {}, 'row', {}, 'ci', {}, 'obsName', {}, ...
    'model', {}, 'attr', {}, 'yy', {}, 'tC', {}, 'tL', {}, 'tD', {}, ...
    'isBlank', {}, 'renIdx', {}, 'colXX', {}, 'rowL', {}, 'rowD', {});
for si = 1:numel(sheets)
    sn = sheets{si};
    if any(strcmpi(sn, {'SUMMARY', 'REPORT', 'README'}))
        continue;
    end
    try
        C = readcell(f, 'Sheet', sn);
    catch
        warning('无法读取 sheet: %s', sn);
        continue;
    end
    if size(C, 1) < 3 || size(C, 2) < 9
        continue;
    end
    obsNames = cell(1, 5);
    for ci = 1:5
        obsNames{ci} = tostr(C{2, 4 + ci});
    end
    nr = size(C, 1);
    for r = 3:nr
        lb = lower(tostr(C{r, 3}));
        if ~startsWith(lb, 'file created time')
            continue;
        end
        model = strtrim(tostr(C{r, 1}));
        attr  = strtrim(tostr(C{r, 2}));
        if isempty(model) || isempty(attr) || strcmpi(attr, 'Attribute')
            continue;
        end
        yy = resolve_yy(attrMap, model, attr);
        % 定位 last / diff 行（正常为 r+1 / r+2，异常时向后找 4 行）
        rL = 0; rD = 0;
        for rr = r + 1:min(nr, r + 4)
            lbr = lower(tostr(C{rr, 3}));
            if rL == 0 && startsWith(lbr, 'last score time')
                rL = rr;
            elseif startsWith(lbr, 'time difference')
                rD = rr;
                break;
            end
        end
        if rL == 0
            rL = r + 1;
        end
        if rD == 0
            rD = r + 2;
        end
        for ci = 1:5
            col = 4 + ci;
            tC = strtrim(tostr(C{r, col}));
            tL = '';
            tD = '';
            if rL <= nr
                tL = strtrim(tostr(C{rL, col}));
            end
            if rD <= nr
                tD = strtrim(tostr(C{rD, col}));
            end
            if strcmp(tD, 'NaN')
                tD = '';
            end
            cells(end+1) = struct('sheet', sn, 'si', si, 'row', r, 'ci', ci, ...
                'obsName', obsNames{ci}, 'model', model, 'attr', attr, 'yy', yy, ...
                'tC', tC, 'tL', tL, 'tD', tD, ...
                'isBlank', isempty(tC) && isempty(tL) && isempty(tD), ...
                'renIdx', 0, 'colXX', '', 'rowL', rL, 'rowD', rD); %#ok<AGROW>
        end
    end
end
end

%% =====================================================================
function idx = time_match(R, renT, model, c, l, yy)
% 用 model+created+last 精确找 renamed 记录（可再按 YY 过滤）
idx = [];
if isempty(c) || isempty(l)
    return;
end
key = sprintf('%s|%s|%s', model, c, l);
if ~isKey(renT, key)
    return;
end
idx = renT(key);
if ~isempty(yy)
    keep = false(1, numel(idx));
    for t = 1:numel(idx)
        keep(t) = strcmp(R(idx(t)).yy, yy);
    end
    idx = idx(keep);
end
end

%% =====================================================================
function idx = time_match_src(S, srcT, model, c, l, attr)
idx = [];
if isempty(c) || isempty(l)
    return;
end
key = sprintf('%s|%s|%s', model, c, l);
if ~isKey(srcT, key)
    return;
end
cand = srcT(key);
keep = false(1, numel(cand));
for t = 1:numel(cand)
    keep(t) = strcmpi(strtrim(S(cand(t)).attr), attr);
end
idx = cand(keep);
end

%% =====================================================================
function [cells, colMap] = build_column_map(cells, R, renT)
% 由「时间完全对得上」的格子反推每一列对应的 obs 文件夹编号
tally = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(cells)
    if cells(k).isBlank
        continue;
    end
    idx = time_match(R, renT, cells(k).model, cells(k).tC, cells(k).tL, cells(k).yy);
    if numel(idx) == 1
        cells(k).renIdx = idx;
        tally = inc_counter(tally, ...
            sprintf('%s|%s|%d', cells(k).sheet, cells(k).model, cells(k).ci), R(idx).xx);
    end
end
colMap = containers.Map('KeyType', 'char', 'ValueType', 'any');
ks = keys(tally);
for i = 1:numel(ks)
    cnt = tally(ks{i});
    vk  = keys(cnt);
    n   = 0;
    for j = 1:numel(vk)
        n = n + cnt(vk{j});
    end
    colMap(ks{i}) = struct('xx', pick_max(cnt), 'n', n, 'nDistinct', numel(vk));
end
for k = 1:numel(cells)
    key = sprintf('%s|%s|%d', cells(k).sheet, cells(k).model, cells(k).ci);
    if isKey(colMap, key)
        cells(k).colXX = colMap(key).xx;
    end
end
end

%% =====================================================================
function [cells, rep, chg, stat] = resolve_cells(cells, R, S, renT, srcT, renK, colMap, tolD)
rep = cell(0, 16);
chg = cell(0, 9);
stat = struct('n', numel(cells), 'OK', 0, 'FIXED', 0, 'EMPTY', 0, ...
    'UNVERIFIED', 0, 'CONFLICT', 0, 'TIME_FAIL', 0, 'DIFF_FAIL', 0, 'OBS_MISMATCH', 0);

for k = 1:numel(cells)
    c = cells(k);
    base = {c.sheet, c.row, c.model, c.attr, c.yy, sprintf('obs%d', c.ci), c.obsName, c.tC, c.tL, c.tD};

    if c.isBlank
        note = '表内空白，未改动';
        if ~isempty(c.colXX) && isKey(renK, sprintf('%s|%s|%s', c.model, c.colXX, c.yy))
            note = sprintf(['表内空白；renamed 有该 (model,obs%s,%s) 文件，但日期/observer 可能不同，未自动填充'], ...
                c.colXX, c.attr);
        end
        rep(end+1, :) = [base, {'', '', '', '', 'EMPTY', note}]; %#ok<AGROW>
        stat.EMPTY = stat.EMPTY + 1;
        continue;
    end

    % ---- 取证：① 时间完全匹配的 renamed（最强） ② 时间完全匹配的源码 ③ renamed 按名字 ----
    eKind = ''; eIdx = 0; sidx = [];
    if c.renIdx > 0
        eKind = 'renamed'; eIdx = c.renIdx;
    else
        sidx = time_match_src(S, srcT, c.model, c.tC, c.tL, c.attr);
        if numel(sidx) == 1
            eKind = 'source';
        else
            key = sprintf('%s|%s|%s', c.model, c.colXX, c.yy);
            if ~isempty(c.colXX) && isKey(renK, key)
                eKind = 'renamed_byname'; eIdx = renK(key);
            end
        end
    end

    eC = ''; eL = ''; eD = ''; evFile = '';
    if strcmp(eKind, 'renamed') || strcmp(eKind, 'renamed_byname')
        eC = R(eIdx).c; eL = R(eIdx).l; eD = R(eIdx).d; evFile = R(eIdx).file;
    elseif strcmp(eKind, 'source')
        eC = S(sidx).c; eL = S(sidx).l; eD = S(sidx).d; evFile = S(sidx).file;
    end

    % ---- 源码交叉验证值 ----
    srcD = '';
    if strcmp(eKind, 'renamed')
        s2 = time_match_src(S, srcT, c.model, c.tC, c.tL, c.attr);
        if ~isempty(s2)
            srcD = S(s2(1)).d;
        end
    elseif strcmp(eKind, 'source')
        srcD = eD;
    end

    % ---- 比对 ----
    okC = strcmp(c.tC, eC) || (isempty(c.tC) && isempty(eC));
    okL = strcmp(c.tL, eL) || (isempty(c.tL) && isempty(eL));
    okD = false;
    if ~isempty(c.tD) && ~isempty(eD)
        okD = abs(str2double(c.tD) - str2double(eD)) <= tolD;
    elseif isempty(c.tD) && isempty(eD)
        okD = true;
    end
    if ~okC || ~okL
        stat.TIME_FAIL = stat.TIME_FAIL + 1;
    end
    if ~okD
        stat.DIFF_FAIL = stat.DIFF_FAIL + 1;
    end

    % ---- 生成改动 ----
    note = ''; status = 'OK'; nAct = 0;
    if isempty(eKind)
        status = 'UNVERIFIED';
        note = 'renamed 与源码均无相同 created+last 的记录，无法校验';
        stat.UNVERIFIED = stat.UNVERIFIED + 1;
        if ~isempty(c.tD)
            note = [note '；表内 diff 与表内时间是否自洽: ' self_consistency(c.tC, c.tL, c.tD, tolD)];
        end
    else
        if ~okC
            chg(end+1, :) = {c.sheet, c.row, 4 + c.ci, addr_(c.row, 4 + c.ci), ...
                'File Created Time', c.tC, eC, eKind, evFile}; %#ok<AGROW>
            nAct = nAct + 1;
        end
        if ~okL
            chg(end+1, :) = {c.sheet, c.rowL, 4 + c.ci, addr_(c.rowL, 4 + c.ci), ...
                'Last Score Time', c.tL, eL, eKind, evFile}; %#ok<AGROW>
            nAct = nAct + 1;
        end
        if ~okD && ~isempty(eD)
            newD = sprintf('%.2f', str2double(eD));
            chg(end+1, :) = {c.sheet, c.rowD, 4 + c.ci, addr_(c.rowD, 4 + c.ci), ...
                'Time Difference (hours)', c.tD, newD, eKind, evFile}; %#ok<AGROW>
            nAct = nAct + 1;
        end
        % 把修正后的值同步回 cells，供汇总行复核使用
        if ~okC && ~isempty(eC)
            cells(k).tC = eC;
        end
        if ~okL && ~isempty(eL)
            cells(k).tL = eL;
        end
        if ~okD && ~isempty(eD)
            cells(k).tD = sprintf('%.2f', str2double(eD));
        end
        if nAct > 0
            status = 'FIXED';
            stat.FIXED = stat.FIXED + 1;
        else
            stat.OK = stat.OK + 1;
        end
        if strcmp(eKind, 'renamed_byname')
            note = '按 (model,obsXX,attr) 取得 renamed 文件，但表内时间与该文件不同；请人工确认日期';
        end
        if strcmp(eKind, 'source')
            note = 'renamed 中无同一 created+last，用 com.example 源码交叉验证';
        end
        if strcmp(eKind, 'renamed') && ~isempty(c.colXX) && ~strcmp(c.colXX, R(eIdx).xx)
            status = 'OBS_MISMATCH';
            note = sprintf('该列在其它行对应 obs%s，此行时间匹配到 obs%s', c.colXX, R(eIdx).xx);
            stat.OBS_MISMATCH = stat.OBS_MISMATCH + 1;
        end
        if ~isempty(srcD) && ~isempty(eD) && abs(str2double(srcD) - str2double(eD)) > tolD
            status = 'CONFLICT';
            note = sprintf('renamed(%s) 与源码(%s) 的 Time Difference 不一致，采用 renamed', eD, srcD);
            stat.CONFLICT = stat.CONFLICT + 1;
        end
    end
    rep(end+1, :) = [base, {eC, eL, eD, srcD, status, note}]; %#ok<AGROW>
    cells(k).renIdx = eIdx;
end
end

%% =====================================================================
function s = self_consistency(tC, tL, tD, tolD)
s = '无法判断';
if isempty(tC) || isempty(tL) || isempty(tD)
    return;
end
try
    d = hours(datetime(tL, 'InputFormat', 'yyyy-MM-dd HH:mm:ss') - ...
        datetime(tC, 'InputFormat', 'yyyy-MM-dd HH:mm:ss'));
    if abs(d - str2double(tD)) <= tolD
        s = 'TRUE';
    else
        s = sprintf('FALSE(应为%.2f)', d);
    end
catch
end
end

%% =====================================================================
function s = addr_(r, c)
col = char('A' + c - 1);
if c > 26
    col = [char('A' + floor((c - 1) / 26) - 1) col];
end
s = sprintf('%s%d', col, r);
end

%% =====================================================================
function [tot, stat, chg] = check_totals(f, sheets, cells, tolSum, tolRest, restHour)
% ② 每列 Added Time = 该列所有 Time Difference 之和；
%    Added Time with Rest = Added Time + n/6
tot  = cell(0, 13);
chg  = cell(0, 9);
stat = struct('n', 0, 'OK', 0, 'FIXED', 0, 'NO_DATA', 0);

for si = 1:numel(sheets)
    sn = sheets{si};
    if any(strcmpi(sn, {'SUMMARY', 'REPORT', 'README'}))
        continue;
    end
    try
        C = readcell(f, 'Sheet', sn);
    catch
        continue;
    end
    rAdd = 0; rRest = 0; rS = 0; rE = 0;
    for r = 3:size(C, 1)
        lb = lower(strtrim(tostr(C{r, 3})));
        if strcmp(lb, 'added time'), rAdd = r;
        elseif strcmp(lb, 'added time with rest'), rRest = r;
        elseif strcmp(lb, 'total start time'), rS = r;
        elseif strcmp(lb, 'total end time'), rE = r;
        end
    end
    for ci = 1:5
        col = 4 + ci;
        sel = strcmp({cells.sheet}, sn) & [cells.si] == si & [cells.ci] == ci;
        sel = sel & ~[cells.isBlank];
        sub = cells(sel);
        if isempty(sub)
            continue;
        end
        obsName = sub(1).obsName;
        dvals = nan(1, numel(sub));
        tCs = cell(1, numel(sub)); tLs = cell(1, numel(sub));
        for i = 1:numel(sub)
            dvals(i) = str2double(sub(i).tD);
            tCs{i} = sub(i).tC;
            tLs{i} = sub(i).tL;
        end
        n = sum(~isnan(dvals));
        s = sum(dvals(~isnan(dvals)));
        expRest = s + n * restHour;
        tAdd  = num_or_empty(C, rAdd, col);
        tRest = num_or_empty(C, rRest, col);
        if n == 0 && isempty(tAdd)
            stat.NO_DATA = stat.NO_DATA + 1;
            continue;
        end
        stat.n = stat.n + 1;
        okAdd  = ~isempty(tAdd)  && abs(tAdd - s) <= tolSum;
        okRest = ~isempty(tRest) && abs(tRest - expRest) <= tolRest;
        status = 'OK'; note = '';
        if isempty(tAdd)
            status = 'MISSING_TOTAL';
            note = '缺少 Added Time 行/值';
        elseif ~okAdd
            status = 'FIXED';
            chg(end+1, :) = {sn, rAdd, col, addr_(rAdd, col), 'Added Time', ...
                tAdd, round(s * 100) / 100, 'sum(diff)', ...
                sprintf('列内 %d 个 Time Difference 之和', n)}; %#ok<AGROW>
            stat.FIXED = stat.FIXED + 1;
            note = sprintf('Added Time 与列内 diff 之和差 %.2f', tAdd - s);
        end
        if ~isempty(tAdd) && isempty(tRest) && rRest > 0
            note = [note ' 缺少 Added Time with Rest'];
        elseif ~isempty(tAdd) && ~isempty(tRest) && ~okRest
            if ~strcmp(status, 'FIXED')
                status = 'FIXED';
                stat.FIXED = stat.FIXED + 1;
            end
            expA = round(s * 100) / 100;
            chg(end+1, :) = {sn, rRest, col, addr_(rRest, col), 'Added Time with Rest', ...
                tRest, round((expA + n * restHour) * 100) / 100, 'Added + n/6', ...
                sprintf('n=%d，每个 file 另加 10 分钟', n)}; %#ok<AGROW>
            note = [note sprintf(' Rest 应为 %.2f（+%d/6）', expA + n * restHour, n)];
        end
        if okAdd && okRest && isempty(note)
            stat.OK = stat.OK + 1;
        end
        % Total Start/End 仅作提示，不自动改
        startEq = 'n/a'; endEq = 'n/a';
        sc = sort(tCs(~cellfun(@isempty, tCs)));
        ec = sort(tLs(~cellfun(@isempty, tLs)));
        if rS > 0 && ~isempty(sc)
            startEq = tf_(strcmp(strtrim(tostr(C{rS, col})), sc{1}));
        end
        if rE > 0 && ~isempty(ec)
            endEq = tf_(strcmp(strtrim(tostr(C{rE, col})), ec{end}));
        end
        tot(end+1, :) = {sn, sprintf('obs%d', ci), obsName, n, ...
            or_empty(tAdd), round(s * 100) / 100, ...
            or_empty(diff_or_nan(tAdd, s)), or_empty(tRest), ...
            round(expRest * 100) / 100, status, startEq, endEq, note}; %#ok<AGROW>
    end
end
end

%% =====================================================================
function v = num_or_empty(C, r, col)
v = [];
if r > 0 && r <= size(C, 1) && col <= size(C, 2)
    x = C{r, col};
    if isnumeric(x) && ~isnan(x)
        v = double(x);
    else
        y = str2double(strtrim(tostr(x)));
        if ~isnan(y)
            v = y;
        end
    end
end
end

%% =====================================================================
function v = or_empty(x)
if isempty(x)
    v = '';
else
    v = round(x * 100) / 100;
end
end

%% =====================================================================
function d = diff_or_nan(a, b)
if isempty(a)
    d = [];
else
    d = a - b;
end
end

%% =====================================================================
function s = tf_(b)
if b
    s = 'TRUE';
else
    s = 'FALSE';
end
end

%% =====================================================================
function write_corrected(src, out, chg)
% 复制原表，仅重写发生改动的 sheet 的 E:I 数据区
if isempty(chg)
    copyfile(src, out, 'f');
    fprintf('   未发现不符合项，修正版与原表内容一致\n');
    return;
end
copyfile(src, out, 'f');
snList = unique(chg(:, 1));
for i = 1:numel(snList)
    sn = snList{i};
    m  = strcmp(chg(:, 1), sn);
    rows = cell2mat(chg(m, 2));
    cols = cell2mat(chg(m, 3));
    vals = chg(m, 7);
    C = readcell(out, 'Sheet', sn);
    if size(C, 2) < 9
        C{size(C, 1), 9} = '';
    end
    if size(C, 1) < max(rows)
        C{max(rows), size(C, 2)} = '';
    end
    for k = 1:numel(rows)
        C{rows(k), cols(k)} = vals{k};
    end
    C = san_cell(C);
    try
        writecell(C(:, 5:9), out, 'Sheet', sn, 'Range', sprintf('E1:I%d', size(C, 1)));
    catch ME
        warning('写回 sheet %s 失败: %s', sn, ME.message);
    end
end
end

%% =====================================================================
function C = san_cell(C)
for i = 1:numel(C)
    v = C{i};
    if isa(v, 'missing')
        C{i} = '';
    elseif isstring(v)
        if ismissing(v)
            C{i} = '';
        end
    elseif isnumeric(v) && isscalar(v) && isnan(v)
        C{i} = '';
    end
end
end

%% =====================================================================
function op = find_orphans(R, cells)
% renamed CSV 中未被表格任何单元格引用的记录（提示性信息）
used = unique([cells.renIdx]);
used = used(used > 0);
op = cell(0, 7);
for k = 1:numel(R)
    if any(used == k)
        continue;
    end
    op(end+1, :) = {R(k).model, R(k).xx, yy_label(R(k).yy), ...
        R(k).c, R(k).l, str2double(R(k).d), R(k).file}; %#ok<AGROW>
end
end

%% =====================================================================
function s = yy_label(yy)
map = {'01', 'Preference'; '02', 'Attractiveness'; '03', 'Health'; ...
       '04', 'Age'; '05', 'Youth'; '06', 'Healthy'; '07', 'Fidelity'; ...
       '08', 'Pink'; '09', 'Fair'; '10', 'Ruddy'};
s = yy;
for i = 1:size(map, 1)
    if strcmp(map{i, 1}, yy)
        s = map{i, 2};
        return;
    end
end
end

%% =====================================================================
function s = tostr(v)
% 统一转成 char
if ischar(v)
    s = v;
elseif isstring(v)
    if ismissing(v)
        s = '';
    else
        s = char(v);
    end
elseif isnumeric(v)
    if isnan(v)
        s = '';
    else
        s = num2str(v);
    end
elseif isdatetime(v)
    s = char(v);
elseif isduration(v)
    s = char(v);
elseif ismissing(v)
    s = '';
else
    s = '';
end
end

%% =====================================================================
function fp = ensure_writable(fp)
% 目标被 Excel 占用时自动换一个可用文件名
if ~isfile(fp)
    return;
end
[folder, name, ext] = fileparts(fp);
for k = 0:20
    if k == 0
        cand = fp;
    else
        cand = fullfile(folder, sprintf('%s_new%d%s', name, k, ext));
    end
    fid = fopen(cand, 'a');
    if fid >= 0
        fclose(fid);
        fp = cand;
        return;
    end
end
error('无法写入: %s', fp);
end

%% =====================================================================
function write_report(f, srcXlsx, outXlsx, stat, totStat, repCell, allChg, ...
    totRows, colMap, orphans, R, nameMap, tolD, tolSum, tolRest, restHour)
if isfile(f)
    try
        delete(f);
    catch
    end
end

% ---------- SUMMARY ----------
nIss = 0;
for i = 1:size(repCell, 1)
    if ~strcmp(repCell{i, 15}, 'OK')
        nIss = nIss + 1;
    end
end
nSrcOnly = 0;
for i = 1:size(repCell, 1)
    if strcmp(repCell{i, 15}, 'OK') && contains(repCell{i, 16}, 'com.example')
        nSrcOnly = nSrcOnly + 1;
    end
end
S = {
    'Item', 'Value'
    '输入表', srcXlsx
    '修正版', outXlsx
    '生成时间', char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))
    '检查单元格总数', stat.n
    '① 完全一致 (OK)', stat.OK
    '   其中仅源码可验证 (renamed 无此文件)', nSrcOnly
    '① 已修正 (FIXED)', stat.FIXED
    '① 冲突 renamed vs 源码 (CONFLICT)', stat.CONFLICT
    '① 列归属异常 (OBS_MISMATCH)', stat.OBS_MISMATCH
    '① 无证据 (UNVERIFIED)', stat.UNVERIFIED
    '空白单元格 (EMPTY)', stat.EMPTY
    'created/last 不一致数', stat.TIME_FAIL
    'diff 不一致数', stat.DIFF_FAIL
    '② 校验列数', totStat.n
    '② 通过', totStat.OK
    '② 已修正', totStat.FIXED
    '改动单元格总数', size(allChg, 1)
    'renamed 未被引用的 CSV', size(orphans, 1)
    'diff 容差 (h)', tolD
    'Added 容差', tolSum
    'Rest 容差', tolRest
    '每 file 附加时间 (h)', restHour
    };
put_sheet(f, 'SUMMARY', S);

% ---------- 分 sheet 统计 ----------
shList = unique(repCell(:, 1));
T = {'Sheet', 'Cells', 'OK', 'FIXED', 'EMPTY', 'UNVERIFIED', 'CONFLICT/OBS'};
for i = 1:numel(shList)
    m = strcmp(repCell(:, 1), shList{i});
    st = repCell(m, 15);
    T(end+1, :) = {shList{i}, sum(m), sum(strcmp(st, 'OK')), sum(strcmp(st, 'FIXED')), ...
        sum(strcmp(st, 'EMPTY')), sum(strcmp(st, 'UNVERIFIED')), ...
        sum(strcmp(st, 'CONFLICT')) + sum(strcmp(st, 'OBS_MISMATCH'))}; %#ok<AGROW>
end
put_sheet(f, 'SUMMARY_BY_SHEET', T);

% ---------- CHANGES ----------
Ch = {'Sheet', 'Cell', 'Field', 'Old', 'New', 'Reason', 'EvidenceFile'};
for i = 1:size(allChg, 1)
    Ch(end+1, :) = {allChg{i, 1}, allChg{i, 4}, allChg{i, 5}, allChg{i, 6}, ...
        allChg{i, 7}, allChg{i, 8}, allChg{i, 9}}; %#ok<AGROW>
end
put_sheet(f, 'CHANGES', Ch);

% ---------- TOTALS ----------
Th = {'Sheet', 'ObsCol', 'Observer', 'nFile', 'Table_Added', 'Sum_of_Diff', ...
      'Delta', 'Table_Rest', 'Expected_Rest', 'Status', ...
      'Start_eq_min', 'End_eq_max', 'Note'};
put_sheet(f, 'TOTALS', [Th; totRows]);

% ---------- CELL_ISSUES ----------
Ih = {'Sheet', 'Row', 'Model', 'Attribute', 'AttrIdx', 'ObsCol', 'Observer', ...
      'Table_Created', 'Table_Last', 'Table_Diff', 'CSV_Created', 'CSV_Last', ...
      'CSV_Diff', 'Source_Diff', 'Status', 'Note'};
Iss = Ih;
for i = 1:size(repCell, 1)
    if ~strcmp(repCell{i, 15}, 'OK')
        Iss(end+1, :) = repCell(i, :); %#ok<AGROW>
    end
end
put_sheet(f, 'CELL_ISSUES', Iss);

% ---------- COLUMN_MAP ----------
CM = {'Sheet', 'Model', 'ObsCol', 'Observer', 'ObsFolder', 'nMatched', ...
      'nDistinctXX', 'SourceNameHint', 'Note'};
ks = keys(colMap);
for i = 1:numel(ks)
    key = ks{i};
    parts = strsplit(key, '|');
    mx = colMap(key);
    observer = ''; obsTag = '';
    if numel(parts) >= 3
        obsTag = sprintf('obs%s', parts{3});
        m = strcmp(repCell(:, 1), parts{1}) & strcmp(repCell(:, 3), parts{2}) ...
            & strcmp(repCell(:, 6), obsTag);
        if any(m)
            idx = find(m, 1);
            observer = repCell{idx, 7};
        end
    end
    hint = '';
    nk = sprintf('%s|%s', parts{2}, mx.xx);
    if isKey(nameMap, nk)
        hint = nameMap(nk);
    end
    note = '';
    if mx.nDistinct > 1
        note = '同一列匹配到多个 obs 文件夹，需人工确认';
    end
    CM(end+1, :) = {parts{1}, parts{2}, obsTag, observer, mx.xx, mx.n, ...
        mx.nDistinct, hint, note}; %#ok<AGROW>
end
% 补充：完全没有 renamed 证据的列（尚未 rename 或日期不同）
combos = unique(strcat(repCell(:, 1), '|', repCell(:, 3), '|', repCell(:, 6)));
for i = 1:numel(combos)
    parts = strsplit(combos{i}, '|');
    if numel(parts) < 3
        continue;
    end
    if isKey(colMap, sprintf('%s|%s|%s', parts{1}, parts{2}, strrep(parts{3}, 'obs', '')))
        continue;
    end
    m = strcmp(repCell(:, 1), parts{1}) & strcmp(repCell(:, 3), parts{2}) ...
        & strcmp(repCell(:, 6), parts{3});
    idx = find(m, 1);
    if isempty(idx)
        continue;
    end
    CM(end+1, :) = {parts{1}, parts{2}, parts{3}, repCell{idx, 7}, 'n/a', 0, 0, '', ...
        '该列无任何 renamed 记录（未 rename 或日期不同），仅能靠源码交叉验证'}; %#ok<AGROW>
end
put_sheet(f, 'COLUMN_MAP', CM);

% ---------- CSV_ORPHANS ----------
OH = {'Model', 'ObsFolder', 'AttrIdx', 'Created', 'Last', 'Diff', 'File'};
put_sheet(f, 'CSV_ORPHANS', [OH; orphans]);

% ---------- README ----------
Rd = {
    '校验脚本', 'verify_work_time.m'
    '① 单元格一致性', 'File Created Time / Last Score Time / Time Difference (hours) 与 renamed CSV 尾三行比对；用 com.example.*p2 源码交叉验证'
    '① 匹配方式', '优先 model+created+last 全等匹配 renamed 记录（可再限制属性 YY），失败再尝试源码，最后按 (model,obsXX,attr) 取文件'
    '① 容差', sprintf('created/last 要求字符串全等；diff 容差 %.3f 小时', tolD)
    '② Added Time', '等于该列所有非空 Time Difference (hours) 之和'
    '② Added Time with Rest', sprintf('等于 Added Time + n*(%0.4f)（n=该列非空 diff 个数，每个 file 另加 10 分钟）', restHour)
    '② 容差', sprintf('Added %.3f h，Rest %.3f h', tolSum, tolRest)
    '③ 修正原则', '仅改写 E:I 数据区；以 renamed 为准，源码仅用于交叉验证；CONFLICT 行会在 Note 中标注并采用 renamed'
    '空白单元格', '不做自动填充（同一 (model,obs,attr) 可能有多批次/多 observer 的同名文件）'
    'UNVERIFIED', 'renamed 与源码都没有相同 created+last 的记录，无法校验，未改动'
    'Total Start/End', '仅做提示性核对（=min(created)/max(last)），不自动修改'
    'CSV_ORPHANS', 'renamed 中未出现在任何表格单元格里的 CSV（可能是未录入表格的新批次数据）'
    };
put_sheet(f, 'README', Rd);
end

%% =====================================================================
function put_sheet(f, sn, D)
if isempty(D)
    D = {'(empty)'};
end
n = 0;
for i = 1:size(D, 1)
    n = max(n, size(D, 2));
end
if size(D, 2) < n
    D(:, end+1:n) = {''};
end
try
    writecell(D, f, 'Sheet', sn);
catch ME
    warning('写 sheet %s 失败: %s', sn, ME.message);
end
end
