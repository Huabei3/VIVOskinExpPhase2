%%
%-------------------------------------
% 计算单个被试的STRESS
%------------------------------------

% rehash toolboxcache % 解决无法访问以前可以访问的文件，重新处理工具箱缓存
close all; % 关闭所有图窗
clc;       % 清空命令窗口
clear;     % 清除工作区所有变量
addpath("utils\")



%% 生成目录

source_folder = 'D:\work\VIVOSkin_phase2\ExpRes\renamed\m10r'; 



% 获取所有子文件夹
subfolders = dir(fullfile(source_folder, '*'));
subfolders = subfolders([subfolders.isdir]); % 只保留文件夹
subfolders = {subfolders.name}'; % 提取文件夹名称
subfolders(strcmp(subfolders(:,1) , '.')) = [];
subfolders(strcmp(subfolders(:,1) , '..')) = [];
subfolders(strcmp(subfolders(:,1) , 'stress_mat')) = [];
subfolders(strcmp(subfolders(:,1) , 'stress_csv')) = [];
subfolders(strcmp(subfolders(:,1) , 'discarded')) = [];
% 初始化一个 cell 数组来存储每个属性对应的文件路径

for i = 1:length(subfolders)
    subfolder_path = fullfile(source_folder, subfolders{i});
    dir_ind_csv=dir(fullfile(subfolder_path,"*.csv"));
    output_folder_ind=fullfile(subfolder_path,"stress_mat");
    if ~exist(output_folder_ind,"dir")
        mkdir(output_folder_ind);
    end
    process_data_stress(dir_ind_csv, output_folder_ind);
end
        % 获取子文件夹中的所有文件




