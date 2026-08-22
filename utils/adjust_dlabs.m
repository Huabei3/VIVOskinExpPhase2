function dlabs_aft=adjust_dlabs(dlabs_bf,factor)
    delta_Lab=dlabs_bf-repmat(dlabs_bf(33,:),length(dlabs_bf),1);
    delta_Lab=delta_Lab.*factor;
    dlabs_aft=repmat(dlabs_bf(33,:),length(dlabs_bf),1)+delta_Lab;
end