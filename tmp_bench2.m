cd('D:\work\VIVOSkin_phase2\analyze');
addpath('utils');

fprintf('=== CPU ===\n');
if ispc
    [~, out] = system('wmic cpu get NumberOfCores,NumberOfLogicalProcessors /format:list');
    disp(strtrim(out));
end
try, fprintf('maxNumCompThreads = %d\n', maxNumCompThreads); catch, end
fprintf('物理核数 (feature parpool): 见下\n\n');

rng(0);
lab = [rand(33,1)*50+30, rand(33,1)*40-20, rand(33,1)*40-20];
sc  = rand(33,1);
N = 30;
outdir = 'tmp_bench_out';
if ~exist(outdir,'dir'), mkdir(outdir); end

% A: 新建 figure + 画 + close（不导出）
tA = tic;
for k = 1:N
    f = figure('Visible','off');
    plot_with_scatter(lab, sc); title('t', 'Interpreter', 'none');
    close(f);
end
TA = toc(tA);

% B: 新建 figure + 画 + getframe（不写盘）+ close
tB = tic;
for k = 1:N
    f = figure('Visible','off');
    plot_with_scatter(lab, sc); title('t', 'Interpreter', 'none');
    fr = getframe(f);
    close(f);
end
TB = toc(tB);

% C: 新建 figure + 画 + getframe + frame2im + imwrite + close  = 现状
tC = tic;
for k = 1:N
    f = figure('Visible','off');
    plot_with_scatter(lab, sc); title('t', 'Interpreter', 'none');
    fr = getframe(f); img = frame2im(fr);
    imwrite(img, fullfile(outdir, sprintf('c_%02d.jpg', k)));
    close(f);
end
TC = toc(tC);

% D: 复用 figure + clf + 画（不导出）
f = figure('Visible','off');
tD = tic;
for k = 1:N
    clf(f);
    plot_with_scatter(lab, sc); title('t', 'Interpreter', 'none');
end
TD = toc(tD); close(f);

% E: 复用 figure + clf + 画 + getframe + imwrite
f = figure('Visible','off');
tE = tic;
for k = 1:N
    clf(f);
    plot_with_scatter(lab, sc); title('t', 'Interpreter', 'none');
    fr = getframe(f); img = frame2im(fr);
    imwrite(img, fullfile(outdir, sprintf('e_%02d.jpg', k)));
end
TE = toc(tE); close(f);

% F: 复用 figure，只建一次坐标系，之后仅 set CData 换色（5 个 observer 共享同一 scene 的场景）
f = figure('Visible','off');
np = N;                     % 沿用 N 次换色导出
tF = tic;
h = scatter(lab(:,2), lab(:,3), 5, sc, 'filled'); hold on;
line([0 0],[-60 60],'Color','k','LineStyle','--');
line([-60 60],[0 0],'Color','k','LineStyle','--');
refline(1,0); axis equal; xlim([-60 60]); ylim([-60 60]);
xlabel('{\ita*}'); ylabel('{\itb*}'); colorbar; title('t');
prepT = toc(tF);            % 建坐标系的一次性成本
tF2 = tic;
for k = 1:np
    set(h, 'CData', rand(33,1));
    fr = getframe(f); img = frame2im(fr);
    imwrite(img, fullfile(outdir, sprintf('f_%02d.jpg', k)));
end
TF = toc(tF2); close(f);

fprintf('%-52s %8s %10s\n', '实验', '总(s)', 'ms/张');
fprintf('%s\n', repmat('-',1,72));
fprintf('%-52s %8.2f %10.1f\n', 'A 新建fig+画+close                (纯绘图)', TA, TA/N*1000);
fprintf('%-52s %8.2f %10.1f\n', 'B A + getframe                    (getframe增量)', TB, TB/N*1000);
fprintf('%-52s %8.2f %10.1f\n', 'C B + frame2im + imwrite          (现状=1)', TC, TC/N*1000);
fprintf('%-52s %8.2f %10.1f\n', 'D 复用fig+clf+画                  (纯绘图)', TD, TD/N*1000);
fprintf('%-52s %8.2f %10.1f\n', 'E 复用fig+clf+画+getframe+imwrite', TE, TE/N*1000);
fprintf('%-52s %8.2f %10.1f\n', 'F 一次建坐标系, 只换CData+导出', TF, TF/N*1000);
fprintf('\n分解(ms/张): getframe增量=%.0f  imwrite增量=%.0f  新建vs复用=%.0f\n', ...
    (TB-TA)/N*1000, (TC-TB)/N*1000, (TA-TD)/N*1000);
fprintf('F 的坐标系一次性建图成本 = %.0f ms\n', prepT*1000);
fprintf('现方案 vs F: %.2fx\n', TC/TF);
