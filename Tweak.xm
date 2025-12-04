%hook CMessageMgr
- (void)AddEmoticonMsg:(NSString *)msg MsgWrap:(CMessageWrap *)msgWrap {
    if (isGameCheatEnabled() && [msgWrap m_uiMessageType] == 47 && ([msgWrap m_uiGameType] == 2 || [msgWrap m_uiGameType] == 1)) {
        NSString *title = [msgWrap m_uiGameType] == 1 ? @"请选择石头/剪刀/布" : @"请选择点数";
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"游戏控制"
                                                                       message:title
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        NSArray *actions;
        if ([msgWrap m_uiGameType] == 1) {
            actions = @[@"剪刀", @"石头", @"布"];
        } else {
            actions = @[@"1", @"2", @"3", @"4", @"5", @"6"];
        }
        
        for (int i = 0; i < actions.count; i++) {
            NSString *actionTitle = actions[i];
            UIAlertAction* action = [UIAlertAction actionWithTitle:actionTitle 
                                                             style:UIAlertActionStyleDefault 
                                                           handler:^(UIAlertAction * _Nonnull action) {
                unsigned int gameContent;
                if ([msgWrap m_uiGameType] == 1) {
                    gameContent = i + 1;
                } else {
                    gameContent = i + 4;
                }
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            [alert addAction:action];
        }
        
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"取消" 
                                                               style:UIAlertActionStyleCancel 
                                                             handler:nil];
        [alert addAction:cancelAction];
        
        // 获取当前最顶层的视图控制器
        UIWindow *window = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    window = windowScene.windows.firstObject;
                    break;
                }
            }
        } else {
            window = UIApplication.sharedApplication.keyWindow;
        }
        
        if (window) {
            UIViewController *topController = window.rootViewController;
            while (topController.presentedViewController) {
                topController = topController.presentedViewController;
            }
            
            // 使用标准的模态样式
            [topController presentViewController:alert animated:YES completion:nil];
        }
        
        return;
    }
    %orig(msg, msgWrap);
}
%end