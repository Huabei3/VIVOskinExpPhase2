function D = calculateD(CCT, duv, Dtype,E)
    % 输入参数：
    %   CCT - 一个列向量，表示色温（单位：K）
    %   duv - 一个列向量，表示色温对应的duv值
    %   Dtype - 字符串，表示计算D的类型（'OPPO', 'summer', 'zhai', 'VIVO_quadra'）
    % 输出：
    %   D - 计算后的D值，与CCT和duv的大小相同

    % 初始化D
    if contains(Dtype, "CAT16")||contains(Dtype, "cherry")
        D = zeros(size(CCT));
        F=0.8;
        omega=2*pi*(1-cos(pi/36));
        S=0.0124; %164.07*75.57*(10^(-6))
        LA=E./S.*omega;
    end

    % 根据Dtype计算D
    if strcmp(Dtype, "OPPO")
        D = 0.00005 * CCT + 0.1977;
    elseif strcmp(Dtype, "summer")
        D = 0.239 * 0.723 * (1 - 1116 ./ CCT);
    elseif strcmp(Dtype, 'zhai')
        D = 0.723 * (1 - 1116 ./ CCT + 8.64 * duv - 49266 * duv ./ CCT);
    elseif strcmp(Dtype, 'cherry_500')
        a=[0.21, 2165.79, 70.44, -165338, 0.97];
        D=a(1).*(1-a(2)./CCT+a(3).*duv-(a(4).*duv)./CCT).*log(500);
    elseif strcmp(Dtype, 'cherry_1000')
        a=[0.21, 2165.79, 70.44, -165338, 0.97];
        D=a(1).*(1-a(2)./CCT+a(3).*duv-(a(4).*duv)./CCT).*log(1000);
    elseif strcmp(Dtype, 'grace')
        D=0.424*(1-2383/CCT);
    elseif strcmp(Dtype, 'zhai_adjusted')
        D = 1.4214*0.723 * (1 - 1116 ./ CCT + 8.46 * duv - 49266 * duv ./ CCT);        
    elseif strcmp(Dtype, 'VIVO_summer')
        a = [-3.35279606378243e-08, 0.000173542463734851, 0.498076343205087];        
        D(CCT <= 6500) = a(1) * CCT(CCT <= 6500).^2 + a(2) * CCT(CCT <= 6500) + a(3);
        D(CCT > 6500) =  0.239 * 0.723 * (1 - 1116 ./ CCT(CCT > 6500));
    elseif strcmp(Dtype, 'VIVO_zhai_adjusted')
        a = [-3.35279606378243e-08, 0.000173542463734851, 0.498076343205087];        
        D(CCT <= 6500) = 1.2*a(1) * CCT(CCT <= 6500).^2 + a(2) * CCT(CCT <= 6500) + a(3);
        D(CCT > 6500) = 1.5* 0.723 * (1 - 1116 ./ CCT + 8.64 * duv - 49266 * duv ./ CCT);
    elseif strcmp(Dtype,'VIVO_CAT16')
        a = [-3.35279606378243e-08, 0.000173542463734851, 0.498076343205087];  

        D(CCT <= 6500) = a(1) * CCT(CCT <= 6500).^2 + a(2) * CCT(CCT <= 6500) + a(3);
        D(CCT > 6500) = F*(1-(1/3.6)*exp((-LA-42)/92));      %0.797797968820369
    elseif strcmp(Dtype,'VIVO_spl')
        % a=[5769.31948248233	6000.01046360996	0.710373884951729	-3.74809458460063e-05	-0.000975692292996272	0.000158186564369972];
        a=[5864.68184873231	6424.65446832581	0.756335298614682	-3.57368165883954e-05	-9.51547570889123e-06	-4.31764202863304e-05];
        D = (CCT <= a(1)) .* (a(3) + a(4)*(CCT - a(1))) + ...
            (CCT > a(1) & CCT <= a(2)) .* (a(3) + a(5)*(CCT - a(1))) + ...
            (CCT > a(2)) .* ((a(3) + a(5)*(a(2) - a(1))) + a(6)*(CCT - a(2)));
    elseif strcmp(Dtype,'VIVO_spl1')
        % a=[5582.69737014086	6639.86595644568	0.584107857806001	6.12895499242687e-05	-0.000684323461666446	0.00153576875507769];     
        a=[5302.28305889350	6000.00044843000	0.626906158523734	7.78090444996742e-06	-0.000332693467326350	0.000110186039154159];%pinjie
        D = (CCT <= a(1)) .* (a(3) + a(4)*(CCT - a(1))) + ...
            (CCT > a(1) & CCT <= a(2)) .* (a(3) + a(5)*(CCT - a(1))) + ...
            (CCT > a(2)) .* ((a(3) + a(5)*(a(2) - a(1))) + a(6)*(CCT - a(2)));
    elseif strcmp(Dtype,'poly4')
        a=[-3.057e-15,8.012e-11,-7.244e-07,0.002637,-2.45];
        D=a(1)*CCT^4 + a(2)*CCT^3 + a(3)*CCT^2 + a(4)*CCT + a(5);
    elseif strcmp(Dtype,'poly3')
        % a=[5.256e-11,-7.75e-07,0.003426,-3.852];
        % a=[3.418e-12,-5.013e-08,0.0001658,0.7822];%灰卡2色温拟合
        a=[4.006e-12,-5.797e-08,0.000197, 0.7375];%灰卡4CCTest色温拟合
        % a=[3.584e-12,-4.916e-08,0.0001413,0.8407];%灰卡4Kang2002色温拟合
        D = a(1)*CCT^3 + a(2)*CCT^2 + a(3)*CCT + a(4);
    elseif strcmp(Dtype,'lfit_h')
        a=[0.7922,-0.6400];
        D=a(1)+a(2).*1116./CCT;
    elseif strcmp(Dtype,'efit2')||strcmp(Dtype,'efit2_r1')
        % a=[0.926189, 500.086250];
        a=[0.9015  500.0089];
        D=a(1).*(1-a(2)./CCT);
    elseif strcmp(Dtype,'efit_p')
        a=[0.9193 500.1675];
        D=a(1).*(1-a(2)./CCT);
    elseif strcmp(Dtype,'efit_p_free')
        a=[1.01780267638662	1266.44481974440];
        D=a(1).*(1-a(2)./CCT);
    elseif strcmp(Dtype,'efit3')
        a=[0.791341, 500.133713, 0.331317];
        D=(a(1)-a(2)./CCT).*a(3).*ln(LA);
    elseif strcmp(Dtype,'VIVO_pchip')
        load("optmizedD\allD_pchip.mat","f_pchip");
        D=f_pchip(CCT);
    elseif strcmp(Dtype,'CAT16')
        F=0.8;
        omega=2*pi*(1-cos(pi/36));
        S=0.0124; %164.07*75.57*(10^(-6))
        LA=E./S.*omega;
        D = F*(1-(1/3.6)*exp((-LA-42)/92));      %0.797797968820369

    elseif strcmp(Dtype, 'full')
        D=1;
    elseif strcmp(Dtype, 'noCAT')
        D=0;

    else
        error('unknown Dtype');
    end
    D=min(D,1);
end