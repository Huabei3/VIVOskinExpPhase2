%-*- coding:utf-8 -*-
function [ pos_output] = lut3d_xyz2rgbLeo(tgtXYZ_input,recnew_file)
    load(recnew_file);
    channel_rgb_input=RGBin;
    xyz_rgb_input=XYZout;

    M = power(size(channel_rgb_input, 1), 1/3);
    N = round(M);
    R = reshape(channel_rgb_input(:, 1), N, N, N);
    G = reshape(channel_rgb_input(:, 2), N, N, N);
    B = reshape(channel_rgb_input(:, 3), N, N, N);

    lutX = reshape(xyz_rgb_input(:, 1), N, N, N);
    lutY = reshape(xyz_rgb_input(:, 2), N, N, N);
    lutZ = reshape(xyz_rgb_input(:, 3), N, N, N);
%     XYZmax = max(xyz_rgb_input);
    XYZmax = xyz_rgb_input(end,:);
    err = [1 1 1];
    RGB2GRB = [2, 1, 3];
    % 确保并行池已经启动
    CoreNum = feature('numcores');
    if isempty(gcp('nocreate'))
        parpool(CoreNum);
    end
    parfor i_row = 1:size(tgtXYZ_input, 1)
        tgtLAB = xyz2lab(tgtXYZ_input,'user', XYZmax);  
        RGBmesh = channel_rgb_input; % 初始RGB点阵
        XYZmesh = xyz_rgb_input; % 初始XYZ点阵
        RGBrange = [0, 0, 0; 2, 2, 2; channel_rgb_input(end, :)]; % 1、3行：初始的RGB区域边界;2行初始的RGB区域中心
    
        while max(RGBrange(3, :) - RGBrange(1, :)) > 1 % 截取子区域并重复在子区域插值，直至边界与中心相邻
            LABmesh = xyz2lab(XYZmesh,'user', XYZmax);
            % der = deltaE2000(LABmesh, repmat(tgtLAB(i_row, :), N^3, 1));
            der = cielabde(LABmesh, repmat(tgtLAB(i_row, :), N^3, 1));
            [demin, row_min] = min(der);
            RGBrange(2, :) = RGBmesh(row_min, :);
            
            for i = 1:3 % 更换新的上下限，并防止边界错误
                if RGBmesh(row_min, i) == RGBrange(3, i)
                else
                    RGBrange(3, i) = RGBmesh(row_min + N^(RGB2GRB(i)-1), i);
                end
                if RGBmesh(row_min, i) == RGBrange(1, i)
                else
                    RGBrange(1, i) = RGBmesh(row_min - N^(RGB2GRB(i)-1), i);
                end
            end
            % 生成新的域并插值
            RGBpt = round([linspace(RGBrange(1, 1), RGBrange(3, 1), N)', ...
                           linspace(RGBrange(1, 2), RGBrange(3, 2), N)', ...
                           linspace(RGBrange(1, 3), RGBrange(3, 3), N)']);
            [r, ~, ~] = meshgrid(RGBpt(:, 1));
            [~, g, ~] = meshgrid(RGBpt(:, 2));
            [~, ~, b] = meshgrid(RGBpt(:, 3));
            RGBmesh = [reshape(r, [N*N*N, 1]), reshape(g, [N*N*N, 1]), reshape(b, [N*N*N, 1])];
    
    
            method = 'linear';
            x = interp3(R, G, B, lutX, r(:), g(:), b(:), method);
            y = interp3(R, G, B, lutY, r(:), g(:), b(:), method);
            z = interp3(R, G, B, lutZ, r(:), g(:), b(:), method);
    
            XYZmesh = [x, y, z];
        end
    
        XYZ_output(i_row, :) = XYZmesh(row_min, :);
        pos_output(i_row, :) = RGBrange(2, :);
        LABoutput(i_row, :) = xyz2lab(XYZ_output(i_row, :),'user', XYZmax);
        de = deltaE2000(LABoutput(i_row, :), tgtLAB(i_row, :));
    
        % if de >= 2
        %     XYZ_output = err * -5;
        %     pos_output = err * -5;
        % end
                % 显示进度
        if mod(i_row, 100) == 0
            disp([num2str(i_row) '/' num2str(size(tgtXYZ_input, 1))]);
            disp(['Current time: ' datestr(now, 'yyyy-mm-dd HH:MM:SS')]);
        end
    end
end
