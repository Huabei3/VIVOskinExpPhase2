function XYZ = lut3d_rgb2xyz1(RGB,datai_file)

load(datai_file);

[m,j,k]=meshgrid(linspace(0,255,cubeL));

lutL=reshape(lablut(:,1),cubeL,cubeL,cubeL);
lutA=reshape(lablut(:,2),cubeL,cubeL,cubeL);
lutB=reshape(lablut(:,3),cubeL,cubeL,cubeL);

lout=interp3(m,j,k,lutL,RGB(:,1),RGB(:,2),RGB(:,3),method);
aout=interp3(m,j,k,lutA,RGB(:,1),RGB(:,2),RGB(:,3),method);
bout=interp3(m,j,k,lutB,RGB(:,1),RGB(:,2),RGB(:,3),method);

P=[lout aout bout];

XYZ = lab2xyz2( P,'user',XYZw);
% XYZ = lab2xyz1( P,XYZw);
% XYZ = lab2xyz( lout,aout,bout,XYZw);
end