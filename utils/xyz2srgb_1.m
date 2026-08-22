function [RGB, flag,outofgamut]=xyz2srgb1(XYZ)
% XYZ2SRGB: calculates IEC:61966 sRGB values from XYZ
%
%   Colour Engineering Toolbox
%   author:    ? Phil Green
%   version:   1.1
%   date:  	   17-01-2001
%   book:      http://www.wileyeurope.com/WileyCDA/WileyTitle/productCd-0471486884.html
%   web:       http://www.digitalcolour.org

% define 3x3 matrix
M =[3.2406,-1.5372,-0.4986
-0.9689,1.8758,0.0415
0.0557,-0.2040,1.0570];

if ischar(XYZ)
   xyz=dlmread(XYZ,'\t');
elseif isnumeric(XYZ)
   xyz=XYZ;
else
   error('No valid input data')
end

sRGB=(M*(xyz./100)')';

channel = sRGB>1 | sRGB<0;
outofgamut = sum(channel(:, 1) | channel(:, 2) | channel(:, 3))/length(sRGB(:, 1));
if(outofgamut ~= 0)
    flag = 1;
    disp('---------------------WARNING-----------------------');
    disp('The pecenta of pixel which is out of display gamut:');
    disp(num2str(outofgamut));       
    disp('---------------------------------------------------');
else
    flag = 0;
end


sRGB(sRGB<0) = 0;
sRGB(sRGB>1) = 1;

sR=sRGB(:, 1);sG=sRGB(:, 2);sB=sRGB(:, 3);
% test for the dark colours in the non-linear part of the function
j=find(sR<=0.0031308);
k=find(sG<=0.0031308);
l=find(sB<=0.0031308);

%apply gamma function
g=1/2.4;
%
% scale to range 0-255
R=(1.055*sR.^g-0.055);
G=(1.055*sG.^g-0.055);
B=(1.055*sB.^g-0.055);
   %non-linear bit for dark colours
R(j)=(sR(j)*12.92);
G(k)=(sG(k)*12.92);
B(l)=(sB(l)*12.92);


% clip to range

RGB=[R,G,B];

