//  DD红包助手 v1.0.0
//  Created by DDHelper
//  功能：自动抢红包、延迟抢红包、群聊过滤、抢自己红包、防止同时抢多个红包

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CaptainHook/CaptainHook.h>

// 插件配置管理
@interface DDRedEnvelopConfig : NSObject
+ (instancetype)shared;

@property (nonatomic, assign) BOOL autoRedEnvelop;         // 自动抢红包
@property (nonatomic, assign) NSInteger redEnvelopDelay;   // 延迟时间（毫秒）
@property (nonatomic, strong) NSArray *redEnvelopGroupFilter; // 群聊过滤
@property (nonatomic, assign) BOOL redEnvelopCatchMe;      // 抢自己红包
@property (nonatomic, assign) BOOL redEnvelopMultipleCatch; // 防止同时抢多个红包

- (void)saveConfig;
@end

// 红包参数模型
@interface DDRedEnvelopParam : NSObject
@property (strong, nonatomic) NSString *msgType;
@property (strong, nonatomic) NSString *sendId;
@property (strong, nonatomic) NSString *channelId;
@property (strong, nonatomic) NSString *nickName;
@property (strong, nonatomic) NSString *headImg;
@property (strong, nonatomic) NSString *nativeUrl;
@property (strong, nonatomic) NSString *sessionUserName;
@property (strong, nonatomic) NSString *sign;
@property (strong, nonatomic) NSString *timingIdentifier;
@property (assign, nonatomic) BOOL isGroupSender;
- (NSDictionary *)toParams;
@end

// 红包参数队列
@interface DDRedEnvelopParamQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(DDRedEnvelopParam *)param;
- (DDRedEnvelopParam *)dequeue;
- (DDRedEnvelopParam *)peek;
- (BOOL)isEmpty;
@end

// 红包领取操作
@interface DDReceiveRedEnvelopOperation : NSOperation
@property (assign, nonatomic, getter=isExecuting) BOOL executing;
@property (assign, nonatomic, getter=isFinished) BOOL finished;
- (instancetype)initWithRedEnvelopParam:(DDRedEnvelopParam *)param delay:(unsigned int)delaySeconds;
@end

// 红包任务管理器
@interface DDRedEnvelopTaskManager : NSObject
+ (instancetype)sharedManager;
- (void)addNormalTask:(DDReceiveRedEnvelopOperation *)task;
- (void)addSerialTask:(DDReceiveRedEnvelopOperation *)task;
- (BOOL)serialQueueIsEmpty;
@end

// 设置控制器
@interface DDRedEnvelopSettingController : UIViewController
@end

// ==================== 配置管理实现 ====================
@implementation DDRedEnvelopConfig

+ (instancetype)shared {
    static DDRedEnvelopConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[DDRedEnvelopConfig alloc] init];
        [config loadConfig];
    });
    return config;
}

- (void)loadConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _autoRedEnvelop = [defaults boolForKey:@"DD_autoRedEnvelop"];
    _redEnvelopDelay = [defaults integerForKey:@"DD_redEnvelopDelay"];
    _redEnvelopGroupFilter = [defaults arrayForKey:@"DD_redEnvelopGroupFilter"] ?: @[];
    _redEnvelopCatchMe = [defaults boolForKey:@"DD_redEnvelopCatchMe"];
    _redEnvelopMultipleCatch = [defaults boolForKey:@"DD_redEnvelopMultipleCatch"];
}

- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:_autoRedEnvelop forKey:@"DD_autoRedEnvelop"];
    [defaults setInteger:_redEnvelopDelay forKey:@"DD_redEnvelopDelay"];
    [defaults setObject:_redEnvelopGroupFilter forKey:@"DD_redEnvelopGroupFilter"];
    [defaults setBool:_redEnvelopCatchMe forKey:@"DD_redEnvelopCatchMe"];
    [defaults setBool:_redEnvelopMultipleCatch forKey:@"DD_redEnvelopMultipleCatch"];
    [defaults synchronize];
}

@end

// ==================== 红包参数模型实现 ====================
@implementation DDRedEnvelopParam

- (NSDictionary *)toParams {
    return @{
        @"msgType": self.msgType ?: @"",
        @"sendId": self.sendId ?: @"",
        @"channelId": self.channelId ?: @"",
        @"nickName": self.nickName ?: @"",
        @"headImg": self.headImg ?: @"",
        @"nativeUrl": self.nativeUrl ?: @"",
        @"sessionUserName": self.sessionUserName ?: @"",
        @"timingIdentifier": self.timingIdentifier ?: @""
    };
}

@end

// ==================== 红包参数队列实现 ====================
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
        _queue = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)enqueue:(DDRedEnvelopParam *)param {
    [_queue addObject:param];
}

- (DDRedEnvelopParam *)dequeue {
    if (_queue.count == 0) return nil;
    DDRedEnvelopParam *first = _queue.firstObject;
    [_queue removeObjectAtIndex:0];
    return first;
}

- (DDRedEnvelopParam *)peek {
    return _queue.firstObject;
}

- (BOOL)isEmpty {
    return _queue.count == 0;
}

@end

// ==================== 红包领取操作实现 ====================
@implementation DDReceiveRedEnvelopOperation

@synthesize executing = _executing;
@synthesize finished = _finished;

- (instancetype)initWithRedEnvelopParam:(DDRedEnvelopParam *)param delay:(unsigned int)delaySeconds {
    if (self = [super init]) {
        _redEnvelopParam = param;
        _delaySeconds = delaySeconds;
    }
    return self;
}

- (void)start {
    if (self.isCancelled) {
        self.finished = YES;
        self.executing = NO;
        return;
    }
    
    [self main];
    self.executing = YES;
    self.finished = NO;
}

- (void)main {
    [NSThread sleepForTimeInterval:self.delaySeconds / 1000.0];
    
    // 调用微信的红包领取接口
    Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
    if (logicMgrClass) {
        id logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:logicMgrClass];
        if ([logicMgr respondsToSelector:@selector(OpenRedEnvelopesRequest:)]) {
            [logicMgr performSelector:@selector(OpenRedEnvelopesRequest:) withObject:[self.redEnvelopParam toParams]];
        }
    }
    
    self.finished = YES;
    self.executing = NO;
}

- (void)cancel {
    self.finished = YES;
    self.executing = NO;
}

- (void)setFinished:(BOOL)finished {
    [self willChangeValueForKey:@"isFinished"];
    _finished = finished;
    [self didChangeValueForKey:@"isFinished"];
}

- (void)setExecuting:(BOOL)executing {
    [self willChangeValueForKey:@"isExecuting"];
    _executing = executing;
    [self didChangeValueForKey:@"isExecuting"];
}

- (BOOL)isAsynchronous {
    return YES;
}

@end

// ==================== 红包任务管理器实现 ====================
@implementation DDRedEnvelopTaskManager {
    NSOperationQueue *_normalTaskQueue;
    NSOperationQueue *_serialTaskQueue;
}

+ (instancetype)sharedManager {
    static DDRedEnvelopTaskManager *taskManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        taskManager = [DDRedEnvelopTaskManager new];
    });
    return taskManager;
}

- (instancetype)init {
    if (self = [super init]) {
        _serialTaskQueue = [[NSOperationQueue alloc] init];
        _serialTaskQueue.maxConcurrentOperationCount = 1;
        _normalTaskQueue = [[NSOperationQueue alloc] init];
        _normalTaskQueue.maxConcurrentOperationCount = 5;
    }
    return self;
}

- (void)addNormalTask:(DDReceiveRedEnvelopOperation *)task {
    [_normalTaskQueue addOperation:task];
}

- (void)addSerialTask:(DDReceiveRedEnvelopOperation *)task {
    [_serialTaskQueue addOperation:task];
}

- (BOOL)serialQueueIsEmpty {
    return _serialTaskQueue.operations.count == 0;
}

@end

// ==================== 设置控制器实现 ====================
@implementation DDRedEnvelopSettingController {
    UITableView *_tableView;
    NSArray *_dataSource;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD红包助手";
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 创建返回按钮
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:@"返回"
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(backAction)];
    self.navigationItem.leftBarButtonItem = backButton;
    
    // 创建表格
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
    
    [self setupDataSource];
}

- (void)setupDataSource {
    _dataSource = @[
        @{@"title": @"自动抢红包", @"type": @"switch", @"key": @"autoRedEnvelop"},
        @{@"title": @"延迟抢红包", @"type": @"input", @"key": @"redEnvelopDelay", @"placeholder": @"毫秒", @"value": @([DDRedEnvelopConfig shared].redEnvelopDelay)},
        @{@"title": @"群聊过滤", @"type": @"group", @"key": @"redEnvelopGroupFilter"},
        @{@"title": @"抢自己红包", @"type": @"switch", @"key": @"redEnvelopCatchMe"},
        @{@"title": @"防止同时抢多个红包", @"type": @"switch", @"key": @"redEnvelopMultipleCatch"}
    ];
}

- (void)backAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _dataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = _dataSource[indexPath.row];
    NSString *type = item[@"type"];
    
    if ([type isEqualToString:@"switch"]) {
        return [self switchCellForItem:item indexPath:indexPath];
    } else if ([type isEqualToString:@"input"]) {
        return [self inputCellForItem:item indexPath:indexPath];
    } else {
        return [self normalCellForItem:item indexPath:indexPath];
    }
}

- (UITableViewCell *)switchCellForItem:(NSDictionary *)item indexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"SwitchCell";
    UITableViewCell *cell = [_tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.tag = 1000;
        [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    }
    
    cell.textLabel.text = item[@"title"];
    UISwitch *switchView = (UISwitch *)cell.accessoryView;
    NSString *key = item[@"key"];
    
    if ([key isEqualToString:@"autoRedEnvelop"]) {
        switchView.on = [DDRedEnvelopConfig shared].autoRedEnvelop;
    } else if ([key isEqualToString:@"redEnvelopCatchMe"]) {
        switchView.on = [DDRedEnvelopConfig shared].redEnvelopCatchMe;
    } else if ([key isEqualToString:@"redEnvelopMultipleCatch"]) {
        switchView.on = [DDRedEnvelopConfig shared].redEnvelopMultipleCatch;
    }
    
    switchView.accessibilityIdentifier = key;
    
    return cell;
}

- (UITableViewCell *)inputCellForItem:(NSDictionary *)item indexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"InputCell";
    UITableViewCell *cell = [_tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
    }
    
    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", item[@"value"]];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (UITableViewCell *)normalCellForItem:(NSDictionary *)item indexPath:(NSIndexPath *)indexPath {
    static NSString *cellId = @"NormalCell";
    UITableViewCell *cell = [_tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    cell.textLabel.text = item[@"title"];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *item = _dataSource[indexPath.row];
    NSString *key = item[@"key"];
    
    if ([key isEqualToString:@"redEnvelopDelay"]) {
        [self showDelayInputAlert];
    } else if ([key isEqualToString:@"redEnvelopGroupFilter"]) {
        [self showGroupFilterAlert];
    }
}

- (void)switchChanged:(UISwitch *)sender {
    NSString *key = sender.accessibilityIdentifier;
    BOOL value = sender.isOn;
    
    if ([key isEqualToString:@"autoRedEnvelop"]) {
        [DDRedEnvelopConfig shared].autoRedEnvelop = value;
    } else if ([key isEqualToString:@"redEnvelopCatchMe"]) {
        [DDRedEnvelopConfig shared].redEnvelopCatchMe = value;
    } else if ([key isEqualToString:@"redEnvelopMultipleCatch"]) {
        [DDRedEnvelopConfig shared].redEnvelopMultipleCatch = value;
    }
    
    [[DDRedEnvelopConfig shared] saveConfig];
}

- (void)showDelayInputAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"延迟时间"
                                                                   message:@"输入延迟时间（毫秒）"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"例如：1000";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%ld", [DDRedEnvelopConfig shared].redEnvelopDelay];
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textField = alert.textFields.firstObject;
        NSInteger delay = [textField.text integerValue];
        [DDRedEnvelopConfig shared].redEnvelopDelay = MAX(0, delay);
        [[DDRedEnvelopConfig shared] saveConfig];
        [_tableView reloadData];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showGroupFilterAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"群聊过滤"
                                                                   message:@"输入要过滤的群聊ID，多个用逗号分隔"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"例如：xxxx@chatroom,yyyy@chatroom";
        NSArray *groups = [DDRedEnvelopConfig shared].redEnvelopGroupFilter;
        textField.text = [groups componentsJoinedByString:@","];
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *text = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSArray *groups = text.length > 0 ? [text componentsSeparatedByString:@","] : @[];
        [DDRedEnvelopConfig shared].redEnvelopGroupFilter = groups;
        [[DDRedEnvelopConfig shared] saveConfig];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end

// ==================== Hook微信关键类 ====================

// 声明要hook的微信类
CHDeclareClass(CMessageMgr);
CHDeclareClass(WCRedEnvelopesLogicMgr);

// Hook CMessageMgr 的 AsyncOnAddMsg:MsgWrap: 方法，监听红包消息
CHMethod(2, void, CMessageMgr, AsyncOnAddMsg, NSString *, msg, MsgWrap, id, wrap)
{
    // 先调用原始方法
    CHSuper(2, CMessageMgr, AsyncOnAddMsg, msg, MsgWrap, wrap);
    
    // 检查是否是红包消息
    if (![DDRedEnvelopConfig shared].autoRedEnvelop) return;
    
    // 获取消息类型
    NSInteger messageType = [[wrap valueForKey:@"m_uiMessageType"] integerValue];
    if (messageType != 49) return; // AppNode 类型消息
    
    // 检查是否是红包消息
    NSString *content = [wrap valueForKey:@"m_nsContent"];
    if (![content containsString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"]) return;
    
    // 获取发送者和接收者
    NSString *fromUsr = [wrap valueForKey:@"m_nsFromUsr"];
    NSString *toUsr = [wrap valueForKey:@"m_nsToUsr"];
    
    // 群聊过滤检查
    NSArray *filterGroups = [DDRedEnvelopConfig shared].redEnvelopGroupFilter;
    if ([filterGroups containsObject:fromUsr]) return;
    
    // 获取自己信息
    Class contactMgrClass = objc_getClass("CContactMgr");
    id contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:contactMgrClass];
    id selfContact = [contactMgr performSelector:@selector(getSelfContact)];
    NSString *selfUsrName = [selfContact valueForKey:@"m_nsUsrName"];
    
    // 判断是否是自己发送的红包
    BOOL isSender = [fromUsr isEqualToString:selfUsrName];
    BOOL isGroupSender = isSender && [toUsr containsString:@"chatroom"];
    BOOL isGroupReceiver = [fromUsr containsString:@"chatroom"];
    
    // 检查是否抢自己红包
    if (isGroupSender && ![DDRedEnvelopConfig shared].redEnvelopCatchMe) return;
    
    // 需要抢红包的情况
    BOOL shouldReceive = NO;
    if (isGroupReceiver) {
        shouldReceive = YES;
    } else if (isGroupSender && [DDRedEnvelopConfig shared].redEnvelopCatchMe) {
        shouldReceive = YES;
    }
    
    if (!shouldReceive) return;
    
    // 解析红包参数
    NSString *nativeUrl = [[[wrap valueForKey:@"m_oWCPayInfoItem"] valueForKey:@"m_c2cNativeUrl"] stringByRemovingPercentEncoding];
    
    if (!nativeUrl) return;
    
    // 提取参数
    NSRange range = [nativeUrl rangeOfString:@"?"];
    if (range.location == NSNotFound) return;
    
    NSString *paramString = [nativeUrl substringFromIndex:range.location + 1];
    NSArray *params = [paramString componentsSeparatedByString:@"&"];
    NSMutableDictionary *paramDict = [NSMutableDictionary dictionary];
    
    for (NSString *param in params) {
        NSArray *keyValue = [param componentsSeparatedByString:@"="];
        if (keyValue.count == 2) {
            paramDict[keyValue[0]] = keyValue[1];
        }
    }
    
    // 创建红包参数
    DDRedEnvelopParam *envelopParam = [[DDRedEnvelopParam alloc] init];
    envelopParam.msgType = paramDict[@"msgtype"];
    envelopParam.sendId = paramDict[@"sendid"];
    envelopParam.channelId = paramDict[@"channelid"];
    envelopParam.nativeUrl = nativeUrl;
    envelopParam.sessionUserName = isGroupSender ? toUsr : fromUsr;
    envelopParam.sign = paramDict[@"sign"];
    envelopParam.isGroupSender = isGroupSender;
    
    // 获取昵称和头像
    if (selfContact) {
        NSString *nickName = [selfContact performSelector:@selector(getContactDisplayName)];
        NSString *headImg = [selfContact valueForKey:@"m_nsHeadImgUrl"];
        envelopParam.nickName = nickName;
        envelopParam.headImg = headImg;
    }
    
    // 查询红包信息
    NSMutableDictionary *queryParams = [@{
        @"agreeDuty": @"0",
        @"channelId": envelopParam.channelId ?: @"",
        @"inWay": @"0",
        @"msgType": envelopParam.msgType ?: @"",
        @"nativeUrl": envelopParam.nativeUrl ?: @"",
        @"sendId": envelopParam.sendId ?: @""
    } mutableCopy];
    
    Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
    if (logicMgrClass) {
        id logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:logicMgrClass];
        if ([logicMgr respondsToSelector:@selector(ReceiverQueryRedEnvelopesRequest:)]) {
            [logicMgr performSelector:@selector(ReceiverQueryRedEnvelopesRequest:) withObject:queryParams];
        }
    }
    
    // 加入队列
    [[DDRedEnvelopParamQueue sharedQueue] enqueue:envelopParam];
}

// Hook WCRedEnvelopesLogicMgr 的 OnWCToHongbaoCommonResponse:Request: 方法，处理红包查询响应
CHMethod(2, void, WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, id, arg1, Request, id, arg2)
{
    // 先调用原始方法
    CHSuper(2, WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, arg1, Request, arg2);
    
    // 检查是否是查询响应
    NSInteger cgiCmdid = [[arg1 valueForKey:@"cgiCmdid"] integerValue];
    if (cgiCmdid != 3) return; // 查询响应
    
    if (![DDRedEnvelopConfig shared].autoRedEnvelop) return;
    
    // 解析响应数据
    NSData *retData = [[arg1 valueForKey:@"retText"] valueForKey:@"buffer"];
    if (!retData) return;
    
    NSString *retString = [[NSString alloc] initWithData:retData encoding:NSUTF8StringEncoding];
    if (!retString) return;
    
    NSData *jsonData = [retString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *error;
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    
    if (error || !responseDict) return;
    
    // 检查红包状态
    NSInteger receiveStatus = [responseDict[@"receiveStatus"] integerValue];
    NSInteger hbStatus = [responseDict[@"hbStatus"] integerValue];
    NSString *timingIdentifier = responseDict[@"timingIdentifier"];
    
    if (receiveStatus == 2) return; // 已经抢过
    if (hbStatus == 4) return; // 红包被抢完
    if (!timingIdentifier) return; // 没有定时标识
    
    // 从队列中取出参数
    DDRedEnvelopParam *envelopParam = [[DDRedEnvelopParamQueue sharedQueue] dequeue];
    if (!envelopParam) return;
    
    // 验证签名
    NSData *reqData = [[arg2 valueForKey:@"reqText"] valueForKey:@"buffer"];
    if (reqData) {
        NSString *reqString = [[NSString alloc] initWithData:reqData encoding:NSUTF8StringEncoding];
        if (reqString) {
            NSArray *reqParams = [reqString componentsSeparatedByString:@"&"];
            for (NSString *param in reqParams) {
                if ([param hasPrefix:@"nativeUrl="]) {
                    NSString *nativeUrl = [[param substringFromIndex:10] stringByRemovingPercentEncoding];
                    NSRange range = [nativeUrl rangeOfString:@"sign="];
                    if (range.location != NSNotFound) {
                        NSString *sign = [nativeUrl substringFromIndex:range.location + 5];
                        if (![envelopParam.isGroupSender boolValue] && ![sign isEqualToString:envelopParam.sign]) {
                            return; // 签名不匹配
                        }
                    }
                    break;
                }
            }
        }
    }
    
    // 设置定时标识
    envelopParam.timingIdentifier = timingIdentifier;
    
    // 计算延迟时间
    unsigned int delaySeconds = 0;
    if ([DDRedEnvelopConfig shared].redEnvelopDelay > 0) {
        if ([DDRedEnvelopConfig shared].redEnvelopMultipleCatch && 
            ![[DDRedEnvelopTaskManager sharedManager] serialQueueIsEmpty]) {
            delaySeconds = 15000; // 15秒
        } else {
            delaySeconds = (unsigned int)[DDRedEnvelopConfig shared].redEnvelopDelay;
        }
    }
    
    // 创建领取任务
    DDReceiveRedEnvelopOperation *operation = [[DDReceiveRedEnvelopOperation alloc] initWithRedEnvelopParam:envelopParam delay:delaySeconds];
    
    // 添加到任务队列
    if ([DDRedEnvelopConfig shared].redEnvelopMultipleCatch) {
        [[DDRedEnvelopTaskManager sharedManager] addSerialTask:operation];
    } else {
        [[DDRedEnvelopTaskManager sharedManager] addNormalTask:operation];
    }
}

// 在构造函数中注册hook
CHConstructor {
    @autoreleasepool {
        // 加载配置
        [DDRedEnvelopConfig shared];
        
        // 注册hook
        CHLoadLateClass(CMessageMgr);
        CHHook(2, CMessageMgr, AsyncOnAddMsg, MsgWrap);
        
        CHLoadLateClass(WCRedEnvelopesLogicMgr);
        CHHook(2, WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, Request);
        
        // 注册插件设置入口
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (NSClassFromString(@"WCPluginsMgr")) {
                [[objc_getClass("WCPluginsMgr") sharedInstance] 
                    registerControllerWithTitle:@"DD红包助手" 
                    version:@"1.0.0" 
                    controller:@"DDRedEnvelopSettingController"];
            }
        });
    }
}

// 需要导出的符号
__attribute__((visibility("default"))) 
NSString *DDRedEnvelopHelperVersion = @"1.0.0";