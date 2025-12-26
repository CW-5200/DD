//
//  DD红包
//  版本：1.0.0
//  功能：自动抢红包插件
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// MARK: - 配置管理类

@interface WCPLRedEnvelopConfig : NSObject

@property (nonatomic, assign) BOOL autoReceiveEnable;      // 自动抢红包开关
@property (nonatomic, assign) BOOL personalRedEnvelopEnable; // 个人红包开关
@property (nonatomic, assign) BOOL receiveSelfRedEnvelop;  // 抢自己发的红包
@property (nonatomic, assign) BOOL serialReceive;          // 串行抢红包
@property (nonatomic, assign) NSInteger delaySeconds;      // 延迟秒数
@property (nonatomic, strong) NSArray<NSString *> *blackList; // 群聊黑名单

+ (instancetype)sharedConfig;
- (void)saveConfig;

@end

@implementation WCPLRedEnvelopConfig

+ (instancetype)sharedConfig {
    static WCPLRedEnvelopConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[WCPLRedEnvelopConfig alloc] init];
    });
    return config;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        // 默认配置
        _autoReceiveEnable = YES;
        _personalRedEnvelopEnable = YES;
        _receiveSelfRedEnvelop = NO;
        _serialReceive = NO;
        _delaySeconds = 0;
        _blackList = @[];
        
        // 从UserDefaults加载配置
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        _autoReceiveEnable = [defaults boolForKey:@"DDHB_autoReceiveEnable"] ?: YES;
        _personalRedEnvelopEnable = [defaults boolForKey:@"DDHB_personalRedEnvelopEnable"] ?: YES;
        _receiveSelfRedEnvelop = [defaults boolForKey:@"DDHB_receiveSelfRedEnvelop"] ?: NO;
        _serialReceive = [defaults boolForKey:@"DDHB_serialReceive"] ?: NO;
        _delaySeconds = [defaults integerForKey:@"DDHB_delaySeconds"] ?: 0;
        _blackList = [defaults arrayForKey:@"DDHB_blackList"] ?: @[];
    }
    return self;
}

- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:_autoReceiveEnable forKey:@"DDHB_autoReceiveEnable"];
    [defaults setBool:_personalRedEnvelopEnable forKey:@"DDHB_personalRedEnvelopEnable"];
    [defaults setBool:_receiveSelfRedEnvelop forKey:@"DDHB_receiveSelfRedEnvelop"];
    [defaults setBool:_serialReceive forKey:@"DDHB_serialReceive"];
    [defaults setInteger:_delaySeconds forKey:@"DDHB_delaySeconds"];
    [defaults setObject:_blackList forKey:@"DDHB_blackList"];
    [defaults synchronize];
}

@end

// MARK: - 红包参数模型

@interface WeChatRedEnvelopParam : NSObject

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

@implementation WeChatRedEnvelopParam

@end

// MARK: - 红包参数队列

@interface WCPLRedEnvelopParamQueue : NSObject

@property (nonatomic, strong) NSMutableArray<WeChatRedEnvelopParam *> *queue;

+ (instancetype)sharedQueue;
- (void)enqueue:(WeChatRedEnvelopParam *)param;
- (WeChatRedEnvelopParam *)dequeue;
- (WeChatRedEnvelopParam *)peek;
- (BOOL)isEmpty;

@end

@implementation WCPLRedEnvelopParamQueue

+ (instancetype)sharedQueue {
    static WCPLRedEnvelopParamQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[WCPLRedEnvelopParamQueue alloc] init];
    });
    return queue;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)enqueue:(WeChatRedEnvelopParam *)param {
    [_queue addObject:param];
}

- (WeChatRedEnvelopParam *)dequeue {
    if ([self isEmpty]) {
        return nil;
    }
    WeChatRedEnvelopParam *first = _queue.firstObject;
    [_queue removeObjectAtIndex:0];
    return first;
}

- (WeChatRedEnvelopParam *)peek {
    if ([self isEmpty]) {
        return nil;
    }
    return _queue.firstObject;
}

- (BOOL)isEmpty {
    return _queue.count == 0;
}

@end

// MARK: - 任务管理器

@interface WCPLRedEnvelopTaskManager : NSObject

@property (nonatomic, strong) NSOperationQueue *serialQueue;
@property (nonatomic, strong) NSOperationQueue *normalQueue;
@property (nonatomic, assign) BOOL serialQueueIsEmpty;

+ (instancetype)sharedManager;
- (void)addSerialTask:(NSOperation *)task;
- (void)addNormalTask:(NSOperation *)task;

@end

@implementation WCPLRedEnvelopTaskManager

+ (instancetype)sharedManager {
    static WCPLRedEnvelopTaskManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[WCPLRedEnvelopTaskManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _serialQueue = [[NSOperationQueue alloc] init];
        _serialQueue.maxConcurrentOperationCount = 1;
        _serialQueueIsEmpty = YES;
        
        _normalQueue = [[NSOperationQueue alloc] init];
        _normalQueue.maxConcurrentOperationCount = 5;
        
        // 监听串行队列状态
        [_serialQueue addObserver:self forKeyPath:@"operationCount" options:NSKeyValueObservingOptionNew context:nil];
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"operationCount"]) {
        _serialQueueIsEmpty = (_serialQueue.operationCount == 0);
    }
}

- (void)addSerialTask:(NSOperation *)task {
    [_serialQueue addOperation:task];
}

- (void)addNormalTask:(NSOperation *)task {
    [_normalQueue addOperation:task];
}

- (void)dealloc {
    [_serialQueue removeObserver:self forKeyPath:@"operationCount"];
}

@end

// MARK: - 抢红包操作

@interface WCPLReceiveRedEnvelopOperation : NSOperation

@property (nonatomic, strong) WeChatRedEnvelopParam *redEnvelopParam;
@property (nonatomic, assign) unsigned int delaySeconds;
@property (nonatomic, copy) void (^completionBlock)(BOOL success);

- (instancetype)initWithRedEnvelopParam:(WeChatRedEnvelopParam *)param delay:(unsigned int)delay;

@end

@implementation WCPLReceiveRedEnvelopOperation {
    BOOL _isExecuting;
    BOOL _isFinished;
}

- (instancetype)initWithRedEnvelopParam:(WeChatRedEnvelopParam *)param delay:(unsigned int)delay {
    self = [super init];
    if (self) {
        _redEnvelopParam = param;
        _delaySeconds = delay;
        _isExecuting = NO;
        _isFinished = NO;
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
    
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_delaySeconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf.isCancelled) {
            [strongSelf receiveRedEnvelop];
        }
        [strongSelf finishOperation];
    });
}

- (void)receiveRedEnvelop {
    // 这里应该调用微信的抢红包方法
    // 由于我们无法直接调用，这里只是一个示例
    NSLog(@"DD红包: 正在抢红包 - sendId: %@", _redEnvelopParam.sendId);
    
    // 模拟抢红包成功
    if (_completionBlock) {
        _completionBlock(YES);
    }
}

- (void)finishOperation {
    [self willChangeValueForKey:@"isExecuting"];
    [self willChangeValueForKey:@"isFinished"];
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

// MARK: - Hook类和方法

// 辅助方法
@interface WCBizUtil : NSObject
+ (NSDictionary *)dictionaryWithDecodedComponets:(NSString *)encodedString separator:(NSString *)separator;
@end

// 微信内部类，我们需要Hook的
@class HongBaoRes, HongBaoReq;
@class CMessageWrap;

// MARK: - Hook WCRedEnvelopesLogicMgr

__attribute__((constructor))
static void initializeDDHongBao() {
    @autoreleasepool {
        // 检查插件管理器是否存在
        if (NSClassFromString(@"WCPluginsMgr")) {
            // 注册插件到微信插件管理器
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD红包" 
                                                                               version:@"1.0.0" 
                                                                            controller:@"DDHongBaoSettingsViewController"];
        }
    }
}

// Hook WCRedEnvelopesLogicMgr 类
@interface WCRedEnvelopesLogicMgr (DDHongBao)
- (void)DD_OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2;
- (unsigned int)DD_wcpl_calculateDelaySeconds;
@end

@implementation WCRedEnvelopesLogicMgr (DDHongBao)

- (void)DD_OnWCToHongbaoCommonResponse:(HongBaoRes *)arg1 Request:(HongBaoReq *)arg2 {
    // 调用原始方法
    [self DD_OnWCToHongbaoCommonResponse:arg1 Request:arg2];
    
    // 非参数查询请求
    if ([arg1 cgiCmdid] != 3) { 
        return; 
    }
    
    // 解析请求签名
    NSString *(^parseRequestSign)(void) = ^NSString *() {
        NSString *requestString = [[NSString alloc] initWithData:[arg2 reqText].buffer encoding:NSUTF8StringEncoding];
        NSDictionary *requestDictionary = [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:requestString separator:@"&"];
        NSString *nativeUrl = [[requestDictionary objectForKey:@"nativeUrl"] stringByRemovingPercentEncoding];
        NSDictionary *nativeUrlDict = [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
        
        return [nativeUrlDict objectForKey:@"sign"];
    };
    
    // 解析响应
    NSDictionary *responseDict = nil;
    @try {
        NSString *responseString = [[NSString alloc] initWithData:[arg1 retText].buffer encoding:NSUTF8StringEncoding];
        responseDict = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] 
                                                       options:0 
                                                         error:nil];
    } @catch (NSException *exception) {
        return;
    }
    
    WeChatRedEnvelopParam *mgrParams = [[WCPLRedEnvelopParamQueue sharedQueue] dequeue];
    
    BOOL (^shouldReceiveRedEnvelop)(void) = ^BOOL() {
        // 手动抢红包
        if (!mgrParams) { 
            return NO; 
        }
        
        // 自己已经抢过
        if ([responseDict[@"receiveStatus"] integerValue] == 2) { 
            return NO; 
        }
        
        // 红包被抢完
        if ([responseDict[@"hbStatus"] integerValue] == 4) { 
            return NO; 
        }  
        
        // 没有这个字段会被判定为使用外挂
        if (!responseDict[@"timingIdentifier"]) { 
            return NO; 
        }  
        
        if (mgrParams.isGroupSender) { 
            // 自己发红包的时候没有 sign 字段
            return [WCPLRedEnvelopConfig sharedConfig].autoReceiveEnable;
        } else {
            NSString *requestSign = parseRequestSign();
            return [requestSign isEqualToString:mgrParams.sign] && [WCPLRedEnvelopConfig sharedConfig].autoReceiveEnable;
        }
    };
    
    if (shouldReceiveRedEnvelop()) {
        mgrParams.timingIdentifier = responseDict[@"timingIdentifier"];
        
        unsigned int delaySeconds = [self DD_wcpl_calculateDelaySeconds];
        WCPLReceiveRedEnvelopOperation *operation = [[WCPLReceiveRedEnvelopOperation alloc] initWithRedEnvelopParam:mgrParams delay:delaySeconds];
        
        if ([WCPLRedEnvelopConfig sharedConfig].serialReceive) {
            [[WCPLRedEnvelopTaskManager sharedManager] addSerialTask:operation];
        } else {
            [[WCPLRedEnvelopTaskManager sharedManager] addNormalTask:operation];
        }
    }
}

- (unsigned int)DD_wcpl_calculateDelaySeconds {
    NSInteger configDelaySeconds = [WCPLRedEnvelopConfig sharedConfig].delaySeconds;
    
    if ([WCPLRedEnvelopConfig sharedConfig].serialReceive) {
        unsigned int serialDelaySeconds;
        if ([WCPLRedEnvelopTaskManager sharedManager].serialQueueIsEmpty) {
            serialDelaySeconds = (unsigned int)configDelaySeconds;
        } else {
            serialDelaySeconds = 5;
        }
        
        return serialDelaySeconds;
    } else {
        return (unsigned int)configDelaySeconds;
    }
}

@end

// MARK: - Hook CMessageMgr

@interface CMessageMgr (DDHongBao)
- (void)DD_AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap;
@end

@implementation CMessageMgr (DDHongBao)

- (void)DD_AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap {
    // 调用原始方法
    [self DD_AsyncOnAddMsg:msg MsgWrap:wrap];
    
    switch(wrap.m_uiMessageType) {
        case 49: { // AppNode
            /** 是否为红包消息 */
            BOOL (^isRedEnvelopMessage)(void) = ^BOOL() {
                return [wrap.m_nsContent rangeOfString:@"wxpay://"].location != NSNotFound;
            };
            
            if (isRedEnvelopMessage()) { // 红包
                // 获取联系人管理器
                Class contactMgrClass = objc_getClass("CContactMgr");
                Class serviceCenterClass = objc_getClass("MMServiceCenter");
                id contactManager = [[serviceCenterClass defaultCenter] getService:contactMgrClass];
                id selfContact = [contactManager getSelfContact];
                
                BOOL (^isSender)(void) = ^BOOL() {
                    return [wrap.m_nsFromUsr isEqualToString:[selfContact m_nsUsrName]];
                };
                
                /** 是否别人在群聊中发消息 */
                BOOL (^isGroupReceiver)(void) = ^BOOL() {
                    return [wrap.m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound;
                };
                
                /** 是否自己在群聊中发消息 */
                BOOL (^isGroupSender)(void) = ^BOOL() {
                    return isSender() && [wrap.m_nsToUsr rangeOfString:@"chatroom"].location != NSNotFound;
                };
                
                /** 是否抢自己发的红包 */
                BOOL (^isReceiveSelfRedEnvelop)(void) = ^BOOL() {
                    return [WCPLRedEnvelopConfig sharedConfig].receiveSelfRedEnvelop;
                };
                
                /** 是否在黑名单中 */
                BOOL (^isGroupInBlackList)(void) = ^BOOL() {
                    return [[WCPLRedEnvelopConfig sharedConfig].blackList containsObject:wrap.m_nsFromUsr];
                };
                
                /** 是否自动抢红包 */
                BOOL (^shouldReceiveRedEnvelop)(void) = ^BOOL() {
                    if (![WCPLRedEnvelopConfig sharedConfig].autoReceiveEnable) { 
                        return NO; 
                    }
                    if (isGroupInBlackList()) { 
                        return NO; 
                    }
                    
                    return isGroupReceiver() || 
                           (isGroupSender() && isReceiveSelfRedEnvelop()) || 
                           (!isGroupReceiver() && !isGroupSender() && [WCPLRedEnvelopConfig sharedConfig].personalRedEnvelopEnable); 
                };
                
                if (shouldReceiveRedEnvelop()) {
                    // 解析红包参数
                    NSDictionary *(^parseNativeUrl)(NSString *nativeUrl) = ^NSDictionary *(NSString *nativeUrl) {
                        nativeUrl = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
                        return [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
                    };
                    
                    // 从消息内容中提取红包参数
                    NSString *content = wrap.m_nsContent;
                    NSRange startRange = [content rangeOfString:@"<url>"];
                    NSRange endRange = [content rangeOfString:@"</url>"];
                    
                    if (startRange.location != NSNotFound && endRange.location != NSNotFound) {
                        NSString *url = [content substringWithRange:NSMakeRange(startRange.location + startRange.length, 
                                                                               endRange.location - startRange.location - startRange.length)];
                        NSDictionary *nativeUrlDict = parseNativeUrl(url);
                        
                        WeChatRedEnvelopParam *param = [[WeChatRedEnvelopParam alloc] init];
                        param.msgType = nativeUrlDict[@"msgtype"];
                        param.sendId = nativeUrlDict[@"sendid"];
                        param.channelId = nativeUrlDict[@"channelid"];
                        param.nickName = nativeUrlDict[@"nick_name"];
                        param.headImg = nativeUrlDict[@"head_img"];
                        param.nativeUrl = url;
                        param.sessionUserName = isGroupSender() ? wrap.m_nsToUsr : wrap.m_nsFromUsr;
                        param.sign = nativeUrlDict[@"sign"];
                        param.isGroupSender = isGroupSender();
                        
                        [[WCPLRedEnvelopParamQueue sharedQueue] enqueue:param];
                    }
                }
            }
            break;
        }
    }
}

@end

// MARK: - 设置界面

@interface DDHongBaoSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *settings;

@end

@implementation DDHongBaoSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"DD红包设置";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    // 创建表视图
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
    
    // 注册单元格
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
    [self.tableView registerClass:[UITableViewHeaderFooterView class] forHeaderFooterViewReuseIdentifier:@"Header"];
    
    // 加载设置项
    [self loadSettings];
}

- (void)loadSettings {
    self.settings = @[
        @{
            @"title": @"基本设置",
            @"items": @[
                @{
                    @"type": @"switch",
                    @"title": @"自动抢红包",
                    @"key": @"autoReceiveEnable",
                    @"default": @YES
                },
                @{
                    @"type": @"switch",
                    @"title": @"抢个人红包",
                    @"key": @"personalRedEnvelopEnable",
                    @"default": @YES
                },
                @{
                    @"type": @"switch",
                    @"title": @"抢自己发的红包",
                    @"key": @"receiveSelfRedEnvelop",
                    @"default": @NO
                }
            ]
        },
        @{
            @"title": @"高级设置",
            @"items": @[
                @{
                    @"type": @"switch",
                    @"title": @"串行抢红包",
                    @"key": @"serialReceive",
                    @"default": @NO,
                    @"detail": @"按顺序一个个抢，避免过快"
                },
                @{
                    @"type": @"stepper",
                    @"title": @"延迟时间",
                    @"key": @"delaySeconds",
                    @"min": @0,
                    @"max": @10,
                    @"step": @1,
                    @"unit": @"秒",
                    @"default": @0
                }
            ]
        },
        @{
            @"title": @"黑名单",
            @"items": @[
                @{
                    @"type": @"button",
                    @"title": @"管理黑名单",
                    @"action": @"showBlackList"
                }
            ]
        }
    ];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.settings.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *sectionDict = self.settings[section];
    NSArray *items = sectionDict[@"items"];
    return items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    NSDictionary *sectionDict = self.settings[indexPath.section];
    NSArray *items = sectionDict[@"items"];
    NSDictionary *item = items[indexPath.row];
    NSString *type = item[@"type"];
    NSString *title = item[@"title"];
    
    cell.textLabel.text = title;
    
    // 清除所有子视图
    for (UIView *subview in cell.contentView.subviews) {
        [subview removeFromSuperview];
    }
    
    // 根据类型创建不同的UI
    if ([type isEqualToString:@"switch"]) {
        UISwitch *switchView = [[UISwitch alloc] init];
        NSString *key = item[@"key"];
        BOOL defaultValue = [item[@"default"] boolValue];
        
        // 加载当前值
        WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
        BOOL currentValue = [[config valueForKey:key] boolValue];
        switchView.on = currentValue;
        
        [switchView addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
        switchView.tag = indexPath.section * 100 + indexPath.row;
        
        cell.accessoryView = switchView;
        
        // 添加详细描述
        if (item[@"detail"]) {
            cell.detailTextLabel.text = item[@"detail"];
        }
    } 
    else if ([type isEqualToString:@"stepper"]) {
        // 创建stepper
        UIStepper *stepper = [[UIStepper alloc] init];
        stepper.minimumValue = [item[@"min"] doubleValue];
        stepper.maximumValue = [item[@"max"] doubleValue];
        stepper.stepValue = [item[@"step"] doubleValue];
        
        NSString *key = item[@"key"];
        NSInteger defaultValue = [item[@"default"] integerValue];
        
        // 加载当前值
        WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
        NSInteger currentValue = [[config valueForKey:key] integerValue];
        stepper.value = currentValue;
        
        [stepper addTarget:self action:@selector(stepperValueChanged:) forControlEvents:UIControlEventValueChanged];
        stepper.tag = indexPath.section * 100 + indexPath.row;
        
        // 创建标签显示当前值
        UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 30)];
        valueLabel.textAlignment = NSTextAlignmentRight;
        valueLabel.text = [NSString stringWithFormat:@"%ld%@", (long)currentValue, item[@"unit"] ?: @""];
        valueLabel.tag = 999;
        
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 120, 30)];
        [container addSubview:stepper];
        [container addSubview:valueLabel];
        
        stepper.frame = CGRectMake(0, 0, 94, 30);
        valueLabel.frame = CGRectMake(100, 0, 60, 30);
        
        cell.accessoryView = container;
    }
    else if ([type isEqualToString:@"button"]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *sectionDict = self.settings[indexPath.section];
    NSArray *items = sectionDict[@"items"];
    NSDictionary *item = items[indexPath.row];
    NSString *type = item[@"type"];
    
    if ([type isEqualToString:@"button"]) {
        NSString *action = item[@"action"];
        if ([action isEqualToString:@"showBlackList"]) {
            [self showBlackList];
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSDictionary *sectionDict = self.settings[section];
    return sectionDict[@"title"];
}

#pragma mark - 事件处理

- (void)switchValueChanged:(UISwitch *)sender {
    NSInteger section = sender.tag / 100;
    NSInteger row = sender.tag % 100;
    
    NSDictionary *sectionDict = self.settings[section];
    NSArray *items = sectionDict[@"items"];
    NSDictionary *item = items[row];
    NSString *key = item[@"key"];
    
    // 更新配置
    WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
    [config setValue:@(sender.on) forKey:key];
    [config saveConfig];
}

- (void)stepperValueChanged:(UIStepper *)sender {
    NSInteger section = sender.tag / 100;
    NSInteger row = sender.tag % 100;
    
    NSDictionary *sectionDict = self.settings[section];
    NSArray *items = sectionDict[@"items"];
    NSDictionary *item = items[row];
    NSString *key = item[@"key"];
    
    // 更新标签显示
    UIView *container = sender.superview;
    UILabel *valueLabel = [container viewWithTag:999];
    valueLabel.text = [NSString stringWithFormat:@"%ld%@", (long)sender.value, item[@"unit"] ?: @""];
    
    // 更新配置
    WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
    [config setValue:@((NSInteger)sender.value) forKey:key];
    [config saveConfig];
}

- (void)showBlackList {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"黑名单管理" 
                                                                   message:@"输入群聊ID（如：xxx@chatroom）" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"群聊ID";
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"添加" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *groupId = alert.textFields.firstObject.text;
        if (groupId.length > 0) {
            WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
            NSMutableArray *newList = [config.blackList mutableCopy];
            if (![newList containsObject:groupId]) {
                [newList addObject:groupId];
                config.blackList = [newList copy];
                [config saveConfig];
                
                // 显示成功提示
                [self showToast:@"已添加到黑名单"];
            }
        }
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"查看列表" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self showBlackListDetails];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showBlackListDetails {
    WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
    
    if (config.blackList.count == 0) {
        [self showToast:@"黑名单为空"];
        return;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"黑名单列表" 
                                                                   message:nil 
                                                            preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (NSString *groupId in config.blackList) {
        [alert addAction:[UIAlertAction actionWithTitle:groupId style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            // 从黑名单中移除
            [self removeFromBlackList:groupId];
        }]];
    }
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)removeFromBlackList:(NSString *)groupId {
    WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
    NSMutableArray *newList = [config.blackList mutableCopy];
    [newList removeObject:groupId];
    config.blackList = [newList copy];
    [config saveConfig];
    
    [self showToast:@"已从黑名单移除"];
}

- (void)showToast:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [alert dismissViewControllerAnimated:YES completion:nil];
        });
    }];
}

@end

// MARK: - Method Swizzling

__attribute__((constructor))
static void swizzleMethods() {
    @autoreleasepool {
        // Hook WCRedEnvelopesLogicMgr 的方法
        Class redEnvelopClass = objc_getClass("WCRedEnvelopesLogicMgr");
        if (redEnvelopClass) {
            Method originalMethod1 = class_getInstanceMethod(redEnvelopClass, 
                                                            @selector(OnWCToHongbaoCommonResponse:Request:));
            Method swizzledMethod1 = class_getInstanceMethod(redEnvelopClass, 
                                                           @selector(DD_OnWCToHongbaoCommonResponse:Request:));
            
            if (originalMethod1 && swizzledMethod1) {
                method_exchangeImplementations(originalMethod1, swizzledMethod1);
            }
        }
        
        // Hook CMessageMgr 的方法
        Class messageMgrClass = objc_getClass("CMessageMgr");
        if (messageMgrClass) {
            Method originalMethod2 = class_getInstanceMethod(messageMgrClass, 
                                                           @selector(AsyncOnAddMsg:MsgWrap:));
            Method swizzledMethod2 = class_getInstanceMethod(messageMgrClass, 
                                                          @selector(DD_AsyncOnAddMsg:MsgWrap:));
            
            if (originalMethod2 && swizzledMethod2) {
                method_exchangeImplementations(originalMethod2, swizzledMethod2);
            }
        }
    }
}