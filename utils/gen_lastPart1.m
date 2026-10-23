function [lastPart1, model1] = gen_lastPart1(lastPart)
    % 提取模型部分和最后一个字符
    model = lastPart(1:end-1);
    iOr = lastPart(end);
    
    % 使用 strrep 替换模型名称
    model1 = strrep(model, 'femalevivo', 'femaleVIVO');
    model1 = strrep(model1, 'malevivo', 'maleVIVO');
    
    % 如果未替换，保持原模型名称
    if strcmp(model1, model)
        model1 = model;
    end
    
    % 拼接 lastPart1
    lastPart1 = strcat(model1, iOr);
end

% function [lastPart1, model1] = gen_lastPart1(lastPart)
%     model = lastPart(1:end-1);
%     iOr = lastPart(end);
%     if strcmp(model, 'femalevivo')
%         model1 = 'femaleVIVO';
%     elseif strcmp(lastPart, 'malevivo')
%         model1 = 'maleVIVO';
%     else
%         model1 = model;
%     end
%     lastPart1 = strcat(model1, iOr);
% end