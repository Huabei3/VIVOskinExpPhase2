function xdata=gog_r(x,ydata)
kg=x(1);
ko=x(2);
coef=x(3);
xdata=(ydata.^(1/coef)-ko)./kg;
end