function LCh=lab2lch(Lab)
%LAB2LCH: Converts Cartesian CIELAB to polar LCh
%
%   Colour Engineering Toolbox
%   author:    © Phil Green
%   version:   1.2
%   date:  	   17-01-2004
%   book:      http://www.wileyeurope.com/WileyCDA/WileyTitle/productCd-0471486884.html
%   web:       http://www.digitalcolour.org

L=Lab(:,1);a=Lab(:,2);b=Lab(:,3);
C=(a.^2+b.^2).^(1/2);
h=hue_angle(a,b);

LCh=[L,C,h];