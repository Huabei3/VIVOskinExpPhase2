function dlabs_aft=adjust_dlabs_shape(dlabs_bf)
    shift2933=dlabs_bf(29,:)-dlabs_bf(33,:);
    squeeze_factor=shift2933(1,3)./shift2933(1,2);
    len2933=sqrt(shift2933(1,2).^2+shift2933(1,3).^2);
 
    if squeeze_factor<tand(50)
        shift2933_target=[0,len2933*cosd(50),len2933*sind(50)];
        delta_Lab=dlabs_bf-repmat(dlabs_bf(33,:),length(dlabs_bf),1);
        delta_Lab(:,2)=delta_Lab(:,2)./shift2933(1,2).*shift2933_target(1,2);
        delta_Lab(:,3)=delta_Lab(:,3)./shift2933(1,3).*shift2933_target(1,3);
        dlabs_aft=repmat(dlabs_bf(33,:),length(dlabs_bf),1)+delta_Lab;
    else
        dlabs_aft=dlabs_bf;
    end

end