// DDHongBaoHelper.m
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 类型声明
@class CMessageWrap, CContact, CContactMgr, WCPayInfoItem, WCRedEnvelopesLogicMgr;
@class WCBizUtil, MMServiceCenter, SettingUtil, MMNewSessionMgr, WCPluginsMgr;

#pragma mark - 常量定义
static NSString *const kDDConfigAutoRedEnvelopKey = @"DD_autoRedEnvelop";
static NSString *const kDDConfigRedEnvelopDelayKey = @"DD_redEnvelopDelay";
static NSString *const kDDConfigRedEnvelopCatchMeKey = @"DD_redEnvelopCatchMe";
static NSString *const kDDConfigRedEnvelopMultipleCatchKey = @"DD_redEnvelopMultipleCatch";
static NSString *const kDDConfigRedEnvelopGroupFiterKey = @"DD_redEnvelopGroupFiter";

#pragma mark - 配置管理器
@interface DDHongBaoConfig : NSObject

@property (nonatomic, assign) BOOL autoRedEnvelop;           // 自动抢红包开关
@property (nonatomic, assign) NSInteger redEnvelopDelay;     // 延迟时间(毫秒)
@property (nonatomic, assign) BOOL redEnvelopCatchMe;        // 抢自己红包开关
@property (nonatomic, assign) BOOL redEnvelopMultipleCatch;  // 防止同时抢多个开关
@property (nonatomic, strong) NSMutableArray<NSString *> *redEnvelopGroupFiter; // 群聊过滤列表

+ (instancetype)sharedConfig;
- (void)loadConfig;
- (void)saveConfig;
- (void)resetToDefaults;

@end

@implementation DDHongBaoConfig {
    NSUserDefaults *_userDefaults;
}

+ (instancetype)sharedConfig {
    static DDHongBaoConfig *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[DDHongBaoConfig alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _userDefaults = [NSUserDefaults standardUserDefaults];
        [self loadConfig];
    }
    return self;
}

- (void)loadConfig {
    _autoRedEnvelop = [_userDefaults boolForKey:kDDConfigAutoRedEnvelopKey];
    _redEnvelopDelay = [_userDefaults integerForKey:kDDConfigRedEnvelopDelayKey];
    _redEnvelopCatchMe = [_userDefaults boolForKey:kDDConfigRedEnvelopCatchMeKey];
    _redEnvelopMultipleCatch = [_userDefaults boolForKey:kDDConfigRedEnvelopMultipleCatchKey];
    
    NSArray *savedGroups = [_userDefaults arrayForKey:kDDConfigRedEnvelopGroupFiterKey];
    _redEnvelopGroupFiter = savedGroups ? [NSMutableArray arrayWithArray:savedGroups] : [NSMutableArray array];
}

- (void)saveConfig {
    [_userDefaults setBool:_autoRedEnvelop forKey:kDDConfigAutoRedEnvelopKey];
    [_userDefaults setInteger:_redEnvelopDelay forKey:kDDConfigRedEnvelopDelayKey];
    [_userDefaults setBool:_redEnvelopCatchMe forKey:kDDConfigRedEnvelopCatchMeKey];
    [_userDefaults setBool:_redEnvelopMultipleCatch forKey:kDDConfigRedEnvelopMultipleCatchKey];
    [_userDefaults setObject:_redEnvelopGroupFiter forKey:kDDConfigRedEnvelopGroupFiterKey];
    [_userDefaults synchronize];
}

- (void)resetToDefaults {
    _autoRedEnvelop = YES;
    _redEnvelopDelay = 0;
    _redEnvelopCatchMe = NO;
    _redEnvelopMultipleCatch = YES;
    _redEnvelopGroupFiter = [NSMutableArray array];
    [self saveConfig];
}

@end

#pragma mark - 红包参数模型
@interface DDRedEnvelopParam : NSObject <NSCopying>

@property (nonatomic, copy) NSString *msgType;           // 消息类型
@property (nonatomic, copy) NSString *sendId;            // 发送ID
@property (nonatomic, copy) NSString *channelId;         // 渠道ID
@property (nonatomic, copy) NSString *nickName;          // 昵称
@property (nonatomic, copy) NSString *headImg;           // 头像
@property (nonatomic, copy) NSString *nativeUrl;         // 原生URL
@property (nonatomic, copy) NSString *sessionUserName;   // 会话用户名
@property (nonatomic, copy) NSString *sign;              // 签名
@property (nonatomic, copy) NSString *timingIdentifier;  // 定时标识符
@property (nonatomic, assign) BOOL isGroupSender;        // 是否为群发送者

- (BOOL)isValid;

@end

@implementation DDRedEnvelopParam

- (id)copyWithZone:(NSZone *)zone {
    DDRedEnvelopParam *copy = [[[self class] allocWithZone:zone] init];
    copy.msgType = self.msgType;
    copy.sendId = self.sendId;
    copy.channelId = self.channelId;
    copy.nickName = self.nickName;
    copy.headImg = self.headImg;
    copy.nativeUrl = self.nativeUrl;
    copy.sessionUserName = self.sessionUserName;
    copy.sign = self.sign;
    copy.timingIdentifier = self.timingIdentifier;
    copy.isGroupSender = self.isGroupSender;
    return copy;
}

- (BOOL)isValid {
    return self.msgType.length > 0 && 
           self.sendId.length > 0 && 
           self.channelId.length > 0 && 
           self.nativeUrl.length > 0;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<DDRedEnvelopParam: sendId=%@, isGroupSender=%@>", 
            self.sendId, self.isGroupSender ? @"YES" : @"NO"];
}

@end

#pragma mark - 红包参数队列
@interface DDRedEnvelopParamQueue : NSObject

@property (nonatomic, assign, readonly) NSUInteger count;

+ (instancetype)sharedQueue;
- (void)enqueue:(DDRedEnvelopParam *)param;
- (DDRedEnvelopParam *)dequeue;
- (void)removeAll;
- (BOOL)containsSendId:(NSString *)sendId;

@end

@implementation DDRedEnvelopParamQueue {
    NSMutableOrderedSet<DDRedEnvelopParam *> *_queue;
    NSRecursiveLock *_lock;
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
        _queue = [NSMutableOrderedSet orderedSet];
        _lock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (NSUInteger)count {
    [_lock lock];
    NSUInteger count = _queue.count;
    [_lock unlock];
    return count;
}

- (void)enqueue:(DDRedEnvelopParam *)param {
    if (!param || !param.isValid) return;
    
    [_lock lock];
    if (![self containsSendId:param.sendId]) {
        [_queue addObject:param];
    }
    [_lock unlock];
}

- (DDRedEnvelopParam *)dequeue {
    [_lock lock];
    DDRedEnvelopParam *first = nil;
    if (_queue.count > 0) {
        first = [_queue firstObject];
        [_queue removeObjectAtIndex:0];
    }
    [_lock unlock];
    return first;
}

- (void)removeAll {
    [_lock lock];
    [_queue removeAllObjects];
    [_lock unlock];
}

- (BOOL)containsSendId:(NSString *)sendId {
    if (!sendId) return NO;
    
    for (DDRedEnvelopParam *param in _queue) {
        if ([param.sendId isEqualToString:sendId]) {
            return YES;
        }
    }
    return NO;
}

@end

#pragma mark - 红包操作任务
@interface DDReceiveRedEnvelopOperation : NSOperation

@property (nonatomic, strong, readonly) DDRedEnvelopParam *redEnvelopParam;
@property (nonatomic, assign, readonly) NSUInteger delayMilliseconds;

- (instancetype)initWithRedEnvelopParam:(DDRedEnvelopParam *)param delay:(NSUInteger)delayMilliseconds;

@end

@implementation DDReceiveRedEnvelopOperation {
    DDRedEnvelopParam *_redEnvelopParam;
    NSUInteger _delayMilliseconds;
    BOOL _isExecuting;
    BOOL _isFinished;
}

@synthesize redEnvelopParam = _redEnvelopParam;
@synthesize delayMilliseconds = _delayMilliseconds;

- (instancetype)initWithRedEnvelopParam:(DDRedEnvelopParam *)param delay:(NSUInteger)delayMilliseconds {
    self = [super init];
    if (self) {
        _redEnvelopParam = [param copy];
        _delayMilliseconds = delayMilliseconds;
        _isExecuting = NO;
        _isFinished = NO;
    }
    return self;
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
    @autoreleasepool {
        if (self.isCancelled) {
            [self completeOperation];
            return;
        }
        
        // 延迟执行
        if (_delayMilliseconds > 0) {
            [NSThread sleepForTimeInterval:_delayMilliseconds / 1000.0];
        }
        
        if (self.isCancelled) {
            [self completeOperation];
            return;
        }
        
        // 执行抢红包请求
        [self openRedEnvelop];
        
        [self completeOperation];
    }
}

- (void)openRedEnvelop {
    if (!_redEnvelopParam.isValid) return;
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    params[@"agreeDuty"] = @"0";
    params[@"channelId"] = _redEnvelopParam.channelId;
    params[@"inWay"] = @"0";
    params[@"msgType"] = _redEnvelopParam.msgType;
    params[@"nativeUrl"] = _redEnvelopParam.nativeUrl;
    params[@"sendId"] = _redEnvelopParam.sendId;
    params[@"timingIdentifier"] = _redEnvelopParam.timingIdentifier;
    
    // 使用正确的类名和方法
    Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
    if (!logicMgrClass) return;
    
    // 获取服务 - 根据头文件，应该使用 MMServiceCenter.defaultCenter.getService:
    id serviceCenter = [objc_getClass("MMServiceCenter") defaultCenter];
    if (!serviceCenter) return;
    
    // 使用正确的消息发送方式
    id logicMgr = ((id (*)(id, SEL, Class))objc_msgSend)(serviceCenter, NSSelectorFromString(@"getService:"), logicMgrClass);
    if (!logicMgr) return;
    
    SEL selector = NSSelectorFromString(@"OpenRedEnvelopesRequest:");
    if ([logicMgr respondsToSelector:selector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(logicMgr, selector, params);
    }
}

- (void)completeOperation {
    [self willChangeValueForKey:@"isFinished"];
    [self willChangeValueForKey:@"isExecuting"];
    
    _isExecuting = NO;
    _isFinished = YES;
    
    [self didChangeValueForKey:@"isExecuting"];
    [self didChangeValueForKey:@"isFinished"];
}

@end

#pragma mark - 红包任务管理器
@interface DDRedEnvelopTaskManager : NSObject

@property (nonatomic, assign, readonly) BOOL hasPendingTasks;
@property (nonatomic, assign, readonly) NSUInteger pendingTaskCount;

+ (instancetype)sharedManager;
- (void)addTask:(DDReceiveRedEnvelopOperation *)task;
- (void)cancelAllTasks;
- (void)waitUntilAllTasksAreFinished;

@end

@implementation DDRedEnvelopTaskManager {
    NSOperationQueue *_operationQueue;
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
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.name = @"com.dd.hongbao.taskqueue";
        _operationQueue.maxConcurrentOperationCount = 1; // 串行执行
        _operationQueue.qualityOfService = NSQualityOfServiceUserInitiated;
    }
    return self;
}

- (BOOL)hasPendingTasks {
    return _operationQueue.operationCount > 0;
}

- (NSUInteger)pendingTaskCount {
    return _operationQueue.operationCount;
}

- (void)addTask:(DDReceiveRedEnvelopOperation *)task {
    if (task) {
        [_operationQueue addOperation:task];
    }
}

- (void)cancelAllTasks {
    [_operationQueue cancelAllOperations];
}

- (void)waitUntilAllTasksAreFinished {
    [_operationQueue waitUntilAllOperationsAreFinished];
}

@end

#pragma mark - 设置界面控制器
@interface DDHongBaoSettingController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

- (void)setupUI;
- (void)setupNavigationBar;
- (void)reloadTableViewData;

@end

@implementation DDHongBaoSettingController

#pragma mark - 生命周期
- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupUI];
    [self setupNavigationBar];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadTableViewData];
}

#pragma mark - UI设置
- (void)setupUI {
    self.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.96 alpha:1.0];
    
    // 创建表格视图
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.backgroundColor = [UIColor clearColor];
    _tableView.separatorColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    _tableView.rowHeight = 56.0;
    [_tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"DDSettingCell"];
    
    [self.view addSubview:_tableView];
}

- (void)setupNavigationBar {
    self.title = @"DD红包助手";
    
    // 关闭按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"关闭"
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self
                                                                  action:@selector(handleClose)];
    self.navigationItem.leftBarButtonItem = closeButton;
    
    // 重置按钮
    UIBarButtonItem *resetButton = [[UIBarButtonItem alloc] initWithTitle:@"重置"
                                                                    style:UIBarButtonItemStylePlain
                                                                   target:self
                                                                   action:@selector(handleReset)];
    self.navigationItem.rightBarButtonItem = resetButton;
}

- (void)reloadTableViewData {
    [_tableView reloadData];
}

#pragma mark - 事件处理
- (void)handleClose {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)handleReset {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重置设置"
                                                                   message:@"确定要恢复默认设置吗？"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                              style:UIAlertActionStyleDestructive
                                            handler:^(UIAlertAction * _Nonnull action) {
        [[DDHongBaoConfig sharedConfig] resetToDefaults];
        [self reloadTableViewData];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)handleAutoRedEnvelopSwitch:(UISwitch *)sender {
    DDHongBaoConfig.sharedConfig.autoRedEnvelop = sender.isOn;
    [DDHongBaoConfig.sharedConfig saveConfig];
}

- (void)handleCatchMeSwitch:(UISwitch *)sender {
    DDHongBaoConfig.sharedConfig.redEnvelopCatchMe = sender.isOn;
    [DDHongBaoConfig.sharedConfig saveConfig];
}

- (void)handleMultipleCatchSwitch:(UISwitch *)sender {
    DDHongBaoConfig.sharedConfig.redEnvelopMultipleCatch = sender.isOn;
    [DDHongBaoConfig.sharedConfig saveConfig];
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1; // 基本设置
        case 1: return 3; // 高级设置
        case 2: return 1; // 关于
        default: return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DDSettingCell" forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    [self configureCell:cell forIndexPath:indexPath];
    
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell forIndexPath:(NSIndexPath *)indexPath {
    DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
    
    // 清除旧内容
    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    if (indexPath.section == 0) {
        // 基本设置
        cell.textLabel.text = @"自动抢红包";
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = config.autoRedEnvelop;
        [switchView addTarget:self action:@selector(handleAutoRedEnvelopSwitch:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    }
    else if (indexPath.section == 1) {
        // 高级设置
        switch (indexPath.row) {
            case 0: {
                cell.textLabel.text = @"延迟抢红包";
                cell.detailTextLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
                cell.detailTextLabel.text = config.redEnvelopDelay > 0 ? 
                    [NSString stringWithFormat:@"%ld毫秒", (long)config.redEnvelopDelay] : @"不延迟";
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            }
            case 1: {
                cell.textLabel.text = @"抢自己的红包";
                UISwitch *switchView = [[UISwitch alloc] init];
                switchView.on = config.redEnvelopCatchMe;
                [switchView addTarget:self action:@selector(handleCatchMeSwitch:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = switchView;
                break;
            }
            case 2: {
                cell.textLabel.text = @"防止同时抢多个";
                UISwitch *switchView = [[UISwitch alloc] init];
                switchView.on = config.redEnvelopMultipleCatch;
                [switchView addTarget:self action:@selector(handleMultipleCatchSwitch:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = switchView;
                break;
            }
        }
    }
    else if (indexPath.section == 2) {
        // 关于
        cell.textLabel.text = @"版本信息";
        cell.detailTextLabel.text = @"v1.0";
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:1.0];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"基本设置";
        case 1: return @"高级设置";
        case 2: return @"关于";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 1) {
        return @"开启'防止同时抢多个'后，红包将按顺序逐个处理，避免触发微信安全检测";
    }
    return nil;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 1 && indexPath.row == 0) {
        [self showDelaySettingAlert];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == 1) {
        return 60.0;
    }
    return 20.0;
}

#pragma mark - 设置延迟弹窗
- (void)showDelaySettingAlert {
    DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"延迟设置"
                                                                   message:@"设置抢红包的延迟时间（毫秒）\n1000毫秒 = 1秒"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.placeholder = @"输入延迟毫秒数";
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        if (config.redEnvelopDelay > 0) {
            textField.text = [NSString stringWithFormat:@"%ld", (long)config.redEnvelopDelay];
        }
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                              style:UIAlertActionStyleDefault
                                            handler:^(UIAlertAction * _Nonnull action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *text = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSInteger delay = [text integerValue];
        
        if (delay >= 0) {
            config.redEnvelopDelay = delay;
            [config saveConfig];
            [self reloadTableViewData];
        } else {
            // 输入无效，显示提示
            [self showInvalidInputAlert];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showInvalidInputAlert {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"输入无效"
                                                                   message:@"请输入有效的数字（大于等于0）"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - Hook实现 (CMessageMgr)
@interface CMessageMgr : NSObject
- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(id)wrap;
@end

@interface CMessageMgr (DDHongBaoHelper)

- (void)dd_AsyncOnAddMsg:(NSString *)msg MsgWrap:(id)wrap;

@end

@implementation CMessageMgr (DDHongBaoHelper)

- (void)dd_AsyncOnAddMsg:(NSString *)msg MsgWrap:(id)wrap {
    // 调用原始实现
    [self dd_AsyncOnAddMsg:msg MsgWrap:wrap];
    
    // 检查配置
    DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
    if (!config.autoRedEnvelop) return;
    
    // 检查消息类型 (49 = AppNode)
    NSInteger messageType = [[wrap valueForKey:@"m_uiMessageType"] integerValue];
    if (messageType != 49) return;
    
    // 检查是否为红包消息
    NSString *content = [wrap valueForKey:@"m_nsContent"];
    if (![content containsString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"]) {
        return;
    }
    
    // 获取会话信息
    NSString *fromUsr = [wrap valueForKey:@"m_nsFromUsr"];
    NSString *toUsr = [wrap valueForKey:@"m_nsToUsr"];
    
    // 群聊过滤检查
    if ([config.redEnvelopGroupFiter containsObject:fromUsr]) {
        return;
    }
    
    // 获取自己信息 - 使用正确的消息发送方式
    id serviceCenter = [objc_getClass("MMServiceCenter") defaultCenter];
    id contactMgr = ((id (*)(id, SEL, Class))objc_msgSend)(serviceCenter, NSSelectorFromString(@"getService:"), objc_getClass("CContactMgr"));
    
    if (!contactMgr) return;
    
    id selfContact = ((id (*)(id, SEL))objc_msgSend)(contactMgr, NSSelectorFromString(@"getSelfContact"));
    if (!selfContact) return;
    
    NSString *selfUsrName = [selfContact valueForKey:@"m_nsUsrName"];
    if (!selfUsrName) return;
    
    // 判断红包类型
    BOOL isGroupSender = [selfUsrName isEqualToString:fromUsr] && [toUsr containsString:@"chatroom"];
    
    // 检查是否抢自己红包
    if (isGroupSender && !config.redEnvelopCatchMe) {
        return;
    }
    
    // 获取红包信息
    id payInfoItem = [wrap valueForKey:@"m_oWCPayInfoItem"];
    if (!payInfoItem) return;
    
    NSString *nativeUrl = [payInfoItem valueForKey:@"m_c2cNativeUrl"];
    if (!nativeUrl) return;
    
    // 解析红包参数
    NSRange range = [nativeUrl rangeOfString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"];
    if (range.location == NSNotFound) return;
    
    NSString *queryString = [nativeUrl substringFromIndex:range.location + range.length];
    if (queryString.length == 0) return;
    
    Class wcBizUtilClass = objc_getClass("WCBizUtil");
    if (!wcBizUtilClass) return;
    
    NSDictionary *nativeUrlDict = nil;
    SEL dictionarySelector = NSSelectorFromString(@"dictionaryWithDecodedComponets:separator:");
    
    if ([wcBizUtilClass respondsToSelector:dictionarySelector]) {
        nativeUrlDict = ((id (*)(id, SEL, id, id))objc_msgSend)(wcBizUtilClass, dictionarySelector, queryString, @"&");
    }
    
    if (!nativeUrlDict) return;
    
    // 创建红包参数
    DDRedEnvelopParam *param = [[DDRedEnvelopParam alloc] init];
    param.msgType = [nativeUrlDict objectForKey:@"msgtype"];
    param.sendId = [nativeUrlDict objectForKey:@"sendid"];
    param.channelId = [nativeUrlDict objectForKey:@"channelid"];
    param.nickName = [selfContact valueForKey:@"m_nsNickName"] ?: @"";
    param.headImg = [selfContact valueForKey:@"m_nsHeadImgUrl"] ?: @"";
    param.nativeUrl = nativeUrl;
    param.sessionUserName = isGroupSender ? toUsr : fromUsr;
    param.sign = [nativeUrlDict objectForKey:@"sign"];
    param.isGroupSender = isGroupSender;
    
    // 验证参数
    if (![param isValid]) return;
    
    // 查询红包信息
    [self queryRedEnvelopInfoWithParam:param];
    
    // 保存参数到队列
    [[DDRedEnvelopParamQueue sharedQueue] enqueue:param];
}

- (void)queryRedEnvelopInfoWithParam:(DDRedEnvelopParam *)param {
    if (!param.isValid) return;
    
    NSMutableDictionary *queryParams = [NSMutableDictionary dictionary];
    queryParams[@"agreeDuty"] = @"0";
    queryParams[@"channelId"] = param.channelId;
    queryParams[@"inWay"] = @"0";
    queryParams[@"msgType"] = param.msgType;
    queryParams[@"nativeUrl"] = param.nativeUrl;
    queryParams[@"sendId"] = param.sendId;
    
    Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
    if (!logicMgrClass) return;
    
    id serviceCenter = [objc_getClass("MMServiceCenter") defaultCenter];
    if (!serviceCenter) return;
    
    id logicMgr = ((id (*)(id, SEL, Class))objc_msgSend)(serviceCenter, NSSelectorFromString(@"getService:"), logicMgrClass);
    if (!logicMgr) return;
    
    SEL selector = NSSelectorFromString(@"ReceiverQueryRedEnvelopesRequest:");
    if ([logicMgr respondsToSelector:selector]) {
        ((void (*)(id, SEL, id))objc_msgSend)(logicMgr, selector, queryParams);
    }
}

@end

#pragma mark - Hook实现 (WCRedEnvelopesLogicMgr)
@interface WCRedEnvelopesLogicMgr : NSObject
- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2;
@end

@interface WCRedEnvelopesLogicMgr (DDHongBaoHelper)

- (void)dd_OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2;

@end

@implementation WCRedEnvelopesLogicMgr (DDHongBaoHelper)

- (void)dd_OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    // 调用原始实现
    [self dd_OnWCToHongbaoCommonResponse:arg1 Request:arg2];
    
    // 检查是否为查询响应 (cgiCmdid = 3)
    NSInteger cgiCmdid = [[arg1 valueForKey:@"cgiCmdid"] integerValue];
    if (cgiCmdid != 3) return;
    
    // 获取响应数据
    id retText = [arg1 valueForKey:@"retText"];
    if (!retText) return;
    
    NSData *buffer = [retText valueForKey:@"buffer"];
    if (!buffer || buffer.length == 0) return;
    
    NSString *responseString = [[NSString alloc] initWithData:buffer encoding:NSUTF8StringEncoding];
    if (!responseString) return;
    
    // 解析JSON响应
    NSDictionary *responseDict = nil;
    @try {
        responseDict = [NSJSONSerialization JSONObjectWithData:buffer options:0 error:nil];
    } @catch (NSException *exception) {
        return;
    }
    
    if (![responseDict isKindOfClass:[NSDictionary class]]) {
        return;
    }
    
    // 获取红包参数
    DDRedEnvelopParam *param = [[DDRedEnvelopParamQueue sharedQueue] dequeue];
    if (!param) return;
    
    // 检查响应状态
    NSInteger receiveStatus = [[responseDict objectForKey:@"receiveStatus"] integerValue];
    NSInteger hbStatus = [[responseDict objectForKey:@"hbStatus"] integerValue];
    NSString *timingIdentifier = [responseDict objectForKey:@"timingIdentifier"];
    
    if (receiveStatus == 2) return; // 已经抢过
    if (hbStatus == 4) return; // 红包已抢完
    if (!timingIdentifier || timingIdentifier.length == 0) return; // 缺少必要参数
    
    // 更新参数
    param.timingIdentifier = timingIdentifier;
    
    // 计算延迟
    DDHongBaoConfig *config = [DDHongBaoConfig sharedConfig];
    NSUInteger delayMilliseconds = 0;
    
    if (config.redEnvelopDelay > 0) {
        if (config.redEnvelopMultipleCatch && 
            [DDRedEnvelopTaskManager sharedManager].hasPendingTasks) {
            // 有任务在排队，使用固定延迟
            delayMilliseconds = 15000; // 15秒
        } else {
            delayMilliseconds = config.redEnvelopDelay;
        }
    }
    
    // 创建并执行抢红包任务
    DDReceiveRedEnvelopOperation *operation = 
        [[DDReceiveRedEnvelopOperation alloc] initWithRedEnvelopParam:param 
                                                                delay:delayMilliseconds];
    
    [[DDRedEnvelopTaskManager sharedManager] addTask:operation];
}

@end

#pragma mark - 插件初始化
__attribute__((constructor)) static void DDHongBaoHelperInitialize(void) {
    @autoreleasepool {
        NSLog(@"[DDHongBaoHelper] 插件初始化开始");
        
        // 注册到微信插件系统
        Class pluginsMgrClass = objc_getClass("WCPluginsMgr");
        if (pluginsMgrClass) {
            // 注意：根据您提供的插件管理示例，应该使用 sharedInstance 方法
            id pluginsMgr = ((id (*)(Class, SEL))objc_msgSend)(pluginsMgrClass, NSSelectorFromString(@"sharedInstance"));
            if (pluginsMgr) {
                SEL registerSelector = NSSelectorFromString(@"registerControllerWithTitle:version:controller:");
                if ([pluginsMgr respondsToSelector:registerSelector]) {
                    NSString *title = @"DD红包助手";
                    NSString *version = @"1.0";
                    NSString *controller = @"DDHongBaoSettingController";
                    
                    // 直接使用 objc_msgSend 调用
                    ((void (*)(id, SEL, NSString *, NSString *, NSString *))objc_msgSend)(pluginsMgr, registerSelector, title, version, controller);
                    
                    NSLog(@"[DDHongBaoHelper] 已注册到插件系统");
                }
            }
        }
        
        // Hook CMessageMgr
        Class CMessageMgrClass = objc_getClass("CMessageMgr");
        if (CMessageMgrClass) {
            SEL originalSelector = @selector(AsyncOnAddMsg:MsgWrap:);
            SEL swizzledSelector = @selector(dd_AsyncOnAddMsg:MsgWrap:);
            
            Method originalMethod = class_getInstanceMethod(CMessageMgrClass, originalSelector);
            Method swizzledMethod = class_getInstanceMethod(CMessageMgrClass, swizzledSelector);
            
            if (originalMethod && swizzledMethod) {
                method_exchangeImplementations(originalMethod, swizzledMethod);
                NSLog(@"[DDHongBaoHelper] CMessageMgr hook 成功");
            } else {
                NSLog(@"[DDHongBaoHelper] CMessageMgr hook 失败");
            }
        }
        
        // Hook WCRedEnvelopesLogicMgr
        Class WCRedEnvelopesLogicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
        if (WCRedEnvelopesLogicMgrClass) {
            SEL originalSelector = @selector(OnWCToHongbaoCommonResponse:Request:);
            SEL swizzledSelector = @selector(dd_OnWCToHongbaoCommonResponse:Request:);
            
            Method originalMethod = class_getInstanceMethod(WCRedEnvelopesLogicMgrClass, originalSelector);
            Method swizzledMethod = class_getInstanceMethod(WCRedEnvelopesLogicMgrClass, swizzledSelector);
            
            if (originalMethod && swizzledMethod) {
                method_exchangeImplementations(originalMethod, swizzledMethod);
                NSLog(@"[DDHongBaoHelper] WCRedEnvelopesLogicMgr hook 成功");
            } else {
                NSLog(@"[DDHongBaoHelper] WCRedEnvelopesLogicMgr hook 失败");
            }
        }
        
        // 加载配置
        [[DDHongBaoConfig sharedConfig] loadConfig];
        
        NSLog(@"[DDHongBaoHelper] 插件初始化完成");
    }
}