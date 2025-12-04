%hook CMessageMgr
- (void)AddEmoticonMsg:(NSString *)msg MsgWrap:(CMessageWrap *)msgWrap {
    if (isGameCheatEnabled() && [msgWrap m_uiMessageType] == 47 && ([msgWrap m_uiGameType] == 2 || [msgWrap m_uiGameType] == 1)) {
        
        BOOL isRockPaperScissors = [msgWrap m_uiGameType] == 1;
        NSString *title = isRockPaperScissors ? @"请选择石头/剪刀/布" : @"请选择点数";
        
        // 创建半透明背景
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow ?: [[UIApplication sharedApplication].windows firstObject];
        
        UIView *containerView = [[UIView alloc] initWithFrame:keyWindow.bounds];
        containerView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.4];
        containerView.tag = 9999; // 用于后续查找
        
        // 内容容器
        UIView *contentView = [[UIView alloc] init];
        contentView.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.96 alpha:1.0];
        contentView.layer.cornerRadius = 14;
        contentView.layer.masksToBounds = YES;
        contentView.layer.shadowColor = [UIColor blackColor].CGColor;
        contentView.layer.shadowOffset = CGSizeMake(0, 2);
        contentView.layer.shadowOpacity = 0.2;
        contentView.layer.shadowRadius = 10;
        contentView.translatesAutoresizingMaskIntoConstraints = NO;
        [containerView addSubview:contentView];
        
        // 标题标签
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.text = title;
        titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        titleLabel.textColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [contentView addSubview:titleLabel];
        
        // 按钮容器
        UIView *buttonsContainer = [[UIView alloc] init];
        buttonsContainer.backgroundColor = [UIColor colorWithRed:0.98 green:0.98 blue:0.98 alpha:1.0];
        buttonsContainer.layer.cornerRadius = 12;
        buttonsContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [contentView addSubview:buttonsContainer];
        
        // 创建按钮
        NSArray *actions;
        if (isRockPaperScissors) {
            actions = @[@"✌️ 剪刀", @"✊ 石头", @"✋ 布"];
        } else {
            actions = @[@"⚀ 1", @"⚁ 2", @"⚂ 3", @"⚃ 4", @"⚄ 5", @"⚅ 6"];
        }
        
        NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
        NSMutableArray<NSLayoutConstraint *> *buttonConstraints = [NSMutableArray array];
        
        UIButton *lastButton = nil;
        
        for (int i = 0; i < actions.count; i++) {
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            button.tag = i;
            button.backgroundColor = [UIColor whiteColor];
            button.layer.cornerRadius = 10;
            button.layer.masksToBounds = YES;
            button.layer.borderWidth = 0.5;
            button.layer.borderColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0].CGColor;
            button.translatesAutoresizingMaskIntoConstraints = NO;
            
            // 设置按钮内容
            NSString *buttonTitle = actions[i];
            NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:buttonTitle];
            [attributedString addAttribute:NSFontAttributeName 
                                     value:[UIFont systemFontOfSize:17 weight:UIFontWeightMedium] 
                                     range:NSMakeRange(0, buttonTitle.length)];
            [attributedString addAttribute:NSForegroundColorAttributeName 
                                     value:[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0] 
                                     range:NSMakeRange(0, buttonTitle.length)];
            
            [button setAttributedTitle:attributedString forState:UIControlStateNormal];
            
            // 高亮效果
            [button addTarget:self action:@selector(gameButtonTouchDown:) forControlEvents:UIControlEventTouchDown];
            [button addTarget:self action:@selector(gameButtonTouchUp:) forControlEvents:UIControlEventTouchUpOutside|UIControlEventTouchUpInside|UIControlEventTouchCancel];
            
            // 按钮点击事件
            [button addTarget:self action:@selector(gameButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
            
            [buttonsContainer addSubview:button];
            [buttons addObject:button];
            
            // 按钮约束
            NSLayoutConstraint *topConstraint = nil;
            if (lastButton) {
                topConstraint = [button.topAnchor constraintEqualToAnchor:lastButton.bottomAnchor constant:10];
            } else {
                topConstraint = [button.topAnchor constraintEqualToAnchor:buttonsContainer.topAnchor constant:15];
            }
            
            [NSLayoutConstraint activateConstraints:@[
                [button.leadingAnchor constraintEqualToAnchor:buttonsContainer.leadingAnchor constant:15],
                [button.trailingAnchor constraintEqualToAnchor:buttonsContainer.trailingAnchor constant:-15],
                [button.heightAnchor constraintEqualToConstant:44],
                topConstraint
            ]];
            
            lastButton = button;
            [buttonConstraints addObject:topConstraint];
        }
        
        // 取消按钮
        UIButton *cancelButton = [UIButton buttonWithType:UIButtonTypeSystem];
        cancelButton.backgroundColor = [UIColor whiteColor];
        cancelButton.layer.cornerRadius = 10;
        cancelButton.layer.masksToBounds = YES;
        cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
        
        NSMutableAttributedString *cancelAttributedString = [[NSMutableAttributedString alloc] initWithString:@"取消"];
        [cancelAttributedString addAttribute:NSFontAttributeName 
                                       value:[UIFont systemFontOfSize:17 weight:UIFontWeightMedium] 
                                       range:NSMakeRange(0, 2)];
        [cancelAttributedString addAttribute:NSForegroundColorAttributeName 
                                       value:[UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0] 
                                       range:NSMakeRange(0, 2)];
        
        [cancelButton setAttributedTitle:cancelAttributedString forState:UIControlStateNormal];
        
        [cancelButton addTarget:self action:@selector(cancelButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        [contentView addSubview:cancelButton];
        
        // 分隔线
        UIView *separatorView = [[UIView alloc] init];
        separatorView.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
        separatorView.translatesAutoresizingMaskIntoConstraints = NO;
        [contentView addSubview:separatorView];
        
        // 设置约束
        [NSLayoutConstraint activateConstraints:@[
            // 内容容器居中
            [contentView.centerXAnchor constraintEqualToAnchor:containerView.centerXAnchor],
            [contentView.centerYAnchor constraintEqualToAnchor:containerView.centerYAnchor],
            [contentView.widthAnchor constraintEqualToConstant:300],
            
            // 标题
            [titleLabel.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:20],
            [titleLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:20],
            [titleLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-20],
            
            // 按钮容器
            [buttonsContainer.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:20],
            [buttonsContainer.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:15],
            [buttonsContainer.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-15],
            
            // 分隔线
            [separatorView.topAnchor constraintEqualToAnchor:buttonsContainer.bottomAnchor constant:15],
            [separatorView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
            [separatorView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
            [separatorView.heightAnchor constraintEqualToConstant:0.5],
            
            // 取消按钮
            [cancelButton.topAnchor constraintEqualToAnchor:separatorView.bottomAnchor],
            [cancelButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
            [cancelButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
            [cancelButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
            [cancelButton.heightAnchor constraintEqualToConstant:50]
        ]];
        
        // 动态计算按钮容器高度
        CGFloat buttonContainerHeight = (actions.count * 44) + ((actions.count - 1) * 10) + 30;
        [buttonsContainer.heightAnchor constraintEqualToConstant:buttonContainerHeight].active = YES;
        
        // 保存数据以便后续使用
        objc_setAssociatedObject(containerView, @"msgWrap", msgWrap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(containerView, @"msg", msg, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(containerView, @"buttons", buttons, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // 添加到窗口
        [keyWindow addSubview:containerView];
        
        // 动画效果
        contentView.transform = CGAffineTransformMakeScale(1.1, 1.1);
        contentView.alpha = 0;
        
        [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            contentView.transform = CGAffineTransformIdentity;
            contentView.alpha = 1;
        } completion:nil];
        
        return;
    }
    %orig(msg, msgWrap);
}

%new
- (void)gameButtonTouchDown:(UIButton *)sender {
    sender.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
}

%new
- (void)gameButtonTouchUp:(UIButton *)sender {
    sender.backgroundColor = [UIColor whiteColor];
}

%new
- (void)gameButtonTapped:(UIButton *)sender {
    UIView *containerView = sender.superview.superview.superview.superview;
    if (!containerView) return;
    
    CMessageWrap *msgWrap = objc_getAssociatedObject(containerView, @"msgWrap");
    NSString *msg = objc_getAssociatedObject(containerView, @"msg");
    
    // 动画效果
    [UIView animateWithDuration:0.2 animations:^{
        containerView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [containerView removeFromSuperview];
        
        // 处理选择
        unsigned int gameContent;
        if ([msgWrap m_uiGameType] == 1) { // 石头剪刀布
            gameContent = (int)sender.tag + 1;
        } else { // 骰子
            gameContent = (int)sender.tag + 4;
        }
        
        NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
        if (md5) {
            [msgWrap setM_nsEmoticonMD5:md5];
            [msgWrap setM_uiGameContent:gameContent];
        }
        
        %orig(msg, msgWrap);
    }];
}

%new
- (void)cancelButtonTapped:(UIButton *)sender {
    UIView *containerView = sender.superview.superview;
    
    [UIView animateWithDuration:0.2 animations:^{
        containerView.alpha = 0;
        containerView.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [containerView removeFromSuperview];
    }];
}
%end