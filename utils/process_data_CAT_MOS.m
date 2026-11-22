function process_data_CAT_MOS(dir_res, output_folder, lastPart, Dtype, scale_type)
%PROCESS_DATA_CAT_MOS  按 MOS（全体 observer 平均分）构造 p_all 的数据预处理
%
%   模块: utils / 数据预处理（stressNmean_MOS.m 专用）
%   与 process_data_CAT_p 的唯一区别：
%     p_all 的构造方式
%       process_data_CAT_p  : p_all(i) = 打高分的 observer 比例
%                             = sum(score_all(i,:) > 0.5) ./ n_obs
%                             （0/1 化的"偏好比例"，偏好分布很尖，适合拟合椭圆）
%       process_data_CAT_MOS: p_all(i) = 全体 observer 的 MOS
%                             = mean(score_all(i,:), 2)
%                             （0~1 连续值，直接当"平均喜好"用，不再拟合椭圆）
%     其余流程（STRESS、CAT16、lab_group 载入、落盘变量名）完全一致。
%
%   输入:
%     dir_res     : 该 (组, 属性, observer 子集) 的 obs*.csv 文件列表（struct array）
%     output_folder: 该单元的根输出目录，labNscore 子目录由其派生
%     lastPart    : 'f04i' / 'm10r' 这种（末尾 i=实验室, r=实景）
%     Dtype       : calculateD 的色适应类型，'efit_p' / 'noCAT' ...
%     scale_type  : 'unscaled' / 'scaled'
%
%   落盘:
%     output_folder\STRESS.mat                 STRESS_inter / STRESS_intra
%     output_folder\labNscore\labNscore_group*.mat
%          lab_group / lab_bfCAT / p_group / picname_group / picname_check /
%          average_curr / average_bf
%     output_folder\{lastPart}picname_check.mat
%
%   说明: score_all 在算 MOS 之前已归一化到 0~1（(score-1)/5），
%         所以 p_all 与旧版 p_all 同量纲，calculate_weighted_or_simple_mean
%         里 "> 0.5" 的阈值语义不变（0.5 = 中性）。

    addpath("utils\")
    resfile = fullfile(dir_res(1).folder, dir_res(1).name);
    result = readtable(resfile);
    result_cell = table2cell(result);
    indices = result_cell(:, 1);
    indices = cell2mat(indices);
    n_lab = max(indices) + 1;
    n_file = length(dir_res);

    score_all = zeros(n_lab, n_file);
    num_lab_all = zeros(n_lab, n_file);
    STRESS_intra = [];
    repeat_score_all = [];

    for i_file = 1:length(dir_res)
        resfile = fullfile(dir_res(i_file).folder, dir_res(i_file).name);
        result = readtable(resfile);
        result_cell = table2cell(result);
        rowsWithNaN = any(isnan(cell2mat(result_cell(:,1))), 2);
        result_cell(rowsWithNaN, :) = [];
        scores = cell2mat(result_cell(:, 3));
        scores = mapMatrixValues(scores);
        for k = 1:length(scores)
            result_cell{k, 3} = scores(k);
        end
        result_cell = sortrows(result_cell, 1);
        repeat_score = [];
        picname_lab = [];
        score_lab = zeros(max(cell2mat(result_cell(:, 1))) + 1, 1);
        num_lab = zeros(max(cell2mat(result_cell(:, 1))) + 1, 1);

        for i_lab = 0:max(cell2mat(result_cell(:, 1)))
            num_scores = find(cell2mat(result_cell(:, 1)) == i_lab);
            score_lab(i_lab + 1) = mean(cell2mat(result_cell(num_scores, 3)));
            if isempty(num_scores)
                disp("1");
            end
            picname_lab = [picname_lab; result_cell(num_scores(1), 2)];
            num_lab(i_lab + 1) = length(num_scores);
            if num_lab(i_lab + 1) > 1
                repeat_score_temp = [i_lab, cell2mat(result_cell(num_scores(1), 3)), cell2mat(result_cell(num_scores(2), 3))];
                repeat_score = [repeat_score; repeat_score_temp];
            end
        end

        % repeat_score(:, 2:3) = (repeat_score(:, 2:3) - 1) / 5;
        repeat_score_mean = (repeat_score(:, 2) + repeat_score(:, 3)) ./ 2;
        repeat_score_all = [repeat_score_all; {repeat_score}];
        STRESS_intra = [STRESS_intra; {dir_res(i_file).name, STRESS(repeat_score(:, 2), repeat_score_mean)}];
        % resfile
        score_all(:, i_file) = score_lab;
        num_lab_all(:, i_file) = num_lab;
    end


    STRESS_intra_mean = mean(cell2mat(STRESS_intra(:, 2)));
    n_group = size(score_all,1)./33;
    n_obs = size(score_all,2);
    for i_obs = 1:n_obs
        for i_group = 1:n_group
            score_all_temp = score_all((i_group-1)*33+1:i_group*33, i_obs);
            % picname_lab_temp=picname_lab((i_group-1)*33+1:i_group*33,1);
            % score_all_temp = (score_all_temp - min(score_all_temp)) /(max(score_all_temp)-min(score_all_temp));
            score_all_scaled((i_group-1)*33+1:i_group*33, i_obs) = score_all_temp;
        end
    end
    score_all_mean = mean(score_all_scaled, 2);
    STRESS_inter = [];
    for i_file = 1:n_file
        STRESS_inter = [STRESS_inter; {dir_res(i_file).name, STRESS(score_all_scaled(:, i_file), score_all_mean)}];
    end

    save(fullfile(output_folder, 'STRESS.mat'), 'STRESS_inter', 'STRESS_intra');

    % 计算 MOS: 先归一化到 0~1, 再直接对全体 observer 取平均
    score_all = (score_all - 1) ./ 5;
    % ---- 与 process_data_CAT_p 的分歧点: 不再统计 "> 0.5 的比例", 直接取 MOS ----
    p_all = mean(score_all, 2);

    % 处理并保存每个 group 的 z-score 和 lab

    load(fullfile('dlabsNpicname', strcat(strrep(lastPart,"add",""), ".mat")));

    average_file = fullfile("aveSkin", lastPart, "autoNhand_scaleoverLUT.mat");
    average_data = load(average_file);
    average = average_data.average_lab_all;
    %---------CAT----------------
    if contains(lastPart,'i')
        iOr = 'i';
    elseif contains(lastPart,'r')
        iOr = 'r';
    end
    if iOr == 'i'
        new2old_indices = [1 2 3 4 6 7 5 15 16 17 18 20 21 19 8 9 10 11 13 14 12];
        average = average(new2old_indices, :);
    end

    picname_check = [];
    for i_group = 1:33:length(p_all)
        i_nog = floor((i_group - 1) / 33) + 1;
        if i_nog == 11
            disp("d")
        end
        picname_group = picname_lab{i_group}(1:end - 3);
        picname_check{floor((i_group - 1) / 33) + 1, 1} = picname_lab{i_group}(1:end - 3);
        lab_group = []; matching_indices = [];
        for i_pic = 1:length(dlabsNpicname)
            picname_sing = char(gen_lastPart_new(dlabsNpicname{i_pic, 2}));
            if strcmp(picname_sing(1:end - 3), gen_lastPart_new(picname_group))
                lab_group = [lab_group; dlabsNpicname{i_pic, 1}];
            end
        end
        p_group = p_all(i_group:i_group + 32, :);


        % load("optimizedD\light_i.mat","CCT_light_old","XYZ_light_old","picnames_old");
        wd65_64 = [94.811, 100.00, 107.304];
        datai_file = p2_config().LUT_P2_FILE;   % phase2 数据 => phase2 自己的显示标定
        LUT = load(datai_file);
        XYZw_LUT = LUT.XYZw;
        load(fullfile("optimizedD\backGroundGray", ...
            strcat(lastPart,".mat")),"xyz_gray");
        % [CCT,XYZw_pre(i_nog, :)] = find_CCT_r1(picname_group);
        [CCT,XYZw_pre(i_nog, :)] = find_CCT_combi(picname_group);
        % [CCT,XYZw_pre(i_nog, :)] = find_CCTest(picname_group);
        % [CCT,XYZw_pre(i_nog, :)] = find_CCT_patch(picname_group);
        % [CCT,XYZw_pre(i_nog, :)] = find_CCTpreXYZ(picname_group);
        E = xyz_gray(i_nog,2);
        D(i_nog,1) = calculateD(CCT, 0, Dtype, E);
        % D(i_nog,1) = calculateD(CCT, duv, Dtype,E);
        average_bf = average(i_nog,:);
        XYZ_ave_bf = lab2xyz2(average_bf, 'd65_64');
        XYZ_ave_aft = CAT16_D(XYZ_ave_bf, XYZw_pre(i_nog, :), wd65_64, D(i_nog,1));
        average_curr = xyz2lab(XYZ_ave_aft, 'd65_64');
        average_CATed(i_nog,:) = average_curr;
        if iOr == 'r'
            white_file = fullfile("optimizedD\card_0830", ...
                strcat(lastPart, ".mat"));
        elseif iOr == 'i'
            white_file = fullfile("optimizedD\whiteSquare\XYZw_white", ...
            strcat(lastPart, ".mat"));
        end
        load(white_file,"XYZw_white");
        for i_points = 1:size(lab_group,1)
            lab_bfCAT(i_points, :) = lab_group(i_points,:);
            XYZ_bf(i_points, :) = lab2xyz2(lab_bfCAT(i_points, :), 'd65_64');

            if ~strcmp(Dtype,'noCAT')
                XYZ_aft(i_points, :) = CAT16_D(XYZ_bf(i_points, :), XYZw_pre(i_nog, :), wd65_64, D(i_nog,1));
                lab_group(i_points, :) = xyz2lab(XYZ_aft(i_points, :), 'd65_64');
            end
            if strcmp(scale_type,"scaled")
                xyz_fit(i_points,:) = lab2xyz2(lab_group(i_points,:), "user", ...
                    wd65_64./wd65_64(2).*XYZw_LUT(2));
                lab_group(i_points,:) = xyz2lab(xyz_fit(i_points,:), "user", ...
                    wd65_64./wd65_64(2).*XYZw_white(i_nog,2));
            end
        end

        if contains(picname_group,'d65')
            disp("d")
        end
        %-------------------
        outputFolder = fullfile(output_folder, 'labNscore');
        if ~exist(outputFolder, 'dir')
            mkdir(outputFolder);
        end
        picname_group_old = lower(picname_group);
        save(fullfile(outputFolder, strcat("labNscore_group", gen_lastPart_new(picname_group), ".mat")), ...
            'lab_group','lab_bfCAT', 'p_group', 'picname_group','picname_check', ...
            "average_curr","average_bf");

    end

    save(fullfile(outputFolder, strcat(lastPart,"picname_check.mat")), ...
    'picname_check',"D","XYZw_pre","average_CATed","average");

end
