#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 微信类的前向声明
@interface CMessageWrap : NSObject
@property(nonatomic) unsigned int m_uiMessageType;
@property(retain, nonatomic) NSString *m_nsContent;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) NSString *m_nsToUsr;
- (unsigned int)m_uiMessageType;
- (NSString *)m_nsContent;
- (NSString *)m_nsFromUsr;
- (NSString *)m_nsToUsr;
@end

@interface CContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
- (NSString *)m_nsUsrName;
@end

@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)serviceClass;
@end

@interface CContactMgr : NSObject
- (CContact *)getSelfContact;
@end

@interface CMessageMgr : NSObject
- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap;
@end

@interface WCRedEnvelopesLogicMgr : NSObject
- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2;
@end

@interface HongBaoRes : NSObject
@property(nonatomic) unsigned int cgiCmdid;
@property(retain, nonatomic) id retText;
- (unsigned int)cgiCmdid;
- (id)retText;
@end

@interface HongBaoReq : NSObject
@property(retain, nonatomic) id reqText;
- (id)reqText;
@end

@interface TextMessage : NSObject
@property(retain, nonatomic) NSData *buffer;
- (NSData *)buffer;
@end

// 配置类
@interface WCPLRedEnvelopConfig : NSObject
@property (nonatomic, assign) BOOL autoReceiveEnable;
@property (nonatomic, assign) BOOL serialReceive;
@property (nonatomic, assign) BOOL personalRedEnvelopEnable;
@property (nonatomic, assign) BOOL receiveSelfRedEnvelop;
@property (nonatomic, assign) NSInteger delaySeconds;
@property (nonatomic, strong) NSArray *blackList;

+ (instancetype)sharedConfig;
- (void)saveConfig;
@end

@implementation WCPLRedEnvelopConfig

+ (instancetype)sharedConfig {
    static WCPLRedEnvelopConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[WCPLRedEnvelopConfig alloc] init];
        [config loadConfig];
    });
    return config;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _autoReceiveEnable = YES;
        _serialReceive = NO;
        _personalRedEnvelopEnable = YES;
        _receiveSelfRedEnvelop = NO;
        _delaySeconds = 0;
        _blackList = @[];
    }
    return self;
}

- (void)loadConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _autoReceiveEnable = [defaults boolForKey:@"WCPLAutoReceiveEnable"] ?: YES;
    _serialReceive = [defaults boolForKey:@"WCPLSerialReceive"] ?: NO;
    _personalRedEnvelopEnable = [defaults boolForKey:@"WCPLPersonalRedEnvelopEnable"] ?: YES;
    _receiveSelfRedEnvelop = [defaults boolForKey:@"WCPLReceiveSelfRedEnvelop"] ?: NO;
    _delaySeconds = [defaults integerForKey:@"WCPLDelaySeconds"] ?: 0;
    _blackList = [defaults arrayForKey:@"WCPLBlackList"] ?: @[];
}

- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:_autoReceiveEnable forKey:@"WCPLAutoReceiveEnable"];
    [defaults setBool:_serialReceive forKey:@"WCPLSerialReceive"];
    [defaults setBool:_personalRedEnvelopEnable forKey:@"WCPLPersonalRedEnvelopEnable"];
    [defaults setBool:_receiveSelfRedEnvelop forKey:@"WCPLReceiveSelfRedEnvelop"];
    [defaults setInteger:_delaySeconds forKey:@"WCPLDelaySeconds"];
    [defaults setObject:_blackList forKey:@"WCPLBlackList"];
    [defaults synchronize];
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

// 任务管理类
@interface WCPLRedEnvelopTaskManager : NSObject
@property (nonatomic, assign, readonly) BOOL serialQueueIsEmpty;

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
    });
    return manager;
}

- (BOOL)serialQueueIsEmpty {
    return YES;
}

- (void)addSerialTask:(id)operation {
    // 实现串行任务添加逻辑
}

- (void)addNormalTask:(id)operation {
    // 实现普通任务添加逻辑
}

@end

// 参数队列类
@interface WCPLRedEnvelopParamQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(WeChatRedEnvelopParam *)param;
- (WeChatRedEnvelopParam *)dequeue;
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

- (void)enqueue:(WeChatRedEnvelopParam *)param {
    // 实现入队逻辑
}

- (WeChatRedEnvelopParam *)dequeue {
    // 实现出队逻辑
    return nil;
}

@end

// 接收红包操作类
@interface WCPLReceiveRedEnvelopOperation : NSObject
- (instancetype)initWithRedEnvelopParam:(WeChatRedEnvelopParam *)param delay:(unsigned int)delay;
@end

@implementation WCPLReceiveRedEnvelopOperation

- (instancetype)initWithRedEnvelopParam:(WeChatRedEnvelopParam *)param delay:(unsigned int)delay {
    self = [super init];
    if (self) {
        // 初始化操作
    }
    return self;
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
    return [dict copy];
}

@end

// 字符串分类
@interface NSString (JSONDictionary)
- (NSDictionary *)JSONDictionary;
@end

@implementation NSString (JSONDictionary)

- (NSDictionary *)JSONDictionary {
    NSData *jsonData = [self dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) return nil;
    
    NSError *error = nil;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    if (error) {
        return nil;
    }
    return dict;
}

@end

// 字典分类
@interface NSDictionary (SafeAccess)
- (NSString *)stringForKey:(NSString *)key;
@end

@implementation NSDictionary (SafeAccess)

- (NSString *)stringForKey:(NSString *)key {
    id value = [self objectForKey:key];
    if ([value isKindOfClass:[NSString class]]) {
        return value;
    } else if ([value isKindOfClass:[NSNumber class]]) {
        return [value stringValue];
    }
    return nil;
}

@end

// 红包逻辑管理器钩子
%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(HongBaoRes *)arg1 Request:(HongBaoReq *)arg2 {
    %orig;

    // 非参数查询请求
    if ([arg1 cgiCmdid] != 3) { return; }

    NSString *(^parseRequestSign)() = ^NSString *() {
        TextMessage *reqText = [arg2 reqText];
        if (!reqText) return nil;
        
        NSData *requestData = [reqText buffer];
        if (!requestData) return nil;
        
        NSString *requestString = [[NSString alloc] initWithData:requestData encoding:NSUTF8StringEncoding];
        NSDictionary *requestDictionary = [WCBizUtil dictionaryWithDecodedComponets:requestString separator:@"&"];
        NSString *nativeUrl = [[requestDictionary stringForKey:@"nativeUrl"] stringByRemovingPercentEncoding];
        if (!nativeUrl) return nil;
        
        NSDictionary *nativeUrlDict = [WCBizUtil dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
        return [nativeUrlDict stringForKey:@"sign"];
    };

    TextMessage *retText = [arg1 retText];
    if (!retText) return;
    
    NSData *responseData = [retText buffer];
    if (!responseData) return;
    
    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    NSDictionary *responseDict = [responseString JSONDictionary];
    if (!responseDict) return;

    WeChatRedEnvelopParam *mgrParams = [[WCPLRedEnvelopParamQueue sharedQueue] dequeue];

    BOOL (^shouldReceiveRedEnvelop)() = ^BOOL() {
        // 手动抢红包
        if (!mgrParams) { return NO; }

        // 自己已经抢过
        if ([responseDict[@"receiveStatus"] integerValue] == 2) { return NO; }

        // 红包被抢完
        if ([responseDict[@"hbStatus"] integerValue] == 4) { return NO; }  

        // 没有这个字段会被判定为使用外挂
        if (!responseDict[@"timingIdentifier"]) { return NO; }  

        WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
        
        if (mgrParams.isGroupSender) { 
            // 自己发红包的时候没有 sign 字段
            return config.autoReceiveEnable;
        } else {
            NSString *sign = parseRequestSign();
            return sign && [sign isEqualToString:mgrParams.sign] && config.autoReceiveEnable;
        }
    };

    if (shouldReceiveRedEnvelop()) {
        mgrParams.timingIdentifier = responseDict[@"timingIdentifier"];

        WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
        unsigned int delaySeconds = 0;
        
        if (config.serialReceive) {
            if ([[WCPLRedEnvelopTaskManager sharedManager] serialQueueIsEmpty]) {
                delaySeconds = (unsigned int)config.delaySeconds;
            } else {
                delaySeconds = 5;
            }
        } else {
            delaySeconds = (unsigned int)config.delaySeconds;
        }

        WCPLReceiveRedEnvelopOperation *operation = [[WCPLReceiveRedEnvelopOperation alloc] initWithRedEnvelopParam:mgrParams delay:delaySeconds];

        if (config.serialReceive) {
            [[WCPLRedEnvelopTaskManager sharedManager] addSerialTask:operation];
        } else {
            [[WCPLRedEnvelopTaskManager sharedManager] addNormalTask:operation];
        }
    }
}

%end

%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap {
    %orig;

    switch([wrap m_uiMessageType]) {
        case 49: { // AppNode
            /** 是否为红包消息 */
            BOOL (^isRedEnvelopMessage)() = ^BOOL() {
                NSString *content = [wrap m_nsContent];
                return content && [content rangeOfString:@"wxpay://"].location != NSNotFound;
            };
            
            if (isRedEnvelopMessage()) { // 红包
                MMServiceCenter *serviceCenter = [MMServiceCenter defaultCenter];
                CContactMgr *contactManager = [serviceCenter getService:[CContactMgr class]];
                CContact *selfContact = [contactManager getSelfContact];

                BOOL (^isSender)() = ^BOOL() {
                    NSString *fromUser = [wrap m_nsFromUsr];
                    NSString *selfUserName = [selfContact m_nsUsrName];
                    return fromUser && selfUserName && [fromUser isEqualToString:selfUserName];
                };

                /** 是否别人在群聊中发消息 */
                BOOL (^isGroupReceiver)() = ^BOOL() {
                    NSString *fromUser = [wrap m_nsFromUsr];
                    return fromUser && [fromUser rangeOfString:@"@chatroom"].location != NSNotFound;
                };

                /** 是否自己在群聊中发消息 */
                BOOL (^isGroupSender)() = ^BOOL() {
                    NSString *toUser = [wrap m_nsToUsr];
                    return isSender() && toUser && [toUser rangeOfString:@"chatroom"].location != NSNotFound;
                };

                /** 是否抢自己发的红包 */
                BOOL (^isReceiveSelfRedEnvelop)() = ^BOOL() {
                    return [WCPLRedEnvelopConfig sharedConfig].receiveSelfRedEnvelop;
                };

                /** 是否在黑名单中 */
                BOOL (^isGroupInBlackList)() = ^BOOL() {
                    NSString *fromUser = [wrap m_nsFromUsr];
                    return fromUser && [[WCPLRedEnvelopConfig sharedConfig].blackList containsObject:fromUser];
                };

                /** 是否自动抢红包 */
                BOOL (^shouldReceiveRedEnvelop)() = ^BOOL() {
                    WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
                    if (!config.autoReceiveEnable) { return NO; }
                    if (isGroupInBlackList()) { return NO; }

                    return isGroupReceiver() || 
                           (isGroupSender() && isReceiveSelfRedEnvelop()) || 
                           (!isGroupReceiver() && !isGroupSender() && config.personalRedEnvelopEnable); 
                };

                if (shouldReceiveRedEnvelop()) {
                    // 解析红包参数并加入队列
                    NSString *content = [wrap m_nsContent];
                    NSDictionary *messageDict = [WCBizUtil dictionaryWithDecodedComponets:content separator:@"="];
                    NSString *nativeUrl = [messageDict stringForKey:@"nativeurl"];
                    
                    if (nativeUrl) {
                        NSDictionary *nativeUrlDict = [WCBizUtil dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
                        
                        WeChatRedEnvelopParam *param = [[WeChatRedEnvelopParam alloc] init];
                        param.msgType = [nativeUrlDict stringForKey:@"msgtype"];
                        param.sendId = [nativeUrlDict stringForKey:@"sendid"];
                        param.channelId = [nativeUrlDict stringForKey:@"channelid"];
                        param.nickName = [nativeUrlDict stringForKey:@"nickname"];
                        param.headImg = [nativeUrlDict stringForKey:@"headimg"];
                        param.nativeUrl = nativeUrl;
                        param.sessionUserName = [wrap m_nsFromUsr];
                        param.sign = [nativeUrlDict stringForKey:@"sign"];
                        param.isGroupSender = isGroupSender();
                        
                        [[WCPLRedEnvelopParamQueue sharedQueue] enqueue:param];
                    }
                }
            }
            break;
        }
        default:
            break;
    }
}

%end

// 设置界面控制器
@interface DDRedEnvelopSettingController : UITableViewController {
    NSArray *_sectionTitles;
    NSArray *_cellTitles;
}

@end

@implementation DDRedEnvelopSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"DD红包设置";
    
    _sectionTitles = @[@"基本设置", @"高级设置", @"黑名单管理"];
    _cellTitles = @[
        @[@"自动抢红包", @"串行模式", @"个人红包", @"抢自己红包"],
        @[@"延迟时间(秒)"],
        @[@"群聊黑名单"]
    ];
    
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _sectionTitles.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_cellTitles[section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _sectionTitles[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = _cellTitles[indexPath.section][indexPath.row];
    
    if (indexPath.section == 1) {
        // 延迟时间设置
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(150, 10, 100, 30)];
        textField.textAlignment = NSTextAlignmentRight;
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%ld", (long)config.delaySeconds];
        textField.placeholder = @"0";
        [textField addTarget:self action:@selector(delayTimeChanged:) forControlEvents:UIControlEventEditingChanged];
        cell.accessoryView = textField;
    } else if (indexPath.section == 2) {
        // 黑名单管理
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        // 开关设置
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.onTintColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
        
        switch (indexPath.row) {
            case 0: switchView.on = config.autoReceiveEnable; break;
            case 1: switchView.on = config.serialReceive; break;
            case 2: switchView.on = config.personalRedEnvelopEnable; break;
            case 3: switchView.on = config.receiveSelfRedEnvelop; break;
        }
        
        switchView.tag = indexPath.row;
        [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    }
    
    return cell;
}

- (void)switchChanged:(UISwitch *)sender {
    WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
    
    switch (sender.tag) {
        case 0: config.autoReceiveEnable = sender.on;
