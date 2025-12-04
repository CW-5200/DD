%hook CMessageMgr
- (void)AddEmoticonMsg:(NSString *)msg MsgWrap:(CMessageWrap *)msgWrap {
    if (isGameCheatEnabled() && [msgWrap m_uiMessageType] == 47 && ([msgWrap m_uiGameType] == 2 || [msgWrap m_uiGameType] == 1)) {
        // 创建插件设置风格的视图控制器
        UIViewController *selectionVC = [[UIViewController alloc] init];
        selectionVC.title = [msgWrap m_uiGameType] == 1 ? @"选择猜拳" : @"选择骰子点数";
        
        // 设置样式
        if (@available(iOS 13.0, *)) {
            selectionVC.view.backgroundColor = [UIColor systemBackgroundColor];
        } else {
            selectionVC.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
        }
        
        // 创建按钮容器
        UIStackView *stackView = [[UIStackView alloc] init];
        stackView.axis = UILayoutConstraintAxisVertical;
        stackView.spacing = 12.0;
        stackView.distribution = UIStackViewDistributionFillEqually;
        stackView.alignment = UIStackViewAlignmentFill;
        stackView.translatesAutoresizingMaskIntoConstraints = NO;
        [selectionVC.view addSubview:stackView];
        
        // 添加约束
        [NSLayoutConstraint activateConstraints:@[
            [stackView.centerXAnchor constraintEqualToAnchor:selectionVC.view.centerXAnchor],
            [stackView.centerYAnchor constraintEqualToAnchor:selectionVC.view.centerYAnchor],
            [stackView.leadingAnchor constraintEqualToAnchor:selectionVC.view.leadingAnchor constant:20],
            [stackView.trailingAnchor constraintEqualToAnchor:selectionVC.view.trailingAnchor constant:-20],
            [stackView.heightAnchor constraintLessThanOrEqualToConstant:300]
        ]];
        
        // 获取选项
        NSArray *actions;
        if ([msgWrap m_uiGameType] == 1) {
            actions = @[@"剪刀", @"石头", @"布"];
        } else {
            actions = @[@"1", @"2", @"3", @"4", @"5", @"6"];
        }
        
        // 创建选项按钮
        for (int i = 0; i < actions.count; i++) {
            NSString *actionTitle = actions[i];
            UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
            button.tag = i;
            
            // 设置按钮样式
            button.backgroundColor = [UIColor systemBlueColor];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            [button setTitle:actionTitle forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightMedium];
            button.layer.cornerRadius = 10.0;
            button.clipsToBounds = YES;
            
            // 按钮高度
            button.translatesAutoresizingMaskIntoConstraints = NO;
            [button.heightAnchor constraintEqualToConstant:50].active = YES;
            
            // 添加点击事件
            [button addTarget:selectionVC action:@selector(handleSelection:) forControlEvents:UIControlEventTouchUpInside];
            
            [stackView addArrangedSubview:button];
        }
        
        // 添加关闭按钮
        UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
        [closeButton setTitle:@"关闭" forState:UIControlStateNormal];
        [closeButton setTitleColor:[UIColor systemGrayColor] forState:UIControlStateNormal];
        closeButton.titleLabel.font = [UIFont systemFontOfSize:15];
        [closeButton addTarget:selectionVC action:@selector(dismissView) forControlEvents:UIControlEventTouchUpInside];
        
        closeButton.translatesAutoresizingMaskIntoConstraints = NO;
        [selectionVC.view addSubview:closeButton];
        
        [NSLayoutConstraint activateConstraints:@[
            [closeButton.topAnchor constraintEqualToAnchor:selectionVC.view.safeAreaLayoutGuide.topAnchor constant:8],
            [closeButton.trailingAnchor constraintEqualToAnchor:selectionVC.view.trailingAnchor constant:-16]
        ]];
        
        // 设置为按钮的action
        [selectionVC performSelector:@selector(setSelectionBlock:) withObject:^(NSInteger selectedIndex) {
            // 处理选择
            unsigned int gameContent;
            if ([msgWrap m_uiGameType] == 1) {
                gameContent = (unsigned int)selectedIndex + 1;
            } else {
                gameContent = (unsigned int)selectedIndex + 4;
            }
            
            NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
            if (md5) {
                [msgWrap setM_nsEmoticonMD5:md5];
                [msgWrap setM_uiGameContent:gameContent];
            }
            
            // 发送消息
            dispatch_async(dispatch_get_main_queue(), ^{
                %orig(msg, msgWrap);
            });
        }];
        
        // 显示模态视图
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:selectionVC];
        nav.modalPresentationStyle = UIModalPresentationFormSheet;
        if (@available(iOS 13.0, *)) {
            nav.modalInPresentation = YES; // 禁止下拉关闭
        }
        
        // 查找当前活动窗口
        UIWindowScene *windowScene = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                windowScene = (UIWindowScene *)scene;
                break;
            }
        }
        
        if (windowScene) {
            UIWindow *window = windowScene.windows.firstObject;
            UIViewController *topController = window.rootViewController;
            while (topController.presentedViewController) {
                topController = topController.presentedViewController;
            }
            
            [topController presentViewController:nav animated:YES completion:nil];
        }
        return;
    }
    %orig(msg, msgWrap);
}
%end

// 为UIViewController添加选择回调的属性
@interface UIViewController (GameSelection)
@property (nonatomic, copy) void (^selectionBlock)(NSInteger);
- (void)setSelectionBlock:(void (^)(NSInteger))block;
- (void)handleSelection:(UIButton *)sender;
- (void)dismissView;
@end

@implementation UIViewController (GameSelection)

static char kSelectionBlockKey;

- (void (^)(NSInteger))selectionBlock {
    return objc_getAssociatedObject(self, &kSelectionBlockKey);
}

- (void)setSelectionBlock:(void (^)(NSInteger))block {
    objc_setAssociatedObject(self, &kSelectionBlockKey, block, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)handleSelection:(UIButton *)sender {
    if (self.selectionBlock) {
        self.selectionBlock(sender.tag);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dismissView {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end