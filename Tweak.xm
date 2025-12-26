%config(generator=internal)
%hookf(IMP, class_getMethodImplementation, Class cls, SEL sel) {
    const char *name = sel_getName(sel);
    if (strcmp(name, "redEnvelopDelay") == 0) {
        static IMP redEnvelopDelayIMP = NULL;
        if (!redEnvelopDelayIMP) {
            redEnvelopDelayIMP = imp_implementationWithBlock(^NSUInteger(id self) {
                return 0;
            });
        }
        return redEnvelopDelayIMP;
    }
    return %orig;
}

// 注册到插件管理器
%ctor {
    if (NSClassFromString(@"WCPluginsMgr")) {
        [[objc_getClass("WCPluginsMgr") sharedInstance] 
            registerSwitchWithTitle:@"DD红包" 
                                key:@"DD_RedEnvelop_Enabled"];
    }
    
    NSLog(@"[DD红包] 插件已加载 v1.0.0");
}

// MARK: - 工具函数
@interface WCBizUtil : NSObject
+ (NSDictionary *)dictionaryWithDecodedComponets:(NSString *)str separator:(NSString *)sep;
@end

// MARK: - Hook红包逻辑管理器
%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL pluginEnabled = [defaults boolForKey:@"DD_RedEnvelop_Enabled"];
    if (!pluginEnabled) return;
    
    @try {
        // 获取cgiCmdid
        unsigned int cgiCmdid = 0;
        if ([arg1 respondsToSelector:@selector(cgiCmdid)]) {
            cgiCmdid = (unsigned int)[arg1 performSelector:@selector(cgiCmdid)];
        }
        
        // 只处理查询请求(cgiCmdid == 3)
        if (cgiCmdid != 3) return;
        
        // 解析响应数据
        NSString *responseString = @"";
        if ([arg1 respondsToSelector:@selector(retText)]) {
            id retText = [arg1 performSelector:@selector(retText)];
            if ([retText respondsToSelector:@selector(buffer)]) {
                NSData *buffer = [retText performSelector:@selector(buffer)];
                if (buffer) {
                    responseString = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
                }
            }
        }
        
        if (responseString.length == 0) return;
        
        // 解析JSON响应
        NSData *jsonData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error = nil;
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        
        if (error || !responseDict) return;
        
        // 检查红包状态
        NSInteger receiveStatus = [responseDict[@"receiveStatus"] integerValue];
        NSInteger hbStatus = [responseDict[@"hbStatus"] integerValue];
        NSString *timingIdentifier = responseDict[@"timingIdentifier"];
        
        if (receiveStatus == 2 || hbStatus == 4 || !timingIdentifier) {
            return;
        }
        
        // 解析请求获取sign
        NSString *requestSign = nil;
        if ([arg2 respondsToSelector:@selector(reqText)]) {
            id reqText = [arg2 performSelector:@selector(reqText)];
            if ([reqText respondsToSelector:@selector(buffer)]) {
                NSData *buffer = [reqText performSelector:@selector(buffer)];
                if (buffer) {
                    NSString *requestString = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
                    NSDictionary *requestDict = [WCBizUtil dictionaryWithDecodedComponets:requestString separator:@"&"];
                    NSString *nativeUrl = [[requestDict objectForKey:@"nativeUrl"] stringByRemovingPercentEncoding];
                    NSDictionary *nativeUrlDict = [WCBizUtil dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
                    requestSign = [nativeUrlDict objectForKey:@"sign"];
                }
            }
        }
        
        if (!requestSign) return;
        
        // 检查黑名单
        NSArray *blackList = [defaults arrayForKey:@"DD_RedEnvelop_BlackList"] ?: @[];
        BOOL isInBlackList = NO;
        for (NSString *blackItem in blackList) {
            if ([responseString containsString:blackItem]) {
                isInBlackList = YES;
                break;
            }
        }
        
        if (isInBlackList) return;
        
        // 检查是否抢自己的红包
        BOOL receiveSelf = [defaults boolForKey:@"DD_RedEnvelop_ReceiveSelf"];
        if (!receiveSelf) {
            // 从响应中提取发送者信息
            NSString *senderInfo = responseDict[@"sendUserName"] ?: @"";
            Class contactMgrClass = objc_getClass("CContactMgr");
            if (contactMgrClass) {
                id mmServiceCenter = objc_getClass("MMServiceCenter");
                id defaultCenter = [mmServiceCenter performSelector:@selector(defaultCenter)];
                id contactMgr = [defaultCenter performSelector:@selector(getService:) withObject:contactMgrClass];
                
                if ([contactMgr respondsToSelector:@selector(getSelfContact)]) {
                    id selfContact = [contactMgr performSelector:@selector(getSelfContact)];
                    if ([selfContact respondsToSelector:@selector(m_nsUsrName)]) {
                        NSString *myUserName = [selfContact performSelector:@selector(m_nsUsrName)];
                        if ([senderInfo isEqualToString:myUserName]) {
                            return;
                        }
                    }
                }
            }
        }
        
        // 延迟设置
        NSInteger delaySeconds = [defaults integerForKey:@"DD_RedEnvelop_Delay"];
        BOOL serialMode = [defaults boolForKey:@"DD_RedEnvelop_SerialMode"];
        
        // 创建红包参数
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        [params setObject:requestSign forKey:@"sign"];
        [params setObject:timingIdentifier forKey:@"timingIdentifier"];
        [params setObject:responseDict[@"sendId"] ?: @"" forKey:@"sendId"];
        [params setObject:responseDict[@"channelId"] ?: @"" forKey:@"channelId"];
        [params setObject:responseDict[@"msgType"] ?: @"" forKey:@"msgType"];
        
        // 延迟执行抢红包
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delaySeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self openRedEnvelopWithParams:params];
        });
        
    } @catch (NSException *exception) {
        NSLog(@"[DD红包] 处理响应异常: %@", exception);
    }
}

%new
- (void)openRedEnvelopWithParams:(NSDictionary *)params {
    @try {
        // 调用OpenRedEnvelopesRequest方法
        SEL openSel = @selector(OpenRedEnvelopesRequest:);
        if ([self respondsToSelector:openSel]) {
            [self performSelector:openSel withObject:params];
            NSLog(@"[DD红包] 已尝试抢红包: %@", params[@"sendId"]);
        }
    } @catch (NSException *exception) {
        NSLog(@"[DD红包] 打开红包异常: %@", exception);
    }
}

%end

// MARK: - Hook消息管理器处理红包消息
%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(id)wrap {
    %orig;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"DD_RedEnvelop_Enabled"]) return;
    
    @try {
        // 获取消息类型
        unsigned int msgType = 0;
        if ([wrap respondsToSelector:@selector(m_uiMessageType)]) {
            msgType = (unsigned int)[wrap performSelector:@selector(m_uiMessageType)];
        }
        
        // 只处理49类型消息(红包消息)
        if (msgType != 49) return;
        
        // 获取消息内容
        NSString *content = @"";
        if ([wrap respondsToSelector:@selector(m_nsContent)]) {
            content = [wrap performSelector:@selector(m_nsContent)];
        }
        
        // 检查是否为红包消息
        if (![content containsString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"]) {
            return;
        }
        
        // 获取发送者
        NSString *fromUsr = @"";
        if ([wrap respondsToSelector:@selector(m_nsFromUsr)]) {
            fromUsr = [wrap performSelector:@selector(m_nsFromUsr)];
        }
        
        // 获取接收者
        NSString *toUsr = @"";
        if ([wrap respondsToSelector:@selector(m_nsToUsr)]) {
            toUsr = [wrap performSelector:@selector(m_nsToUsr)];
        }
        
        // 检查黑名单
        NSArray *blackList = [defaults arrayForKey:@"DD_RedEnvelop_BlackList"] ?: @[];
        if ([blackList containsObject:fromUsr]) {
            return;
        }
        
        // 解析nativeUrl
        NSRange range = [content rangeOfString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"];
        if (range.location != NSNotFound) {
            NSString *nativeUrl = [content substringFromIndex:range.location];
            NSDictionary *urlParams = [WCBizUtil dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
            
            // 判断是否群聊
            BOOL isGroupChat = [fromUsr containsString:@"@chatroom"] || [toUsr containsString:@"@chatroom"];
            
            // 个人红包开关
            BOOL personalEnabled = [defaults boolForKey:@"DD_RedEnvelop_PersonalEnabled"];
            if (!isGroupChat && !personalEnabled) {
                return;
            }
            
            // 记录日志
            NSLog(@"[DD红包] 检测到红包消息 from: %@, to: %@", fromUsr, toUsr);
            
        }
        
    } @catch (NSException *exception) {
        NSLog(@"[DD红包] 处理消息异常: %@", exception);
    }
}

%end

// MARK: - 提供设置界面
@interface DDRedEnvelopSettingsController : UIViewController {
    UISwitch *_enabledSwitch;
    UISwitch *_receiveSelfSwitch;
    UISwitch *_personalSwitch;
    UISwitch *_serialSwitch;
    UITextField *_delayField;
    UITextField *_blackListField;
    UIButton *_saveButton;
}

@end

%hook DDRedEnvelopSettingsController

- (void)viewDidLoad {
    %orig;
    
    self.title = @"DD红包设置";
    self.view.backgroundColor = [UIColor whiteColor];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 总开关
    UILabel *enabledLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 200, 40)];
    enabledLabel.text = @"启用插件";
    [self.view addSubview:enabledLabel];
    
    _enabledSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(250, 100, 60, 40)];
    [_enabledSwitch setOn:[defaults boolForKey:@"DD_RedEnvelop_Enabled"]];
    [self.view addSubview:_enabledSwitch];
    
    // 抢自己红包
    UILabel *receiveSelfLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 150, 200, 40)];
    receiveSelfLabel.text = @"抢自己发的红包";
    [self.view addSubview:receiveSelfLabel];
    
    _receiveSelfSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(250, 150, 60, 40)];
    [_receiveSelfSwitch setOn:[defaults boolForKey:@"DD_RedEnvelop_ReceiveSelf"]];
    [self.view addSubview:_receiveSelfSwitch];
    
    // 个人红包
    UILabel *personalLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 200, 200, 40)];
    personalLabel.text = @"抢个人红包";
    [self.view addSubview:personalLabel];
    
    _personalSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(250, 200, 60, 40)];
    [_personalSwitch setOn:[defaults boolForKey:@"DD_RedEnvelop_PersonalEnabled"]];
    [self.view addSubview:_personalSwitch];
    
    // 串行模式
    UILabel *serialLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 250, 200, 40)];
    serialLabel.text = @"串行模式";
    [self.view addSubview:serialLabel];
    
    _serialSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(250, 250, 60, 40)];
    [_serialSwitch setOn:[defaults boolForKey:@"DD_RedEnvelop_SerialMode"]];
    [self.view addSubview:_serialSwitch];
    
    // 延迟秒数
    UILabel *delayLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 300, 200, 40)];
    delayLabel.text = @"延迟秒数";
    [self.view addSubview:delayLabel];
    
    _delayField = [[UITextField alloc] initWithFrame:CGRectMake(150, 300, 100, 40)];
    _delayField.borderStyle = UITextBorderStyleRoundedRect;
    _delayField.keyboardType = UIKeyboardTypeNumberPad;
    _delayField.text = [NSString stringWithFormat:@"%ld", [defaults integerForKey:@"DD_RedEnvelop_Delay"]];
    [self.view addSubview:_delayField];
    
    // 保存按钮
    _saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    _saveButton.frame = CGRectMake(100, 400, 120, 44);
    [_saveButton setTitle:@"保存设置" forState:UIControlStateNormal];
    [_saveButton addTarget:self action:@selector(saveSettings) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_saveButton];
}

%new
- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:_enabledSwitch.isOn forKey:@"DD_RedEnvelop_Enabled"];
    [defaults setBool:_receiveSelfSwitch.isOn forKey:@"DD_RedEnvelop_ReceiveSelf"];
    [defaults setBool:_personalSwitch.isOn forKey:@"DD_RedEnvelop_PersonalEnabled"];
    [defaults setBool:_serialSwitch.isOn forKey:@"DD_RedEnvelop_SerialMode"];
    [defaults setInteger:[_delayField.text integerValue] forKey:@"DD_RedEnvelop_Delay"];
    [defaults synchronize];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"设置已保存" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end