function XYZ = CCT2xyz( CCT, Duv, cieob, Y, deltaT )

if nargin < 2; Duv = 0; end
if nargin < 3; cieob = 2; end
if nargin < 4; Y = 100; end
if nargin < 5; deltaT=0.01; end

BB0spd = blackbodySPD(CCT);
BB1spd = blackbodySPD(CCT+abs(deltaT));

BB0xyz=XYZcal(BB0spd,1,cieob);
BB1xyz=XYZcal(BB1spd,1,cieob);

upvpY0=xyz2uvY(BB0xyz);
upvpY1=xyz2uvY(BB1xyz);

u0=upvpY0(:,1);v0=(2/3).*upvpY0(:,2);
u1=upvpY1(:,1);v1=(2/3).*upvpY1(:,2);

du=u0-u1;
dv=v0-v1;
duv=(du^2+dv^2)^0.5;

Du=Duv*(dv/duv);
Dv=Duv*(du/duv);

u=u0-Du;
v=v0+Dv;

upvp=[u,(3/2)*v];
XYZ=uvY2xyz([upvp,Y]);
end

