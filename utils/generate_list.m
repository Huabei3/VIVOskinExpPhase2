function generate_list(output_folder, par_all, r_all, average)
    % 生成 list 并保存为表格文件
    [n_para, ~] = size(par_all);
    list = zeros(n_para, 9); % 分别是 L、a、b、C、h、A、A/B、theta、coefficients
    L = average(:, 1);

    list(:, 1) = L(1:n_para,:);
    list(:, 2:3) = par_all(:, 4:5);
    list(:, 4) = sqrt(par_all(:, 4).^2 + par_all(:, 5).^2);
    list(:, 5) = atan2d_360(par_all(:, 5), par_all(:, 4));

    lambda00 = par_all(:, 1);
    lambda01 = par_all(:, 3) / 2;
    lambda10 = par_all(:, 3) / 2;
    lambda11 = par_all(:, 2);
    theta = 0.5 * atan2d_360(2 * lambda01, (lambda00 - lambda11));
    isshort = lambda00 < lambda11;

    A = lambda00 .* cosd(theta).^2 - lambda01 .* sind(2 * theta) + lambda11 .* sind(theta).^2;
    B = lambda00 .* sind(theta).^2 + lambda01 .* sind(2 * theta) + lambda11 .* cosd(theta).^2;
    aabb(:, 1) = sqrt(1 ./ A);
    aabb(:, 2) = sqrt(1 ./ B);
    A = aabb(:, 1);
    B = aabb(:, 2);

    list(:, 6) = aabb(:, 1);
    list(:, 7) = aabb(:, 1) ./ aabb(:, 2);
    list(:, 8) = theta - 90;
    list(:, 9) = r_all(:);

    save_folder = fullfile(output_folder, 'list');
    if ~exist(save_folder, 'dir')
        mkdir(save_folder);
    end
    % save(fullfile(save_folder, strcat("ellip_list.mat")), 'list');
    list_table = array2table(list, 'VariableNames', ...
    {'L', 'a', 'b', 'C', 'h', 'A', 'A_over_B', 'theta', 'coefficients'});

    % 保存为 xlsx 文件
    writetable(list_table, fullfile(save_folder, 'ellip_list.xlsx'));
end