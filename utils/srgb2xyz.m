function XYZ=srgb2xyz(RGB)
% sRGB2XYZ: calculates XYZ tristimulus values from IEC:61966 sRGB
%
%   Colour Engineering Toolbox
%   author:    ? Phil Green
%   version:   1.1
%   date:  	   17-01-2001
%   book:      http://www.wileyeurope.com/WileyCDA/WileyTitle/productCd-0471486884.html
%   web:       http://www.digitalcolour.org
% RGB 0-255
% define 3x3 matrix
M =[0.4124,0.3576,0.1805
0.2126,0.7152,0.0722
0.0193,0.1192,0.9505];

if ischar(RGB)
   rgb=dlmread(RGB,'\t');
elseif isnumeric(RGB)
   rgb=RGB;
else
   error('No valid input data')
end

%scale device coordinates 
sR=rgb(:,1);
sG=rgb(:,2);
sB=rgb(:,3);

%test for non-linear part of conversion
i=find(sR<=0.04045);j=find(sG<=0.04045);k=find(sB<=0.04045);

%apply gamma function to convert to sRGB
sr=((sR+0.055)./1.055).^2.4;
sg=((sG+0.055)./1.055).^2.4;
sb=((sB+0.055)./1.055).^2.4;

sr(i)=sR(i)./12.92;
sg(j)=sG(j)./12.92;
sb(k)=sB(k)./12.92;
sRGB=[sr,sg,sb];

XYZ=(M*sRGB')'.*100;






