% _tmp_export_batch.m  临时文件：静态检查 + 用 skip_fit=true 重新导出，验证完即删
fprintf('--- checkcode ---\n');
msgs = checkcode('single_folder_STRESS\run_all_STRESS_and_export.m', '-string');
if isempty(msgs)
    disp('CHECKCODE_CLEAN');
else
    disp(msgs);
end

fprintf('\n--- 用 skip_fit=true 重新导出 ---\n');
addpath('single_folder_STRESS');
run_all_STRESS_and_export([], true);
