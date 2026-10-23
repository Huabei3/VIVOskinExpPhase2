function [par, r] = calculate_weighted_or_simple_mean( MSV_group_original, lab_group_original)

        % 找到 MSV_group_original > 0.5 的行
        high_score_rows = MSV_group_original > 0.5;
        
        if any(high_score_rows)
            % 加权平均
            weights = MSV_group_original(high_score_rows);
            weighted_mean = sum(lab_group_original(high_score_rows, 2:3).* weights , 1, 'omitnan') / sum(weights);
            par(1, 4:5) = weighted_mean;
        else
            % 找到 MSV_group_original 的最大值
            max_score = max(unique(MSV_group_original));
            max_score_rows = MSV_group_original == max_score;
            
            % 简单平均
            simple_mean = mean(lab_group_original(max_score_rows, 2:3), 1);
            par(1, 4:5) = simple_mean;
        end
        
        % 其他参数设为 0
        par(1, 1:3) = 0;
        par(1, 6) = 0;
        r = 1; % 设置 r 为 1，表示强制满足条件

end
