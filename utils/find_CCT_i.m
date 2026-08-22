function [CCT,i_light] = find_CCT_i( picname_group)
    picnames_groups = ["h3k","h4k","h5k","h6k","h7k","h8k","hd65", ...
                     "l3k","l4k","l5k","l6k","l7k","l8k","ld65", ...
                     "m3k","m4k","m5k","m6k","m7k","m8k","md65"];
    CT = [3000, 4000, 5000, 6000, 7000, 8000, 6500, ...
          3000, 4000, 5000, 6000, 7000, 8000, 6500, ...
          3000, 4000, 5000, 6000, 7000, 8000, 6500]';
    CCT = [];

    % 遍历 picname_group
    for idx = 1:length(picnames_groups)
        % 检查 input_string 是否包含当前 picname
        if contains(lower(picname_group), picnames_groups(idx))
            % 如果包含，返回对应的 CT 值
            CCT = CT(idx);
            i_light=idx;
            return; % 找到匹配项后立即返回
        end
    end

    % 如果未找到匹配项，输出警告
    warning('未找到匹配的 picname: %s', input_string);
end