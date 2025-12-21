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

#pragma mark - 插件管理器接口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

#pragma mark - 微信基础类声明
@interface WCPayInfoItem : NSObject
@property(retain, nonatomic) NSString *m_c2cNativeUrl;
@end

@interface CContact : NSObject
@property (nonatomic, copy) NSString *m_nsUsrName;
@property (nonatomic, copy) NSString *m_nsNickName;
@property(retain, nonatomic) NSString *m_nsHeadImgUrl;
- (id)getContactDisplayName;
@end

@interface CMessageWrap : NSObject
@property (retain, nonatomic) WCPayInfoItem *m_oWCPayInfoItem;
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

#pragma mark - DD红包插件核心类
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

@interface DDRedEnvelopParamQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(DDRedEnvelopParam *)param;
- (DDRedEnvelopParam *)dequeue;
@end

@implementation DDRedEnvelopParamQueue {
    NSMutableArray *_queue;
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
    self = [super init];
    if (self) {
        _queue = [NSMutableArray array];
    }
    return self;
}

- (void)enqueue:(DDRedEnvelopParam *)param {
    [_queue addObject:param];
}

- (DDRedEnvelopParam *)dequeue {
    if (_queue.count == 0) {
        return nil;
    }
    DDRedEnvelopParam *param = [_queue firstObject];
    [_queue removeObjectAtIndex:0];
    return param;
}

@end

@interface DDRedEnvelopTask : NSObject
@property(strong, nonatomic) DDRedEnvelopParam *param;
@property(assign, nonatomic) NSTimeInterval delay;
@end

@implementation DDRedEnvelopTask
@end

@interface DDRedEnvelopTaskManager : NSObject
@property(assign, nonatomic) BOOL serialQueueIsEmpty;
+ (instancetype)sharedManager;
- (void)addSerialTask:(DDRedEnvelopTask *)task;
- (void)addNormalTask:(DDRedEnvelopTask *)task;
@end

@implementation DDRedEnvelopTaskManager {
    NSMutableArray *_serialQueue;
    NSMutableArray *_normalQueue;
    BOOL _isExecutingSerialTask;
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
    self = [super init];
    if (self) {
        _serialQueue = [NSMutableArray array];
        _normalQueue = [NSMutableArray array];
        _isExecutingSerialTask = NO;
    }
    return self;
}

- (void)addSerialTask:(DDRedEnvelopTask *)task {
    @synchronized (self) {
        [_serialQueue addObject:task];
        [self executeSerialTasks];
    }
}

- (void)addNormalTask:(DDRedEnvelopTask *)task {
    @synchronized (self) {
        [_normalQueue addObject:task];
        [self executeNormalTask:task];
    }
}

- (void)executeSerialTasks {
    if (_isExecutingSerialTask || _serialQueue.count == 0) {
        self.serialQueueIsEmpty = (_serialQueue.count == 0);
        return;
    }
    
    _isExecutingSerialTask = YES;
    self.serialQueueIsEmpty = NO;
    
    DDRedEnvelopTask *task = [_serialQueue firstObject];
    [_serialQueue removeObjectAtIndex:0];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(task.delay * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
        [self executeTask:task];
        self->_isExecutingSerialTask = NO;
        [self executeSerialTasks];
    });
}

- (void)executeNormalTask:(DDRedEnvelopTask *)task {
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

@end

#pragma mark - 插件配置类
@interface DDPluginConfig : NSObject
@property (nonatomic, assign) BOOL autoRedEnvelop;
@property (nonatomic, assign) NSInteger redEnvelopDelay;
@property (nonatomic, copy) NSArray *redEnvelopGroupFilter;
@property (nonatomic, assign) BOOL redEnvelopCatchMe;
@property (nonatomic, assign) BOOL redEnvelopMultipleCatch;
+ (instancetype)sharedConfig;
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
    self = [super init];
    if (self) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        _autoRedEnvelop = [defaults boolForKey:@"DDPlugin_AutoRedEnvelop"] ?: YES;
        _redEnvelopDelay = [defaults integerForKey:@"DDPlugin_RedEnvelopDelay"] ?: 0;
        _redEnvelopGroupFilter = [defaults arrayForKey:@"DDPlugin_RedEnvelopGroupFilter"] ?: @[];
        _redEnvelopCatchMe = [defaults boolForKey:@"DDPlugin_RedEnvelopCatchMe"] ?: NO;
        _redEnvelopMultipleCatch = [defaults boolForKey:@"DDPlugin_RedEnvelopMultipleCatch"] ?: YES;
    }
    return self;
}

- (void)setAutoRedEnvelop:(BOOL)autoRedEnvelop {
    _autoRedEnvelop = autoRedEnvelop;
    [[NSUserDefaults standardUserDefaults] setBool:autoRedEnvelop forKey:@"DDPlugin_AutoRedEnvelop"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setRedEnvelopDelay:(NSInteger)redEnvelopDelay {
    _redEnvelopDelay = redEnvelopDelay;
    [[NSUserDefaults standardUserDefaults] setInteger:redEnvelopDelay forKey:@"DDPlugin_RedEnvelopDelay"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setRedEnvelopGroupFilter:(NSArray *)redEnvelopGroupFilter {
    _redEnvelopGroupFilter = redEnvelopGroupFilter;
    [[NSUserDefaults standardUserDefaults] setObject:redEnvelopGroupFilter forKey:@"DDPlugin_RedEnvelopGroupFilter"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setRedEnvelopCatchMe:(BOOL)redEnvelopCatchMe {
    _redEnvelopCatchMe = redEnvelopCatchMe;
    [[NSUserDefaults standardUserDefaults] setBool:redEnvelopCatchMe forKey:@"DDPlugin_RedEnvelopCatchMe"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setRedEnvelopMultipleCatch:(BOOL)redEnvelopMultipleCatch {
    _redEnvelopMultipleCatch = redEnvelopMultipleCatch;
    [[NSUserDefaults standardUserDefaults] setBool:redEnvelopMultipleCatch forKey:@"DDPlugin_RedEnvelopMultipleCatch"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

#pragma mark - 插件设置界面
@interface DDPluginSettingController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
    UITableView *_tableView;
    NSArray *_sections;
}
@end

@implementation DDPluginSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD红包设置";
    self.view.backgroundColor = [UIColor whiteColor];
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tableView];
    
    [self setupSections];
}

- (void)setupSections {
    _sections = @[
        @{
            @"header": @"自动抢红包",
            @"rows": @[
                @{@"type": @"switch", @"title": @"开启自动抢红包", @"key": @"autoRedEnvelop"},
                @{@"type": @"input", @"title": @"延迟抢红包(毫秒)", @"key": @"redEnvelopDelay"},
                @{@"type": @"switch", @"title": @"抢自己发的红包", @"key": @"redEnvelopCatchMe"},
                @{@"type": @"switch", @"title": @"防止同时抢多个", @"key": @"redEnvelopMultipleCatch"}
            ]
        }
    ];
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_sections[section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _sections[section][@"header"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *rowInfo = _sections[indexPath.section][@"rows"][indexPath.row];
    NSString *type = rowInfo[@"type"];
    NSString *title = rowInfo[@"title"];
    NSString *key = rowInfo[@"key"];
    
    if ([type isEqualToString:@"switch"]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SwitchCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SwitchCell"];
            UISwitch *switchView = [[UISwitch alloc] init];
            switchView.tag = 1000;
            cell.accessoryView = switchView;
        }
        
        UISwitch *switchView = (UISwitch *)[cell viewWithTag:1000];
        [switchView removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        
        DDPluginConfig *config = [DDPluginConfig sharedConfig];
        if ([key isEqualToString:@"autoRedEnvelop"]) {
            switchView.on = config.autoRedEnvelop;
            [switchView addTarget:self action:@selector(autoRedEnvelopSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        } else if ([key isEqualToString:@"redEnvelopCatchMe"]) {
            switchView.on = config.redEnvelopCatchMe;
            [switchView addTarget:self action:@selector(redEnvelopCatchMeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        } else if ([key isEqualToString:@"redEnvelopMultipleCatch"]) {
            switchView.on = config.redEnvelopMultipleCatch;
            [switchView addTarget:self action:@selector(redEnvelopMultipleCatchSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        }
        
        cell.textLabel.text = title;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
        
    } else if ([type isEqualToString:@"input"]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"InputCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"InputCell"];
        }
        
        DDPluginConfig *config = [DDPluginConfig sharedConfig];
        cell.textLabel.text = title;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)config.redEnvelopDelay];
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

#pragma mark - Switch Handlers
- (void)autoRedEnvelopSwitchChanged:(UISwitch *)sender {
    [DDPluginConfig sharedConfig].autoRedEnvelop = sender.on;
}

- (void)redEnvelopCatchMeSwitchChanged:(UISwitch *)sender {
    [DDPluginConfig sharedConfig].redEnvelopCatchMe = sender.on;
}

- (void)redEnvelopMultipleCatchSwitchChanged:(UISwitch *)sender {
    [DDPluginConfig sharedConfig].redEnvelopMultipleCatch = sender.on;
}

- (void)showDelayInputAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"延迟时间"
                                                                   message:@"输入延迟毫秒数 (1秒=1000毫秒)"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"0";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%ld", (long)[DDPluginConfig sharedConfig].redEnvelopDelay];
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        NSInteger delay = [text integerValue];
        [DDPluginConfig sharedConfig].redEnvelopDelay = MAX(0, delay);
        [self->_tableView reloadData];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - Hook实现
CHDeclareClass(CMessageMgr)

CHOptimizedMethod2(self, void, CMessageMgr, AsyncOnAddMsg, NSString *, msg, MsgWrap, CMessageWrap *, wrap) {
    CHSuper2(CMessageMgr, AsyncOnAddMsg, msg, MsgWrap, wrap);
    
    // 处理红包消息
    if (wrap.m_uiMessageType == 49) { // AppNode消息
        BOOL (^isRedEnvelopMessage)(void) = ^BOOL {
            return [wrap.m_nsContent rangeOfString:@"wxpay://"].location != NSNotFound;
        };
        
        if (isRedEnvelopMessage()) {
            DDPluginConfig *config = [DDPluginConfig sharedConfig];
            if (!config.autoRedEnvelop) return;
            
            CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
            CContact *selfContact = [contactMgr getSelfContact];
            
            BOOL (^isSender)(void) = ^BOOL {
                return [wrap.m_nsFromUsr isEqualToString:selfContact.m_nsUsrName];
            };
            
            BOOL (^isGroupReceiver)(void) = ^BOOL {
                return [wrap.m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound;
            };
            
            BOOL (^isGroupSender)(void) = ^BOOL {
                return isSender() && [wrap.m_nsToUsr rangeOfString:@"chatroom"].location != NSNotFound;
            };
            
            BOOL (^shouldReceiveRedEnvelop)(void) = ^BOOL {
                if (isGroupReceiver()) {
                    // 检查群聊过滤
                    if ([config.redEnvelopGroupFilter containsObject:wrap.m_nsFromUsr]) {
                        return NO;
                    }
                    return YES;
                } else if (isGroupSender() && config.redEnvelopCatchMe) {
                    return YES;
                }
                return NO;
            };
            
            NSDictionary *(^parseNativeUrl)(NSString *) = ^NSDictionary *(NSString *nativeUrl) {
                nativeUrl = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
                return [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
            };
            
            void (^queryRedEnvelopesRequest)(NSDictionary *) = ^(NSDictionary *nativeUrlDict) {
                NSMutableDictionary *params = [NSMutableDictionary dictionary];
                params[@"agreeDuty"] = @"0";
                params[@"channelId"] = [nativeUrlDict stringForKey:@"channelid"];
                params[@"inWay"] = @"0";
                params[@"msgType"] = [nativeUrlDict stringForKey:@"msgtype"];
                params[@"nativeUrl"] = [wrap.m_oWCPayInfoItem m_c2cNativeUrl];
                params[@"sendId"] = [nativeUrlDict stringForKey:@"sendid"];
                
                WCRedEnvelopesLogicMgr *logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("WCRedEnvelopesLogicMgr")];
                [logicMgr ReceiverQueryRedEnvelopesRequest:params];
            };
            
            void (^enqueueParam)(NSDictionary *) = ^(NSDictionary *nativeUrlDict) {
                DDRedEnvelopParam *param = [[DDRedEnvelopParam alloc] init];
                param.msgType = [nativeUrlDict stringForKey:@"msgtype"];
                param.sendId = [nativeUrlDict stringForKey:@"sendid"];
                param.channelId = [nativeUrlDict stringForKey:@"channelid"];
                param.nickName = [selfContact getContactDisplayName];
                param.headImg = [selfContact m_nsHeadImgUrl];
                param.nativeUrl = [wrap.m_oWCPayInfoItem m_c2cNativeUrl];
                param.sessionUserName = isGroupSender() ? wrap.m_nsToUsr : wrap.m_nsFromUsr;
                param.sign = [nativeUrlDict stringForKey:@"sign"];
                param.isGroupSender = isGroupSender();
                
                [[DDRedEnvelopParamQueue sharedQueue] enqueue:param];
            };
            
            if (shouldReceiveRedEnvelop()) {
                NSString *nativeUrl = [wrap.m_oWCPayInfoItem m_c2cNativeUrl];
                NSDictionary *nativeUrlDict = parseNativeUrl(nativeUrl);
                queryRedEnvelopesRequest(nativeUrlDict);
                enqueueParam(nativeUrlDict);
            }
        }
    }
}

CHDeclareClass(WCRedEnvelopesLogicMgr)

CHOptimizedMethod2(self, void, WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, HongBaoRes *, arg1, Request, HongBaoReq *, arg2) {
    CHSuper2(WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, arg1, Request, arg2);
    
    // 查询红包详情响应
    if (arg1.cgiCmdid != 3) return;
    
    NSString *(^parseRequestSign)(void) = ^NSString * {
        NSString *requestString = [[NSString alloc] initWithData:arg2.reqText.buffer encoding:NSUTF8StringEncoding];
        NSDictionary *requestDict = [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:requestString separator:@"&"];
        NSString *nativeUrl = [[requestDict stringForKey:@"nativeUrl"] stringByRemovingPercentEncoding];
        NSDictionary *nativeUrlDict = [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
        return [nativeUrlDict stringForKey:@"sign"];
    };
    
    NSDictionary *responseDict = [[[NSString alloc] initWithData:arg1.retText.buffer encoding:NSUTF8StringEncoding] JSONValue];
    
    DDRedEnvelopParam *param = [[DDRedEnvelopParamQueue sharedQueue] dequeue];
    if (!param) return;
    
    // 检查红包状态
    if ([responseDict[@"receiveStatus"] integerValue] == 2) return; // 已经抢过
    if ([responseDict[@"hbStatus"] integerValue] == 4) return;     // 红包被抢完
    if (!responseDict[@"timingIdentifier"]) return;               // 没有timingIdentifier
    
    if (param.isGroupSender) {
        // 自己发的红包
        if (![DDPluginConfig sharedConfig].autoRedEnvelop) return;
    } else {
        // 别人发的红包
        if (![parseRequestSign() isEqualToString:param.sign]) return;
        if (![DDPluginConfig sharedConfig].autoRedEnvelop) return;
    }
    
    param.timingIdentifier = responseDict[@"timingIdentifier"];
    
    DDRedEnvelopTask *task = [[DDRedEnvelopTask alloc] init];
    task.param = param;
    task.delay = [DDPluginConfig sharedConfig].redEnvelopDelay;
    
    DDRedEnvelopTaskManager *manager = [DDRedEnvelopTaskManager sharedManager];
    if ([DDPluginConfig sharedConfig].redEnvelopMultipleCatch) {
        [manager addSerialTask:task];
    } else {
        [manager addNormalTask:task];
    }
}

#pragma mark - 插件注册
CHConstructor {
    @autoreleasepool {
        // 延迟加载，确保微信主框架初始化完成
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 检查插件管理器是否存在
            Class WCPluginsMgrClass = objc_getClass("WCPluginsMgr");
            if (WCPluginsMgrClass) {
                id pluginMgr = [WCPluginsMgrClass sharedInstance];
                if (pluginMgr) {
                    // 注册带有设置页面的插件
                    [pluginMgr registerControllerWithTitle:@"DD红包" 
                                                  version:@"1.0.0" 
                                              controller:@"DDPluginSettingController"];
                    
                    NSLog(@"✅ DD红包插件注册成功！");
                }
            } else {
                NSLog(@"⚠️ WCPluginsMgr 不存在，插件管理器未找到");
            }
        });
        
        // Hook消息管理器
        CHLoadLateClass(CMessageMgr);
        CHHook2(CMessageMgr, AsyncOnAddMsg, MsgWrap);
        
        // Hook红包逻辑管理器
        CHLoadLateClass(WCRedEnvelopesLogicMgr);
        CHHook2(WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, Request);
    }
}