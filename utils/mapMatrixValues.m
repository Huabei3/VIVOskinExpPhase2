function mappedMatrix = mapMatrixValues(matrix)
    mappedMatrix = matrix;
    [rows, cols] = size(matrix);
    for i = 1:rows
        for j = 1:cols
            if matrix(i, j) == -3
                mappedMatrix(i, j) = 1;
            elseif matrix(i, j) == -2
                mappedMatrix(i, j) = 2;
            elseif matrix(i, j) == -1
                mappedMatrix(i, j) = 3;
            elseif matrix(i, j) == 1
                mappedMatrix(i, j) = 4;
            elseif matrix(i, j) == 2
                mappedMatrix(i, j) = 5;
            elseif matrix(i, j) == 3
                mappedMatrix(i, j) = 6;
            end
        end
    end
end