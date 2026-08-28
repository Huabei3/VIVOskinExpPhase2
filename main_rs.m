close all; 
clc;       
clear;     
addpath("utils\")
%% rs 
% 2025 3 1版本 没有2mask 使用get_average 使用chgW（13 15 分别拉亮5、50）
num_points = readmatrix('points_added_33.xlsx'); 
num_points=[zeros(length(num_points),1),num_points];
datai_file = '..\A_characterization\display_model\data_ipv18_3.mat';
wd65=[94.813  100.000  107.262];
LUT=load(datai_file);
XYZw_LUT=LUT.XYZw;
wd65_scaled=wd65./100.*XYZw_LUT(2);

%%
%------------r--------------
new_names = {'f04','f05','f06','m04','m05','m06',...
    'f01','f02','f03','m01','m02','m03',...
    'f07','f08','m07','m08',...
    'f09','f10','m09','m10'};
iOr="r";
Dtype="full";
% load("rendered\rs\checkLabFromPics_CA_SA.mat","dE_cell_big");

for i_model=1:length(new_names)
    source_folder=fullfile('mask',strcat(new_names(i_model),'r'));   
    lastPart=strcat(new_names(i_model),'r');
    model = new_names(i_model);    
    i_type=select_type(model);    
    files = dir(strcat(source_folder,'\*.jpg'));     
    dir_mask=dir(strcat("mask\",lastPart,"\*.jpg"));
    % XYZ data: local path maps to original_image_XYZ
    xyz_base = "D:\work\VIVOSkinExpe\original_image_XYZ";
    dir_XYZfile=dir(fullfile(xyz_base, lastPart, "*.mat"));  
    
    %----------------------
    if ismember(lastPart,["f04i","f05i","f06i","m04i","m06i"]) 
        if_wei=0;
    else
        if_wei=1;
    end

    load(fullfile("documents\aveSkin\i",strcat("aveLab_D65_",num2str(i_type),".mat")), ...
        "labC_HD65");   
    
    save_folder=fullfile('rendered\rs',lastPart);
    if ~exist(save_folder, 'dir')
        mkdir(save_folder);
    end

    
    load(fullfile("light_r\model_tcp",strcat(model,".mat")));
    % for i = [8]
    for i = 1:length(files)
    
        filename = fullfile(files(i).folder, files(i).name);      
        img0=imread(filename);
    %--------先跑小图看问题--------
        % img0 = imresize(img0, [size(img0,1)./6, size(img0,2)./6]);
    
        img=im2double(img0);
        [m,n,p]=size(img);
    
        startCenter=1;
        endCenter=length(num_points);
    
        for i_mask=1:length(dir_mask)
            if strcmp(files(i).name(1:end-4),dir_mask(i_mask).name(1:end-4))
            bull=imread(strcat(dir_mask(i_mask).folder,'\',dir_mask(i_mask).name));
            % bull = imresize(bull, [size(bull,1)./6, size(bull,2)./6]);%先跑小图看问题
                break
            end
        end

        for i_xyz=1:length(dir_XYZfile)
            if strcmp(dir_XYZfile(i_xyz).name(end-7:end-4),files(i).name(1:end-4))
                XYZ=load(fullfile(dir_XYZfile(i_xyz).folder,dir_XYZfile(i_xyz).name));
                XYZ=XYZ.XYZ_cropped;
                %------先跑小图看问题-------
                 % XYZ = imresize(XYZ, [size(XYZ,1)./6, size(XYZ,2)./6]);       
                break
            end
        end
        img=im2double(img0);
        [m, n, p] = size(img);
        xyz1= reshape(XYZ, [m * n, p]);
        [lab1] = xyz2lab(xyz1,'user',wd65_scaled);

        average(i,:)=get_average(lab1,bull,if_wei);

        a_CL=[];
        lastPart=char(lastPart);
        if ismember(i_type,[1,2])
            a_CL=[6.7421,-9.9816];
        elseif ismember(i_type,[3,4])
            load(fullfile("documents\aveSkin\i\C_Lpara",...
            strcat(num2str(i_type),"C_L_para.mat")),"a_CL");
        end

        if average(i,1)>60
            C_pre=a_CL(1)*log(60)+a_CL(2);%亮度实验
        else
            C_pre=a_CL(1)*log(average(i,1))+a_CL(2);%亮度实验
        end


        if i_type==4
            load(fullfile("documents\aveSkin",strcat(model,"i"), ...
                "autoNhand_scaleoverLUT.mat"),"average_lab_all");
            C_HD65_ind=sqrt(average_lab_all(7,2).^2+average_lab_all(7,3).^2);
            labC_HD65(1,2:4)=labC_HD65(1,2:4)./labC_HD65(1,4).*C_HD65_ind;
        end
        factor=C_pre./labC_HD65(1,4);
        dlabs=repmat([average(i,1),labC_HD65(1,2:3)],length(num_points),1)+num_points;
        dlabs(:,2:3)=dlabs(:,2:3).*factor;
 
        %-----------后CAT-----------        
        CCT=model_tcp_mean(i,1);
        for i_points=endCenter:-1:startCenter
            dlabs(i_points,:)=CAT_lab2lab1(dlabs(i_points,:),Dtype,CCT,"fore");            
        end   
        dlabs=adjust_dlabs_shape1(dlabs);
        if i_type==4
            if ismember(model,["f09","m09"])
                adj=0.55;
            elseif ismember(model,["f10"])
                adj=0.54;
            elseif ismember(model,["m10"])
                adj=0.5;
            end
            dlabs=adjust_dlabs(dlabs,adj);
        end

        for i_points=startCenter:endCenter
    % 
    %         %--------算中心-------
    % 
            dlab=dlabs(i_points,:);
            delta_Lab=dlab-average(i,:);

            search_name=strcat(files(i).name(1:end-4),'_',sprintf('%02d', i_points), ...
                '[',num2str(dlab(1,1)),',' ,...
                num2str(dlab(1,2)),',',num2str(dlab(1,3)),'].jpg');
            dir_img_file=dir(fullfile(save_folder,search_name));
            if ~isempty(dir_img_file)
                continue
            end

            noFaceRGB_folder=fullfile(save_folder,"noFaceRGB");
            if ~exist(noFaceRGB_folder,"dir")
                mkdir(noFaceRGB_folder);
            end
            noFaceRGB_file=fullfile(noFaceRGB_folder, ...
                strcat(files(i).name(1:end-4),".mat"));

            disp([num2str(i_points),'/',num2str(endCenter),'of', ...
                num2str(i),'/',num2str(numel(files)),' ',files(i).name,' begin']);
            startTime = datetime('now'); 
            %---------渲染-----------
            [out_rendering,dest_lab,bull_nosd]=...
                img_AddRender_simp(img,bull,bull,'srgb',delta_Lab, ...
                XYZ,noFaceRGB_file,if_wei,0);

            % plot_pic_dE(out_rendering,lab2,bull,if_wei);
            deltaE2000(dest_lab,dlab)
    %         ---------渲染-----------
            figure(2);
            imshow(out_rendering);

            disp([num2str(i_points),'/',num2str(endCenter),'of', ...
                num2str(i),'/',num2str(numel(files)),' ',files(i).name,' was done']);

            imwrite(out_rendering,fullfile(save_folder, ...
                strcat(files(i).name(1:end-4),'_',sprintf('%02d', i_points),'[',num2str(dlab(1,1)),',' ,...
                num2str(dlab(1,2)),',',num2str(dlab(1,3)),'].jpg')) );
            currentTime = datetime('now');    
            formattedTime = datestr(currentTime, 'yyyy-mm-dd HH:MM:SS');
            disp([files(i).name(1:end-4),'_',num2str(i_points),'finished: ', formattedTime]);
            time_diff = currentTime - startTime;
            fprintf('时间差: %s\n', time_diff);
        end
        currentTime = datetime('now');  
        formattedTime = datestr(currentTime, 'yyyy-mm-dd HH:MM:SS');
        disp([files(i).name(1:end-4),'finished: ',formattedTime]);
    end
end



% min(cell2mat(squeeze_factor(:,5)))
% max(cell2mat(squeeze_factor(:,5)))
%%
function plot_pic_dE(out_rendering,lab2,bull,if_wei)

    datai_file = '..\A_characterization\display_model\datai_ipv18_3.mat';

    wd65=[94.813  100.000  107.262];
    LUT=load(datai_file);
    XYZw_LUT=LUT.XYZw;
    wd65_scaled=wd65./100.*XYZw_LUT(2);

    [logicalIndex,bull_weight]=read_bull(bull,if_wei);
    sz=size(out_rendering);
    rgb_r=reshape(out_rendering,[sz(1)*sz(2),sz(3)]);
    rgb_r=rgb_r.*255;
    xyz_r = lut3d_rgb2xyz1(rgb_r,datai_file);
    [lab_r] = xyz2lab(xyz_r,'user',wd65_scaled);

    dE=deltaE2000(lab_r(~logicalIndex,:),lab2(~logicalIndex,:))';
    big_idx=find(dE>2);
    % 将 big_idx 转换为原图中的坐标
    [rows, cols] = ind2sub([sz(1),sz(2)], find(~logicalIndex));
    rows = rows(big_idx);
    cols = cols(big_idx);

    figure(2)
    hold on;
    imshow(out_rendering);
    hold on;
    scatter(cols,rows, 1,  'filled');
    disp("d")


    ave_r=get_average(lab_r,bull,if_wei);
    ave_2=get_average(lab2,bull,if_wei);

    lab_big=[lab2(big_idx,:),lab_r(big_idx,:),dE(big_idx,:)];

end

