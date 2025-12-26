#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>

// MARK: - 插件配置
@interface DDRedEnvelopConfig : NSObject
+ (instancetype)shared;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL autoReceive;
@property (nonatomic, assign) BOOL receiveSelf;
@property (nonatomic, assign) BOOL personalEnabled;
@property (nonatomic, assign) NSInteger delay;
@end

@implementation DDRedEnvelopConfig
+ (instancetype)shared {
    static DDRedEnvelopConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.enabled = YES;
        instance.autoReceive = YES;
        instance.receiveSelf = NO;
        instance.personalEnabled = YES;
        instance.delay = 0;
    });
    return instance;
}
@end

// MARK: - Hook WCRedEnvelopesLogicMgr
// 根据头文件 WCRedEnvelopesLogicMgr.h，有以下关键方法：
// - (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2;
// - (void)OpenRedEnvelopesRequest:(id)arg1;

static void (*original_OnWCToHongbaoCommonResponse)(id, SEL, id, id) = NULL;

void hooked_OnWCToHongbaoCommonResponse(id self, SEL _cmd, id response, id request) {
    // 调用原始方法
    if (original_OnWCToHongbaoCommonResponse) {
        original_OnWCToHongbaoCommonResponse(self, _cmd, response, request);
    }
    
    if (![DDRedEnvelopConfig shared].enabled || ![DDRedEnvelopConfig shared].autoReceive) {
        return;
    }
    
    @try {
        // 根据头文件，arg1可能是HongBaoRes，arg2是HongBaoReq
        // 我们假设response有cgiCmdid属性
        unsigned int cgiCmdid = 0;
        
        // 尝试获取cgiCmdid - 方法1: KVC
        @try {
            id cmdIdValue = [response valueForKey:@"cgiCmdid"];
            if (cmdIdValue && [cmdIdValue respondsToSelector:@selector(unsignedIntValue)]) {
                cgiCmdid = [cmdIdValue unsignedIntValue];
            }
        } @catch (NSException *e) {}
        
        // 方法2: 直接调用方法
        if (cgiCmdid == 0 && [response respondsToSelector:@selector(cgiCmdid)]) {
            cgiCmdid = (unsigned int)[response performSelector:@selector(cgiCmdid)];
        }
        
        // 只处理查询请求 (cgiCmdid == 3)
        if (cgiCmdid != 3) {
            return;
        }
        
        // 获取响应数据
        NSString *responseString = nil;
        @try {
            if ([response respondsToSelector:@selector(retText)]) {
                id retText = [response performSelector:@selector(retText)];
                if ([retText respondsToSelector:@selector(buffer)]) {
                    NSData *buffer = [retText performSelector:@selector(buffer)];
                    if (buffer) {
                        responseString = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
                    }
                }
            }
        } @catch (NSException *e) {}
        
        if (!responseString || responseString.length == 0) {
            return;
        }
        
        // 解析JSON
        NSData *jsonData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
        NSError *error = nil;
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
        
        if (error || !responseDict) {
            return;
        }
        
        // 检查红包状态
        id receiveStatus = responseDict[@"receiveStatus"];
        id hbStatus = responseDict[@"hbStatus"];
        id timingIdentifier = responseDict[@"timingIdentifier"];
        
        if (!timingIdentifier || 
            (receiveStatus && [receiveStatus intValue] == 2) || 
            (hbStatus && [hbStatus intValue] == 4)) {
            return;
        }
        
        // 获取sign
        NSString *sign = nil;
        @try {
            if ([request respondsToSelector:@selector(reqText)]) {
                id reqText = [request performSelector:@selector(reqText)];
                if ([reqText respondsToSelector:@selector(buffer)]) {
                    NSData *buffer = [reqText performSelector:@selector(buffer)];
                    if (buffer) {
                        NSString *requestString = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
                        
                        // 解析请求参数
                        NSArray *components = [requestString componentsSeparatedByString:@"&"];
                        for (NSString *comp in components) {
                            if ([comp hasPrefix:@"nativeurl="]) {
                                NSString *nativeUrl = [[comp substringFromIndex:10] stringByRemovingPercentEncoding];
                                NSArray *urlComponents = [nativeUrl componentsSeparatedByString:@"&"];
                                for (NSString *urlComp in urlComponents) {
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
        } @catch (NSException *e) {}
        
        if (!sign) {
            return;
        }
        
        // 获取发送者
        NSString *sendUserName = nil;
        @try {
            if ([request respondsToSelector:@selector(reqText)]) {
                id reqText = [request performSelector:@selector(reqText)];
                if ([reqText respondsToSelector:@selector(buffer)]) {
                    NSData *buffer = [reqText performSelector:@selector(buffer)];
                    if (buffer) {
                        NSString *requestString = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
                        NSArray *components = [requestString componentsSeparatedByString:@"&"];
                        for (NSString *comp in components) {
                            if ([comp hasPrefix:@"sendusername="]) {
                                sendUserName = [comp substringFromIndex:13];
                                break;
                            }
                        }
                    }
                }
            }
        } @catch (NSException *e) {}
        
        // 检查是否抢自己发的红包
        if (sendUserName && ![DDRedEnvelopConfig shared].receiveSelf) {
            Class contactMgrClass = objc_getClass("CContactMgr");
            if (contactMgrClass) {
                Class mmServiceCenterClass = objc_getClass("MMServiceCenter");
                if (mmServiceCenterClass) {
                    id defaultCenter = [mmServiceCenterClass performSelector:@selector(defaultCenter)];
                    id contactMgr = [defaultCenter performSelector:@selector(getService:) withObject:contactMgrClass];
                    if (contactMgr) {
                        id selfContact = [contactMgr performSelector:@selector(getSelfContact)];
                        if (selfContact) {
                            NSString *myUserName = [selfContact performSelector:@selector(m_nsUsrName)];
                            if ([sendUserName isEqualToString:myUserName]) {
                                return;
                            }
                        }
                    }
                }
            }
        }
        
        // 延迟执行
        NSInteger delay = [DDRedEnvelopConfig shared].delay;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self performOpenRedEnvelopWithResponse:responseDict sign:sign];
        });
        
    } @catch (NSException *exception) {
        NSLog(@"[DD红包] 处理异常: %@", exception);
    }
}

// MARK: - Hook CMessageMgr
// 根据头文件 CMessageMgr.h，有以下关键方法：
// - (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap;

static void (*original_AsyncOnAddMsg)(id, SEL, NSString *, id) = NULL;

void hooked_AsyncOnAddMsg(id self, SEL _cmd, NSString *msg, id wrap) {
    // 调用原始方法
    if (original_AsyncOnAddMsg) {
        original_AsyncOnAddMsg(self, _cmd, msg, wrap);
    }
    
    if (![DDRedEnvelopConfig shared].enabled) {
        return;
    }
    
    @try {
        // 获取消息类型
        unsigned int msgType = 0;
        if ([wrap respondsToSelector:@selector(m_uiMessageType)]) {
            msgType = (unsigned int)[wrap performSelector:@selector(m_uiMessageType)];
        }
        
        // 只处理49类型（红包消息）
        if (msgType != 49) {
            return;
        }
        
        // 获取消息内容
        NSString *content = nil;
        if ([wrap respondsToSelector:@selector(m_nsContent)]) {
            content = [wrap performSelector:@selector(m_nsContent)];
        }
        
        if (!content || ![content containsString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"]) {
            return;
        }
        
        // 获取发送者
        NSString *fromUsr = nil;
        if ([wrap respondsToSelector:@selector(m_nsFromUsr)]) {
            fromUsr = [wrap performSelector:@selector(m_nsFromUsr)];
        }
        
        // 获取接收者
        NSString *toUsr = nil;
        if ([wrap respondsToSelector:@selector(m_nsToUsr)]) {
            toUsr = [wrap performSelector:@selector(m_nsToUsr)];
        }
        
        // 检查是否为群聊
        BOOL isGroupChat = [fromUsr containsString:@"@chatroom"] || [toUsr containsString:@"@chatroom"];
        
        // 检查个人红包开关
        if (!isGroupChat && ![DDRedEnvelopConfig shared].personalEnabled) {
            return;
        }
        
        // 记录检测到红包
        NSLog(@"[DD红包] 检测到红包消息 from:%@ to:%@", fromUsr, toUsr);
        
        // 提取nativeUrl参数
        NSRange range = [content rangeOfString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"];
        if (range.location != NSNotFound) {
            NSString *nativeUrlPart = [content substringFromIndex:range.location];
            // 这里可以解析红包参数，但实际抢红包在OnWCToHongbaoCommonResponse中处理
        }
        
    } @catch (NSException *exception) {
        NSLog(@"[DD红包] 消息处理异常: %@", exception);
    }
}

// MARK: - 打开红包的辅助方法
void performOpenRedEnvelopWithResponse(id self, NSDictionary *responseDict, NSString *sign) {
    @try {
        // 根据头文件，调用OpenRedEnvelopesRequest:方法
        SEL openSel = @selector(OpenRedEnvelopesRequest:);
        if ([self respondsToSelector:openSel]) {
            // 构建请求参数
            NSMutableDictionary *params = [NSMutableDictionary dictionary];
            [params setObject:responseDict[@"sendId"] ?: @"" forKey:@"sendId"];
            [params setObject:responseDict[@"channelId"] ?: @"" forKey:@"channelId"];
            [params setObject:responseDict[@"msgType"] ?: @"" forKey:@"msgType"];
            [params setObject:sign ?: @"" forKey:@"sign"];
            [params setObject:responseDict[@"timingIdentifier"] ?: @"" forKey:@"timingIdentifier"];
            
            [self performSelector:openSel withObject:params];
            NSLog(@"[DD红包] 已尝试抢红包 sendId:%@", responseDict[@"sendId"]);
        }
    } @catch (NSException *exception) {
        NSLog(@"[DD红包] 打开红包异常: %@", exception);
    }
}

// MARK: - 插件安装
__attribute__((constructor)) static void installPlugin() {
    NSLog(@"[DD红包] 插件加载 v1.0.0");
    
    // 延迟执行，确保类已加载
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        // Hook WCRedEnvelopesLogicMgr
        Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
        if (logicMgrClass) {
            Method method = class_getInstanceMethod(logicMgrClass, @selector(OnWCToHongbaoCommonResponse:Request:));
            if (method) {
                original_OnWCToHongbaoCommonResponse = (void (*)(id, SEL, id, id))method_getImplementation(method);
                method_setImplementation(method, (IMP)hooked_OnWCToHongbaoCommonResponse);
                NSLog(@"[DD红包] Hook WCRedEnvelopesLogicMgr成功");
            } else {
                NSLog(@"[DD红包] 未找到OnWCToHongbaoCommonResponse方法");
            }
        }
        
        // Hook CMessageMgr
        Class messageMgrClass = objc_getClass("CMessageMgr");
        if (messageMgrClass) {
            Method method = class_getInstanceMethod(messageMgrClass, @selector(AsyncOnAddMsg:MsgWrap:));
            if (method) {
                original_AsyncOnAddMsg = (void (*)(id, SEL, NSString *, id))method_getImplementation(method);
                method_setImplementation(method, (IMP)hooked_AsyncOnAddMsg);
                NSLog(@"[DD红包] Hook CMessageMgr成功");
            } else {
                NSLog(@"[DD红包] 未找到AsyncOnAddMsg方法");
            }
        }
        
        // 注册到插件系统
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerSwitchWithTitle:@"DD红包" key:@"DD_RedEnvelop_Enabled"];
            NSLog(@"[DD红包] 已注册到插件系统");
        }
    });
}

// MARK: - 设置界面
@interface DDRedEnvelopSettingsController : UIViewController {
    UISwitch *_enabledSwitch;
    UISwitch *_autoReceiveSwitch;
    UISwitch *_receiveSelfSwitch;
    UISwitch *_personalSwitch;
    UITextField *_delayField;
}

- (void)saveSettings;

@end

@implementation DDRedEnvelopSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"DD红包设置";
    self.view.backgroundColor = [UIColor whiteColor];
    
    CGFloat y = 100;
    CGFloat labelWidth = 150;
    CGFloat switchX = 200;
    
    // 总开关
    UILabel *enabledLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, labelWidth, 40)];
    enabledLabel.text = @"启用插件";
    [self.view addSubview:enabledLabel];
    
    _enabledSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(switchX, y, 60, 40)];
    [_enabledSwitch setOn:[DDRedEnvelopConfig shared].enabled];
    [self.view addSubview:_enabledSwitch];
    
    y += 50;
    
    // 自动抢红包
    UILabel *autoLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, labelWidth, 40)];
    autoLabel.text = @"自动抢红包";
    [self.view addSubview:autoLabel];
    
    _autoReceiveSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(switchX, y, 60, 40)];
    [_autoReceiveSwitch setOn:[DDRedEnvelopConfig shared].autoReceive];
    [self.view addSubview:_autoReceiveSwitch];
    
    y += 50;
    
    // 抢自己发的
    UILabel *selfLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, labelWidth, 40)];
    selfLabel.text = @"抢自己发的红包";
    [self.view addSubview:selfLabel];
    
    _receiveSelfSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(switchX, y, 60, 40)];
    [_receiveSelfSwitch setOn:[DDRedEnvelopConfig shared].receiveSelf];
    [self.view addSubview:_receiveSelfSwitch];
    
    y += 50;
    
    // 个人红包
    UILabel *personalLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, labelWidth, 40)];
    personalLabel.text = @"抢个人红包";
    [self.view addSubview:personalLabel];
    
    _personalSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(switchX, y, 60, 40)];
    [_personalSwitch setOn:[DDRedEnvelopConfig shared].personalEnabled];
    [self.view addSubview:_personalSwitch];
    
    y += 50;
    
    // 延迟秒数
    UILabel *delayLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, labelWidth, 40)];
    delayLabel.text = @"延迟秒数";
    [self.view addSubview:delayLabel];
    
    _delayField = [[UITextField alloc] initWithFrame:CGRectMake(switchX, y, 100, 40)];
    _delayField.borderStyle = UITextBorderStyleRoundedRect;
    _delayField.keyboardType = UIKeyboardTypeNumberPad;
    _delayField.text = [NSString stringWithFormat:@"%ld", [DDRedEnvelopConfig shared].delay];
    [self.view addSubview:_delayField];
    
    y += 80;
    
    // 保存按钮
    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    saveButton.frame = CGRectMake(100, y, 120, 44);
    [saveButton setTitle:@"保存设置" forState:UIControlStateNormal];
    [saveButton addTarget:self action:@selector(saveSettings) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:saveButton];
}

- (void)saveSettings {
    [DDRedEnvelopConfig shared].enabled = _enabledSwitch.isOn;
    [DDRedEnvelopConfig shared].autoReceive = _autoReceiveSwitch.isOn;
    [DDRedEnvelopConfig shared].receiveSelf = _receiveSelfSwitch.isOn;
    [DDRedEnvelopConfig shared].personalEnabled = _personalSwitch.isOn;
    [DDRedEnvelopConfig shared].delay = [_delayField.text integerValue];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"设置已保存" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

// 注册设置界面
__attribute__((constructor)) static void registerSettings() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD红包设置" 
                                   version:@"1.0.0" 
                                controller:@"DDRedEnvelopSettingsController"];
        }
    });
}