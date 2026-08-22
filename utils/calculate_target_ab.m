% 定义函数 y
function [target_a1,target_b1,target_a2,target_b2] = calculate_target_ab( par,target_score,constrain,score_type)


    % 生成一系列 data2 的值
    if strcmp(constrain,"hue")
        data2_values = par(4) + (-50:0.01:50);  % 假设 data2 在 [0, 10] 范围内
        data3_values = (par(5) / par(4)) * data2_values;  % 根据条件 data3 / data32 = par(5) / par(4)
    elseif strcmp(constrain,"chroma")
        theta = linspace(0, 2*pi, 10000);
        % data3_values=-(par(4)/par(5)).*(data2_values-par(4))+par(5);
        % data3_values=sqrt((par(4).^2+par(5).^2)-data2_values.^2);
        R=sqrt((par(4).^2+par(5).^2));
        data2_values=R*cos(theta);
        data3_values=R*sin(theta);
   elseif strcmp(constrain,"45") 
       data2_values=par(4) + (-50:0.01:50);
       data3_values=data2_values;
    end

    % 过滤掉 data2_values 或 data3_values 为复数的值
    valid_mask = (imag(data2_values) == 0) & (imag(data3_values) == 0);  % 仅保留实数值
    data2_values = data2_values(valid_mask);
    data3_values = data3_values(valid_mask);

    % 计算每个点的 y 值
    
    if strcmp(score_type,"abs")
        target_y=target_score;
    elseif strcmp(score_type,"rela")
        y_center=calculate_y(par(4), par(5), par);
        target_y=target_score*y_center;
    end
    
    y_values = arrayfun(@(data2, data3) calculate_y(data2, data3, par), data2_values, data3_values);
    

    differences = y_values - target_y;
    sign_changes = [0; diff(sign(differences))'];  % 计算符号变化
    change_indices = find(sign_changes ~= 0);  % 找到符号变化的索引
    for i_change=1:size(change_indices,1)
        if abs(y_values(change_indices(i_change)-1)-target_y)<abs(y_values(change_indices(i_change))-target_y)
            change_indices(i_change)=change_indices(i_change)-1;
        end
    end
    % 提取两个根
    if length(change_indices) >= 2
        % 第一个根
        idx1 = change_indices(1);
        target_a1 = data2_values(idx1);
        target_b1 = data3_values(idx1);

        % 第二个根
        idx2 = change_indices(2);
        target_a2 = data2_values(idx2);
        target_b2 = data3_values(idx2);
    else
        target_a1=NaN;target_b1=NaN;target_a2=NaN;target_b2=NaN;
    end


end





