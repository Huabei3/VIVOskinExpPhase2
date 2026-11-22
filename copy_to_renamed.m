% copy_to_renamed.m
% -------------------------------------------------------------------------
% 把 ExpRes\com.example.{model}{i/r}p2 下的问卷 csv 复制为
%   ExpRes\renamed\{nation}\{model}{i/r}\obs_{i_obs}\obs{i_obs}_{i_attr}.csv
%
% 源位置 (两处, SCAN_MODE 决定是否额外递归):
%   1) com.example.{model}{i/r}p2\{obs name}_{attribute}_{ts}_result_{folder}.csv
%   2) com.example.{model}{i/r}p2\attribute\{attribute}\{obs name}_{attribute}_{ts}_result_{folder}.csv
%
% 规则:
%   1) 文件 < 8KB 不复制        (MIN_BYTES, 上次你定的规矩, 这次没提, 先保留)
%   2) 同一 (nation, group, obs, attr) 多份 -> 取 STRESS_intra 更小的那份
%      (口径与 single_folder_STRESS\process_data_stress.m 对单个 csv 的算法一致,
%       即 cal_STRESS_ind.m; 都算不出/相等时退回"时间戳最新 + 文件较大")
%   3) observer 名单按 nation 分开, 每套名单按位置对应 i_obs (每套内部各自从 1 开始):
%        AF:  A 套 Malvin..Ongama (10 人) / B 套 NIWE..chelsea (10 人) /
%             C 套 atascopy..vanessa (10 人)
%        SA:  A 套 Areeba..Jenny (5 人) / B 套 raz sadia..minahil (5 人) /
%             C 套 Memoona..Bani (5 人) / D 套 ASKARI HASAN..SINGH ARVEEN (5 人) /
%             E 套 shabbir..Araiz Nasik (5 人) / F 套 Taha..Kaleem Ahsan (5 人)
%        同一 nation 内若两批评了同一个组, 用 OBS_SHIFT.(nation)(b) 给后一批加编号偏移,
%        否则会写进同一个 obs_XX 目录互相覆盖 (目前 SA 第 5 批评 m07 与第 2 批重叠)
%      nation 由 observer 人名唯一决定, 所以同一组可以同时有 AF 与 SA 的 obs 编号
%      (AF 的 obs_01 与 SA 的 obs_01 是两个人, 分别落在 renamed\AF 与 renamed\SA 下)
%      不区分大小写; 观测到的拼写变体在 OBS_ALIAS 显式登记 (别名 -> 规范名)
%   4) attribute 不区分大小写, 1..10 = Preference .. Ruddy
%   5) 归属目录 (owner) = 该文件【往上最近的】名字形如 com.example.*p2 的祖先目录,
%      而不是扫描起点的顶层目录。修的是嵌套镜像:
%        com.example.f01rp2\com.example.f02ip2\atascopy_..._result_com.example.f02ip2.csv
%      旧规则拿顶层 f01rp2 去比文件名里的 f02ip2 -> 判不一致 -> 整批 atascopy 被丢
%      新规则 owner = f02ip2 -> 正确归到 f02i。组归属和 {folder} 校验都以 owner 为准
%   6) 文件名里的 {folder} 必须与 owner 目录同名, 否则记为不一致并跳过
%      (owner 找不到时退回顶层目录名, 行为与旧版一致)
%   7) 输出根目录: renamed\{nation}\{group}\obs_{i_obs}\obs{i_obs}_{i_attr}.csv
%   8) 组批白名单: 每个 nation 的 {model} 分 3 个组批 (GROUP_BATCH), 每个组批只采纳
%      自己那几组 observer 的数据; 别的组批的人做了同一组 = 做错了 -> 记入
%      "跨组批跳过" 不予采纳。例外由 ALLOW_OVERRIDE 显式登记
%      (现阶段: SA 的 f09/f10 第 2 组人空缺, 由第 6 组人 Taha..Kaleem 补做)
%   9) WRITE_MAP = true 时额外输出 analyze\copy_map_{nation}.xlsx:
%      每个 sheet = 一个组批; 每行 = model + attribute;
%      列 = i 侧 obs01..10 + r 侧 obs01..10, 单元格 = 该槽位收的 observer 名
% -------------------------------------------------------------------------
% -------------------------------------------------------------------------

close all; clc; clear;

%% ---------- 模块 1: 配置区 (要改的都在这里) ----------
EXP_DIR = 'D:\work\VIVOSkin_phase2\ExpRes';
OUT_DIR = fullfile(EXP_DIR, 'renamed');

MIN_BYTES = 8 * 1024;   % <8KB 不复制; 想全复制就设 0

% 同一 (nation, group, obs, attr) 出现多份 csv 时的取舍规则:
%   'stress' = 取 STRESS_intra 更小者 (现用; 口径 = process_data_stress / cal_STRESS_ind)
%   'time'   = 旧规则, 取时间戳最新, 并列取较大文件
DEDUP_RULE = 'stress';

% 'spec'      = 只看 顶层 与 attribute\{attribute}\ 两处 (你原话给的两处)
% 'recursive' = 组目录下全部 csv (含 2\ 4\ 12345\ NIWE\ 等 156 种父目录)
SCAN_MODE = 'recursive';

CLEAN_OUT = false;      % true = 先清空整个 renamed (危险, 默认不动)
WRITE_LOG = true;       % true = 报告同时写入 analyze\copy_to_renamed_log.txt
WRITE_MAP = true;       % true = 同时输出出处映射 analyze\copy_map_{nation}.xlsx

%% 模块 1b: 名单 (按 nation 分开; obs 编号在各 nation 内部独立从 1 计数)
OBS_SETS = struct();
OBS_SETS.AF = { ...
    {'Malvin', 'Jerome', 'moussa', 'viva', 'philippe', ...#obs1~5 for f04	f01	f07	f09 f08	f10
     'Divine', 'uneza', 'DANIELLA', 'Shanly', 'Ongama'}, ...#obs6~10 
    {'NIWE', 'LUKE MARRION MARUFU', 'Balima Miguel', ...
     'TANATSWA MUKOKANDUKU', 'TANATSWA GWABADA', ...#obs1~5 for f06	f03	m07	m09 m08	m10
     'Mercy', 'Axelle', 'natasha', 'tanya', 'chelsea'}, ...#obs6~10 
    {'atascopy', 'placide', 'Bevin', 'sherlington', 'brian', ...#obs1~5 for f05	f02 m04	m01 m05	m02 m06	m03
     'Kirsty', 'noluthando', 'Samara', 'paballo', 'vanessa'} }; % obs6~10 


OBS_SETS.SA = { ...
    {'Mehak Nazir',	'tayyaba',	'Mariam',	'Areeba',	'ma yi ran' }, ...#obs1~5 for f04	f01	f07	f09 f08	f10 in relace of {'Areeba', 'Alishba', 'Eman', 'Alisha', 'Jenny'}
    {'raz sadia', 'sarwar malaika', 'meenal babar', 'Arooha', 'minahil'}, ...#obs1~5 for f06	f03	m07	m09 m08	m10
    {'Memoona', 'ayesha', 'Amina', 'Pari', 'Bani'}, ...#obs1~5 for f05	f02 m04	m01 m05	m02 m06	m03
    {'ASKARI HASAN', 'QASIM MUHAMMAD ALI', 'ULLAH SAEED', 'ALI RAJAB', 'SINGH ARVEEN'}, ...#obs6~10  f04	f01	f07	 f08 f09 f10
    {'shabbir Muhammad sufyan', 'RAMZAN MUHAMMAD', 'KHALID MUHAMMAD ALI', ...
     'ALISYEDHAMMAD', 'Araiz Nasik'}, ...#obs6~10 for  f06	 f03	m07	m09 m08	m10
    {'Taha Abdur Rehman', 'SHOAIB MUHAMMAD', 'TEHSEEN MUHAMMAD FAISAL', ...
     'AAMISH MUHAMMAD', 'KALEEM AHSAN'} };   %obs6~10   for f05	f02 m04	m01 m05	m02 m06	m03 

NATIONS = fieldnames(OBS_SETS);  % {'AF'; 'SA'}

% obs 编号默认在每批内部从 1 重新计数。若【两批 observer 评了同一个组】，编号会撞到
% 同一个 obs_XX 目录、后写入的覆盖先写入的。给后一批加偏移即可让两批并存:
%   OBS_SHIFT.(nation)(b) = 第 b 批的编号偏移 (0 = 不偏移), 长度必须等于该 nation 的批数
% AF 三批的组互不重叠 -> 全 0
% SA 是「3 个组批 × 2 组人」, 每组的第 2 组人要 +5 才不会覆盖第 1 组人:
%   组批 A (f01 f04 f07 f08 f09 f10):  Areeba..  obs_01..05 / ASKARI..  obs_06..10
%   组批 B (f03 f06 m07 m08 m09 m10):  raz sadia.. obs_01..05 / shabbir.. obs_06..10
%   组批 C (f02 f05 m01..m06)        :  Memoona..  obs_01..05 / Taha..    obs_06..10
% 每组批只有这两组人, +5 就够, 组不重叠所以编号可以复用
OBS_SHIFT = struct();
OBS_SHIFT.AF = [0 0 0];
OBS_SHIFT.SA = [0 0 0 5 5 5];
for ni = 1:numel(NATIONS)
    nat = NATIONS{ni};
    if ~isfield(OBS_SHIFT, nat) || numel(OBS_SHIFT.(nat)) ~= numel(OBS_SETS.(nat))
        error(['OBS_SHIFT.%s 的长度必须等于 OBS_SETS.%s 的批数 (%d)。\n' ...
               '  每批一个偏移量, 不偏移写 0。'], nat, nat, numel(OBS_SETS.(nat)));
    end
end

% ---- 组批: 每个 nation 的 {model} 只有 3 个组批; 每个组批由 OBS_SETS 里的若干组人评 ----
% 规则: 只采纳「自己组批」的人评的数据; 别的组批的人做了同一组 = 做错了, 不予理会
% (与 single_folder_STRESS\export_STRESS_by_observer.m 的 BATCH_MODELS 保持一致)
GROUP_BATCH = struct();
GROUP_BATCH.AF = { ...
    {'f01', 'f04', 'f07', 'f08', 'f09', 'f10'}, ...
    {'f03', 'f06', 'm07', 'm08', 'm09', 'm10'}, ...
    {'f02', 'f05', 'm04', 'm01', 'm05', 'm02', 'm06', 'm03'} };
GROUP_BATCH.SA = { ...
    {'f01', 'f04', 'f07', 'f08', 'f09', 'f10'}, ...
    {'f03', 'f06', 'm07', 'm08', 'm09', 'm10'}, ...
    {'f02', 'f05', 'm01', 'm02', 'm03', 'm04', 'm05', 'm06'} };

% 例外表: 组 -> 允许的人名组号 (覆盖默认的「该组批自己的那几组人」)
%   SA 组批 A 的 f09/f10 没有第 2 组人 (ASKARI 那批只做了 Preference/Healthy),
%   由组批 C 的第 2 组人 (第 6 组: Taha..Kaleem) 补做 -> 允许 [1 6]
ALLOW_OVERRIDE = struct();
ALLOW_OVERRIDE.AF = cell(0, 2);
ALLOW_OVERRIDE.SA = { 'f09', [1 6]; ...
                      'f10', [1 6] };

% 目录里实际出现过的拼写变体 -> 规范名 (键已归一化为大写; 规范名必须出现在名单里)
OBS_ALIAS = { ...
    'MLVIN',               'Malvin'; ...
    'NWE',                 'NIWE'; ...
    'LUKE MARRON MARUFU',  'LUKE MARRION MARUFU'; ...
    'LUKE MARUFU MARUFU',  'LUKE MARRION MARUFU'; ...
    'BALIKMA MIGUEL',      'Balima Miguel'; ...
    'TANATSWA MUKOKANDUU', 'TANATSWA MUKOKANDUKU'; ...
    'PHILIPPPE',           'philippe'; ...
    'SAMAR',               'Samara'; ...
    'PABA;;O',             'paballo'; ...
    'VANESSSA',            'vanessa'; ...
    % --- AF 第 2 批: natasha 的采集端文件名写作 tasha (2026-10-17 同一轮作答) ---
    'TASHA',               'natasha'; ...
    % --- SA: 名单写「名+姓」, 采集端文件名只有「名」, 必须显式登记 ---
    'SADIA',               'raz sadia'; ...
    'SARWAR',              'sarwar malaika'; ...
    'MEENAL',              'meenal babar'; ...
    'AROOHQ',              'Arooha'; ...
    'SADIA SADIA',         'raz sadia'; ...   % 录入时把名字写了两遍
    'SADIA S',             'raz sadia'; ...   % 多打一个空格
    'MEENA',               'meenal babar'; ...% 少一个 l
    % --- SA 第 5 批 (2026-11-06 起): 文件名只写名字里的一段 ---
    'SUFYAN',              'shabbir Muhammad sufyan'; ...
    'RAMZAN',              'RAMZAN MUHAMMAD'; ...
    'ALI',                 'KHALID MUHAMMAD ALI'; ...
    'ALIALI',              'KHALID MUHAMMAD ALI'; ...  % 名字打了两遍
    'ALISYED',             'ALISYEDHAMMAD'; ...
    'ARAIZ',               'Araiz Nasik'; ...          % 预防: 目前还没有她的文件
    % --- SA 第 6 批: 文件用的是第二个名字 ---
    'TAHA',                'Taha Abdur Rehman'; ...
    'SHOAIB',              'SHOAIB MUHAMMAD'; ...
    'FAISAL',              'TEHSEEN MUHAMMAD FAISAL'; ...
    'AAMISH',              'AAMISH MUHAMMAD'; ...
    'AHSAN',               'KALEEM AHSAN'; ...
    % --- 录入端手误 (同一人的错拼) ---
    'FAIASL',              'TEHSEEN MUHAMMAD FAISAL'; ...
    'MEMONA',              'Memoona'; ...
    'SHERLINGOTON',        'sherlington'; ...
    % --- SA 组批 A 第 1 组 (2026-11-16 起代替 Areeba..Jenny), 文件只写名 ---
    'MARYAM',              'Maryam Ali'};   % 注意: 与第 3 位 'Mariam' 是两个人

ATTRS = {'Preference', 'Attractiveness', 'Feminine', 'Cooperative', 'Youth', ...
         'Healthy', 'Fidelity', 'Harmony', 'Fair', 'Ruddy'};
nAttr = numel(ATTRS);

% 每个 nation 的最大 obs 编号 (报告里完整性矩阵的行数; 含批次偏移)
N_OBS_BY_NATION = struct();
for ni = 1:numel(NATIONS)
    nat = NATIONS{ni};
    N_OBS_BY_NATION.(nat) = max([cellfun(@numel, OBS_SETS.(nat)) + OBS_SHIFT.(nat), 0]);
end

%% ---------- 模块 2: 索引表 ----------
OBS_INDEX  = containers.Map('KeyType', 'char', 'ValueType', 'double');  % 归一化名 -> 批内 i_obs
OBS_NATION = containers.Map('KeyType', 'char', 'ValueType', 'char');    % 归一化名 -> nation
OBS_BATCH  = containers.Map('KeyType', 'char', 'ValueType', 'double');  % 归一化名 -> 批号 (取偏移用)
OBS_DISPLAY = containers.Map('KeyType', 'char', 'ValueType', 'char');   % 归一化名 -> 名单里的写法
for ni = 1:numel(NATIONS)
    nat  = NATIONS{ni};
    sets = OBS_SETS.(nat);
    for si = 1:numel(sets)
        for ii = 1:numel(sets{si})
            nm = norm_name(sets{si}{ii});
            if isKey(OBS_INDEX, nm)
                error('observer "%s" 在多个 nation 名单中重复出现, 请检查 OBS_SETS', nm);
            end
            OBS_INDEX(nm)   = ii;
            OBS_NATION(nm)  = nat;
            OBS_BATCH(nm)   = si;
            OBS_DISPLAY(nm) = sets{si}{ii};
        end
    end
end
% 拼写变体: 归一到规范名后沿用规范名的 nation / 编号 / 批号 / 显示名
for r = 1:size(OBS_ALIAS, 1)
    canon = norm_name(OBS_ALIAS{r, 2});
    if ~isKey(OBS_INDEX, canon)
        error('OBS_ALIAS 第 %d 行: 规范名 "%s" 不在 OBS_SETS 名单里', r, OBS_ALIAS{r, 2});
    end
    OBS_INDEX(OBS_ALIAS{r, 1})   = OBS_INDEX(canon);
    OBS_NATION(OBS_ALIAS{r, 1})  = OBS_NATION(canon);
    OBS_BATCH(OBS_ALIAS{r, 1})   = OBS_BATCH(canon);
    OBS_DISPLAY(OBS_ALIAS{r, 1}) = OBS_DISPLAY(canon);
end
ATTR_INDEX = containers.Map('KeyType', 'char', 'ValueType', 'double');
for a = 1:nAttr
    ATTR_INDEX(lower(ATTRS{a})) = a;
end

% 组 -> 允许的人名组号 (默认该组批自己的那几组人; 再套 ALLOW_OVERRIDE 的例外)
ALLOW = struct();
N_SLOTS = struct();     % 每个 nation 一个组批里最大 obs 号 (写映射表用)
for ni = 1:numel(NATIONS)
    nat   = NATIONS{ni};
    nSet  = numel(OBS_SETS.(nat));
    nB    = numel(GROUP_BATCH.(nat));
    if mod(nSet, nB) ~= 0
        error('%s: OBS_SETS 有 %d 组人, GROUP_BATCH 有 %d 个组批, 无法均分', nat, nSet, nB);
    end
    perB = nSet / nB;                       % 每个组批配几组人 (AF=1, SA=2)
    m = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for b = 1:nB
        ok = b + (0:perB - 1) * nB;         % SA 组批 A -> [1 4], B -> [2 5], C -> [3 6]
        for gi = 1:numel(GROUP_BATCH.(nat){b})
            m(GROUP_BATCH.(nat){b}{gi}) = ok;
        end
    end
    ov = ALLOW_OVERRIDE.(nat);
    for r = 1:size(ov, 1)
        m(ov{r, 1}) = ov{r, 2};
    end
    ALLOW.(nat)   = m;
    N_SLOTS.(nat) = max([cellfun(@numel, OBS_SETS.(nat)) + OBS_SHIFT.(nat), 0]);
end

%% ---------- 模块 3: 日志句柄 ----------
if WRITE_LOG
    LOG_FILE = fullfile(fileparts(mfilename('fullpath')), 'copy_to_renamed_log.txt');
    fid = fopen(LOG_FILE, 'w', 'n', 'UTF-8');
    fids = [1, fid];
else
    fids = 1;
end
say(fids, '源目录: %s\n输出根: %s\n扫描模式: %s   MIN_BYTES=%d   %s\n', ...
    EXP_DIR, OUT_DIR, SCAN_MODE, MIN_BYTES, datestr(now, 'yyyy-mm-dd HH:MM:SS'));
for ni = 1:numel(NATIONS)
    say(fids, '  nation %s : 每批人数 = [%s] -> 输出 renamed\\%s\\{group}\\obs_XX\n', ...
        NATIONS{ni}, num2str(cellfun(@numel, OBS_SETS.(NATIONS{ni}))), NATIONS{ni});
end

if CLEAN_OUT && isfolder(OUT_DIR)
    rmdir(OUT_DIR, 's');
    say(fids, '[警告] 已清空输出目录 %s\n', OUT_DIR);
end

%% ---------- 模块 4: 扫描 + 解析 ----------
FOLDER_PAT = '^com\.example\.(?<m>[a-zA-Z0-9]+)(?<ir>[ir])p2$';
FILE_PAT   = '^(?<obs>.+?)_(?<attr>[^_]+)_(?<ts>\d{8}_\d{6})_result_(?<fld>.+)\.csv$';

folders = dir(EXP_DIR);
folders = folders([folders.isdir] & ~ismember({folders.name}, {'.', '..'}));

gName = {}; M = []; pPath = {}; pName = {}; pTs = {}; pObs = {};
skippedSmall = {}; unknownObs = {}; unknownAtr = {}; badName = {};
fldMismatch = {}; crossBatch = {}; nSpec = 0; nAll = 0; nNested = 0;

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

        % ---- 组批白名单: 只采纳「自己组批」的人评的数据 ----
        nat = OBS_NATION(nm);                  % 人名同时决定 nation
        if isKey(ALLOW.(nat), group)
            okSets = ALLOW.(nat)(group);
            if ~ismember(OBS_BATCH(nm), okSets)
                crossBatch{end + 1} = sprintf('%s\\%s | %s (%s) 属第 %d 组人 -> 该组只收第 %s 组', ...
                    nat, group, tk.obs, tk.attr, OBS_BATCH(nm), mat2str(okSets)); %#ok<SAGROW>
                continue;
            end
        end

        if flist(k).bytes < MIN_BYTES
            skippedSmall{end + 1} = sprintf('%s\\%-50s %6dB', group, rel, flist(k).bytes); %#ok<SAGROW>
            continue;
        end

        iAtr = ATTR_INDEX(lower(tk.attr));
        iObs = OBS_INDEX(nm) + OBS_SHIFT.(nat)(OBS_BATCH(nm));   % 批内编号 + 该批偏移
        nIdx = find(strcmp(NATIONS, nat), 1);
        % M 列: [nation 序号, group 序号, obs, attr, 时间戳, 字节数]
        M(end + 1, :) = [nIdx, gIdx, iObs, iAtr, datenum(tk.ts, 'yyyymmdd_HHMMSS'), flist(k).bytes]; %#ok<SAGROW>
        pPath{end + 1} = full;    %#ok<SAGROW>
        pName{end + 1} = rel;     %#ok<SAGROW>
        pTs{end + 1}   = tk.ts;   %#ok<SAGROW>
        pObs{end + 1}  = OBS_DISPLAY(nm);   %#ok<SAGROW>
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
    list(fids, crossBatch, '跳过: 跨组批 (人名不属于该组的组批, 视为做错不予采纳)');
    if WRITE_LOG, fclose(fid); end
    return;
end

%% ---------- 模块 5: 去重 (同 key 取 STRESS_intra 更小者) ----------
% key = [nation group obs attr]
% 同一 key 有多份 csv 时, 取【STRESS_intra 更小】的那份:
%   STRESS_intra 由 cal_STRESS_ind.m 计算, 与 process_data_stress.m 对单个 csv 的
%   算法一致: 先 mapMatrixValues 标准化, 只对"同一刺激被评了两次"的标签取
%   (评分-1)/5 与两者均值算 STRESS; 没有重复评分的 csv 返回 NaN
% 取舍顺序:
%   ① 能算出有限 STRESS_intra 的, 优先于 NaN(无重复评分 -> 无法评估一致性)
%   ② 都有限值 -> 取更小者(评分一致性更好)
%   ③ 全 NaN 或数值相等 -> 旧规则: 时间戳更新优先, 再比文件字节数
% 性能: 只有出现重复的 key 才真的读 csv 算 STRESS; 单份候选直接采用
[uk, ~, gid] = unique(M(:, 1:4), 'rows');
nKey = size(uk, 1);

% cal_STRESS_ind 内部用相对 "utils\", 先切到 analyze 目录再算
here_m     = fileparts(mfilename('fullpath'));
addpath(fullfile(here_m, 'single_folder_STRESS'));
addpath(fullfile(here_m, 'utils'));
old_wd     = cd(here_m);
prev_warn2 = warning('off', 'MATLAB:mpath:nameNonexistentOrNotADirectory');

% STRESS.m 来自外部库 (D:\work\MATLABlib\...\agreement\stress), 不在本工程里。
% 若它或 cal_STRESS_ind 不在路径上, 本次自动退回"时间戳最新 + 文件较大"的旧规则,
% 免得整份脚本因为缺少函数直接报错。
useStress = strcmpi(DEDUP_RULE, 'stress') && ...
            ~isempty(which('cal_STRESS_ind')) && ~isempty(which('STRESS'));
if strcmpi(DEDUP_RULE, 'stress') && ~useStress
    warning(['找不到 cal_STRESS_ind.m 或 STRESS.m, 本次无法按 STRESS_intra 去重, ' ...
             '退回旧规则(时间戳最新 + 文件较大)。\n' ...
             '请先把 MATLABlib 加进路径 (addpath(genpath(''D:\work\MATLABlib''))) 再重跑。']);
end

win     = zeros(nKey, 1);       % 赢家在 M / pPath 中的下标
sWin    = nan(nKey, 1);         % 赢家的 STRESS_intra
dupInfo = cell(0, 1);           % 重复 key 的取舍记录(写进日志)
nEval   = 0;                    % 实际计算过 STRESS 的文件数

for i = 1:nKey
    rows = find(gid == i);
    if numel(rows) == 1
        win(i) = rows;          % 只有一份, 不用算 STRESS
        continue
    end

    if ~useStress
        % 退路: 时间戳最新 -> 文件较大
        [~, ord] = sortrows([-M(rows, 5), -M(rows, 6)]);
        win(i) = rows(ord(1));
        continue
    end

    s = nan(numel(rows), 1);
    seenSig = cell(numel(rows), 1);      % 同一份文件的多拷贝只算一次
    for t = 1:numel(rows)
        sig = sprintf('%s|%d', pTs{rows(t)}, M(rows(t), 6));
        hit = find(strcmp(seenSig(1:t - 1), sig), 1);
        if ~isempty(hit)
            s(t) = s(hit);
            continue
        end
        seenSig{t} = sig;
        try
            s(t) = cal_STRESS_ind(pPath{rows(t)});
            nEval = nEval + 1;
        catch ME
            warning('STRESS_intra 计算失败(该候选排到最后): %s\n  -> %s', ...
                pPath{rows(t)}, ME.message);
        end
    end

    sCmp = s;  sCmp(isnan(sCmp)) = Inf;                      % NaN -> 最差
    [~, ord] = sortrows([sCmp, -M(rows, 5), -M(rows, 6)]);   % STRESS 升, ts 降, size 降
    win(i)  = rows(ord(1));
    sWin(i) = s(ord(1));

    parts = cell(numel(rows), 1);
    for t = 1:numel(rows)
        parts{t} = sprintf('s=%s', num2str(s(t), '%.4g'));
    end
    dupInfo{end + 1, 1} = sprintf('%s/%s obs%02d_%02d -> %s (%s) | 候选: %s', ...
        NATIONS{uk(i, 1)}, gName{uk(i, 2)}, uk(i, 3), uk(i, 4), ...
        pName{rows(ord(1))}, parts{ord(1)}, strjoin(parts', ', '));
end

cd(old_wd);                     % 还原工作目录
warning(prev_warn2);

[win, si] = sort(win);          % 再按原始顺序排好, 便于报告
Ms   = M(win, :);
nDup = accumarray(gid, 1);      % 每个 key 的候选条数
nDup = nDup(si);


%% ---------- 模块 6: 复制 ----------
for i = 1:nKey
    nIdx = Ms(i, 1); gi = Ms(i, 2); o = Ms(i, 3); a = Ms(i, 4);
    dstDir = fullfile(OUT_DIR, NATIONS{nIdx}, gName{gi}, sprintf('obs_%02d', o));
    if ~isfolder(dstDir), mkdir(dstDir); end
    copyfile(pPath{win(i)}, fullfile(dstDir, sprintf('obs%02d_%02d.csv', o, a)));
end

%% ---------- 模块 6.5: 出处映射 xlsx (每个 nation 一个文件, 每个 sheet = 一个组批) ----------
% 每行: model | attribute | 之后 2*N_SLOTS 列 = i 侧 obs01..NN + r 侧 obs01..NN
% 单元格 = 该槽位最终收的是哪位 observer 的源文件 (空 = 没有)
if WRITE_MAP
    PMAP = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for i = 1:nKey
        g    = gName{Ms(i, 2)};
        key  = sprintf('%s|%s|%d|%s', NATIONS{Ms(i, 1)}, g(1:end - 1), Ms(i, 4), g(end));
        if ~isKey(PMAP, key), PMAP(key) = cell(1, 20); end
        c = PMAP(key);
        c{Ms(i, 3)} = pObs{win(i)};
        PMAP(key) = c;
    end
    for ni = 1:numel(NATIONS)
        nat   = NATIONS{ni};
        nSlot = N_SLOTS.(nat);
        mapX  = fullfile(fileparts(mfilename('fullpath')), sprintf('copy_map_%s.xlsx', nat));
        if exist(mapX, 'file') == 2, delete(mapX); end
        for b = 1:numel(GROUP_BATCH.(nat))
            rows = [{'model', 'attribute'}, compose('%di', 1:nSlot), compose('%dr', 1:nSlot)];
            for mi = 1:numel(GROUP_BATCH.(nat){b})
                model = GROUP_BATCH.(nat){b}{mi};
                for a = 1:nAttr
                    row = {model, ATTRS{a}};
                    for side = {'i', 'r'}
                        key = sprintf('%s|%s|%d|%s', nat, model, a, side{1});
                        c = repmat({''}, 1, nSlot);
                        if isKey(PMAP, key), c = PMAP(key); end
                        row = [row, c]; %#ok<AGROW>
                    end
                    rows(end + 1, :) = row; %#ok<AGROW>
                end
            end
            writecell(rows, mapX, 'Sheet', sprintf('batch_%s', char(64 + b)));
        end
        say(fids, '\n出处映射已写入: %s  (%d 个 sheet: batch_A..batch_%s)\n', ...
            mapX, numel(GROUP_BATCH.(nat)), char(64 + numel(GROUP_BATCH.(nat))));
    end
end

%% ---------- 模块 7: 报告 ----------
say(fids, '\n%s\n复制结果: 共 %d 个文件\n%s\n', repmat('=', 1, 72), nKey, repmat('=', 1, 72));
for ni = 1:numel(NATIONS)
    for gi = 1:numel(gName)
        sel = Ms(:, 1) == ni & Ms(:, 2) == gi;
        if ~any(sel), continue; end
        say(fids, '\n[%s\%s] %d 个\n', NATIONS{ni}, gName{gi}, sum(sel));
        for i = find(sel)'
            say(fids, '  obs%02d_%02d <- %-56s %6dB  %s  S=%s\n', ...
                Ms(i, 3), Ms(i, 4), pName{win(i)}, Ms(i, 6), pTs{win(i)}, ...
                num2str(sWin(i), '%.4g'));
        end
    end
end
say(fids, '\n总计复制: %d 个 (候选 %d 条, 去重掉 %d 条)\n', nKey, numel(win), ...
    sum(max(0, nDup - 1)));

say(fids, '\n%s\n完整性矩阵 (行=obs 1-N, 列=attr 1-10; 1=有 .=缺)\n%s\n', ...
    repmat('=', 1, 72), repmat('=', 1, 72));
for ni = 1:numel(NATIONS)
    nat  = NATIONS{ni};
    nObs = N_OBS_BY_NATION.(nat);
    for gi = 1:numel(gName)
        sel = Ms(:, 1) == ni & Ms(:, 2) == gi;
        if ~any(sel), continue; end
        oo = Ms(sel, 3); aa = Ms(sel, 4);
        say(fids, '\n[%s\%s]   (%d/%d)\n        %s\n', nat, gName{gi}, sum(sel), ...
            nObs * nAttr, strjoin(compose('%3d', 1:nAttr), ''));
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
end

%% ---------- 模块 8: 诊断 ----------
say(fids, '\n%s\n诊断\n%s\n', repmat('=', 1, 72), repmat('=', 1, 72));
agg(fids, unknownObs, '未映射的 observer 名称 (按出现次数排序)');
agg(fids, unknownAtr, '未映射的 attribute 名称');
agg(fids, skippedSmall, sprintf('跳过: 文件 < %d B', MIN_BYTES), true);
agg(fids, badName, '跳过: 文件名不符合 {obs}_{attr}_{ts}_result_{folder}.csv');
agg(fids, fldMismatch, '跳过: 文件名里的 folder 与归属目录 (最近的 com.example.*p2) 不一致');
list(fids, crossBatch, '跳过: 跨组批 (人名不属于该组的组批, 视为做错不予采纳)');

say(fids, '\n--- INFO: 重复文件取舍 (STRESS_intra 更小者胜) ---\n');
say(fids, '  实际计算 STRESS_intra 的 csv 数: %d (S=NaN 表示该文件没有重复评分)\n', nEval);
if isempty(dupInfo)
    say(fids, '  (无重复候选)\n');
else
    for i = 1:numel(dupInfo)
        say(fids, '  %s\n', dupInfo{i});
    end
end
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

function list(fids, items, title, maxShow)
% 逐条打印 (不聚合), 超过 maxShow 条时截断
if nargin < 4, maxShow = 120; end
say(fids, '\n--- %s ---\n', title);
if isempty(items)
    say(fids, '  (无)\n');
    return;
end
say(fids, '  共 %d 条:\n', numel(items));
for i = 1:min(numel(items), maxShow)
    say(fids, '    %s\n', items{i});
end
if numel(items) > maxShow
    say(fids, '    ... 其余 %d 条省略\n', numel(items) - maxShow);
end
end
