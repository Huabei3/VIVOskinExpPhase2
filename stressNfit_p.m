% rehash toolboxcache % 解决无法访问以前可以访问的文件，重新处理工具箱缓存
close all; % 关闭所有图窗
clc;       % 清空命令窗口
clear;     % 清除工作区所有变量
addpath("utils\")
%% 生成目录
% 
% phase2 新数据（ExpRes\renamed 下实际存在的 4 组）
% lastParts = {'f09i', 'f09r', 'f10i', 'f10r'};

% 旧数据（20 组）
lastParts = {'f04i', 'f05i', 'f06i', 'm04i', 'm05i', 'm06i',...
'f01i', 'f02i', 'f03i', 'm01i', 'm02i', 'm03i',...
'f07i', 'f08i','m07i', 'm08i',...
'f09i', 'f10i','m09i', 'm10i',...
'f04r', 'f05r', 'f06r', 'm04r', 'm05r', 'm06r',...
'f01r', 'f02r', 'f03r', 'm01r', 'm02r', 'm03r',...
'f07r', 'f08r','m07r', 'm08r',...
'f09r', 'f10r','m09r', 'm10r'};

% lastParts = {'f04r', 'f05r', 'f06r', 'm04r', 'm05r', 'm06r',...
% 'f01r', 'f02r', 'f03r', 'm01r', 'm02r', 'm03r',...
% 'f07r', 'f08r','m07r', 'm08r',...
% 'f09r', 'f10r','m09r', 'm10r'};

% Dtype='noCAT';
Dtype='efit_p';
scale_type_origin="unscaled";
%% 数据根目录 + 两种 nation
% 目录结构: ExpRes\renamed\{observer_nation}\{model}{i/r}\obs_{i_obs}\obs{i_obs}_{i_attr}.csv
% 同一个组名 (f04i / f07i / ...) 在 AF 和 SA 下可能同时存在, 但 observer 是不同的人,
% 所以 observer_nation 必须参与寻址, 也必须参与输出路径 (否则同名组的结果会互相覆盖)
DATA_ROOT = 'D:\work\VIVOSkin_phase2\ExpRes\renamed';
% 当前只跑 AF 这一种 observer_nation; 要全跑改成 {'AF','SA','CA','AS'} (目录不存在会自动跳过)
NATIONS   = {'AF'};

% ---- 每个 nation 的属性集合规则 (键 = observer_nation, 即目录第一层 AF/SA/CA/AS) ----
%   full_models : 这些 model (只写 f/m + 编号, 不带结尾 i/r) 跑 full 属性集
%   其余 model   : 跑 base 属性集
%   AF : f09/f10/m09/m10       -> [1 5 6 7 9 10],  {f/m}{01~08}      -> [1 6]
%   SA : f07/f08/m07/m08       -> [1 5 6 7 9 10],  {f/m}{01~06,09,10} -> [1 6]
%   CA : {f/m}{01~03}          -> [1 5 6 7 9 10],  {f/m}{04~10}       -> [1 6]
%   AS : 全部                  -> [1 6]
ATTR_FULL = [1, 5, 6, 7, 9, 10];
ATTR_BASE = [1, 6];
ATTR_RULES = struct();
ATTR_RULES.AF = struct('full_models', {{'f09', 'f10', 'm09', 'm10'}}, ...
                       'full', ATTR_FULL, 'base', ATTR_BASE);
ATTR_RULES.SA = struct('full_models', {{'f07', 'f08', 'm07', 'm08'}}, ...
                       'full', ATTR_FULL, 'base', ATTR_BASE);
ATTR_RULES.CA = struct('full_models', {{'f01', 'f02', 'f03'}}, ...
                       'full', ATTR_FULL, 'base', ATTR_BASE);
ATTR_RULES.AS = struct('full_models', {{}}, ...
                       'full', ATTR_FULL, 'base', ATTR_BASE);   % 全部走 base

% ---- 已存在结果时怎么办 ----
%   'skip'      : 该 {model}{i/r} + {attribute} (+ {observer_gender}) 的结果已经齐了
%                 (ellipPara\fitRes.mat 与 list\ellip_list.xlsx 都存在且非空) 就跳过
%   'overwrite' : 不管有没有，全部重新拟合并覆盖
% 注意: 判据是"结果文件齐全"，不是"目录存在"。上次跑到一半中断的单元
%       (只有 labNscore / pre_draw，没有 fitRes) 仍会重跑，不会被误判成已完成。
REUSE_EXISTING = 'overwrite';

% ---- 两种 nation, 不要混用 ----
%   observer_nation : 目录 ExpRes\renamed\{observer_nation}\{model}{i/r}\obs_{i_obs}\...
%                     的第一层, 即外层循环变量 nation
%   model_nation    : 由 {model} 编号决定, 01~03=CA, 04~06=AS, 07~08=SA, 09~10=AF
%                     (见文件末尾 model_nation_of, 代码自动推算, 不需要手工写表)
% 注意: 属性规则 ATTR_RULES 与输出路径都用 observer_nation;
%       model_nation 只写进日志和 fit_subset.mat, 不参与任何选择逻辑

% ---- observer 性别: 10 位 observer 合起来拟合, 还是按性别分开拟合 ----
%   'all'   : 全部 observer 一起算平均分, 拟合一个椭圆 (旧行为)
%             落盘: ...\{model}{i/r}\non_model\{attribute_serial}\
%   'split' : 按 observer 性别拆成 male / female 两组, 各自算平均分、各自拟合
%             落盘: ...\{model}{i/r}\non_model\{observer_gender}\{attribute_serial}\
OBS_GENDER_MODE = 'split';
% 目前只有 AF / SA 两族裔给出了 observer 性别规则 (见 observer_gender_of):
%   AF : i_obs 1~5 -> male  , 6~10 -> female
%   SA : i_obs 1~5 -> female, 6~10 -> male
% CA / AS 未定义: 'split' 模式下这些 nation 会自动退回 'all' 并给出 warning

% ---- 要拟合哪些 {i_attr} ----
%   'auto'   : 按 observer_nation 查 ATTR_RULES (full_models 走 full 集, 其余走 base 集)
%   'manual' : 完全按 ATTR_MANUAL 来, 忽略 ATTR_RULES
ATTR_MODE   = 'manual';
ATTR_MANUAL = [1, 6];   % 01Preference, 06Healthy

% ---- 要拟合哪些 {scene} (picture 分组) ----
%   只影响"拟合"这一步; labNscore 仍按 obs 文件里的全部 scene 生成, 不受影响
%   'all'    : i 组跑 h3k~l8k 共 21 个, r 组跑 rs01~rs14 共 14 个
%   'manual' : 只拟合 SCENE_MANUAL 里列出的 scene, 按 i / r 分别指定; 某项留空 = 该 i/r 用全部
SCENE_MODE   = 'manual';
SCENE_MANUAL = struct();
SCENE_MANUAL.i = {'hd65'};   % i 组只拟合 hd65 (in-lab D65)
SCENE_MANUAL.r = {};         % 空 => r 组照旧拟合 rs01~rs14 全部

% for i_lastPart = [19]
for i_nat = 1:numel(NATIONS)
    nation = NATIONS{i_nat};   % 这里是 observer_nation (目录第一层)
    if ~isfolder(fullfile(DATA_ROOT, nation))
        fprintf('[跳过] observer_nation %s : 目录不存在 (%s)\n', nation, fullfile(DATA_ROOT, nation));
        continue
    end
for i_lastPart = 1:length(lastParts)
    lastPart = lastParts{i_lastPart};
    %--------non-model-group-------------
    source_folder = fullfile(DATA_ROOT, nation, lastPart); 
    group_type=1;
    
    %--------model-group-------------
    % source_folder =  fullfile('D:\work\VIVOSkin_phase2\ExpRes\renamed', ...
    %     lastPart,'model_group');
    % group_type=2;
    %--------model-------------
    % source_folder =  fullfile('D:\work\VIVOSkin_phase2\ExpRes\renamed', ...
    %     lastPart,'model');    
    % group_type=3;
    % %--------model-------------
    % source_folder = 'D:\work\VIVOskinExpe\analyze\expRes\female41i\all'; 
    % group_type=4;
    %--------all_ruddy_normal-------------
    % source_folder = 'D:\work\VIVOskinExpe\analyze\expRes\female78i\all_ruddy_normal'; 
    % group_type=5;
    %------------------------
    

    % ---- 两种 nation: observer_nation 由外层目录给出, model_nation 由 model 编号推 ----
    model = lastPart(1:end-1);      % f04 / m10 这种, 不带结尾 i/r
    model_nation = model_nation_of(model);

    % ---- 该组要跑哪些属性 (见配置区 ATTR_MODE / ATTR_MANUAL / ATTR_RULES) ----
    % ATTR_RULES 按 observer_nation 查表
    if strcmpi(ATTR_MODE, 'manual')
        attributes = ATTR_MANUAL;
    else
        if ~isfield(ATTR_RULES, nation)
            error('ATTR_RULES 里没有 observer_nation "%s" 的属性规则, 请先在配置区补上', nation);
        end
        attr_rule = ATTR_RULES.(nation);
        if ismember(model, attr_rule.full_models)
            attributes = attr_rule.full;
        else
            attributes = attr_rule.base;
        end
    end
    fprintf('[observer=%s / model=%s / model_nation=%s] attributes = [%s]\n', ...
        nation, lastPart, model_nation, num2str(attributes));

    % ---- 跳过完全没有数据的 lastPart ----
    % 判据：source_folder 不存在，或存在但没有任何 obs* 文件匹配 attributes 中的属性
    % （半有数据的 lastPart 如 f03i 只有 01/06，不在此跳过，由属性级 continue 处理）
    has_data = false;
    for attr_check = attributes
        if ~isempty(findSpecificFiles(source_folder, attr_check))
            has_data = true;
            break
        end
    end
    if ~has_data
        fprintf('[跳过] %s：没有数据（%s）\n', lastPart, source_folder);
        continue
    end

    % 旧逻辑（按 nation 自动推断 + 自动删属性）已停用：
    % if strcmp(nation,"AS")
    %     attributes = [1, 2, 3, 4, 5, 6, 7,8, 9,10];
    % elseif strcmp(nation,"CA")
    %     attributes = [1, 3, 5, 6, 7,8, 9,10];
    % else
    %     attributes = [1, 3, 5, 6,7, 8];
    % end
    % if ~strcmp(nation,"AS")&&strcmp(lastPart(1),'m')
    %     attributes(attributes==3)=[];
    % end
    % if strcmp(obs_type,"non_model")
    %     attributes(attributes==7)=[];
    % end


    % 定义所有需要处理的 attribute
    attribute_names_new = ["Preference", "Attractiveness", "Feminine", "Cooperative", ...
        "Youth", "Healthy", "Fidelity","Harmony", "Fair", "Ruddy"];
    
    [lastPart1]= gen_lastPart1(lastPart);
    
    average_file=fullfile("aveSkin",strrep(lastPart1,"add",""),"autoNhand_scaleoverLUT.mat");
    average=load(average_file);
    average=average.average_lab_all(:,1:3);

    % 该组的 picture 分组 (只和 i/r 有关, 与 observer 子集无关, 提到属性循环外)
    if lastPart(end) == 'i' || contains(lastPart,"add")
        iOr = 'i';
        all_scenes = ["h3k","h4k","h5k","h6k","hd65","h7k","h8k", ...
                      "m3k","m4k","m5k","m6k","md65","m7k","m8k",...
                      "l3k","l4k","l5k","l6k","ld65","l7k","l8k"];
    elseif lastPart(end) == 'r'
        iOr = 'r';
        all_scenes = ["rs01","rs02","rs03","rs04","rs05","rs06","rs07", ...
                      "rs08","rs09","rs10","rs11","rs12","rs13","rs14"];
    end

    % ---- 只拟合指定的 {scene} (见配置区 SCENE_MODE / SCENE_MANUAL) ----
    % 注意: 行序必须保持 21 / 14 全长, 未选中的 scene 在 par_all 里记 NaN 占位。
    % 因为 generate_list 的 list(:,1)=average(1:n_para,1) 与 p2_load_labfit 的
    % p2_local_fit_rows 都按"行号 = scene 序号"对齐, 压缩行数会让明度/参数错位。
    picnames_groups = all_scenes;
    scene_mask = true(1, numel(all_scenes));
    if strcmpi(SCENE_MODE, 'manual') && isfield(SCENE_MANUAL, iOr) ...
            && ~isempty(SCENE_MANUAL.(iOr))
        want = string(SCENE_MANUAL.(iOr));
        unknown = setdiff(want, all_scenes);
        if ~isempty(unknown)
            warning('stressNfit_p:unknownScene', '%s : SCENE_MANUAL.%s 里有不存在的 scene: %s', ...
                lastPart, iOr, strjoin(unknown, ', '));
        end
        scene_mask = ismember(all_scenes, want);
        if ~any(scene_mask)
            fprintf('[跳过] %s : SCENE_MANUAL.%s 与现有 scene 名单没有交集\n', lastPart, iOr);
            continue
        end
    end
    groups_again = 1:length(picnames_groups);   % 全部组都重新拟合
    fprintf('  scenes(%s) 实际拟合 = %s\n', iOr, strjoin(all_scenes(scene_mask), ', '));

    % 循环处理每个 attribute
    startTime = datetime('now'); 
    for attribute = attributes

        fprintf('Processing attribute: %d (%s)\n', attribute, attribute_names_new(attribute));
        
        % 生成 attribute_serial
        attribute_serial = strcat(sprintf("%02d", attribute), attribute_names_new(attribute));
        
        % 该属性下所有 observer 的文件列表
        dir_res_all = findSpecificFiles(source_folder, attribute);
        if isempty(dir_res_all)
            continue
        end
        
        % ---- observer 性别子集 (见配置区 OBS_GENDER_MODE) ----
        % 'all'   -> 1 个子集, 10 位 observer 合起来
        % 'split' -> male / female 两个子集, 各自算平均分、各自拟合
        subsets = build_observer_subsets(dir_res_all, nation, OBS_GENDER_MODE);
        
        % 输出路径带 observer_nation: AF 与 SA 的同名组 (f04i/f07i/f08i...) 否则会互相覆盖
        save_folder=fullfile('AnalyseResults_p',Dtype,scale_type_origin,nation);
        
        % 定义输出目录 (attribute 与 observer 子集在下面拼)
        if group_type==1        
            base_folder = fullfile(save_folder, strrep(lastPart,"add",""), 'non_model');
        elseif group_type==2
            base_folder = fullfile(save_folder, strrep(lastPart,"add",""), "model_group");
        elseif group_type==3
            base_folder = fullfile(save_folder, strrep(lastPart,"add",""), "model");
        elseif group_type==4
            base_folder = fullfile(save_folder, strrep(lastPart,"add",""), "all");
        end
        
        for i_sub = 1:numel(subsets)
            sub = subsets{i_sub};
            dir_res = sub.dir_res;
            obs_names  = {dir_res.name};
            obs_idx    = sub.obs_idx;
            obs_gender = sub.gender;
            
            % 'all'   : ...\{attribute_serial}\            (沿用旧路径, 不破坏已有结果)
            % 'split' : ...\{observer_gender}\{attribute_serial}\
            if strcmpi(sub.name, 'all')
                output_folder = fullfile(base_folder, attribute_serial);
            else
                output_folder = fullfile(base_folder, sub.name, attribute_serial);
            end
            
            if isempty(dir_res)
                fprintf('[跳过] %s/%s/%s：该子集没有 observer\n', ...
                    lastPart, attribute_serial, sub.name);
                continue
            end
            if numel(dir_res) < 3
                warning('stressNfit_p:fewObserver', ...
                    '%s/%s/%s：observer 只有 %d 个, 拟合结果可能不稳', ...
                    lastPart, attribute_serial, sub.name, numel(dir_res));
            end
            fprintf('[%s | observer=%s] %s\n', lastPart, sub.name, strjoin(obs_names, ', '));
            
            if ~exist(output_folder, 'dir')
                mkdir(output_folder);
            end
            
            % ---- 已存在结果时：跳过 还是 重算覆盖（见配置区 REUSE_EXISTING）----
            if ~strcmpi(REUSE_EXISTING, 'overwrite') && result_ready(output_folder, scene_mask)
                fprintf('[跳过] 结果已存在: %s\n', output_folder);
                continue
            end
            
            % 记录本次拟合用的 observer 子集 (事后可核对两种 nation 与 observer 性别)
            subset_name = sub.name;
            save(fullfile(output_folder, 'fit_subset.mat'), ...
                'nation', 'model', 'model_nation', 'attribute', 'attribute_serial', ...
                'subset_name', 'obs_names', 'obs_idx', 'obs_gender');
            
            % 处理数据并拟合椭圆
            fit_one_subset(dir_res, output_folder, lastPart, attribute, ...
                Dtype, scale_type_origin, average, picnames_groups, scene_mask, groups_again, group_type);
        end
    end
    currentTime = datetime('now');    
    time_diff = currentTime - startTime;
    fprintf('时间差: %s\n', time_diff);
    disp('All attributes and i_groups processed successfully.');
end
end   % for i_nat (observer_nation 循环)

%% 辅助函数

function nat = model_nation_of(model)
%MODEL_NATION_OF 由 model 名 ({f/m} + 两位编号) 推出 model_nation
%   {f/m}01~{f/m}03 -> CA (Caucasian)
%   {f/m}04~{f/m}06 -> AS (Asian)
%   {f/m}07~{f/m}08 -> SA (South Asian)
%   {f/m}09~{f/m}10 -> AF (African)
tok = regexp(model, '([fm])(\d{2})', 'tokens', 'once');
if isempty(tok)
    error(['无法从 model "%s" 解析出 f/m + 两位编号, 无法判定 model_nation; ' ...
           '期望形如 f04 / m10'], model);
end
num = str2double(tok{2});
if num <= 3
    nat = 'CA';
elseif num <= 6
    nat = 'AS';
elseif num <= 8
    nat = 'SA';
else
    nat = 'AF';
end
end

function g = observer_gender_of(observer_nation, i_obs)
%OBSERVER_GENDER_OF observer 性别规则 (按 observer_nation + observer 编号)
%   AF : i_obs 1~5 -> male  , 6~10 -> female
%   SA : i_obs 1~5 -> female, 6~10 -> male
%   其他 nation 未定义 -> 返回 '' (未知)
switch upper(observer_nation)
    case 'AF'
        if i_obs <= 5
            g = 'male';
        else
            g = 'female';
        end
    case 'SA'
        if i_obs <= 5
            g = 'female';
        else
            g = 'male';
        end
    otherwise
        g = '';
end
end

function subsets = build_observer_subsets(dir_res, observer_nation, gender_mode)
%BUILD_OBSERVER_SUBSETS 把该属性的 observer 文件拆成 1 个或多个子集
%   gender_mode='all'   : 一个子集, name='all', 含全部 observer (旧行为)
%   gender_mode='split' : 按 observer_gender_of 拆成 'male' / 'female'
% 每个子集是 struct: name / dir_res / obs_idx / gender
% observer 编号从文件名 (obs01_06.csv) 解析, 不依赖 dir 的返回顺序
persistent warned_keys    % 同一个 (nation, 性别) 只报一次 warning, 否则会刷屏
if isempty(warned_keys)
    warned_keys = {};
end
names = {dir_res.name};
obs_idx = zeros(1, numel(names));
for k = 1:numel(names)
    tok = regexp(names{k}, 'obs_?(\d+)', 'tokens', 'once');
    if isempty(tok)
        error('无法从文件名 "%s" 解析 observer 编号', names{k});
    end
    obs_idx(k) = str2double(tok{1});
end

if strcmpi(gender_mode, 'all')
    subsets = {struct('name', {'all'}, 'dir_res', {dir_res}, ...
        'obs_idx', {obs_idx}, 'gender', {repmat({''}, 1, numel(obs_idx))})};
    return
end

genders = cell(1, numel(obs_idx));
for k = 1:numel(obs_idx)
    genders{k} = observer_gender_of(observer_nation, obs_idx(k));
end

% 该 nation 没有 observer 性别规则: 退回 'all'
if any(cellfun(@isempty, genders))
    if ~ismember(observer_nation, warned_keys)
        warning('stressNfit_p:noGenderRule', ...
            ['observer_nation "%s" 没有 observer 性别规则, OBS_GENDER_MODE=''split'' ' ...
             '在此 nation 下退回 ''all'' (全部 observer 一起拟合)'], observer_nation);
        warned_keys{end+1} = observer_nation;
    end
    subsets = {struct('name', {'all'}, 'dir_res', {dir_res}, ...
        'obs_idx', {obs_idx}, 'gender', {genders})};
    return
end

subsets = {};
for i_g = 1:2
    if i_g == 1
        target = 'male';
    else
        target = 'female';
    end
    sel = strcmp(genders, target);
    if ~any(sel)
        key = sprintf('%s|%s', observer_nation, target);
        if ~ismember(key, warned_keys)
            warning('stressNfit_p:emptyGender', ...
                'observer_nation "%s" 下没有 %s observer, 该子集跳过', observer_nation, target);
            warned_keys{end+1} = key;
        end
        continue
    end
    subsets{end+1} = struct('name', {target}, 'dir_res', {dir_res(sel)}, ...
        'obs_idx', {obs_idx(sel)}, 'gender', {genders(sel)});
end
end

function fit_one_subset(dir_res, output_folder, lastPart, attribute, Dtype, scale_type_origin, ...
                        average, picnames_groups, scene_mask, groups_again, group_type)
%FIT_ONE_SUBSET 用一组 observer (全部 / 某一性别) 做 (组, 属性) 的椭圆拟合并落盘
%   dir_res     : 只含本子集的 observer 文件 => 平均分也只由本子集的 observer 决定
%   scene_mask  : 与 picnames_groups 等长, true 的 scene 才拟合; 其余记 NaN 占位
%                 保持 par_all 行序 = scene 序号 (generate_list / p2_load_labfit 依赖)
%   产物: output_folder\{labNscore, ellipPara, list, pre_draw, delete_log}
    % 处理数据并保存
    process_data_CAT_p(dir_res, output_folder, strrep(lastPart,"add",""), Dtype, scale_type_origin);

    % 拟合椭圆
    outputFolder = fullfile(output_folder, 'ellipPara');
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end

    % 初始化存储拟合结果的变量
    par_all = [];
    r_all = [];
    parNr_all = [];

    delete_log_folder = fullfile(output_folder, 'delete_log');
    if ~exist(delete_log_folder, 'dir')
        mkdir(delete_log_folder);
    end

    if exist(fullfile(delete_log_folder, 'row_delete_data.mat'),'file')
        deleteData=load(fullfile(delete_log_folder, 'row_delete_data.mat'), 'row_delete_all');
    end
    if exist(fullfile(outputFolder, "fitRes.mat"),'file')
        parData=load(fullfile(outputFolder, "fitRes.mat"), ...
            'par_all', 'r_all', 'parNr_all','picname_check');
    end
    picname_check = {};   % 预置，避免所有 i_group 都被 continue 时 save 出现未定义变量

    % 循环处理每个 i_group
    for i_group = 1:length(picnames_groups)

        fprintf('Processing i_group: %d (%s)\n', i_group, picnames_groups(i_group));
        picname_check{i_group,1}=strcat(lastPart, picnames_groups(i_group));

        % 加载数据
        dir_labNgroup = dir(fullfile(output_folder, 'labNscore', ...
            strcat('labNscore_group',strrep(lastPart,"add",""), picnames_groups(i_group),'*.mat')));

        % ---- 不在拟合范围内 (SCENE_MANUAL) 或缺少 labNscore 的 scene: 记 NaN 占位 ----
        % 必须占一行, 否则 par_all 行号与 picnames_groups / average 的 scene 序号错开
        if ~scene_mask(i_group) || isempty(dir_labNgroup)
            if ~scene_mask(i_group)
                reason = '不在 SCENE_MANUAL.';
            else
                reason = '没有 labNscore 文件';
            end
            fprintf('[NaN 占位] %s / %s：%s\n', lastPart, picnames_groups(i_group), reason);
            row_delete_all{i_group,1} = {[], []};
            par_all   = [par_all;   nan(1, 6)];
            r_all     = [r_all;     NaN];
            parNr_all = [parNr_all; [nan(1, 6), NaN]];
            continue
        end
        MSVNlab = load(fullfile(dir_labNgroup(1).folder, dir_labNgroup(1).name));
        lab_group_original = MSVNlab.lab_group; % 原始 lab_group
        p_group_original = MSVNlab.p_group; % 原始 p_group

        
        % 复制一份用于修改
        lab_group = lab_group_original;
        p_group = p_group_original;


        if ~ismember(i_group,groups_again)
            par=parData.par_all(i_group,:);
            r=parData.r_all(i_group,:);
            row_delete=deleteData.row_delete_all{i_group,1}{1,1};
            row_delete_lab_group=deleteData.row_delete_all{i_group,1}{1,2};
            p_group(row_delete,:)=[];
            lab_group(row_delete,:)=[];
        else

            % 初始化 row_delete 和对应的 lab_group 数据
            row_delete = [];
            row_delete_lab_group = [];

            % ---- 退化检查 ----
            % 该组所有 observer 的得分完全一致 (p_group 无方差) 时, 相关系数 corr 恒为 NaN,
            % 椭圆拟合没有意义, 100 次随机初值也选不出 par; 这里记一条 NaN 占位,
            % 保证 par_all 的行序仍与 picnames_groups 对齐 (generate_list 按行取 average)。
            if numel(unique(p_group_original)) < 2 || any(isnan(p_group_original))
                fprintf('[退化跳过] %s / %s：p_group 无方差 (unique=%d, 值=%s)\n', ...
                    lastPart, picnames_groups(i_group), numel(unique(p_group_original)), ...
                    mat2str(unique(p_group_original)', 3));
                par = nan(1, 6);
                r = NaN;
                row_delete_all{i_group,1} = {[], []};
                par_all   = [par_all;   par];
                r_all     = [r_all;     r];
                parNr_all = [parNr_all; [par, r]];
                continue
            end
            
            while true
                % 拟合椭圆
                [par_mean, r_mean] = calculate_weighted_or_simple_mean( p_group_original, lab_group_original);
                % 如果 group_type == 3 且 row_delete >= 5，则调用函数
                if group_type == 3||(length(row_delete) >= 5)
                % if (group_type == 3 && length(row_delete) >= 5)||(length(row_delete) >= 24)
                    par=par_mean;
                    r=r_mean;
                    if ~isempty(par) % 如果返回的 par 不为空，则退出循环
                        break;
                    end
                end
                mean_cen(1)=mean(lab_group(:,1));
                mean_cen(2:3)=par_mean(1,4:5);
                if attribute == 10 && ismember(i_group,[15])
                    [par, r, y] = my_ellipsoidfit3_special(lab_group, p_group,mean_cen,lastPart,i_group);
                else
                    [par, r, y] = my_ellipsoidfit3_dy(lab_group, p_group,mean_cen);
                end
                
                % my_ellipsoidfit3_dy 在数据退化时返回空 par (相关性全 NaN), 无法继续迭代
                if isempty(par) || any(isnan(par))
                    fprintf('[退化跳过] %s / %s：拟合返回空或 NaN, 记为 NaN\n', ...
                        lastPart, picnames_groups(i_group));
                    par = nan(1, 6);
                    r = NaN;
                    break
                end
                
                [A, B, ~] = calculate_ellipse_axes_from_par(par);
                if (4*par(1)*par(2)-par(3)^2)>0
                % if (4*par(1)*par(2)-par(3)^2)>0&&r>=0.75
                    break;
                end

                % 找到最大误差的索引
                [~, max_ind] = max(abs(y - p_group));
                
                % 记录原始 lab_group 中的索引
                original_index = find(ismember(lab_group_original, lab_group(max_ind, :), 'rows'));
                
                % 将原始索引加入 row_delete
                row_delete = [row_delete; original_index];
                
                % 将对应的 lab_group 数据加入 row_delete_lab_group
                row_delete_lab_group = [row_delete_lab_group; lab_group_original(original_index, :)];
                
                % 删除异常数据点
                lab_group(max_ind, :) = [];
                p_group(max_ind, :) = [];
                figure('Visible','off');
                plot_contour_with_scatter(par, lab_group, p_group);
            end
        end
        % 存储 row_delete 和对应的 lab_group 数据
        row_delete_all{i_group,1} = {row_delete, row_delete_lab_group};
        
        % 存储拟合结果
        par_all = [par_all; par];
        r_all = [r_all; r];
        parNr_all = [parNr_all; [par, r]];
        
        % 绘制等高线图并保存 (退化组 par 全 NaN, 画不出来, 直接不画)
        if ~any(isnan(par))
            pre_draw_folder = fullfile(output_folder, 'pre_draw');
            if ~exist(pre_draw_folder, 'dir')
                mkdir(pre_draw_folder);
            end
            figure('Visible','off');
            plot_contour_with_scatter(par, lab_group, p_group);
            title(strrep(dir_labNgroup(1).name,'labNscore_group',''));

            frame = getframe(gcf); % 获取当前 Figure 窗口的帧
            img = frame2im(frame); % 将帧转换为图像数据
            imwrite(img, fullfile(pre_draw_folder, ...
                strcat(strrep(dir_labNgroup(1).name,'labNscore_group',''), '.jpg')));
            close(gcf);
        end
    end
    % 保存 row_delete 和 row_delete_lab_group 到 delete_log 文件夹
    if exist('row_delete_all','var')
        save(fullfile(delete_log_folder, 'row_delete_data.mat'), 'row_delete_all');
    end

    % 保存拟合结果
    %   scenes_fit : par_all 的每一行对应哪个 scene (行序 = scene 序号, 未拟合的是 NaN 行)
    %   scene_mask : 哪些 scene 是真正拟合过的 (其余行为 NaN 占位)
    scenes_fit = picnames_groups;
    save(fullfile(outputFolder, "fitRes.mat"), ...
        'par_all', 'r_all', 'parNr_all','picname_check','scenes_fit','scene_mask');
    
    % 生成 list 并保存为表格文件
    % 没有拟合结果时跳过（否则 generate_list 会写出 0 行表格而报错）
    if ~isempty(par_all)
        generate_list(output_folder, par_all, r_all, average);
    else
        fprintf('[跳过] %s / attr %d：没有拟合结果，不生成 ellip_list.xlsx\n', ...
            lastPart, attribute);
    end
end

function [lastPart1]= gen_lastPart1(lastPart)
    lastParts1=["femaleVIVO","maleVIVO"];
    lastParts=["femalevivo","malevivo"];
    lastPart1=lastPart;
    for i=length(lastParts)
        lastPart1=strrep(lastPart1,lastParts(i),lastParts1(i));
    end
end

function tf = result_ready(output_folder, scene_mask)
%RESULT_READY 该 (组, 属性, observer 子集) 的拟合结果是否已经完整产出
%   判据: ellipPara\fitRes.mat 与 list\ellip_list.xlsx 都存在且非空。
%   半途中断的单元一般只写了 labNscore / pre_draw，缺这两个文件 => 判为未完成，
%   下次照常重跑（不会被 skip 误当成已完成）。
%   若给了 scene_mask, 还要求 fitRes 里记录的拟合范围与当前一致:
%   改了 SCENE_MANUAL 后, 旧的"全 scene"结果会自动判为未完成并重跑。
tf = false;
f1 = fullfile(output_folder, 'ellipPara', 'fitRes.mat');
f2 = fullfile(output_folder, 'list', 'ellip_list.xlsx');
if isfile(f1) && isfile(f2)
    tf = (dir(f1).bytes > 0) && (dir(f2).bytes > 0);
end
if tf && nargin >= 2 && ~isempty(scene_mask)
    w = whos('-file', f1);   % 用 whos 判断字段在不在, 避免 load 反复刷"未找到变量"警告
    if ~any(strcmp({w.name}, 'scene_mask'))
        tf = false;          % 旧结果没记录拟合范围 => 视为未完成
    else
        s = load(f1, 'scene_mask');
        if ~isequal(logical(s.scene_mask(:))', logical(scene_mask(:))')
            tf = false;      % 拟合范围变了 => 需要重跑
        end
    end
end
end
