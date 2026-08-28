function dlabs_aft=adjust_dlabs_shape1(dlabs_bf)
    shift2933=dlabs_bf(29,:)-dlabs_bf(33,:);
    squeeze_factor=shift2933(1,3)./shift2933(1,2);
 
    if squeeze_factor<tand(50)
        dest_2933height=shift2933(1,2).*tand(50);
        delta_Lab=dlabs_bf-repmat(dlabs_bf(33,:),length(dlabs_bf),1);        
        delta_Lab(:,3)=delta_Lab(:,3)./shift2933(1,3).*dest_2933height;
        dlabs_aft=repmat(dlabs_bf(33,:),length(dlabs_bf),1)+delta_Lab;
    else
        dlabs_aft=dlabs_bf;
    end

end