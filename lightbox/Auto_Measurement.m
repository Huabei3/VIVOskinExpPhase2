clc
clear all

meas = 22;

for i = 1:meas

    disp('Processing....!');
    %---------------------------------------
    MaxT = 50; % Maximum time (secs) per measurement

    [flag, time, fRadio, fPhoto,fX,fY,fZ,fChromx,fChromy,fChromx10,fChromy10,...
        fChromu,fChromv,fChromu_,fChromv_, fDuv, fDWL, fPE, dwCCT, DC, Ra,...
        R1_15, fSpRad] = Measurement(MaxT);
    %---------------------------------------
    %~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ write your code here~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

    pause(1)
    datestr(now,30)

    if exist('VIVO-SKIN-20240925.mat','file')
        load VIVO-SKIN-20240925.mat;
    else
        DATAs = cell(1,11);
    end

    DATAs(end+1,:)={datestr(now,30),time,fX,fY,fZ,fDWL,fDuv,dwCCT,Ra,R1_15,fSpRad};
    save('VIVO-SKIN-20240925.mat','DATAs')
    disp('============data saved============');


    if flag==0
        disp('Measurement could not complete in given time....., Status-Flag=0')
    else
        Measurement_time = time;
        CCT=dwCCT
        Luminance=fY
    end

%     pause(120)

end
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ End ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

