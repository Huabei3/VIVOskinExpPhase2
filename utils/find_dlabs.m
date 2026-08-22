close all; 
clc;       
clear;     

%%
files = dir('Z:\homes\Peggy\VIVOskinExpe\Hassel_downsampled\HD65\cropped\CardMasked\*.jpg');  % 读取文件夹中的所有.jpg文件
dir_maskUp=dir("Z:\homes\Peggy\VIVOskinExpe\Hassel_downsampled\HD65\cropped\CardMasked\mask_up\*.jpg");
dir_maskDown=dir("Z:\homes\Peggy\VIVOskinExpe\Hassel_downsampled\HD65\cropped\CardMasked\mask_down\*.jpg");
dir_mask=dir("Z:\homes\Peggy\VIVOskinExpe\Hassel_downsampled\HD65\cropped\CardMasked\mask\*.jpg");
dir_XYZfile=dir("Z:\homes\Peggy\VIVOskinExpe\Hassel_downsampled\HD65\cropped\CardMasked\XYZ_cropped\*.mat");

average_file='Z:\homes\Peggy\VIVOskinExpe\Hassel_downsampled\HD65\cropped\CardMasked\aveSkinByHand\autoNhand_fromXYZ.mat';
average=load(average_file);
average=average.average_lab_all(:,1:3);

save_folder='Z:\homes\Peggy\VIVOskinExpe\Hassel_downsampled\HD65\cropped\CardMasked\rendered\rendered25\dlabs';
if ~exist(save_folder, 'dir')
    mkdir(save_folder);
end

num_points = readmatrix('Z:\homes\Peggy\VIVOskinExpe\points25_delta.xlsx'); 


% white65=[95.04,100,108.89];
two=[7,15];

for i = 1:numel(files)
    if (~ismember(i, two))
        continue
    end   

    filename = fullfile(files(i).folder, files(i).name);      
    img0=imread(filename);
    img=im2double(img0);
    [m,n,p]=size(img);
    % if i==6
    %     startCenter=15;
    %     endCenter=49;
    % else
        startCenter=1;
        endCenter=length(num_points);
    % end

    UpExists=0;
    for i_maskUp = 1:length(dir_maskUp)
        if contains(dir_maskUp(i_maskUp).name, files(i).name)
            UpExists = 1;
            break;
        end
    end
    if ~UpExists
        i_mask=1;
        while ~contains(files(i).name,dir_mask(i_mask).name)
            i_mask=i_mask+1;
        end
    end
    dlabs=[];
    for i_points=startCenter:endCenter

 
        delta_Lab(1,1)=0;
        delta_Lab(1,2:3)=num_points(i_points,:);
        % delta_Lab1=0.7*delta_Lab;
        dlab=average(i,:)+delta_Lab;
        dlabs=[dlabs;dlab];


    end
    save(fullfile(save_folder, strcat(files(i).name(1:end-4),".mat")),"dlabs");
    writematrix(dlabs, fullfile(save_folder, strcat(files(i).name(1:end-4),".xlsx")));
end



