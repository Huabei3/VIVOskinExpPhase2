% check_renamed_integrity.m  —— 全目录完整性检查
% -------------------------------------------------------------------------
% 检查 SRC_DIR (默认 ...\ExpRes\renamed) 下的**每一个文件**
% 输出 sheet:
%   SUM       汇总(逐属性命中/TOTAL/完整率/实际文件数/异常数/一致性)
%   {组名}    完整度矩阵: 行=obs%02d_{obs_name}, 列=属性名, 值=TRUE/FALSE
%   INVENTORY renamed 下全部文件的递归清单
%   EXTRA     非规范路径的文件 ({组}\obs_XX\obsXX_AA.csv 之外的一切)
%   MISSING   缺失清单 (组+observer+属性)
%   ISSUES    问题汇总 (空文件/偏小/不可读/零行/组内不一致/空obs目录/缺失组目录)
%   CONSISTENCY 组内一致性: 每组期望的行数/列数/刺激项签名 + 偏差文件数
%
% 着色 (COLOR_TF=true): 写完后用 Excel COM 打开该 xlsx, 把所有内容为
%   TRUE 的单元格填浅绿 #C6EFCE, FALSE 的单元格填浅红 #FFC7CE, 然后存回原文件。
%   覆盖全部 sheet, 因此 {组名} 完整度矩阵 + INVENTORY 的 readable 列都会变色。
% -------------------------------------------------------------------------

close all; clc; clear;

%% ---------- 模块 1: 配置区 ----------
SRC_DIR  = 'D:\work\VIVOSkin_phase2\ExpRes\renamed';
OUT_XLSX = 'D:\work\VIVOSkin_phase2\analyze\data_integrity_renamed.xlsx';

ADD_SUMMARY   = true;   % false = 不输出 SUM 首页
CHECK_CONTENT = true;   % true  = 逐个打开规范文件统计行数/列数/刺激项集合
CHECK_GROUPS  = true;   % true  = 检查 f/m01-10{i,r} 这 40 个组目录哪些不存在
MIN_BYTES     = 8192;   % 小于该字节数 => 标记"偏小(疑似中断)"
MAX_LIST      = 5000;   % 明细 sheet 最多写多少行

COLOR_TF  = true;       % true = 写完后用 Excel COM 给 TRUE 格填绿 / FALSE 格填红
CLR_TRUE  = 13561798;   % 浅绿 #C6EFCE (Excel 的 Interior.Color 是 BGR 整数)
CLR_FALSE = 13551615;   % 浅红 #FFC7CE

OBS_NAMES = ["Malvin","Jerome","moussa","viva","philippe"];
ATTRIBUTES = ["Preference","Attractiveness","Feminine","Cooperative", ...
              "Youth","Healthy","Fidelity","Harmony","Fair","Ruddy"];
OBS_SERIALS = 1:numel(OBS_NAMES);

nObs = numel(OBS_SERIALS);  nAttr = numel(ATTRIBUTES);

fprintf('输入目录: %s\n', SRC_DIR);
fprintf('全目录递归扫描  MIN_BYTES=%d  %s\n', MIN_BYTES, datestr(now,'yyyy-mm-dd HH:MM:SS'));

%% ---------- 模块 2: 扫描组目录 ----------
items = dir(SRC_DIR);  items = items([items.isdir]);
items = items(~ismember({items.name}, {'.','..'}));
groupNames = sort({items.name});  nGroup = numel(groupNames);
if nGroup == 0, error('输入目录下没有任何子文件夹: %s', SRC_DIR); end
fprintf('发现 %d 个组: %s\n', nGroup, strjoin(groupNames, ', '));

%% ---------- 模块 3: 逐组完整度矩阵 ----------
frames = cell(nGroup,1);  mats = cell(nGroup,1);
hitPerAttr = zeros(nGroup,nAttr);  nHitTotal = zeros(nGroup,1);

for g = 1:nGroup
    gName = groupNames{g};
    rowLabel = strings(nObs,1);
    for i = 1:nObs
        s = OBS_SERIALS(i);
        rowLabel(i) = sprintf('obs%02d_%s', s, OBS_NAMES(s));
    end
    mat = strings(nObs,nAttr);
    for i = 1:nObs
        s = OBS_SERIALS(i);
        for a = 1:nAttr
            fp = fullfile(SRC_DIR, gName, sprintf('obs_%02d',s), ...
                          sprintf('obs%02d_%02d.csv', s, a));
            mat(i,a) = ternary(isfile(fp), "TRUE", "FALSE");
        end
    end
    mats{g} = mat;
    T = table(rowLabel, 'VariableNames', {'observer'});
    for a = 1:nAttr
        T.(matlab.lang.makeValidName(ATTRIBUTES(a))) = mat(:,a);
    end
    frames{g} = T;
    hitPerAttr(g,:) = sum(mat == "TRUE", 1);
    nHitTotal(g)    = sum(hitPerAttr(g,:));
    fprintf('  [%-5s] 矩阵命中 %2d/%2d\n', gName, nHitTotal(g), nObs*nAttr);
end

%% ---------- 模块 4: 全目录递归清单 ----------
allItems = dir(fullfile(SRC_DIR,'**','*'));
allItems = allItems(~[allItems.isdir]);
nAll = numel(allItems);

rp = strings(nAll,1); gg = strings(nAll,1); att = strings(nAll,1);
osr = nan(nAll,1); asr = nan(nAll,1); byt = zeros(nAll,1);
modt = strings(nAll,1); ln = nan(nAll,1); nc = nan(nAll,1);
sig = strings(nAll,1); sta = strings(nAll,1); rd = strings(nAll,1);

for k = 1:nAll
    rel = erase(fullfile(allItems(k).folder, allItems(k).name), [SRC_DIR filesep]);
    rp(k)   = string(rel);
    byt(k)  = allItems(k).bytes;
    modt(k) = string(datestr(allItems(k).datenum, 'yyyy-mm-dd HH:MM:SS'));

    relN = strrep(rel, filesep, '/');     % 统一 / 再解析, 避免转义踩坑
    tk = regexp(relN, ['^(?<g>[^/]+)/obs_(?<os>\d{2})/obs(?<os2>\d{2})_(?<a>\d{2})\.csv$'], ...
                'names', 'once');
    if isempty(tk)
        sta(k) = "非规范路径";
    else
        gg(k) = string(tk.g);  osr(k) = str2double(tk.os);  asr(k) = str2double(tk.a);
        if ~strcmp(tk.os, tk.os2)
            sta(k) = "序号不一致";
        elseif ~ismember(osr(k), OBS_SERIALS)
            sta(k) = "obs序号越界";
        elseif asr(k) < 1 || asr(k) > nAttr
            sta(k) = "属性序号越界";
        elseif ~ismember(gg(k), string(groupNames))
            sta(k) = "未知组目录";
        else
            sta(k) = "规范";  att(k) = ATTRIBUTES(asr(k));
        end
    end
end

%% ---------- 模块 5: 内容体检 (行数 / 列数 / 刺激项集合) ----------
% 结果 csv 实际结构:
%   前 3 行是元数据, 不含逗号:
%       File Created Time: 2026-09-23 12:59:18
%       Last Score Time:  2026-09-23 13:22:08
%       Time Difference (hours): 0.38
%   之后每行 "序号,刺激项名,评分" (3 列), 刺激项在第 2 列。
% 同一组内 (同一个 {model}{i/r}) 所有文件应当:
%   总行数相同  &  每行字段数相同  &  刺激项集合完全相同
%   (元数据行的字段数=1, 不计入刺激项; 但计入"行数")
% 任一条不满足 => 该文件被标成"组内不一致"。
if CHECK_CONTENT
    for k = 1:nAll
        if sta(k) ~= "规范", continue; end
        fid = fopen(fullfile(SRC_DIR, rp(k)), 'r', 'n', 'UTF-8');
        if fid < 0, rd(k) = "FALSE"; continue; end
        raw = fread(fid, Inf, '*char')';  fclose(fid);
        rd(k) = "TRUE";
        if isempty(raw), ln(k) = 0; nc(k) = 0; continue; end
        parts = regexp(raw, '\r\n|\n|\r', 'split');
        if ~isempty(parts) && isempty(parts{end}), parts(end) = []; end
        parts = parts(~cellfun(@(s) all(isspace(s)), parts));   % 丢掉空行
        ln(k) = numel(parts);
        if ln(k) == 0, nc(k) = 0; continue; end
        f1 = regexp(parts{1}, ',', 'split');
        nc(k)  = numel(f1);
        col1 = strings(ln(k), 1);
        for q = 1:ln(k)
            fq = regexp(parts{q}, ',', 'split');
            if numel(fq) >= 2, col1(q) = strtrim(string(fq{2})); end
        end
        col1 = unique(col1(col1 ~= ""));
        sig(k) = strhash(strjoin(sort(col1), '|'));
    end
end

%% ---------- 模块 6: 各类异常统计 ----------
% 每组: 实际规范文件数 / 非规范文件数 / 空文件数 / 偏小数
nFilesG = zeros(nGroup,1);  nExtraG = zeros(nGroup,1);
nEmptyG = zeros(nGroup,1);  nSmallG = zeros(nGroup,1);
for g = 1:nGroup
    gName = groupNames{g};
    inG   = startsWith(rp, string(gName) + filesep);
    nFilesG(g) = sum(gg == gName & sta == "规范");
    nExtraG(g) = sum(inG & sta ~= "规范");
    nEmptyG(g) = sum(inG & byt == 0);
    nSmallG(g) = sum(inG & byt > 0 & byt < MIN_BYTES);
end

% 空 obs 目录 (存在 obs_XX 文件夹但里面一个文件都没有)
emptyDirs = strings(0,1);
for g = 1:nGroup
    gp = fullfile(SRC_DIR, groupNames{g});
    sd = dir(gp);  sd = sd([sd.isdir]);
    sd = sd(~ismember({sd.name}, {'.','..'}));
    for q = 1:numel(sd)
        if isempty(regexp(sd(q).name, '^obs_\d{2}$', 'once')), continue; end
        inner = dir(fullfile(gp, sd(q).name));
        inner = inner(~ismember({inner.name}, {'.','..'}));
        if sum(~[inner.isdir]) == 0
            emptyDirs(end+1,1) = string(fullfile(groupNames{g}, sd(q).name)); %#ok<SAGROW>
        end
    end
end

% 期望的组目录是否存在 (f/m01-10{i,r} 共 40 个)
missingGroups = strings(0,1);
if CHECK_GROUPS
    expG = strings(0,1);
    for pre = ["f","m"]
        for kk = 1:10
            for suf = ["i","r"]
                expG(end+1,1) = sprintf('%s%02d%s', pre, kk, suf); %#ok<SAGROW>
            end
        end
    end
    missingGroups = setdiff(expG, string(groupNames));
end

% 一致性: 矩阵命中数 应等于 磁盘上规范文件数
consistent = strings(nGroup,1);
for g = 1:nGroup
    if nFilesG(g) == nHitTotal(g), consistent(g) = "OK"; else, consistent(g) = "不一致"; end
end

% 组内内容一致性: 同一组所有文件应有相同的 (行数, 列数, 刺激项集合)
devFiles  = strings(0,1);            % 与组内多数派不一致的文件
consKey   = strings(nGroup,1);       % 组内多数派的 "行数|列数|签名"
consCnt   = zeros(nGroup,1);         % 多数派包含几个文件
consNDev  = zeros(nGroup,1);         % 该组有几个偏差文件
if CHECK_CONTENT
    for g = 1:nGroup
        idx = find(gg == groupNames{g} & sta == "规范" & rd == "TRUE");
        if isempty(idx), continue; end
        key = strings(numel(idx),1);
        for q = 1:numel(idx)
            key(q) = sprintf('%d|%d|%s', ln(idx(q)), nc(idx(q)), sig(idx(q)));
        end
        [uk, ~, ic] = unique(key);
        cnt = accumarray(ic, 1);
        [mc, mi] = max(cnt);
        consKey(g) = uk(mi);  consCnt(g) = mc;
        for q = 1:numel(idx)
            if key(q) ~= uk(mi)
                devFiles(end+1,1) = rp(idx(q)); %#ok<SAGROW>
                consNDev(g) = consNDev(g) + 1;
            end
        end
    end
end

%% ---------- 模块 7: SUM 汇总表 ----------
Tsum = table(string(groupNames(:)), 'VariableNames', {'group'});
for a = 1:nAttr
    Tsum.(sprintf('a%02d', a)) = hitPerAttr(:,a);
end
Tsum.nTOTAL = nHitTotal;
Tsum.cov    = round(100 * nHitTotal / (nObs*nAttr), 1);
Tsum.nFiles = nFilesG;  Tsum.nExtra = nExtraG;
Tsum.nEmpty = nEmptyG;  Tsum.nSmall = nSmallG;
Tsum.ok     = consistent;
Tsum.Properties.VariableNames = [{'group'}, cellstr(ATTRIBUTES), ...
    {'TOTAL','完整率','nFiles','nExtra','nEmpty','nSmall','一致'}];

%% ---------- 模块 8: 明细表 ----------
usedName = ["INVENTORY","EXTRA","MISSING","ISSUES","CONSISTENCY","SUM"];
Tinventory = table(rp, gg, osr, asr, att, byt, ln, nc, modt, sta, rd, sig, ...
    'VariableNames', {'relpath','group','obs_serial','attr_serial','attribute', ...
                      'bytes','lines','ncol','modified','status','readable','stimsig'});
if height(Tinventory) > MAX_LIST, Tinventory = Tinventory(1:MAX_LIST,:); end

Textra = Tinventory(Tinventory.status ~= "规范", :);
if height(Textra) > MAX_LIST, Textra = Textra(1:MAX_LIST,:); end

% 缺失清单
mg = strings(0,1); mo = strings(0,1); ma = strings(0,1);
for g = 1:nGroup
    for i = 1:nObs
        for a = 1:nAttr
            if mats{g}(i,a) == "FALSE"
                mg(end+1,1) = string(groupNames{g});                       %#ok<SAGROW>
                mo(end+1,1) = sprintf('obs%02d_%s', OBS_SERIALS(i), OBS_NAMES(OBS_SERIALS(i))); %#ok<SAGROW>
                ma(end+1,1) = ATTRIBUTES(a);                               %#ok<SAGROW>
            end
        end
    end
end
Tmissing = table(mg, mo, ma, 'VariableNames', {'group','observer','attribute'});
if height(Tmissing) > MAX_LIST, Tmissing = Tmissing(1:MAX_LIST,:); end

% ISSUES: 问题 / 数量 / 示例
isDev = ismember(rp, devFiles);   % 组内不一致的文件 -> 逻辑掩码
defs = {
  '空文件 (0B)'                 , byt == 0
  sprintf('偏小 (<%d B)',MIN_BYTES), byt > 0 & byt < MIN_BYTES
  '内容不可读'                   , rd == "FALSE"
  '零行文件'                     , ln == 0
  '组内行数/列数/刺激项不一致'    , isDev
  '非规范路径的文件'             , sta == "非规范路径"
  'obs目录与文件名序号不一致'     , sta == "序号不一致"
  'obs 序号越界'                 , sta == "obs序号越界"
  '属性序号越界'                 , sta == "属性序号越界"
  '未知组目录'                   , sta == "未知组目录"
};
ik = strings(0,1); ic = zeros(0,1); ie = strings(0,1);
for q = 1:size(defs,1)
    sel = defs{q,2};  n = sum(sel);
    if n == 0, continue; end
    ik(end+1,1) = string(defs{q,1});  %#ok<SAGROW>
    ic(end+1,1) = n;                  %#ok<SAGROW>
    ex = rp(sel);  ie(end+1,1) = strjoin(ex(1:min(3,numel(ex))), ' | '); %#ok<SAGROW>
end
if ~isempty(emptyDirs)
    ik(end+1,1) = "空 obs 目录";  ic(end+1,1) = numel(emptyDirs);        %#ok<SAGROW>
    ie(end+1,1) = strjoin(emptyDirs(1:min(3,numel(emptyDirs))), ' | ');  %#ok<SAGROW>
end
if ~isempty(missingGroups)
    ik(end+1,1) = "缺失的组目录";  ic(end+1,1) = numel(missingGroups);   %#ok<SAGROW>
    ie(end+1,1) = strjoin(missingGroups(1:min(6,numel(missingGroups))), ' | '); %#ok<SAGROW>
end
Tissues = table(ik, ic, ie, 'VariableNames', {'问题','数量','示例'});

% 组内一致性明细: 每组应该只有一种 (行数, 列数, 刺激项签名)
cG = strings(nGroup,1); cL = nan(nGroup,1); cC = nan(nGroup,1);
cS = strings(nGroup,1); cN = zeros(nGroup,1);
for g = 1:nGroup
    cG(g) = string(groupNames{g});
    tk = regexp(consKey(g), '^(?<l>\d+)\|(?<c>\d+)\|(?<s>.*)$', 'names', 'once');
    if ~isempty(tk)
        cL(g) = str2double(tk.l);  cC(g) = str2double(tk.c);  cS(g) = string(tk.s);
    end
    cN(g) = consNDev(g);
end
Tcons = table(cG, nFilesG, cL, cC, cS, consCnt, cN, ...
    'VariableNames', {'group','nFiles','expect_lines','expect_ncol', ...
                      'expect_stimsig','nMajority','nDeviation'});
if height(Tcons) > MAX_LIST, Tcons = Tcons(1:MAX_LIST,:); end

%% ---------- 模块 9: 写出 xlsx ----------
% 旧文件若在 Excel/WPS 里打开则删不掉, delete 只发 warning; 复查后改用带时间戳的备用名
outFile = OUT_XLSX;
if isfile(outFile)
    w_state = warning('off','all');  delete(outFile);  warning(w_state);
    if isfile(outFile)
        [pth, nm, ext] = fileparts(OUT_XLSX);
        outFile = fullfile(pth, sprintf('%s_%s%s', nm, datestr(now,'yyyymmdd_HHMMSS'), ext));
        fprintf(2, '[提示] %s 被占用 (可能已在 Excel/WPS 中打开),\n       本次改写到: %s\n', OUT_XLSX, outFile);
    end
end

if ADD_SUMMARY, writetable(Tsum, outFile, 'Sheet', 'SUM'); end
for g = 1:nGroup
    nmG = groupNames{g};
    if ismember(upper(string(nmG)), upper(usedName))
        nmG = ['G_' nmG];
    end
    writetable(frames{g}, outFile, 'Sheet', nmG);
end
writetable(Tinventory, outFile, 'Sheet', 'INVENTORY');
if height(Textra)  > 0, writetable(Textra,  outFile, 'Sheet', 'EXTRA');   end
if height(Tmissing)> 0, writetable(Tmissing,outFile, 'Sheet', 'MISSING'); end
if height(Tissues) > 0, writetable(Tissues, outFile, 'Sheet', 'ISSUES');  end
if height(Tcons)   > 0, writetable(Tcons,   outFile, 'Sheet', 'CONSISTENCY'); end

%% ---------- 模块 9b: 着色 (TRUE=绿 / FALSE=红) ----------
if COLOR_TF
    t0 = tic;
    [nClr, clrMsg] = colorize_tf(outFile, CLR_TRUE, CLR_FALSE);
    if nClr < 0
        fprintf(2, '[提示] 未着色: %s\n', clrMsg);
    else
        fprintf('着色完成: 共 %d 个 TRUE/FALSE 单元格 (耗时 %.1f s)\n', nClr, toc(t0));
    end
end

%% ---------- 模块 10: 控制台报告 ----------
fprintf('%s\n', repmat('-',1,64));
fprintf('全目录清单: %d 个文件 (规范 %d / 非规范 %d)\n', ...
        height(Tinventory), sum(sta == "规范"), sum(sta ~= "规范"));
if height(Tissues) > 0
    probTxt = Tissues.('问题');  cntNum = Tissues.('数量');  exTxt = Tissues.('示例');
    fprintf('问题汇总:\n');
    for q = 1:height(Tissues)
        fprintf('  %-28s %4d   %s\n', char(probTxt(q)), cntNum(q), ...
                shorten(char(exTxt(q)), 60));
    end
else
    fprintf('问题汇总: (无)\n');
end
if CHECK_CONTENT
    fprintf('组内一致性 (行数/列数/刺激项集合):\n');
    for g = 1:nGroup
        if consCnt(g) == 0
            fprintf('  %-5s (无文件)\n', groupNames{g});
        else
            tag = 'OK';
            if consNDev(g) > 0, tag = sprintf('** %d 个偏差 **', consNDev(g)); end
            fprintf('  %-5s 行数=%-4d 列数=%d  刺激项签名=%s  多数派=%d/%d  %s\n', ...
                groupNames{g}, cL(g), cC(g), char(cS(g)), consCnt(g), nFilesG(g), tag);
        end
    end
end
fprintf('%s\n', repmat('-',1,64));
fprintf('缺失明细:\n');
if height(Tmissing) == 0
    fprintf('  (无)\n');
else
    for g = 1:nGroup
        sel = Tmissing.group == string(groupNames{g});
        if ~any(sel), continue; end
        lst = strjoin(compose('%s/%s', Tmissing.observer(sel), Tmissing.attribute(sel))', ', ');
        fprintf('  %-5s 缺 %2d: %s\n', groupNames{g}, sum(sel), shorten(char(lst), 100));
    end
end
fprintf('%s\n', repmat('-',1,64));
fprintf('总计: %d/%d (%.1f%%)\n', sum(nHitTotal), nGroup*nObs*nAttr, ...
        100*sum(nHitTotal)/(nGroup*nObs*nAttr));
fprintf('已写出: %s\n', outFile);

%% ---------- 局部函数 ----------
function out = ternary(cond, a, b)
% 三目运算符
if cond, out = a; else, out = b; end
end

function s = shorten(c, n)
% 超长字符串截断, 防止 xlsx 单元格爆长
if isstring(c), c = char(c); end
if numel(c) > n
    s = [c(1:n) '...'];
else
    s = c;
end
end

function [n, msg] = colorize_tf(xlsxFile, clrTrue, clrFalse)
% 用 Excel COM 打开 xlsx, 把"文本内容为 TRUE/FALSE"的单元格填绿/红。
% 扫描所有 sheet, 所以 {组名} 完整度矩阵和 INVENTORY 的 readable 列都会生效。
% 返回: n = 着色单元格数 (失败为 -1), msg = 失败原因 (成功为空串)。
n = -1;  msg = '';
try
    xl = actxserver('Excel.Application');
catch ME
    msg = sprintf('无法启动 Excel COM (%s), 请确认本机装有 Excel 或 WPS 且已注册', ME.message);
    return;
end
try
    xl.Visible = 0;  xl.DisplayAlerts = 0;  xl.ScreenUpdating = 0;
    WB = xl.Workbooks.Open(xlsxFile);
    n  = 0;
    for s = 1:WB.Worksheets.Count
        WS  = WB.Worksheets.Item(s);
        rng = WS.UsedRange;
        nR  = double(rng.Rows.Count);   nC = double(rng.Columns.Count);
        if nR == 0 || nC == 0, continue; end
        r0  = double(rng.Row);          c0 = double(rng.Column);
        vals = rng.Value;               % 整块同类型时返回矩阵, 混合时返回 cell
        if ~iscell(vals), continue; end % 全数字的 sheet 不可能含 TRUE/FALSE
        for r = 1:nR
            rowT = false(1,nC);  rowF = false(1,nC);
            for c = 1:nC
                v = vals{r,c};
                if ~(ischar(v) || (isstring(v) && isscalar(v))), continue; end
                t = upper(strtrim(char(v)));
                if strcmp(t, 'TRUE')
                    rowT(c) = true;
                elseif strcmp(t, 'FALSE')
                    rowF(c) = true;
                end
            end
            n = n + sum(rowT) + sum(rowF);
            rr = r0 + r - 1;
            % 同一行里连续的同类格子合并成一个 Range 一次刷色, 减少 COM 往返
            sg = logical_runs(rowT);
            for q = 1:size(sg,1)
                WS.Range(a1addr(rr, c0+sg(q,1)-1, rr, c0+sg(q,2)-1)).Interior.Color = clrTrue;
            end
            sg = logical_runs(rowF);
            for q = 1:size(sg,1)
                WS.Range(a1addr(rr, c0+sg(q,1)-1, rr, c0+sg(q,2)-1)).Interior.Color = clrFalse;
            end
        end
    end
    WB.Save();
    WB.Close(false);
    xl.Quit();
catch ME
    msg = ME.message;
    try, xl.Quit(); catch, end   %#ok<CTCH>
    n = -1;
end
end

function segs = logical_runs(mask)
% 把逻辑向量里的连续 true 段找出来, 返回 n×2 的 [起点 终点]。
% 注意: MATLAB 的 COM 只认 WS.Range('B2:F2') 这种 A1 写法,
%       WS.Cells.Item(r,c) 会报 "找不到具有匹配签名的方法 Item"。
mask = mask(:)';
if isempty(mask), segs = zeros(0,2); return; end
d = diff([0 mask 0]);
segs = [find(d == 1)', find(d == -1)' - 1];
end

function s = colletter(c)
% 1->A, 26->Z, 27->AA ...
s = '';
while c > 0
    m = mod(c - 1, 26);
    s = [char(65 + m) s];  %#ok<AGROW>
    c = floor((c - 1) / 26);
end
end

function a = a1addr(r1, c1, r2, c2)
% 生成 A1 区域地址; 单格时退化为 "B2"
if r1 == r2 && c1 == c2
    a = sprintf('%s%d', colletter(c1), r1);
else
    a = sprintf('%s%d:%s%d', colletter(c1), r1, colletter(c2), r2);
end
end

function h = strhash(s)
% 轻量字符串指纹 (长-求和-加权和), 用来比较两个刺激项集合是否相同
% 不用 md5 是为了不依赖 Java; 对本用途够用, 且是纯向量化, 快。
b = double(char(s));
n = numel(b);
if n == 0, h = "0-0-0"; return; end
w = mod((1:n)', 1000000007);
h = string(sprintf('%d-%d-%d', n, mod(sum(b), 2^31), ...
                   mod(sum(b(:) .* w), 2^31)));
end
