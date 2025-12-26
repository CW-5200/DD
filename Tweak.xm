// DD红包插件 v1.0.0
// 自动抢红包插件 for WeChat

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

#pragma mark - 配置管理类

@interface DDRedEnvelopConfig : NSObject

@property (nonatomic, assign) BOOL autoReceiveEnable;      // 总开关
@property (nonatomic, assign) BOOL receiveSelfRedEnvelop;  // 抢自己发的红包
@property (nonatomic, assign) BOOL personalRedEnvelopEnable; // 个人红包开关
@property (nonatomic, assign) BOOL serialReceive;          // 顺序抢红包
@property (nonatomic, assign) NSInteger delaySeconds;      // 延迟时间
@property (nonatomic, strong) NSMutableArray *blackList;   // 黑名单

+ (instancetype)sharedConfig;

@end

@implementation DDRedEnvelopConfig

+ (instancetype)sharedConfig {
    static DDRedEnvelopConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[DDRedEnvelopConfig alloc] init];
    });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        _autoReceiveEnable = YES;
        _receiveSelfRedEnvelop = NO;
        _personalRedEnvelopEnable = YES;
        _serialReceive = NO;
        _delaySeconds = 0;
        _blackList = [NSMutableArray array];
        
        // 从UserDefaults加载配置
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:@"DDRedEnvelop_autoReceiveEnable"]) {
            _autoReceiveEnable = [defaults boolForKey:@"DDRedEnvelop_autoReceiveEnable"];
        }
        if ([defaults objectForKey:@"DDRedEnvelop_receiveSelfRedEnvelop"]) {
            _receiveSelfRedEnvelop = [defaults boolForKey:@"DDRedEnvelop_receiveSelfRedEnvelop"];
        }
        if ([defaults objectForKey:@"DDRedEnvelop_personalRedEnvelopEnable"]) {
            _personalRedEnvelopEnable = [defaults boolForKey:@"DDRedEnvelop_personalRedEnvelopEnable"];
        }
        if ([defaults objectForKey:@"DDRedEnvelop_serialReceive"]) {
            _serialReceive = [defaults boolForKey:@"DDRedEnvelop_serialReceive"];
        }
        if ([defaults objectForKey:@"DDRedEnvelop_delaySeconds"]) {
            _delaySeconds = [defaults integerForKey:@"DDRedEnvelop_delaySeconds"];
        }
        if ([defaults objectForKey:@"DDRedEnvelop_blackList"]) {
            _blackList = [[defaults arrayForKey:@"DDRedEnvelop_blackList"] mutableCopy];
        }
    }
    return self;
}

- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:_autoReceiveEnable forKey:@"DDRedEnvelop_autoReceiveEnable"];
    [defaults setBool:_receiveSelfRedEnvelop forKey:@"DDRedEnvelop_receiveSelfRedEnvelop"];
    [defaults setBool:_personalRedEnvelopEnable forKey:@"DDRedEnvelop_personalRedEnvelopEnable"];
    [defaults setBool:_serialReceive forKey:@"DDRedEnvelop_serialReceive"];
    [defaults setInteger:_delaySeconds forKey:@"DDRedEnvelop_delaySeconds"];
    [defaults setObject:_blackList forKey:@"DDRedEnvelop_blackList"];
    [defaults synchronize];
}

@end

#pragma mark - 红包参数类

@interface DDWeChatRedEnvelopParam : NSObject

@property (nonatomic, copy) NSString *msgType;
@property (nonatomic, copy) NSString *sendId;
@property (nonatomic, copy) NSString *channelId;
@property (nonatomic, copy) NSString *nickName;
@property (nonatomic, copy) NSString *headImg;
@property (nonatomic, copy) NSString *nativeUrl;
@property (nonatomic, copy) NSString *sessionUserName;
@property (nonatomic, copy) NSString *sign;
@property (nonatomic, assign) BOOL isGroupSender;
@property (nonatomic, copy) NSString *timingIdentifier;

@end

@implementation DDWeChatRedEnvelopParam
@end

#pragma mark - 红包参数队列

@interface DDRedEnvelopParamQueue : NSObject

+ (instancetype)sharedQueue;
- (void)enqueue:(DDWeChatRedEnvelopParam *)param;
- (DDWeChatRedEnvelopParam *)dequeue;
- (DDWeChatRedEnvelopParam *)peek;
- (BOOL)isEmpty;

@end

@implementation DDRedEnvelopParamQueue {
    NSMutableArray *_queue;
}

+ (instancetype)sharedQueue {
    static DDRedEnvelopParamQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[DDRedEnvelopParamQueue alloc] init];
    });
    return queue;
}

- (instancetype)init {
    if (self = [super init]) {
        _queue = [NSMutableArray array];
    }
    return self;
}

- (void)enqueue:(DDWeChatRedEnvelopParam *)param {
    [_queue addObject:param];
}

- (DDWeChatRedEnvelopParam *)dequeue {
    if (_queue.count == 0) {
        return nil;
    }
    DDWeChatRedEnvelopParam *first = _queue.firstObject;
    [_queue removeObjectAtIndex:0];
    return first;
}

- (DDWeChatRedEnvelopParam *)peek {
    return _queue.firstObject;
}

- (BOOL)isEmpty {
    return _queue.count == 0;
}

@end

#pragma mark - 任务管理器

@interface DDRedEnvelopTaskManager : NSObject

@property (nonatomic, assign) BOOL serialQueueIsEmpty;

+ (instancetype)sharedManager;
- (void)addSerialTask:(id)task;
- (void)addNormalTask:(id)task;

@end

@implementation DDRedEnvelopTaskManager {
    dispatch_queue_t _serialQueue;
    NSOperationQueue *_concurrentQueue;
}

+ (instancetype)sharedManager {
    static DDRedEnvelopTaskManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[DDRedEnvelopTaskManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        _serialQueue = dispatch_queue_create("com.dd.redenvelop.serial", DISPATCH_QUEUE_SERIAL);
        _concurrentQueue = [[NSOperationQueue alloc] init];
        _concurrentQueue.maxConcurrentOperationCount = 5;
        _serialQueueIsEmpty = YES;
    }
    return self;
}

- (void)addSerialTask:(id)task {
    _serialQueueIsEmpty = NO;
    dispatch_async(_serialQueue, ^{
        // 执行任务
        if ([task respondsToSelector:@selector(execute)]) {
            [task performSelector:@selector(execute)];
        }
        self->_serialQueueIsEmpty = YES;
    });
}

- (void)addNormalTask:(id)task {
    if ([task isKindOfClass:[NSOperation class]]) {
        [_concurrentQueue addOperation:task];
    }
}

@end

#pragma mark - 抢红包操作类

@interface DDReceiveRedEnvelopOperation : NSOperation

@property (nonatomic, strong) DDWeChatRedEnvelopParam *redEnvelopParam;
@property (nonatomic, assign) unsigned int delaySeconds;

- (instancetype)initWithRedEnvelopParam:(DDWeChatRedEnvelopParam *)param delay:(unsigned int)delay;

@end

@implementation DDReceiveRedEnvelopOperation {
    BOOL _isFinished;
    BOOL _isExecuting;
}

- (instancetype)initWithRedEnvelopParam:(DDWeChatRedEnvelopParam *)param delay:(unsigned int)delay {
    if (self = [super init]) {
        _redEnvelopParam = param;
        _delaySeconds = delay;
        _isFinished = NO;
        _isExecuting = NO;
    }
    return self;
}

- (void)start {
    if (self.isCancelled) {
        [self willChangeValueForKey:@"isFinished"];
        _isFinished = YES;
        [self didChangeValueForKey:@"isFinished"];
        return;
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = YES;
    [self didChangeValueForKey:@"isExecuting"];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_delaySeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self execute];
    });
}

- (void)execute {
    // 这里应该调用微信的打开红包方法
    // 由于原代码中的具体实现未知，这里简化为调用一个方法
    Class logicMgrClass = NSClassFromString(@"WCRedEnvelopesLogicMgr");
    if (logicMgrClass) {
        id logicMgr = [[NSClassFromString(@"MMServiceCenter") defaultCenter] getService:logicMgrClass];
        if ([logicMgr respondsToSelector:@selector(OpenRedEnvelopesRequest:)]) {
            [logicMgr performSelector:@selector(OpenRedEnvelopesRequest:) withObject:_redEnvelopParam];
        }
    }
    
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
    _isExecuting = NO;
    _isFinished = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isExecuting {
    return _isExecuting;
}

- (BOOL)isFinished {
    return _isFinished;
}

@end

#pragma mark - Hook: WCRedEnvelopesLogicMgr

%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig;
    
    // 非参数查询请求
    if ([arg1 cgiCmdid] != 3) { return; }
    
    NSString *(^parseRequestSign)(void) = ^NSString * {
        NSString *requestString = [[NSString alloc] initWithData:[arg2 reqText].buffer encoding:NSUTF8StringEncoding];
        NSArray *components = [requestString componentsSeparatedByString:@"&"];
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        for (NSString *component in components) {
            NSArray *keyValue = [component componentsSeparatedByString:@"="];
            if (keyValue.count == 2) {
                dict[keyValue[0]] = keyValue[1];
            }
        }
        NSString *nativeUrl = [[dict[@"nativeUrl"] stringByRemovingPercentEncoding] stringByReplacingOccurrencesOfString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" withString:@""];
        NSArray *nativeComponents = [nativeUrl componentsSeparatedByString:@"&"];
        NSMutableDictionary *nativeDict = [NSMutableDictionary dictionary];
        for (NSString *component in nativeComponents) {
            NSArray *keyValue = [component componentsSeparatedByString:@"="];
            if (keyValue.count == 2) {
                nativeDict[keyValue[0]] = keyValue[1];
            }
        }
        return nativeDict[@"sign"];
    };
    
    NSString *responseString = [[NSString alloc] initWithData:[arg1 retText].buffer encoding:NSUTF8StringEncoding];
    NSData *jsonData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    DDWeChatRedEnvelopParam *mgrParams = [[DDRedEnvelopParamQueue sharedQueue] dequeue];
    
    BOOL (^shouldReceiveRedEnvelop)(void) = ^BOOL {
        // 手动抢红包
        if (!mgrParams) { return NO; }
        
        // 自己已经抢过
        if ([responseDict[@"receiveStatus"] integerValue] == 2) { return NO; }
        
        // 红包被抢完
        if ([responseDict[@"hbStatus"] integerValue] == 4) { return NO; }  
        
        // 没有这个字段会被判定为使用外挂
        if (!responseDict[@"timingIdentifier"]) { return NO; }  
        
        if (mgrParams.isGroupSender) { 
            // 自己发红包的时候没有 sign 字段
            return [DDRedEnvelopConfig sharedConfig].autoReceiveEnable;
        } else {
            return [parseRequestSign() isEqualToString:mgrParams.sign] && [DDRedEnvelopConfig sharedConfig].autoReceiveEnable;
        }
    };
    
    if (shouldReceiveRedEnvelop()) {
        mgrParams.timingIdentifier = responseDict[@"timingIdentifier"];
        
        unsigned int delaySeconds = [self calculateDelaySeconds];
        DDReceiveRedEnvelopOperation *operation = [[DDReceiveRedEnvelopOperation alloc] initWithRedEnvelopParam:mgrParams delay:delaySeconds];
        
        if ([DDRedEnvelopConfig sharedConfig].serialReceive) {
            [[DDRedEnvelopTaskManager sharedManager] addSerialTask:operation];
        } else {
            [[DDRedEnvelopTaskManager sharedManager] addNormalTask:operation];
        }
    }
}

- (unsigned int)calculateDelaySeconds {
    NSInteger configDelaySeconds = [DDRedEnvelopConfig sharedConfig].delaySeconds;
    
    if ([DDRedEnvelopConfig sharedConfig].serialReceive) {
        unsigned int serialDelaySeconds;
        if ([DDRedEnvelopTaskManager sharedManager].serialQueueIsEmpty) {
            serialDelaySeconds = (unsigned int)configDelaySeconds;
        } else {
            serialDelaySeconds = 5;
        }
        
        return serialDelaySeconds;
    } else {
        return (unsigned int)configDelaySeconds;
    }
}

%end

#pragma mark - Hook: CMessageMgr

%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(id)wrap {
    %orig;
    
    int messageType = (int)[wrap m_uiMessageType];
    if (messageType == 49) { // AppNode
        // 是否为红包消息
        BOOL (^isRedEnvelopMessage)(void) = ^BOOL {
            NSString *content = [wrap m_nsContent];
            return content && [content rangeOfString:@"wxpay://"].location != NSNotFound;
        };
        
        if (isRedEnvelopMessage()) {
            // 获取自己的联系人信息
            Class contactMgrClass = NSClassFromString(@"CContactMgr");
            id contactManager = [[NSClassFromString(@"MMServiceCenter") defaultCenter] getService:contactMgrClass];
            id selfContact = [contactManager getSelfContact];
            NSString *selfUserName = [selfContact m_nsUsrName];
            
            BOOL (^isSender)(void) = ^BOOL {
                return [[wrap m_nsFromUsr] isEqualToString:selfUserName];
            };
            
            // 是否别人在群聊中发消息
            BOOL (^isGroupReceiver)(void) = ^BOOL {
                return [[wrap m_nsFromUsr] rangeOfString:@"@chatroom"].location != NSNotFound;
            };
            
            // 是否自己在群聊中发消息
            BOOL (^isGroupSender)(void) = ^BOOL {
                return isSender() && [[wrap m_nsToUsr] rangeOfString:@"chatroom"].location != NSNotFound;
            };
            
            // 是否在黑名单中
            BOOL (^isGroupInBlackList)(void) = ^BOOL {
                return [[DDRedEnvelopConfig sharedConfig].blackList containsObject:[wrap m_nsFromUsr]];
            };
            
            // 是否自动抢红包
            BOOL (^shouldReceiveRedEnvelop)(void) = ^BOOL {
                if (![DDRedEnvelopConfig sharedConfig].autoReceiveEnable) { return NO; }
                if (isGroupInBlackList()) { return NO; }
                
                if (isGroupReceiver()) {
                    return YES;
                } else if (isGroupSender() && [DDRedEnvelopConfig sharedConfig].receiveSelfRedEnvelop) {
                    return YES;
                } else if (!isGroupReceiver() && !isGroupSender() && [DDRedEnvelopConfig sharedConfig].personalRedEnvelopEnable) {
                    return YES;
                }
                return NO;
            };
            
            if (shouldReceiveRedEnvelop()) {
                // 解析红包参数
                NSString *content = [wrap m_nsContent];
                NSRange range = [content rangeOfString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"];
                if (range.location != NSNotFound) {
                    NSString *paramsString = [content substringFromIndex:range.location + range.length];
                    NSArray *components = [paramsString componentsSeparatedByString:@"&"];
                    NSMutableDictionary *paramsDict = [NSMutableDictionary dictionary];
                    
                    for (NSString *component in components) {
                        NSArray *keyValue = [component componentsSeparatedByString:@"="];
                        if (keyValue.count == 2) {
                            paramsDict[keyValue[0]] = [keyValue[1] stringByRemovingPercentEncoding];
                        }
                    }
                    
                    DDWeChatRedEnvelopParam *param = [[DDWeChatRedEnvelopParam alloc] init];
                    param.msgType = paramsDict[@"msgtype"];
                    param.sendId = paramsDict[@"sendid"];
                    param.channelId = paramsDict[@"channelid"];
                    param.nativeUrl = [content substringFromIndex:range.location];
                    param.sign = paramsDict[@"sign"];
                    
                    if (isGroupReceiver()) {
                        param.isGroupSender = NO;
                        param.sessionUserName = [wrap m_nsFromUsr];
                    } else if (isGroupSender()) {
                        param.isGroupSender = YES;
                        param.sessionUserName = [wrap m_nsToUsr];
                    } else {
                        param.isGroupSender = NO;
                        param.sessionUserName = [wrap m_nsFromUsr];
                    }
                    
                    [[DDRedEnvelopParamQueue sharedQueue] enqueue:param];
                    
                    // 延迟查询红包详情
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        Class logicMgrClass = NSClassFromString(@"WCRedEnvelopesLogicMgr");
                        if (logicMgrClass) {
                            id logicMgr = [[NSClassFromString(@"MMServiceCenter") defaultCenter] getService:logicMgrClass];
                            if ([logicMgr respondsToSelector:@selector(QueryRedEnvelopesDetailRequest:)]) {
                                [logicMgr performSelector:@selector(QueryRedEnvelopesDetailRequest:) withObject:param];
                            }
                        }
                    });
                }
            }
        }
    }
}

%end

#pragma mark - 设置界面

@interface DDRedEnvelopSettingViewController : UITableViewController

@property (nonatomic, strong) NSArray *settings;

@end

@implementation DDRedEnvelopSettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"DD红包设置";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone target:self action:@selector(saveSettings)];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    self.tableView.tableFooterView = [[UIView alloc] init];
    
    self.settings = @[
        @{@"title": @"自动抢红包", @"key": @"autoReceiveEnable", @"type": @"switch"},
        @{@"title": @"抢自己发的红包", @"key": @"receiveSelfRedEnvelop", @"type": @"switch"},
        @{@"title": @"抢个人红包", @"key": @"personalRedEnvelopEnable", @"type": @"switch"},
        @{@"title": @"顺序抢红包", @"key": @"serialReceive", @"type": @"switch"},
        @{@"title": @"延迟时间(秒)", @"key": @"delaySeconds", @"type": @"number"},
        @{@"title": @"黑名单管理", @"key": @"blackList", @"type": @"button"}
    ];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.settings.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    NSDictionary *setting = self.settings[indexPath.row];
    cell.textLabel.text = setting[@"title"];
    
    if ([setting[@"type"] isEqualToString:@"switch"]) {
        UISwitch *switchView = [[UISwitch alloc] init];
        BOOL value = [[[DDRedEnvelopConfig sharedConfig] valueForKey:setting[@"key"]] boolValue];
        [switchView setOn:value animated:NO];
        [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        switchView.tag = indexPath.row;
        cell.accessoryView = switchView;
    } else if ([setting[@"type"] isEqualToString:@"number"]) {
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 30)];
        label.text = [NSString stringWithFormat:@"%ld", (long)[DDRedEnvelopConfig sharedConfig].delaySeconds];
        label.textAlignment = NSTextAlignmentRight;
        cell.accessoryView = label;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if ([setting[@"type"] isEqualToString:@"button"]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *setting = self.settings[indexPath.row];
    
    if ([setting[@"type"] isEqualToString:@"number"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置延迟时间" message:@"请输入延迟时间(秒):" preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.keyboardType = UIKeyboardTypeNumberPad;
            textField.placeholder = @"延迟秒数";
            textField.text = [NSString stringWithFormat:@"%ld", (long)[DDRedEnvelopConfig sharedConfig].delaySeconds];
        }];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *text = alert.textFields.firstObject.text;
            [DDRedEnvelopConfig sharedConfig].delaySeconds = [text integerValue];
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        }]];
        
        [self presentViewController:alert animated:YES completion:nil];
    } else if ([setting[@"type"] isEqualToString:@"button"]) {
        if ([setting[@"key"] isEqualToString:@"blackList"]) {
            // 黑名单管理界面
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"黑名单管理" message:@"请输入要加入黑名单的群聊ID:" preferredStyle:UIAlertControllerStyleAlert];
            
            [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                textField.placeholder = @"群聊ID (如: xxxx@chatroom)";
            }];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            [alert addAction:[UIAlertAction actionWithTitle:@"添加" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                NSString *groupId = alert.textFields.firstObject.text;
                if (groupId.length > 0) {
                    if (![[DDRedEnvelopConfig sharedConfig].blackList containsObject:groupId]) {
                        [[DDRedEnvelopConfig sharedConfig].blackList addObject:groupId];
                    }
                }
            }]];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"查看列表" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                UIAlertController *listAlert = [UIAlertController alertControllerWithTitle:@"黑名单列表" message:[[DDRedEnvelopConfig sharedConfig].blackList componentsJoinedByString:@"\n"] preferredStyle:UIAlertControllerStyleAlert];
                [listAlert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
                [self presentViewController:listAlert animated:YES completion:nil];
            }]];
            
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

- (void)switchChanged:(UISwitch *)sender {
    NSDictionary *setting = self.settings[sender.tag];
    NSString *key = setting[@"key"];
    [[DDRedEnvelopConfig sharedConfig] setValue:@(sender.isOn) forKey:key];
}

- (void)saveSettings {
    [[DDRedEnvelopConfig sharedConfig] saveConfig];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" message:@"设置已保存" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - 插件入口

// 插件管理器接口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

// 插件初始化
__attribute__((constructor)) static void DDRedEnvelopPluginEntry() {
    // 延迟执行，确保微信已启动
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (NSClassFromString(@"WCPluginsMgr")) {
            // 注册设置页面
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD红包" 
                                                                               version:@"1.0.0" 
                                                                           controller:@"DDRedEnvelopSettingViewController"];
        }
    });
}

%ctor {
    // 初始化配置
    [DDRedEnvelopConfig sharedConfig];
    
    // 应用Hook
    %init;
}