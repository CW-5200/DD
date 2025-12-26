// Required frameworks
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

// MARK: - 插件配置系统
@interface DDRedEnvelopConfig : NSObject

@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) BOOL autoReceive;
@property (nonatomic, assign) BOOL receiveSelf;
@property (nonatomic, assign) BOOL personalEnabled;
@property (nonatomic, assign) BOOL serialMode;
@property (nonatomic, assign) NSInteger delaySeconds;
@property (nonatomic, strong) NSMutableArray *blackList;
@property (nonatomic, assign) NSInteger version;
@property (nonatomic, strong) NSString *lastUpdate;

+ (instancetype)sharedConfig;
- (void)saveConfig;
- (void)loadConfig;
- (BOOL)isInBlackList:(NSString *)userName;

@end

@implementation DDRedEnvelopConfig

+ (instancetype)sharedConfig {
    static DDRedEnvelopConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        instance.enabled = YES;
        instance.autoReceive = YES;
        instance.receiveSelf = NO;
        instance.personalEnabled = YES;
        instance.serialMode = YES;
        instance.delaySeconds = 0;
        instance.blackList = [NSMutableArray array];
        instance.version = 100; // 1.0.0
        instance.lastUpdate = @"2025-12-26";
        [instance loadConfig];
    });
    return instance;
}

- (void)loadConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _enabled = [defaults boolForKey:@"DD_RedEnvelop_Enabled"];
    _autoReceive = [defaults boolForKey:@"DD_RedEnvelop_AutoReceive"];
    _receiveSelf = [defaults boolForKey:@"DD_RedEnvelop_ReceiveSelf"];
    _personalEnabled = [defaults boolForKey:@"DD_RedEnvelop_PersonalEnabled"];
    _serialMode = [defaults boolForKey:@"DD_RedEnvelop_SerialMode"];
    _delaySeconds = [defaults integerForKey:@"DD_RedEnvelop_DelaySeconds"];
    
    NSArray *savedList = [defaults arrayForKey:@"DD_RedEnvelop_BlackList"];
    if (savedList) {
        _blackList = [savedList mutableCopy];
    }
}

- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:_enabled forKey:@"DD_RedEnvelop_Enabled"];
    [defaults setBool:_autoReceive forKey:@"DD_RedEnvelop_AutoReceive"];
    [defaults setBool:_receiveSelf forKey:@"DD_RedEnvelop_ReceiveSelf"];
    [defaults setBool:_personalEnabled forKey:@"DD_RedEnvelop_PersonalEnabled"];
    [defaults setBool:_serialMode forKey:@"DD_RedEnvelop_SerialMode"];
    [defaults setInteger:_delaySeconds forKey:@"DD_RedEnvelop_DelaySeconds"];
    [defaults setObject:_blackList forKey:@"DD_RedEnvelop_BlackList"];
    [defaults synchronize];
}

- (BOOL)isInBlackList:(NSString *)userName {
    if (!userName || userName.length == 0) return NO;
    return [_blackList containsObject:userName];
}

@end

// MARK: - 红包参数模型
@interface DDRedEnvelopParam : NSObject

@property (nonatomic, copy) NSString *msgType;
@property (nonatomic, copy) NSString *sendId;
@property (nonatomic, copy) NSString *channelId;
@property (nonatomic, copy) NSString *nativeUrl;
@property (nonatomic, copy) NSString *sessionUserName;
@property (nonatomic, copy) NSString *sign;
@property (nonatomic, copy) NSString *timingIdentifier;
@property (nonatomic, assign) BOOL isGroupSender;

+ (instancetype)paramWithNativeUrl:(NSString *)nativeUrl;
- (NSDictionary *)toDictionary;

@end

@implementation DDRedEnvelopParam

+ (instancetype)paramWithNativeUrl:(NSString *)nativeUrl {
    if (!nativeUrl) return nil;
    
    DDRedEnvelopParam *param = [[DDRedEnvelopParam alloc] init];
    
    // 解析nativeUrl中的参数
    NSArray *components = [nativeUrl componentsSeparatedByString:@"&"];
    for (NSString *comp in components) {
        if ([comp hasPrefix:@"msgtype="]) {
            param.msgType = [comp substringFromIndex:8];
        } else if ([comp hasPrefix:@"sendid="]) {
            param.sendId = [comp substringFromIndex:7];
        } else if ([comp hasPrefix:@"channelid="]) {
            param.channelId = [comp substringFromIndex:10];
        } else if ([comp hasPrefix:@"nativeurl="]) {
            param.nativeUrl = [comp substringFromIndex:10];
        } else if ([comp hasPrefix:@"sign="]) {
            param.sign = [comp substringFromIndex:5];
        }
    }
    
    param.isGroupSender = [nativeUrl containsString:@"sendusername="];
    return param;
}

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    if (_msgType) [dict setObject:_msgType forKey:@"msgType"];
    if (_sendId) [dict setObject:_sendId forKey:@"sendId"];
    if (_channelId) [dict setObject:_channelId forKey:@"channelId"];
    if (_nativeUrl) [dict setObject:_nativeUrl forKey:@"nativeUrl"];
    if (_sessionUserName) [dict setObject:_sessionUserName forKey:@"sessionUserName"];
    if (_sign) [dict setObject:_sign forKey:@"sign"];
    if (_timingIdentifier) [dict setObject:_timingIdentifier forKey:@"timingIdentifier"];
    [dict setObject:@(_isGroupSender) forKey:@"isGroupSender"];
    return dict;
}

@end

// MARK: - Hook WCRedEnvelopesLogicMgr (基于头文件的方法名)
__attribute__((constructor)) static void initialize() {
    NSLog(@"[DD红包] 插件初始化 v1.0.0");
    
    // 注册到插件系统
    if (NSClassFromString(@"WCPluginsMgr")) {
        [[objc_getClass("WCPluginsMgr") sharedInstance] 
            registerSwitchWithTitle:@"DD红包" 
                                key:@"DD_RedEnvelop_Enabled"];
    }
}

// Hook红包查询响应
void hook_WCRedEnvelopesLogicMgr_OnWCToHongbaoCommonResponse(id self, SEL _cmd, id response, id request) {
    // 调用原始实现
    void (*orig)(id, SEL, id, id) = (void (*)(id, SEL, id, id))class_getMethodImplementation([self class], _cmd);
    if (orig) {
        orig(self, _cmd, response, request);
    }
    
    // 检查插件是否启用
    if (![[DDRedEnvelopConfig sharedConfig] enabled]) {
        return;
    }
    
    if (![[DDRedEnvelopConfig sharedConfig] autoReceive]) {
        return;
    }
    
    @try {
        // 获取cgiCmdid - 根据头文件，这是查询请求
        unsigned int cgiCmdid = 0;
        if ([response respondsToSelector:@selector(cgiCmdid)]) {
            cgiCmdid = (unsigned int)[response performSelector:@selector(cgiCmdid)];
        }
        
        // 只处理查询请求(cgiCmdid == 3)
        if (cgiCmdid != 3) {
            return;
        }
        
        // 解析响应数据
        NSData *responseData = nil;
        if ([response respondsToSelector:@selector(retText)]) {
            id retText = [response performSelector:@selector(retText)];
            if ([retText respondsToSelector:@selector(buffer)]) {
                responseData = [retText performSelector:@selector(buffer)];
            }
        }
        
        if (!responseData) {
            return;
        }
        
        NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        
        // 解析JSON
        NSError *error = nil;
        NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        
        if (error || !responseDict) {
            return;
        }
        
        // 检查红包状态
        NSNumber *receiveStatus = responseDict[@"receiveStatus"];
        NSNumber *hbStatus = responseDict[@"hbStatus"];
        NSString *timingIdentifier = responseDict[@"timingIdentifier"];
        
        if (!timingIdentifier || 
            (receiveStatus && [receiveStatus integerValue] == 2) || 
            (hbStatus && [hbStatus integerValue] == 4)) {
            return;
        }
        
        // 解析请求参数获取sign
        NSString *sign = nil;
        if ([request respondsToSelector:@selector(reqText)]) {
            id reqText = [request performSelector:@selector(reqText)];
            if ([reqText respondsToSelector:@selector(buffer)]) {
                NSData *reqData = [reqText performSelector:@selector(buffer)];
                if (reqData) {
                    NSString *reqString = [[NSString alloc] initWithData:reqData encoding:NSUTF8StringEncoding];
                    NSArray *reqComponents = [reqString componentsSeparatedByString:@"&"];
                    for (NSString *comp in reqComponents) {
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
        
        if (!sign) {
            return;
        }
        
        // 获取发送者信息
        NSString *sendUserName = nil;
        if ([request respondsToSelector:@selector(reqText)]) {
            id reqText = [request performSelector:@selector(reqText)];
            if ([reqText respondsToSelector:@selector(buffer)]) {
                NSData *reqData = [reqText performSelector:@selector(buffer)];
                if (reqData) {
                    NSString *reqString = [[NSString alloc] initWithData:reqData encoding:NSUTF8StringEncoding];
                    NSArray *reqComponents = [reqString componentsSeparatedByString:@"&"];
                    for (NSString *comp in reqComponents) {
                        if ([comp hasPrefix:@"sendusername="]) {
                            sendUserName = [comp substringFromIndex:13];
                            break;
                        }
                    }
                }
            }
        }
        
        // 检查黑名单
        if (sendUserName && [[DDRedEnvelopConfig sharedConfig] isInBlackList:sendUserName]) {
            return;
        }
        
        // 检查是否抢自己发的红包
        if (sendUserName && ![[DDRedEnvelopConfig sharedConfig] receiveSelf]) {
            Class contactMgrClass = objc_getClass("CContactMgr");
            if (contactMgrClass) {
                id mmServiceCenter = objc_getClass("MMServiceCenter");
                if (mmServiceCenter) {
                    id defaultCenter = [mmServiceCenter performSelector:@selector(defaultCenter)];
                    if (defaultCenter) {
                        id contactMgr = [defaultCenter performSelector:@selector(getService:) withObject:contactMgrClass];
                        if (contactMgr && [contactMgr respondsToSelector:@selector(getSelfContact)]) {
                            id selfContact = [contactMgr performSelector:@selector(getSelfContact)];
                            if (selfContact && [selfContact respondsToSelector:@selector(m_nsUsrName)]) {
                                NSString *myUserName = [selfContact performSelector:@selector(m_nsUsrName)];
                                if ([sendUserName isEqualToString:myUserName]) {
                                    return;
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // 准备红包参数
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        [params setObject:sign forKey:@"sign"];
        [params setObject:timingIdentifier forKey:@"timingIdentifier"];
        [params setObject:responseDict[@"sendId"] ?: @"" forKey:@"sendId"];
        [params setObject:responseDict[@"channelId"] ?: @"" forKey:@"channelId"];
        [params setObject:responseDict[@"msgType"] ?: @"" forKey:@"msgType"];
        
        // 延迟执行
        NSInteger delay = [[DDRedEnvelopConfig sharedConfig] delaySeconds];
        if (delay > 0) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [self openRedEnvelopWithParams:params];
            });
        } else {
            [self openRedEnvelopWithParams:params];
        }
        
    } @catch (NSException *exception) {
        NSLog(@"[DD红包] 处理异常: %@", exception);
    }
}

// Hook消息管理器处理红包消息
void hook_CMessageMgr_AsyncOnAddMsg(id self, SEL _cmd, NSString *msg, id msgWrap) {
    // 调用原始实现
    void (*orig)(id, SEL, NSString *, id) = (void (*)(id, SEL, NSString *, id))class_getMethodImplementation([self class], _cmd);
    if (orig) {
        orig(self, _cmd, msg, msgWrap);
    }
    
    // 检查插件是否启用
    if (![[DDRedEnvelopConfig sharedConfig] enabled]) {
        return;
    }
    
    @try {
        // 获取消息类型
        unsigned int messageType = 0;
        if ([msgWrap respondsToSelector:@selector(m_uiMessageType)]) {
            messageType = (unsigned int)[msgWrap performSelector:@selector(m_uiMessageType)];
        }
        
        // 只处理49类型(红包消息)
        if (messageType != 49) {
            return;
        }
        
        // 获取消息内容
        NSString *content = nil;
        if ([msgWrap respondsToSelector:@selector(m_nsContent)]) {
            content = [msgWrap performSelector:@selector(m_nsContent)];
        }
        
        if (!content || ![content containsString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"]) {
            return;
        }
        
        // 获取发送者
        NSString *fromUsr = nil;
        if ([msgWrap respondsToSelector:@selector(m_nsFromUsr)]) {
            fromUsr = [msgWrap performSelector:@selector(m_nsFromUsr)];
        }
        
        // 获取接收者
        NSString *toUsr = nil;
        if ([msgWrap respondsToSelector:@selector(m_nsToUsr)]) {
            toUsr = [msgWrap performSelector:@selector(m_nsToUsr)];
        }
        
        // 检查是否为群聊
        BOOL isGroupChat = [fromUsr containsString:@"@chatroom"] || [toUsr containsString:@"@chatroom"];
        
        // 检查个人红包开关
        if (!isGroupChat && ![[DDRedEnvelopConfig sharedConfig] personalEnabled]) {
            return;
        }
        
        // 检查黑名单
        if (fromUsr && [[DDRedEnvelopConfig sharedConfig] isInBlackList:fromUsr]) {
            return;
        }
        
        // 记录日志
        NSLog(@"[DD红包] 检测到红包消息 from: %@, to: %@", fromUsr, toUsr);
        
        // 解析红包URL
        NSRange range = [content rangeOfString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"];
        if (range.location != NSNotFound) {
            NSString *nativeUrl = [content substringFromIndex:range.location];
            DDRedEnvelopParam *param = [DDRedEnvelopParam paramWithNativeUrl:nativeUrl];
            param.sessionUserName = fromUsr;
            
            // 可以在这里存储参数供后续使用
            NSLog(@"[DD红包] 红包参数: %@", [param toDictionary]);
        }
        
    } @catch (NSException *exception) {
        NSLog(@"[DD红包] 消息处理异常: %@", exception);
    }
}

// MARK: - Hook安装
__attribute__((constructor)) static void installHooks() {
    @autoreleasepool {
        // Hook WCRedEnvelopesLogicMgr的OnWCToHongbaoCommonResponse方法
        Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
        if (logicMgrClass) {
            Method originalMethod = class_getInstanceMethod(logicMgrClass, @selector(OnWCToHongbaoCommonResponse:Request:));
            if (originalMethod) {
                method_setImplementation(originalMethod, (IMP)hook_WCRedEnvelopesLogicMgr_OnWCToHongbaoCommonResponse);
                NSLog(@"[DD红包] Hook WCRedEnvelopesLogicMgr成功");
            } else {
                NSLog(@"[DD红包] 未找到OnWCToHongbaoCommonResponse方法");
            }
        }
        
        // Hook CMessageMgr的AsyncOnAddMsg方法
        Class messageMgrClass = objc_getClass("CMessageMgr");
        if (messageMgrClass) {
            Method originalMethod = class_getInstanceMethod(messageMgrClass, @selector(AsyncOnAddMsg:MsgWrap:));
            if (originalMethod) {
                method_setImplementation(originalMethod, (IMP)hook_CMessageMgr_AsyncOnAddMsg);
                NSLog(@"[DD红包] Hook CMessageMgr成功");
            } else {
                NSLog(@"[DD红包] 未找到AsyncOnAddMsg方法");
            }
        }
        
        // 添加打开红包的方法到WCRedEnvelopesLogicMgr
        if (logicMgrClass) {
            class_addMethod(logicMgrClass, @selector(openRedEnvelopWithParams:), (IMP)openRedEnvelopImplementation, "v@:@");
        }
    }
}

// 打开红包的实现
void openRedEnvelopImplementation(id self, SEL _cmd, NSDictionary *params) {
    NSLog(@"[DD红包] 执行抢红包: %@", params);
    
    // 这里调用微信的OpenRedEnvelopesRequest方法
    SEL openSel = @selector(OpenRedEnvelopesRequest:);
    if ([self respondsToSelector:openSel]) {
        // 创建请求对象
        NSMutableDictionary *requestDict = [NSMutableDictionary dictionary];
        [requestDict setObject:params[@"sendId"] ?: @"" forKey:@"sendId"];
        [requestDict setObject:params[@"channelId"] ?: @"" forKey:@"channelId"];
        [requestDict setObject:params[@"msgType"] ?: @"" forKey:@"msgType"];
        [requestDict setObject:params[@"nativeUrl"] ?: @"" forKey:@"nativeUrl"];
        [requestDict setObject:params[@"sign"] ?: @"" forKey:@"sign"];
        [requestDict setObject:params[@"timingIdentifier"] ?: @"" forKey:@"timingIdentifier"];
        
        @try {
            [self performSelector:openSel withObject:requestDict];
        } @catch (NSException *exception) {
            NSLog(@"[DD红包] 调用OpenRedEnvelopesRequest失败: %@", exception);
        }
    }
}

// MARK: - 设置界面
@interface DDRedEnvelopSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *settingsItems;

@end

@implementation DDRedEnvelopSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD红包设置";
    self.view.backgroundColor = [UIColor whiteColor];
    
    self.settingsItems = @[
        @{@"type": @"switch", @"title": @"启用插件", @"key": @"DD_RedEnvelop_Enabled"},
        @{@"type": @"switch", @"title": @"自动抢红包", @"key": @"DD_RedEnvelop_AutoReceive"},
        @{@"type": @"switch", @"title": @"抢自己发的", @"key": @"DD_RedEnvelop_ReceiveSelf"},
        @{@"type": @"switch", @"title": @"抢个人红包", @"key": @"DD_RedEnvelop_PersonalEnabled"},
        @{@"type": @"switch", @"title": @"串行模式", @"key": @"DD_RedEnvelop_SerialMode"},
        @{@"type": @"input", @"title": @"延迟秒数", @"key": @"DD_RedEnvelop_DelaySeconds"},
        @{@"type": @"button", @"title": @"保存设置", @"action": @"saveSettings"}
    ];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.settingsItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
    }
    
    NSDictionary *item = self.settingsItems[indexPath.row];
    NSString *type = item[@"type"];
    NSString *title = item[@"title"];
    
    cell.textLabel.text = title;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if ([type isEqualToString:@"switch"]) {
        NSString *key = item[@"key"];
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [[NSUserDefaults standardUserDefaults] boolForKey:key];
        [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        switchView.tag = indexPath.row;
        cell.accessoryView = switchView;
    } else if ([type isEqualToString:@"input"]) {
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 100, 30)];
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.textAlignment = NSTextAlignmentRight;
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%ld", [[DDRedEnvelopConfig sharedConfig] delaySeconds]];
        textField.tag = indexPath.row;
        cell.accessoryView = textField;
    } else if ([type isEqualToString:@"button"]) {
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [UIColor systemBlueColor];
    }
    
    return cell;
}

- (void)switchChanged:(UISwitch *)sender {
    NSDictionary *item = self.settingsItems[sender.tag];
    NSString *key = item[@"key"];
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *item = self.settingsItems[indexPath.row];
    if ([item[@"type"] isEqualToString:@"button"]) {
        [[DDRedEnvelopConfig sharedConfig] saveConfig];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"设置已保存" preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

@end