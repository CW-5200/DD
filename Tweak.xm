#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

#pragma mark - 常量定义
#define DD_PLUGIN_NAME @"DD红包"
#define DD_PLUGIN_VERSION @"1.0.0"

#pragma mark - 配置管理
@interface DDConfig : NSObject
@property (nonatomic, assign) BOOL autoRedEnvelop;
@property (nonatomic, assign) NSInteger redEnvelopDelay;
@property (nonatomic, strong) NSArray<NSString *> *redEnvelopGroupFilter;
@property (nonatomic, assign) BOOL redEnvelopCatchMe;
@property (nonatomic, assign) BOOL redEnvelopMultipleCatch;

+ (instancetype)shared;
- (void)saveConfig;
@end

@implementation DDConfig {
    NSUserDefaults *_userDefaults;
}

+ (instancetype)shared {
    static DDConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DDConfig alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.dd.redenvelop"];
        [self loadConfig];
    }
    return self;
}

- (void)loadConfig {
    self.autoRedEnvelop = [_userDefaults boolForKey:@"dd_auto_red_envelop"] ?: YES;
    self.redEnvelopDelay = [_userDefaults integerForKey:@"dd_red_envelop_delay"] ?: 0;
    self.redEnvelopGroupFilter = [_userDefaults arrayForKey:@"dd_red_envelop_group_filter"] ?: @[];
    self.redEnvelopCatchMe = [_userDefaults boolForKey:@"dd_red_envelop_catch_me"] ?: NO;
    self.redEnvelopMultipleCatch = [_userDefaults boolForKey:@"dd_red_envelop_multiple_catch"] ?: YES;
}

- (void)saveConfig {
    [_userDefaults setBool:self.autoRedEnvelop forKey:@"dd_auto_red_envelop"];
    [_userDefaults setInteger:self.redEnvelopDelay forKey:@"dd_red_envelop_delay"];
    [_userDefaults setObject:self.redEnvelopGroupFilter forKey:@"dd_red_envelop_group_filter"];
    [_userDefaults setBool:self.redEnvelopCatchMe forKey:@"dd_red_envelop_catch_me"];
    [_userDefaults setBool:self.redEnvelopMultipleCatch forKey:@"dd_red_envelop_multiple_catch"];
    [_userDefaults synchronize];
}

@end

#pragma mark - 红包参数模型
@interface DDRedEnvelopParam : NSObject
@property (nonatomic, copy) NSString *msgType;
@property (nonatomic, copy) NSString *sendId;
@property (nonatomic, copy) NSString *channelId;
@property (nonatomic, copy) NSString *nickName;
@property (nonatomic, copy) NSString *headImg;
@property (nonatomic, copy) NSString *nativeUrl;
@property (nonatomic, copy) NSString *sessionUserName;
@property (nonatomic, copy) NSString *sign;
@property (nonatomic, copy) NSString *timingIdentifier;
@property (nonatomic, assign) BOOL isGroupSender;
@end

@implementation DDRedEnvelopParam
@end

#pragma mark - 红包参数队列
@interface DDRedEnvelopParamQueue : NSObject
@property (nonatomic, strong) NSMutableArray<DDRedEnvelopParam *> *queue;
+ (instancetype)shared;
- (void)enqueue:(DDRedEnvelopParam *)param;
- (DDRedEnvelopParam *)dequeue;
@end

@implementation DDRedEnvelopParamQueue

+ (instancetype)shared {
    static DDRedEnvelopParamQueue *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DDRedEnvelopParamQueue alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = [NSMutableArray array];
    }
    return self;
}

- (void)enqueue:(DDRedEnvelopParam *)param {
    @synchronized (self) {
        [_queue addObject:param];
    }
}

- (DDRedEnvelopParam *)dequeue {
    @synchronized (self) {
        if (_queue.count == 0) return nil;
        DDRedEnvelopParam *param = _queue.firstObject;
        [_queue removeObjectAtIndex:0];
        return param;
    }
}

@end

#pragma mark - 红包任务管理器
@interface DDRedEnvelopTaskManager : NSObject
@property (nonatomic, assign) BOOL serialQueueIsEmpty;
+ (instancetype)shared;
- (void)addNormalTask:(id)operation;
- (void)addSerialTask:(id)operation;
@end

@implementation DDRedEnvelopTaskManager

+ (instancetype)shared {
    static DDRedEnvelopTaskManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DDRedEnvelopTaskManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _serialQueueIsEmpty = YES;
    }
    return self;
}

- (void)addNormalTask:(id)operation {
    // 实现任务添加逻辑
}

- (void)addSerialTask:(id)operation {
    // 实现串行任务添加逻辑
}

@end

#pragma mark - 红包设置控制器
@interface DDRedEnvelopSettingController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *settings;
@end

@implementation DDRedEnvelopSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD红包设置";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
    self.settings = @[
        @{
            @"title": @"自动抢红包",
            @"type": @"switch",
            @"key": @"autoRedEnvelop"
        },
        @{
            @"title": @"延迟抢红包",
            @"type": @"input",
            @"key": @"redEnvelopDelay",
            @"placeholder": @"毫秒"
        },
        @{
            @"title": @"抢自己红包",
            @"type": @"switch",
            @"key": @"redEnvelopCatchMe"
        },
        @{
            @"title": @"防止同时抢多个",
            @"type": @"switch",
            @"key": @"redEnvelopMultipleCatch"
        }
    ];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return self.settings.count;
    return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"红包设置";
    return @"群聊过滤";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }
    
    if (indexPath.section == 0) {
        NSDictionary *setting = self.settings[indexPath.row];
        cell.textLabel.text = setting[@"title"];
        
        if ([setting[@"type"] isEqualToString:@"switch"]) {
            UISwitch *switchView = [[UISwitch alloc] init];
            switchView.tag = indexPath.row;
            NSString *key = setting[@"key"];
            
            if ([key isEqualToString:@"autoRedEnvelop"]) {
                switchView.on = [DDConfig shared].autoRedEnvelop;
                [switchView addTarget:self action:@selector(autoRedEnvelopChanged:) forControlEvents:UIControlEventValueChanged];
            } else if ([key isEqualToString:@"redEnvelopCatchMe"]) {
                switchView.on = [DDConfig shared].redEnvelopCatchMe;
                [switchView addTarget:self action:@selector(catchMeChanged:) forControlEvents:UIControlEventValueChanged];
            } else if ([key isEqualToString:@"redEnvelopMultipleCatch"]) {
                switchView.on = [DDConfig shared].redEnvelopMultipleCatch;
                [switchView addTarget:self action:@selector(multipleCatchChanged:) forControlEvents:UIControlEventValueChanged];
            }
            
            cell.accessoryView = switchView;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if ([setting[@"type"] isEqualToString:@"input"]) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld毫秒", [DDConfig shared].redEnvelopDelay];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else {
        cell.textLabel.text = @"群聊黑名单";
        cell.detailTextLabel.text = [NSString stringWithFormat:@"已过滤%lu个群", (unsigned long)[DDConfig shared].redEnvelopGroupFilter.count];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0) {
        NSDictionary *setting = self.settings[indexPath.row];
        if ([setting[@"type"] isEqualToString:@"input"]) {
            [self showDelayInputAlert];
        }
    } else {
        [self showGroupFilter];
    }
}

- (void)autoRedEnvelopChanged:(UISwitch *)sender {
    [DDConfig shared].autoRedEnvelop = sender.isOn;
    [[DDConfig shared] saveConfig];
}

- (void)catchMeChanged:(UISwitch *)sender {
    [DDConfig shared].redEnvelopCatchMe = sender.isOn;
    [[DDConfig shared] saveConfig];
}

- (void)multipleCatchChanged:(UISwitch *)sender {
    [DDConfig shared].redEnvelopMultipleCatch = sender.isOn;
    [[DDConfig shared] saveConfig];
}

- (void)showDelayInputAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置延迟时间"
                                                                   message:@"输入延迟毫秒数（1000毫秒=1秒）"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"毫秒";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%ld", [DDConfig shared].redEnvelopDelay];
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        [DDConfig shared].redEnvelopDelay = [text integerValue];
        [[DDConfig shared] saveConfig];
        [self.tableView reloadData];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showGroupFilter {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"群聊过滤"
                                                                   message:@"此功能需要额外的界面实现"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - Logos Hooks

%group DDWeChatHooks

%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(id)wrap {
    %orig;
    
    // 获取消息类型
    unsigned int msgType = [wrap m_uiMessageType];
    
    if (msgType == 49) { // 红包消息
        NSString *content = [wrap m_nsContent];
        
        // 检查是否为红包消息
        if ([content containsString:@"wxpay://"]) {
            DDConfig *config = [DDConfig shared];
            
            // 检查是否启用自动抢红包
            if (!config.autoRedEnvelop) return;
            
            // 获取发送者和接收者
            NSString *fromUsr = [wrap m_nsFromUsr];
            NSString *toUsr = [wrap m_nsToUsr];
            
            // 检查群聊过滤
            if ([config.redEnvelopGroupFilter containsObject:fromUsr]) return;
            
            // 检查是否为群聊消息
            BOOL isGroupChat = [fromUsr containsString:@"@chatroom"];
            
            // 获取自己的用户名
            Class contactMgrClass = objc_getClass("CContactMgr");
            Class serviceCenterClass = objc_getClass("MMServiceCenter");
            id contactMgr = [[serviceCenterClass defaultCenter] getService:contactMgrClass];
            id selfContact = [contactMgr getSelfContact];
            NSString *selfUsrName = [selfContact m_nsUsrName];
            
            BOOL isFromSelf = [fromUsr isEqualToString:selfUsrName];
            BOOL isToSelf = [toUsr isEqualToString:selfUsrName];
            
            // 确定是否处理该红包
            BOOL shouldHandle = NO;
            
            if (isGroupChat) {
                if (isFromSelf) {
                    // 自己发的群红包
                    shouldHandle = config.redEnvelopCatchMe;
                } else {
                    // 别人发的群红包
                    shouldHandle = YES;
                }
            } else if (isToSelf) {
                // 私聊红包
                shouldHandle = YES;
            }
            
            if (shouldHandle) {
                // 解析红包参数
                [self handleRedEnvelop:wrap];
            }
        }
    }
}

%new
- (void)handleRedEnvelop:(id)wrap {
    // 获取支付信息
    id payInfoItem = [wrap m_oWCPayInfoItem];
    NSString *nativeUrl = [payInfoItem m_c2cNativeUrl];
    
    if (!nativeUrl) return;
    
    // 解析URL参数
    NSDictionary *(^parseNativeUrl)(NSString *) = ^(NSString *url) {
        NSString *queryString = [url substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        
        NSArray *components = [queryString componentsSeparatedByString:@"&"];
        for (NSString *component in components) {
            NSArray *keyValue = [component componentsSeparatedByString:@"="];
            if (keyValue.count == 2) {
                NSString *key = [keyValue[0] stringByRemovingPercentEncoding];
                NSString *value = [keyValue[1] stringByRemovingPercentEncoding];
                if (key && value) {
                    params[key] = value;
                }
            }
        }
        return params;
    };
    
    NSDictionary *urlParams = parseNativeUrl(nativeUrl);
    
    // 获取自己的信息
    Class contactMgrClass = objc_getClass("CContactMgr");
    Class serviceCenterClass = objc_getClass("MMServiceCenter");
    id contactMgr = [[serviceCenterClass defaultCenter] getService:contactMgrClass];
    id selfContact = [contactMgr getSelfContact];
    
    // 创建红包参数
    DDRedEnvelopParam *param = [[DDRedEnvelopParam alloc] init];
    param.msgType = urlParams[@"msgtype"];
    param.sendId = urlParams[@"sendid"];
    param.channelId = urlParams[@"channelid"];
    param.nickName = [selfContact getContactDisplayName];
    param.headImg = [selfContact m_nsHeadImgUrl];
    param.nativeUrl = nativeUrl;
    param.sessionUserName = [wrap m_nsFromUsr];
    param.sign = urlParams[@"sign"];
    param.isGroupSender = [[wrap m_nsFromUsr] isEqualToString:[selfContact m_nsUsrName]];
    
    // 加入队列
    [[DDRedEnvelopParamQueue shared] enqueue:param];
    
    // 发送查询请求
    [self queryRedEnvelop:param];
}

%new
- (void)queryRedEnvelop:(DDRedEnvelopParam *)param {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"agreeDuty"] = @"0";
    params[@"channelId"] = param.channelId;
    params[@"inWay"] = @"0";
    params[@"msgType"] = param.msgType;
    params[@"nativeUrl"] = param.nativeUrl;
    params[@"sendId"] = param.sendId;
    
    Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
    id logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:logicMgrClass];
    
    if ([logicMgr respondsToSelector:@selector(ReceiverQueryRedEnvelopesRequest:)]) {
        [logicMgr ReceiverQueryRedEnvelopesRequest:params];
    }
}

%end

%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig;
    
    // 检查是否为参数查询响应
    int cmdId = [arg1 cgiCmdid];
    if (cmdId != 3) return;
    
    // 解析响应数据
    NSData *retData = [[arg1 retText] buffer];
    NSString *retString = [[NSString alloc] initWithData:retData encoding:NSUTF8StringEncoding];
    NSDictionary *response = [self dictionaryFromJSONString:retString];
    
    if (!response) return;
    
    // 获取队列中的参数
    DDRedEnvelopParam *param = [[DDRedEnvelopParamQueue shared] dequeue];
    if (!param) return;
    
    // 检查红包状态
    NSInteger receiveStatus = [response[@"receiveStatus"] integerValue];
    NSInteger hbStatus = [response[@"hbStatus"] integerValue];
    NSString *timingIdentifier = response[@"timingIdentifier"];
    
    if (receiveStatus == 2 || hbStatus == 4 || !timingIdentifier) {
        return;
    }
    
    // 验证签名（如果不是自己发的）
    if (!param.isGroupSender) {
        NSData *reqData = [[arg2 reqText] buffer];
        NSString *reqString = [[NSString alloc] initWithData:reqData encoding:NSUTF8StringEncoding];
        NSDictionary *requestDict = [self dictionaryFromQueryString:reqString];
        
        NSString *nativeUrl = [[requestDict[@"nativeUrl"] stringByRemovingPercentEncoding] stringByRemovingPercentEncoding];
        NSDictionary *urlParams = [self dictionaryFromQueryString:[nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]]];
        
        NSString *requestSign = urlParams[@"sign"];
        if (![requestSign isEqualToString:param.sign]) {
            return;
        }
    }
    
    // 设置定时标识符
    param.timingIdentifier = timingIdentifier;
    
    // 计算延迟
    NSUInteger delay = [self calculateDelaySeconds];
    
    // 执行抢红包操作
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [self openRedEnvelop:param];
    });
}

%new
- (NSDictionary *)dictionaryFromJSONString:(NSString *)jsonString {
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) return nil;
    
    NSError *error = nil;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (error) {
        NSLog(@"JSON解析错误: %@", error);
        return nil;
    }
    return dictionary;
}

%new
- (NSDictionary *)dictionaryFromQueryString:(NSString *)queryString {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    NSArray *components = [queryString componentsSeparatedByString:@"&"];
    for (NSString *component in components) {
        NSArray *keyValue = [component componentsSeparatedByString:@"="];
        if (keyValue.count == 2) {
            NSString *key = [keyValue[0] stringByRemovingPercentEncoding];
            NSString *value = [keyValue[1] stringByRemovingPercentEncoding];
            if (key && value) {
                params[key] = value;
            }
        }
    }
    return params;
}

%new
- (NSUInteger)calculateDelaySeconds {
    DDConfig *config = [DDConfig shared];
    NSUInteger delay = config.redEnvelopDelay;
    
    if (config.redEnvelopMultipleCatch && ![[DDRedEnvelopTaskManager shared] serialQueueIsEmpty]) {
        delay = MAX(delay, 15000); // 防止同时抢多个，最小延迟15秒
    }
    
    return delay;
}

%new
- (void)openRedEnvelop:(DDRedEnvelopParam *)param {
    NSMutableDictionary *openParams = [NSMutableDictionary dictionary];
    openParams[@"agreeDuty"] = @"0";
    openParams[@"channelId"] = param.channelId;
    openParams[@"inWay"] = @"0";
    openParams[@"msgType"] = param.msgType;
    openParams[@"nativeUrl"] = param.nativeUrl;
    openParams[@"sendId"] = param.sendId;
    openParams[@"timingIdentifier"] = param.timingIdentifier;
    
    if ([self respondsToSelector:@selector(OpenRedEnvelopesRequest:)]) {
        [self OpenRedEnvelopesRequest:openParams];
    }
}

%end

%group DDPluginRegistration

%hook MicroMessengerAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    BOOL result = %orig;
    
    // 注册插件到插件管理系统
    [self registerPlugin];
    
    return result;
}

%new
- (void)registerPlugin {
    // 检查是否存在插件管理系统
    Class pluginsMgrClass = NSClassFromString(@"WCPluginsMgr");
    if (pluginsMgrClass) {
        // 注册带设置页面的插件
        SEL sharedSelector = NSSelectorFromString(@"sharedInstance");
        if ([pluginsMgrClass respondsToSelector:sharedSelector]) {
            id pluginsMgr = [pluginsMgrClass performSelector:sharedSelector];
            
            SEL registerControllerSelector = NSSelectorFromString(@"registerControllerWithTitle:version:controller:");
            if ([pluginsMgr respondsToSelector:registerControllerSelector]) {
                NSMethodSignature *signature = [pluginsMgr methodSignatureForSelector:registerControllerSelector];
                NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
                [invocation setTarget:pluginsMgr];
                [invocation setSelector:registerControllerSelector];
                
                NSString *title = DD_PLUGIN_NAME;
                NSString *version = DD_PLUGIN_VERSION;
                NSString *controller = NSStringFromClass([DDRedEnvelopSettingController class]);
                
                [invocation setArgument:&title atIndex:2];
                [invocation setArgument:&version atIndex:3];
                [invocation setArgument:&controller atIndex:4];
                [invocation invoke];
                
                NSLog(@"✅ DD红包插件已注册到插件管理系统");
            }
        }
    } else {
        // 如果没有插件管理系统，我们可以添加自己的入口
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self addPluginEntry];
        });
    }
}

%new
- (void)addPluginEntry {
    // 这里可以添加自己的插件入口，例如在设置页面添加
    NSLog(@"DD红包插件已加载");
}

%end

%end // DDWeChatHooks

#pragma mark - Constructor

__attribute__((constructor)) static void DDEntry() {
    @autoreleasepool {
        NSLog(@"🔧 DD红包插件初始化...");
        
        // 初始化配置
        [DDConfig shared];
        
        // 应用Logos hooks
        %init(DDWeChatHooks);
        %init(DDPluginRegistration);
        
        NSLog(@"✅ DD红包插件初始化完成");
    }
}