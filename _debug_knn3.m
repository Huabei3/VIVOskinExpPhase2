% _debug_knn3.m - dump KNN index/distance for 3 diff colors
close all; clc; clear;
addpath('utils')

LUT_BACK = 'D:\work\VIVOSkinExpe\PeggySkinBackup\A_code\C_VIVO_skin_project\A_characterization\display_model\data_ipv30_phase2_3.mat';
load('test96_XYZ10.mat');
load(LUT_BACK);

Lab = xyz2lab(XYZ10, 'user', XYZw);
kdtree = KDTreeSearcher(P_labs);

for i = [19 37 55]
    q = Lab(i, :);
    [idx8, d8] = knnsearch(kdtree, q, 'K', 8);
    fprintf('\n--- color #%d (1-based %d)  Lab=[%.8f %.8f %.8f] ---\n', i-1, i, q);
    fprintf('  KNN idx: '); fprintf('%d ', idx8); fprintf('\n');
    fprintf('  KNN dist: '); fprintf('%.10f ', d8); fprintf('\n');
    w = 1 ./ d8';
    w = w / sum(w);
    rgb_out = sum(w .* rgb(idx8, :), 1);
    fprintf('  RGB weighted: [%.8f %.8f %.8f]\n', rgb_out);
end
