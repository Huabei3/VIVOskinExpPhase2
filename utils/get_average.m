function [average]=get_average(lab,bull,if_wei)
    [logicalIndex,bull_weight]=read_bull(bull,if_wei);
    if if_wei
        average=sum(lab.*bull_weight)./sum(bull_weight);
    else
        average=mean(lab(~logicalIndex, :));
    end
    
end