function result=gog(x,xdata)
%xdata=[0:15:255]/255;
kg=x(1);
ko=x(2);
coef=x(3);
result=(kg*xdata+ko).^coef;
end