function process_data_stress(dir_res, output_folder)
    % 处理数据并保存
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
            try
                picname_lab = [picname_lab; result_cell(num_scores(1), 2)];
            catch ME

                disp(dir_res(i_file).name);
            
                % 可选：重新抛出错误，或者在这里处理它
                % rethrow(ME); 
            end
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
        score_all(:, i_file) = score_lab;
        num_lab_all(:, i_file) = num_lab;
    end


    STRESS_intra_mean = mean(cell2mat(STRESS_intra(:, 2)));
    big_idx=find(cell2mat(STRESS_intra(:, 2))>STRESS_intra_mean*1.5);
    STRESS_intra_big=STRESS_intra(big_idx,:);
    n_group=size(score_all,1)./33;
    n_obs=size(score_all,2);
    for i_obs = 1:n_obs
        % if i_obs==3
        %     disp("d")
        % end
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
    STRESS_inter_mean = mean(cell2mat(STRESS_inter(:, 2)));

    save(fullfile(output_folder, 'STRESS.mat'), ...
        'STRESS_inter', 'STRESS_intra', ...
        'STRESS_inter_mean', 'STRESS_intra_mean', ...
        'STRESS_intra_big');
end