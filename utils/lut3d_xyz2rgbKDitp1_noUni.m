function [RGB, out_of_gamut_ratio] = lut3d_xyz2rgbKDitp1_noUni(XYZ, datafile)
    % 加载 LUT 数据
    LUTdata = load(datafile);

    P_labs = LUTdata.P_labs;
    XYZw1 = LUTdata.XYZw;
    rgb = LUTdata.rgb;
    cubeL = LUTdata.cubeL;

    % 将 XYZ 转换为 Lab
    Lab = xyz2lab(XYZ, 'user', XYZw1);

    % 初始化 RGB
    RGB = zeros(size(XYZ, 1), 3);

    % 创建 KD 树
    kdtree = KDTreeSearcher(P_labs);
    delete(gcp("nocreate"));
    % 确保并行池已经启动
    % CoreNum = feature('numcores');
    % if isempty(gcp('nocreate'))
        parpool(6);
    % end

    % 将 rgb reshape 为网格
    grid_size = nthroot(size(rgb, 1), 3); % 网格大小
    rgb_grid = reshape(rgb, [grid_size, grid_size, grid_size, 3]); % reshape 为 3D 网格

    % 生成网格点的坐标
    [x, y, z] = meshgrid(1:grid_size, 1:grid_size, 1:grid_size);
    grid_points = [x(:), y(:), z(:)]; % 网格点的坐标

    % 无去重：逐行独立 KNN(K=8)，与去重版仅在是否 uniquetol 上不同
    for i_row = 1:size(Lab, 1)
        % 获取当前行的 Lab 值
        Lab_row = Lab(i_row, :);
        % 找到最近的 8 个点（立方体的 8 个顶点）
        [indices, ~] = knnsearch(kdtree, Lab_row, 'K', 8);

        % 计算插值权重
        weights = zeros(8, 1);
        for j = 1:8
            distances = norm(Lab_row - P_labs(indices(j), :));
            weights(j) = 1 / distances; % 使用距离倒数作为权重
        end
        weights = weights / sum(weights); % 归一化权重

        % 插值计算 RGB
        RGB(i_row, :) = sum(weights .* rgb(indices, :), 1); % 加权平均

        % 显示进度
        if mod(i_row, 100000) == 0
            disp([num2str(i_row) '/' num2str(size(Lab, 1))]);
            disp(['Current time: ' datestr(now, 'yyyy-mm-dd HH:MM:SS')]);
        end
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
