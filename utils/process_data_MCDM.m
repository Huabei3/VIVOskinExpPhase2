function MCDM=process_data_MCDM(dir_res, output_folder, lastPart,Dtype)
    % 处理数据并保存
    % phase2 适配：LUT 改为绝对路径（phase1 的 ..\..\A_characterization
    % 在 D:\work\VIVOSkin_phase2 下不存在，会导致 load 失败）
    addpath("utils\")
    P2C = p2_config();
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
        repeat_score(:, 2:3) = (repeat_score(:, 2:3) - 1) / 5;
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
            score_all_temp = (score_all_temp - min(score_all_temp)) /(max(score_all_temp)-min(score_all_temp));
            score_all_scaled((i_group-1)*33+1:i_group*33,i_obs)=score_all_temp;
        end
    end
    % score_all_scaled = (score_all - 1) /5;
    score_all_mean = mean(score_all_scaled, 2);
    STRESS_inter = [];
    for i_file = 1:n_file
        STRESS_inter = [STRESS_inter; {dir_res(i_file).name, STRESS(score_all_scaled(:, i_file), score_all_mean)}];
    end

    save(fullfile(output_folder, 'STRESS.mat'), 'STRESS_inter', 'STRESS_intra');

    for i_ind=1:size(score_all,2)
        score_scaled(:,i_ind) = (score_all(:,i_ind) - min(score_all(:,i_ind))) ./ ...
            (max(score_all(:,i_ind)) - min(score_all(:,i_ind)));
    end

    % 处理并保存每个 group 的 z-score 和 lab
    %---------CAT----------------
    if contains(lastPart,'i')
        iOr='i';
    elseif contains(lastPart,'r')
        iOr='r';
    end
   
    load(fullfile('dlabsNpicname', strcat(strrep(lastPart,"add",""), ".mat")));

    average_file = fullfile("aveSkin", lastPart, "autoNhand_scaleoverLUT.mat");
    average_data=load(average_file);
    average = average_data.average_lab_all;
    if iOr=='i'
        new2old_indices=[1	2	3	4	6	7	5	15	16	17	18	20	21	19	8	9	10	11	13	14	12];
        average=average(new2old_indices,:);
    end

    picname_check = [];
    for i_group = 1:33:length(score_all)
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
        score_group = score_scaled(i_group:i_group + 32, :);

        % load("optimizedD\light_i.mat","CCT_light_old","XYZ_light_old","picnames_old");
        wd65_64 = [94.811, 100.00, 107.304];
        datai_file = P2C.LUT_P2_FILE;      % phase2 数据 => phase2 自己的显示标定
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

        for i_points=1:size(lab_group,1)
            lab_bfCAT(i_points, :) = lab_group(i_points,:);
            XYZ_bf(i_points, :) = lab2xyz2(lab_bfCAT(i_points, :), 'd65_64');           

            if ~strcmp(Dtype,'noCAT')
                XYZ_aft(i_points, :) = CAT16_D(XYZ_bf(i_points, :),  XYZw_pre(i_nog, :),wd65_64, D(i_nog,1));
                lab_group(i_points, :) = xyz2lab(XYZ_aft(i_points, :), 'd65_64');
            end
        end
        %计算平均
        for i_ind=1:size(score_group,2)
            [par_mean, r_mean] = calculate_weighted_or_simple_mean( score_group(:,i_ind), lab_group);
            ind_cen(i_ind,:)=[average_bf(1),par_mean(4:5)];
        end
        ind_cen_all{i_nog,1}=ind_cen;
        ind_cen_all{i_nog,2}=picname_group;

    end

    if iOr=='i'
        old2new_indices=[1	2	3	4	7	5	6	15	16	17	18	21	19	20	8	9	10	11	14	12	13];
        if length(old2new_indices)>size(ind_cen_all,1)
            old2new_indices=old2new_indices(1:size(ind_cen_all,1));
        end
        ind_cen_all=ind_cen_all(old2new_indices,:);    
        average_CATed=average_CATed(old2new_indices,:);
        picname_check=picname_check(old2new_indices,:);
    end

    ellip_folder=fullfile(output_folder,"ellipPara");
    ellip_data=load(fullfile(ellip_folder,"fitRes.mat"));
    par_all=ellip_data.par_all;
    for i_para=1:size(par_all,1)
        mean_cen(i_para,:)=[average_CATed(i_para,1),par_all(i_para,4:5)];
        inds_cen=ind_cen_all{i_para,1};
        for i_ind=1:size(inds_cen,1)
            de_fr_mean(i_ind,:)=deltaE2000(inds_cen(i_ind,:),mean_cen(i_para,:));
        end
        MCDM(i_para,:)=de_fr_mean';

    end
    MCDM_mean=mean(mean(MCDM,"omitnan"),"omitnan");

    %-------------------
    outputFolder = fullfile(output_folder, 'MCDM');
    if ~exist(outputFolder, 'dir')
        mkdir(outputFolder);
    end
    save(fullfile(outputFolder, strcat("MCDMdata.mat")),"MCDM","picname_check","MCDM_mean");



end








