% tmp_export_batch.m  临时文件：静态检查 + 用 skip_fit=true 导出到临时 xlsx，验证完即删
fprintf('--- checkcode ---\n');
msgs = checkcode('single_folder_STRESS\tmp_run_export_check.m', '-string');
if isempty(msgs)
    disp('CHECKCODE_CLEAN');
else
    disp(msgs);
end

fprintf('\n--- 用 skip_fit=true 导出到 tmp_STRESS_check.xlsx ---\n');
addpath('single_folder_STRESS');
tmp_run_export_check([], true);
