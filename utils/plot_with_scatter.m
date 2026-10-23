function plot_with_scatter(lab_group, MSV_group)
%PLOT_WITH_SCATTER 在 a*-b* 平面上画散点，颜色表示评分
%
%   逻辑参考 plot_contour_with_scatter，但去掉了椭圆等高线部分：
%     - 不再需要 par 入参
%     - 删除 contour(data2,data3,y,...) 与拟合中心点 scatter(par(4),par(5))
%     - 保留：散点、参考线（x=0 / y=0 / 45 度）、坐标轴范围
%
%   输入:
%     lab_group : n x 3，每行一个刺激的 Lab 值 (L*, a*, b*)
%                 a* 取第 2 列, b* 取第 3 列
%     MSV_group : n x 1，每个刺激的评分，用作散点颜色

    % 绘制散点图（颜色 = 评分）
    scatter(lab_group(:, 2), lab_group(:, 3), 5, MSV_group, 'filled');
    hold on;

    % 添加坐标轴和参考线（与原函数一致）
    lim_max = max(max(lab_group(:, 2)), max(lab_group(:, 3))) + 10;
    lim_min = min(min(lab_group(:, 2)), min(lab_group(:, 3))) - 10;
    line([0, 0], [lim_min, lim_max], 'Color', 'k', 'LineStyle', '--');      % x=0
    line([lim_min, lim_max], [0, 0], 'Color', 'k', 'LineStyle', '--');      % y=0
    refline(1, 0);                                                          % 45 度线

    % 设置图形属性
    axis equal;
    xlim([lim_min, lim_max]);
    ylim([lim_min, lim_max]);
    xlabel('{\ita*}');
    ylabel('{\itb*}');
    colorbar;       % 颜色 = 评分，没有色条无法读数（如不需要删掉这一行即可）
    hold off;
end
