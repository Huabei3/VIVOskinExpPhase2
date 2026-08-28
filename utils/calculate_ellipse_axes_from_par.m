function [A, B, theta] = calculate_ellipse_axes_from_par(par)
    % 从 par 中提取椭圆参数并计算半长轴 (A)、半短轴 (B) 和旋转角度 (theta)
    %
    % 输入参数：
    %   par: 包含椭圆参数的向量或矩阵，格式为 [lambda00, lambda11, lambda01, ...]
    %
    % 输出参数：
    %   A: 半长轴
    %   B: 半短轴
    %   theta: 椭圆的旋转角度（以度为单位）

    % 提取椭圆参数
    y_target=0.5;
    denominator=(log((1/y_target-1)./par(:,6)).^2);
    lambda00 = par(:, 1)./denominator; % lambda00 是 par 的第一列
    lambda11 = par(:, 2)./denominator; % lambda11 是 par 的第二列
    lambda01 = par(:, 3) ./denominator./ 2; % lambda01 是 par 的第三列的一半
    
    % 计算旋转角度 theta
    theta = 0.5 * atan2d_360(2 * lambda01, (lambda00 - lambda11));
    
    % 计算 A 和 B
    A = lambda00 .* cosd(theta).^2 - lambda01 .* sind(2 * theta) + lambda11 .* sind(theta).^2;
    B = lambda00 .* sind(theta).^2 + lambda01 .* sind(2 * theta) + lambda11 .* cosd(theta).^2;
    
    % 计算半长轴和半短轴
    A_t = sqrt(1 ./ A);
    B_t = sqrt(1 ./ B);
    A=max(A_t,B_t);
    B=min(A_t,B_t);
end

function degree = atan2d_360(y, x)
    % 将 atan2d 的结果转换为 0 到 360 度
    degree = atan2d(y, x);
    if degree < 0
        degree = degree + 360;
    end
end