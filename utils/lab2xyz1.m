function[XYZ]=lab2xyz1(lab,white)
    l=lab(:,1);
    a=lab(:,2);
    b=lab(:,3);
    %光源色%
    %xn = light10(:,2).*cmf10(:,2);
    %yn = light10(:,2).*cmf10(:,3);
    %zn = light10(:,2).*cmf10(:,4);
    %kn = 100/sum(yn);
    %Xn = kn*sum(xn);
    %Yn = kn*sum(yn);
    %Zn = kn*sum(zn);
    
    %D65 参考白
    Xn = white(1);
    Yn = white(2);
    Zn = white(3);
    
    
    y=(l+16)/116;
    x=y+a/500;
    z=y-b/200;
    
    y=fa(y)*Yn;
    x=fa(x)*Xn;
    z=fa(z)*Zn;

    XYZ=[x,y,z];
 
   %点运算 