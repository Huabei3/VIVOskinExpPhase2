function CAL_STRESS_expRes(source_folder)
    % 创建结果存储结构
    dict1 = containers.Map(...
    {'f06i', 'f06r', 'm06i', 'm06r', 'f04i', 'f04r', 'f05i', 'f05r',...
     'm04i', 'm04r', 'm05i', 'm05r', 'f01i', 'f01r', 'f02i', 'f02r',...
     'f03i', 'f03r', 'm01i', 'm01r', 'm02i', 'm02r', 'm03i', 'm03r',...
     'f07i', 'f07r', 'f08i', 'f08r', 'm07i', 'm07r', 'm08i', 'm08r',...
     'f09i', 'f09r', 'f10i', 'f10r', 'm09i', 'm09r', 'm10i', 'm10r'},...
    {'sec1i', 'sec1r', 'sec2i', 'sec2r', 'sec3i', 'sec3r', 'sec4i', 'sec4r',...
     'sec5i', 'sec5r', 'sec6i', 'sec6r', 'sec7i', 'sec7r', 'sec8i', 'sec8r',...
     'sec9i', 'sec9r', 'sec10i', 'sec10r', 'sec11i', 'sec11r', 'sec12i', 'sec12r',...
     'sec13i', 'sec13r', 'sec14i', 'sec14r', 'sec15i', 'sec15r', 'sec16i', 'sec16r',...
     'sec17i', 'sec17r', 'sec18i', 'sec18r', 'sec19i', 'sec19r', 'sec20i', 'sec20r'}...
    );
    % dict1 = containers.Map({ 'm10i', 'm10r'},...
    % {'sec20i', 'sec20r'});

    results = struct();
    dict_keys = keys(dict1);
    
    % 创建日志文件
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    log_file = fullfile(source_folder, ['folder_move_log_' timestamp '.txt']);
    fileID = fopen(log_file, 'w');
    fprintf(fileID, '开始处理 - %s\n', datestr(now));
    fclose(fileID);
    
    % 遍历字典中的键（一级子文件夹）
    for k = 1:length(dict_keys)
        original_name = dict_keys{k};
        mapped_name = dict1(original_name);
        
        % 构建一级文件夹路径
        level1_path = fullfile(source_folder, original_name);
        
        % 检查二级子文件夹是否存在
        subfolders = {'non_model', 'model_group'};
        for sf = 1:length(subfolders)
            level2_path = fullfile(level1_path, subfolders{sf});
            
            if ~isfolder(level2_path)
                fprintf('跳过不存在的二级文件夹: %s\n', level2_path);
                continue;
            end
            
            % 创建discarded文件夹
            discarded_path = fullfile(level2_path, 'discarded');
            if ~isfolder(discarded_path)
                mkdir(discarded_path);
            end
            
            % 获取三级子文件夹列表
            level3_dirs = dir(level2_path);
            level3_dirs = level3_dirs([level3_dirs.isdir]);
            level3_dirs = level3_dirs(~ismember({level3_dirs.name}, {'.', '..', 'discarded'}));
            
            % 处理每个三级子文件夹
            stress_data = struct('name', {}, 'path', {}, 'stress', {});
            for d = 1:length(level3_dirs)
                level3_name = level3_dirs(d).name;
                level3_path = fullfile(level2_path, level3_name);
                
                % 查找CSV文件
                csv_files = dir(fullfile(level3_path, '*.csv'));
                
                if isempty(csv_files)
                    fprintf('跳过空的三级文件夹: %s\n', level3_path);
                    continue;
                end
                
                % 计算所有CSV文件的stress_value平均值
                stress_values = [];
                for f = 1:length(csv_files)
                    file_path = fullfile(level3_path, csv_files(f).name);
                    try
                        stress_val = cal_STRESS_ind(file_path);
                        stress_values = [stress_values; stress_val];
                    catch ME
                        fprintf('处理文件 %s 时出错: %s\n', file_path, ME.message);
                    end
                end
                
                % 存储结果
                if ~isempty(stress_values)
                    stress_mean = mean(stress_values);
                    
                    stress_data(d).name = level3_name;
                    stress_data(d).path = level3_path;
                    stress_data(d).stress = stress_mean;
                    
                    if ~isfield(results, mapped_name)
                        results.(mapped_name) = {};
                    end
                    
                    results.(mapped_name){end+1, 1} = level3_name;
                    results.(mapped_name){end, 2} = stress_mean;
                    results.(mapped_name){end, 3} = subfolders{sf};
                end
            end
            
            % 筛选和移动文件夹
            if ~isempty(stress_data)
                % 排序
                [sorted_stress, idx] = sort([stress_data.stress], 'descend');
                sorted_data = stress_data(idx);
                
                % 筛选需要移动的文件夹
                move_count = 0;
                remaining_count = length(sorted_data);
                
                % 打开日志文件追加记录
                fileID = fopen(log_file, 'a');
                
                for i = 1:length(sorted_data)
                    if sorted_data(i).stress >= 0.25 && remaining_count > 13
                        % 移动文件夹
                        src = sorted_data(i).path;
                        dst = fullfile(discarded_path, sorted_data(i).name);
                        
                        try
                            movefile(src, dst);
                            move_count = move_count + 1;
                            remaining_count = remaining_count - 1;
                            
                            % 记录日志
                            fprintf(fileID, '移动: %s -> %s (Stress: %.4f)\n', src, dst, sorted_data(i).stress);
                        catch ME
                            fprintf(fileID, '移动失败: %s -> %s (错误: %s)\n', src, dst, ME.message);
                        end
                    else
                        % 剩余文件夹已满足条件，停止筛选
                        break;
                    end
                end
                
                fprintf(fileID, '处理完成: %s - 移动了 %d 个文件夹\n', level2_path, move_count);
                fclose(fileID);
            end
        end
    end
    
    % 导出到Excel文件
    output_file = fullfile(source_folder, 'ind_stress_value_summary.xlsx');
    
    for sheet = fieldnames(results)'
        sheet_data = results.(sheet{1});
        
        % 转换为表格并写入Excel
        try
            t = array2table(sheet_data, ...
                'VariableNames', {'Level3_Folder', 'Stress_Mean', 'Level2_Folder'});
            writetable(t, output_file, 'Sheet', sheet{1});
        catch ME
            fprintf('写入工作表 %s 时出错: %s\n', sheet{1}, ME.message);
        end
    end
    
    fprintf('结果已保存到: %s\n', output_file);
    fprintf('日志已保存到: %s\n', log_file);
end

source_folder="D:\work\VIVOskinExpe\analyze\expRes\renamed";
CAL_STRESS_expRes(source_folder);
%%
% function CAL_STRESS_expRes(source_folder)
%     % 创建结果存储结构
%     dict1 = containers.Map(...
%     {'f06i', 'f06r', 'm06i', 'm06r', 'f04i', 'f04r', 'f05i', 'f05r',...
%      'm04i', 'm04r', 'm05i', 'm05r', 'f01i', 'f01r', 'f02i', 'f02r',...
%      'f03i', 'f03r', 'm01i', 'm01r', 'm02i', 'm02r', 'm03i', 'm03r',...
%      'f07i', 'f07r', 'f08i', 'f08r', 'm07i', 'm07r', 'm08i', 'm08r',...
%      'f09i', 'f09r', 'f10i', 'f10r', 'm09i', 'm09r', 'm10i', 'm10r'},...
%     {'sec1i', 'sec1r', 'sec2i', 'sec2r', 'sec3i', 'sec3r', 'sec4i', 'sec4r',...
%      'sec5i', 'sec5r', 'sec6i', 'sec6r', 'sec7i', 'sec7r', 'sec8i', 'sec8r',...
%      'sec9i', 'sec9r', 'sec10i', 'sec10r', 'sec11i', 'sec11r', 'sec12i', 'sec12r',...
%      'sec13i', 'sec13r', 'sec14i', 'sec14r', 'sec15i', 'sec15r', 'sec16i', 'sec16r',...
%      'sec17i', 'sec17r', 'sec18i', 'sec18r', 'sec19i', 'sec19r', 'sec20i', 'sec20r'}...
%     );
% 
%     results = struct();
%     dict_keys = keys(dict1);
% 
%     % 遍历字典中的键（一级子文件夹）
%     for k = 1:length(dict_keys)
%         original_name = dict_keys{k};
%         mapped_name = dict1(original_name);
% 
%         % 构建一级文件夹路径
%         level1_path = fullfile(source_folder, original_name);
% 
%         % 检查二级子文件夹是否存在
%         subfolders = {'non_model', 'model_group'};
%         for sf = 1:length(subfolders)
%             level2_path = fullfile(level1_path, subfolders{sf});
% 
%             if ~isfolder(level2_path)
%                 fprintf('跳过不存在的二级文件夹: %s\n', level2_path);
%                 continue;
%             end
% 
%             % 获取三级子文件夹列表
%             level3_dirs = dir(level2_path);
%             level3_dirs = level3_dirs([level3_dirs.isdir]);
%             level3_dirs = level3_dirs(~ismember({level3_dirs.name}, {'.', '..'}));
% 
%             % 处理每个三级子文件夹
%             for d = 1:length(level3_dirs)
%                 level3_name = level3_dirs(d).name;
%                 level3_path = fullfile(level2_path, level3_name);
% 
%                 % 查找CSV文件
%                 csv_files = dir(fullfile(level3_path, '*.csv'));
% 
%                 if isempty(csv_files)
%                     fprintf('跳过空的三级文件夹: %s\n', level3_path);
%                     continue;
%                 end
% 
%                 % 计算所有CSV文件的stress_value平均值
%                 stress_values = [];
%                 for f = 1:length(csv_files)
%                     file_path = fullfile(level3_path, csv_files(f).name);
%                     try
%                         stress_val = cal_STRESS_ind(file_path);
%                         stress_values = [stress_values; stress_val];
%                     catch ME
%                         fprintf('处理文件 %s 时出错: %s\n', file_path, ME.message);
%                     end
%                 end
% 
%                 % 存储结果
%                 if ~isempty(stress_values)
%                     stress_mean = mean(stress_values);
% 
%                     if ~isfield(results, mapped_name)
%                         results.(mapped_name) = {};
%                     end
% 
%                     results.(mapped_name){end+1, 1} = level3_name;
%                     results.(mapped_name){end, 2} = stress_mean;
%                     results.(mapped_name){end, 3} = subfolders{sf};
%                 end
%             end
%         end
%     end
% 
%     % 导出到Excel文件
%     output_file = fullfile(source_folder, 'ind_stress_value_summary.xlsx');
% 
%     for sheet = fieldnames(results)'
%         sheet_data = results.(sheet{1});
% 
%         % 转换为表格并写入Excel
%         try
%             t = array2table(sheet_data, ...
%                 'VariableNames', {'Level3_Folder', 'Stress_Mean', 'Level2_Folder'});
%             writetable(t, output_file, 'Sheet', sheet{1});
%         catch ME
%             fprintf('写入工作表 %s 时出错: %s\n', sheet{1}, ME.message);
%         end
%     end
% 
%     fprintf('结果已保存到: %s\n', output_file);
% end
%%
% source_folder="D:\work\VIVOskinExpe\analyze\expRes\renamed";
% CAL_STRESS_expRes(source_folder);
