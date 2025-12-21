#import <UIKit/UIKit.h>
#import <CaptainHook/CaptainHook.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

#pragma mark - 常量定义

#define kDDHongBaoVersion @"1.0.0"
#define kDDHongBaoTitle @"DD红包"

#pragma mark - 配置管理类

@interface DDHongBaoConfig : NSObject

@property (nonatomic, assign) BOOL autoGrab;                    // 自动抢红包
@property (nonatomic, assign) NSInteger delayTime;              // 延迟时间（毫秒）
@property (nonatomic, strong) NSArray *filterGroups;            // 群聊过滤
@property (nonatomic, assign) BOOL grabSelf;                    // 抢自己红包
@property (nonatomic, assign) BOOL preventMultiple;             // 防止同时抢多个红包

+ (instancetype)sharedConfig;
- (void)saveConfig;

@end

@implementation DDHongBaoConfig

+ (instancetype)sharedConfig {
    static DDHongBaoConfig *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DDHongBaoConfig alloc] init];
        [sharedInstance loadConfig];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _autoGrab = YES;
        _delayTime = 0;
        _filterGroups = @[];
        _grabSelf = NO;
        _preventMultiple = YES;
    }
    return self;
}

- (void)loadConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _autoGrab = [defaults boolForKey:@"DDHongBao_autoGrab"];
    _delayTime = [defaults integerForKey:@"DDHongBao_delayTime"];
    _filterGroups = [defaults arrayForKey:@"DDHongBao_filterGroups"] ?: @[];
    _grabSelf = [defaults boolForKey:@"DDHongBao_grabSelf"];
    _preventMultiple = [defaults boolForKey:@"DDHongBao_preventMultiple"];
}

- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:_autoGrab forKey:@"DDHongBao_autoGrab"];
    [defaults setInteger:_delayTime forKey:@"DDHongBao_delayTime"];
    [defaults setObject:_filterGroups forKey:@"DDHongBao_filterGroups"];
    [defaults setBool:_grabSelf forKey:@"DDHongBao_grabSelf"];
    [defaults setBool:_preventMultiple forKey:@"DDHongBao_preventMultiple"];
    [defaults synchronize];
}

@end

#pragma mark - 红包参数队列

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

@interface DDRedEnvelopParamQueue : NSObject

+ (instancetype)sharedQueue;
- (void)enqueue:(DDRedEnvelopParam *)param;
- (DDRedEnvelopParam *)dequeue;
- (void)clear;

@end

@implementation DDRedEnvelopParamQueue {
    NSMutableArray *_queue;
    NSLock *_lock;
}

+ (instancetype)sharedQueue {
    static DDRedEnvelopParamQueue *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DDRedEnvelopParamQueue alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = [NSMutableArray array];
        _lock = [[NSLock alloc] init];
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

- (void)clear {
    [_lock lock];
    [_queue removeAllObjects];
    [_lock unlock];
}

@end

#pragma mark - 红包任务管理器

@interface DDReceiveRedEnvelopOperation : NSOperation

@property (nonatomic, strong) DDRedEnvelopParam *param;
@property (nonatomic, assign) unsigned int delay;

- (instancetype)initWithRedEnvelopParam:(DDRedEnvelopParam *)param delay:(unsigned int)delay;

@end

@implementation DDReceiveRedEnvelopOperation {
    BOOL _isFinished;
    BOOL _isExecuting;
}

- (instancetype)initWithRedEnvelopParam:(DDRedEnvelopParam *)param delay:(unsigned int)delay {
    self = [super init];
    if (self) {
        _param = param;
        _delay = delay;
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
    
    [self main];
}

- (void)main {
    if (self.isCancelled) {
        [self completeOperation];
        return;
    }
    
    if (_delay > 0) {
        [NSThread sleepForTimeInterval:_delay / 1000.0];
    }
    
    if (self.isCancelled) {
        [self completeOperation];
        return;
    }
    
    [self openRedEnvelop];
}

- (void)openRedEnvelop {
    Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
    if (!logicMgrClass) {
        [self completeOperation];
        return;
    }
    
    NSMutableDictionary *params = [@{} mutableCopy];
    params[@"agreeDuty"] = @"0";
    params[@"channelId"] = _param.channelId;
    params[@"inWay"] = @"0";
    params[@"msgType"] = _param.msgType;
    params[@"nativeUrl"] = _param.nativeUrl;
    params[@"sendId"] = _param.sendId;
    params[@"timingIdentifier"] = _param.timingIdentifier;
    params[@"sessionUserName"] = _param.sessionUserName;
    params[@"headImg"] = _param.headImg;
    params[@"nickName"] = _param.nickName;
    
    WCRedEnvelopesLogicMgr *logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:logicMgrClass];
    [logicMgr OpenRedEnvelopesRequest:params];
    
    [self completeOperation];
}

- (void)completeOperation {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    _isExecuting = NO;
    _isFinished = YES;
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

- (BOOL)isAsynchronous {
    return YES;
}

- (BOOL)isExecuting {
    return _isExecuting;
}

- (BOOL)isFinished {
    return _isFinished;
}

@end

@interface DDRedEnvelopTaskManager : NSObject

@property (nonatomic, assign) BOOL serialQueueIsEmpty;

+ (instancetype)sharedManager;
- (void)addNormalTask:(DDReceiveRedEnvelopOperation *)operation;
- (void)addSerialTask:(DDReceiveRedEnvelopOperation *)operation;

@end

@implementation DDRedEnvelopTaskManager {
    NSOperationQueue *_normalQueue;
    NSOperationQueue *_serialQueue;
}

+ (instancetype)sharedManager {
    static DDRedEnvelopTaskManager *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DDRedEnvelopTaskManager alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _normalQueue = [[NSOperationQueue alloc] init];
        _normalQueue.maxConcurrentOperationCount = 1;
        
        _serialQueue = [[NSOperationQueue alloc] init];
        _serialQueue.maxConcurrentOperationCount = 1;
        
        _serialQueueIsEmpty = YES;
        
        [self addObservers];
    }
    return self;
}

- (void)addObservers {
    [_serialQueue addObserver:self forKeyPath:@"operationCount" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == _serialQueue && [keyPath isEqualToString:@"operationCount"]) {
        self.serialQueueIsEmpty = _serialQueue.operationCount == 0;
    }
}

- (void)addNormalTask:(DDReceiveRedEnvelopOperation *)operation {
    [_normalQueue addOperation:operation];
}

- (void)addSerialTask:(DDReceiveRedEnvelopOperation *)operation {
    [_serialQueue addOperation:operation];
}

- (void)dealloc {
    [_serialQueue removeObserver:self forKeyPath:@"operationCount"];
}

@end

#pragma mark - 设置页面

@interface DDHongBaoSettingController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
    UITableView *_tableView;
}

@end

@implementation DDHongBaoSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = kDDHongBaoTitle;
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 创建返回按钮
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"返回" 
                                                                             style:UIBarButtonItemStylePlain 
                                                                            target:self 
                                                                            action:@selector(backAction)];
    
    // 创建表格视图
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tableView];
    
    // 注册cell
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
}

- (void)backAction {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1; // 基本功能
        case 1: return 3; // 高级设置
        case 2: return 2; // 过滤设置
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"基本功能";
        case 1: return @"高级设置";
        case 2: return @"过滤设置";
        default: return @"";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
    
    switch (indexPath.section) {
        case 0: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"自动抢红包";
                UISwitch *switchView = [[UISwitch alloc] init];
                switchView.on = config.autoGrab;
                [switchView addTarget:self action:@selector(autoGrabSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = switchView;
            }
            break;
        }
        case 1: {
            switch (indexPath.row) {
                case 0: {
                    cell.textLabel.text = @"延迟抢红包";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld毫秒", (long)config.delayTime];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    break;
                }
                case 1: {
                    cell.textLabel.text = @"抢自己红包";
                    UISwitch *switchView = [[UISwitch alloc] init];
                    switchView.on = config.grabSelf;
                    [switchView addTarget:self action:@selector(grabSelfSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                    cell.accessoryView = switchView;
                    break;
                }
                case 2: {
                    cell.textLabel.text = @"防止同时抢多个红包";
                    UISwitch *switchView = [[UISwitch alloc] init];
                    switchView.on = config.preventMultiple;
                    [switchView addTarget:self action:@selector(preventMultipleSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                    cell.accessoryView = switchView;
                    break;
                }
            }
            break;
        }
        case 2: {
            switch (indexPath.row) {
                case 0: {
                    cell.textLabel.text = @"群聊过滤";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"已过滤%lu个群", (unsigned long)config.filterGroups.count];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    break;
                }
                case 1: {
                    cell.textLabel.text = @"清空过滤列表";
                    cell.textLabel.textColor = [UIColor systemRedColor];
                    cell.accessoryType = UITableViewCellAccessoryNone;
                    break;
                }
            }
            break;
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
    
    switch (indexPath.section) {
        case 1: {
            if (indexPath.row == 0) {
                // 延迟设置
                [self showDelaySetting];
            }
            break;
        }
        case 2: {
            if (indexPath.row == 0) {
                // 群聊过滤
                [self showGroupFilter];
            } else if (indexPath.row == 1) {
                // 清空过滤列表
                [self clearFilterGroups];
            }
            break;
        }
    }
}

#pragma mark - 开关事件处理

- (void)autoGrabSwitchChanged:(UISwitch *)sender {
    DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
    config.autoGrab = sender.isOn;
    [config saveConfig];
}

- (void)grabSelfSwitchChanged:(UISwitch *)sender {
    DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
    config.grabSelf = sender.isOn;
    [config saveConfig];
}

- (void)preventMultipleSwitchChanged:(UISwitch *)sender {
    DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
    config.preventMultiple = sender.isOn;
    [config saveConfig];
}

#pragma mark - 设置方法

- (void)showDelaySetting {
    DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"延迟设置" 
                                                                   message:@"输入延迟时间（毫秒，1000毫秒=1秒）" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"请输入延迟时间";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%ld", (long)config.delayTime];
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textField = alert.textFields.firstObject;
        NSInteger delay = [textField.text integerValue];
        if (delay >= 0) {
            config.delayTime = delay;
            [config saveConfig];
            [_tableView reloadData];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showGroupFilter {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"群聊过滤" 
                                                                   message:@"请输入要过滤的群聊ID（多个用逗号分隔）" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"例如：group1,group2,group3";
        DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
        textField.text = [config.filterGroups componentsJoinedByString:@","];
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *input = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (input.length > 0) {
            NSArray *groups = [input componentsSeparatedByString:@","];
            NSMutableArray *filteredGroups = [NSMutableArray array];
            for (NSString *group in groups) {
                NSString *trimmedGroup = [group stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if (trimmedGroup.length > 0) {
                    [filteredGroups addObject:trimmedGroup];
                }
            }
            DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
            config.filterGroups = [filteredGroups copy];
            [config saveConfig];
            [_tableView reloadData];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)clearFilterGroups {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认清空" 
                                                                   message:@"确定要清空所有过滤的群聊吗？" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
        config.filterGroups = @[];
        [config saveConfig];
        [_tableView reloadData];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - Hook实现

CHDeclareClass(CMessageMgr);
CHDeclareClass(WCRedEnvelopesLogicMgr);

#pragma mark - CMessageMgr Hook

CHMethod2(void, CMessageMgr, AsyncOnAddMsg, NSString *, msg, MsgWrap, CMessageWrap *, wrap) {
    CHSuper2(CMessageMgr, AsyncOnAddMsg, msg, MsgWrap, wrap);
    
    DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
    
    // 检查是否是红包消息
    if (wrap.m_uiMessageType == 49 && [wrap.m_nsContent containsString:@"wxpay://"]) {
        if (!config.autoGrab) {
            return;
        }
        
        // 获取自己的联系信息
        CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
        CContact *selfContact = [contactMgr getSelfContact];
        
        // 检查是否发送者是自己
        BOOL isSender = [wrap.m_nsFromUsr isEqualToString:selfContact.m_nsUsrName];
        
        // 检查是否是群聊消息
        BOOL isGroupReceiver = [wrap.m_nsFromUsr containsString:@"@chatroom"];
        BOOL isGroupSender = isSender && [wrap.m_nsToUsr containsString:@"chatroom"];
        
        // 检查是否在黑名单中
        BOOL isGroupInBlackList = [config.filterGroups containsObject:wrap.m_nsFromUsr];
        
        // 判断是否应该抢红包
        BOOL shouldGrab = NO;
        if (isGroupReceiver && !isGroupInBlackList) {
            shouldGrab = YES;
        } else if (isGroupSender && config.grabSelf) {
            shouldGrab = YES;
        }
        
        if (shouldGrab) {
            // 解析红包URL
            NSString *nativeUrl = [[wrap m_oWCPayInfoItem] m_c2cNativeUrl];
            NSString *queryString = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
            
            // 解析参数
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
            
            // 创建红包参数
            DDRedEnvelopParam *param = [[DDRedEnvelopParam alloc] init];
            param.msgType = params[@"msgtype"];
            param.sendId = params[@"sendid"];
            param.channelId = params[@"channelid"];
            param.nickName = [selfContact getContactDisplayName];
            param.headImg = selfContact.m_nsHeadImgUrl;
            param.nativeUrl = nativeUrl;
            param.sessionUserName = isGroupSender ? wrap.m_nsToUsr : wrap.m_nsFromUsr;
            param.sign = params[@"sign"];
            param.isGroupSender = isGroupSender;
            
            // 先查询红包信息
            NSMutableDictionary *queryParams = [@{} mutableCopy];
            queryParams[@"agreeDuty"] = @"0";
            queryParams[@"channelId"] = param.channelId;
            queryParams[@"inWay"] = @"0";
            queryParams[@"msgType"] = param.msgType;
            queryParams[@"nativeUrl"] = param.nativeUrl;
            queryParams[@"sendId"] = param.sendId;
            
            WCRedEnvelopesLogicMgr *logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("WCRedEnvelopesLogicMgr")];
            [logicMgr ReceiverQueryRedEnvelopesRequest:queryParams];
            
            // 保存参数到队列
            [[DDRedEnvelopParamQueue sharedQueue] enqueue:param];
        }
    }
}

#pragma mark - WCRedEnvelopesLogicMgr Hook

CHMethod2(void, WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, HongBaoRes *, arg1, Request, HongBaoReq *, arg2) {
    CHSuper2(WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, arg1, Request, arg2);
    
    // 检查是否是红包查询响应（cmdId 3）
    if (arg1.cgiCmdid != 3) {
        return;
    }
    
    DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
    
    // 解析响应数据
    NSString *responseString = [[NSString alloc] initWithData:arg1.retText.buffer encoding:NSUTF8StringEncoding];
    NSData *jsonData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    
    // 从队列中取出参数
    DDRedEnvelopParam *param = [[DDRedEnvelopParamQueue sharedQueue] dequeue];
    if (!param) {
        return;
    }
    
    // 检查是否可以抢红包
    BOOL canGrab = YES;
    
    // 检查是否已经抢过
    if ([responseDict[@"receiveStatus"] integerValue] == 2) {
        canGrab = NO;
    }
    
    // 检查红包是否已经被抢完
    if ([responseDict[@"hbStatus"] integerValue] == 4) {
        canGrab = NO;
    }
    
    // 检查是否有 timingIdentifier
    if (!responseDict[@"timingIdentifier"]) {
        canGrab = NO;
    }
    
    // 检查签名（非自己发送的红包需要验证签名）
    if (!param.isGroupSender) {
        // 解析请求中的签名
        NSString *requestString = [[NSString alloc] initWithData:arg2.reqText.buffer encoding:NSUTF8StringEncoding];
        NSMutableDictionary *requestDict = [NSMutableDictionary dictionary];
        NSArray *requestComponents = [requestString componentsSeparatedByString:@"&"];
        for (NSString *component in requestComponents) {
            NSArray *keyValue = [component componentsSeparatedByString:@"="];
            if (keyValue.count == 2) {
                NSString *key = [keyValue[0] stringByRemovingPercentEncoding];
                NSString *value = [keyValue[1] stringByRemovingPercentEncoding];
                if (key && value) {
                    requestDict[key] = value;
                }
            }
        }
        
        NSString *nativeUrl = [requestDict[@"nativeUrl"] stringByRemovingPercentEncoding];
        NSString *nativeQuery = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
        NSMutableDictionary *nativeDict = [NSMutableDictionary dictionary];
        NSArray *nativeComponents = [nativeQuery componentsSeparatedByString:@"&"];
        for (NSString *component in nativeComponents) {
            NSArray *keyValue = [component componentsSeparatedByString:@"="];
            if (keyValue.count == 2) {
                NSString *key = [keyValue[0] stringByRemovingPercentEncoding];
                NSString *value = [keyValue[1] stringByRemangingPercentEncoding];
                if (key && value) {
                    nativeDict[key] = value;
                }
            }
        }
        
        NSString *requestSign = nativeDict[@"sign"];
        if (![requestSign isEqualToString:param.sign]) {
            canGrab = NO;
        }
    }
    
    if (canGrab && config.autoGrab) {
        param.timingIdentifier = responseDict[@"timingIdentifier"];
        
        // 计算延迟时间
        unsigned int delay = 0;
        if (config.delayTime > 0) {
            if (config.preventMultiple && ![DDRedEnvelopTaskManager sharedManager].serialQueueIsEmpty) {
                delay = 15000; // 15秒
            } else {
                delay = (unsigned int)config.delayTime;
            }
        }
        
        // 创建抢红包任务
        DDReceiveRedEnvelopOperation *operation = [[DDReceiveRedEnvelopOperation alloc] initWithRedEnvelopParam:param delay:delay];
        
        // 添加到任务队列
        if (config.preventMultiple) {
            [[DDRedEnvelopTaskManager sharedManager] addSerialTask:operation];
        } else {
            [[DDRedEnvelopTaskManager sharedManager] addNormalTask:operation];
        }
    }
}

#pragma mark - 插件注册

CHConstructor {
    @autoreleasepool {
        // 延迟加载，确保微信主框架已初始化
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 注册插件到插件管理器
            if (NSClassFromString(@"WCPluginsMgr")) {
                [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:kDDHongBaoTitle 
                                                                                    version:kDDHongBaoVersion 
                                                                                controller:@"DDHongBaoSettingController"];
            }
            
            // 加载Hook
            CHLoadLateClass(CMessageMgr);
            CHHook2(CMessageMgr, AsyncOnAddMsg, MsgWrap);
            
            CHLoadLateClass(WCRedEnvelopesLogicMgr);
            CHHook2(WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, Request);
            
            NSLog(@"%@ v%@ 已加载", kDDHongBaoTitle, kDDHongBaoVersion);
        });
    }
}