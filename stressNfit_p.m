% rehash toolboxcache % 解决无法访问以前可以访问的文件，重新处理工具箱缓存
close all; % 关闭所有图窗
clc;       % 清空命令窗口
clear;     % 清除工作区所有变量
addpath("utils\")
%% 生成目录
% 
% phase2 新数据（ExpRes\renamed 下实际存在的 4 组）
% lastParts = {'f09i', 'f09r', 'f10i', 'f10r'};

% 旧数据（20 组）
lastParts = {'f04i', 'f05i', 'f06i', 'm04i', 'm05i', 'm06i',...
'f01i', 'f02i', 'f03i', 'm01i', 'm02i', 'm03i',...
'f07i', 'f08i','m07i', 'm08i',...
'f09i', 'f10i','m09i', 'm10i',...
'f04r', 'f05r', 'f06r', 'm04r', 'm05r', 'm06r',...
'f01r', 'f02r', 'f03r', 'm01r', 'm02r', 'm03r',...
'f07r', 'f08r','m07r', 'm08r',...
'f09r', 'f10r','m09r', 'm10r'};

% lastParts = {'f04r', 'f05r', 'f06r', 'm04r', 'm05r', 'm06r',...
% 'f01r', 'f02r', 'f03r', 'm01r', 'm02r', 'm03r',...
% 'f07r', 'f08r','m07r', 'm08r',...
% 'f09r', 'f10r','m09r', 'm10r'};

% Dtype='noCAT';
Dtype='efit_p';
scale_type_origin="unscaled";
% for i_lastPart = [19]
for i_lastPart = 1:length(lastParts)
% for i_lastPart = 1:length(lastParts)
    lastPart = lastParts{i_lastPart};
    %--------non-model-group-------------
    source_folder = fullfile('D:\work\VIVOSkin_phase2\ExpRes\renamed', ...
        lastPart); 
    group_type=1;
    
    %--------model-group-------------
    % source_folder =  fullfile('D:\work\VIVOSkin_phase2\ExpRes\renamed', ...
    %     lastPart,'model_group');
    % group_type=2;
    %--------model-------------
    % source_folder =  fullfile('D:\work\VIVOSkin_phase2\ExpRes\renamed', ...
    %     lastPart,'model');    
    % group_type=3;
    % %--------model-------------
    % source_folder = 'D:\work\VIVOskinExpe\analyze\expRes\female41i\all'; 
    % group_type=4;
    %--------all_ruddy_normal-------------
    % source_folder = 'D:\work\VIVOskinExpe\analyze\expRes\female78i\all_ruddy_normal'; 
    % group_type=5;
    %------------------------
    
    

    
    source_folder1 = char(strrep(source_folder,"renamed\",""));
    slashes = strfind(source_folder1, '\');
    obs_type="non_model";
    % obs_type=source_folder1(slashes(end) + 1:end);
    model=lastPart(1:end-1);
    nations=["AS","CA","SA","AF"];
    if ismember(model,["f04", "f05", "f06","m04", "m05", "m06"])
        nation=nations(1);
    elseif ismember(model,["f01", "f02", "f03","m01", "m02", "m03"])
        nation=nations(2);
    elseif ismember(model,["f07", "f08","m07", "m08"])
        nation=nations(3);
    elseif ismember(model,["f09", "f10", "m09", "m10"])
        nation=nations(4);
    end

    % ---- phase2 新数据：f09/f10 组实际评测属性 = {01,05,06,07,09,10} ----
    attributes = [1, 5, 6, 7, 9, 10];

    % ---- 跳过完全没有数据的 lastPart ----
    % 判据：source_folder 不存在，或存在但没有任何 obs* 文件匹配 attributes 中的属性
    % （半有数据的 lastPart 如 f03i 只有 01/06，不在此跳过，由属性级 continue 处理）
    has_data = false;
    for attr_check = attributes
        if ~isempty(findSpecificFiles(source_folder, attr_check))
            has_data = true;
            break
        end
    end
    if ~has_data
        fprintf('[跳过] %s：没有数据（%s）\n', lastPart, source_folder);
        continue
    end

    % 旧逻辑（按 nation 自动推断 + 自动删属性）已停用：
    % if strcmp(nation,"AS")
    %     attributes = [1, 2, 3, 4, 5, 6, 7,8, 9,10];
    % elseif strcmp(nation,"CA")
    %     attributes = [1, 3, 5, 6, 7,8, 9,10];
    % else
    %     attributes = [1, 3, 5, 6,7, 8];
    % end
    % if ~strcmp(nation,"AS")&&strcmp(lastPart(1),'m')
    %     attributes(attributes==3)=[];
    % end
    % if strcmp(obs_type,"non_model")
    %     attributes(attributes==7)=[];
    % end


    % 定义所有需要处理的 attribute
    attribute_names_new = ["Preference", "Attractiveness", "Feminine", "Cooperative", ...
        "Youth", "Healthy", "Fidelity","Harmony", "Fair", "Ruddy"];
    
    [lastPart1]= gen_lastPart1(lastPart);
    
    average_file=fullfile("aveSkin",strrep(lastPart1,"add",""),"autoNhand_scaleoverLUT.mat");
    average=load(average_file);
    average=average.average_lab_all(:,1:3);
    
    % 循环处理每个 attribute
    startTime = datetime('now'); 
    for attribute = attributes


        fprintf('Processing savesavttribute: %d\n', attribute);
        
        % 生成 attribute_serial
        attribute_serial = strcat(sprintf("%02d", attribute), attribute_names_new(attribute));
        
       
        % 获取所有格式为 obs%02d 的子文件夹
    
        dir_res = findSpecificFiles(source_folder, attribute);

        if isempty(dir_res)
            continue
        end
        
    
        save_folder=fullfile('AnalyseResults_p',Dtype,scale_type_origin);
    
        % 定义输出目录
        
        if group_type==1        
            output_folder = fullfile(save_folder, strrep(lastPart,"add",""), ...
            'non_model', attribute_serial);        
        elseif group_type==2
            output_folder = fullfile(save_folder, strrep(lastPart,"add",""), ...
            "model_group" ,attribute_serial);
        elseif group_type==3
            output_folder = fullfile(save_folder, strrep(lastPart,"add",""), ...
            "model" ,attribute_serial);
        elseif group_type==4
            output_folder = fullfile(save_folder, strrep(lastPart,"add",""), ...
            "all" ,attribute_serial);
        end
    
    
        if ~exist(output_folder, 'dir')
            mkdir(output_folder);
        end
    
        % 处理数据并保存
        process_data_CAT_p(dir_res, output_folder, strrep(lastPart,"add",""),Dtype,scale_type_origin);
        
    
        
        % 拟合椭圆
        outputFolder = fullfile(output_folder, 'ellipPara');
        if ~exist(outputFolder, 'dir')
            mkdir(outputFolder);
        end
        
        % 初始化存储拟合结果的变量
        par_all = [];
        r_all = [];
        parNr_all = [];
        
        % 循环处理每个 i_group        
        delete_log_folder = fullfile(output_folder, 'delete_log');
        if ~exist(delete_log_folder, 'dir')
            mkdir(delete_log_folder);
        end
    
        if exist(fullfile(delete_log_folder, 'row_delete_data.mat'),'file')
            deleteData=load(fullfile(delete_log_folder, 'row_delete_data.mat'), 'row_delete_all');
        end
        if exist(fullfile(outputFolder, "fitRes.mat"),'file')
            parData=load(fullfile(outputFolder, "fitRes.mat"), ...
                'par_all', 'r_all', 'parNr_all','picname_check');
        end
        % groups_again=[5];
        groups_again=[1:21];
        mix_idx=[];
        ori_idx=[];
        picname_check = {};   % 预置，避免所有 i_group 都被 continue 时 save 出现未定义变量
        if lastPart(end) == 'i' ||contains(lastPart,"add")
            picnames_groups = ["h3k","h4k","h5k","h6k","hd65","h7k","h8k", ...
                            "m3k","m4k","m5k","m6k","md65","m7k","m8k",...
                             "l3k","l4k","l5k","l6k","ld65","l7k","l8k"];
        elseif lastPart(end) == 'r'
            picnames_groups = ["rs01","rs02","rs03","rs04","rs05","rs06","rs07", ...
                         "rs08","rs09","rs10","rs11","rs12","rs13","rs14"];
        end
        for i_group = 1:length(picnames_groups)

            fprintf('Processing i_group: %d\n', i_group);
    
            % 加载数据
            dir_labNgroup = dir(fullfile(output_folder, 'labNscore', ...
                strcat('labNscore_group',strrep(lastPart,"add",""), picnames_groups(i_group),'*.mat')));
            if isempty(dir_labNgroup)
                continue
            end
            MSVNlab = load(fullfile(dir_labNgroup(1).folder, dir_labNgroup(1).name));
            picname_check{i_group,1}=strcat(lastPart, picnames_groups(i_group));
            lab_group_original = MSVNlab.lab_group; % 原始 lab_group
            p_group_original = MSVNlab.p_group; % 原始 p_group
    
            
            % 复制一份用于修改
            lab_group = lab_group_original;
            p_group = p_group_original;
    
    
            if ~ismember(i_group,groups_again)
                par=parData.par_all(i_group,:);
                r=parData.r_all(i_group,:);
                row_delete=deleteData.row_delete_all{i_group,1}{1,1};
                row_delete_lab_group=deleteData.row_delete_all{i_group,1}{1,2};
                p_group(row_delete,:)=[];
                lab_group(row_delete,:)=[];
            else
    
                % 初始化 row_delete 和对应的 lab_group 数据
                row_delete = [];
                row_delete_lab_group = [];
                
                while true
                    % 拟合椭圆
                    [par_mean, r_mean] = calculate_weighted_or_simple_mean( p_group_original, lab_group_original);
                    % 如果 group_type == 3 且 row_delete >= 5，则调用函数
                    if group_type == 3||(length(row_delete) >= 5)
                    % if (group_type == 3 && length(row_delete) >= 5)||(length(row_delete) >= 24)
                        par=par_mean;
                        r=r_mean;
                        if ~isempty(par) % 如果返回的 par 不为空，则退出循环
                            break;
                        end
                    end
                    mean_cen(1)=mean(lab_group(:,1));
                    mean_cen(2:3)=par_mean(1,4:5);
                    if attribute == 10 && ismember(i_group,[15])
                        [par, r, y] = my_ellipsoidfit3_special(lab_group, p_group,mean_cen,lastPart,i_group);
                    else
                        [par, r, y] = my_ellipsoidfit3_dy(lab_group, p_group,mean_cen);
                    end
                    
                    [A, B, ~] = calculate_ellipse_axes_from_par(par);
                    if (4*par(1)*par(2)-par(3)^2)>0
                    % if (4*par(1)*par(2)-par(3)^2)>0&&r>=0.75
                        break;
                    end
    
                    % 找到最大误差的索引
                    [~, max_ind] = max(abs(y - p_group));
                    
                    % 记录原始 lab_group 中的索引
                    original_index = find(ismember(lab_group_original, lab_group(max_ind, :), 'rows'));
                    
                    % 将原始索引加入 row_delete
                    row_delete = [row_delete; original_index];
                    
                    % 将对应的 lab_group 数据加入 row_delete_lab_group
                    row_delete_lab_group = [row_delete_lab_group; lab_group_original(original_index, :)];
                    
                    % 删除异常数据点
                    lab_group(max_ind, :) = [];
                    p_group(max_ind, :) = [];
                    figure('Visible','off');
                    plot_contour_with_scatter(par, lab_group, p_group);
                end
            end
            % 存储 row_delete 和对应的 lab_group 数据
            row_delete_all{i_group,1} = {row_delete, row_delete_lab_group};
            
            % 存储拟合结果
            par_all = [par_all; par];
            r_all = [r_all; r];
            parNr_all = [parNr_all; [par, r]];
            
            % 绘制等高线图并保存
            pre_draw_folder = fullfile(output_folder, 'pre_draw');
            if ~exist(pre_draw_folder, 'dir')
                mkdir(pre_draw_folder);
            end
            figure('Visible','off');
            plot_contour_with_scatter(par, lab_group, p_group);
            title(strrep(dir_labNgroup(1).name,'labNscore_group',''));
    
            frame = getframe(gcf); % 获取当前 Figure 窗口的帧
            img = frame2im(frame); % 将帧转换为图像数据
            imwrite(img, fullfile(pre_draw_folder, ...
                strcat(strrep(dir_labNgroup(1).name,'labNscore_group',''), '.jpg')));
            close(gcf);
        end
        % 保存 row_delete 和 row_delete_lab_group 到 delete_log 文件夹
        if exist('row_delete_all','var')
            save(fullfile(delete_log_folder, 'row_delete_data.mat'), 'row_delete_all');
        end
    
        % 保存拟合结果
        save(fullfile(outputFolder, "fitRes.mat"), ...
            'par_all', 'r_all', 'parNr_all','picname_check');
        
        % 生成 list 并保存为表格文件
        % 没有拟合结果时跳过（否则 generate_list 会写出 0 行表格而报错）
        if ~isempty(par_all)
            generate_list(output_folder, par_all, r_all, average);
        else
            fprintf('[跳过] %s / %s：没有拟合结果，不生成 ellip_list.xlsx\n', ...
                lastPart, attribute_serial);
        end
    
    end
    currentTime = datetime('now');    
    time_diff = currentTime - startTime;
    fprintf('时间差: %s\n', time_diff);
    disp('All attributes and i_groups processed successfully.');
end

%% 辅助函数

function [lastPart1]= gen_lastPart1(lastPart)
    lastParts1=["femaleVIVO","maleVIVO"];
    lastParts=["femalevivo","malevivo"];
    lastPart1=lastPart;
    for i=length(lastParts)
        lastPart1=strrep(lastPart1,lastParts(i),lastParts1(i));
    end
end




