#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UserNotifications/UserNotifications.h>

#pragma mark - 微信私有类声明

@interface WCBizUtil : NSObject
+ (id)dictionaryWithDecodedComponets:(id)arg1 separator:(id)arg2;
@end

@interface SKBuiltinBuffer_t : NSObject
@property (retain, nonatomic) NSData *buffer;
@end

@interface WCPayInfoItem : NSObject
@property (retain, nonatomic) NSString *m_c2cNativeUrl;
@end

@interface CMessageMgr : NSObject
- (void)AddLocalMsg:(id)arg1 MsgWrap:(id)arg2 fixTime:(_Bool)arg3 NewMsgArriveNotify:(_Bool)arg4;
@end

@interface CMessageWrap : NSObject
@property (retain, nonatomic) WCPayInfoItem *m_oWCPayInfoItem;
@property (retain, nonatomic) NSString* m_nsFromUsr;
@property (retain, nonatomic) NSString* m_nsToUsr;
@property (assign, nonatomic) NSUInteger m_uiStatus;
@property (retain, nonatomic) NSString* m_nsContent;
@property (assign, nonatomic) NSUInteger m_uiMessageType;
@property (assign, nonatomic) NSUInteger m_uiCreateTime;
@end

@interface MMContext : NSObject
+ (id)activeUserContext;
+ (id)rootContext;
+ (id)currentContext;
- (id)getService:(Class)arg1;
@end

@interface WCRedEnvelopesLogicMgr : NSObject
- (void)OpenRedEnvelopesRequest:(id)params;
- (void)ReceiverQueryRedEnvelopesRequest:(id)arg1;
@end

@interface HongBaoRes : NSObject
@property (retain, nonatomic) SKBuiltinBuffer_t *retText;
@property (nonatomic) int cgiCmdid;
@end

@interface HongBaoReq : NSObject
@property (retain, nonatomic) SKBuiltinBuffer_t *reqText;
@end

@interface CContact : NSObject
@property (retain, nonatomic) NSString *m_nsUsrName;
@property (retain, nonatomic) NSString *m_nsHeadImgUrl;
@property (retain, nonatomic) NSString *m_nsNickName;
- (id)getContactDisplayName;
@end

@interface CContactMgr : NSObject
- (id)getSelfContact;
- (id)getContactByName:(id)arg1;
- (id)getContactForSearchByName:(id)arg1;
- (_Bool)addLocalContact:(id)arg1 listType:(unsigned int)arg2;
- (_Bool)getContactsFromServer:(id)arg1;
- (_Bool)isInContactList:(id)arg1;
@end

@interface MultiSelectContactsViewController : UIViewController
@property (nonatomic) int m_scene;
@property (nonatomic, weak) id m_delegate;
@property (nonatomic) _Bool m_bKeepCurViewAfterSelect;
@property (nonatomic) _Bool m_bShowHistoryGroup;
@property (nonatomic) unsigned int m_uiGroupScene;
@property (nonatomic) _Bool m_onlyChatRoom;
- (void)updatePanelBtn;
@end

@protocol MultiSelectContactsViewControllerDelegate <NSObject>
1
@end

#pragma mark - 插件管理接口

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

#pragma mark - 辅助分类

@interface NSDictionary (DDSafeAccess)
- (NSString *)dd_stringForKey:(NSString *)key;
@end

@implementation NSDictionary (DDSafeAccess)

- (NSString *)dd_stringForKey:(NSString *)key {
    id value = [self objectForKey:key];
    if ([value isKindOfClass:[NSString class]]) return value;
    if ([value isKindOfClass:[NSNumber class]]) return [value stringValue];
    return nil;
}

@end

@interface NSString (DDJSON)
- (id)dd_JSONDictionary;
@end

@implementation NSString (DDJSON)

- (id)dd_JSONDictionary {
    NSData *jsonData = [self dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) return nil;
    
    NSError *error = nil;
    id jsonObject = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (error) return nil;
    
    if ([jsonObject isKindOfClass:[NSDictionary class]]) return jsonObject;
    return nil;
}

@end

#pragma mark - 配置管理

@interface DDRedEnvelopConfig : NSObject
+ (instancetype)sharedConfig;

@property (assign, nonatomic) BOOL autoReceiveEnable;
@property (assign, nonatomic) NSInteger delaySeconds;
@property (assign, nonatomic) BOOL receiveSelfRedEnvelop;
@property (assign, nonatomic) BOOL serialReceive;
@property (strong, nonatomic) NSArray *blackList;
@property (assign, nonatomic) BOOL delayEnabled;
@property (assign, nonatomic) BOOL showNotification;
@end

static NSString * const kDelaySecondsKey = @"DDDelaySecondsKey";
static NSString * const kAutoReceiveRedEnvelopKey = @"DDAutoReceiveRedEnvelopKey";
static NSString * const kReceiveSelfRedEnvelopKey = @"DDReceiveSelfRedEnvelopKey";
static NSString * const kSerialReceiveKey = @"DDSerialReceiveKey";
static NSString * const kBlackListKey = @"DDBlackListKey";
static NSString * const kDelayEnabledKey = @"DDDelayEnabledKey";
static NSString * const kShowNotificationKey = @"DDShowNotificationKey";

@implementation DDRedEnvelopConfig

+ (instancetype)sharedConfig {
    static DDRedEnvelopConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [DDRedEnvelopConfig new];
    });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        _delaySeconds = [[NSUserDefaults standardUserDefaults] integerForKey:kDelaySecondsKey];
        _autoReceiveEnable = [[NSUserDefaults standardUserDefaults] boolForKey:kAutoReceiveRedEnvelopKey];
        _serialReceive = [[NSUserDefaults standardUserDefaults] boolForKey:kSerialReceiveKey];
        _blackList = [[NSUserDefaults standardUserDefaults] objectForKey:kBlackListKey];
        _receiveSelfRedEnvelop = [[NSUserDefaults standardUserDefaults] boolForKey:kReceiveSelfRedEnvelopKey];
        _delayEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kDelayEnabledKey];
        _showNotification = [[NSUserDefaults standardUserDefaults] boolForKey:kShowNotificationKey];
        
        if (_delaySeconds == 0) {
            _delaySeconds = 0;
            [[NSUserDefaults standardUserDefaults] setInteger:_delaySeconds forKey:kDelaySecondsKey];
        }
        
        if (![[NSUserDefaults standardUserDefaults] objectForKey:kShowNotificationKey]) {
            _showNotification = NO;
            [[NSUserDefaults standardUserDefaults] setBool:_showNotification forKey:kShowNotificationKey];
        }
        
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return self;
}

- (void)setDelaySeconds:(NSInteger)delaySeconds {
    _delaySeconds = delaySeconds;
    [[NSUserDefaults standardUserDefaults] setInteger:delaySeconds forKey:kDelaySecondsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setAutoReceiveEnable:(BOOL)autoReceiveEnable {
    _autoReceiveEnable = autoReceiveEnable;
    [[NSUserDefaults standardUserDefaults] setBool:autoReceiveEnable forKey:kAutoReceiveRedEnvelopKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setReceiveSelfRedEnvelop:(BOOL)receiveSelfRedEnvelop {
    _receiveSelfRedEnvelop = receiveSelfRedEnvelop;
    [[NSUserDefaults standardUserDefaults] setBool:receiveSelfRedEnvelop forKey:kReceiveSelfRedEnvelopKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setSerialReceive:(BOOL)serialReceive {
    _serialReceive = serialReceive;
    [[NSUserDefaults standardUserDefaults] setBool:serialReceive forKey:kSerialReceiveKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setDelayEnabled:(BOOL)delayEnabled {
    _delayEnabled = delayEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:delayEnabled forKey:kDelayEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setBlackList:(NSArray *)blackList {
    _blackList = blackList;
    [[NSUserDefaults standardUserDefaults] setObject:blackList forKey:kBlackListKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setShowNotification:(BOOL)showNotification {
    _showNotification = showNotification;
    [[NSUserDefaults standardUserDefaults] setBool:showNotification forKey:kShowNotificationKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

#pragma mark - 通知管理器

@interface DDNotificationManager : NSObject <UNUserNotificationCenterDelegate>
+ (instancetype)sharedManager;
- (void)showLocalNotificationWithAmount:(NSInteger)amount totalAmount:(NSInteger)totalAmount;
@end

@implementation DDNotificationManager

+ (instancetype)sharedManager {
    static DDNotificationManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[DDNotificationManager alloc] init];
        
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                              completionHandler:^(BOOL granted, NSError * _Nullable error) {}];
        
        center.delegate = manager;
    });
    return manager;
}

// 修改通知方法，支持总金额显示
- (void)showLocalNotificationWithAmount:(NSInteger)amount totalAmount:(NSInteger)totalAmount {
    if (![DDRedEnvelopConfig sharedConfig].showNotification || amount <= 0) return;
    
    CGFloat yuanAmount = amount / 100.0;
    
    NSString *message = nil;
    
    if (totalAmount > 0) {
        // 有总金额信息
        CGFloat yuanTotalAmount = totalAmount / 100.0;
        message = [NSString stringWithFormat:@"成功抢到红包%.2f元，总共：%.2f元", yuanAmount, yuanTotalAmount];
    } else {
        // 没有总金额信息
        message = [NSString stringWithFormat:@"成功抢到红包%.2f元", yuanAmount];
    }
    
    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    content.title = @"红包通知";
    content.body = message;
    content.sound = [UNNotificationSound defaultSound];
    
    UNTimeIntervalNotificationTrigger *trigger = [UNTimeIntervalNotificationTrigger 
        triggerWithTimeInterval:0.1 repeats:NO];
    
    NSString *identifier = [NSString stringWithFormat:@"DD_RED_ENVELOP_%@", @([[NSDate date] timeIntervalSince1970])];
    UNNotificationRequest *request = [UNNotificationRequest 
        requestWithIdentifier:identifier 
        content:content 
        trigger:trigger];
    
    [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:request withCompletionHandler:nil];
}

#pragma mark - UNUserNotificationCenterDelegate

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
didReceiveNotificationResponse:(UNNotificationResponse *)response
         withCompletionHandler:(void(^)(void))completionHandler {
    completionHandler();
}

@end

#pragma mark - 红包参数

@interface DDWeChatRedEnvelopParam : NSObject
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

@implementation DDWeChatRedEnvelopParam

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

#pragma mark - 参数队列

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
        _queue = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)enqueue:(DDWeChatRedEnvelopParam *)param {
    [_queue addObject:param];
}

- (DDWeChatRedEnvelopParam *)dequeue {
    if (_queue.count == 0) return nil;
    
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

@interface DDReceiveRedEnvelopOperation : NSOperation
@property (assign, nonatomic, getter=isExecuting) BOOL executing;
@property (assign, nonatomic, getter=isFinished) BOOL finished;
- (instancetype)initWithRedEnvelopParam:(DDWeChatRedEnvelopParam *)param delay:(unsigned int)delaySeconds;
@end

@implementation DDReceiveRedEnvelopOperation {
    DDWeChatRedEnvelopParam *_redEnvelopParam;
    unsigned int _delaySeconds;
}

@synthesize executing = _executing;
@synthesize finished = _finished;

- (instancetype)initWithRedEnvelopParam:(DDWeChatRedEnvelopParam *)param delay:(unsigned int)delaySeconds {
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
    sleep(_delaySeconds);
    
    MMContext *context = [objc_getClass("MMContext") activeUserContext];
    WCRedEnvelopesLogicMgr *logicMgr = [context getService:objc_getClass("WCRedEnvelopesLogicMgr")];
    [logicMgr OpenRedEnvelopesRequest:[_redEnvelopParam toParams]];
    
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

@interface DDTaskManager : NSObject
+ (instancetype)sharedManager;
- (void)addNormalTask:(DDReceiveRedEnvelopOperation *)task;
- (void)addSerialTask:(DDReceiveRedEnvelopOperation *)task;
- (BOOL)serialQueueIsEmpty;
@end

@implementation DDTaskManager {
    NSOperationQueue *_normalTaskQueue;
    NSOperationQueue *_serialTaskQueue;
}

+ (instancetype)sharedManager {
    static DDTaskManager *taskManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        taskManager = [DDTaskManager new];
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
    return [_serialTaskQueue operations].count == 0;
}

@end

#pragma mark - 设置界面

@interface DDRedEnvelopSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, MultiSelectContactsViewControllerDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *delaySecondsField;
@property (nonatomic, strong) UIButton *delayConfirmButton;
@end

#pragma mark - 主界面

@interface DDRedEnvelopMainViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation DDRedEnvelopMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD红包";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"DDRedEnvelopMainCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    
    cell.textLabel.text = @"红包辅助";
    cell.imageView.image = [UIImage systemImageNamed:@"gift.fill"];
    cell.imageView.tintColor = [UIColor systemBlueColor];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 55.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    DDRedEnvelopSettingsViewController *settingsVC = [[DDRedEnvelopSettingsViewController alloc] init];
    [self.navigationController pushViewController:settingsVC animated:YES];
}

@end

#pragma mark - 设置界面实现

@implementation DDRedEnvelopSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"红包辅助";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    DDRedEnvelopConfig *config = [DDRedEnvelopConfig sharedConfig];
    if (!config.autoReceiveEnable) return 1;
    
    int rowCount = 6; // 基础6项
    if (config.delayEnabled) rowCount += 1; // 延迟输入框
    return rowCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    DDRedEnvelopConfig *config = [DDRedEnvelopConfig sharedConfig];
    
    if (!config.autoReceiveEnable) {
        return [self createCellWithTitle:@"自动抢红包" switchAction:@selector(autoReceiveChanged:) on:config.autoReceiveEnable];
    }
    
    NSInteger rowIndex = indexPath.row;
    
    if (rowIndex == 0) {
        return [self createCellWithTitle:@"自动抢红包" switchAction:@selector(autoReceiveChanged:) on:config.autoReceiveEnable];
    } else if (rowIndex == 1) {
        return [self createCellWithTitle:@"延迟抢红包" switchAction:@selector(delayEnabledChanged:) on:config.delayEnabled];
    } else if (config.delayEnabled && rowIndex == 2) {
        return [self createDelayInputCell];
    } else {
        // 调整索引以跳过延迟输入框
        if (config.delayEnabled) {
            rowIndex -= 1;
        }
        
        if (rowIndex == 2) {
            return [self createCellWithTitle:@"抢自己红包" switchAction:@selector(receiveSelfChanged:) on:config.receiveSelfRedEnvelop];
        } else if (rowIndex == 3) {
            return [self createCellWithTitle:@"防止同时抢" switchAction:@selector(serialReceiveChanged:) on:config.serialReceive];
        } else if (rowIndex == 4) {
            return [self createBlackListCell];
        } else if (rowIndex == 5) {
            return [self createCellWithTitle:@"抢红包通知" switchAction:@selector(notificationChanged:) on:config.showNotification];
        }
    }
    
    return [[UITableViewCell alloc] init];
}

- (UITableViewCell *)createCellWithTitle:(NSString *)title switchAction:(SEL)action on:(BOOL)isOn {
    static NSString *cellIdentifier = @"SwitchCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    
    cell.textLabel.text = title;
    
    if (action) {
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.onTintColor = [UIColor systemBlueColor];
        switchView.on = isOn;
        [switchView addTarget:self action:action forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    } else {
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (UITableViewCell *)createDelayInputCell {
    static NSString *cellIdentifier = @"DelayInputCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(20, 10, self.view.frame.size.width - 140, 40)];
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.placeholder = @"输入延迟秒数（如：2）";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.delegate = self;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.backgroundColor = [UIColor tertiarySystemBackgroundColor];
        textField.textColor = [UIColor labelColor];
        [cell.contentView addSubview:textField];
        self.delaySecondsField = textField;
        
        UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
        confirmButton.frame = CGRectMake(self.view.frame.size.width - 110, 10, 80, 40);
        [confirmButton setTitle:@"确认" forState:UIControlStateNormal];
        confirmButton.tintColor = [UIColor systemBlueColor];
        [confirmButton addTarget:self action:@selector(delayConfirmTapped:) forControlEvents:UIControlEventTouchUpInside];
        self.delayConfirmButton = confirmButton;
        
        [cell.contentView addSubview:confirmButton];
    }
    
    NSInteger delaySeconds = [DDRedEnvelopConfig sharedConfig].delaySeconds;
    self.delaySecondsField.text = delaySeconds > 0 ? [NSString stringWithFormat:@"%ld", (long)delaySeconds] : @"";
    
    return cell;
}

- (UITableViewCell *)createBlackListCell {
    static NSString *cellIdentifier = @"BlackListCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    
    cell.textLabel.text = @"过滤黑名单";
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    DDRedEnvelopConfig *config = [DDRedEnvelopConfig sharedConfig];
    if (config.autoReceiveEnable && config.delayEnabled && indexPath.row == 2) {
        return 60.0;
    }
    return 50.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    DDRedEnvelopConfig *config = [DDRedEnvelopConfig sharedConfig];
    if (!config.autoReceiveEnable) return;
    
    NSInteger rowIndex = indexPath.row;
    
    // 调整索引以匹配实际的行
    if (config.delayEnabled && rowIndex > 2) {
        rowIndex -= 1;
    }
    
    if (rowIndex == 4) {
        [self showBlackList];
    }
}

- (void)autoReceiveChanged:(UISwitch *)sender {
    [DDRedEnvelopConfig sharedConfig].autoReceiveEnable = sender.isOn;
    [self.tableView reloadData];
}

- (void)delayEnabledChanged:(UISwitch *)sender {
    [DDRedEnvelopConfig sharedConfig].delayEnabled = sender.isOn;
    [self.tableView reloadData];
}

- (void)receiveSelfChanged:(UISwitch *)sender {
    [DDRedEnvelopConfig sharedConfig].receiveSelfRedEnvelop = sender.isOn;
}

- (void)serialReceiveChanged:(UISwitch *)sender {
    [DDRedEnvelopConfig sharedConfig].serialReceive = sender.isOn;
}

- (void)notificationChanged:(UISwitch *)sender {
    [DDRedEnvelopConfig sharedConfig].showNotification = sender.isOn;
}

- (void)delayConfirmTapped:(UIButton *)sender {
    [self.delaySecondsField resignFirstResponder];
    [self saveDelaySecondsValue];
}

- (void)saveDelaySecondsValue {
    NSString *text = self.delaySecondsField.text;
    if (text && text.length > 0) {
        NSInteger delaySeconds = [text integerValue];
        if (delaySeconds >= 0 && delaySeconds <= 60) {
            [DDRedEnvelopConfig sharedConfig].delaySeconds = delaySeconds;
        } else {
            self.delaySecondsField.text = @"0";
            [DDRedEnvelopConfig sharedConfig].delaySeconds = 0;
        }
    } else {
        [DDRedEnvelopConfig sharedConfig].delaySeconds = 0;
    }
}

- (void)showBlackList {
    id contactsViewController = [[objc_getClass("MultiSelectContactsViewController") alloc] init];
    [contactsViewController setM_scene:5];
    [contactsViewController setM_delegate:self];
    
    if ([contactsViewController respondsToSelector:@selector(loadViewIfNeeded)]) {
        [contactsViewController loadViewIfNeeded];
    }
    
    MMContext *context = [objc_getClass("MMContext") activeUserContext];
    CContactMgr *contactMgr = [context getService:objc_getClass("CContactMgr")];
    
    id selectView = [contactsViewController valueForKey:@"m_selectView"];
    for (NSString *contactName in [DDRedEnvelopConfig sharedConfig].blackList) {
        CContact *contact = [contactMgr getContactByName:contactName];
        if (contact && [selectView respondsToSelector:@selector(addSelect:)]) {
            [selectView performSelector:@selector(addSelect:) withObject:contact];
        }
    }
    
    if ([contactsViewController respondsToSelector:@selector(updatePanelBtn)]) {
        [contactsViewController updatePanelBtn];
    }
    
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:contactsViewController];
    navigationController.modalPresentationStyle = UIModalPresentationPageSheet;
    
    [self presentViewController:navigationController animated:YES completion:nil];
}

- (void)onMultiSelectContactReturn:(NSArray *)arg1 {
    NSMutableArray *blackList = [NSMutableArray new];
    for (id contact in arg1) {
        if ([contact isKindOfClass:objc_getClass("CContact")]) {
            NSString *contactName = [contact m_nsUsrName];
            if ([contactName length] > 0 && [contactName hasSuffix:@"@chatroom"]) {
                [blackList addObject:contactName];
            }
        }
    }
    [DDRedEnvelopConfig sharedConfig].blackList = blackList;
    [self.tableView reloadData];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField == self.delaySecondsField) {
        [self saveDelaySecondsValue];
    }
}

- (void)keyboardWillShow:(NSNotification *)notification {
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = keyboardFrame.size.height;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0, 0, keyboardHeight, 0);
    self.tableView.contentInset = contentInsets;
    self.tableView.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.tableView.contentInset = contentInsets;
    self.tableView.scrollIndicatorInsets = contentInsets;
}

@end

#pragma mark - Hook逻辑

%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(HongBaoRes *)arg1 Request:(HongBaoReq *)arg2 {
    %orig;
    
    // 红包通知处理 - 修改为显示总金额
    if ([DDRedEnvelopConfig sharedConfig].showNotification && [arg1 isKindOfClass:objc_getClass("HongBaoRes")]) {
        HongBaoRes *hongbaores = (HongBaoRes *)arg1;
        SKBuiltinBuffer_t *buffer = [hongbaores retText];
        
        if (buffer && buffer.buffer) {
            NSString *jsonstring = [[NSString alloc] initWithData:buffer.buffer encoding:NSUTF8StringEncoding];
            NSDictionary *dic = [jsonstring dd_JSONDictionary];
            
            if (dic) {
                // 获取金额信息 - 使用正确的totalAmount键名
                NSInteger amount = [[dic objectForKey:@"amount"] integerValue];
                NSInteger totalAmount = [[dic objectForKey:@"totalAmount"] integerValue]; // 修改为正确的totalAmount键名
                
                if (amount > 0) {
                    // 显示通知，包含总金额信息
                    [[DDNotificationManager sharedManager] showLocalNotificationWithAmount:amount totalAmount:totalAmount];
                }
            }
        }
    }
    
    // 队列处理逻辑
    if (arg1.cgiCmdid != 3) return;
    
    NSString *(^parseRequestSign)(void) = ^NSString * {
        NSString *requestString = [[NSString alloc] initWithData:arg2.reqText.buffer encoding:NSUTF8StringEncoding];
        NSDictionary *requestDictionary = [%c(WCBizUtil) dictionaryWithDecodedComponets:requestString separator:@"&"];
        
        NSString *nativeUrl = [requestDictionary dd_stringForKey:@"nativeUrl"];
        if (!nativeUrl) return nil;
        
        nativeUrl = [nativeUrl stringByRemovingPercentEncoding];
        NSDictionary *nativeUrlDict = [%c(WCBizUtil) dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
        
        return [nativeUrlDict dd_stringForKey:@"sign"];
    };
    
    NSString *responseString = [[NSString alloc] initWithData:arg1.retText.buffer encoding:NSUTF8StringEncoding];
    NSDictionary *responseDict = [responseString dd_JSONDictionary];
    
    DDWeChatRedEnvelopParam *mgrParams = [[DDRedEnvelopParamQueue sharedQueue] dequeue];
    
    BOOL (^shouldReceiveRedEnvelop)(void) = ^BOOL {
        if (!mgrParams) return NO;
        if ([responseDict[@"receiveStatus"] integerValue] == 2) return NO;
        if ([responseDict[@"hbStatus"] integerValue] == 4) return NO;
        if (!responseDict[@"timingIdentifier"]) return NO;
        
        DDRedEnvelopConfig *config = [DDRedEnvelopConfig sharedConfig];
        if (!config.autoReceiveEnable) return NO;
        
        if (mgrParams.isGroupSender) return YES;
        
        NSString *sign = parseRequestSign();
        return [sign isEqualToString:mgrParams.sign];
    };
    
    if (shouldReceiveRedEnvelop()) {
        mgrParams.timingIdentifier = responseDict[@"timingIdentifier"];
        
        DDRedEnvelopConfig *config = [DDRedEnvelopConfig sharedConfig];
        NSInteger configDelaySeconds = config.delaySeconds;
        BOOL serialReceive = config.serialReceive;
        
        unsigned int delaySeconds = serialReceive ? 
            ([DDTaskManager sharedManager].serialQueueIsEmpty ? (unsigned int)configDelaySeconds : 2) :
            (unsigned int)configDelaySeconds;
        
        DDReceiveRedEnvelopOperation *operation = [[DDReceiveRedEnvelopOperation alloc] 
            initWithRedEnvelopParam:mgrParams 
            delay:delaySeconds];
        
        if (serialReceive) {
            [[DDTaskManager sharedManager] addSerialTask:operation];
        } else {
            [[DDTaskManager sharedManager] addNormalTask:operation];
        }
    }
}

%end

%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap {
    %orig;
    
    if (wrap.m_uiMessageType != 49) return;
    
    BOOL (^isRedEnvelopMessage)(void) = ^BOOL {
        return [wrap.m_nsContent rangeOfString:@"wxpay://"].location != NSNotFound;
    };
    
    if (!isRedEnvelopMessage()) return;
    
    MMContext *context = [%c(MMContext) activeUserContext];
    CContactMgr *contactManager = [context getService:[%c(CContactMgr) class]];
    CContact *selfContact = [contactManager getSelfContact];
    
    BOOL (^isSender)(void) = ^BOOL {
        return [wrap.m_nsFromUsr isEqualToString:selfContact.m_nsUsrName];
    };
    
    BOOL (^isGroupReceiver)(void) = ^BOOL {
        return [wrap.m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound;
    };
    
    BOOL (^isGroupSender)(void) = ^BOOL {
        return isSender() && [wrap.m_nsToUsr rangeOfString:@"chatroom"].location != NSNotFound;
    };
    
    DDRedEnvelopConfig *config = [DDRedEnvelopConfig sharedConfig];
    
    BOOL (^isGroupInBlackList)(void) = ^BOOL {
        NSArray *blackList = config.blackList;
        return [blackList isKindOfClass:[NSArray class]] && [blackList containsObject:wrap.m_nsFromUsr];
    };
    
    BOOL (^shouldReceiveRedEnvelop)(void) = ^BOOL {
        if (!config.autoReceiveEnable) return NO;
        if (isGroupInBlackList()) return NO;
        return isGroupReceiver() || (isGroupSender() && config.receiveSelfRedEnvelop);
    };
    
    NSDictionary *(^parseNativeUrl)(NSString *nativeUrl) = ^(NSString *nativeUrl) {
        nativeUrl = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
        return [%c(WCBizUtil) dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
    };
    
    void (^queryRedEnvelopesReqeust)(NSDictionary *nativeUrlDict) = ^(NSDictionary *nativeUrlDict) {
        NSMutableDictionary *params = [@{} mutableCopy];
        params[@"agreeDuty"] = @"0";
        params[@"channelId"] = [nativeUrlDict dd_stringForKey:@"channelid"] ?: @"";
        params[@"inWay"] = @"0";
        params[@"msgType"] = [nativeUrlDict dd_stringForKey:@"msgtype"] ?: @"";
        params[@"nativeUrl"] = [[wrap m_oWCPayInfoItem] m_c2cNativeUrl];
        params[@"sendId"] = [nativeUrlDict dd_stringForKey:@"sendid"] ?: @"";
        
        MMContext *context = [objc_getClass("MMContext") activeUserContext];
        WCRedEnvelopesLogicMgr *logicMgr = [context getService:objc_getClass("WCRedEnvelopesLogicMgr")];
        [logicMgr ReceiverQueryRedEnvelopesRequest:params];
    };
    
    void (^enqueueParam)(NSDictionary *nativeUrlDict) = ^(NSDictionary *nativeUrlDict) {
        DDWeChatRedEnvelopParam *mgrParams = [[DDWeChatRedEnvelopParam alloc] init];
        mgrParams.msgType = [nativeUrlDict dd_stringForKey:@"msgtype"];
        mgrParams.sendId = [nativeUrlDict dd_stringForKey:@"sendid"];
        mgrParams.channelId = [nativeUrlDict dd_stringForKey:@"channelid"];
        mgrParams.nickName = [selfContact getContactDisplayName];
        mgrParams.headImg = [selfContact m_nsHeadImgUrl];
        mgrParams.nativeUrl = [[wrap m_oWCPayInfoItem] m_c2cNativeUrl];
        mgrParams.sessionUserName = isGroupSender() ? wrap.m_nsToUsr : wrap.m_nsFromUsr;
        mgrParams.sign = [nativeUrlDict dd_stringForKey:@"sign"];
        mgrParams.isGroupSender = isGroupSender();
        
        [[DDRedEnvelopParamQueue sharedQueue] enqueue:mgrParams];
    };
    
    if (shouldReceiveRedEnvelop()) {
        NSString *nativeUrl = [[wrap m_oWCPayInfoItem] m_c2cNativeUrl];
        NSDictionary *nativeUrlDict = parseNativeUrl(nativeUrl);
        
        queryRedEnvelopesReqeust(nativeUrlDict);
        enqueueParam(nativeUrlDict);
    }
}

%end

#pragma mark - 插件注册

%ctor {
    @autoreleasepool {
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD红包" 
                version:@"1.0.0" 
                controller:@"DDRedEnvelopMainViewController"];
        }
    }
}