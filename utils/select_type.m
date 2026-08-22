function i_type= select_type(model)

    models{1,1}=["f01","f02","f03","m01","m02","m03"];
    models{2,1}=["f04","f05","f06","m04","m05","m06"];
    models{3,1}=["f07","f08","m07","m08"];
    models{4,1}=["f09","f10","m09","m10"];
    if ismember(model,models{1,1})
        i_type=1;
    elseif ismember(model,models{2,1})
        i_type=2;
    elseif ismember(model,models{3,1})
        i_type=3;
    elseif ismember(model,models{4,1})
        i_type=4;
    else
        error("model doesn't exist");
    end
end