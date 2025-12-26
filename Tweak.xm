#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 微信类声明
@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)service;
@end

@interface CContactMgr : NSObject
- (id)getSelfContact;
@end

@interface CContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@end

@interface CMessageWrap : NSObject
@property(nonatomic) NSInteger m_uiMessageType;
@property(retain, nonatomic) NSString *m_nsContent;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) NSString *m_nsToUsr;
@end

@interface WCBizUtil : NSObject
+ (NSDictionary *)dictionaryWithDecodedComponets:(NSString *)string separator:(NSString *)separator;
@end

@interface HongBaoRes : NSObject
@property(retain, nonatomic) NSData *retText;
@property(nonatomic) int cgiCmdid;
@end

@interface HongBaoReq : NSObject
@property(retain, nonatomic) NSData *reqText;
@end

#pragma mark - 配置类
@interface WCPLRedEnvelopConfig : NSObject
@property (nonatomic, assign) BOOL autoReceiveEnable;
@property (nonatomic, assign) BOOL personalRedEnvelopEnable;
@property (nonatomic, assign) BOOL receiveSelfRedEnvelop;
@property (nonatomic, assign) BOOL serialReceive;
@property (nonatomic, assign) NSInteger delaySeconds;
@property (nonatomic, strong) NSArray<NSString *> *blackList;
+ (instancetype)sharedConfig;
@end

@implementation WCPLRedEnvelopConfig
+ (instancetype)sharedConfig {
    static WCPLRedEnvelopConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[WCPLRedEnvelopConfig alloc] init];
        config.autoReceiveEnable = YES;
        config.personalRedEnvelopEnable = YES;
        config.receiveSelfRedEnvelop = NO;
        config.serialReceive = NO;
        config.delaySeconds = 0;
        config.blackList = @[];
    });
    return config;
}
@end

#pragma mark - 红包参数模型
@interface WeChatRedEnvelopParam : NSObject
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

@implementation WeChatRedEnvelopParam
@end

#pragma mark - 参数队列
@interface WCPLRedEnvelopParamQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(WeChatRedEnvelopParam *)param;
- (WeChatRedEnvelopParam *)dequeue;
- (BOOL)isEmpty;
@end

@implementation WCPLRedEnvelopParamQueue {
    NSMutableArray<WeChatRedEnvelopParam *> *_queue;
}

+ (instancetype)sharedQueue {
    static WCPLRedEnvelopParamQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[WCPLRedEnvelopParamQueue alloc] init];
    });
    return queue;
}

- (instancetype)init {
    if (self = [super init]) {
        _queue = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)enqueue:(WeChatRedEnvelopParam *)param {
    @synchronized(self) {
        [_queue addObject:param];
    }
}

- (WeChatRedEnvelopParam *)dequeue {
    @synchronized(self) {
        if (_queue.count == 0) {
            return nil;
        }
        WeChatRedEnvelopParam *first = _queue.firstObject;
        [_queue removeObjectAtIndex:0];
        return first;
    }
}

- (BOOL)isEmpty {
    @synchronized(self) {
        return _queue.count == 0;
    }
}
@end

#pragma mark - 任务管理器
@interface WCPLRedEnvelopTaskManager : NSObject
+ (instancetype)sharedManager;
- (void)addSerialTask:(id)task;
- (void)addNormalTask:(id)task;
@property (nonatomic, assign) BOOL serialQueueIsEmpty;
@end

@implementation WCPLRedEnvelopTaskManager {
    NSMutableArray *_serialQueue;
    NSMutableArray *_normalQueue;
}

+ (instancetype)sharedManager {
    static WCPLRedEnvelopTaskManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[WCPLRedEnvelopTaskManager alloc] init];
    });
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        _serialQueue = [[NSMutableArray alloc] init];
        _normalQueue = [[NSMutableArray alloc] init];
        _serialQueueIsEmpty = YES;
    }
    return self;
}

- (void)addSerialTask:(id)task {
    @synchronized(self) {
        [_serialQueue addObject:task];
        _serialQueueIsEmpty = NO;
    }
}

- (void)addNormalTask:(id)task {
    @synchronized(self) {
        [_normalQueue addObject:task];
    }
}
@end

#pragma mark - 抢红包操作
@interface WCPLReceiveRedEnvelopOperation : NSOperation
- (instancetype)initWithRedEnvelopParam:(WeChatRedEnvelopParam *)param delay:(unsigned int)delaySeconds;
@end

@implementation WCPLReceiveRedEnvelopOperation {
    WeChatRedEnvelopParam *_param;
    unsigned int _delaySeconds;
}

- (instancetype)initWithRedEnvelopParam:(WeChatRedEnvelopParam *)param delay:(unsigned int)delaySeconds {
    if (self = [super init]) {
        _param = param;
        _delaySeconds = delaySeconds;
    }
    return self;
}

- (void)main {
    // 模拟抢红包操作
    NSLog(@"DD红包: 开始抢红包，延迟: %u秒", _delaySeconds);
}
@end

#pragma mark - 插件设置界面
@interface DDRedEnvelopSettingsController : UIViewController
@end

@implementation DDRedEnvelopSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD红包设置";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    [self setupUI];
}

- (void)setupUI {
    WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
    
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:scrollView];
    
    UIStackView *stackView = [[UIStackView alloc] initWithFrame:CGRectMake(20, 20, self.view.bounds.size.width - 40, 0)];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 20;
    [scrollView addSubview:stackView];
    
    // 主开关
    [self addSwitchToStack:stackView title:@"自动抢红包" value:config.autoReceiveEnable keyPath:@"autoReceiveEnable"];
    
    // 个人红包开关
    [self addSwitchToStack:stackView title:@"个人红包" value:config.personalRedEnvelopEnable keyPath:@"personalRedEnvelopEnable"];
    
    // 自己发的红包
    [self addSwitchToStack:stackView title:@"抢自己发的红包" value:config.receiveSelfRedEnvelop keyPath:@"receiveSelfRedEnvelop"];
    
    // 串行抢红包
    [self addSwitchToStack:stackView title:@"串行抢红包(防封号)" value:config.serialReceive keyPath:@"serialReceive"];
    
    // 延迟设置
    UILabel *delayLabel = [self createLabel:@"延迟抢红包(秒)"];
    [stackView addArrangedSubview:delayLabel];
    
    UISlider *slider = [[UISlider alloc] init];
    slider.minimumValue = 0;
    slider.maximumValue = 10;
    slider.value = config.delaySeconds;
    [slider addTarget:self action:@selector(delaySliderChanged:) forControlEvents:UIControlEventValueChanged];
    [stackView addArrangedSubview:slider];
    
    UILabel *delayValueLabel = [self createLabel:[NSString stringWithFormat:@"%ld", (long)config.delaySeconds]];
    delayValueLabel.textAlignment = NSTextAlignmentCenter;
    [stackView addArrangedSubview:delayValueLabel];
    
    // 更新布局
    [stackView sizeToFit];
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, CGRectGetMaxY(stackView.frame) + 20);
}

- (void)addSwitchToStack:(UIStackView *)stackView title:(NSString *)title value:(BOOL)value keyPath:(NSString *)keyPath {
    UIView *switchView = [[UIView alloc] init];
    switchView.frame = CGRectMake(0, 0, stackView.bounds.size.width, 44);
    
    UILabel *label = [self createLabel:title];
    label.frame = CGRectMake(0, 0, stackView.bounds.size.width - 60, 44);
    [switchView addSubview:label];
    
    UISwitch *switchControl = [[UISwitch alloc] init];
    switchControl.frame = CGRectMake(stackView.bounds.size.width - 60, 7, 0, 0);
    switchControl.on = value;
    switchControl.tag = [@[@"autoReceiveEnable", @"personalRedEnvelopEnable", @"receiveSelfRedEnvelop", @"serialReceive"] indexOfObject:keyPath];
    [switchControl addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [switchView addSubview:switchControl];
    
    [stackView addArrangedSubview:switchView];
}

- (UILabel *)createLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.font = [UIFont systemFontOfSize:16];
    label.textColor = [UIColor labelColor];
    return label;
}

- (void)switchChanged:(UISwitch *)sender {
    WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
    
    switch (sender.tag) {
        case 0: config.autoReceiveEnable = sender.on; break;
        case 1: config.personalRedEnvelopEnable = sender.on; break;
        case 2: config.receiveSelfRedEnvelop = sender.on; break;
        case 3: config.serialReceive = sender.on; break;
    }
}

- (void)delaySliderChanged:(UISlider *)sender {
    WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
    config.delaySeconds = (NSInteger)sender.value;
}
@end

#pragma mark - Hook 实现
%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(HongBaoRes *)arg1 Request:(HongBaoReq *)arg2 {
    %orig;
    
    // 非参数查询请求
    int cgiCmdid = (int)objc_msgSend(arg1, @selector(cgiCmdid));
    if (cgiCmdid != 3) { return; }
    
    NSString *(^parseRequestSign)(void) = ^NSString *{
        NSData *reqTextData = objc_msgSend(objc_msgSend(arg2, @selector(reqText)), @selector(buffer));
        if (!reqTextData) return nil;
        
        NSString *requestString = [[NSString alloc] initWithData:reqTextData encoding:NSUTF8StringEncoding];
        if (!requestString) return nil;
        
        NSDictionary *requestDictionary = [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:requestString separator:@"&"];
        if (!requestDictionary) return nil;
        
        NSString *nativeUrl = [requestDictionary objectForKey:@"nativeUrl"];
        if (!nativeUrl) return nil;
        
        nativeUrl = [nativeUrl stringByRemovingPercentEncoding];
        if (!nativeUrl) return nil;
        
        NSDictionary *nativeUrlDict = [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
        if (!nativeUrlDict) return nil;
        
        return [nativeUrlDict objectForKey:@"sign"];
    };
    
    NSData *retTextData = objc_msgSend(objc_msgSend(arg1, @selector(retText)), @selector(buffer));
    if (!retTextData) return;
    
    NSError *error = nil;
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:retTextData options:0 error:&error];
    if (error || ![responseDict isKindOfClass:[NSDictionary class]]) return;
    
    WeChatRedEnvelopParam *mgrParams = [[WCPLRedEnvelopParamQueue sharedQueue] dequeue];
    
    BOOL (^shouldReceiveRedEnvelop)(void) = ^BOOL{
        // 手动抢红包
        if (!mgrParams) { return NO; }
        
        // 自己已经抢过
        NSNumber *receiveStatus = responseDict[@"receiveStatus"];
        if (receiveStatus && [receiveStatus integerValue] == 2) { return NO; }
        
        // 红包被抢完
        NSNumber *hbStatus = responseDict[@"hbStatus"];
        if (hbStatus && [hbStatus integerValue] == 4) { return NO; }  
        
        // 没有这个字段会被判定为使用外挂
        NSString *timingIdentifier = responseDict[@"timingIdentifier"];
        if (!timingIdentifier) { return NO; }  
        
        if (mgrParams.isGroupSender) { 
            // 自己发红包的时候没有 sign 字段
            return [WCPLRedEnvelopConfig sharedConfig].autoReceiveEnable;
        } else {
            NSString *sign = parseRequestSign();
            if (!sign) return NO;
            return [sign isEqualToString:mgrParams.sign] && [WCPLRedEnvelopConfig sharedConfig].autoReceiveEnable;
        }
    };
    
    if (shouldReceiveRedEnvelop()) {
        mgrParams.timingIdentifier = responseDict[@"timingIdentifier"];
        
        unsigned int delaySeconds = [self wcpl_calculateDelaySeconds];
        WCPLReceiveRedEnvelopOperation *operation = [[WCPLReceiveRedEnvelopOperation alloc] initWithRedEnvelopParam:mgrParams delay:delaySeconds];
        
        if ([WCPLRedEnvelopConfig sharedConfig].serialReceive) {
            [[WCPLRedEnvelopTaskManager sharedManager] addSerialTask:operation];
        } else {
            [[WCPLRedEnvelopTaskManager sharedManager] addNormalTask:operation];
        }
    }
}

%new
- (unsigned int)wcpl_calculateDelaySeconds {
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

%end

#pragma mark - Hook CMessageMgr
%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap {
    %orig;
    
    NSInteger messageType = [wrap m_uiMessageType];
    if (messageType != 49) { return; } // AppNode
    
    /** 是否为红包消息 */
    BOOL (^isRedEnvelopMessage)(void) = ^BOOL{
        NSString *content = [wrap m_nsContent];
        return content && [content rangeOfString:@"wxpay://"].location != NSNotFound;
    };
    
    if (!isRedEnvelopMessage()) return;
    
    MMServiceCenter *center = [objc_getClass("MMServiceCenter") defaultCenter];
    CContactMgr *contactManager = [center getService:objc_getClass("CContactMgr")];
    CContact *selfContact = [contactManager getSelfContact];
    
    BOOL (^isSender)(void) = ^BOOL{
        NSString *fromUser = [wrap m_nsFromUsr];
        NSString *selfUserName = [selfContact m_nsUsrName];
        return selfUserName && fromUser && [fromUser isEqualToString:selfUserName];
    };
    
    /** 是否别人在群聊中发消息 */
    BOOL (^isGroupReceiver)(void) = ^BOOL{
        NSString *fromUser = [wrap m_nsFromUsr];
        return fromUser && [fromUser rangeOfString:@"@chatroom"].location != NSNotFound;
    };
    
    /** 是否自己在群聊中发消息 */
    BOOL (^isGroupSender)(void) = ^BOOL{
        NSString *toUser = [wrap m_nsToUsr];
        return isSender() && toUser && [toUser rangeOfString:@"chatroom"].location != NSNotFound;
    };
    
    /** 是否抢自己发的红包 */
    BOOL (^isReceiveSelfRedEnvelop)(void) = ^BOOL{
        return [WCPLRedEnvelopConfig sharedConfig].receiveSelfRedEnvelop;
    };
    
    /** 是否在黑名单中 */
    BOOL (^isGroupInBlackList)(void) = ^BOOL{
        NSString *fromUser = [wrap m_nsFromUsr];
        NSArray *blackList = [WCPLRedEnvelopConfig sharedConfig].blackList;
        return fromUser && blackList && [blackList containsObject:fromUser];
    };
    
    /** 是否自动抢红包 */
    BOOL (^shouldReceiveRedEnvelop)(void) = ^BOOL{
        WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
        if (!config.autoReceiveEnable) { return NO; }
        if (isGroupInBlackList()) { return NO; }
        
        return isGroupReceiver() || 
               (isGroupSender() && isReceiveSelfRedEnvelop()) || 
               (!isGroupReceiver() && !isGroupSender() && config.personalRedEnvelopEnable); 
    };
    
    if (!shouldReceiveRedEnvelop()) return;
    
    NSString *nativeUrl = [wrap m_nsContent];
    if (!nativeUrl) return;
    
    // 解析红包参数
    NSDictionary *(^parseNativeUrl)(NSString *) = ^NSDictionary *(NSString *nativeUrlStr) {
        NSString *prefix = @"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?";
        if (![nativeUrlStr hasPrefix:prefix]) return nil;
        
        NSString *queryString = [nativeUrlStr substringFromIndex:prefix.length];
        return [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:queryString separator:@"&"];
    };
    
    NSDictionary *nativeUrlDict = parseNativeUrl(nativeUrl);
    if (!nativeUrlDict) return;
    
    // 创建红包参数
    WeChatRedEnvelopParam *param = [[WeChatRedEnvelopParam alloc] init];
    param.msgType = [nativeUrlDict objectForKey:@"msgtype"] ?: @"1";
    param.sendId = [nativeUrlDict objectForKey:@"sendid"] ?: @"";
    param.channelId = [nativeUrlDict objectForKey:@"channelid"] ?: @"1";
    param.nickName = [nativeUrlDict objectForKey:@"sendusername"] ?: @"";
    param.headImg = [nativeUrlDict objectForKey:@"headerimg"] ?: @"";
    param.nativeUrl = nativeUrl;
    param.sessionUserName = isGroupReceiver() ? [wrap m_nsFromUsr] : [wrap m_nsToUsr];
    param.sign = [nativeUrlDict objectForKey:@"sign"] ?: @"";
    param.isGroupSender = isGroupSender();
    
    // 加入队列
    [[WCPLRedEnvelopParamQueue sharedQueue] enqueue:param];
    
    // 发送查询请求
    Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
    if (logicMgrClass) {
        SEL selector = NSSelectorFromString(@"QueryRedEnvelopesRequest:");
        if ([logicMgrClass instancesRespondToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            id logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:logicMgrClass];
            [logicMgr performSelector:selector withObject:param];
#pragma clang diagnostic pop
        }
    }
}

%end

#pragma mark - 插件入口
%ctor {
    @autoreleasepool {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            Class pluginsMgrClass = NSClassFromString(@"WCPluginsMgr");
            if (pluginsMgrClass) {
                SEL sharedInstanceSel = @selector(sharedInstance);
                if ([pluginsMgrClass respondsToSelector:sharedInstanceSel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                    id manager = [pluginsMgrClass performSelector:sharedInstanceSel];
                    
                    if (manager) {
                        // 注册带设置页面的插件
                        SEL registerControllerSel = @selector(registerControllerWithTitle:version:controller:);
                        if ([manager respondsToSelector:registerControllerSel]) {
                            [manager performSelector:registerControllerSel 
                                          withObject:@"DD红包" 
                                          withObject:@"1.0.0" 
                                          withObject:@"DDRedEnvelopSettingsController"];
                        }
                    }
#pragma clang diagnostic pop
                }
            }
        });
    }
}
