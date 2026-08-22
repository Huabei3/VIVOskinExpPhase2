close all; 
clc;       
clear;     
addpath("utils\")
%% % 
%----------------------
ct=["H3K","H4K","H5K","H6K","H7K","H8K","HD65",...
"L3K","L4K","L5K","L6K","L7K","L8K","LD65",...
"M3K","M4K","M5K","M6K","M7K","M8K","MD65"];
CT = [3000, 4000, 5000, 6000, 7000, 8000, 6500, ...
  3000, 4000, 5000, 6000, 7000, 8000, 6500, ...
  3000, 4000, 5000, 6000, 7000, 8000, 6500]';
% datai_file = '..\A_characterization\display_model\datai_ipv18_3.mat';
% LUT 类型：phase1（默认，保持现有逻辑）或 phase2（使用 data_ipv30_phase2_3.mat）
handle.LUT_type = "phase2";
if strcmp(handle.LUT_type, "phase2")
    datai_file = '..\A_characterization\display_model\data_ipv30_phase2_3.mat';
else
    datai_file = '..\A_characterization\display_model\data_ipv35_3.mat';
end
wd65=[94.813  100.000  107.262];
LUT=load(datai_file);
XYZw_LUT=LUT.XYZw;
wd65_scaled=wd65./100.*XYZw_LUT(2);
% load("render_range.mat","shift_range","db_range");
%------------i--------------
new_names = {'f04','f05','f06','m04','m05','m06',...
    'f01','f02','f03','m01','m02','m03',...
    'f07','f08','m07','m08',...
    'f09','f10','m09','m10'};

Dtype="full";
iOr="i";
for i_model=1:length(new_names)
    source_folder=fullfile('mask',strcat(new_names(i_model),'i'));
    source_folder=char(source_folder);
    slashes = find(source_folder== '\');
    lastPart=source_folder(slashes(1,end)+1:end);    

    model = lastPart(1:end-1);

    if ismember(lastPart,["f04i","f05i","f06i","m04i","m06i"]) 
        if_wei=0;
    else
        if_wei=1;
    end
    if ismember(lastPart,["m02i","m03i"]) 
        if_2mask=1;
    else
        if_2mask=0;
    end
    i_type=select_type(model);
    
    files = dir(strcat(source_folder,'\*.jpg'));  % 读取文件夹中的所有.jpg文件
    
    dir_mask=dir(strcat("mask\",lastPart,"\*.jpg"));
    dir_mask_nosd=dir(fullfile("Shadow\mask",lastPart,"nosd\*.jpg"));
    % XYZ data: local path maps to original_image_XYZ
    xyz_base = "D:\work\VIVOSkinExpe\original_image_XYZ";
    dir_XYZfile=dir(fullfile(xyz_base, lastPart, "*.mat"));
    
    
    load(fullfile("documents\aveSkin\i",strcat("aveLab_D65_",num2str(i_type),".mat")), ...
        "labC_HD65");  
    
    save_folder=fullfile('rendered',char(handle.LUT_type),'i',lastPart);

    if ~exist(save_folder, 'dir')
        mkdir(save_folder);
    end
    
    num_points = readmatrix('points_added_33.xlsx'); 
    num_points=[zeros(length(num_points),1),num_points];
    for i =[1]
    % for i = 1:numel(files)
    
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
                picname_check{i,1}=files(i).name(1:end-4);
                picname_check{i,2}=dir_mask(i_mask).name(1:end-4);
                bull=imread(strcat(dir_mask(i_mask).folder,'\',dir_mask(i_mask).name));
                % bull = imresize(bull, [size(bull,1)./6, size(bull,2)./6]);%先跑小图看问题
                break
            end
        end
        for i_mask=1:length(dir_mask_nosd)
            if strcmp(files(i).name(1:end-4),dir_mask_nosd(i_mask).name(1:end-4))
                bull_nosd=imread(strcat(dir_mask_nosd(i_mask).folder,'\',dir_mask_nosd(i_mask).name));
                % bull_nosd = imresize(bull_nosd, [size(bull_nosd,1)./6, size(bull_nosd,2)./6]);%先跑小图看问题
                break
            end
        end
        for i_xyz=1:length(dir_XYZfile)
            if strcmp(dir_XYZfile(i_xyz).name(1:end-4),files(i).name(1:end-4))
                picname_check{i,4}=dir_XYZfile(i_xyz).name(1:end-4);
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
        if if_2mask
            average(i,:)=get_average(lab1,bull_nosd,if_wei);
        else
            average(i,:)=get_average(lab1,bull,if_wei);
        end

        a_CL=[];
        if ismember(i_type,[1,2])
            a_CL=[6.7421,-9.9816];
        elseif ismember(i_type,[3,4])
            load(fullfile("aveSkinByHand2\i\C_Lpara",...
            strcat(num2str(i_type),"C_L_para.mat")),"a_CL");
        end

        if average(i,1)>60
            C_pre=a_CL(1)*log(60)+a_CL(2);%亮度实验
        else
            C_pre=a_CL(1)*log(average(i,1))+a_CL(2);%亮度实验
        end

        factor=C_pre./labC_HD65(1,4);
        dlabs=repmat([average(i,1),labC_HD65(1,2:3)],length(num_points),1)+num_points;
        dlabs(:,2:3)=dlabs(:,2:3).*factor;

        %计算delta_Lab
        CCT=CT(i);
        for i_points=startCenter:1:endCenter
            dlab_CATed(i_points,:)=CAT_lab2lab1(dlabs(i_points,:),Dtype,CCT,"fore");            
        end
        dlab_CATed=adjust_dlabs_shape1(dlab_CATed);
        if i_type==4
            if ismember(model,["f09","m09"])
                adj=0.55;
            elseif ismember(model,["f10"])
                adj=0.54;
            elseif ismember(model,["m10"])
                adj=0.5;
            end
            dlab_CATed=adjust_dlabs(dlab_CATed,adj);
        end

        % figure(1)
        % plot_render_points(dlab_CATed)
        % draw_folder=fullfile(save_folder,"draw");
        % if ~exist(draw_folder,"dir")
        %     mkdir(draw_folder);
        % end
        % exportgraphics(gcf,fullfile(draw_folder,strcat(lastPart,files(i).name)),'Resolution',150);
        % clf;
        
        % adjust
        delta_Lab=dlab_CATed-repmat(average(i,:),length(dlabs),1);
        for i_points=[startCenter] 
        % for i_points=startCenter:1:endCenter  
            % dlab=dlabs(i_points,:);
            % delta_Lab(i_points,:)=dlab-average(i,:);
            dlab=delta_Lab(i_points,:)+average(i,:);
            %看是否已经有了
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
            % 保存 LUT 映射前中间变量 xyz2（与输出 jpg 同名 .mat）
            xyz2_file=fullfile(save_folder, strcat(search_name(1:end-4), ".mat"));
            % 保存 LUT 映射后 RGB outnew（便于逐像素对比）
            outnew_file=fullfile(save_folder, strcat(search_name(1:end-4), "_outnew.mat"));

            disp([lastPart,num2str(i_points),'/',num2str(endCenter),'of', ...
                num2str(i),'/',num2str(numel(files)),' ',files(i).name,' begin']);
            startTime = datetime('now'); 
            %---------渲染-----------
            [out_rendering,dest_lab,bull_nosd]=...
                img_AddRender_simp(img,bull,bull_nosd,'LUT',delta_Lab(i_points,:), ...
                XYZ,noFaceRGB_file,if_wei,if_2mask, handle, xyz2_file, outnew_file);
            deltaE2000(dest_lab,dlab)

            % plot_pic_dE(out_rendering,lab2,bull,if_wei);
            %---------渲染-----------
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

    dE=deltaE2000(lab_r(~logicalIndex,:),lab2(~logicalIndex,:));
    big_idx=find(dE>3);
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

    lab_big=lab2(big_idx,:);

end
