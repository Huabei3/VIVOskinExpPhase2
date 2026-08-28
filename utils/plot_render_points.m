function plot_render_points(dlab)

    hold on;

    % 绘制散点图
    scatter(dlab(:, 2), dlab(:, 3), 40,  'filled');
    hold on;



       % 添加坐标轴和参考线
    lim_max = max(max(dlab(:, 2)), max( dlab(:, 3)));
    lim_min = min(min(dlab(:, 2)), min( dlab(:, 3)));
    line([0, 0], [lim_min, lim_max], 'Color', 'k', 'LineStyle', '--'); % x=0
    line([lim_min, lim_max], [0, 0], 'Color', 'k', 'LineStyle', '--'); % y=0
    refline(1, 0); % 45 度线

    % 设置图形属性
    axis equal;
    xlim([lim_min, lim_max]);
    ylim([lim_min, lim_max]);
    xlabel('{\ita*}');
    ylabel('{\itb*}');
    title('Contour Plot with Scatter');
    hold off;
end