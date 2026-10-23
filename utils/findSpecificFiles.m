function dir_res = findSpecificFiles(source_folder_used, attribute)
    % findSpecificFiles 函数
    % 输入：
    %   source_folder_used - 目标文件夹路径
    %   attribute - 文件名中的属性编号（例如 01, 02 等）
    % 输出：
    %   dir_res - 包含找到的文件信息的 dir 结构体数组

    % 获取所有以 "obs" 开头的子文件夹
    subFolders = dir(fullfile(source_folder_used, 'obs*'));
    subFolders = subFolders([subFolders.isdir]); % 只保留文件夹

    % 初始化一个空的 dir 结构体数组
    dir_res = [];

    % 支持的文件格式
    supportedFormats = {'.csv', '.xls', '.xlsx'};


    % 遍历每个子文件夹
    for i_obs = 1:length(subFolders)
        % 获取当前子文件夹路径
        folderPath = fullfile(source_folder_used, subFolders(i_obs).name);

        % 遍历支持的文件格式
        for fmt = supportedFormats
            % 构建目标文件名（兼容 obs01 / obs_01 两种命名）
            obsName = strrep(subFolders(i_obs).name, '_', '');
            targetFileName = sprintf('%s_%02d%s', obsName, attribute, fmt{1});
            targetFilePath = fullfile(folderPath, targetFileName);

            % 检查文件是否存在
            if exist(targetFilePath, 'file')
                % 获取文件的 dir 信息
                fileInfo = dir(targetFilePath);

                % 检查文件大小是否小于 8KB
                if ~fileInfo.bytes < 8 * 1024
                    dir_res = [dir_res; fileInfo];
                end
                break; % 如果找到文件，跳出格式循环
            end
        end
    end


end