function C = p2_config()
%P2_CONFIG  phase2 分析脚本的公共配置（路径、属性、族裔映射、场景列表）
%
%   模块: utils / 公共配置
%   用法: C = p2_config();
%
%   说明:
%     phase1 的分析代码把"族裔"当成数据路径的一部分
%     (expRes\renamed\{f01i..m10r}\non_model)，族裔 = 刺激模特的族裔；
%     phase2 把族裔提到了观察者一层
%     (ExpRes\renamed\{AF|SA}\{f01i..m10r}\obs_XX\obsXX_AA.csv)，
%     族裔 = 观察者的族裔。两者语义不同，因此本文件把两个维度分开命名：
%
%       obs_nations  : 观察者族裔，决定数据路径 AnalyseResults_p\...\{AF}\...
%       stim_nations : 刺激模特族裔，决定图上分面 (AS/CA/SA/AF)
%
%   所有依赖 phase1 资源的绝对路径集中在这里，换机器只改本文件。

    %% ---------- 1. 根目录 ----------
    C.P2_ROOT   = 'D:\work\VIVOSkin_phase2\analyze';         % 本工作目录
    C.EXPRES    = 'D:\work\VIVOSkin_phase2\ExpRes';          % 原始问卷 CSV + renamed
    C.RENAMED   = fullfile(C.EXPRES, 'renamed');             % {AF|SA}\{subject}\obs_XX\obsXX_AA.csv

    % phase1 工程根（复用其中的 LUT / 光源参考数据，这些 phase2 没有副本）
    C.P1_ROOT   = 'D:\work\VIVOskinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project';

    %% ---------- 2. 结果目录 ----------
    C.Dtype             = 'efit_p';      % efit_p | efit_p_free | noCAT
    C.scale_type_origin = 'unscaled';    % 拟合时所在的标度（固定）
    C.ANALYSE_ROOT      = fullfile(C.P2_ROOT, 'AnalyseResults_p');
    C.PIC_ROOT          = fullfile(C.P2_ROOT, 'ellip_pic_p');   % 出图根目录

    %% ---------- 3. 标定 LUT ----------
    % datai_ipv18_3        : phase1 的标定（10deg / 1964 观察者），只给 phase1 数据用
    % datai_ipv30_phase2_3 : phase2 自己的显示标定，phase2 的数据处理一律用它
    % datai_ipv35_3        : 2deg / 1964 观察者，仅留作参考（已不在任何计算路径上）
    C.LUT18_FILE  = fullfile(C.P1_ROOT, 'A_characterization', 'display_model', 'datai_ipv18_3.mat');
    C.LUT_P2_FILE = fullfile(C.P1_ROOT, 'A_characterization', 'display_model', 'datai_ipv30_phase2_3.mat');
    C.LUT35_FILE  = fullfile(C.P1_ROOT, 'A_characterization', 'display_model', 'datai_ipv35_3.mat');

    %% ---------- 4. 光源参考数据（phase1 资源，r 组用） ----------
    C.LIGHT_R_DIR      = fullfile(C.P1_ROOT, 'I_render_stimuli', 'light_r');
    C.LIGHT_R_MEAN_DIR = fullfile(C.LIGHT_R_DIR, 'model_light_mean');   % {f/m}01..10.mat
    C.LIGHT_R_TCP_DIR  = fullfile(C.LIGHT_R_DIR, 'model_tcp');          % {f/m}01..10.mat

    %% ---------- 5. 属性定义 ----------
    % 索引 = 属性编号，固定 10 个槽位；phase2 实际只产出其中一部分
    C.ATTRIBUTE_NAMES = ["Preference", "Attractiveness", "Feminine", "Cooperative", ...
        "Youth", "Healthy", "Fidelity", "Harmony", "Fair", "Ruddy"];

    % phase2 的拟合属性规则（与 stressNfit_p.m 的 ATTR_RULES 保持一致）
    %   全属性组 = 该族裔"本族"的 4 个模特
    %   基础属性组 = 01 Preference + 06 Healthy
    C.ATTR_FULL = [1, 5, 6, 7, 9, 10];
    C.ATTR_BASE = [1, 6];

    %% ---------- 6. 刺激模特族裔映射 ----------
    % 由 model 编号推族裔，与 phase1 的 nation_indices 完全一致
    C.STIM_NATIONS      = ["AS", "CA", "SA", "AF"];
    C.STIM_NATION_NAMES = ["Asian", "Caucasian", "South Asian", "African"];

    % 各族裔的 model 编号（不含结尾 i/r）
    C.STIM_MODELS = {["f04", "f05", "f06", "m04", "m05", "m06"], ...   % AS
                     ["f01", "f02", "f03", "m01", "m02", "m03"], ...   % CA
                     ["f07", "f08", "m07", "m08"], ...                 % SA
                     ["f09", "f10", "m09", "m10"]};                    % AF

    %% ---------- 7. 观察者族裔（自动探测） ----------
    % 只保留 AnalyseResults_p\efit_p\unscaled 下真实存在、且 not 属于 40 组
    % subject 命名规则的目录（即 AF / SA / CA / AS 这些族裔层）
    C.OBS_NATIONS = p2_local_detect_obs_nations(C.ANALYSE_ROOT, C.Dtype, C.scale_type_origin);

    %% ---------- 8. 场景列表 ----------
    % i 组：21 个光源（3 个亮度级 h/m/l × 7 个色温 3k/4k/5k/6k/d65/7k/8k）
    C.PICNAMES_I = ["h3k","h4k","h5k","h6k","hd65","h7k","h8k", ...
                    "m3k","m4k","m5k","m6k","md65","m7k","m8k", ...
                    "l3k","l4k","l5k","l6k","ld65","l7k","l8k"];
    % r 组：14 个实景
    C.PICNAMES_R = ["rs01","rs02","rs03","rs04","rs05","rs06","rs07", ...
                    "rs08","rs09","rs10","rs11","rs12","rs13","rs14"];
    % 实景中文名（phase1 C_T_02 用）
    C.SCENE_NAMES_R = ["1负一楼商场","2负一楼vivo","3下沉广场","4学校饭堂","5学校小卖部", ...
                       "6学校星巴克","7草地顺光","8草地侧光","9草地逆光","10阴天场景", ...
                       "11夕阳草地逆光","12夕阳草地侧光","13夜景小卖部门口","14极夜小卖部对面"];

    %% ---------- 9. 参考肤色（PMCC / PengCIC / CaoCIC / Zeng） ----------
    % 5 列: L*, a*, b*, C*, h*；第 5 行 = 四族平均
    C.LABCH_PMCC = [62.11 18.96 19.76 27.39 46.18; ...
                    64.15 19.56 19.63 27.71 45.10; ...
                    56.01 18.25 18.72 26.14 45.72; ...
                    41.06 17.37 17.94 24.97 45.93];
    C.LABCH_PMCC(end+1, :) = mean(C.LABCH_PMCC, 1);

    C.WD65 = [94.811, 100.000, 107.304];   % D65 / 1964 白点

    %% ---------- 10. 常用派生字段 ----------
    C.nAttr = numel(C.ATTRIBUTE_NAMES);
end

% ------------------------------------------------------------------------
function nations = p2_local_detect_obs_nations(analyse_root, Dtype, scale_origin)
%P2_LOCAL_DETECT_OBS_NATIONS  探测 AnalyseResults 下的观察者族裔目录
%   40 个刺激组（f01i..m10r）与族裔目录（AF/SA/CA/AS）混在同一层，
%   这里用命名规则把它们区分开：族裔 = 长度 2 的纯字母目录。
    base = fullfile(analyse_root, Dtype, scale_origin);
    nations = {};
    if ~isfolder(base)
        warning('p2_config: 结果根目录不存在 -> %s', base);
        return
    end
    d = dir(base);
    d = d([d.isdir]);
    for i = 1:numel(d)
        nm = d(i).name;
        if numel(nm) == 2 && all(isletter(nm))
            nations{end+1} = upper(nm); %#ok<AGROW>
        end
    end
    % 固定顺序：AF -> SA -> CA -> AS，保证多次运行图序一致
    order = ["AF", "SA", "CA", "AS"];
    nationsStr = string(nations);
    nationsStr = [order(ismember(order, nationsStr)), nationsStr(~ismember(nationsStr, order))];
    nations = cellstr(nationsStr);
end
