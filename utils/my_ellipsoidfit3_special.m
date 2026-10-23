function [par,r,y] = my_ellipsoidfit3_special(cielab,zscore,mean_cen,lastPart,i_group,colorcenter)
% cielab should be m*3 matrix
% zscore should be m*1 vector

% if color center is preset, it will be fixed and not be optimized.
% output: par = [k1,k2,k3,k4,l0,a0,b0,k5,k6]
if nargin < 10
    xdata = cielab;
    ydata = zscore;
    
    f = @(a,xdata)(1./(1+a(6)*exp(sqrt(a(1)*(xdata(:,2)-a(4)).^2+a(2)*(xdata(:,3)-a(5)).^2 ...
        +a(3)*(xdata(:,2)-a(4)).*(xdata(:,3)-a(5))))))...
    .*((a(1)*(xdata(:,2)-a(4)).^2+a(2)*(xdata(:,3)-a(5)).^2+ ...
    a(3)*(xdata(:,2)-a(4)).*(xdata(:,3)-a(5)))>=0);

    
    rmax = -inf;

    for t = 1:100
        a0 = [rand,rand,rand,rand,rand,rand];
        options = optimset('MaxFunEvals',200000);
        if ismember(i_group,[15])
            a = lsqcurvefit(f,a0,xdata,ydata, ...
                [0,0.02,-inf,mean_cen(2),mean_cen(3),0], ...
                [inf,inf,inf,mean_cen(2),mean_cen(3),1],options);
        else
            a = lsqcurvefit(f,a0,xdata,ydata, ...
                [0,0,-inf,mean_cen(2),mean_cen(3),0], ...
                [inf,inf,inf,mean_cen(2),mean_cen(3),1],options);
        end

        
        y = (1./(1+a(6)*exp(sqrt(a(1)*(xdata(:,2)-a(4)).^2+a(2)*(xdata(:,3)-a(5)).^2+ ...
            a(3)*(xdata(:,2)-a(4)).*(xdata(:,3)-a(5)))))).*((a(1)*(xdata(:,2)-a(4)).^2+ ...
            a(2)*(xdata(:,3)-a(5)).^2+a(3)*(xdata(:,2)-a(4)).*(xdata(:,3)-a(5)))>=0);
   
        r = corr(y,ydata);
        if r >= rmax
            rmax = r;
            afinal = a;
        end
        if rmax>0.9
            break
        end
    end

    par = afinal;
    a = afinal;
    y  =(1./(1+a(6)*exp(sqrt(a(1)*(xdata(:,2)-a(4)).^2+a(2)*(xdata(:,3)-a(5)).^2+ ...
        a(3)*(xdata(:,2)-a(4)).*(xdata(:,3)-a(5)))))).*((a(1)*(xdata(:,2)-a(4)).^2+ ...
        a(2)*(xdata(:,3)-a(5)).^2+a(3)*(xdata(:,2)-a(4)).*(xdata(:,3)-a(5)))>=0);
%    scatter(ydata,y);
    r = corr(y,ydata);
%绘制拟合结果
    % scatter(ydata, y);
    % xlabel('True Probability');
    % ylabel('Predicted Probability');
    % title('Fitting Result');

    fprintf('corralation coefficient is %.2f\n',r);
    
else
    xdata = cielab;
    ydata = zscore;

    f = @(a,xdata)(a(8)*exp(a(1)*sqrt((xdata(:,1)-colorcenter(1)).^2+a(2)*(xdata(:,2)-colorcenter(2)).^2+a(3)*(xdata(:,3)-colorcenter(3)).^2+a(4)*(xdata(:,2)-colorcenter(2)).*(xdata(:,3)-colorcenter(3))))+a(9)).*(((xdata(:,1)-colorcenter(1)).^2+a(2)*(xdata(:,2)-colorcenter(2)).^2+a(3)*(xdata(:,3)-colorcenter(3)).^2+a(4)*(xdata(:,2)-colorcenter(2)).*(xdata(:,3)-colorcenter(3)))>=0);
    rmax = 0;

    for t = 1:100
        a0 = [-rand,rand,rand,rand,rand,rand,rand,rand,rand];
        options = optimset('MaxFunEvals',200000);
        a = lsqcurvefit(f,a0,xdata,ydata,[-inf,0,0,-inf,-inf,-inf,-inf,-inf,-inf], ...
            [inf,inf,inf,inf,inf,inf,inf,inf,inf],options);
        y = (a(8)*exp(a(1)*sqrt((xdata(:,1)-colorcenter(1)).^2+a(2)*(xdata(:,2)-colorcenter(2)) ...
        .^2+a(3)*(xdata(:,3)-colorcenter(3)).^2+a(4)*(xdata(:,2)-colorcenter(2)).* ...
        (xdata(:,3)-colorcenter(3))))+a(9)).*(((xdata(:,1)-colorcenter(1)).^2+a(2)* ...
        (xdata(:,2)-colorcenter(2)).^2+a(3)*(xdata(:,3)-colorcenter(3)).^2+a(4)* ...
        (xdata(:,2)-colorcenter(2)).*(xdata(:,3)-colorcenter(3)))>=0);

        r = corr(y,ydata);
        if r >= rmax
            rmax = r;
            afinal = a;
        end
    end

    par = afinal;
    par(5:7) = colorcenter;
    a = afinal;
    y = (a(8)*exp(a(1)*sqrt((xdata(:,1)-colorcenter(1)).^2+a(2)*(xdata(:,2)-colorcenter(2)).^2 ...
        +a(3)*(xdata(:,3)-colorcenter(3)).^2+a(4)*(xdata(:,2)-colorcenter(2)) ...
        .*(xdata(:,3)-colorcenter(3))))+a(9)).*(((xdata(:,1)-colorcenter(1)).^2+a(2)* ...
        (xdata(:,2)-colorcenter(2)).^2+a(3)*(xdata(:,3)-colorcenter(3)).^2+a(4)*...
        (xdata(:,2)-colorcenter(2)).*(xdata(:,3)-colorcenter(3)))>=0);
    scatter(y,ydata);
    r = corr(y,ydata);
    fprintf('corralation coefficient is %.2f\n',r);
end
end