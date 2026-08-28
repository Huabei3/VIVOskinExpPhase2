function [logicalIndex,bull_weight]=read_bull(bull,if_wei)
    sz=size(bull);
    if if_wei
        bull=double(bull)./255;
        if length(sz)==3
            bull_reshaped=reshape(bull, [sz(1)*sz(2),sz(3)]);
        elseif length(sz)==2
            bull_reshaped=reshape(bull, [sz(1)*sz(2),1]);
        end
        
    else
        if length(sz)==3
            bull_reshaped=reshape(bull, [sz(1)*sz(2),sz(3)])./255;
        elseif length(sz)==2
            bull_reshaped=reshape(bull, [sz(1)*sz(2),1])./255;
        end
        bull_reshaped = double(bull_reshaped);
        
        
    end
    logicalIndex = all(bull_reshaped == 0, 2);
    bull_weight=mean(bull_reshaped,2);
end