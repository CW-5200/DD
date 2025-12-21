// DDHongbao.xm
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// MARK: - 插件配置类
@interface DDHongbaoConfig : NSObject
@property (nonatomic, assign) BOOL autoGrabEnabled;           // 自动抢红包
@property (nonatomic, assign) NSInteger delayTime;           // 延迟时间(毫秒)
@property (nonatomic, assign) BOOL grabSelfEnabled;          // 抢自己红包
@property (nonatomic, assign) BOOL preventMultiple;          // 防止同时抢多个
@property (nonatomic, copy) NSArray *blackListGroups;        // 群聊过滤黑名单

+ (instancetype)sharedConfig;
- (void)saveConfig;
@end

@implementation DDHongbaoConfig

+ (instancetype)sharedConfig {
    static DDHongbaoConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DDHongbaoConfig alloc] init];
        [instance loadConfig];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _autoGrabEnabled = YES;
        _delayTime = 0;
        _grabSelfEnabled = NO;
        _preventMultiple = YES;
        _blackListGroups = @[];
    }
    return self;
}

- (void)loadConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _autoGrabEnabled = [defaults boolForKey:@"DDHongbaoAutoGrab"];
    _delayTime = [defaults integerForKey:@"DDHongbaoDelay"];
    _grabSelfEnabled = [defaults boolForKey:@"DDHongbaoGrabSelf"];
    _preventMultiple = [defaults boolForKey:@"DDHongbaoPreventMultiple"];
    _blackListGroups = [defaults arrayForKey:@"DDHongbaoBlackList"] ?: @[];
}

- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:_autoGrabEnabled forKey:@"DDHongbaoAutoGrab"];
    [defaults setInteger:_delayTime forKey:@"DDHongbaoDelay"];
    [defaults setBool:_grabSelfEnabled forKey:@"DDHongbaoGrabSelf"];
    [defaults setBool:_preventMultiple forKey:@"DDHongbaoPreventMultiple"];
    [defaults setObject:_blackListGroups forKey:@"DDHongbaoBlackList"];
    [defaults synchronize];
}

@end

// MARK: - 红包参数队列
@interface DDEnvelopParam : NSObject
@property (nonatomic, copy) NSString *msgType;
@property (nonatomic, copy) NSString *sendId;
@property (nonatomic, copy) NSString *channelId;
@property (nonatomic, copy) NSString *nativeUrl;
@property (nonatomic, copy) NSString *sessionUserName;
@property (nonatomic, copy) NSString *sign;
@property (nonatomic, assign) BOOL isGroupSender;
@property (nonatomic, copy) NSString *timingIdentifier;
@end

@implementation DDEnvelopParam
@end

@interface DDEnvelopQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(DDEnvelopParam *)param;
- (DDEnvelopParam *)dequeue;
- (BOOL)isEmpty;
@end

@implementation DDEnvelopQueue {
    NSMutableArray *_queue;
}

+ (instancetype)sharedQueue {
    static DDEnvelopQueue *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DDEnvelopQueue alloc] init];
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

- (void)enqueue:(DDEnvelopParam *)param {
    @synchronized(self) {
        [_queue addObject:param];
    }
}

- (DDEnvelopParam *)dequeue {
    @synchronized(self) {
        if (_queue.count == 0) return nil;
        DDEnvelopParam *param = _queue.firstObject;
        [_queue removeObjectAtIndex:0];
        return param;
    }
}

- (BOOL)isEmpty {
    @synchronized(self) {
        return _queue.count == 0;
    }
}

@end

// MARK: - 红包任务管理器
@interface DDHongbaoTaskManager : NSObject
@property (nonatomic, assign) BOOL isExecuting;
+ (instancetype)sharedManager;
- (void)addTask:(DDEnvelopParam *)param delay:(NSUInteger)delay;
@end

@implementation DDHongbaoTaskManager {
    dispatch_queue_t _taskQueue;
}

+ (instancetype)sharedManager {
    static DDHongbaoTaskManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DDHongbaoTaskManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _taskQueue = dispatch_queue_create("com.dd.hongbao.queue", DISPATCH_QUEUE_SERIAL);
        _isExecuting = NO;
    }
    return self;
}

- (void)addTask:(DDEnvelopParam *)param delay:(NSUInteger)delay {
    if (![DDHongbaoConfig sharedConfig].autoGrabEnabled) return;
    
    if ([DDHongbaoConfig sharedConfig].preventMultiple && _isExecuting) {
        // 如果正在执行且开启了防止同时抢，则等待
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), _taskQueue, ^{
            [self addTask:param delay:delay];
        });
        return;
    }
    
    _isExecuting = YES;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_MSEC)), _taskQueue, ^{
        [self executeTask:param];
    });
}

- (void)executeTask:(DDEnvelopParam *)param {
    // 调用微信的拆红包接口
    Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
    id logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:logicMgrClass];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"agreeDuty"] = @"0";
    params[@"channelId"] = param.channelId;
    params[@"inWay"] = @"0";
    params[@"msgType"] = param.msgType;
    params[@"nativeUrl"] = param.nativeUrl;
    params[@"sendId"] = param.sendId;
    
    if (param.timingIdentifier) {
        params[@"timingIdentifier"] = param.timingIdentifier;
    }
    
    SEL selector = NSSelectorFromString(@"OpenRedEnvelopesRequest:");
    if ([logicMgr respondsToSelector:selector]) {
        [logicMgr performSelector:selector withObject:params];
    }
    
    _isExecuting = NO;
}

@end

// MARK: - Hook CMessageMgr
%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(id)wrap {
    %orig;
    
    DDHongbaoConfig *config = [DDHongbaoConfig sharedConfig];
    if (!config.autoGrabEnabled) return;
    
    // 检查是否为红包消息
    if ([wrap isKindOfClass:objc_getClass("CMessageWrap")]) {
        unsigned int msgType = [(CMessageWrap *)wrap m_uiMessageType];
        if (msgType == 49) { // 红包消息类型
            NSString *content = [wrap m_nsContent];
            if ([content containsString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao"]) {
                [self handleHongbaoMessage:wrap];
            }
        }
    }
}

- (void)handleHongbaoMessage:(id)wrap {
    DDHongbaoConfig *config = [DDHongbaoConfig sharedConfig];
    
    // 获取群聊ID
    NSString *fromUsr = [wrap m_nsFromUsr];
    BOOL isGroupMessage = [fromUsr containsString:@"@chatroom"];
    
    // 群聊过滤检查
    if (isGroupMessage && [config.blackListGroups containsObject:fromUsr]) {
        return;
    }
    
    // 获取自己信息
    Class contactMgrClass = objc_getClass("CContactMgr");
    id contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:contactMgrClass];
    id selfContact = [contactMgr getSelfContact];
    NSString *selfUsrName = [selfContact m_nsUsrName];
    
    // 是否为自己发的红包
    BOOL isSelfSender = [[wrap m_nsFromUsr] isEqualToString:selfUsrName];
    
    // 检查是否抢自己红包
    if (isSelfSender && !config.grabSelfEnabled) {
        return;
    }
    
    // 解析红包参数
    id payInfoItem = [wrap m_oWCPayInfoItem];
    NSString *nativeUrl = [payInfoItem m_c2cNativeUrl];
    
    if (nativeUrl) {
        NSString *queryString = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
        
        // 解析参数
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        NSArray *components = [queryString componentsSeparatedByString:@"&"];
        for (NSString *component in components) {
            NSArray *keyValue = [component componentsSeparatedByString:@"="];
            if (keyValue.count == 2) {
                params[keyValue[0]] = keyValue[1];
            }
        }
        
        // 创建红包参数
        DDEnvelopParam *param = [[DDEnvelopParam alloc] init];
        param.msgType = params[@"msgtype"];
        param.sendId = params[@"sendid"];
        param.channelId = params[@"channelid"];
        param.nativeUrl = nativeUrl;
        param.sessionUserName = isSelfSender ? [wrap m_nsToUsr] : [wrap m_nsFromUsr];
        param.sign = params[@"sign"];
        param.isGroupSender = isSelfSender;
        
        // 先查询红包信息
        [self queryHongbaoInfo:param];
    }
}

- (void)queryHongbaoInfo:(DDEnvelopParam *)param {
    Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
    id logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:logicMgrClass];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"agreeDuty"] = @"0";
    params[@"channelId"] = param.channelId;
    params[@"inWay"] = @"0";
    params[@"msgType"] = param.msgType;
    params[@"nativeUrl"] = param.nativeUrl;
    params[@"sendId"] = param.sendId;
    
    SEL selector = NSSelectorFromString(@"ReceiverQueryRedEnvelopesRequest:");
    if ([logicMgr respondsToSelector:selector]) {
        [logicMgr performSelector:selector withObject:params];
    }
    
    // 加入队列等待查询结果
    [[DDEnvelopQueue sharedQueue] enqueue:param];
}

%end

// MARK: - Hook WCRedEnvelopesLogicMgr
%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig;
    
    // 解析响应数据
    Class skBuiltinBufferClass = objc_getClass("SKBuiltinBuffer_t");
    if ([arg1 isKindOfClass:objc_getClass("HongBaoRes")]) {
        int cmdId = [(HongBaoRes *)arg1 cgiCmdid];
        
        if (cmdId == 3) { // 红包查询响应
            SKBuiltinBuffer_t *retText = [arg1 retText];
            NSData *responseData = [retText buffer];
            NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            
            NSDictionary *responseDict = [responseString JSONDictionary];
            if (responseDict) {
                // 检查是否可以抢红包
                NSInteger receiveStatus = [responseDict[@"receiveStatus"] integerValue];
                NSInteger hbStatus = [responseDict[@"hbStatus"] integerValue];
                NSString *timingIdentifier = responseDict[@"timingIdentifier"];
                
                if (receiveStatus != 2 && hbStatus != 4 && timingIdentifier) {
                    DDEnvelopParam *param = [[DDEnvelopQueue sharedQueue] dequeue];
                    if (param) {
                        param.timingIdentifier = timingIdentifier;
                        
                        // 计算延迟时间
                        NSUInteger delay = [DDHongbaoConfig sharedConfig].delayTime;
                        [[DDHongbaoTaskManager sharedManager] addTask:param delay:delay];
                    }
                }
            }
        }
    }
}

%new
- (NSUInteger)calculateDelaySeconds {
    return [DDHongbaoConfig sharedConfig].delayTime;
}

%end

// MARK: - 设置界面控制器
@interface DDHongbaoSettingController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
    UITableView *_tableView;
    NSArray *_sectionTitles;
    NSArray *_sectionData;
}

@end

@implementation DDHongbaoSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD红包设置";
    self.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.96 alpha:1.0];
    
    // 设置导航栏
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" 
                                                                            style:UIBarButtonItemStylePlain 
                                                                           target:self 
                                                                           action:@selector(close)];
    
    // 创建表格
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_tableView];
    
    // 数据源
    _sectionTitles = @[@"基本设置", @"高级设置", @"群聊过滤"];
    [self updateSectionData];
}

- (void)updateSectionData {
    DDHongbaoConfig *config = [DDHongbaoConfig sharedConfig];
    
    _sectionData = @[
        @[
            @{@"type": @"switch", @"title": @"自动抢红包", @"key": @"autoGrab"},
            config.autoGrabEnabled ? @{@"type": @"switch", @"title": @"抢自己红包", @"key": @"grabSelf"} : nil,
            config.autoGrabEnabled ? @{@"type": @"switch", @"title": @"防止同时抢多个", @"key": @"preventMultiple"} : nil,
        ].mutableCopy,
        @[
            config.autoGrabEnabled ? @{@"type": @"input", @"title": @"延迟时间(毫秒)", @"key": @"delay", @"value": @(config.delayTime).stringValue} : nil,
        ].mutableCopy,
        @[
            @{@"type": @"button", @"title": @"管理过滤群聊", @"key": @"manageBlacklist"},
            config.blackListGroups.count > 0 ? 
            @{@"type": @"label", @"title": @"已过滤群聊", @"value": [NSString stringWithFormat:@"%ld个", (long)config.blackListGroups.count]} : 
            @{@"type": @"label", @"title": @"已过滤群聊", @"value": @"未设置"}
        ]
    ];
    
    // 过滤nil值
    NSMutableArray *filteredSections = [NSMutableArray array];
    for (NSArray *section in _sectionData) {
        NSMutableArray *filteredRows = [NSMutableArray array];
        for (id row in section) {
            if (row != nil) {
                [filteredRows addObject:row];
            }
        }
        [filteredSections addObject:filteredRows];
    }
    _sectionData = filteredSections;
    
    [_tableView reloadData];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableView DataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _sectionData.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_sectionData[section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _sectionTitles[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }
    
    NSDictionary *rowData = _sectionData[indexPath.section][indexPath.row];
    NSString *type = rowData[@"type"];
    NSString *title = rowData[@"title"];
    
    cell.textLabel.text = title;
    cell.detailTextLabel.text = nil;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    if ([type isEqualToString:@"switch"]) {
        UISwitch *switchView = [[UISwitch alloc] init];
        NSString *key = rowData[@"key"];
        
        if ([key isEqualToString:@"autoGrab"]) {
            switchView.on = [DDHongbaoConfig sharedConfig].autoGrabEnabled;
            [switchView addTarget:self action:@selector(autoGrabSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        } else if ([key isEqualToString:@"grabSelf"]) {
            switchView.on = [DDHongbaoConfig sharedConfig].grabSelfEnabled;
            [switchView addTarget:self action:@selector(grabSelfSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        } else if ([key isEqualToString:@"preventMultiple"]) {
            switchView.on = [DDHongbaoConfig sharedConfig].preventMultiple;
            [switchView addTarget:self action:@selector(preventMultipleSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        }
        
        cell.accessoryView = switchView;
    } else if ([type isEqualToString:@"input"]) {
        cell.detailTextLabel.text = rowData[@"value"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if ([type isEqualToString:@"button"]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if ([type isEqualToString:@"label"]) {
        cell.detailTextLabel.text = rowData[@"value"];
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *rowData = _sectionData[indexPath.section][indexPath.row];
    NSString *key = rowData[@"key"];
    
    if ([key isEqualToString:@"delay"]) {
        [self showDelayInput];
    } else if ([key isEqualToString:@"manageBlacklist"]) {
        [self showBlacklistManager];
    }
}

#pragma mark - Switch Handlers

- (void)autoGrabSwitchChanged:(UISwitch *)sender {
    [DDHongbaoConfig sharedConfig].autoGrabEnabled = sender.isOn;
    [[DDHongbaoConfig sharedConfig] saveConfig];
    [self updateSectionData];
}

- (void)grabSelfSwitchChanged:(UISwitch *)sender {
    [DDHongbaoConfig sharedConfig].grabSelfEnabled = sender.isOn;
    [[DDHongbaoConfig sharedConfig] saveConfig];
}

- (void)preventMultipleSwitchChanged:(UISwitch *)sender {
    [DDHongbaoConfig sharedConfig].preventMultiple = sender.isOn;
    [[DDHongbaoConfig sharedConfig] saveConfig];
}

#pragma mark - Input Handlers

- (void)showDelayInput {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"延迟时间"
                                                                   message:@"输入延迟时间(毫秒)" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"毫秒";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = @([DDHongbaoConfig sharedConfig].delayTime).stringValue;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        NSInteger delay = [text integerValue];
        [DDHongbaoConfig sharedConfig].delayTime = delay;
        [[DDHongbaoConfig sharedConfig] saveConfig];
        [self updateSectionData];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showBlacklistManager {
    // 这里应该实现群聊选择界面
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示"
                                                                   message:@"群聊过滤功能需选择群聊，这里需要实现群聊选择界面"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

// MARK: - 插件注册
__attribute__((constructor)) static void entry() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (NSClassFromString(@"WCPluginsMgr")) {
            // 注册带设置页面的插件
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD红包" 
                                   version:@"1.0" 
                               controller:@"DDHongbaoSettingController"];
        }
    });
}