% test_lut_96color.m — 96 色块 XYZ -> phase2 LUT -> RGB（MATLAB 侧，无并行）
% 数据流（与 DiffLUT729pre96backKDVall1.m 对齐）：
%   1. load VIVO_CS2000_96_x200_3_mode96*.mat 的 DATAs
%   2. DATAs(1,:) = []; 删表头
%   3. SPD = reshape(cell2mat(DATAs(:,4)),401,96);  % 380:1:780 nm
%   4. XYZ10 = spd2xyz([SPDname SPD],10);            % 96x3 XYZ (10° observer)
%   5. RGB = lut3d_xyz2rgbKDitp1_nopar(XYZ10, data_ipv30_phase2_3.mat);
%
% 输出：test96_XYZ10.mat / test96_RGB.mat（与 Python 侧对齐）

close all; clc; clear;
addpath("utils\")

DATA96 = 'D:\work\VIVOSkin_phase2\display\x200\VIVO_CS2000_96_x200_3_mode962026_08_06_11_30_07.mat';
LUT_BACK = 'D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\A_characterization\display_model\data_ipv30_phase2_3.mat';

% 1-3. DATAs -> SPD (401x96)
load(DATA96);
DATAs(1,:) = [];
SPD = reshape(cell2mat(DATAs(:,4)), 401, 96);
SPDname = 380:1:780; SPDname = SPDname';

% 4. XYZ10 (96x3)
XYZ10 = spd2xyz([SPDname SPD], 10);
disp(['XYZ10 size = ', num2str(size(XYZ10))]);
disp('XYZ10 前3行:');
disp(XYZ10(1:3,:));

% 5. RGB (96x3)
RGB = lut3d_xyz2rgbKDitp1_nopar(XYZ10, LUT_BACK);
disp(['RGB size = ', num2str(size(RGB))]);
disp('RGB 前3行:');
disp(RGB(1:3,:));

% 输出（保存到 I_render_stimuli 目录，与 Python 侧可交叉读取）
save('test96_XYZ10.mat', 'XYZ10');
save('test96_RGB.mat', 'RGB');
disp('done: 已写出 test96_XYZ10.mat / test96_RGB.mat');
