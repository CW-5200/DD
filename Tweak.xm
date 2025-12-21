//
//  DD红包.xm
//  DD红包 v1.0.0
//
//  Created by DD红包插件
//  Copyright © 2023. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CaptainHook/CaptainHook.h>

// ============================================================================
// MARK: - 微信框架类声明
// ============================================================================

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

@interface WCPayInfoItem : NSObject
@property(retain, nonatomic) NSString *m_c2cNativeUrl;
@end

@interface CContact : NSObject
@property(nonatomic, copy) NSString *m_nsUsrName;
@property(nonatomic, copy) NSString *m_nsNickName;
@property(retain, nonatomic) NSString *m_nsHeadImgUrl;
- (id)getContactDisplayName;
@end

@interface CMessageWrap : NSObject
@property(retain, nonatomic) WCPayInfoItem *m_oWCPayInfoItem;
@property(nonatomic) int m_uiMessageType;
@property(nonatomic, copy) NSString *m_nsContent;
@property(nonatomic, copy) NSString *m_nsFromUsr;
@property(nonatomic, copy) NSString *m_nsToUsr;
@property(nonatomic) unsigned int m_uiCreateTime;
- (id)initWithMsgType:(long long)arg1;
@end

@interface CContactMgr : NSObject
- (id)getSelfContact;
@end

@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)service;
@end

@interface WCBizUtil : NSObject
+ (id)dictionaryWithDecodedComponets:(id)arg1 separator:(id)arg2;
@end

@interface WCRedEnvelopesLogicMgr : NSObject
- (void)ReceiverQueryRedEnvelopesRequest:(id)arg1;
- (void)OpenRedEnvelopesRequest:(id)arg1;
@end

@interface SKBuiltinBuffer_t : NSObject
@property(retain, nonatomic) NSData *buffer;
@end

@interface HongBaoRes : NSObject
@property(retain, nonatomic) SKBuiltinBuffer_t *retText;
@property(nonatomic) int cgiCmdid;
@end

@interface HongBaoReq : NSObject
@property(retain, nonatomic) SKBuiltinBuffer_t *reqText;
@end

// ============================================================================
// MARK: - 插件配置管理类
// ============================================================================

@interface DDPluginConfig : NSObject
@property(nonatomic, assign) BOOL autoRedEnvelop;
@property(nonatomic, assign) NSInteger redEnvelopDelay;
@property(nonatomic, copy) NSArray *redEnvelopGroupFilter;
@property(nonatomic, assign) BOOL redEnvelopCatchMe;
@property(nonatomic, assign) BOOL redEnvelopMultipleCatch;
+ (instancetype)sharedConfig;
- (void)saveConfig;
@end

@implementation DDPluginConfig

+ (instancetype)sharedConfig {
    static DDPluginConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DDPluginConfig alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        [self loadConfig];
    }
    return self;
}

- (void)loadConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _autoRedEnvelop = [defaults boolForKey:@"DDPlugin_AutoRedEnvelop"] ?: YES;
    _redEnvelopDelay = [defaults integerForKey:@"DDPlugin_RedEnvelopDelay"] ?: 0;
    _redEnvelopGroupFilter = [defaults arrayForKey:@"DDPlugin_RedEnvelopGroupFilter"] ?: @[];
    _redEnvelopCatchMe = [defaults boolForKey:@"DDPlugin_RedEnvelopCatchMe"] ?: NO;
    _redEnvelopMultipleCatch = [defaults boolForKey:@"DDPlugin_RedEnvelopMultipleCatch"] ?: YES;
}

- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:_autoRedEnvelop forKey:@"DDPlugin_AutoRedEnvelop"];
    [defaults setInteger:_redEnvelopDelay forKey:@"DDPlugin_RedEnvelopDelay"];
    [defaults setObject:_redEnvelopGroupFilter forKey:@"DDPlugin_RedEnvelopGroupFilter"];
    [defaults setBool:_redEnvelopCatchMe forKey:@"DDPlugin_RedEnvelopCatchMe"];
    [defaults setBool:_redEnvelopMultipleCatch forKey:@"DDPlugin_RedEnvelopMultipleCatch"];
    [defaults synchronize];
}

- (void)setAutoRedEnvelop:(BOOL)autoRedEnvelop {
    _autoRedEnvelop = autoRedEnvelop;
    [self saveConfig];
}

- (void)setRedEnvelopDelay:(NSInteger)redEnvelopDelay {
    _redEnvelopDelay = redEnvelopDelay;
    [self saveConfig];
}

- (void)setRedEnvelopGroupFilter:(NSArray *)redEnvelopGroupFilter {
    _redEnvelopGroupFilter = redEnvelopGroupFilter;
    [self saveConfig];
}

- (void)setRedEnvelopCatchMe:(BOOL)redEnvelopCatchMe {
    _redEnvelopCatchMe = redEnvelopCatchMe;
    [self saveConfig];
}

- (void)setRedEnvelopMultipleCatch:(BOOL)redEnvelopMultipleCatch {
    _redEnvelopMultipleCatch = redEnvelopMultipleCatch;
    [self saveConfig];
}

@end

// ============================================================================
// MARK: - 红包参数模型类
// ============================================================================

@interface DDRedEnvelopParam : NSObject
@property(copy, nonatomic) NSString *msgType;
@property(copy, nonatomic) NSString *sendId;
@property(copy, nonatomic) NSString *channelId;
@property(copy, nonatomic) NSString *nickName;
@property(copy, nonatomic) NSString *headImg;
@property(copy, nonatomic) NSString *nativeUrl;
@property(copy, nonatomic) NSString *sessionUserName;
@property(copy, nonatomic) NSString *sign;
@property(copy, nonatomic) NSString *timingIdentifier;
@property(nonatomic) BOOL isGroupSender;
@end

@implementation DDRedEnvelopParam
@end

// ============================================================================
// MARK: - 参数队列管理类
// ============================================================================

@interface DDRedEnvelopParamQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(DDRedEnvelopParam *)param;
- (DDRedEnvelopParam *)dequeue;
- (void)clearQueue;
@end

@implementation DDRedEnvelopParamQueue {
    NSMutableArray *_queue;
    NSRecursiveLock *_lock;
}

+ (instancetype)sharedQueue {
    static DDRedEnvelopParamQueue *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DDRedEnvelopParamQueue alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _queue = [NSMutableArray array];
        _lock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (void)enqueue:(DDRedEnvelopParam *)param {
    [_lock lock];
    [_queue addObject:param];
    [_lock unlock];
}

- (DDRedEnvelopParam *)dequeue {
    [_lock lock];
    DDRedEnvelopParam *param = nil;
    if (_queue.count > 0) {
        param = [_queue firstObject];
        [_queue removeObjectAtIndex:0];
    }
    [_lock unlock];
    return param;
}

- (void)clearQueue {
    [_lock lock];
    [_queue removeAllObjects];
    [_lock unlock];
}

@end

// ============================================================================
// MARK: - 抢红包任务类
// ============================================================================

@interface DDRedEnvelopTask : NSObject
@property(strong, nonatomic) DDRedEnvelopParam *param;
@property(assign, nonatomic) NSTimeInterval delay;
+ (instancetype)taskWithParam:(DDRedEnvelopParam *)param delay:(NSTimeInterval)delay;
@end

@implementation DDRedEnvelopTask

+ (instancetype)taskWithParam:(DDRedEnvelopParam *)param delay:(NSTimeInterval)delay {
    DDRedEnvelopTask *task = [[self alloc] init];
    task.param = param;
    task.delay = delay;
    return task;
}

@end

// ============================================================================
// MARK: - 任务调度管理器类
// ============================================================================

@interface DDRedEnvelopTaskManager : NSObject
@property(assign, nonatomic) BOOL serialQueueIsEmpty;
@property(assign, nonatomic) BOOL isExecuting;
+ (instancetype)sharedManager;
- (void)addSerialTask:(DDRedEnvelopTask *)task;
- (void)addNormalTask:(DDRedEnvelopTask *)task;
- (void)stopAllTasks;
@end

@implementation DDRedEnvelopTaskManager {
    NSMutableArray *_serialQueue;
    NSMutableArray *_normalQueue;
    BOOL _isExecutingSerialTask;
    NSRecursiveLock *_lock;
}

+ (instancetype)sharedManager {
    static DDRedEnvelopTaskManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DDRedEnvelopTaskManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _serialQueue = [NSMutableArray array];
        _normalQueue = [NSMutableArray array];
        _lock = [[NSRecursiveLock alloc] init];
        _isExecutingSerialTask = NO;
        _isExecuting = NO;
        _serialQueueIsEmpty = YES;
    }
    return self;
}

- (void)addSerialTask:(DDRedEnvelopTask *)task {
    [_lock lock];
    [_serialQueue addObject:task];
    [self executeSerialTasks];
    [_lock unlock];
}

- (void)addNormalTask:(DDRedEnvelopTask *)task {
    [_lock lock];
    [_normalQueue addObject:task];
    [self executeNormalTask:task];
    [_lock unlock];
}

- (void)executeSerialTasks {
    if (_isExecutingSerialTask || _serialQueue.count == 0) {
        _serialQueueIsEmpty = (_serialQueue.count == 0);
        return;
    }
    
    _isExecutingSerialTask = YES;
    _isExecuting = YES;
    _serialQueueIsEmpty = NO;
    
    DDRedEnvelopTask *task = [_serialQueue firstObject];
    [_serialQueue removeObjectAtIndex:0];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(task.delay * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [self executeTask:task];
        self->_isExecutingSerialTask = NO;
        [self executeSerialTasks];
    });
}

- (void)executeNormalTask:(DDRedEnvelopTask *)task {
    _isExecuting = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(task.delay * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [self executeTask:task];
    });
}

- (void)executeTask:(DDRedEnvelopTask *)task {
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"agreeDuty"] = @"0";
    params[@"channelId"] = task.param.channelId;
    params[@"inWay"] = @"0";
    params[@"msgType"] = task.param.msgType;
    params[@"nativeUrl"] = task.param.nativeUrl;
    params[@"sendId"] = task.param.sendId;
    params[@"timingIdentifier"] = task.param.timingIdentifier;
    
    WCRedEnvelopesLogicMgr *logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("WCRedEnvelopesLogicMgr")];
    [logicMgr OpenRedEnvelopesRequest:params];
}

- (void)stopAllTasks {
    [_lock lock];
    [_serialQueue removeAllObjects];
    [_normalQueue removeAllObjects];
    _isExecutingSerialTask = NO;
    _isExecuting = NO;
    _serialQueueIsEmpty = YES;
    [_lock unlock];
}

@end

// ============================================================================
// MARK: - 插件设置界面控制器类
// ============================================================================

@interface DDPluginSettingController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@end

@implementation DDPluginSettingController {
    UITableView *_tableView;
    NSArray<NSDictionary *> *_sections;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self setupSections];
}

- (void)setupUI {
    self.title = @"DD红包设置 v1.0.0";
    self.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tableView];
    
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 60)];
    headerView.backgroundColor = [UIColor clearColor];
    
    UILabel *versionLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 20, self.view.bounds.size.width - 40, 20)];
    versionLabel.text = @"DD红包插件 v1.0.0";
    versionLabel.textAlignment = NSTextAlignmentCenter;
    versionLabel.textColor = [UIColor grayColor];
    versionLabel.font = [UIFont systemFontOfSize:14];
    [headerView addSubview:versionLabel];
    
    _tableView.tableHeaderView = headerView;
}

- (void)setupSections {
    _sections = @[
        @{
            @"header": @"📦 自动抢红包设置",
            @"rows": @[
                @{@"type": @"switch", @"title": @"开启自动抢红包", @"key": @"autoRedEnvelop", @"icon": @"⚡️"},
                @{@"type": @"input", @"title": @"延迟时间(毫秒)", @"key": @"redEnvelopDelay", @"icon": @"⏱️"},
                @{@"type": @"switch", @"title": @"抢自己发的红包", @"key": @"redEnvelopCatchMe", @"icon": @"🤖"},
                @{@"type": @"switch", @"title": @"防止同时抢多个", @"key": @"redEnvelopMultipleCatch", @"icon": @"🚫"}
            ]
        }
    ];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _sections[section][@"rows"] ? [_sections[section][@"rows"] count] : 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _sections[section][@"header"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *rowInfo = _sections[indexPath.section][@"rows"][indexPath.row];
    NSString *type = rowInfo[@"type"];
    NSString *title = rowInfo[@"title"];
    NSString *key = rowInfo[@"key"];
    NSString *icon = rowInfo[@"icon"] ?: @"";
    
    if ([type isEqualToString:@"switch"]) {
        static NSString *switchCellID = @"SwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:switchCellID];
        
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:switchCellID];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            UISwitch *switchView = [[UISwitch alloc] init];
            switchView.tag = 1000 + indexPath.row;
            [switchView addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = switchView;
        }
        
        UISwitch *switchView = (UISwitch *)[cell viewWithTag:1000 + indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", icon, title];
        
        DDPluginConfig *config = [DDPluginConfig sharedConfig];
        if ([key isEqualToString:@"autoRedEnvelop"]) {
            switchView.on = config.autoRedEnvelop;
            switchView.accessibilityIdentifier = @"autoRedEnvelop";
        } else if ([key isEqualToString:@"redEnvelopCatchMe"]) {
            switchView.on = config.redEnvelopCatchMe;
            switchView.accessibilityIdentifier = @"redEnvelopCatchMe";
        } else if ([key isEqualToString:@"redEnvelopMultipleCatch"]) {
            switchView.on = config.redEnvelopMultipleCatch;
            switchView.accessibilityIdentifier = @"redEnvelopMultipleCatch";
        }
        
        return cell;
        
    } else if ([type isEqualToString:@"input"]) {
        static NSString *inputCellID = @"InputCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:inputCellID];
        
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:inputCellID];
        }
        
        cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", icon, title];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)[DDPluginConfig sharedConfig].redEnvelopDelay];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        return cell;
    }
    
    return [[UITableViewCell alloc] init];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *rowInfo = _sections[indexPath.section][@"rows"][indexPath.row];
    NSString *key = rowInfo[@"key"];
    
    if ([key isEqualToString:@"redEnvelopDelay"]) {
        [self showDelayInputAlert];
    }
}

#pragma mark - Action Handlers

- (void)switchValueChanged:(UISwitch *)sender {
    NSString *key = sender.accessibilityIdentifier;
    DDPluginConfig *config = [DDPluginConfig sharedConfig];
    
    if ([key isEqualToString:@"autoRedEnvelop"]) {
        config.autoRedEnvelop = sender.on;
    } else if ([key isEqualToString:@"redEnvelopCatchMe"]) {
        config.redEnvelopCatchMe = sender.on;
    } else if ([key isEqualToString:@"redEnvelopMultipleCatch"]) {
        config.redEnvelopMultipleCatch = sender.on;
    }
}

- (void)showDelayInputAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"延迟时间设置"
                                                                   message:@"输入延迟毫秒数 (1秒=1000毫秒)\n建议设置：200-1000毫秒"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"请输入延迟时间";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%ld", (long)[DDPluginConfig sharedConfig].redEnvelopDelay];
    }];
    
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定"
                                                            style:UIAlertActionStyleDefault
                                                          handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        NSInteger delay = MAX(0, [text integerValue]);
        [DDPluginConfig sharedConfig].redEnvelopDelay = delay;
        [self->_tableView reloadData];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                           style:UIAlertActionStyleCancel
                                                         handler:nil];
    
    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end

// ============================================================================
// MARK: - Logos Hooks 实现
// ============================================================================

%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap {
    %orig;
    
    // 只处理AppNode消息（类型49）
    if (wrap.m_uiMessageType != 49) return;
    
    // 检查是否为红包消息
    if (![wrap.m_nsContent containsString:@"wxpay://"]) return;
    
    DDPluginConfig *config = [DDPluginConfig sharedConfig];
    if (!config.autoRedEnvelop) return;
    
    CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
    CContact *selfContact = [contactMgr getSelfContact];
    
    // 判断消息类型
    BOOL isSender = [wrap.m_nsFromUsr isEqualToString:selfContact.m_nsUsrName];
    BOOL isGroupReceiver = [wrap.m_nsFromUsr containsString:@"@chatroom"];
    BOOL isGroupSender = isSender && [wrap.m_nsToUsr containsString:@"chatroom"];
    
    // 检查是否需要处理
    BOOL shouldProcess = NO;
    
    if (isGroupReceiver) {
        // 群聊消息：检查群聊过滤
        if (![config.redEnvelopGroupFilter containsObject:wrap.m_nsFromUsr]) {
            shouldProcess = YES;
        }
    } else if (isGroupSender && config.redEnvelopCatchMe) {
        // 自己发的群红包且开启抢自己
        shouldProcess = YES;
    }
    
    if (!shouldProcess) return;
    
    // 解析nativeUrl
    NSString *nativeUrl = [wrap.m_oWCPayInfoItem m_c2cNativeUrl];
    NSString *queryString = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
    NSDictionary *nativeUrlDict = [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:queryString separator:@"&"];
    
    if (!nativeUrlDict) return;
    
    // 查询红包详情
    NSMutableDictionary *queryParams = [NSMutableDictionary dictionary];
    queryParams[@"agreeDuty"] = @"0";
    queryParams[@"channelId"] = nativeUrlDict[@"channelid"] ?: @"";
    queryParams[@"inWay"] = @"0";
    queryParams[@"msgType"] = nativeUrlDict[@"msgtype"] ?: @"";
    queryParams[@"nativeUrl"] = nativeUrl;
    queryParams[@"sendId"] = nativeUrlDict[@"sendid"] ?: @"";
    
    WCRedEnvelopesLogicMgr *logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("WCRedEnvelopesLogicMgr")];
    [logicMgr ReceiverQueryRedEnvelopesRequest:queryParams];
    
    // 存储参数到队列
    DDRedEnvelopParam *param = [[DDRedEnvelopParam alloc] init];
    param.msgType = nativeUrlDict[@"msgtype"];
    param.sendId = nativeUrlDict[@"sendid"];
    param.channelId = nativeUrlDict[@"channelid"];
    param.nickName = [selfContact getContactDisplayName];
    param.headImg = [selfContact m_nsHeadImgUrl];
    param.nativeUrl = nativeUrl;
    param.sessionUserName = isGroupSender ? wrap.m_nsToUsr : wrap.m_nsFromUsr;
    param.sign = nativeUrlDict[@"sign"];
    param.isGroupSender = isGroupSender;
    
    [[DDRedEnvelopParamQueue sharedQueue] enqueue:param];
}

%end

// ============================================================================

%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(HongBaoRes *)response Request:(HongBaoReq *)request {
    %orig;
    
    // 只处理查询响应（cgiCmdid = 3）
    if (response.cgiCmdid != 3) return;
    
    // 解析请求参数获取sign
    NSString *requestString = [[NSString alloc] initWithData:request.reqText.buffer encoding:NSUTF8StringEncoding];
    NSDictionary *requestDict = [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:requestString separator:@"&"];
    NSString *encodedUrl = [requestDict[@"nativeUrl"] stringByRemovingPercentEncoding];
    NSDictionary *nativeUrlDict = [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:encodedUrl separator:@"&"];
    NSString *requestSign = nativeUrlDict[@"sign"];
    
    // 解析响应
    NSDictionary *responseDict = [[[NSString alloc] initWithData:response.retText.buffer encoding:NSUTF8StringEncoding] JSONObject];
    
    // 检查红包状态
    if ([responseDict[@"receiveStatus"] integerValue] == 2) return; // 已抢过
    if ([responseDict[@"hbStatus"] integerValue] == 4) return;     // 已抢完
    if (!responseDict[@"timingIdentifier"]) return;                // 无timingIdentifier
    
    // 从队列获取参数
    DDRedEnvelopParam *param = [[DDRedEnvelopParamQueue sharedQueue] dequeue];
    if (!param) return;
    
    // 验证sign（自己发的红包没有sign）
    BOOL isValid = param.isGroupSender || [requestSign isEqualToString:param.sign];
    if (!isValid) return;
    
    DDPluginConfig *config = [DDPluginConfig sharedConfig];
    if (!config.autoRedEnvelop) return;
    
    // 设置timingIdentifier
    param.timingIdentifier = responseDict[@"timingIdentifier"];
    
    // 创建任务
    DDRedEnvelopTask *task = [DDRedEnvelopTask taskWithParam:param delay:config.redEnvelopDelay];
    
    // 添加到任务管理器
    DDRedEnvelopTaskManager *manager = [DDRedEnvelopTaskManager sharedManager];
    if (config.redEnvelopMultipleCatch) {
        [manager addSerialTask:task];
    } else {
        [manager addNormalTask:task];
    }
}

%end

// ============================================================================
// MARK: - 插件初始化
// ============================================================================

%ctor {
    @autoreleasepool {
        NSLog(@"🔧 DD红包插件 v1.0.0 正在初始化...");
        
        // 延迟注册到插件管理器
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            Class pluginMgrClass = objc_getClass("WCPluginsMgr");
            if (pluginMgrClass) {
                id pluginMgr = [pluginMgrClass sharedInstance];
                if (pluginMgr) {
                    [pluginMgr registerControllerWithTitle:@"DD红包" 
                                                  version:@"1.0.0" 
                                              controller:@"DDPluginSettingController"];
                    NSLog(@"✅ DD红包插件注册成功！");
                }
            } else {
                NSLog(@"⚠️ 未找到插件管理器，使用内置设置界面");
            }
        });
    }
}