// DD红包 v1.0.0
// Created by DDHelper

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 配置管理
@interface DDRedEnvelopConfig : NSObject
+ (instancetype)shared;
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
    // 从NSUserDefaults加载配置
}

- (void)saveConfig {
    // 保存配置到NSUserDefaults
}

@end

#pragma mark - 红包参数模型
@interface DDRedEnvelopParam : NSObject
@property (strong, nonatomic) NSString *msgType;
@property (strong, nonatomic) NSString *sendId;
@property (strong, nonatomic) NSString *channelId;
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
@end

#pragma mark - Logos Hook部分

// Hook CMessageMgr
%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(id)wrap {
    %orig;
    
    // 检查开关是否开启
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DD_autoRedEnvelop"]) return;
    
    // 检查消息类型
    NSInteger m_uiMessageType = [[wrap valueForKey:@"m_uiMessageType"] integerValue];
    if (m_uiMessageType != 49) return;
    
    // 检查是否为红包消息
    NSString *content = [wrap valueForKey:@"m_nsContent"];
    if (![content containsString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"]) return;
    
    // 获取发送者和接收者
    NSString *fromUsr = [wrap valueForKey:@"m_nsFromUsr"];
    NSString *toUsr = [wrap valueForKey:@"m_nsToUsr"];
    
    // 获取配置
    NSArray *groupFilter = [[NSUserDefaults standardUserDefaults] arrayForKey:@"DD_redEnvelopGroupFilter"] ?: @[];
    BOOL catchMe = [[NSUserDefaults standardUserDefaults] boolForKey:@"DD_redEnvelopCatchMe"];
    
    // 群聊过滤
    if ([groupFilter containsObject:fromUsr]) return;
    
    // 获取自己信息
    Class mmServiceClass = objc_getClass("MMServiceCenter");
    id mmService = [mmServiceClass performSelector:@selector(defaultCenter)];
    
    Class contactMgrClass = objc_getClass("CContactMgr");
    id contactMgr = [mmService performSelector:@selector(getService:) withObject:contactMgrClass];
    id selfContact = [contactMgr performSelector:@selector(getSelfContact)];
    NSString *selfUsrName = [selfContact valueForKey:@"m_nsUsrName"];
    
    // 判断消息类型
    BOOL isSender = [fromUsr isEqualToString:selfUsrName];
    BOOL isGroupSender = isSender && [toUsr containsString:@"chatroom"];
    BOOL isGroupReceiver = [fromUsr containsString:@"chatroom"];
    
    // 是否抢自己红包
    if (isGroupSender && !catchMe) return;
    
    // 判断是否需要抢红包
    BOOL shouldReceive = isGroupReceiver || (isGroupSender && catchMe);
    if (!shouldReceive) return;
    
    // 解析红包参数
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
    
    // 创建红包参数
    DDRedEnvelopParam *envelopParam = [[DDRedEnvelopParam alloc] init];
    envelopParam.msgType = paramDict[@"msgtype"];
    envelopParam.sendId = paramDict[@"sendid"];
    envelopParam.channelId = paramDict[@"channelid"];
    envelopParam.sessionUserName = isGroupSender ? toUsr : fromUsr;
    envelopParam.sign = paramDict[@"sign"];
    envelopParam.isGroupSender = isGroupSender;
    
    // 查询红包信息
    NSDictionary *queryParams = @{
        @"agreeDuty": @"0",
        @"channelId": envelopParam.channelId ?: @"",
        @"inWay": @"0",
        @"msgType": envelopParam.msgType ?: @"",
        @"nativeUrl": nativeUrl,
        @"sendId": envelopParam.sendId ?: @""
    };
    
    Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
    id logicMgr = [mmService performSelector:@selector(getService:) withObject:logicMgrClass];
    
    // 使用performSelector调用方法
    SEL receiverQuerySel = NSSelectorFromString(@"ReceiverQueryRedEnvelopesRequest:");
    if ([logicMgr respondsToSelector:receiverQuerySel]) {
        [logicMgr performSelector:receiverQuerySel withObject:queryParams];
    }
    
    // 加入队列
    [[DDRedEnvelopParamQueue sharedQueue] enqueue:envelopParam];
}

%end

// Hook WCRedEnvelopesLogicMgr
%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig(arg1, arg2);
    
    // 检查响应类型
    NSInteger cgiCmdid = [[arg1 valueForKey:@"cgiCmdid"] integerValue];
    if (cgiCmdid != 3) return;
    
    // 检查开关是否开启
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DD_autoRedEnvelop"]) return;
    
    // 解析响应数据
    NSData *retData = [[arg1 valueForKey:@"retText"] valueForKey:@"buffer"];
    if (!retData) return;
    
    NSString *retString = [[NSString alloc] initWithData:retData encoding:NSUTF8StringEncoding];
    if (!retString) return;
    
    NSError *error;
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:[retString dataUsingEncoding:NSUTF8StringEncoding] 
                                                               options:0 
                                                                 error:&error];
    if (error || !responseDict) return;
    
    // 检查红包状态
    NSInteger receiveStatus = [responseDict[@"receiveStatus"] integerValue];
    NSInteger hbStatus = [responseDict[@"hbStatus"] integerValue];
    NSString *timingIdentifier = responseDict[@"timingIdentifier"];
    
    if (receiveStatus == 2) return;
    if (hbStatus == 4) return;
    if (!timingIdentifier) return;
    
    // 从队列中取出参数
    DDRedEnvelopParam *envelopParam = [[DDRedEnvelopParamQueue sharedQueue] dequeue];
    if (!envelopParam) return;
    
    // 设置定时标识
    envelopParam.timingIdentifier = timingIdentifier;
    
    // 计算延迟时间
    NSInteger delay = [[NSUserDefaults standardUserDefaults] integerForKey:@"DD_redEnvelopDelay"];
    BOOL multipleCatch = [[NSUserDefaults standardUserDefaults] boolForKey:@"DD_redEnvelopMultipleCatch"];
    
    unsigned int delaySeconds = 0;
    if (delay > 0) {
        delaySeconds = (unsigned int)delay;
    }
    
    // 延迟执行打开红包
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delaySeconds / 1000.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 获取服务
        Class mmServiceClass = objc_getClass("MMServiceCenter");
        id mmService = [mmServiceClass performSelector:@selector(defaultCenter)];
        Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
        id logicMgr = [mmService performSelector:@selector(getService:) withObject:logicMgrClass];
        
        // 使用performSelector调用打开红包方法
        SEL openRedEnvelopSel = NSSelectorFromString(@"OpenRedEnvelopesRequest:");
        if ([logicMgr respondsToSelector:openRedEnvelopSel]) {
            [logicMgr performSelector:openRedEnvelopSel withObject:[envelopParam toParams]];
        }
    });
}

%end

#pragma mark - 插件初始化
%ctor {
    @autoreleasepool {
        // 设置默认配置
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults boolForKey:@"DD_hasSetDefaults"]) {
            [defaults setBool:YES forKey:@"DD_autoRedEnvelop"];
            [defaults setInteger:0 forKey:@"DD_redEnvelopDelay"];
            [defaults setObject:@[] forKey:@"DD_redEnvelopGroupFilter"];
            [defaults setBool:NO forKey:@"DD_redEnvelopCatchMe"];
            [defaults setBool:NO forKey:@"DD_redEnvelopMultipleCatch"];
            [defaults setBool:YES forKey:@"DD_hasSetDefaults"];
            [defaults synchronize];
        }
        
        // 延迟注册插件入口
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            Class pluginsMgrClass = objc_getClass("WCPluginsMgr");
            if (pluginsMgrClass) {
                // 使用performSelector调用单例和方法
                SEL sharedSel = NSSelectorFromString(@"sharedInstance");
                if ([pluginsMgrClass respondsToSelector:sharedSel]) {
                    id pluginsMgr = [pluginsMgrClass performSelector:sharedSel];
                    
                    SEL registerSwitchSel = NSSelectorFromString(@"registerSwitchWithTitle:key:");
                    if ([pluginsMgr respondsToSelector:registerSwitchSel]) {
                        [pluginsMgr performSelector:registerSwitchSel withObject:@"DD红包" withObject:@"DD_autoRedEnvelop"];
                    }
                }
            }
        });
    }
}

// 插件版本信息
__attribute__((visibility("default"))) NSString *DDRedEnvelopVersion = @"1.0.0";