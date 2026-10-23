function degree = atan2d_360(y, x)
    degree = atan2d(y, x);
    if degree < 0
        degree = degree + 360;
    end
end