function lab_aft=CAT_lab2lab1(lab_bf,Dtype,CCT,direction)
    wd65_64 = [94.811, 100.00, 107.304];
    XYZw_pre = CCT2xyz(CCT);
    for i_input=1:size(lab_bf,1)    
        XYZ_bf(i_input, :) = lab2xyz2(lab_bf(i_input, :), 'd65_64');


        [CCT, duv, S_out] = xyz2CCT(XYZw_pre, 10);
        if strcmp(Dtype,'full')
            D=1;
        elseif strcmp(Dtype,'zhai')
            D = 0.723 * (1 - 1116 / CCT + 8.64 * duv - 49266 * duv / CCT); % zhai
        elseif strcmp(Dtype,'summer')
            D = 0.239 * 0.723 * (1 - 1116 / CCT); % summer
        elseif strcmp(Dtype,'OPPO')
            D = 0.00005 * CCT + 0.1977; % OPPO
        end
        if strcmp(direction,"fore")
            XYZ_aft(i_input, :) = CAT16_D(XYZ_bf(i_input, :),  wd65_64,XYZw_pre, D);
        elseif strcmp(direction,"back")
            XYZ_aft(i_input, :) = CAT16_D(XYZ_bf(i_input, :),  XYZw_pre,wd65_64, D);
        end

        lab_aft(i_input, :) = xyz2lab(XYZ_aft(i_input, :), 'd65_64');


    
    end


end