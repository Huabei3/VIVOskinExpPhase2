function fill_work_time()
%FILL_WORK_TIME  根据 CSV 元信息填充 ExpRes\work time.xlsx 中所有空白单元格
%
% 数据源（按优先级）：
%   1) ExpRes\renamed\{model}\obs_{XX}\obs{XX}_{YY}.csv      主数据源
%   2) ExpRes\com.example.{model}{i/r}p2\*.csv               备用/交叉验证
%      （尚未 rename 的数据，如 batch5）
%
% 每个 csv 末尾三行：
%   File Created Time: yyyy-MM-dd HH:mm:ss
%   Last Score Time:   yyyy-MM-dd HH:mm:ss
%   Time Difference (hours): x.xx
%
% 输出：
%   analyze\work time_filled.xlsx   原表填充（保留 A-D 列与格式）+ REPORT sheet
%   analyze\work_time_report.csv    明细报告
%
% 用法：matlab -batch "fill_work_time"

%% ================= 配置 =================
srcXlsx     = 'D:\work\VIVOSkin_phase2\ExpRes\work time.xlsx';
outXlsx     = 'D:\work\VIVOSkin_phase2\analyze\work time_filled.xlsx';
reportCsv   = 'D:\work\VIVOSkin_phase2\analyze\work_time_report.csv';
renamedRoot = 'D:\work\VIVOSkin_phase2\ExpRes\renamed';
expresRoot  = 'D:\work\VIVOSkin_phase2\ExpRes';

if ~isfile(srcXlsx)
    error('找不到源表: %s', srcXlsx);
end

% 目标文件若被 Excel/WPS 打开，自动退到 _v2/_v3...
outXlsx   = ensure_writable(outXlsx);
reportCsv = ensure_writable(reportCsv);
fprintf('输出: %s\n', outXlsx);

fprintf('==== 1/4 扫描源码 CSV ====\n');
src = scan_source(expresRoot);
fprintf('   源码记录(去重后): %d\n', numel(src));

fprintf('==== 2/4 扫描 renamed CSV 并回连 observer 名 ====\n');
ren = scan_renamed(renamedRoot, src);
fprintf('   renamed 记录: %d\n', numel(ren));
nNamed = sum(~cellfun(@isempty, {ren.obsName}));
fprintf('   成功回连 observer 名: %d / %d\n', nNamed, numel(ren));

fprintf('==== 3/4 读取并填充 work time.xlsx ====\n');
[rep, nFill, nMiss, nAmb, batchAgg] = fill_sheets(srcXlsx, outXlsx, src, ren);
fprintf('   已填: %d 格 | 缺失: %d 格 | 多候选/别名: %d 处\n', ...
    nFill, nMiss, nAmb);

fprintf('==== 4/4 写报告 ====\n');
write_summary(outXlsx, batchAgg);
write_report(outXlsx, reportCsv, rep);
fprintf('完成:\n   %s\n   %s\n', outXlsx, reportCsv);
end


%% =====================================================================
%% 扫描源码 CSV
%% =====================================================================
function S = scan_source(root)
% 文件名: {obs}_{attr}_{YYYYMMDD}_{HHMMSS}_result_com.example.{model}{i/r}p2.csv
% 个别文件后缀被截断（如 ..._result_com.example..csv），此时从所在目录名取 model
patStrict = '^(.+?)_([A-Za-z]+)_(\d{8})_(\d{6})_result_com\.example\.([fm]\d{2})([ir])p2\.csv$';
patLoose  = '^(.+?)_([A-Za-z]+)_(\d{8})_(\d{6})_result_com\.example\..*\.csv$';
dirPat    = 'com\.example\.([fm]\d{2})([ir])p2$';
files = dir(fullfile(root, '**', '*.csv'));

S = struct('model', {}, 'obs', {}, 'attr', {}, 'date', {}, 'time', {}, ...
    'created', {}, 'last', {}, 'diff', {}, 'file', {}, 'note', {});

for k = 1:numel(files)
    f = files(k);
    if contains(lower(f.folder), 'renamed')
        continue;
    end
    note = '';
    tok = regexp(f.name, patStrict, 'tokens', 'once');
    if ~isempty(tok)
        model = [tok{5} tok{6}];
        obs = tok{1}; attr = tok{2}; date = tok{3}; tm = tok{4};
    else
        tok = regexp(f.name, patLoose, 'tokens', 'once');
        if isempty(tok)
            continue;
        end
        dm = regexp(f.folder, dirPat, 'tokens', 'once');
        if isempty(dm)
            continue;
        end
        model = [dm{1} dm{2}];
        obs = tok{1}; attr = tok{2}; date = tok{3}; tm = tok{4};
        note = 'BROKEN_FILENAME';
    end
    fp = fullfile(f.folder, f.name);
    info = read_csv_meta(fp);
    if isempty(info.created)
        continue;
    end
    S(end+1) = struct('model', model, 'obs', obs, 'attr', attr, ...
        'date', date, 'time', tm, 'created', info.created, ...
        'last', info.last, 'diff', info.diff, 'file', fp, 'note', note); %#ok<AGROW>
end

% 去重: 同一 (model, obs, attr, created, last) 只保留一条
if ~isempty(S)
    key = strcat({S.model}, '|', lower({S.obs}), '|', {S.attr}, '|', ...
        {S.created}, '|', {S.last});
    [~, ia] = unique(key, 'stable');
    S = S(sort(ia));
end
end


%% =====================================================================
%% 扫描 renamed 并以 (created,last) 回连源码得到 observer 名
%% =====================================================================
function R = scan_renamed(root, src)
R = struct('model', {}, 'obsXX', {}, 'iattr', {}, 'created', {}, 'last', {}, ...
    'diff', {}, 'file', {}, 'obsName', {}, 'attrName', {});

if ~isfolder(root)
    return;
end

% 时间索引: model|created|last -> 源码下标数组
tmap = containers.Map('KeyType', 'char', 'ValueType', 'any');
for k = 1:numel(src)
    key = sprintf('%s|%s|%s', src(k).model, src(k).created, src(k).last);
    if isKey(tmap, key)
        v = tmap(key);
    else
        v = [];
    end
    v(end+1) = k; %#ok<AGROW>
    tmap(key) = v;
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
        obsXX = regexprep(obsDirs(j).name, '^obs_', '');
        csvs = dir(fullfile(root, model, obsDirs(j).name, 'obs*_*.csv'));
        for k = 1:numel(csvs)
            tok = regexp(csvs(k).name, '^obs(\d{2})_(\d{2})\.csv$', 'tokens', 'once');
            if isempty(tok)
                continue;
            end
            fp = fullfile(root, model, obsDirs(j).name, csvs(k).name);
            info = read_csv_meta(fp);
            obsName = ''; attrName = '';
            key = sprintf('%s|%s|%s', model, info.created, info.last);
            if isKey(tmap, key)
                idx = tmap(key);
                for q = 1:numel(idx)
                    if strcmp(src(idx(q)).model, model)
                        obsName = src(idx(q)).obs;
                        attrName = src(idx(q)).attr;
                        break;
                    end
                end
            end
            R(end+1) = struct('model', model, 'obsXX', obsXX, ...
                'iattr', tok{2}, 'created', info.created, 'last', info.last, ...
                'diff', info.diff, 'file', fp, 'obsName', obsName, ...
                'attrName', attrName); %#ok<AGROW>
        end
    end
end
end


%% =====================================================================
%% 读取 csv 末尾三行元信息
%% =====================================================================
function info = read_csv_meta(fp)
info = struct('created', '', 'last', '', 'diff', '');
try
    txt = fileread(fp);
catch
    return;
end
lines = regexp(txt, '\r?\n', 'split');
n = numel(lines);
for i = max(1, n - 10):n
    ln = strtrim(lines{i});
    if startsWith(ln, 'File Created Time:')
        info.created = strtrim(extractAfter(ln, 'File Created Time:'));
    elseif startsWith(ln, 'Last Score Time:')
        info.last = strtrim(extractAfter(ln, 'Last Score Time:'));
    elseif startsWith(ln, 'Time Difference (hours):')
        info.diff = strtrim(extractAfter(ln, 'Time Difference (hours):'));
    end
end
end


%% =====================================================================
%% 填充主逻辑
%% =====================================================================
function [rep, nFill, nMiss, nAmb, batchAgg] = fill_sheets(srcXlsx, outXlsx, src, ren)
rep = {};           % 报告行 (cell)
nFill = 0; nMiss = 0; nAmb = 0;

REST_HOUR = 1/6;    % 每个 file 额外加的休息时间（10 分钟）

% ---- 时间修正 / 校准规则 -------------------------------------------
% (a) 个别文件 File Created Time 机器记录错误，按原始 created 精确匹配后覆盖
%     shanly_Preference_20261012_171027 (f10r) 实际为 2026-10-13 11:40:44
OVR_CREATED = { ...
    '2026-10-12 17:10:27', '2026-10-13 11:40:44'};
% (b) batch1~4 obs5 的机器时间整体偏移：
%     机器 2025-08-03 16:59:33 == 实际 2026-10-13 09:53:55
CALIB_FROM  = '2025-08-03 16:59:33';
CALIB_TO    = '2026-10-13 09:53:55';
CALIB_BATCH = {'batch1', 'batch2', 'batch3', 'batch4'};
CALIB_COL   = 5;              % 仅 obs5
CALIB_PREFIX = '2025-';       % 仅校准机器记录成 2025 年的时间戳
calibOff = to_dt(CALIB_TO) - to_dt(CALIB_FROM);
if isempty(calibOff)
    error('校准基准时间解析失败');
end

% 每个 (sheet, obs列) 的时间收集，用于 Total 行
totStart = containers.Map('KeyType', 'char', 'ValueType', 'any');
totEnd   = containers.Map('KeyType', 'char', 'ValueType', 'any');
totDiff  = containers.Map('KeyType', 'char', 'ValueType', 'any');
% 每个 batch 每 obs 的跨 sheet 累计（用于 SUMMARY）
batchAgg = containers.Map('KeyType', 'char', 'ValueType', 'any');

copyfile(srcXlsx, outXlsx);   % 先复制，保留原表样式
sheets = sheetnames(srcXlsx);

for si = 1:numel(sheets)
    sn = sheets{si};
    fprintf('   [%d/%d] %s\n', si, numel(sheets), sn);
    try
        C = readcell(srcXlsx, 'Sheet', sn);
    catch ME
        fprintf('      读取失败: %s\n', ME.message);
        continue;
    end
    [nr, nc] = size(C);
    if nc < 9
        C(:, end+1:9) = {missing};
        nc = 9;
    end
    outC = C;
    totalRow = [];
    sheetHasCalib = false;
    batchName = regexprep(strtrim(sn), '\s*day\s*\d+\s*$', '', 'ignorecase');

    % 表头 obs1..obs5 (第2行, 第5-9列)
    obsNames = cell(1, 5);
    for ci = 1:5
        obsNames{ci} = tostr(C{2, 4+ci});
    end

    % 预取该 sheet 用到的各 model 候选
    modelCache = containers.Map('KeyType', 'char', 'ValueType', 'any');

    for r = 3:nr
        model = tostr(C{r, 1});
        attr  = tostr(C{r, 2});
        lab   = tostr(C{r, 3});
        if isempty(model) || isempty(attr) || ~startsWith(strtrim(lab), 'File Created Time')
            continue;
        end
        model = strtrim(model);
        attr  = strtrim(attr);

        % 该 model 的 renamed 候选（obsXX -> obsName）与 attr 映射
        if ~isKey(modelCache, model)
            modelCache(model) = build_model_index(ren, model);
        end
        mi = modelCache(model);

        for ci = 1:5
            col = 4 + ci;
            obsName = obsNames{ci};
            status = ''; source = ''; note = '';
            created = ''; last = ''; diff = '';

            % --- 1) renamed ---
            [obsXX, how] = match_obs(obsName, mi.obsNames, mi.obsXX);
            if ~isempty(obsXX)
                ia = find_attr_index(mi, attr);
                if ~isempty(ia)
                    hit = find(strcmp({ren.model}, model) & ...
                        strcmp({ren.obsXX}, obsXX) & strcmp({ren.iattr}, ia), 1);
                    if ~isempty(hit)
                        created = ren(hit).created;
                        last    = ren(hit).last;
                        diff    = ren(hit).diff;
                        source  = 'renamed';
                        status  = 'FILLED';
                    end
                end
            end

            % --- 2) 源码回退 ---
            if isempty(created)
                km = find(strcmp({src.model}, model) & ...
                    strcmpi({src.attr}, attr) & ...
                    strcmpi({src.obs}, obsName), 1);
                if isempty(km)
                    % 名字做规范化/别名后再找
                    cand = {src(strcmp({src.model}, model) & strcmpi({src.attr}, attr)).obs};
                    [nm, ~] = match_obs(obsName, cellfun(@normalize_name, cand, ...
                        'UniformOutput', false), cand);
                    if ~isempty(nm)
                        km = find(strcmp({src.model}, model) & ...
                            strcmpi({src.attr}, attr) & ...
                            strcmpi({src.obs}, nm), 1);
                    end
                end
                if ~isempty(km)
                    % 同 (model,obs,attr) 多候选：
                    %   取 Time Difference 最大的一条（实际评分最完整），并列时取较晚
                    same = find(strcmp({src.model}, model) & ...
                        strcmpi({src.attr}, attr) & ...
                        strcmpi({src.obs}, src(km).obs));
                    if numel(same) > 1
                        [~, ord] = sort({src(same).created});
                        same = same(ord);
                        dv = zeros(numel(same), 1);
                        for q = 1:numel(same)
                            dv(q) = str2double(src(same(q)).diff);
                            if isnan(dv(q)), dv(q) = -Inf; end
                        end
                        [~, im] = max(dv);
                        % 记录全部候选
                        parts = cell(1, numel(same));
                        for q = 1:numel(same)
                            parts{q} = sprintf('%s(%.2fh)', ...
                                src(same(q)).created, dv(q));
                        end
                        note = sprintf('MULTI(%d): %s', numel(same), ...
                            strjoin(parts, ' | '));
                        same = same(im);
                        nAmb = nAmb + 1;
                    end
                    km = same(1);
                    created = src(km).created;
                    last    = src(km).last;
                    diff    = src(km).diff;
                    source  = 'source_csv';
                    status  = 'FILLED';
                    if how ~= "" && ~strcmp(how, 'exact')
                        note = strtrim([note ' NAME:' how]);
                    end
                    if ~isempty(src(km).note)
                        note = strtrim([note ' ' src(km).note]);
                    end
                end
            end

            % --- 写值 / 记录 ---
            if ~isempty(created)
                % ① 单文件 created 机器时间错误：按原始值精确匹配后覆盖，diff 重算
                rawCreated = created;
                rawLast    = last;
                calibTag   = '';
                for q = 1:size(OVR_CREATED, 1)
                    if strcmp(strtrim(created), OVR_CREATED{q, 1})
                        created = OVR_CREATED{q, 2};
                        d2 = to_dt(last) - to_dt(created);
                        if ~isempty(d2)
                            diff = sprintf('%.2f', hours(d2));
                        end
                        calibTag = sprintf(' CREATED_FIXED(%s -> %s)', ...
                            OVR_CREATED{q, 1}, OVR_CREATED{q, 2});
                        note = strtrim([note calibTag]);
                        break;
                    end
                end

                % ② batch1~4 obs5 机器时间整体校准（只处理 2025 年的记录）
                if isempty(calibTag) && ci == CALIB_COL && ...
                        any(strcmp(batchName, CALIB_BATCH)) && ...
                        startsWith(strtrim(created), CALIB_PREFIX)
                    c2 = to_dt(created) + calibOff;
                    l2 = to_dt(last) + calibOff;
                    if ~isempty(c2) && ~isempty(l2)
                        created = char(c2, 'yyyy-MM-dd HH:mm:ss');
                        last    = char(l2, 'yyyy-MM-dd HH:mm:ss');
                        calibTag = sprintf(' CALIBRATED(%s -> %s)', ...
                            rawCreated, created);
                        note = strtrim([note calibTag]);
                    end
                end

                outC{r, col}     = created;
                outC{r+1, col}   = last;
                outC{r+2, col}   = diff;
                if ~isempty(calibTag)
                    outC{r,   10} = rawCreated;   % J 列：校准前时间，便于追查
                    outC{r+1, 10} = rawLast;
                    sheetHasCalib = true;
                end
                nFill = nFill + 1;
                % 汇总
                k = sprintf('%s|%d', sn, ci);
                if ~isKey(totStart, k), totStart(k) = {}; end
                if ~isKey(totEnd, k),   totEnd(k) = {}; end
                if ~isKey(totDiff, k),  totDiff(k) = {}; end
                v = totStart(k); v{end+1} = created; totStart(k) = v;
                v = totEnd(k);   v{end+1} = last;    totEnd(k) = v;
                v = totDiff(k);  v{end+1} = str2double(diff); totDiff(k) = v;
            else
                status = 'MISSING';
                nMiss = nMiss + 1;
            end

            rep(end+1, :) = {sn, model, attr, sprintf('obs%d', ci), obsName, ...
                status, source, created, last, diff, note}; %#ok<AGROW>
        end
    end

    % ---- Total Start / Total End / Added Time / Added Time with Rest ----
    % Added Time        = 该列所有 file 的 Time Difference (hours) 之和
    % Added Time w/Rest = sum(Time Difference + 1/6 h)，即每个 file 额外 10 分钟
    for r = 3:nr
        lab = strtrim(tostr(C{r, 3}));
        if ~strcmp(lab, 'Total Start Time')
            continue;
        end
        totalRow = r;
        outC{r+3, 3} = 'Added Time with Rest';
        for ci = 1:5
            col = 4 + ci;
            k = sprintf('%s|%d', sn, ci);
            if ~isKey(totDiff, k) || isempty(totDiff(k))
                continue;
            end
            dv = cell2mat(totDiff(k));
            dv = dv(~isnan(dv));
            if isempty(dv)
                continue;
            end
            added     = sum(dv);
            addedRest = added + numel(dv) * REST_HOUR;

            % Start/End 仍保留实际时间跨度（供参考）
            if isKey(totStart, k) && ~isempty(totStart(k))
                ds = to_dt(totStart(k));
                de = to_dt(totEnd(k));
                if ~isempty(ds) && ~isempty(de)
                    outC{r,   col} = char(min(ds), 'yyyy-MM-dd HH:mm:ss');
                    outC{r+1, col} = char(max(de), 'yyyy-MM-dd HH:mm:ss');
                end
            end
            outC{r+2, col} = sprintf('%.2f', added);
            outC{r+3, col} = sprintf('%.2f', addedRest);

            rep(end+1, :) = {sn, '', 'TOTAL', sprintf('obs%d', ci), ...
                obsNames{ci}, 'FILLED', 'computed', ...
                tostr(outC{r, col}), tostr(outC{r+1, col}), ...
                sprintf('%.2f', added), ...
                sprintf('n=%d; with_rest=%.2f', numel(dv), addedRest)}; %#ok<AGROW>

            % 累计到 SUMMARY（同一 batch 的多个 day）
            bk = sprintf('%s|%s', batchName, obsNames{ci});
            if isKey(batchAgg, bk)
                s = batchAgg(bk);
            else
                s = struct('batch', batchName, 'obs', obsNames{ci}, ...
                    'obsIdx', ci, 'days', 0, 'nFile', 0, ...
                    'added', 0, 'addedRest', 0, 'missing', 0);
            end
            s.days      = s.days + 1;
            s.nFile     = s.nFile + numel(dv);
            s.added     = s.added + added;
            s.addedRest = s.addedRest + addedRest;
            batchAgg(bk) = s;
        end
    end

    % ---- 只写数据区 E:J，保留 A-D 列 ----
    outC = sanitary(outC);
    if size(outC, 2) < 10
        outC(:, end+1:10) = {''};
    end
    if sheetHasCalib
        outC{2, 10} = 'Original Time (before calibration)';
    end
    writecell(outC(:, 5:10), outXlsx, 'Sheet', sn, ...
        'Range', sprintf('E1:J%d', size(outC, 1)));
    % C 列新增标签（不覆盖其它 C 列内容）
    if ~isempty(totalRow)
        writecell({'Added Time with Rest'}, outXlsx, 'Sheet', sn, ...
            'Range', sprintf('C%d', totalRow + 3));
    end
end
end


%% =====================================================================
%% 构造某 model 的候选索引
%% =====================================================================
function mi = build_model_index(ren, model)
% obsXX -> obsName (多数投票)
mi = struct('obsXX', {{}}, 'obsNames', {{}}, 'attrName', {{}}, 'attrIdx', {{}});

msk = strcmp({ren.model}, model);
if ~any(msk)
    return;
end
sub = ren(msk);

% --- obsXX -> obsName ---
uObs = unique({sub.obsXX});
for i = 1:numel(uObs)
    s2 = sub(strcmp({sub.obsXX}, uObs{i}));
    nm = {s2.obsName};
    nm = nm(~cellfun(@isempty, nm));
    if isempty(nm)
        continue;
    end
    [~, ~, ic] = unique(lower(nm));
    cnt = accumarray(ic, 1);
    [~, im] = max(cnt);
    mi.obsXX{end+1} = uObs{i};
    mi.obsNames{end+1} = normalize_name(nm{im});
end

% --- iattr -> attrName ---
uAttr = unique({sub.iattr});
for i = 1:numel(uAttr)
    s2 = sub(strcmp({sub.iattr}, uAttr{i}));
    an = {s2.attrName};
    an = an(~cellfun(@isempty, an));
    if isempty(an)
        continue;
    end
    [~, ~, ic] = unique(lower(an));
    cnt = accumarray(ic, 1);
    [~, im] = max(cnt);
    mi.attrIdx{end+1} = uAttr{i};
    mi.attrName{end+1} = lower(an{im});
end
end


%% =====================================================================
%% 属性名 -> i_attribute 编号
%% =====================================================================
function ia = find_attr_index(mi, attr)
ia = '';
a = lower(strtrim(attr));
for i = 1:numel(mi.attrIdx)
    if strcmp(mi.attrName{i}, a)
        ia = mi.attrIdx{i};
        return;
    end
end
end


%% =====================================================================
%% observer 名匹配
%% =====================================================================
function [obsXX, how] = match_obs(name, candNorm, candObs)
% candNorm: 规范化后的候选名  candObs: 对应 obsXX
obsXX = ''; how = '';
n = normalize_name(name);
if isempty(n) || isempty(candNorm)
    return;
end

% 1) 规范化精确匹配
idx = find(strcmp(candNorm, n));
if numel(idx) == 1
    obsXX = candObs{idx}; how = 'exact'; return;
elseif numel(idx) > 1
    obsXX = candObs{idx(1)}; how = 'exact_multi'; return;
end

% 2) 别名
na = alias_name(n);
if ~strcmp(na, n)
    idx = find(strcmp(candNorm, na));
    if ~isempty(idx)
        obsXX = candObs{idx(1)}; how = ['alias->' na]; return;
    end
end

% 3) 前缀/包含匹配
for i = 1:numel(candNorm)
    c = candNorm{i};
    if startsWith(c, n) || startsWith(n, c)
        obsXX = candObs{i}; how = 'prefix'; return;
    end
end
end


%% =====================================================================
%% 名称规范化与别名
%% =====================================================================
function s = normalize_name(s)
s = lower(strtrim(char(s)));
s = regexprep(s, '[^a-z0-9]', '');
end

function a = alias_name(s)
% 已知写法的别名映射（依据 ExpRes 中实际出现过的变体）
alias = {
    'natasha',          'tasha';
    'nasha',            'tasha';
    'chele',            'chelsea';
    'chelssea',         'chelsea';
    'chelseaa',         'chelsea';
    'niwenshimeamosgyuy','niwe';
    'lukemarrionmarufu','lukemarrionmarufu';
    };
a = s;
for i = 1:size(alias, 1)
    if strcmp(s, alias{i, 1})
        a = alias{i, 2};
        return;
    end
end
end


%% =====================================================================
%% 工具函数
%% =====================================================================
function s = tostr(v)
if ischar(v)
    s = v;
elseif isstring(v)
    s = char(v);
elseif ismissing(v)
    s = '';
elseif isnumeric(v) && isnan(v)
    s = '';
elseif isdatetime(v)
    s = datestr(v, 'yyyy-mm-dd HH:MM:SS');
else
    s = '';
end
end

function dt = to_dt(c)
dt = [];
try
    dt = datetime(c, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
catch
    try
        dt = datetime(c);
    catch
    end
end
end

function C = sanitary(C)
% 把 writecell 不支持的 missing/NaN 空值转成空字符串
for i = 1:numel(C)
    v = C{i};
    if isa(v, 'missing')
        C{i} = '';
    elseif isnumeric(v) && isscalar(v) && isnan(v)
        C{i} = '';
    elseif iscell(v) && isempty(v)
        C{i} = '';
    elseif isempty(v)
        C{i} = '';
    end
end
end

function p = ensure_writable(p)
% 若目标 xlsx 被占用，返回第一个可写的备用路径（_v2/_v3/...）
[d, nm, ext] = fileparts(p);
for k = 0:9
    if k == 0
        cand = p;
    else
        cand = fullfile(d, sprintf('%s_v%d%s', nm, k + 1, ext));
    end
    if ~isfile(cand)
        p = cand;
        return;
    end
    f = fopen(cand, 'r+');
    if f >= 0
        fclose(f);
        p = cand;
        return;
    end
end
error('找不到可写的输出路径: %s', p);
end


%% =====================================================================
%% 写 SUMMARY sheet（每个 batch × 每个 observer 的三天合计）
%% =====================================================================
function write_summary(outXlsx, batchAgg)
if isempty(batchAgg) || batchAgg.Count == 0
    return;
end
keys = batchAgg.keys;
n = numel(keys);

B    = cell(n, 7);
bnum = zeros(n, 1);
oidx = zeros(n, 1);
for i = 1:n
    s = batchAgg(keys{i});
    tok = regexp(s.batch, '(\d+)', 'tokens', 'once');
    if isempty(tok)
        bnum(i) = 999;
    else
        bnum(i) = str2double(tok{1});
    end
    oidx(i) = s.obsIdx;
    B(i, :) = {s.batch, s.obs, s.days, s.nFile, ...
        round(s.added * 100) / 100, round(s.addedRest * 100) / 100, ...
        sprintf('%.2f', s.addedRest - s.added)};
end
[~, ord] = sortrows([bnum oidx]);
B = B(ord, :);

hdr = {'Batch', 'Observer', 'Days', 'nFile', ...
    'Added Time', 'Added Time with Rest', 'Rest Total'};
try
    writecell([hdr; B], outXlsx, 'Sheet', 'SUMMARY');
catch ME
    fprintf('   SUMMARY 写入失败: %s\n', ME.message);
end
end


%% =====================================================================
%% 写报告
%% =====================================================================
function write_report(outXlsx, reportCsv, rep)
if isempty(rep)
    return;
end
varnames = {'Sheet', 'Model', 'Attribute', 'ObsIndex', 'Observer', ...
    'Status', 'Source', 'FileCreatedTime', 'LastScoreTime', ...
    'TimeDifference', 'Note'};
T = cell2table(rep, 'VariableNames', varnames);

% csv 明细
writetable(T, reportCsv);
% xlsx 内 REPORT sheet
try
    writetable(T, outXlsx, 'Sheet', 'REPORT');
catch ME
    fprintf('   REPORT sheet 写入失败: %s\n', ME.message);
end

% 控制台摘要
fprintf('   ---- 状态统计 ----\n');
[st, ~, ic] = unique(T.Status);
for i = 1:numel(st)
    fprintf('   %-10s : %d\n', st{i}, sum(ic == i));
end
missRows = T(strcmp(T.Status, 'MISSING'), :);
if height(missRows) > 0
    fprintf('   ---- 缺失明细（前 30 条）----\n');
    showN = min(30, height(missRows));
    for i = 1:showN
        fprintf('   %s | %s | %s | %s | %s\n', ...
            missRows.Sheet{i}, missRows.Model{i}, missRows.Attribute{i}, ...
            missRows.ObsIndex{i}, missRows.Observer{i});
    end
end
end
