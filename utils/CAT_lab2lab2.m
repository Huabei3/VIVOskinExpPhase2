function lab_aft=CAT_lab2lab2(lab_bf,Dtype,CCT,direction,LA)
    wd65_64 = [94.811, 100.00, 107.304];
    XYZw_pre = CCT2xyz(CCT);
    if strcmp(direction,"fore")
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
            elseif strcmp(Dtype,'CAT16')
                F=0.8;
                D = F*(1-(1/3.6)*exp((-LA-42)/92));         
            end
            
            XYZ_aft(i_input, :) = CAT16_D(XYZ_bf(i_input, :),  wd65_64,XYZw_pre, D);
    
            lab_aft(i_input, :) = xyz2lab(XYZ_aft(i_input, :), 'd65_64');
    
        end
    elseif strcmp(direction,"back")
        for i_input=1:size(lab_bf,1)    
            XYZ_bf(i_input, :) = lab2xyz2(lab_bf(i_input, :), 'user',XYZw_pre);
    
    
            [CCT, duv, S_out] = xyz2CCT(XYZw_pre, 10);
            if strcmp(Dtype,'full')
                D=1;
            elseif strcmp(Dtype,'zhai')
                D = 0.723 * (1 - 1116 / CCT + 8.64 * duv - 49266 * duv / CCT); % zhai
            elseif strcmp(Dtype,'summer')
                D = 0.239 * 0.723 * (1 - 1116 / CCT); % summer
            elseif strcmp(Dtype,'OPPO')
                D = 0.00005 * CCT + 0.1977; % OPPO
            elseif strcmp(Dtype,'CAT16')
                F=0.8;
                D = F*(1-(1/3.6)*e((-LA-42)/92));         
            end
            
            XYZ_aft(i_input, :) = CAT16_D(XYZ_bf(i_input, :),  XYZw_pre,wd65_64, D);
    
            lab_aft(i_input, :) = xyz2lab(XYZ_aft(i_input, :), 'd65_64');
    
        end
    end


end