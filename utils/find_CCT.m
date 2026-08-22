function CCT = find_CCT(picname_group)
    if contains(picname_group,'i')
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
                return; % 找到匹配项后立即返回
            end
        end
    elseif contains(picname_group,'r')
        picnames_groups = ["rs01","rs02","rs03","rs04","rs05","rs06","rs07", ...
                         "rs08","rs09","rs10","rs11","rs12","rs13","rs14"];
        picname_group=char(picname_group);
        slash=find(picname_group=='r');
        model=picname_group(1:slash(1)-1);
        model=gen_lastPart_new(model);
        load(fullfile("light_r\model_tcp",strcat(model,".mat")), ...
            "model_tcp_mean");
        for idx = 1:length(picnames_groups)
            % 检查 input_string 是否包含当前 picname
            if contains(picname_group, picnames_groups(idx))
                % 如果包含，返回对应的 CT 值
                CCT = model_tcp_mean(idx,1);
                return; % 找到匹配项后立即返回
            end
        end
    end

end