function stress_value = cal_STRESS_ind(file_path)
    addpath("utils\")
    % 处理单个文件的数据并返回STRESS_intra结果
    % 输入:
    %   file_path - 要处理的单个文件路径
    % 输出:
    %   STRESS_results - 包含文件名和STRESS_intra值的结构体
    
    % 读取数据文件
    result = readtable(file_path);
    result_cell = table2cell(result);
    
    % 处理缺失值
    rowsWithNaN = any(isnan(cell2mat(result_cell(:,1))), 2);
    result_cell(rowsWithNaN, :) = [];
    
    % 标准化分数
    scores = cell2mat(result_cell(:, 3));
    scores = mapMatrixValues(scores);
    for k = 1:length(scores)
        result_cell{k, 3} = scores(k);
    end
    
    % 按标签排序
    result_cell = sortrows(result_cell, 1);
    
    % 初始化变量
    repeat_score = [];
    picname_lab = [];
    num_scores_all=[];
    max_lab = max(cell2mat(result_cell(:, 1)));
    score_lab = zeros(max_lab + 1, 1);
    num_lab = zeros(max_lab + 1, 1);
    
    % 计算每个标签的统计量
    for i_lab = 0:max_lab
        num_scores = find(cell2mat(result_cell(:, 1)) == i_lab);
        score_lab(i_lab + 1) = mean(cell2mat(result_cell(num_scores, 3)));
        picname_lab = [picname_lab; result_cell(num_scores(1), 2)];
        num_lab(i_lab + 1) = length(num_scores);
        
        
        % 如果有重复评分，记录下来用于计算STRESS_intra
        if num_lab(i_lab + 1) > 1
            num_scores_all=[num_scores_all;[num_scores(1),num_scores(2)]];
            repeat_score_temp = [i_lab, cell2mat(result_cell(num_scores(1), 3)), ...
                               cell2mat(result_cell(num_scores(2), 3))];
            repeat_score = [repeat_score; repeat_score_temp];
        end
    end
    
    % 计算STRESS_intra
    if ~isempty(repeat_score)
        repeat_score(:, 2:3) = (repeat_score(:, 2:3) - 1) / 5;
        repeat_score_mean = (repeat_score(:, 2) + repeat_score(:, 3)) ./ 2;
        stress_value = STRESS(repeat_score(:, 2), repeat_score_mean);
    else
        stress_value = NaN; % 如果没有重复评分，返回NaN
    end
    

end
