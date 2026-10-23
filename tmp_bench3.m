cd('D:\work\VIVOSkin_phase2\analyze');
addpath('utils');
rng(0);
lab = [rand(33,1)*50+30, rand(33,1)*40-20, rand(33,1)*40-20];
sc  = rand(33,1);
N = 30;
outdir = 'tmp_bench_out';
if ~exist(outdir,'dir'), mkdir(outdir); end

% F 对照：复用fig(560x420) + 只换CData + getframe+imwrite
f = figure('Visible','off','Position',[100 100 560 420]);
h = setup_axes(f, lab, sc);
tF = tic;
for k = 1:N
    set(h,'CData',rand(33,1));
    fr = getframe(f); imwrite(frame2im(fr), fullfile(outdir,sprintf('f_%02d.jpg',k)));
end
TF = toc(tF); close(f);

% G: 复用fig + 只换CData + print -djpeg（一步出图，省 frame2im/imwrite）
f = figure('Visible','off','Position',[100 100 560 420]);
h = setup_axes(f, lab, sc);
tG = tic; okG = true;
for k = 1:N
    try
        set(h,'CData',rand(33,1));
        print(f, fullfile(outdir,sprintf('g_%02d.jpg',k)), '-djpeg');
    catch ME
        fprintf('G 失败: %s\n', ME.message); okG = false; break;
    end
end
TG = toc(tG); close(f);

% H: 复用fig(小尺寸 360x270) + 只换CData + getframe+imwrite
f = figure('Visible','off','Position',[100 100 360 270]);
h = setup_axes(f, lab, sc);
tH = tic;
for k = 1:N
    set(h,'CData',rand(33,1));
    fr = getframe(f); imwrite(frame2im(fr), fullfile(outdir,sprintf('h_%02d.jpg',k)));
end
TH = toc(tH); close(f);

% I: F 再跑一遍（看测量稳定性）
f = figure('Visible','off','Position',[100 100 560 420]);
h = setup_axes(f, lab, sc);
tI = tic;
for k = 1:N
    set(h,'CData',rand(33,1));
    fr = getframe(f); imwrite(frame2im(fr), fullfile(outdir,sprintf('i_%02d.jpg',k)));
end
TI = toc(tI); close(f);

fprintf('\n%-56s %8s %10s\n','实验','总(s)','ms/张');
fprintf('%s\n', repmat('-',1,76));
fprintf('%-56s %8.2f %10.1f\n','F 复用fig@560x420 + CData + getframe/imwrite', TF, TF/N*1000);
if okG
    fprintf('%-56s %8.2f %10.1f\n','G 复用fig@560x420 + CData + print -djpeg', TG, TG/N*1000);
end
fprintf('%-56s %8.2f %10.1f\n','H 复用fig@360x270 + CData + getframe/imwrite', TH, TH/N*1000);
fprintf('%-56s %8.2f %10.1f\n','I = F 重复测(稳定性)', TI, TI/N*1000);
fprintf('\n现状(基准2 的 C) = 418 ms/张\n');
fprintf('F/现状=%.2fx  H/现状=%.2fx\n', (TF/N*1000)/418, (TH/N*1000)/418);

function h = setup_axes(f, lab, sc)
    ax = axes(f); hold(ax,'on');
    h = scatter(ax, lab(:,2), lab(:,3), 5, sc, 'filled');
    line(ax,[0 0],[-60 60],'Color','k','LineStyle','--');
    line(ax,[-60 60],[0 0],'Color','k','LineStyle','--');
    refline(ax,1,0); axis(ax,'equal');
    xlim(ax,[-60 60]); ylim(ax,[-60 60]);
    xlabel(ax,'{\ita*}'); ylabel(ax,'{\itb*}');
    colorbar(ax); title(ax,'t');
end
