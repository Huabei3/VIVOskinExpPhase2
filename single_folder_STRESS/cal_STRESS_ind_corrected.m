function [stress_value, info] = cal_STRESS_ind_corrected(file_path)
%CAL_STRESS_IND_CORRECTED  中心化版 STRESS_intra（最小二乘拟合允许截距）
%
%   与 cal_STRESS_ind.m 的唯一区别：先去掉两次评分各自的均值，再计算"分歧 / 总量"。
%
%   ---- 原算法为什么错 ----
%   原版 STRESS.m 计算
%       S = sqrt(1 - (sum(dEi.*dVi))^2 / (sum(dEi.^2).*sum(dVi.^2)))
%   等价于用过原点的直线 d = b*u 去拟合（b = sum(u.*v)/sum(u.^2)，只有一个自由参数）。
%   "过原点"意味着拟合不允许截距，而截距正好对应被试整体打分的绝对高低，
%   于是残差被评分水平污染：分数越靠右，同样的分歧摊下来 S 越小。
%   实测：与评分水平的相关 = -0.472；同一份作答整体 +1 档，S 从 0.2869 掉到 0.2082。
%
%   ---- 修正 ----
%   允许截距 d = a + b*u，a 吸收评分水平，等价于先中心化再拟合：
%       Au = dEi - mean(dEi);  Av = dVi - mean(dVi)
%       rho = sum(Au.*Av) / sqrt(sum(Au.^2)*sum(Av.^2))
%       S_c = sqrt(1 - rho^2)
%
%   这是 Kruskal stress-1 在"线性 + 截距"拟合、以总平方和为分母时的标准形式：
%       S_c = sqrt( sum(resid.^2) / sum(d.^2) ) = sqrt(1 - R^2)
%
%   ---- 性质 ----
%   * 与评分的绝对高低无关（对平移不再敏感）：同一份作答整体 +1 档，只有 0.0024 的变化。
%   * 与"用了几档"无关：相关系数对平移和缩放都不变，
%     所以"只用 3、4 两档乱按"不再能伪装成一致（该情形 rho≈0，S_c≈1）。
%   * 与先后顺序无关：对称。
%   * 0 = 完全一致；1 = 完全无一致性（随机作答基准）；>1 不可能。
%     若习惯旧的"随机约 0.7"刻度，可用 sqrt((1-rho)/2)，与 rho 单调关系相同，阈值可按 rho 换算。
%
%   ---- 新旧不可比 ----
%   旧版：2071 个结果文件均值 0.310，随机作答基准 0.345，与评分水平相关 -0.472。
%   新版：真实被试均值 0.918（p5 = 0.702，中位 0.965），随机作答基准 0.994，与评分水平相关 +0.175。
%   换算法后必须重新定阈值，绝不能把旧阈值（如 0.45）套到新值上。
%   判定建议直接用 info.rho（被试级 rho < 0.05 触发复核），S_c 只用于展示。
%
%   ---- 与原版的另一个差异（有意为之）----
%   原版比较的是 (第一次评分) 与 (两次平均)，"参考"里含着一部分待检数据；
%   当第二次评分几乎没有波动时，平均向量几乎就是第一次评分的平移缩放，S 会趋近 0，
%   看起来"最一致"。本版直接比较两次评分，对称，且该情形会正确地得到 rho≈0、S_c≈1。
%
%   输入:
%     file_path    - App 导出的结果 csv（label, imageName, score 三列）。
%                    文件尾部的 "File Created Time: ..." / "STRESS_intra: ..." 等
%                    元数据行会被自动忽略（原版靠 cell2mat 报错暴露这类文件）。
%
%   输出:
%     stress_value - 中心化 STRESS_intra；无法计算时为 NaN
%     info         - 诊断结构体:
%                      n_pair        参与计算的重复评分对数
%                      n_label       出现过的图片 label 数
%                      n_rows        有效评分行数
%                      rho           两次评分之间的 Pearson 相关（判阈值用这个）
%                      level         全部评分的均值（映射后 1..6 档）
%                      sd            全部评分的标准差（映射后 1..6 档）
%                      n_unique      用到的不同档位数
%                      note          无法计算的原因；正常为空字符串
%
%   自检:
%     [s, i] = cal_STRESS_ind_corrected('...\obs01_01.csv')
%     参考值（AF/f09i/obs_01/Preference，84 对）：s = 0.934220, i.rho = 0.356748
%
%   见 STRESS讨论.md §7

    stress_value = NaN;
    info = struct('n_pair', 0, 'n_label', 0, 'n_rows', 0, 'rho', NaN, ...
                  'level', NaN, 'sd', NaN, 'n_unique', 0, 'note', '');

    % ---- 路径：不依赖调用者的 cwd（原版用的是相对 "utils\"）----
    here = fileparts(mfilename('fullpath'));
    if isempty(here)
        here = pwd;
    end
    if exist('mapMatrixValues', 'file') ~= 2
        addpath(fullfile(here, '..', 'utils'));
    end

    % ---- 读入并按数值解析（容忍文件尾部的元数据行）----
    result = readtable(file_path);
    n_col = size(result, 2);
    if n_col < 3
        info.note = sprintf('列数不足 3 列（实际 %d 列）', n_col);
        return;
    end
    lab = str2double(string(result{:, 1}));
    sco = str2double(string(result{:, 3}));
    ok = ~isnan(lab) & ~isnan(sco);
    lab = lab(ok);
    sco = sco(ok);
    if isempty(lab)
        info.note = '没有可解析的评分行';
        return;
    end

    % ---- 分数映射 -3,-2,-1,1,2,3 -> 1..6，与 mapMatrixValues.m 一致 ----
    sco = mapMatrixValues(sco);

    % ---- 按 label 排序（sortrows 稳定，等价于 cal_STRESS_ind.m 第 25 行）----
    M = sortrows([lab, sco], 1);
    lab = M(:, 1);
    sco = M(:, 2);

    % ---- 每个 label 取前两次评分作为一个重复对 ----
    u = zeros(0, 1);
    v = zeros(0, 1);
    i0 = 1;
    n = numel(lab);
    n_label = 0;
    while i0 <= n
        j0 = i0;
        while j0 < n && lab(j0 + 1) == lab(i0)
            j0 = j0 + 1;
        end
        n_label = n_label + 1;
        if j0 > i0
            u(end + 1, 1) = sco(i0);      %#ok<AGROW>
            v(end + 1, 1) = sco(i0 + 1);  %#ok<AGROW>
        end
        i0 = j0 + 1;
    end

    info.n_pair   = numel(u);
    info.n_label  = n_label;
    info.n_rows   = n;
    info.level    = mean(sco);
    info.sd       = std(sco, 1);
    info.n_unique = numel(unique(sco));

    if info.n_pair < 2
        info.note = sprintf('重复评分对只有 %d 对，少于 2 对无法计算相关', info.n_pair);
        return;
    end

    % ---- 与 cal_STRESS_ind.m 第 54-55 行同样的映射，然后中心化 ----
    uu = (u - 1) / 5;          % repeat_score(:,2)
    vv = (v - 1) / 5;          % repeat_score(:,3)
    Au = uu - mean(uu);        % ← 新增：去截距
    Av = vv - mean(vv);        % ← 新增：去截距
    sU = sum(Au .^ 2);
    sV = sum(Av .^ 2);

    if sU == 0 || sV == 0
        % 原版在这里会给出 0（"看起来最一致"）或 NaN，都是假象：
        % 恒定作答 / 窄带平推根本没有可谈的一致性。
        if sU == 0 && sV == 0
            info.note = sprintf(['两次评分都没有任何变化（%d 对，唯一档位数 %d），', ...
                                 '一致性无定义：疑似恒定作答'], info.n_pair, info.n_unique);
        else
            info.note = sprintf(['其中一次评分没有任何变化（%d 对，唯一档位数 %d），', ...
                                 '一致性无定义'], info.n_pair, info.n_unique);
        end
        stress_value = NaN;
        return;
    end

    info.rho = sum(Au .* Av) / sqrt(sU * sV);
    stress_value = sqrt(max(0, 1 - info.rho ^ 2));
end
