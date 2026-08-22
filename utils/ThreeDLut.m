classdef ThreeDLut
    properties
        cube_size
        inter_cube_size = 41
        csv_filename
        lut
        rgb_values
        white_point
        P
        rgb
        rgb_end = [191, 223, 191, 223, 159, 255]
    end

    methods
        function obj = ThreeDLut(cube_size, csv_filename)
            obj.cube_size = cube_size;
            obj.csv_filename = csv_filename;
        end

        function obj = load_lut(obj)
            xyz_data = csvread(obj.csv_filename);
            obj.white_point = xyz_data(end, 1:3);
            obj.lut = obj.xyz_to_cielab(xyz_data(:, 1:3), obj.white_point);
        end

        function lab = xyz_to_cielab(~, xyz, white_point)
            xyz_scaled = bsxfun(@rdivide, xyz, white_point);

            f = @(t) (t > (6/29)^3) .* t.^(1/3) + (t <= (6/29)^3) .* (t / (3 * (6/29)^2) + 4/29);

            xyz_f = f(xyz_scaled);
            L = 116 * xyz_f(:, 2) - 16;
            a = 500 * (xyz_f(:, 1) - xyz_f(:, 2));
            b = 200 * (xyz_f(:, 2) - xyz_f(:, 3));
            lab = [L, a, b];
        end

        function obj = generate_rgb_plab(obj)
            single_channel = round(linspace(0, 255, obj.inter_cube_size));
            [r, g, b] = ndgrid(single_channel, single_channel, single_channel);
            rgb = [r(:), g(:), b(:)];

            obj.rgb_values = rgb;
            P = obj.interpolate_lut3d(r, g, b, 'linear');
            obj.P = reshape(P, [], 3);
            obj.rgb = rgb;
        end

        function P = interpolate_lut3d(obj, r, g, b, method)
            X = reshape(obj.lut(:, 1), obj.cube_size, obj.cube_size, obj.cube_size);
            Y = reshape(obj.lut(:, 2), obj.cube_size, obj.cube_size, obj.cube_size);
            Z = reshape(obj.lut(:, 3), obj.cube_size, obj.cube_size, obj.cube_size);

            grid_points = linspace(0, 255, obj.cube_size);

            interp_funcX = griddedInterpolant({grid_points, grid_points, grid_points}, X, method);
            interp_funcY = griddedInterpolant({grid_points, grid_points, grid_points}, Y, method);
            interp_funcZ = griddedInterpolant({grid_points, grid_points, grid_points}, Z, method);

            points = cat(4, r, g, b);
            points = reshape(points, [], 3);

            x = interp_funcX(points);
            y = interp_funcY(points);
            z = interp_funcZ(points);

            P = [x, y, z];
        end

        function xyz = lab_to_xyz(~, lab, white_point)
            inverse_f = @(t) ((t > 6/29) .* (t .^ 3) + (t <= 6/29) .* (3 * (6/29)^2 * (t - 4/29)));

            fY = (lab(:, 1) + 16) / 116;
            fX = lab(:, 2) / 500 + fY;
            fZ = fY - lab(:, 3) / 200;

            X = inverse_f(fX) * white_point(1);
            Y = inverse_f(fY) * white_point(2);
            Z = inverse_f(fZ) * white_point(3);
            xyz = [X, Y, Z];
        end

        function rgb = lut3d_xyz_to_rgb(obj, xyz)
            lab = obj.xyz_to_cielab(xyz, obj.white_point);
            de = obj.calculate_color_difference(lab, obj.P);
            [~, min_de_idx] = min(de, [], 2);
            rgb = obj.rgb(min_de_idx, :);

            rgb = max(0, min(255, rgb));
        end
    end

    methods (Static)
        function de = calculate_color_difference(lab, p_labs)
            num_colors = size(lab, 1);
            num_lab = size(p_labs, 1);
            de = zeros(num_colors, num_lab);
            for i = 1:num_colors
                for j = 1:num_lab
                    de(i, j) = sqrt(sum((lab(i, :) - p_labs(j, :)).^2));
                end
            end
        end
    end
end
