#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 配置类
@interface WCPLRedEnvelopConfig : NSObject
@property (nonatomic, assign) BOOL autoReceiveEnable;
@property (nonatomic, assign) BOOL serialReceive;
@property (nonatomic, assign) BOOL personalRedEnvelopEnable;
@property (nonatomic, assign) BOOL receiveSelfRedEnvelop;
@property (nonatomic, assign) NSInteger delaySeconds;
@property (nonatomic, strong) NSArray *blackList;
+ (instancetype)sharedConfig;
@end

@implementation WCPLRedEnvelopConfig
+ (instancetype)sharedConfig {
    static WCPLRedEnvelopConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[WCPLRedEnvelopConfig alloc] init];
        config.autoReceiveEnable = YES;
        config.serialReceive = YES;
        config.personalRedEnvelopEnable = YES;
        config.receiveSelfRedEnvelop = NO;
        config.delaySeconds = 0;
        config.blackList = @[];
    });
    return config;
}
@end

// 红包参数类
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

// 红包参数队列
@interface WCPLRedEnvelopParamQueue : NSObject
@property (nonatomic, strong) NSMutableArray *queue;
+ (instancetype)sharedQueue;
- (void)enqueue:(WeChatRedEnvelopParam *)param;
- (WeChatRedEnvelopParam *)dequeue;
- (BOOL)isEmpty;
@end

@implementation WCPLRedEnvelopParamQueue
+ (instancetype)sharedQueue {
    static WCPLRedEnvelopParamQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[WCPLRedEnvelopParamQueue alloc] init];
        queue.queue = [NSMutableArray array];
    });
    return queue;
}

- (void)enqueue:(WeChatRedEnvelopParam *)param {
    [self.queue addObject:param];
}

- (WeChatRedEnvelopParam *)dequeue {
    if (self.queue.count == 0) {
        return nil;
    }
    WeChatRedEnvelopParam *first = self.queue.firstObject;
    [self.queue removeObjectAtIndex:0];
    return first;
}

- (BOOL)isEmpty {
    return self.queue.count == 0;
}
@end

// 红包任务管理器
@interface WCPLRedEnvelopTaskManager : NSObject
@property (nonatomic, assign) BOOL serialQueueIsEmpty;
+ (instancetype)sharedManager;
- (void)addSerialTask:(id)operation;
- (void)addNormalTask:(id)operation;
@end

@implementation WCPLRedEnvelopTaskManager
+ (instancetype)sharedManager {
    static WCPLRedEnvelopTaskManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[WCPLRedEnvelopTaskManager alloc] init];
        manager.serialQueueIsEmpty = YES;
    });
    return manager;
}

- (void)addSerialTask:(id)operation {
    NSLog(@"DD红包: 添加串行任务");
    self.serialQueueIsEmpty = NO;
}

- (void)addNormalTask:(id)operation {
    NSLog(@"DD红包: 添加普通任务");
}
@end

// 红包操作类
@interface WCPLReceiveRedEnvelopOperation : NSObject
- (instancetype)initWithRedEnvelopParam:(WeChatRedEnvelopParam *)param delay:(unsigned int)delay;
@end

@implementation WCPLReceiveRedEnvelopOperation
- (instancetype)initWithRedEnvelopParam:(WeChatRedEnvelopParam *)param delay:(unsigned int)delay {
    NSLog(@"DD红包: 创建抢红包操作，延迟: %u秒", delay);
    return [super init];
}
@end

// 工具类
@interface WCBizUtil : NSObject
+ (NSDictionary *)dictionaryWithDecodedComponets:(NSString *)string separator:(NSString *)separator;
@end

@implementation WCBizUtil
+ (NSDictionary *)dictionaryWithDecodedComponets:(NSString *)string separator:(NSString *)separator {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSArray *components = [string componentsSeparatedByString:separator];
    for (NSString *component in components) {
        NSArray *keyValue = [component componentsSeparatedByString:@"="];
        if (keyValue.count == 2) {
            NSString *key = [keyValue[0] stringByRemovingPercentEncoding];
            NSString *value = [keyValue[1] stringByRemovingPercentEncoding];
            if (key && value) {
                dict[key] = value;
            }
        }
    }
    return dict;
}
@end

// 分类扩展
@interface NSString (DDAdditions)
- (NSString *)JSONString;
@end

@implementation NSString (DDAdditions)
- (NSDictionary *)JSONDictionary {
    NSData *jsonData = [self dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) return nil;
    
    NSError *error = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (error) {
        NSLog(@"DD红包: JSON解析错误: %@", error);
        return nil;
    }
    return dict;
}
@end

// 主逻辑 - Hook WCRedEnvelopesLogicMgr
%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig;
    
    // 非参数查询请求
    if ([arg1 cgiCmdid] != 3) { return; }
    
    NSString *(^parseRequestSign)(void) = ^NSString *{
        NSString *requestString = [[NSString alloc] initWithData:[[arg2 reqText] buffer] encoding:NSUTF8StringEncoding];
        NSDictionary *requestDictionary = [%c(WCBizUtil) dictionaryWithDecodedComponets:requestString separator:@"&"];
        NSString *nativeUrl = [[requestDictionary objectForKey:@"nativeUrl"] stringByRemovingPercentEncoding];
        NSDictionary *nativeUrlDict = [%c(WCBizUtil) dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
        
        return [nativeUrlDict objectForKey:@"sign"];
    };
    
    NSDictionary *responseDict = [[[NSString alloc] initWithData:[[arg1 retText] buffer] encoding:NSUTF8StringEncoding] JSONDictionary];
    
    WeChatRedEnvelopParam *mgrParams = [[WCPLRedEnvelopParamQueue sharedQueue] dequeue];
    
    BOOL (^shouldReceiveRedEnvelop)(void) = ^BOOL {
        // 手动抢红包
        if (!mgrParams) { 
            NSLog(@"DD红包: 没有红包参数，可能是手动抢红包");
            return NO; 
        }
        
        // 自己已经抢过
        if ([[responseDict objectForKey:@"receiveStatus"] integerValue] == 2) { 
            NSLog(@"DD红包: 已经抢过这个红包");
            return NO; 
        }
        
        // 红包被抢完
        if ([[responseDict objectForKey:@"hbStatus"] integerValue] == 4) { 
            NSLog(@"DD红包: 红包已被抢完");
            return NO; 
        }  
        
        // 没有这个字段会被判定为使用外挂
        if ( { 
            NSLog(@"DD红包: 缺少timingIdentifier字段");
            return NO; 
        }  
        
        if (mgrParams.isGroupSender) { 
            // 自己发红包的时候没有 sign 字段
            BOOL shouldReceive = [[WCPLRedEnvelopConfig sharedConfig] autoReceiveEnable];
            NSLog(@"DD红包: 群发红包，自动抢红包状态: %@", shouldReceive ? @"开启" : @"关闭");
            return shouldReceive;
        } else {
            BOOL signMatch = [parseRequestSign() isEqualToString:mgrParams.sign];
            BOOL shouldReceive = signMatch && [[WCPLRedEnvelopConfig sharedConfig] autoReceiveEnable];
            NSLog(@"DD红包: 接收红包，签名匹配: %@，自动抢红包状态: %@", signMatch ? @"是" : @"否", [[WCPLRedEnvelopConfig sharedConfig] autoReceiveEnable] ? @"开启" : @"关闭");
            return shouldReceive;
        }
    };
    
    if (shouldReceiveRedEnvelop()) {
        mgrParams.timingIdentifier = [responseDict objectForKey:@"timingIdentifier"];
        
        unsigned int delaySeconds = [self wcpl_calculateDelaySeconds];
        WCPLReceiveRedEnvelopOperation *operation = [[WCPLReceiveRedEnvelopOperation alloc] initWithRedEnvelopParam:mgrParams delay:delaySeconds];
        
        if ([[WCPLRedEnvelopConfig sharedConfig] serialReceive]) {
            [[WCPLRedEnvelopTaskManager sharedManager] addSerialTask:operation];
        } else {
            [[WCPLRedEnvelopTaskManager sharedManager] addNormalTask:operation];
        }
        
        NSLog(@"DD红包: 已加入抢红包队列，延迟: %u秒", delaySeconds);
    }
}

%new
- (unsigned int)wcpl_calculateDelaySeconds {
    NSInteger configDelaySeconds = [[WCPLRedEnvelopConfig sharedConfig] delaySeconds];
    
    if ([[WCPLRedEnvelopConfig sharedConfig] serialReceive]) {
        unsigned int serialDelaySeconds;
        if ([[WCPLRedEnvelopTaskManager sharedManager] serialQueueIsEmpty]) {
            serialDelaySeconds = (unsigned int)configDelaySeconds;
        } else {
            serialDelaySeconds = 5;
        }
        
        NSLog(@"DD红包: 串行模式延迟: %u秒", serialDelaySeconds);
        return serialDelaySeconds;
    } else {
        NSLog(@"DD红包: 普通模式延迟: %ld秒", (long)configDelaySeconds);
        return (unsigned int)configDelaySeconds;
    }
}

%end

// Hook CMessageMgr
%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(id)wrap {
    %orig;
    
    unsigned int messageType = [wrap m_uiMessageType];
    switch(messageType) {
        case 49: { // AppNode
            /** 是否为红包消息 */
            BOOL (^isRedEnvelopMessage)(void) = ^BOOL {
                NSString *content = [wrap m_nsContent];
                return content && [content rangeOfString:@"wxpay://"].location != NSNotFound;
            };
            
            if (isRedEnvelopMessage()) { // 红包
                Class contactMgrClass = objc_getClass("CContactMgr");
                Class serviceCenterClass = objc_getClass("MMServiceCenter");
                
                if (!contactMgrClass || !serviceCenterClass) {
                    NSLog(@"DD红包: 无法获取必要的类");
                    break;
                }
                
                id contactManager = [[serviceCenterClass defaultCenter] getService:contactMgrClass];
                id selfContact = [contactManager getSelfContact];
                
                BOOL (^isSender)(void) = ^BOOL {
                    return [[wrap m_nsFromUsr] isEqualToString:[selfContact m_nsUsrName]];
                };
                
                /** 是否别人在群聊中发消息 */
                BOOL (^isGroupReceiver)(void) = ^BOOL {
                    NSString *fromUser = [wrap m_nsFromUsr];
                    return fromUser && [fromUser rangeOfString:@"@chatroom"].location != NSNotFound;
                };
                
                /** 是否自己在群聊中发消息 */
                BOOL (^isGroupSender)(void) = ^BOOL {
                    return isSender() && [[wrap m_nsToUsr] rangeOfString:@"chatroom"].location != NSNotFound;
                };
                
                /** 是否抢自己发的红包 */
                BOOL (^isReceiveSelfRedEnvelop)(void) = ^BOOL {
                    return [[WCPLRedEnvelopConfig sharedConfig] receiveSelfRedEnvelop];
                };
                
                /** 是否在黑名单中 */
                BOOL (^isGroupInBlackList)(void) = ^BOOL {
                    NSString *fromUser = [wrap m_nsFromUsr];
                    return fromUser && [[[WCPLRedEnvelopConfig sharedConfig] blackList] containsObject:fromUser];
                };
                
                /** 是否自动抢红包 */
                BOOL (^shouldReceiveRedEnvelop)(void) = ^BOOL {
                    if ( { 
                        NSLog(@"DD红包: 自动抢红包功能已关闭");
                        return NO; 
                    }
                    if (isGroupInBlackList()) { 
                        NSLog(@"DD红包: 群聊在黑名单中");
                        return NO; 
                    }
                    
                    BOOL shouldReceive = isGroupReceiver() || 
                                       (isGroupSender() && isReceiveSelfRedEnvelop()) || 
                                       (!isGroupReceiver() && !isGroupSender() && [[WCPLRedEnvelopConfig sharedConfig] personalRedEnvelopEnable]);
                    
                    NSLog(@"DD红包: 消息类型 - 群接收: %@, 群发送: %@, 个人红包: %@, 最终决定: %@",
                          isGroupReceiver() ? @"是" : @"否",
                          isGroupSender() ? @"是" : @"否",
                          (!isGroupReceiver() && !isGroupSender()) ? @"是" : @"否",
                          shouldReceive ? @"抢" : @"不抢");
                    
                    return shouldReceive;
                };
                
                NSDictionary *(^parseNativeUrl)(NSString *nativeUrl) = ^NSDictionary *(NSString *nativeUrl) {
                    NSString *prefix = @"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?";
                    if ([nativeUrl hasPrefix:prefix]) {
                        nativeUrl = [nativeUrl substringFromIndex:prefix.length];
                    }
                    return [%c(WCBizUtil) dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
                };
                
                if (shouldReceiveRedEnvelop()) {
                    NSString *content = [wrap m_nsContent];
                    NSDictionary *nativeUrlDict = parseNativeUrl(content);
                    
                    if (nativeUrlDict) {
                        WeChatRedEnvelopParam *param = [[WeChatRedEnvelopParam alloc] init];
                        param.msgType = [nativeUrlDict objectForKey:@"msgtype"];
                        param.sendId = [nativeUrlDict objectForKey:@"sendid"];
                        param.channelId = [nativeUrlDict objectForKey:@"channelid"];
                        param.nickName = [nativeUrlDict objectForKey:@"nick_name"];
                        param.headImg = [nativeUrlDict objectForKey:@"head_img"];
                        param.nativeUrl = content;
                        param.sessionUserName = [wrap m_nsFromUsr];
                        param.sign = [nativeUrlDict objectForKey:@"sign"];
                        param.isGroupSender = isGroupSender();
                        
                        [[WCPLRedEnvelopParamQueue sharedQueue] enqueue:param];
                        
                        NSLog(@"DD红包: 检测到红包消息，已加入处理队列");
                        NSLog(@"DD红包: 发送ID: %@, 频道ID: %@, 签名: %@", param.sendId, param.channelId, param.sign);
                    } else {
                        NSLog(@"DD红包: 解析红包URL失败");
                    }
                }
            }
            break;
        }
    }
}

%end

// 设置界面控制器
@interface DDRedEnvelopSettingsController : UITableViewController
@end

@implementation DDRedEnvelopSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD红包设置";
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 4;
    if (section == 1) return 1;
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"基本设置";
    if (section == 1) return @"其他设置";
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
    }
    
    WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
    
    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0: {
                cell.textLabel.text = @"自动抢红包";
                UISwitch *switchView = [[UISwitch alloc] init];
                switchView.on = config.autoReceiveEnable;
                [switchView addTarget:self action:@selector(autoReceiveSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = switchView;
                break;
            }
            case 1: {
                cell.textLabel.text = @"串行模式";
                UISwitch *switchView = [[UISwitch alloc] init];
                switchView.on = config.serialReceive;
                [switchView addTarget:self action:@selector(serialReceiveSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = switchView;
                break;
            }
            case 2: {
                cell.textLabel.text = @"抢个人红包";
                UISwitch *switchView = [[UISwitch alloc] init];
                switchView.on = config.personalRedEnvelopEnable;
                [switchView addTarget:self action:@selector(personalRedEnvelopSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = switchView;
                break;
            }
            case 3: {
                cell.textLabel.text = @"抢自己发的红包";
                UISwitch *switchView = [[UISwitch alloc] init];
                switchView.on = config.receiveSelfRedEnvelop;
                [switchView addTarget:self action:@selector(receiveSelfRedEnvelopSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = switchView;
                break;
            }
        }
    } else if (indexPath.section == 1) {
        cell.textLabel.text = @"延迟设置(秒)";
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(150, 0, 100, 44)];
        textField.text = [NSString stringWithFormat:@"%ld", (long)config.delaySeconds];
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.textAlignment = NSTextAlignmentRight;
        [textField addTarget:self action:@selector(delaySecondsChanged:) forControlEvents:UIControlEventEditingChanged];
        cell.accessoryView = textField;
    }
    
    return cell;
}

- (void)autoReceiveSwitchChanged:(UISwitch *)sender {
    [WCPLRedEnvelopConfig sharedConfig].autoReceiveEnable = sender.on;
}

- (void)serialReceiveSwitchChanged:(UISwitch *)sender {
    [WCPLRedEnvelopConfig sharedConfig].serialReceive = sender.on;
}

- (void)personalRedEnvelopSwitchChanged:(UISwitch *)sender {
    [WCPLRedEnvelopConfig sharedConfig].personalRedEnvelopEnable = sender.on;
}

- (void)receiveSelfRedEnvelopSwitchChanged:(UISwitch *)sender {
    [WCPLRedEnvelopConfig sharedConfig].receiveSelfRedEnvelop = sender.on;
}

- (void)delaySecondsChanged:(UITextField *)sender {
    [WCPLRedEnvelopConfig sharedConfig].delaySeconds = [sender.text integerValue];
}

@end

// 插件管理器接口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

// 插件初始化
__attribute__((constructor)) static void DDRedEnvelopEntry() {
    NSLog(@"DD红包插件已加载");
    
    // 注册到插件管理器
    if (NSClassFromString(@"WCPluginsMgr")) {
        [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD红包" 
                                                                           version:@"1.0.0" 
                                                                       controller:@"DDRedEnvelopSettingsController"];
    }
    
    // 初始化配置
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
        NSLog(@"DD红包: 插件初始化完成");
        NSLog(@"DD红包: 自动抢红包: %@", config.autoReceiveEnable ? @"开启" : @"关闭");
        NSLog(@"DD红包: 串行模式: %@", config.serialReceive ? @"开启" : @"关闭");
        NSLog(@"DD红包: 个人红包: %@", config.personalRedEnvelopEnable ? @"开启" : @"关闭");
        NSLog(@"DD红包: 抢自己红包: %@", config.receiveSelfRedEnvelop ? @"开启" : @"关闭");
        NSLog(@"DD红包: 延迟设置: %ld秒", (long)config.delaySeconds);
    });
}
