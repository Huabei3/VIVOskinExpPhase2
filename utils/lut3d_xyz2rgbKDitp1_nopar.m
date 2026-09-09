function [RGB, out_of_gamut_ratio] = lut3d_xyz2rgbKDitp1_nopar(XYZ, datafile)
% 无并行版 lut3d_xyz2rgbKDitp1（供 96 色块等小样本使用，避免 parpool 开销）
% 逻辑与 lut3d_xyz2rgbKDitp1.m 完全一致，仅去掉 parpool(6) 与进度打印。

    LUTdata = load(datafile);
    P_labs = LUTdata.P_labs;
    XYZw1 = LUTdata.XYZw;
    rgb = LUTdata.rgb;

    % 将 XYZ 转换为 Lab
    Lab = xyz2lab(XYZ, 'user', XYZw1);

    % 初始化 RGB
    RGB = zeros(size(XYZ, 1), 3);

    % 创建 KD 树
    kdtree = KDTreeSearcher(P_labs);

    % 按行去重（三个通道的值相差均小于 0.01 视为相同）
    [~, unique_indices, ~] = uniquetol(Lab, 0.01/max(max(Lab)), 'ByRows', true, 'OutputAllIndices', true);

    % 对唯一行计算
    RGB_unique = cell(numel(unique_indices), 1);
    for i_unique = 1:numel(unique_indices)
        idx = unique_indices{i_unique};
        Lab_row = Lab(idx(1), :);

        % 找到最近的 8 个点
        [indices, ~] = knnsearch(kdtree, Lab_row, 'K', 8);

        % 计算插值权重
        weights = zeros(8, 1);
        for j = 1:8
            distances = norm(Lab_row - P_labs(indices(j), :));
            weights(j) = 1 / distances;
        end
        weights = weights / sum(weights);

        % 插值计算 RGB
        RGB_row = sum(weights .* rgb(indices, :), 1);
        RGB_unique{i_unique} = repmat(RGB_row, numel(idx), 1);
    end

    % 将各组的结果合并到 RGB 矩阵中
    for i_unique = 1:numel(unique_indices)
        idx = unique_indices{i_unique};
        RGB(idx, :) = RGB_unique{i_unique};
    end

    % 计算超色域值的比例
    out_of_gamut = sum(any(RGB < 0 | RGB > 255, 2));
    out_of_gamut_ratio = out_of_gamut / size(RGB, 1);

    % 使用邻近的有效值插值处理 NaN 和 Inf
    for c = 1:size(RGB, 2)
        invalid_mask = isnan(RGB(:, c)) | isinf(RGB(:, c));
        if any(invalid_mask)
            RGB(:, c) = fillmissing(RGB(:, c), 'nearest');
        end
    end

    % 限制 RGB 值的范围
    RGB(RGB < 0 | isnan(RGB) | isinf(RGB)) = 0;
    RGB(RGB >= 0 & isinf(RGB)) = 255;
    RGB(RGB <= 0 & isinf(RGB)) = 0;
    RGB(RGB > 255) = 255;
end
