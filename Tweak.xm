// DD红包 v1.0.0
// Created by DDHelper
// 功能：自动抢红包、延迟抢红包、群聊过滤、抢自己红包、防止同时抢多个红包

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

#pragma mark - 配置管理
@interface DDRedEnvelopConfig : NSObject

@property (nonatomic, assign) BOOL autoRedEnvelop;
@property (nonatomic, assign) NSInteger redEnvelopDelay;
@property (nonatomic, strong) NSArray *redEnvelopGroupFilter;
@property (nonatomic, assign) BOOL redEnvelopCatchMe;
@property (nonatomic, assign) BOOL redEnvelopMultipleCatch;

+ (instancetype)shared;
- (void)saveConfig;

@end

#pragma mark - 红包参数模型
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

#pragma mark - 红包参数队列
@interface DDRedEnvelopParamQueue : NSObject

+ (instancetype)sharedQueue;
- (void)enqueue:(DDRedEnvelopParam *)param;
- (DDRedEnvelopParam *)dequeue;
- (BOOL)isEmpty;

@end

#pragma mark - 红包领取操作
@interface DDReceiveRedEnvelopOperation : NSOperation

@property (assign, nonatomic, getter=isExecuting) BOOL executing;
@property (assign, nonatomic, getter=isFinished) BOOL finished;
@property (strong, nonatomic) DDRedEnvelopParam *redEnvelopParam;
@property (assign, nonatomic) unsigned int delaySeconds;

- (instancetype)initWithRedEnvelopParam:(DDRedEnvelopParam *)param delay:(unsigned int)delaySeconds;

@end

#pragma mark - 红包任务管理器
@interface DDRedEnvelopTaskManager : NSObject

+ (instancetype)sharedManager;
- (void)addNormalTask:(DDReceiveRedEnvelopOperation *)task;
- (void)addSerialTask:(DDReceiveRedEnvelopOperation *)task;
- (BOOL)serialQueueIsEmpty;

@end

#pragma mark - 设置控制器
@interface DDRedEnvelopSettingController : UIViewController

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray<NSDictionary *> *dataSource;

- (instancetype)initWithStyle:(UITableViewStyle)style;

@end

#pragma mark - 实现部分
@implementation DDRedEnvelopConfig {
    NSUserDefaults *_defaults;
}

+ (instancetype)shared {
    static DDRedEnvelopConfig *config;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[DDRedEnvelopConfig alloc] init];
    });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        _defaults = [NSUserDefaults standardUserDefaults];
        [self loadConfig];
    }
    return self;
}

- (void)loadConfig {
    _autoRedEnvelop = [_defaults boolForKey:@"DD_autoRedEnvelop"];
    _redEnvelopDelay = [_defaults integerForKey:@"DD_redEnvelopDelay"];
    _redEnvelopGroupFilter = [_defaults arrayForKey:@"DD_redEnvelopGroupFilter"] ?: @[];
    _redEnvelopCatchMe = [_defaults boolForKey:@"DD_redEnvelopCatchMe"];
    _redEnvelopMultipleCatch = [_defaults boolForKey:@"DD_redEnvelopMultipleCatch"];
}

- (void)saveConfig {
    [_defaults setBool:_autoRedEnvelop forKey:@"DD_autoRedEnvelop"];
    [_defaults setInteger:_redEnvelopDelay forKey:@"DD_redEnvelopDelay"];
    [_defaults setObject:_redEnvelopGroupFilter forKey:@"DD_redEnvelopGroupFilter"];
    [_defaults setBool:_redEnvelopCatchMe forKey:@"DD_redEnvelopCatchMe"];
    [_defaults setBool:_redEnvelopMultipleCatch forKey:@"DD_redEnvelopMultipleCatch"];
    [_defaults synchronize];
}

@end

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

@implementation DDRedEnvelopParamQueue {
    NSMutableArray<DDRedEnvelopParam *> *_queue;
}

+ (instancetype)sharedQueue {
    static DDRedEnvelopParamQueue *queue;
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

- (void)enqueue:(DDRedEnvelopParam *)param {
    if (param) [_queue addObject:param];
}

- (DDRedEnvelopParam *)dequeue {
    if (_queue.count == 0) return nil;
    DDRedEnvelopParam *first = _queue.firstObject;
    [_queue removeObjectAtIndex:0];
    return first;
}

- (BOOL)isEmpty {
    return _queue.count == 0;
}

@end

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
        [self completeOperation];
        return;
    }
    
    self.executing = YES;
    [self main];
}

- (void)main {
    if (self.delaySeconds > 0) {
        [NSThread sleepForTimeInterval:self.delaySeconds / 1000.0];
    }
    
    [self openRedEnvelop];
    [self completeOperation];
}

- (void)openRedEnvelop {
    Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
    if (!logicMgrClass) return;
    
    Class mmServiceClass = objc_getClass("MMServiceCenter");
    if (!mmServiceClass) return;
    
    id mmService = [mmServiceClass defaultCenter];
    if (!mmService) return;
    
    id logicMgr = [mmService getService:logicMgrClass];
    if (!logicMgr) return;
    
    NSDictionary *params = [self.redEnvelopParam toParams];
    if ([logicMgr respondsToSelector:@selector(OpenRedEnvelopesRequest:)]) {
        [logicMgr OpenRedEnvelopesRequest:params];
    }
}

- (void)completeOperation {
    self.executing = NO;
    self.finished = YES;
}

- (void)cancel {
    [super cancel];
    [self completeOperation];
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

@implementation DDRedEnvelopTaskManager {
    NSOperationQueue *_serialQueue;
    NSOperationQueue *_normalQueue;
}

+ (instancetype)sharedManager {
    static DDRedEnvelopTaskManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[DDRedEnvelopTaskManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        _serialQueue = [[NSOperationQueue alloc] init];
        _serialQueue.maxConcurrentOperationCount = 1;
        _serialQueue.name = @"DD.RedEnvelop.SerialQueue";
        
        _normalQueue = [[NSOperationQueue alloc] init];
        _normalQueue.maxConcurrentOperationCount = 5;
        _normalQueue.name = @"DD.RedEnvelop.NormalQueue";
    }
    return self;
}

- (void)addNormalTask:(DDReceiveRedEnvelopOperation *)task {
    [_normalQueue addOperation:task];
}

- (void)addSerialTask:(DDReceiveRedEnvelopOperation *)task {
    [_serialQueue addOperation:task];
}

- (BOOL)serialQueueIsEmpty {
    return _serialQueue.operationCount == 0;
}

@end

@implementation DDRedEnvelopSettingController

- (instancetype)initWithStyle:(UITableViewStyle)style {
    self = [super init];
    if (self) {
        // 使用现代iOS模态样式
        if (@available(iOS 13.0, *)) {
            self.modalPresentationStyle = UIModalPresentationPageSheet;
        } else {
            self.modalPresentationStyle = UIModalPresentationFormSheet;
        }
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self setupDataSource];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // 刷新数据
    [self.tableView reloadData];
}

- (void)setupUI {
    self.title = @"DD红包设置";
    
    // 使用系统颜色适配
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor groupTableViewBackgroundColor];
    }
    
    // 使用现代导航栏样式
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    
    // 设置导航栏返回按钮
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                target:self
                                                                                action:@selector(dismissView)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    // 创建TableView
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.rowHeight = 60;
    [self.view addSubview:self.tableView];
}

- (void)setupDataSource {
    DDRedEnvelopConfig *config = [DDRedEnvelopConfig shared];
    self.dataSource = @[
        @{@"title": @"自动抢红包", @"type": @"switch", @"key": @"autoRedEnvelop"},
        @{@"title": @"延迟抢红包", @"type": @"input", @"key": @"redEnvelopDelay", 
          @"placeholder": @"毫秒", @"value": @(config.redEnvelopDelay)},
        @{@"title": @"群聊过滤", @"type": @"group", @"key": @"redEnvelopGroupFilter"},
        @{@"title": @"抢自己红包", @"type": @"switch", @"key": @"redEnvelopCatchMe"},
        @{@"title": @"防止同时抢多个红包", @"type": @"switch", @"key": @"redEnvelopMultipleCatch"}
    ];
}

- (void)dismissView {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.dataSource.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *item = self.dataSource[indexPath.row];
    NSString *type = item[@"type"];
    
    if ([type isEqualToString:@"switch"]) {
        return [self switchCellForItem:item];
    } else if ([type isEqualToString:@"input"]) {
        return [self inputCellForItem:item];
    } else {
        return [self normalCellForItem:item];
    }
}

- (UITableViewCell *)switchCellForItem:(NSDictionary *)item {
    static NSString *cellId = @"SwitchCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellId];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        UISwitch *switchView = [[UISwitch alloc] init];
        [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    }
    
    cell.textLabel.text = item[@"title"];
    UISwitch *switchView = (UISwitch *)cell.accessoryView;
    switchView.accessibilityIdentifier = item[@"key"];
    
    NSString *key = item[@"key"];
    DDRedEnvelopConfig *config = [DDRedEnvelopConfig shared];
    
    if ([key isEqualToString:@"autoRedEnvelop"]) {
        switchView.on = config.autoRedEnvelop;
    } else if ([key isEqualToString:@"redEnvelopCatchMe"]) {
        switchView.on = config.redEnvelopCatchMe;
    } else if ([key isEqualToString:@"redEnvelopMultipleCatch"]) {
        switchView.on = config.redEnvelopMultipleCatch;
    }
    
    return cell;
}

- (UITableViewCell *)inputCellForItem:(NSDictionary *)item {
    static NSString *cellId = @"InputCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellId];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellId];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    cell.textLabel.text = item[@"title"];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", item[@"value"]];
    return cell;
}

- (UITableViewCell *)normalCellForItem:(NSDictionary *)item {
    static NSString *cellId = @"NormalCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellId];
    
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
    
    NSDictionary *item = self.dataSource[indexPath.row];
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
    
    DDRedEnvelopConfig *config = [DDRedEnvelopConfig shared];
    
    if ([key isEqualToString:@"autoRedEnvelop"]) {
        config.autoRedEnvelop = value;
    } else if ([key isEqualToString:@"redEnvelopCatchMe"]) {
        config.redEnvelopCatchMe = value;
    } else if ([key isEqualToString:@"redEnvelopMultipleCatch"]) {
        config.redEnvelopMultipleCatch = value;
    }
    
    [config saveConfig];
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
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textField = alert.textFields.firstObject;
        NSInteger delay = [textField.text integerValue];
        [DDRedEnvelopConfig shared].redEnvelopDelay = MAX(0, delay);
        [[DDRedEnvelopConfig shared] saveConfig];
        [self.tableView reloadData];
    }];
    
    [alert addAction:cancel];
    [alert addAction:confirm];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showGroupFilterAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"群聊过滤"
                                                                   message:@"输入要过滤的群聊ID，多个用逗号分隔"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        NSArray *groups = [DDRedEnvelopConfig shared].redEnvelopGroupFilter;
        textField.placeholder = @"例如：xxxx@chatroom,yyyy@chatroom";
        textField.text = groups.count > 0 ? [groups componentsJoinedByString:@","] : @"";
    }];
    
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *confirm = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *text = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSArray *groups = text.length > 0 ? [text componentsSeparatedByString:@","] : @[];
        [DDRedEnvelopConfig shared].redEnvelopGroupFilter = groups;
        [[DDRedEnvelopConfig shared] saveConfig];
    }];
    
    [alert addAction:cancel];
    [alert addAction:confirm];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - Logos Hook部分

// Hook CMessageMgr
%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(id)wrap {
    %orig;
    
    DDRedEnvelopConfig *config = [DDRedEnvelopConfig shared];
    if (!config.autoRedEnvelop) return;
    
    NSInteger m_uiMessageType = [[wrap valueForKey:@"m_uiMessageType"] integerValue];
    if (m_uiMessageType != 49) return;
    
    NSString *content = [wrap valueForKey:@"m_nsContent"];
    if (![content containsString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"]) return;
    
    NSString *fromUsr = [wrap valueForKey:@"m_nsFromUsr"];
    NSString *toUsr = [wrap valueForKey:@"m_nsToUsr"];
    
    if ([config.redEnvelopGroupFilter containsObject:fromUsr]) return;
    
    Class contactMgrClass = objc_getClass("CContactMgr");
    Class mmServiceClass = objc_getClass("MMServiceCenter");
    id mmService = [mmServiceClass defaultCenter];
    if (!mmService) return;
    
    id contactMgr = [mmService getService:contactMgrClass];
    if (!contactMgr) return;
    
    id selfContact = [contactMgr getSelfContact];
    if (!selfContact) return;
    
    NSString *selfUsrName = [selfContact valueForKey:@"m_nsUsrName"];
    
    BOOL isSender = [fromUsr isEqualToString:selfUsrName];
    BOOL isGroupSender = isSender && [toUsr containsString:@"chatroom"];
    BOOL isGroupReceiver = [fromUsr containsString:@"chatroom"];
    
    if (isGroupSender && !config.redEnvelopCatchMe) return;
    
    BOOL shouldReceive = isGroupReceiver || (isGroupSender && config.redEnvelopCatchMe);
    if (!shouldReceive) return;
    
    id m_oWCPayInfoItem = [wrap valueForKey:@"m_oWCPayInfoItem"];
    if (!m_oWCPayInfoItem) return;
    
    NSString *nativeUrl = [[m_oWCPayInfoItem valueForKey:@"m_c2cNativeUrl"] stringByRemovingPercentEncoding];
    if (!nativeUrl) return;
    
    NSRange range = [nativeUrl rangeOfString:@"?"];
    if (range.location == NSNotFound) return;
    
    NSString *paramString = [nativeUrl substringFromIndex:range.location + 1];
    NSArray *components = [paramString componentsSeparatedByString:@"&"];
    
    NSMutableDictionary *paramDict = [NSMutableDictionary dictionary];
    for (NSString *component in components) {
        NSArray *keyValue = [component componentsSeparatedByString:@"="];
        if (keyValue.count == 2) {
            paramDict[keyValue[0]] = keyValue[1];
        }
    }
    
    DDRedEnvelopParam *envelopParam = [[DDRedEnvelopParam alloc] init];
    envelopParam.msgType = paramDict[@"msgtype"];
    envelopParam.sendId = paramDict[@"sendid"];
    envelopParam.channelId = paramDict[@"channelid"];
    envelopParam.nativeUrl = nativeUrl;
    envelopParam.sessionUserName = isGroupSender ? toUsr : fromUsr;
    envelopParam.sign = paramDict[@"sign"];
    envelopParam.isGroupSender = isGroupSender;
    envelopParam.nickName = [selfContact valueForKey:@"m_nsNickName"] ?: @"";
    envelopParam.headImg = [selfContact valueForKey:@"m_nsHeadImgUrl"] ?: @"";
    
    NSDictionary *queryParams = @{
        @"agreeDuty": @"0",
        @"channelId": envelopParam.channelId ?: @"",
        @"inWay": @"0",
        @"msgType": envelopParam.msgType ?: @"",
        @"nativeUrl": envelopParam.nativeUrl ?: @"",
        @"sendId": envelopParam.sendId ?: @""
    };
    
    Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
    id logicMgr = [mmService getService:logicMgrClass];
    if (logicMgr && [logicMgr respondsToSelector:@selector(ReceiverQueryRedEnvelopesRequest:)]) {
        [logicMgr ReceiverQueryRedEnvelopesRequest:queryParams];
    }
    
    [[DDRedEnvelopParamQueue sharedQueue] enqueue:envelopParam];
}

%end

// Hook WCRedEnvelopesLogicMgr
%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig(arg1, arg2);
    
    NSInteger cgiCmdid = [[arg1 valueForKey:@"cgiCmdid"] integerValue];
    if (cgiCmdid != 3) return;
    
    DDRedEnvelopConfig *config = [DDRedEnvelopConfig shared];
    if (!config.autoRedEnvelop) return;
    
    NSData *retData = [[arg1 valueForKey:@"retText"] valueForKey:@"buffer"];
    if (!retData) return;
    
    NSString *retString = [[NSString alloc] initWithData:retData encoding:NSUTF8StringEncoding];
    if (!retString) return;
    
    NSError *error;
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:[retString dataUsingEncoding:NSUTF8StringEncoding] 
                                                               options:0 
                                                                 error:&error];
    if (error || !responseDict) return;
    
    NSInteger receiveStatus = [responseDict[@"receiveStatus"] integerValue];
    NSInteger hbStatus = [responseDict[@"hbStatus"] integerValue];
    NSString *timingIdentifier = responseDict[@"timingIdentifier"];
    
    if (receiveStatus == 2) return;
    if (hbStatus == 4) return;
    if (!timingIdentifier) return;
    
    DDRedEnvelopParam *envelopParam = [[DDRedEnvelopParamQueue sharedQueue] dequeue];
    if (!envelopParam) return;
    
    if (!envelopParam.isGroupSender) {
        NSData *reqData = [[arg2 valueForKey:@"reqText"] valueForKey:@"buffer"];
        if (reqData) {
            NSString *reqString = [[NSString alloc] initWithData:reqData encoding:NSUTF8StringEncoding];
            NSArray *components = [reqString componentsSeparatedByString:@"&"];
            
            NSString *sign = nil;
            for (NSString *component in components) {
                if ([component hasPrefix:@"nativeUrl="]) {
                    NSString *encodedUrl = [component substringFromIndex:10];
                    NSString *nativeUrl = [encodedUrl stringByRemovingPercentEncoding];
                    NSRange signRange = [nativeUrl rangeOfString:@"sign="];
                    if (signRange.location != NSNotFound) {
                        sign = [nativeUrl substringFromIndex:signRange.location + 5];
                        break;
                    }
                }
            }
            
            if (sign && ![sign isEqualToString:envelopParam.sign]) {
                return;
            }
        }
    }
    
    envelopParam.timingIdentifier = timingIdentifier;
    
    unsigned int delaySeconds = 0;
    if (config.redEnvelopDelay > 0) {
        if (config.redEnvelopMultipleCatch && ![[DDRedEnvelopTaskManager sharedManager] serialQueueIsEmpty]) {
            delaySeconds = 15000;
        } else {
            delaySeconds = (unsigned int)config.redEnvelopDelay;
        }
    }
    
    DDReceiveRedEnvelopOperation *operation = [[DDReceiveRedEnvelopOperation alloc] 
        initWithRedEnvelopParam:envelopParam 
                         delay:delaySeconds];
    
    if (config.redEnvelopMultipleCatch) {
        [[DDRedEnvelopTaskManager sharedManager] addSerialTask:operation];
    } else {
        [[DDRedEnvelopTaskManager sharedManager] addNormalTask:operation];
    }
}

%end

#pragma mark - 插件入口和设置页面控制器

// 插件设置页面控制器 - 用于包装DDRedEnvelopSettingController
@interface DDPluginSettingsController : UINavigationController
@end

@implementation DDPluginSettingsController

- (instancetype)init {
    DDRedEnvelopSettingController *settingsVC = [[DDRedEnvelopSettingController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    self = [super initWithRootViewController:settingsVC];
    if (self) {
        // 设置现代导航样式
        if (@available(iOS 13.0, *)) {
            self.modalPresentationStyle = UIModalPresentationPageSheet;
        } else {
            self.modalPresentationStyle = UIModalPresentationFormSheet;
        }
    }
    return self;
}

@end

#pragma mark - 构造函数
%ctor {
    @autoreleasepool {
        // 预加载配置
        [DDRedEnvelopConfig shared];
        
        // 延迟注册插件入口
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 使用总开关作为插件入口
            if (NSClassFromString(@"WCPluginsMgr")) {
                // 只注册一个总开关
                [[objc_getClass("WCPluginsMgr") sharedInstance] registerSwitchWithTitle:@"DD红包" key:@"DD_autoRedEnvelop"];
                
                // 同时注册设置页面控制器，这样用户可以从插件管理界面进入详细设置
                [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD红包设置" 
                                                                                   version:@"1.0.0" 
                                                                                controller:@"DDPluginSettingsController"];
            }
        });
    }
}

// 插件版本信息
__attribute__((visibility("default"))) NSString *DDRedEnvelopVersion = @"1.0.0";