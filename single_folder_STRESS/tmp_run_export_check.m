function tmp_run_export_check(groups_override, skip_fit)
%TMP_RUN_EXPORT_CHECK  已并入 run_all_STRESS_and_export.m（含 nation 维度）
%
%   这个文件原来是 run_all_STRESS_and_export.m 的一份临时副本（只是输出名不同）。
%   现在 nation 维度只在 run_all_STRESS_and_export.m 里维护，这里改成薄封装，
%   避免两份逻辑各自演化后再对不上。
%
%   输出统一为 single_folder_STRESS\STRESS_interNintra_mean_by_obs.xlsx
%
%   用法:
%     >> tmp_run_export_check                     % 全部 nation x 全部组
%     >> tmp_run_export_check({'AF/f04i'})        % 只跑指定组（'f04i' 也能匹配）
%     >> tmp_run_export_check([], true)           % 跳过步骤1，只重新汇总导出

if nargin < 1, groups_override = []; end
if nargin < 2, skip_fit = []; end

run_all_STRESS_and_export(groups_override, skip_fit);
end
