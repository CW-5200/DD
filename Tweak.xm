// DD红包.x
// 仅Hook最关键的两个方法

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 插件配置
static BOOL pluginEnabled = YES;
static NSInteger delaySeconds = 0;
static BOOL receiveSelf = NO;
static BOOL personalEnabled = YES;

// Hook WCRedEnvelopesLogicMgr的OnWCToHongbaoCommonResponse方法
%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig;
    
    if (!pluginEnabled) return;
    
    @try {
        // 获取cgiCmdid
        unsigned int cgiCmdid = 0;
        if ([arg1 respondsToSelector:@selector(cgiCmdid)]) {
            cgiCmdid = [(NSNumber *)[arg1 valueForKey:@"cgiCmdid"] unsignedIntValue];
        }
        
        // 只处理查询请求(cgiCmdid == 3)
        if (cgiCmdid != 3) return;
        
        // 获取响应数据
        NSData *responseData = nil;
        if ([arg1 respondsToSelector:@selector(retText)]) {
            id retText = [arg1 performSelector:@selector(retText)];
            if ([retText respondsToSelector:@selector(buffer)]) {
                responseData = [retText performSelector:@selector(buffer)];
            }
        }
        
        if (!responseData) return;
        
        NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        
        // 解析JSON响应
        NSData *jsonData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
        
        if (!responseDict) return;
        
        // 检查红包状态
        NSInteger receiveStatus = [responseDict[@"receiveStatus"] integerValue];
        NSInteger hbStatus = [responseDict[@"hbStatus"] integerValue];
        NSString *timingIdentifier = responseDict[@"timingIdentifier"];
        
        if (receiveStatus == 2 || hbStatus == 4 || !timingIdentifier) {
            return;
        }
        
        // 获取请求中的sign
        NSString *sign = nil;
        if ([arg2 respondsToSelector:@selector(reqText)]) {
            id reqText = [arg2 performSelector:@selector(reqText)];
            if ([reqText respondsToSelector:@selector(buffer)]) {
                NSData *reqData = [reqText performSelector:@selector(buffer)];
                if (reqData) {
                    NSString *reqString = [[NSString alloc] initWithData:reqData encoding:NSUTF8StringEncoding];
                    
                    // 解析请求参数
                    NSArray *components = [reqString componentsSeparatedByString:@"&"];
                    for (NSString *comp in components) {
                        if ([comp hasPrefix:@"nativeurl="]) {
                            NSString *nativeUrl = [[comp substringFromIndex:10] stringByRemovingPercentEncoding];
                            NSArray *urlComps = [nativeUrl componentsSeparatedByString:@"&"];
                            for (NSString *urlComp in urlComps) {
                                if ([urlComp hasPrefix:@"sign="]) {
                                    sign = [urlComp substringFromIndex:5];
                                    break;
                                }
                            }
                            break;
                        }
                    }
                }
            }
        }
        
        if (!sign) return;
        
        // 延迟执行
        if (delaySeconds > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delaySeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self openRedEnvelopWithDict:responseDict sign:sign];
            });
        } else {
            [self openRedEnvelopWithDict:responseDict sign:sign];
        }
        
    } @catch (NSException *e) {
        // 静默处理异常
    }
}

// 新增方法：打开红包
%new
- (void)openRedEnvelopWithDict:(NSDictionary *)dict sign:(NSString *)sign {
    @try {
        // 调用微信的OpenRedEnvelopesRequest方法
        SEL openSel = @selector(OpenRedEnvelopesRequest:);
        if ([self respondsToSelector:openSel]) {
            NSMutableDictionary *params = [NSMutableDictionary dictionary];
            [params setObject:dict[@"sendId"] ?: @"" forKey:@"sendId"];
            [params setObject:dict[@"channelId"] ?: @"" forKey:@"channelId"];
            [params setObject:dict[@"msgType"] ?: @"" forKey:@"msgType"];
            [params setObject:sign forKey:@"sign"];
            [params setObject:dict[@"timingIdentifier"] ?: @"" forKey:@"timingIdentifier"];
            
            [self performSelector:openSel withObject:params];
        }
    } @catch (NSException *e) {
        // 静默处理异常
    }
}

%end

// Hook CMessageMgr的AsyncOnAddMsg方法
%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(id)wrap {
    %orig;
    
    if (!pluginEnabled) return;
    
    @try {
        // 获取消息类型
        unsigned int msgType = 0;
        if ([wrap respondsToSelector:@selector(m_uiMessageType)]) {
            msgType = [(NSNumber *)[wrap valueForKey:@"m_uiMessageType"] unsignedIntValue];
        }
        
        // 只处理49类型（红包消息）
        if (msgType != 49) return;
        
        // 获取消息内容
        NSString *content = nil;
        if ([wrap respondsToSelector:@selector(m_nsContent)]) {
            content = [wrap valueForKey:@"m_nsContent"];
        }
        
        // 检查是否为红包消息
        if (!content || ![content containsString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"]) {
            return;
        }
        
        // 获取发送者
        NSString *fromUsr = nil;
        if ([wrap respondsToSelector:@selector(m_nsFromUsr)]) {
            fromUsr = [wrap valueForKey:@"m_nsFromUsr"];
        }
        
        // 获取接收者
        NSString *toUsr = nil;
        if ([wrap respondsToSelector:@selector(m_nsToUsr)]) {
            toUsr = [wrap valueForKey:@"m_nsToUsr"];
        }
        
        // 检查是否为群聊
        BOOL isGroupChat = [fromUsr containsString:@"@chatroom"] || [toUsr containsString:@"@chatroom"];
        
        // 检查个人红包开关
        if (!isGroupChat && !personalEnabled) {
            return;
        }
        
        // 记录日志
        NSLog(@"[DD红包] 检测到红包 from:%@", fromUsr);
        
    } @catch (NSException *e) {
        // 静默处理异常
    }
}

%end

// 插件初始化
%ctor {
    NSLog(@"[DD红包] 插件加载 v1.0.0");
    
    // 注册到插件系统
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerSwitchWithTitle:@"DD红包" 
                                    key:@"DD_RedEnvelop_Enabled"];
            
            // 加载设置
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            pluginEnabled = [defaults boolForKey:@"DD_RedEnvelop_Enabled"];
            delaySeconds = [defaults integerForKey:@"DD_RedEnvelop_Delay"];
            receiveSelf = [defaults boolForKey:@"DD_RedEnvelop_ReceiveSelf"];
            personalEnabled = [defaults boolForKey:@"DD_RedEnvelop_PersonalEnabled"];
        }
    });
}

// 设置界面
@interface DDRedEnvelopSettingsController : UIViewController
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
    
    UISwitch *enabledSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(250, 100, 60, 40)];
    [enabledSwitch setOn:[defaults boolForKey:@"DD_RedEnvelop_Enabled"]];
    [enabledSwitch addTarget:self action:@selector(enabledChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:enabledSwitch];
    
    // 延迟秒数
    UILabel *delayLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 150, 200, 40)];
    delayLabel.text = @"延迟秒数";
    [self.view addSubview:delayLabel];
    
    UITextField *delayField = [[UITextField alloc] initWithFrame:CGRectMake(150, 150, 100, 40)];
    delayField.borderStyle = UITextBorderStyleRoundedRect;
    delayField.keyboardType = UIKeyboardTypeNumberPad;
    delayField.text = [NSString stringWithFormat:@"%ld", [defaults integerForKey:@"DD_RedEnvelop_Delay"]];
    delayField.tag = 100;
    [self.view addSubview:delayField];
    
    // 抢自己发的
    UILabel *selfLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 200, 200, 40)];
    selfLabel.text = @"抢自己发的红包";
    [self.view addSubview:selfLabel];
    
    UISwitch *selfSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(250, 200, 60, 40)];
    [selfSwitch setOn:[defaults boolForKey:@"DD_RedEnvelop_ReceiveSelf"]];
    [selfSwitch addTarget:self action:@selector(receiveSelfChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:selfSwitch];
    
    // 个人红包
    UILabel *personalLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 250, 200, 40)];
    personalLabel.text = @"抢个人红包";
    [self.view addSubview:personalLabel];
    
    UISwitch *personalSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(250, 250, 60, 40)];
    [personalSwitch setOn:[defaults boolForKey:@"DD_RedEnvelop_PersonalEnabled"]];
    [personalSwitch addTarget:self action:@selector(personalChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:personalSwitch];
    
    // 保存按钮
    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    saveButton.frame = CGRectMake(100, 320, 120, 44);
    [saveButton setTitle:@"保存设置" forState:UIControlStateNormal];
    [saveButton addTarget:self action:@selector(saveSettings) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:saveButton];
}

%new
- (void)enabledChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"DD_RedEnvelop_Enabled"];
}

%new
- (void)receiveSelfChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"DD_RedEnvelop_ReceiveSelf"];
}

%new
- (void)personalChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:@"DD_RedEnvelop_PersonalEnabled"];
}

%new
- (void)saveSettings {
    UITextField *delayField = [self.view viewWithTag:100];
    if (delayField) {
        [[NSUserDefaults standardUserDefaults] setInteger:[delayField.text integerValue] forKey:@"DD_RedEnvelop_Delay"];
    }
    
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" 
                                                                   message:@"设置已保存" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

%end