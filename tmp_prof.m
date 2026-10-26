cd('D:\work\VIVOSkin_phase2\analyze');
addpath('utils');

NATION = 'AF';          % 'AF' 或 'SA' —— 目录结构 ExpRes\renamed\{nation}\{model}{i/r}\obs_XX
lastPart = 'f09i';
Dtype = 'efit_p';
scale_type = 'unscaled';
attribute = 1;

source_folder = fullfile('D:\work\VIVOSkin_phase2\ExpRes\renamed', NATION, lastPart);
dir_res = findSpecificFiles(source_folder, attribute);

output_folder = fullfile('tmp_prof_out', NATION, lastPart, 'non_model', '01Preference');
if ~exist(output_folder, 'dir'), mkdir(output_folder); end

profile off; clear profile;
profile on;
tP = tic;
process_data_CAT_plot_sing(dir_res, output_folder, lastPart, Dtype, scale_type);
timeP = toc(tP);
p = profile('info');
profile off;
fprintf('\n[profile 模式] 总耗时 = %.2f s\n', timeP);

st = p.FunctionTable;
fprintf('FunctionTable 字段名: %s\n\n', strjoin(fieldnames(st)', ', '));

tt = [st.TotalTime];
[~, idx] = sort(tt, 'descend');
fprintf('%-46s %10s %9s\n', 'Function', 'Total(s)', 'Calls');
fprintf('%s\n', repmat('-', 1, 70));
for k = 1:min(35, numel(idx))
    f = st(idx(k));
    nm = f.FunctionName;
    if numel(nm) > 44, nm = ['...' nm(end-40:end)]; end
    fprintf('%-46s %10.3f %9d\n', nm, f.TotalTime, f.NumCalls);
end
