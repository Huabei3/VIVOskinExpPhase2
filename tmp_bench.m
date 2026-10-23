cd('D:\work\VIVOSkin_phase2\analyze');
addpath('utils');

rng(0);
lab = [rand(33,1)*50+30, rand(33,1)*40-20, rand(33,1)*40-20];
sc  = rand(33,1);
N = 60;
outdir = 'tmp_bench_out';
if ~exist(outdir,'dir'), mkdir(outdir); end

% ---- 方法1：当前做法 figure + getframe + frame2im + imwrite + close ----
t1 = tic;
for k = 1:N
    figure('Visible','off');
    plot_with_scatter(lab, sc);
    title('t', 'Interpreter', 'none');
    frame = getframe(gcf);
    img = frame2im(frame);
    imwrite(img, fullfile(outdir, sprintf('m1_%02d.jpg', k)));
    close(gcf);
end
T1 = toc(t1);

% ---- 方法2：exportgraphics（每次新建 figure） ----
t2 = tic;
for k = 1:N
    f = figure('Visible','off');
    plot_with_scatter(lab, sc);
    title('t', 'Interpreter', 'none');
    exportgraphics(f, fullfile(outdir, sprintf('m2_%02d.jpg', k)), 'Resolution', 150);
    close(f);
end
T2 = toc(t2);

% ---- 方法3：复用同一个 figure + exportgraphics ----
f = figure('Visible','off');
t3 = tic;
for k = 1:N
    clf;
    plot_with_scatter(lab, sc);
    title('t', 'Interpreter', 'none');
    exportgraphics(f, fullfile(outdir, sprintf('m3_%02d.jpg', k)), 'Resolution', 150);
end
T3 = toc(t3); close(f);

% ---- 方法4：复用 figure，但只在第1张画 colorbar ----
f = figure('Visible','off');
t4 = tic;
for k = 1:N
    clf;
    scatter(lab(:,2), lab(:,3), 5, sc, 'filled'); hold on;
    line([0 0],[-60 60],'Color','k','LineStyle','--');
    line([-60 60],[0 0],'Color','k','LineStyle','--');
    refline(1,0); axis equal; xlim([-60 60]); ylim([-60 60]);
    xlabel('{\ita*}'); ylabel('{\itb*}');
    exportgraphics(f, fullfile(outdir, sprintf('m4_%02d.jpg', k)), 'Resolution', 150);
end
T4 = toc(t4); close(f);

fprintf('\n%-42s %8s %10s\n', '方法', '总(s)', 'ms/张');
fprintf('%s\n', repmat('-',1,62));
fprintf('%-42s %8.2f %10.1f\n', '1) figure+getframe+imwrite+close (现状)', T1, T1/N*1000);
fprintf('%-42s %8.2f %10.1f\n', '2) exportgraphics + close', T2, T2/N*1000);
fprintf('%-42s %8.2f %10.1f\n', '3) 复用fig + exportgraphics', T3, T3/N*1000);
fprintf('%-42s %8.2f %10.1f\n', '4) 复用fig + 去colorbar + exportgfx', T4, T4/N*1000);
fprintf('\n加速比: 1/2 = %.1fx    1/3 = %.1fx    1/4 = %.1fx\n', T1/T2, T1/T3, T1/T4);
