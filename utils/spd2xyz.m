function [XYZ,XYZw]=spd2xyz(spddata, obs, AorR,rfldata)
% Calculate XYZ from source spectrum (and reflectance spectrum)
% Input:
% 	spddata = filename or matrixname of SPD data
% 	obs 	= 2 or 10 for resp. 2° (1931) or 10° (1964) CIE standard observers
%    		= 1931 or 1964 for resp. 2° (1931) or 10° (1964) CIE standard observers
%    		= 200602 or 200610 (or 2006) for resp. CIE2006 2° or 10° standard observers
% 	AorR 	= absolute (1) or relative tristimulus values (default = 1), 
% 	rfldata = filename or matrixname of reflectance data (0: calculate XYZ of SPD, not SPD.*RFL)
%
% Output
%	XYZ  = tristimulus values of spddata if rfldata = 0 (or not given as input)
%		 = tristimulus values of rfldata illuminated by spddata (dim 1: rfldata varies, dim 3: spddata varies)
%	XYZw = tristimulus values of spddata (dim 1: spddata varies)
%
% author:    © K. Smet
% version: 1.2
%   v1.0: date: June, 2008
% 	v1.1: date: May 15, 2013
%   v1.2: date: March 15, 2014: correction to wavelengthstep (for irregular spacing)
% 	v1.3: date: May 5, 2015: Possibility to enter multiple SPDs as input at once
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if nargin<2;obs=2;AorR=1;rfldata=0;;end
if nargin<3;AorR=1;rfldata=0;end
if nargin<4;rfldata=0;end

%read colour matching functions
[cmf,k]=selectcmf(obs);

%if data is file then read file else data is matlab matrix
if ischar(spddata) == 1  
    spd = dlmread(spddata);
else
    spd = spddata;
end

spd=spd(spd(:,1)>=360 & spd(:,1)<=830,:);


lambdas=spd(:,1);

%create delta_wavelength vector for use in summation-integral
d=diff(lambdas);
d1=[d(1);d(1:end-1)./2;d(end)];
d2=[0;d(2:end)./2;0];
dl=(d1+d2);
spd=spd(:,2:end);


%to save calculation time only perform interpolation when necessary
if abs(dl(1)-dl(2))==abs(mean(dl)) & (((dl(1)==5) | (dl(1)==1) | (dl(1)==2)) & ((lambdas(1,1)==380) | (lambdas(1,1)==360)) & ((lambdas(end,1)==780) | (lambdas(end,1)==830)));
%if (((dl(1)==5) | (dl(1)==1) | (dl(1)==2)) & ((lambdas(1,1)==380) | (lambdas(1,1)==360)) & ((lambdas(end,1)==780) | (lambdas(end,1)==830)));
    cmf=cmf(1:dl(1):end,2:end);
    if lambdas(1,1)==380;cmf=cmf(20/dl(1)+1:end-50/dl(1),:);end;%for 380:780 nm data
else
    for i=1:3;cmf_(:,i)=CIEinterp(cmf(:,1),cmf(:,i+1),lambdas,'linear');end;cmf=cmf_;clear cmf_;
end
    

%Relative or absolute tristimulus values?
if AorR==0
        k=100./sum(spd.*repmat(cmf(:,2).*dl,1,size(spd,2))); %relative tristimulus
else
		k=k.*ones(size(spd,2));
end

%surface color or object color? 
if rfldata(1,1)~=0 %=surface color
    %if data is file then read file else data is matlab matrix
    if ischar(rfldata) == 1  
        rfl=convertspdformat(rfldata);
        rfl = dlmread(rfldata);
    else
        rfl = rfldata;
    end

    if size(rfl,1)==size(lambdas,1);
	if (sum(abs(rfl(:,1)-lambdas)<1e-6)==size(lambdas,1));interpolaterfls=0;else;interpolaterfls=1;end;else;interpolaterfls=1;end%check if rfl interpolation is necessary
    if interpolaterfls==1;
        for i=1:size(rfl,2)-1;
            rfl_(:,i)=CIEinterp(rfl(:,1),rfl(:,i+1),lambdas,'linear'); 
        end
    else
        rfl_=rfl(:,2:end);
    end
    rfl=rfl_;clear rfl_;
    
    if AorR==0
        k=100./sum(spd.*repmat(cmf(:,2).*dl,1,size(spd,2))); %relative tristimulus
    else
        k=k;%do nothing, keep value set earlier for absolute values
    end
else %=selfluminous color
    rfl=ones(1,size(spd,1))';
end

XYZ=nan(size(rfl,2),3);
%for i=1:size(rfl,2);
%    XYZ(i,:)=k*[sum(spd.*rfl(:,i).*cmf(:,1).*dl),sum(spd.*rfl(:,i).*cmf(:,2).*dl),sum(spd.*rfl(:,i).*cmf(:,3).*dl)];
%end
%XYZw=k*[sum(spd.*cmf(:,1).*dl),sum(spd.*cmf(:,2).*dl),sum(spd.*cmf(:,3).*dl)];
for j=1:size(spd,2);
    XYZ(:,:,j)=k(j).*[sum(repmat(spd(:,j).*cmf(:,1).*dl,1,size(rfl,2)).*rfl);sum(repmat(spd(:,j).*cmf(:,2).*dl,1,size(rfl,2)).*rfl);sum(repmat(spd(:,j).*cmf(:,3).*dl,1,size(rfl,2)).*rfl)]';
    XYZw(j,:)=k(j).*[sum(spd(:,j).*cmf(:,1).*dl),sum(spd(:,j).*cmf(:,2).*dl),sum(spd(:,j).*cmf(:,3).*dl)];
end
if rfldata==0;
    XYZ = permute(XYZ,[3,2,1]);
end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function X=neg2zero(X)
X=(X+X.*sign(X))/2;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function Ynew=CIEinterp(X,Y,Xnew,type,extrap);
% 1-D interpolation (table lookup) with all negative values set to 0!
% Extrapolate if necessary: if extrapolation produces impossible results,
% set to closest old value.
%
%     YI = INTERP1(X,Y,XI) interpolates to find YI, the values of
%     the underlying function Y at the points in the vector, or array XI. X
%     must be a vector of length N, and SIZE(Y,1) must be N.  If Y is an array
%     of size [N,M1,M2,...,Mk] then the interpolation is performed for 
%     each M1-by-M2-by-...-Mk value in Y.  If XI is an array of size
%     [D1,D2,...,Dj], then YI will be of size [D1,D2,...,Dj,M1,M2,...,Mk].
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if nargin<5;extrap=1;end
if nargin <4; extrap=1;type='v5cubic';end
switch type
    case 'none'
    case 'lagrange'
        Ynew=Lagrange(X,Y,Xnew);
    case 'sprague';
        Ynew=sprague(X,Y,Xnew);
        if isnan(Ynew);Ynew = (interp1(X,Y,Xnew,'v5cubic'));end
    otherwise
        Ynew = (interp1(X,Y,Xnew,type));
end
%extrapolate beyond begin and end boundary;
switch extrap
    case 0
        if sum(Ynew(Xnew<X(1))>0) | sum(isnan(Ynew(Xnew<X(1)))); Ynew(Xnew<X(1))=0;end %if extrapolation produces impossible results, set to closest old value.
        if sum(Ynew(Xnew>X(end))>0) | sum(isnan(Ynew(Xnew>X(end))));Ynew(Xnew>X(end))=0;end %if extrapolation produces impossible results, set to closest old value.
    case 1
        if sum(Ynew(Xnew<X(1))>0) | sum(isnan(Ynew(Xnew<X(1)))); Ynew(Xnew<X(1))=Y(1);end %if extrapolation produces impossible results, set to closest old value.
        if sum(Ynew(Xnew>X(end))>0) | sum(isnan(Ynew(Xnew>X(end))));Ynew(Xnew>X(end))=Y(end);end %if extrapolation produces impossible results, set to closest old value.
        
end
Ynew=neg2zero(Ynew);
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function data=convertspdformat(filename)
%convert komma decimal numbers to point decimal numbers
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
datastring=textread(filename,'%s');
chardatastring=char(datastring);
kommapos=find(chardatastring==',');
chardatastring(kommapos)='.';
data=str2double(cellstr(chardatastring));
lendata=length(data);
positions=(1:lendata);
oddn=find(mod(positions,2)~=0);
evenn=find(mod(positions,2)==0);
lamb=data(oddn);
spdy=data(evenn);
data=[lamb,spdy];
format long
dlmwrite(filename,data,'delimiter','\t','precision','%.12g');
end