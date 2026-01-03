// DD红包助手.xm
// 自动抢红包、延迟抢红包、抢自己发的红包、防止抢多个红包、群聊过滤
// 支持 iOS 15.0+

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 微信私有类声明

@interface WCBizUtil : NSObject
+ (id)dictionaryWithDecodedComponets:(id)arg1 separator:(id)arg2;
@end

@interface SKBuiltinBuffer_t : NSObject
@property(retain, nonatomic) NSData *buffer;
@end

@interface WCPayInfoItem: NSObject
@property(retain, nonatomic) NSString *m_c2cNativeUrl;
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

@interface WCRedEnvelopesLogicMgr: NSObject
- (void)OpenRedEnvelopesRequest:(id)params;
- (void)ReceiverQueryRedEnvelopesRequest:(id)arg1;
@end

@interface HongBaoRes : NSObject
@property(retain, nonatomic) SKBuiltinBuffer_t *retText;
@property(nonatomic) int cgiCmdid;
@end

@interface HongBaoReq : NSObject
@property(retain, nonatomic) SKBuiltinBuffer_t *reqText;
@end

@interface CContact: NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@property(retain, nonatomic) NSString *m_nsHeadImgUrl;
@property(retain, nonatomic) NSString *m_nsNickName;
- (id)getContactDisplayName;
@end

@interface CContactMgr : NSObject
- (id)getSelfContact;
- (id)getContactForSearchByName:(id)arg1;
- (_Bool)addLocalContact:(id)arg1 listType:(unsigned int)arg2;
- (_Bool)getContactsFromServer:(id)arg1;
@end

@interface WCTableViewManager : NSObject
- (void)clearAllSection;
- (id)getTableView;
- (void)insertSection:(id)arg1 At:(unsigned int)arg2;
- (void)addSection:(id)arg1;
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionInfoDefaut;
+ (id)sectionInfoHeader:(id)arg1;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewCellManager : NSObject
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightValue:(id)arg4 accessoryType:(long long)arg5;
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(_Bool)arg4;
@end

@interface WCTableViewNormalCellManager : NSObject
+ (id)normalCellForTitle:(id)arg1 rightValue:(id)arg2;
@end

@interface MMTableView: UITableView
@end

@interface MMLoadingView : UIView
@property(retain, nonatomic) NSString *text;
@property (assign, nonatomic) BOOL ignoreInteractionEventsWhenLoading;
- (void)startLoading;
- (void)stopLoading;
- (void)stopLoadingAndShowError:(id)arg1;
- (void)stopLoadingAndShowOK:(id)arg1;
@end

@interface MMUINavigationController : UINavigationController
@end

@interface NSDictionary (SafeJSON)
- (id)stringForKey:(id)arg1;
@end

@interface NSString (SBJSON)
- (id)JSONDictionary;
@end

@interface UINavigationController (LogicController)
- (void)PushViewController:(id)arg1 animated:(_Bool)arg2;
@end

@interface NewSettingViewController: UIViewController
- (void)reloadTableData;
@end

@interface MMWebViewController: NSObject
- (id)initWithURL:(id)arg1 presentModal:(_Bool)arg2 extraInfo:(id)arg3;
@end

@interface MultiSelectContactsViewController : UIViewController
@property(nonatomic, weak) id m_delegate;
@end

@protocol MultiSelectContactsViewControllerDelegate <NSObject>
- (void)onMultiSelectContactReturn:(NSArray *)arg1;
@end

#pragma mark - 插件管理接口

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

#pragma mark - 配置管理

@interface DDRedEnvelopConfig : NSObject

+ (instancetype)sharedConfig;

@property (assign, nonatomic) BOOL autoReceiveEnable;
@property (assign, nonatomic) NSInteger delaySeconds;
@property (assign, nonatomic) BOOL receiveSelfRedEnvelop;
@property (assign, nonatomic) BOOL serialReceive;
@property (strong, nonatomic) NSArray *blackList;

@end

static NSString * const kDelaySecondsKey = @"DDDelaySecondsKey";
static NSString * const kAutoReceiveRedEnvelopKey = @"DDAutoReceiveRedEnvelopKey";
static NSString * const kReceiveSelfRedEnvelopKey = @"DDReceiveSelfRedEnvelopKey";
static NSString * const kSerialReceiveKey = @"DDSerialReceiveKey";
static NSString * const kBlackListKey = @"DDBlackListKey";

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

- (void)setBlackList:(NSArray *)blackList {
    _blackList = blackList;
    [[NSUserDefaults standardUserDefaults] setObject:blackList forKey:kBlackListKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

#pragma mark - 红包参数

@interface DDWeChatRedEnvelopParam : NSObject

- (NSDictionary *)toParams;

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

@interface DDSettingViewController : UIViewController <MultiSelectContactsViewControllerDelegate>

@property (nonatomic, strong) WCTableViewManager *tableViewMgr;

@end

@implementation DDSettingViewController

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        _tableViewMgr = [[objc_getClass("WCTableViewManager") alloc] initWithFrame:[UIScreen mainScreen].bounds style:UITableViewStyleGrouped];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initTitle];
    [self reloadTableData];
    
    UITableView *tableView = [_tableViewMgr getTableView];
    tableView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentAutomatic;
    [self.view addSubview:tableView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UITableView *tableView = [_tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
}

- (void)initTitle {
    self.title = @"DD红包助手";
}

- (void)reloadTableData {
    [_tableViewMgr clearAllSection];
    
    [self addBasicSettingSection];
    [self addAdvanceSettingSection];
    
    UITableView *tableView = [_tableViewMgr getTableView];
    [tableView reloadData];
}

#pragma mark - BasicSetting

- (void)addBasicSettingSection {
    WCTableViewSectionManager *sectionInfo = [objc_getClass("WCTableViewSectionManager") sectionInfoDefaut];
    
    [sectionInfo addCell:[self createAutoReceiveRedEnvelopCell]];
    [sectionInfo addCell:[self createDelaySettingCell]];
    
    [_tableViewMgr addSection:sectionInfo];
}

- (WCTableViewCellManager *)createAutoReceiveRedEnvelopCell {
    return [objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(switchRedEnvelop:) target:self 
        title:@"自动抢红包" on:[DDRedEnvelopConfig sharedConfig].autoReceiveEnable];
}

- (WCTableViewNormalCellManager *)createDelaySettingCell {
    NSInteger delaySeconds = [DDRedEnvelopConfig sharedConfig].delaySeconds;
    NSString *delayString = delaySeconds == 0 ? @"不延迟" : [NSString stringWithFormat:@"%ld 秒", (long)delaySeconds];
    
    if ([DDRedEnvelopConfig sharedConfig].autoReceiveEnable) {
        return [objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(settingDelay) target:self 
            title:@"延迟抢红包" rightValue:delayString accessoryType:1];
    } else {
        return [objc_getClass("WCTableViewNormalCellManager") normalCellForTitle:@"延迟抢红包" rightValue:@"抢红包已关闭"];
    }
}

- (void)switchRedEnvelop:(UISwitch *)envelopSwitch {
    [DDRedEnvelopConfig sharedConfig].autoReceiveEnable = envelopSwitch.on;
    [self reloadTableData];
}

- (void)settingDelay {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"延迟抢红包(秒)" 
                                                                   message:nil 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    alert.alertViewStyle = UIAlertControllerStyleAlert;
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"延迟时长";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%ld", (long)[DDRedEnvelopConfig sharedConfig].delaySeconds];
    }];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" 
                                                           style:UIAlertActionStyleCancel 
                                                         handler:nil];
    
    UIAlertAction *confirmAction = [UIAlertAction actionWithTitle:@"确定" 
                                                            style:UIAlertActionStyleDefault 
                                                          handler:^(UIAlertAction *action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *delaySecondsString = textField.text;
        NSInteger delaySeconds = [delaySecondsString integerValue];
        [DDRedEnvelopConfig sharedConfig].delaySeconds = delaySeconds;
        [self reloadTableData];
    }];
    
    [alert addAction:cancelAction];
    [alert addAction:confirmAction];
    
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - ProSetting

- (void)addAdvanceSettingSection {
    WCTableViewSectionManager *sectionInfo = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:@"高级功能"];
    
    [sectionInfo addCell:[self createReceiveSelfRedEnvelopCell]];
    [sectionInfo addCell:[self createQueueCell]];
    [sectionInfo addCell:[self createBlackListCell]];
    
    [_tableViewMgr addSection:sectionInfo];
}

- (WCTableViewCellManager *)createReceiveSelfRedEnvelopCell {
    return [objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(settingReceiveSelfRedEnvelop:) target:self 
        title:@"抢自己发的红包" on:[DDRedEnvelopConfig sharedConfig].receiveSelfRedEnvelop];
}

- (WCTableViewCellManager *)createQueueCell {
    return [objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(settingReceiveByQueue:) target:self 
        title:@"防止同时抢多个红包" on:[DDRedEnvelopConfig sharedConfig].serialReceive];
}

- (WCTableViewNormalCellManager *)createBlackListCell {
    if ([DDRedEnvelopConfig sharedConfig].blackList.count == 0) {
        return [objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(showBlackList) target:self 
            title:@"群聊过滤" rightValue:@"已关闭" accessoryType:1];
    } else {
        NSString *blackListCountStr = [NSString stringWithFormat:@"已选 %lu 个群", (unsigned long)[DDRedEnvelopConfig sharedConfig].blackList.count];
        return [objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(showBlackList) target:self 
            title:@"群聊过滤" rightValue:blackListCountStr accessoryType:1];
    }
}

- (void)settingReceiveSelfRedEnvelop:(UISwitch *)receiveSwitch {
    [DDRedEnvelopConfig sharedConfig].receiveSelfRedEnvelop = receiveSwitch.on;
}

- (void)settingReceiveByQueue:(UISwitch *)queueSwitch {
    [DDRedEnvelopConfig sharedConfig].serialReceive = queueSwitch.on;
}

- (void)showBlackList {
    MultiSelectContactsViewController *contactsViewController = [[objc_getClass("MultiSelectContactsViewController") alloc] init];
    contactsViewController.m_delegate = self;
    
    MMUINavigationController *navigationController = [[objc_getClass("MMUINavigationController") alloc] initWithRootViewController:contactsViewController];
    [self presentViewController:navigationController animated:YES completion:nil];
}

#pragma mark - MultiSelectContactsViewControllerDelegate

- (void)onMultiSelectContactReturn:(NSArray *)arg1 {
    NSMutableArray *blackList = [NSMutableArray new];
    for (CContact *contact in arg1) {
        NSString *contactName = contact.m_nsUsrName;
        if ([contactName length] > 0 && [contactName hasSuffix:@"@chatroom"]) {
            [blackList addObject:contactName];
        }
    }
    [DDRedEnvelopConfig sharedConfig].blackList = blackList;
    [self reloadTableData];
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - Hook逻辑

%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(HongBaoRes *)arg1 Request:(HongBaoReq *)arg2 {
    %orig;
    
    // 非参数查询请求
    if (arg1.cgiCmdid != 3) { return; }
    
    NSString *(^parseRequestSign)(void) = ^NSString * {
        NSString *requestString = [[NSString alloc] initWithData:arg2.reqText.buffer encoding:NSUTF8StringEncoding];
        NSDictionary *requestDictionary = [%c(WCBizUtil) dictionaryWithDecodedComponets:requestString separator:@"&"];
        NSString *nativeUrl = [[requestDictionary stringForKey:@"nativeUrl"] stringByRemovingPercentEncoding];
        NSDictionary *nativeUrlDict = [%c(WCBizUtil) dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
        return [nativeUrlDict stringForKey:@"sign"];
    };
    
    NSDictionary *responseDict = [[[NSString alloc] initWithData:arg1.retText.buffer encoding:NSUTF8StringEncoding] JSONDictionary];
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
        
        if (mgrParams.isGroupSender) { // 自己发红包的时候没有 sign 字段
            return [DDRedEnvelopConfig sharedConfig].autoReceiveEnable;
        } else {
            return [parseRequestSign() isEqualToString:mgrParams.sign] && [DDRedEnvelopConfig sharedConfig].autoReceiveEnable;
        }
    };
    
    if (shouldReceiveRedEnvelop()) {
        mgrParams.timingIdentifier = responseDict[@"timingIdentifier"];
        
        // 计算延迟秒数
        NSInteger configDelaySeconds = [DDRedEnvelopConfig sharedConfig].delaySeconds;
        unsigned int delaySeconds;
        
        if ([DDRedEnvelopConfig sharedConfig].serialReceive) {
            if ([DDTaskManager sharedManager].serialQueueIsEmpty) {
                delaySeconds = (unsigned int)configDelaySeconds;
            } else {
                delaySeconds = 15;
            }
        } else {
            delaySeconds = (unsigned int)configDelaySeconds;
        }
        
        DDReceiveRedEnvelopOperation *operation = [[DDReceiveRedEnvelopOperation alloc] initWithRedEnvelopParam:mgrParams delay:delaySeconds];
        
        if ([DDRedEnvelopConfig sharedConfig].serialReceive) {
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
    
    switch(wrap.m_uiMessageType) {
        case 49: { // AppNode
            /** 是否为红包消息 */
            BOOL (^isRedEnvelopMessage)(void) = ^BOOL {
                return [wrap.m_nsContent rangeOfString:@"wxpay://"].location != NSNotFound;
            };
            
            if (isRedEnvelopMessage()) { // 红包
                MMContext *context = [%c(MMContext) activeUserContext];
                CContactMgr *contactManager = [context getService:[%c(CContactMgr) class]];
                CContact *selfContact = [contactManager getSelfContact];
                
                BOOL (^isSender)(void) = ^BOOL {
                    return [wrap.m_nsFromUsr isEqualToString:selfContact.m_nsUsrName];
                };
                
                /** 是否别人在群聊中发消息 */
                BOOL (^isGroupReceiver)(void) = ^BOOL {
                    return [wrap.m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound;
                };
                
                /** 是否自己在群聊中发消息 */
                BOOL (^isGroupSender)(void) = ^BOOL {
                    return isSender() && [wrap.m_nsToUsr rangeOfString:@"chatroom"].location != NSNotFound;
                };
                
                /** 是否抢自己发的红包 */
                BOOL (^isReceiveSelfRedEnvelop)(void) = ^BOOL {
                    return [DDRedEnvelopConfig sharedConfig].receiveSelfRedEnvelop;
                };
                
                /** 是否在黑名单中 */
                BOOL (^isGroupInBlackList)(void) = ^BOOL {
                    return [[DDRedEnvelopConfig sharedConfig].blackList containsObject:wrap.m_nsFromUsr];
                };
                
                /** 是否自动抢红包 */
                BOOL (^shouldReceiveRedEnvelop)(void) = ^BOOL {
                    if (![DDRedEnvelopConfig sharedConfig].autoReceiveEnable) { return NO; }
                    if (isGroupInBlackList()) { return NO; }
                    return isGroupReceiver() || (isGroupSender() && isReceiveSelfRedEnvelop());
                };
                
                NSDictionary *(^parseNativeUrl)(NSString *nativeUrl) = ^(NSString *nativeUrl) {
                    nativeUrl = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
                    return [%c(WCBizUtil) dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
                };
                
                /** 获取服务端验证参数 */
                void (^queryRedEnvelopesReqeust)(NSDictionary *nativeUrlDict) = ^(NSDictionary *nativeUrlDict) {
                    NSMutableDictionary *params = [@{} mutableCopy];
                    params[@"agreeDuty"] = @"0";
                    params[@"channelId"] = [nativeUrlDict stringForKey:@"channelid"];
                    params[@"inWay"] = @"0";
                    params[@"msgType"] = [nativeUrlDict stringForKey:@"msgtype"];
                    params[@"nativeUrl"] = [[wrap m_oWCPayInfoItem] m_c2cNativeUrl];
                    params[@"sendId"] = [nativeUrlDict stringForKey:@"sendid"];
                    
                    MMContext *context = [objc_getClass("MMContext") activeUserContext];
                    WCRedEnvelopesLogicMgr *logicMgr = [context getService:objc_getClass("WCRedEnvelopesLogicMgr")];
                    [logicMgr ReceiverQueryRedEnvelopesRequest:params];
                };
                
                /** 储存参数 */
                void (^enqueueParam)(NSDictionary *nativeUrlDict) = ^(NSDictionary *nativeUrlDict) {
                    DDWeChatRedEnvelopParam *mgrParams = [[DDWeChatRedEnvelopParam alloc] init];
                    mgrParams.msgType = [nativeUrlDict stringForKey:@"msgtype"];
                    mgrParams.sendId = [nativeUrlDict stringForKey:@"sendid"];
                    mgrParams.channelId = [nativeUrlDict stringForKey:@"channelid"];
                    mgrParams.nickName = [selfContact getContactDisplayName];
                    mgrParams.headImg = [selfContact m_nsHeadImgUrl];
                    mgrParams.nativeUrl = [[wrap m_oWCPayInfoItem] m_c2cNativeUrl];
                    mgrParams.sessionUserName = isGroupSender() ? wrap.m_nsToUsr : wrap.m_nsFromUsr;
                    mgrParams.sign = [nativeUrlDict stringForKey:@"sign"];
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
            break;
        }
        default:
            break;
    }
}

%end

%hook NewSettingViewController

- (void)reloadTableData {
    %orig;
    
    [self.view layoutIfNeeded];
    
    WCTableViewManager *tableViewMgr = MSHookIvar<id>(self, "m_tableViewMgr");
    WCTableViewSectionManager *sectionInfo = [%c(WCTableViewSectionManager) sectionInfoDefaut];
    
    WCTableViewCellManager *settingCell = [%c(WCTableViewCellManager) normalCellForSel:@selector(openDDSetting) target:self title:@"DD红包助手"];
    [sectionInfo addCell:settingCell];
    
    [tableViewMgr insertSection:sectionInfo At:0];
    
    UITableView *tableView = [tableViewMgr getTableView];
    [tableView reloadData];
}

%new
- (void)openDDSetting {
    DDSettingViewController *settingViewController = [[DDSettingViewController alloc] init];
    [self.navigationController PushViewController:settingViewController animated:YES];
}

%end

#pragma mark - 插件注册

%ctor {
    @autoreleasepool {
        // 注册插件到插件管理器
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD红包助手" 
                version:@"1.0" 
                controller:@"DDSettingViewController"];
        }
        
        NSLog(@"🎉 DD红包助手加载成功!");
    }
}