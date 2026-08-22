% ============================================================
% 临时诊断脚本：复刻 main_i_test.m 对 f04i/H3K (i_type=2, CCT=3000) 的
% dlab 计算链路，输出全部关键中间量，供 Python 侧锚点对照。
% 运行方式：MATLAB 打开本文件直接 run，输出到命令窗口。
% ============================================================
addpath(fullfile(fileparts(mfilename('fullpath')), 'utils'));

I_ROOT    = 'D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\I_render_stimuli';
DATA_ROOT = 'D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project';
XYZ_PATH  = 'D:\work\VIVOSkinExpe\original_image_XYZ';

ct = 'H3K'; i = 1; i_type = 2; if_wei = 0; if_2mask = 0; CCT = 3000;
mask_dir  = fullfile(I_ROOT, 'mask', 'f04i');
nosd_dir  = fullfile(I_ROOT, 'Shadow', 'mask', 'f04i', 'nosd');
img_name  = 'H3K';

% ---- 1) 白点 ----
fwd = load(fullfile(DATA_ROOT, 'A_characterization', 'display_model', 'datai_ipv18_3.mat'));
wd65 = [94.813 100.000 107.262];
wd65_scaled = wd65 ./ 100 .* fwd.XYZw(2);
fprintf('1 wd65_scaled   = %s\n', mat2str(wd65_scaled, 12));

% ---- 2) aveLab_D65_2 ----
load(fullfile(I_ROOT, 'documents', 'aveSkin', 'i', strcat('aveLab_D65_', num2str(i_type), '.mat')), 'labC_HD65');
fprintf('2 labC_HD65     = %s\n', mat2str(labC_HD65, 12));

% ---- 3) points ----
num_points = readmatrix(fullfile(I_ROOT, 'points_added_33.xlsx'));
num_points = [zeros(length(num_points), 1), num_points];
fprintf('3 num_points(1:3,:) = %s\n', mat2str(num_points(1:3, :), 12));

% ---- 4) lab1 / average ----
img0 = imread(fullfile(mask_dir, 'H3K.JPG'));
img = im2double(img0);
[m, n, p] = size(img);
bull = imread(fullfile(mask_dir, 'H3K.JPG'));
bull_nosd = imread(fullfile(nosd_dir, 'H3K.JPG'));
XYZd = load(fullfile(XYZ_PATH, 'f04i', 'H3K.mat'));
XYZ = XYZd.XYZ_cropped;
fprintf('4 size(XYZ_cropped) = %s\n', mat2str(size(XYZ), 12));
xyz1 = reshape(XYZ, [m * n, p]);
[lab1] = xyz2lab(xyz1, 'user', wd65_scaled);
fprintf('4 lab1 mean(all) = %s\n', mat2str(mean(lab1), 12));
average = get_average(lab1, bull, if_wei);
fprintf('4 average        = %s\n', mat2str(average, 12));

% ---- 4b) bull JPEG 解码锚点：背景像素数 + 导出解码结果供 Python 对照 ----
fprintf('4b bull_bg_count(all==0) = %d\n', sum(all(bull == 0, 3)));
fprintf('4b bull_bg_count(any==0) = %d\n', sum(any(bull == 0, 3)));
fprintf('4b bull_unique_n = %d\n', numel(unique(bull(:))));
save(fullfile(I_ROOT, '..', 'I_render_stimuli_python', 'bull_f04i_H3K.mat'), 'bull');

% ---- 5) C_pre / factor ----
a_CL = [6.7421, -9.9816];
if average(1) > 60
    C_pre = a_CL(1) * log(60) + a_CL(2);
else
    C_pre = a_CL(1) * log(average(1)) + a_CL(2);
end
fprintf('5 C_pre = %.12f\n', C_pre);
factor = C_pre ./ labC_HD65(1, 4);
fprintf('5 factor = %.12f\n', factor);

% ---- 6) dlabs ----
dlabs = repmat([average(1), labC_HD65(1, 2:3)], length(num_points), 1) + num_points;
dlabs(:, 2:3) = dlabs(:, 2:3) .* factor;
fprintf('6 dlabs(1,:)     = %s\n', mat2str(dlabs(1, :), 12));
fprintf('6 dlabs(29,:)    = %s\n', mat2str(dlabs(29, :), 12));
fprintf('6 dlabs(33,:)    = %s\n', mat2str(dlabs(33, :), 12));

% ---- 7) CAT 链 ----
XYZw_pre = CCT2xyz(CCT);
fprintf('7 XYZw_pre       = %s\n', mat2str(XYZw_pre, 12));

dlab_CATed = zeros(length(num_points), 3);
for ip = 1:length(num_points)
    dlab_CATed(ip, :) = CAT_lab2lab1(dlabs(ip, :), 'full', CCT, 'fore');
end
fprintf('7 dlab_CATed(1,:)  = %s\n', mat2str(dlab_CATed(1, :), 12));
fprintf('7 dlab_CATed(29,:) = %s\n', mat2str(dlab_CATed(29, :), 12));
fprintf('7 dlab_CATed(33,:) = %s\n', mat2str(dlab_CATed(33, :), 12));

dlab_CATed = adjust_dlabs_shape1(dlab_CATed);
fprintf('8 dlab_CATed_adj(1,:)  = %s\n', mat2str(dlab_CATed(1, :), 12));

% ---- 9) 文件名对照 ----
fprintf('9 MATLAB 文件名  = [58.5861,22.4045,44.8393]\n');
fprintf('9 dlab(1,:)      = %s\n', mat2str(dlab_CATed(1, :), 12));
