// DD红包 v1.0.0
// Created by DDHelper
// 功能：自动抢红包、延迟抢红包、群聊过滤、抢自己红包、防止同时抢多个红包

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

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

#pragma mark - 红包参数队列
@interface DDRedEnvelopParamQueue : NSObject

+ (instancetype)sharedQueue;
- (void)enqueue:(DDRedEnvelopParam *)param;
- (DDRedEnvelopParam *)dequeue;
- (BOOL)isEmpty;

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

#pragma mark - 任务管理器
@interface DDRedEnvelopTaskManager : NSObject

+ (instancetype)sharedManager;
- (void)addTaskWithParam:(DDRedEnvelopParam *)param delay:(unsigned int)delaySeconds;
- (BOOL)isSerialQueueEmpty;

@end

@implementation DDRedEnvelopTaskManager {
    NSOperationQueue *_serialQueue;
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
    }
    return self;
}

- (void)addTaskWithParam:(DDRedEnvelopParam *)param delay:(unsigned int)delaySeconds {
    NSOperation *task = [NSBlockOperation blockOperationWithBlock:^{
        if (delaySeconds > 0) {
            [NSThread sleepForTimeInterval:delaySeconds / 1000.0];
        }
        
        Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
        if (!logicMgrClass) return;
        
        Class mmServiceClass = objc_getClass("MMServiceCenter");
        if (!mmServiceClass) return;
        
        id mmService = [mmServiceClass defaultCenter];
        if (!mmService) return;
        
        id logicMgr = [mmService getService:logicMgrClass];
        if (!logicMgr) return;
        
        NSDictionary *params = [param toParams];
        if ([logicMgr respondsToSelector:@selector(OpenRedEnvelopesRequest:)]) {
            [logicMgr OpenRedEnvelopesRequest:params];
        }
    }];
    
    [_serialQueue addOperation:task];
}

- (BOOL)isSerialQueueEmpty {
    return _serialQueue.operationCount == 0;
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
    
    // 获取自己信息
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
        if (config.redEnvelopMultipleCatch && ![[DDRedEnvelopTaskManager sharedManager] isSerialQueueEmpty]) {
            delaySeconds = 15000;
        } else {
            delaySeconds = (unsigned int)config.redEnvelopDelay;
        }
    }
    
    [[DDRedEnvelopTaskManager sharedManager] addTaskWithParam:envelopParam delay:delaySeconds];
}

%end

#pragma mark - 插件入口
%ctor {
    @autoreleasepool {
        // 预加载配置
        [DDRedEnvelopConfig shared];
        
        // 注册插件到微信插件管理器
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            Class pluginsMgrClass = objc_getClass("WCPluginsMgr");
            if (pluginsMgrClass && [pluginsMgrClass respondsToSelector:@selector(sharedInstance)]) {
                id pluginsMgr = [pluginsMgrClass sharedInstance];
                if ([pluginsMgr respondsToSelector:@selector(registerSwitchWithTitle:key:)]) {
                    [pluginsMgr registerSwitchWithTitle:@"DD红包" key:@"DD_autoRedEnvelop"];
                }
            }
        });
    }
}

// 插件版本信息
__attribute__((visibility("default"))) NSString *DDRedEnvelopVersion = @"1.0.0";