function process_data_CAT_plot_sing(dir_res, output_folder, lastPart,Dtype,scale_type,nation_tag)
%PROCESS_DATA_CAT_PLOT_SING 与 process_data_CAT_p 完全相同，额外为每个 observer 单独画一张散点图
%
%   相比 process_data_CAT_p 多出的功能（其余逻辑一行未改）：
%       for i_obs = 1:size(score_all, 2)
%           plot_with_scatter(lab_group, score_all(i_group:i_group+n_pt-1, i_obs));
%       end
%   图片保存到:
%       singe_obs_plot\obs{i_obs}\{model}{i/r}\{attribute_serial}\{scene}.jpg
%
%   【维度说明 - 关键】
%     score_all = (33 x n_scene) x n_obs
%     一个 csv 有 693 行 label = 33 刺激 x 21 scene (已实测确认)
%     所以 score_all(:, i_obs) 是 693 x 1，而 lab_group 是当前 scene 的 33 x 3，
%     两者长度不等，必须切片为 score_all(i_group:i_group+n_pt-1, i_obs) 才能对上。
%
%   dir_res 的顺序 = findSpecificFiles 中 obs* 目录的升序 = score_all 的列顺序
%   (本函数内 i_obs 即此列序号，文件夹名用的是从 dir_res 路径解析出的真实 observer 编号)

    % ---- 输出根目录 ----
    PLOT_ROOT = 'D:\work\VIVOSkin_phase2\analyze\singe_obs_plot';

    % nation 标签 (第 6 个入参, 可省略): 有值时图片落到
    %   singe_obs_plot\{nation}\obs{i_obs}\{model}{i/r}\{attribute_serial}\{scene}.jpg
    % 因为同一个组名 (f04i/f07i/...) 在 AF 与 SA 下都有数据, 不加 nation 会互相覆盖
    if nargin < 6 || isempty(nation_tag)
        nation_tag = '';
    end

    % attribute_serial，如 01Preference（调用方传入的 output_folder 末级目录名）
    [~, attribute_serial] = fileparts(output_folder);

    % 处理数据并保存
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
    n_group=size(score_all,1)./33;
    n_obs=size(score_all,2);
    for i_obs = 1:n_obs
        for i_group = 1:n_group        
            score_all_temp=score_all((i_group-1)*33+1:i_group*33,i_obs);
            % picname_lab_temp=picname_lab((i_group-1)*33+1:i_group*33,1);
            % score_all_temp = (score_all_temp - min(score_all_temp)) /(max(score_all_temp)-min(score_all_temp));
            score_all_scaled((i_group-1)*33+1:i_group*33,i_obs)=score_all_temp;
        end
    end
    score_all_mean = mean(score_all_scaled, 2);
    STRESS_inter = [];
    for i_file = 1:n_file
        STRESS_inter = [STRESS_inter; {dir_res(i_file).name, STRESS(score_all_scaled(:, i_file), score_all_mean)}];
    end

    save(fullfile(output_folder, 'STRESS.mat'), 'STRESS_inter', 'STRESS_intra');

    % 计算 z_score
    score_all=(score_all-1)./5;
    for i_row=1:size(score_all,1)
        p_all(i_row,1) = sum(score_all(i_row,:)>0.5)./size(score_all,2);
    end


    % 处理并保存每个 group 的 z-score 和 lab

    load(fullfile('dlabsNpicname', strcat(strrep(lastPart,"add",""), ".mat")));

    average_file = fullfile("aveSkin", lastPart, "autoNhand_scaleoverLUT.mat");
    average_data=load(average_file);
    average = average_data.average_lab_all;
    %---------CAT----------------
    if contains(lastPart,'i')
        iOr='i';
    elseif contains(lastPart,'r')
        iOr='r';
    end
    if iOr=='i'
        new2old_indices=[1	2	3	4	6	7	5	15	16	17	18	20	21	19	8	9	10	11	13	14	12];
        average=average(new2old_indices,:);
    end

    picname_check = [];
    for i_group = 1:33:length(p_all)
        i_nog=floor((i_group - 1) / 33) + 1;
        if i_nog==11
            disp("d")
        end
        picname_group = picname_lab{i_group}(1:end - 3);
        picname_check{floor((i_group - 1) / 33) + 1, 1} = picname_lab{i_group}(1:end - 3);
        lab_group = [];matching_indices=[];
        for i_pic = 1:length(dlabsNpicname)
            picname_sing=char(gen_lastPart_new(dlabsNpicname{i_pic, 2}));
            if strcmp(picname_sing(1:end - 3),gen_lastPart_new(picname_group))
                lab_group = [lab_group; dlabsNpicname{i_pic, 1}];
            end
        end
        p_group = p_all(i_group:i_group + 32, :);


       
        % load("optimizedD\light_i.mat","CCT_light_old","XYZ_light_old","picnames_old");
        wd65_64 = [94.811, 100.00, 107.304];
        datai_file = 'D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\A_characterization\display_model\datai_ipv30_phase2_3.mat';
        LUT=load(datai_file);
        XYZw_LUT=LUT.XYZw;
        load(fullfile("optimizedD\backGroundGray", ...
            strcat(lastPart,".mat")),"xyz_gray");
        % [CCT,XYZw_pre(i_nog, :)] = find_CCT_r1(picname_group);
        [CCT,XYZw_pre(i_nog, :)] = find_CCT_combi(picname_group);
        % [CCT,XYZw_pre(i_nog, :)] = find_CCTest(picname_group);
        % [CCT,XYZw_pre(i_nog, :)] = find_CCT_patch(picname_group);
        % [CCT,XYZw_pre(i_nog, :)] = find_CCTpreXYZ(picname_group);
        E=xyz_gray(i_nog,2);
        D(i_nog,1) = calculateD(CCT, 0, Dtype,E);
        % D(i_nog,1) = calculateD(CCT, duv, Dtype,E);
        average_bf=average(i_nog,:);
        XYZ_ave_bf = lab2xyz2(average_bf, 'd65_64');
        XYZ_ave_aft = CAT16_D(XYZ_ave_bf,  XYZw_pre(i_nog, :),wd65_64, D(i_nog,1));
        average_curr = xyz2lab(XYZ_ave_aft, 'd65_64');
        average_CATed(i_nog,:)=average_curr;
        if iOr=='r'
            white_file = fullfile("optimizedD\card_0830",...
                strcat(lastPart, ".mat"));
        elseif iOr=='i'
            white_file = fullfile("optimizedD\whiteSquare\XYZw_white", ...
            strcat(lastPart, ".mat"));
        end
        load(white_file,"XYZw_white");
        for i_points=1:size(lab_group,1)
            lab_bfCAT(i_points, :) = lab_group(i_points,:);
            XYZ_bf(i_points, :) = lab2xyz2(lab_bfCAT(i_points, :), 'd65_64');           

            if ~strcmp(Dtype,'noCAT')
                XYZ_aft(i_points, :) = CAT16_D(XYZ_bf(i_points, :),  XYZw_pre(i_nog, :),wd65_64, D(i_nog,1));
                lab_group(i_points, :) = xyz2lab(XYZ_aft(i_points, :), 'd65_64');
            end
            if strcmp(scale_type,"scaled")
                xyz_fit(i_points,:)=lab2xyz2(lab_group(i_points,:),"user", ...
                    wd65_64./wd65_64(2).*XYZw_LUT(2));
                lab_group(i_points,:)=xyz2lab(xyz_fit(i_points,:),"user", ...
                    wd65_64./wd65_64(2).*XYZw_white(i_nog,2));    
            end
        end

        % ================= 新增：逐个 observer 画散点图并保存 =================
        % lab_group 此时已完成 CAT / scale 变换，与 score_all 的当前 scene 切片一一对应
        if ~isempty(lab_group)
            n_pt  = size(lab_group, 1);                 % 该 scene 的刺激数（正常 33）
            scene = char(gen_lastPart_new(picname_group));

            for i_obs = 1:size(score_all, 2)
                % 真实 observer 编号：从 dir_res(i_obs) 的上级目录名解析
                %   兼容 obs_01 / obs01 两种命名；解析失败时退化为列序号
                [~, obs_dirname] = fileparts(dir_res(i_obs).folder);
                tk = regexp(obs_dirname, 'obs_?(\d+)', 'tokens', 'once');
                if isempty(tk)
                    obs_tag = sprintf('obs%02d', i_obs);
                else
                    obs_tag = sprintf('obs%02d', str2double(tk{1}));
                end

                % 当前 scene 下该 observer 的评分（长度 = n_pt）
                score_obs = score_all(i_group:i_group + n_pt - 1, i_obs);

                if isempty(nation_tag)
                    fig_dir = fullfile(PLOT_ROOT, obs_tag, lastPart, attribute_serial);
                else
                    fig_dir = fullfile(PLOT_ROOT, nation_tag, obs_tag, lastPart, attribute_serial);
                end
                if ~exist(fig_dir, 'dir')
                    mkdir(fig_dir);
                end

                figure('Visible','off');
                plot_with_scatter(lab_group, score_obs);
                title(scene, 'Interpreter', 'none');

                frame = getframe(gcf);
                img = frame2im(frame);
                imwrite(img, fullfile(fig_dir, strcat(scene, '.jpg')));
                close(gcf);
            end
        end
        % ====================================================================

        if contains(picname_group,'d65')
            disp("d")
        end
        %-------------------
        outputFolder = fullfile(output_folder, 'labNscore');
        if ~exist(outputFolder, 'dir')
            mkdir(outputFolder);
        end
        picname_group_old=lower(picname_group);
        save(fullfile(outputFolder, strcat("labNscore_group",gen_lastPart_new(picname_group) , ".mat")), ...
            'lab_group','lab_bfCAT', 'p_group', 'picname_group','picname_check', ...
            "average_curr","average_bf");

    end

    save(fullfile(outputFolder, strcat(lastPart,"picname_check.mat")), ...
    'picname_check',"D","XYZw_pre","average_CATed","average");

end
