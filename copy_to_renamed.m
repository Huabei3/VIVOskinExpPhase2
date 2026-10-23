% copy_to_renamed.m
% -------------------------------------------------------------------------
% 把 ExpRes\com.example.{model}{i/r}p2 下的问卷 csv 复制为
%   ExpRes\renamed\{model}{i/r}\obs_{i_obs}\obs{i_obs}_{i_attr}.csv
%
% 源位置 (两处, SCAN_MODE 决定是否额外递归):
%   1) com.example.{model}{i/r}p2\{obs name}_{attribute}_{ts}_result_{folder}.csv
%   2) com.example.{model}{i/r}p2\attribute\{attribute}\{obs name}_{attribute}_{ts}_result_{folder}.csv
%
% 规则:
%   1) 文件 < 8KB 不复制        (MIN_BYTES, 上次你定的规矩, 这次没提, 先保留)
%   2) 同一 (group,obs,attr) 多份 -> 取时间戳最新, 并列取较大文件
%   3) observer 三套名单按 i_obs 位置对应 (每套内部各自 1..5):
%        i_obs : 1          2                    3             4                     5
%        A 套  : Malvin     Jerome               moussa        viva                  philippe
%        B 套  : NIWE       LUKE MARRION MARUFU  Balima Miguel TANATSWA MUKOKANDUKU   TANATSWA GWABADA
%        C 套  : atascopy   placide              Bevin         sherlington            brian   (batch3)
%      不区分大小写; 观测到的拼写变体在 OBS_ALIAS 显式登记
%   4) attribute 不区分大小写, 1..10 = Preference .. Ruddy
%   5) 归属目录 (owner) = 该文件【往上最近的】名字形如 com.example.*p2 的祖先目录,
%      而不是扫描起点的顶层目录。修的是嵌套镜像:
%        com.example.f01rp2\com.example.f02ip2\atascopy_..._result_com.example.f02ip2.csv
%      旧规则拿顶层 f01rp2 去比文件名里的 f02ip2 -> 判不一致 -> 整批 atascopy 被丢
%      新规则 owner = f02ip2 -> 正确归到 f02i。组归属和 {folder} 校验都以 owner 为准
%   6) 文件名里的 {folder} 必须与 owner 目录同名, 否则记为不一致并跳过
%      (owner 找不到时退回顶层目录名, 行为与旧版一致)
% -------------------------------------------------------------------------

close all; clc; clear;

%% ---------- 模块 1: 配置区 (要改的都在这里) ----------
EXP_DIR = 'D:\work\VIVOSkin_phase2\ExpRes';
OUT_DIR = fullfile(EXP_DIR, 'renamed');

MIN_BYTES = 8 * 1024;   % <8KB 不复制; 想全复制就设 0

% 'spec'      = 只看 顶层 与 attribute\{attribute}\ 两处 (你原话给的两处)
% 'recursive' = 组目录下全部 csv (含 2\ 4\ 12345\ NIWE\ 等 156 种父目录)
SCAN_MODE = 'recursive';

CLEAN_OUT = false;      % true = 先清空整个 renamed (危险, 默认不动)
WRITE_LOG = true;       % true = 报告同时写入 analyze\copy_to_renamed_log.txt

%% 模块 1b: 名单
OBS_SETS = { ...
    {'Malvin', 'Jerome', 'moussa', 'viva', 'philippe',...
    'Divine',	'uneza',	'DANIELLA',	'Shanly',	'Ongama',...
    'Areeba',	'Alishba', 	'Eman', 	'Alisha',	'Jenny'}, ...
    {'NIWE', 'LUKE MARRION MARUFU', 'Balima Miguel', ...
     'TANATSWA MUKOKANDUKU', 'TANATSWA GWABADA',...
     'Mercy',	'Axelle',	'natasha',	'tanya',	'chelsea',...
     'raz sadia',	'sarwar', 'malaika',	'meenal',	'minahil'}, ...
    {'atascopy', 'placide', 'Bevin', 'sherlington', 'brian',...
    'Kirsty',	'noluthando',	'Samara',	'paballo',	'vanessa'} };   % 第 3 套 = batch3

% 目录里实际出现过的拼写变体 -> i_obs (已归一为大写)
OBS_ALIAS = { ...
    'MLVIN',               1; ...   % Malvin
    'NWE',                 1; ...   % NIWE
    'LUKE MARRON MARUFU',  2; ...
    'LUKE MARUFU MARUFU',  2; ...
    'BALIKMA MIGUEL',      3; ...
    'TANATSWA MUKOKANDUU', 4; ...
    'PHILIPPPE',           5; ...   % philippe
    'SAMAR',               8; ...   % Samara 少一个 a   (f02rp2, Healthy)
    'PABA;;O',             9; ...   % paballo, LL 录成两个分号 (f05ip2, Healthy)
    'VANESSSA',           10};      % vanessa 拼成 3 个 s (m02ip2, Preference)

ATTRS = {'Preference', 'Attractiveness', 'Feminine', 'Cooperative', 'Youth', ...
         'Healthy', 'Fidelity', 'Harmony', 'Fair', 'Ruddy'};
nObs = 5;  nAttr = numel(ATTRS);

%% ---------- 模块 2: 索引表 ----------
OBS_INDEX = containers.Map('KeyType', 'char', 'ValueType', 'double');
for si = 1:numel(OBS_SETS)
    for ii = 1:numel(OBS_SETS{si})
        OBS_INDEX(norm_name(OBS_SETS{si}{ii})) = ii;
    end
end
for r = 1:size(OBS_ALIAS, 1)
    OBS_INDEX(OBS_ALIAS{r, 1}) = OBS_ALIAS{r, 2};
end
ATTR_INDEX = containers.Map('KeyType', 'char', 'ValueType', 'double');
for a = 1:nAttr
    ATTR_INDEX(lower(ATTRS{a})) = a;
end

%% ---------- 模块 3: 日志句柄 ----------
if WRITE_LOG
    LOG_FILE = fullfile(fileparts(mfilename('fullpath')), 'copy_to_renamed_log.txt');
    fid = fopen(LOG_FILE, 'w', 'n', 'UTF-8');
    fids = [1, fid];
else
    fids = 1;
end
say(fids, '源目录: %s\n输出到: %s\n扫描模式: %s   MIN_BYTES=%d   %s\n', ...
    EXP_DIR, OUT_DIR, SCAN_MODE, MIN_BYTES, datestr(now, 'yyyy-mm-dd HH:MM:SS'));

if CLEAN_OUT && isfolder(OUT_DIR)
    rmdir(OUT_DIR, 's');
    say(fids, '[警告] 已清空输出目录 %s\n', OUT_DIR);
end

%% ---------- 模块 4: 扫描 + 解析 ----------
FOLDER_PAT = '^com\.example\.(?<m>[a-zA-Z0-9]+)(?<ir>[ir])p2$';
FILE_PAT   = '^(?<obs>.+?)_(?<attr>[^_]+)_(?<ts>\d{8}_\d{6})_result_(?<fld>.+)\.csv$';

folders = dir(EXP_DIR);
folders = folders([folders.isdir] & ~ismember({folders.name}, {'.', '..'}));

gName = {}; M = []; pPath = {}; pName = {}; pTs = {};
skippedSmall = {}; unknownObs = {}; unknownAtr = {}; badName = {};
fldMismatch = {}; nSpec = 0; nAll = 0; nNested = 0;

for fi = 1:numel(folders)
    fname = folders(fi).name;
    fpath = fullfile(EXP_DIR, fname);
    tm = regexp(fname, FOLDER_PAT, 'names', 'once');
    if isempty(tm), continue; end
    % 顶层目录所属组: 只用来登记组清单 (保留旧版"空组也出现在报告里"的行为)
    % 以及 owner 一层都找不到时的兜底
    topGroup = [tm.m, tm.ir];
    if ~any(strcmp(gName, topGroup)), gName{end + 1} = topGroup; end   %#ok<SAGROW>

    if strcmpi(SCAN_MODE, 'recursive')
        flist = dir(fullfile(fpath, '**', '*.csv'));
    else
        flist = [dir(fullfile(fpath, '*.csv')); dir(fullfile(fpath, 'attribute', '*', '*.csv'))];
    end

    for k = 1:numel(flist)
        full = fullfile(flist(k).folder, flist(k).name);
        rel  = strrep(full, [fpath, filesep], '');
        nAll = nAll + 1;
        parts = strsplit(rel, filesep);
        if (numel(parts) == 1) || (numel(parts) == 3 && strcmpi(parts{1}, 'attribute'))
            nSpec = nSpec + 1;
        end

        % ---- owner 修法: 归属 = 往上最近的 com.example.*p2 祖先目录 (顶层兜底) ----
        own = owner_of(rel, fname, FOLDER_PAT);
        om  = regexp(own, FOLDER_PAT, 'names', 'once');
        if isempty(om)
            group = topGroup;
        else
            group = [om.m, om.ir];
        end
        if ~any(strcmp(gName, group)), gName{end + 1} = group; end   %#ok<SAGROW>
        gIdx = find(strcmp(gName, group), 1);
        if ~strcmpi(own, fname), nNested = nNested + 1; end          % 来自嵌套镜像

        tk = regexp(flist(k).name, FILE_PAT, 'names', 'once');
        if isempty(tk)
            badName{end + 1} = [group, '\', rel]; %#ok<SAGROW>
            continue;
        end
        if ~strcmpi(tk.fld, own)
            fldMismatch{end + 1} = [group, '\', rel]; %#ok<SAGROW>
            continue;
        end
        nm = norm_name(tk.obs);
        if ~isKey(OBS_INDEX, nm)
            unknownObs{end + 1} = [group, '\', tk.obs]; %#ok<SAGROW>
            continue;
        end
        if ~isKey(ATTR_INDEX, lower(tk.attr))
            unknownAtr{end + 1} = [group, '\', tk.attr]; %#ok<SAGROW>
            continue;
        end
        if flist(k).bytes < MIN_BYTES
            skippedSmall{end + 1} = sprintf('%s\\%-50s %6dB', group, rel, flist(k).bytes); %#ok<SAGROW>
            continue;
        end

        iObs = OBS_INDEX(nm); iAtr = ATTR_INDEX(lower(tk.attr));
        M(end + 1, :) = [gIdx, iObs, iAtr, datenum(tk.ts, 'yyyymmdd_HHMMSS'), flist(k).bytes]; %#ok<SAGROW>
        pPath{end + 1} = full;    %#ok<SAGROW>
        pName{end + 1} = rel;     %#ok<SAGROW>
        pTs{end + 1}   = tk.ts;   %#ok<SAGROW>
    end
end
say(fids, '扫描到 csv: %d 个 (其中落在你给的规则两处位置的 %d 个)\n', nAll, nSpec);

% 兜底: 一个候选都没有时, 先把诊断打出来再退出, 免得后面 empty 索引报错
if isempty(M)
    say(fids, '\n[中止] 没有可复制的候选文件。诊断如下:\n');
    agg(fids, unknownObs,  '未映射的 observer 名称');
    agg(fids, unknownAtr,  '未映射的 attribute 名称');
    agg(fids, fldMismatch, '文件名 folder 与所在文件夹不一致');
    agg(fids, badName,     '文件名无法解析');
    agg(fids, skippedSmall, sprintf('文件 < %d B', MIN_BYTES), true);
    if WRITE_LOG, fclose(fid); end
    return;
end

%% ---------- 模块 5: 去重 (同 key 取时间戳最新, 并列取较大) ----------
% 先按 [group obs attr] 升序 + [ts size] 降序排, 则每个 key 的首次出现即赢家
[~, perm] = sortrows([M(:, 1:3), -M(:, 4), -M(:, 5)]);
MsAll = M(perm, :);
[~, ia] = unique(MsAll(:, 1:3), 'rows', 'first');   % ia 是 MsAll 的行号
win = perm(ia);          % 赢家在原始 M / pPath 中的下标
Ms  = MsAll(ia, :);      % 赢家矩阵 (注意: 必须用 ia 取行, 不能拿 si 切全表!)
[win, si] = sort(win);   % 再按原始顺序排好, 便于报告
Ms  = Ms(si, :);
nKey = numel(win);

nDup = zeros(nKey, 1);
for i = 1:nKey
    nDup(i) = sum(M(:, 1) == Ms(i, 1) & M(:, 2) == Ms(i, 2) & M(:, 3) == Ms(i, 3));
end


%% ---------- 模块 6: 复制 ----------
for i = 1:nKey
    gi = Ms(i, 1); o = Ms(i, 2); a = Ms(i, 3);
    dstDir = fullfile(OUT_DIR, gName{gi}, sprintf('obs_%02d', o));
    if ~isfolder(dstDir), mkdir(dstDir); end
    copyfile(pPath{win(i)}, fullfile(dstDir, sprintf('obs%02d_%02d.csv', o, a)));
end

%% ---------- 模块 7: 报告 ----------
say(fids, '\n%s\n复制结果: 共 %d 个文件\n%s\n', repmat('=', 1, 72), nKey, repmat('=', 1, 72));
for gi = 1:numel(gName)
    sel = Ms(:, 1) == gi;
    say(fids, '\n[%s] %d 个\n', gName{gi}, sum(sel));
    for i = find(sel)'
        say(fids, '  obs%02d_%02d <- %-56s %6dB  %s\n', ...
            Ms(i, 2), Ms(i, 3), pName{win(i)}, Ms(i, 5), pTs{win(i)});
    end
end
say(fids, '\n总计复制: %d 个 (候选 %d 条, 去重掉 %d 条)\n', nKey, numel(win), ...
    sum(max(0, nDup - 1)));

say(fids, '\n%s\n完整性矩阵 (行=obs 1-5, 列=attr 1-10; 1=有 .=缺)\n%s\n', ...
    repmat('=', 1, 72), repmat('=', 1, 72));
for gi = 1:numel(gName)
    sel = Ms(:, 1) == gi;
    oo = Ms(sel, 2); aa = Ms(sel, 3);
    say(fids, '\n[%s]   (%d/50)\n        %s\n', gName{gi}, sum(sel), ...
        strjoin(compose('%3d', 1:nAttr), ''));
    miss = {};
    for o = 1:nObs
        row = repmat('.', 1, nAttr);
        for a = 1:nAttr
            if any(oo == o & aa == a), row(a) = '1'; else, miss{end + 1} = ...
                sprintf('obs%02d_%02d', o, a); end %#ok<SAGROW>
        end
        say(fids, '  obs%02d %s\n', o, strjoin(cellstr(row')', '  '));
    end
    if isempty(miss)
        say(fids, '  缺失: 无\n');
    else
        say(fids, '  缺失(%d): %s\n', numel(miss), strjoin(miss, ' '));
    end
end

%% ---------- 模块 8: 诊断 ----------
say(fids, '\n%s\n诊断\n%s\n', repmat('=', 1, 72), repmat('=', 1, 72));
agg(fids, unknownObs, '未映射的 observer 名称 (按出现次数排序)');
agg(fids, unknownAtr, '未映射的 attribute 名称');
agg(fids, skippedSmall, sprintf('跳过: 文件 < %d B', MIN_BYTES), true);
agg(fids, badName, '跳过: 文件名不符合 {obs}_{attr}_{ts}_result_{folder}.csv');
agg(fids, fldMismatch, '跳过: 文件名里的 folder 与归属目录 (最近的 com.example.*p2) 不一致');
if strcmpi(SCAN_MODE, 'recursive')
    say(fids, '\n--- INFO: 扫描口径 ---\n');
    say(fids, '  recursive 收到 %d 个 csv; 其中落在他两处规则目录内的 %d 个, 另有 %d 个来自 2\\ 4\\ 12345\\ 等目录\n', ...
        nAll, nSpec, nAll - nSpec);
    say(fids, '  把 SCAN_MODE 改成 ''spec'' 就只看那两处 (会少 %d 个)\n', nAll - nSpec);
end
say(fids, '\n--- INFO: owner 判定 ---\n');
say(fids, '  归属来自嵌套镜像目录的候选: %d 个 (旧规则会因 "顶层目录名 != 文件名 folder" 全丢)\n', nNested);

say(fids, '\n完成。输出根目录: %s\n', OUT_DIR);
if WRITE_LOG
    say(fids, '报告已写入: %s\n', LOG_FILE);
    fclose(fid);
end

%% ---------- 局部函数 ----------
function s = norm_name(s)
% 归一化 observer 名: 去首尾空格、内部空白压成单个空格、转大写
s = strtrim(s);
s = regexprep(s, '\s+', ' ');
s = upper(s);
end

function own = owner_of(rel, top_name, pat)
% 归属目录 = 该文件往上【最近的】名字符合 pat (com.example.*p2) 的祖先目录。
% 一个都没有 (文件直接躺在顶层目录里, 或只在 attribute\{attr}\ 下) 时用顶层目录名。
% 这样嵌套镜像 com.example.f01rp2\com.example.f02ip2\xx.csv 会归到 f02i 而不是 f01r。
% 输入:
%   rel      : 相对顶层扫描目录的相对路径 (含文件名)
%   top_name : 顶层扫描目录名 (兜底)
%   pat      : 匹配 p2 目录名的正则
parts = strsplit(rel, filesep);
own = top_name;
for p = numel(parts) - 1 : -1 : 1          % 由深到浅, 命中最近的一个就返回
    if ~isempty(regexp(parts{p}, pat, 'names', 'once'))
        own = parts{p};
        return;
    end
end
end

function say(fids, fmt, varargin)
% 同时写多个句柄 (1 = 命令行, 其它 = 文件)
for k = 1:numel(fids)
    fprintf(fids(k), fmt, varargin{:});
end
end

function agg(fids, items, title, showRaw)
% 把 'group\name' 形式的一批条目按 name 聚合计数后输出
if nargin < 4, showRaw = false; end
say(fids, '\n--- %s ---\n', title);
if isempty(items)
    say(fids, '  (无)\n');
    return;
end
keys = items;
if ~showRaw
    for i = 1:numel(items)
        p = strfind(items{i}, '\');
        if ~isempty(p), keys{i} = items{i}(p(end) + 1:end); end
    end
else
    for i = 1:numel(items)
        parts = strsplit(strtrim(items{i}));
        keys{i} = parts{end};        % 取最后一段(去掉 group 前缀和大小)
    end
end
[u, ~, ic] = unique(keys);
cnt = accumarray(ic(:), 1);
[cnt, ord] = sort(cnt, 'descend');
u = u(ord);
say(fids, '  共 %d 条, %d 个不同名称\n', numel(items), numel(u));
for i = 1:numel(u)
    say(fids, '    %-30s %5d\n', u{i}, cnt(i));
end
end
