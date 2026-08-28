function RGB =  lab2rgb_3dlut(Lab,P_lab,rgb);
%% Input ： Lab 需要对应的Lab值 有1x3，也就是三个维度
%% Parameter： P_lab 27000 x 3 的 Lut表，需要对应Lab
%% Parameter   rgb   27000 x 3 的 Lut表，对应P_Lab
%% Output : RGB 输出对应的RGB
    Lab_extend = repmat(Lab,size(P_lab,1),1);%% repmat 复制和P_lab一样维度的Input
    De = cielabde(Lab_extend,P_lab);%% 计算Lab和P_lab的距离
    De_sort = sortrows([P_lab,rgb,De],7);%% 按照距离进行排序
%     Sum = sqrt(sum(De_sort(1:15,7).^2));
    RGB = geomean(De_sort(1:15,4:6)); %% 使用几何均值得到结果
end