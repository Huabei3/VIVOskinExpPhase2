% ===================================================
% *** FUNCTION xyz2lab
% ***
% *** function [lab] = xyz2lab(xyz, obs, xyzw)
% *** computes LAB from XYZ 
% *** xyz is an n by 3 matrix 
% *** e.g. set obs to 'd65_64 for D65 and 1964
% *** set obs to 'user' to use optional argument   
% *** xyzw as the white point
% ===================================================
function [lab] = xyz2lab(xyz,obs,white)
 
if (size(xyz,2)~=3)
   disp('xyz must be n by 3'); return;   
end
lab = zeros(size(xyz,1),size(xyz,2));

if strcmp('We',obs)
    white=[100.00 100.00 100.00];
elseif strcmp('d65_31', obs)
    white=[95.047 100.00 108.883];
elseif strcmp('d65_64', obs)
    white=[94.813  100.000  107.262];
elseif strcmp('user', obs)
    white=white;
else
   disp('unknown option obs');return;
end

lab = zeros(size(xyz,1),3);  

fx = zeros(size(xyz,1),3);
for i=1:3
    index = (xyz(:,i)/white(i) > (6/29)^3);
    fx(:,i) = fx(:,i) + index.*(xyz(:,i)/white(i)).^(1/3);   
    fx(:,i) = fx(:,i) + (1-index).*((841/108)*(xyz(:,i)/white(i)) + 4/29);   
end

lab(:,1)=116*fx(:,2)-16;
lab(:,2) = 500*(fx(:,1)-fx(:,2));
lab(:,3) = 200*(fx(:,2)-fx(:,3));

end
% ====================================================
% *** END FUNCTION xyz2lab
% ====================================================















