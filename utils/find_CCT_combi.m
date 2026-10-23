function [CCT,XYZwpre]= find_CCT_combi(picname_group)
    picname_group=gen_lastPart_new(picname_group);
    if contains(picname_group,'i')
        picnames_groups = ["h3k","h4k","h5k","h6k","hd65","h7k","h8k",...
                        "m3k","m4k","m5k","m6k","md65","m7k","m8k",...
                         "l3k","l4k","l5k","l6k","ld65","l7k","l8k"];
        load('optimizedD\neutral_gray\combi_XYZw_i.mat', 'XYZ_combi',"CCT_combi");
        CCT = [];
    
        % 遍历 picname_group
        for idx = 1:length(picnames_groups)
            % 检查 input_string 是否包含当前 picname
            if contains(lower(picname_group), picnames_groups(idx))
                % 如果包含，返回对应的 CT 值
                CCT = CCT_combi(idx);
                XYZwpre=XYZ_combi(idx,:);
                return; % 找到匹配项后立即返回
            end
        end
    elseif contains(picname_group,'r')
        picnames_groups = ["rs01","rs02","rs03","rs04","rs05","rs06","rs07", ...
                         "rs08","rs09","rs10","rs11","rs12","rs13","rs14"];
        picname_group=char(picname_group);
        slash=find(picname_group=='r');
        model=picname_group(1:slash(1)-1);
        
        load(fullfile('D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli\light_r\model_light_mean', ...
            strcat(model,".mat")), "model_tcp_mean","XYZwpre_mea");
        for idx = 1:length(picnames_groups)
            % 检查 input_string 是否包含当前 picname
            if contains(picname_group, picnames_groups(idx))
                % 如果包含，返回对应的 CT 值
                CCT = model_tcp_mean(idx,1);
                XYZwpre=XYZwpre_mea(idx,:);
                % XYZwpre=CCT2xyz(CCT);
                return; % 找到匹配项后立即返回
            end
        end
    end

end