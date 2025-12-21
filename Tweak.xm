// DDRedEnvelop.xm
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - DD红包插件配置类

@interface DDRedEnvelopConfig : NSObject
@property (nonatomic, assign) BOOL autoRedEnvelop;          // 自动抢红包总开关
@property (nonatomic, assign) BOOL redEnvelopDelayEnabled;  // 延迟抢红包开关
@property (nonatomic, assign) NSInteger redEnvelopDelay;    // 延迟时间（毫秒）
@property (nonatomic, assign) BOOL groupFilterEnabled;      // 群聊过滤开关
@property (nonatomic, strong) NSArray *filteredGroups;      // 过滤的群聊列表
@property (nonatomic, assign) BOOL catchSelfRedEnvelop;     // 抢自己红包开关
@property (nonatomic, assign) BOOL preventMultipleCatch;    // 防止同时抢多个红包开关

+ (instancetype)sharedConfig;
- (void)saveConfig;
@end

@implementation DDRedEnvelopConfig

+ (instancetype)sharedConfig {
    static DDRedEnvelopConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DDRedEnvelopConfig alloc] init];
        [instance loadConfig];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _autoRedEnvelop = NO;
        _redEnvelopDelayEnabled = NO;
        _redEnvelopDelay = 0;
        _groupFilterEnabled = NO;
        _filteredGroups = @[];
        _catchSelfRedEnvelop = NO;
        _preventMultipleCatch = YES;
    }
    return self;
}

- (void)loadConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _autoRedEnvelop = [defaults boolForKey:@"DDRedEnvelop_autoRedEnvelop"];
    _redEnvelopDelayEnabled = [defaults boolForKey:@"DDRedEnvelop_redEnvelopDelayEnabled"];
    _redEnvelopDelay = [defaults integerForKey:@"DDRedEnvelop_redEnvelopDelay"];
    _groupFilterEnabled = [defaults boolForKey:@"DDRedEnvelop_groupFilterEnabled"];
    _filteredGroups = [defaults arrayForKey:@"DDRedEnvelop_filteredGroups"] ?: @[];
    _catchSelfRedEnvelop = [defaults boolForKey:@"DDRedEnvelop_catchSelfRedEnvelop"];
    _preventMultipleCatch = [defaults boolForKey:@"DDRedEnvelop_preventMultipleCatch"];
}

- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:_autoRedEnvelop forKey:@"DDRedEnvelop_autoRedEnvelop"];
    [defaults setBool:_redEnvelopDelayEnabled forKey:@"DDRedEnvelop_redEnvelopDelayEnabled"];
    [defaults setInteger:_redEnvelopDelay forKey:@"DDRedEnvelop_redEnvelopDelay"];
    [defaults setBool:_groupFilterEnabled forKey:@"DDRedEnvelop_groupFilterEnabled"];
    [defaults setObject:_filteredGroups forKey:@"DDRedEnvelop_filteredGroups"];
    [defaults setBool:_catchSelfRedEnvelop forKey:@"DDRedEnvelop_catchSelfRedEnvelop"];
    [defaults setBool:_preventMultipleCatch forKey:@"DDRedEnvelop_preventMultipleCatch"];
    [defaults synchronize];
}

@end

#pragma mark - 红包参数模型

@interface DDRedEnvelopParam : NSObject
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

@implementation DDRedEnvelopParam
@end

#pragma mark - 红包参数队列

@interface DDRedEnvelopParamQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(DDRedEnvelopParam *)param;
- (DDRedEnvelopParam *)dequeue;
- (BOOL)isEmpty;
@end

@implementation DDRedEnvelopParamQueue {
    NSMutableArray *_queue;
    NSLock *_lock;
}

+ (instancetype)sharedQueue {
    static DDRedEnvelopParamQueue *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DDRedEnvelopParamQueue alloc] init];
    });
    return instance;
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
        param = _queue.firstObject;
        [_queue removeObjectAtIndex:0];
    }
    [_lock unlock];
    return param;
}

- (BOOL)isEmpty {
    [_lock lock];
    BOOL empty = _queue.count == 0;
    [_lock unlock];
    return empty;
}

@end

#pragma mark - 红包任务管理器

@interface DDRedEnvelopTaskManager : NSObject
+ (instancetype)sharedManager;
- (void)addNormalTask:(void (^)(void))task;
- (void)addSerialTask:(void (^)(void))task;
@property (nonatomic, assign) BOOL serialQueueIsEmpty;
@end

@implementation DDRedEnvelopTaskManager {
    dispatch_queue_t _serialQueue;
    BOOL _isExecutingSerialTask;
}

+ (instancetype)sharedManager {
    static DDRedEnvelopTaskManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DDRedEnvelopTaskManager alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _serialQueue = dispatch_queue_create("com.dd.redenvelop.serial", DISPATCH_QUEUE_SERIAL);
        _serialQueueIsEmpty = YES;
    }
    return self;
}

- (void)addNormalTask:(void (^)(void))task {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        task();
    });
}

- (void)addSerialTask:(void (^)(void))task {
    _serialQueueIsEmpty = NO;
    dispatch_async(_serialQueue, ^{
        task();
        self->_serialQueueIsEmpty = YES;
    });
}

@end

#pragma mark - DD红包设置控制器

@interface DDRedEnvelopSettingController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *sectionTitles;
@property (nonatomic, strong) NSArray<NSArray<NSDictionary *> *> *cellConfigs;
@end

@implementation DDRedEnvelopSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD红包设置";
    self.view.backgroundColor = [UIColor colorWithRed:240/255.0 green:239/255.0 blue:245/255.0 alpha:1.0];
    
    // 创建表格
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.tableView];
    
    // 加载配置
    [self loadCellConfigs];
}

- (void)loadCellConfigs {
    DDRedEnvelopConfig *config = [DDRedEnvelopConfig sharedConfig];
    
    self.sectionTitles = @[@"基本设置", @"高级功能"];
    
    self.cellConfigs = @[
        @[
            @{
                @"type": @"switch",
                @"title": @"自动抢红包",
                @"key": @"autoRedEnvelop",
                @"value": @(config.autoRedEnvelop),
                @"section": @0
            }
        ],
        @[
            @{
                @"type": @"switch",
                @"title": @"延迟抢红包",
                @"key": @"redEnvelopDelayEnabled",
                @"value": @(config.redEnvelopDelayEnabled),
                @"section": @1
            },
            @{
                @"type": @"input",
                @"title": @"延迟时间(毫秒)",
                @"key": @"redEnvelopDelay",
                @"value": @(config.redEnvelopDelay),
                @"enabled": @(config.redEnvelopDelayEnabled),
                @"section": @1
            },
            @{
                @"type": @"switch",
                @"title": @"群聊过滤",
                @"key": @"groupFilterEnabled",
                @"value": @(config.groupFilterEnabled),
                @"section": @1
            },
            @{
                @"type": @"switch",
                @"title": @"抢自己红包",
                @"key": @"catchSelfRedEnvelop",
                @"value": @(config.catchSelfRedEnvelop),
                @"section": @1
            },
            @{
                @"type": @"switch",
                @"title": @"防止同时抢多个",
                @"key": @"preventMultipleCatch",
                @"value": @(config.preventMultipleCatch),
                @"section": @1
            }
        ]
    ];
}

#pragma mark - UITableView DataSource & Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sectionTitles.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    
    DDRedEnvelopConfig *config = [DDRedEnvelopConfig sharedConfig];
    if (!config.autoRedEnvelop) {
        // 自动抢红包关闭时，高级功能全部收起
        return 0;
    }
    return self.cellConfigs[section].count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sectionTitles[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"DDRedEnvelopCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *config = self.cellConfigs[indexPath.section][indexPath.row];
    NSString *type = config[@"type"];
    NSString *title = config[@"title"];
    id value = config[@"value"];
    
    cell.textLabel.text = title;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if ([type isEqualToString:@"switch"]) {
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [value boolValue];
        switchView.tag = indexPath.section * 100 + indexPath.row;
        [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
        cell.accessoryType = UITableViewCellAccessoryNone;
    } else if ([type isEqualToString:@"input"]) {
        cell.accessoryView = nil;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        BOOL enabled = [config[@"enabled"] boolValue];
        cell.textLabel.textColor = enabled ? [UIColor blackColor] : [UIColor grayColor];
        cell.userInteractionEnabled = enabled;
        
        UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 100, 30)];
        valueLabel.text = [NSString stringWithFormat:@"%@", value];
        valueLabel.textAlignment = NSTextAlignmentRight;
        valueLabel.textColor = [UIColor grayColor];
        cell.accessoryView = valueLabel;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *config = self.cellConfigs[indexPath.section][indexPath.row];
    NSString *type = config[@"type"];
    NSString *key = config[@"key"];
    
    if ([type isEqualToString:@"input"]) {
        [self showInputDialogForKey:key currentValue:[config[@"value"] integerValue]];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44;
}

#pragma mark - Actions

- (void)switchChanged:(UISwitch *)sender {
    NSInteger section = sender.tag / 100;
    NSInteger row = sender.tag % 100;
    
    NSDictionary *config = self.cellConfigs[section][row];
    NSString *key = config[@"key"];
    
    DDRedEnvelopConfig *ddConfig = [DDRedEnvelopConfig sharedConfig];
    
    if ([key isEqualToString:@"autoRedEnvelop"]) {
        ddConfig.autoRedEnvelop = sender.isOn;
        
        // 自动抢红包开关变化时，刷新表格
        [self.tableView beginUpdates];
        if (sender.isOn) {
            // 展开高级功能
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:1];
            [self.tableView insertSections:indexSet withRowAnimation:UITableViewRowAnimationFade];
        } else {
            // 收起高级功能
            NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:1];
            [self.tableView deleteSections:indexSet withRowAnimation:UITableViewRowAnimationFade];
        }
        [self.tableView endUpdates];
    }
    else if ([key isEqualToString:@"redEnvelopDelayEnabled"]) {
        ddConfig.redEnvelopDelayEnabled = sender.isOn;
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:1]] withRowAnimation:UITableViewRowAnimationNone];
    }
    else if ([key isEqualToString:@"groupFilterEnabled"]) {
        ddConfig.groupFilterEnabled = sender.isOn;
    }
    else if ([key isEqualToString:@"catchSelfRedEnvelop"]) {
        ddConfig.catchSelfRedEnvelop = sender.isOn;
    }
    else if ([key isEqualToString:@"preventMultipleCatch"]) {
        ddConfig.preventMultipleCatch = sender.isOn;
    }
    
    [ddConfig saveConfig];
}

- (void)showInputDialogForKey:(NSString *)key currentValue:(NSInteger)currentValue {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置延迟时间"
                                                                   message:@"请输入延迟时间（毫秒）"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%ld", (long)currentValue];
        textField.placeholder = @"0";
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textField = alert.textFields.firstObject;
        NSInteger value = [textField.text integerValue];
        
        DDRedEnvelopConfig *config = [DDRedEnvelopConfig sharedConfig];
        config.redEnvelopDelay = value;
        [config saveConfig];
        
        [self.tableView reloadData];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - 插件注册

// 检查并注册插件到微信插件管理系统
__attribute__((constructor)) static void registerDDRedEnvelopPlugin() {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 检查微信是否支持插件管理
        Class WCPluginsMgr = NSClassFromString(@"WCPluginsMgr");
        if (WCPluginsMgr) {
            id pluginMgr = [WCPluginsMgr performSelector:@selector(sharedInstance)];
            if (pluginMgr) {
                // 注册带设置页面的插件
                [pluginMgr performSelector:@selector(registerControllerWithTitle:version:controller:) 
                                withObject:@"DD红包" 
                                withObject:@"1.0.0" 
                                withObject:@"DDRedEnvelopSettingController"];
            }
        }
    });
}

#pragma mark - Hook微信核心类

// 声明微信类（从原文件中提取必要声明）
@class CContact, CMessageWrap, CMessageMgr, WCRedEnvelopesLogicMgr, WCPayInfoItem;
@class HongBaoRes, HongBaoReq;

@interface CContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@property(retain, nonatomic) NSString *m_nsHeadImgUrl;
- (NSString *)getContactDisplayName;
@end

@interface CMessageWrap : NSObject
@property(retain, nonatomic) NSString *m_nsContent;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(retain, nonatomic) WCPayInfoItem *m_oWCPayInfoItem;
@property(nonatomic) int m_uiMessageType;
@end

@interface WCPayInfoItem : NSObject
@property(retain, nonatomic) NSString *m_c2cNativeUrl;
@end

@interface CMessageMgr : NSObject
- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap;
@end

@interface WCRedEnvelopesLogicMgr : NSObject
- (void)OnWCToHongbaoCommonResponse:(HongBaoRes *)arg1 Request:(HongBaoReq *)arg2;
- (void)ReceiverQueryRedEnvelopesRequest:(NSDictionary *)params;
@end

@interface HongBaoRes : NSObject
@property(retain, nonatomic) NSData *retText;
@property(nonatomic) int cgiCmdid;
@end

@interface HongBaoReq : NSObject
@property(retain, nonatomic) NSData *reqText;
@end

// 工具函数
static NSDictionary *dictionaryWithDecodedComponents(NSString *str, NSString *separator) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    NSArray *components = [str componentsSeparatedByString:separator];
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

static id JSONObjectFromData(NSData *data) {
    if (!data) return nil;
    NSError *error;
    id obj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error) {
        NSLog(@"JSON解析错误: %@", error);
        return nil;
    }
    return obj;
}

#pragma mark - Hook实现

// Hook CMessageMgr 检测红包消息
%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap {
    %orig;
    
    DDRedEnvelopConfig *config = [DDRedEnvelopConfig sharedConfig];
    if (!config.autoRedEnvelop) return;
    
    // 只处理AppNode消息类型
    if (wrap.m_uiMessageType != 49) return;
    
    // 检查是否是红包消息
    NSString *content = wrap.m_nsContent;
    if (![content containsString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"]) return;
    
    // 获取联系人管理器
    Class CContactMgrClass = NSClassFromString(@"CContactMgr");
    Class MMServiceCenterClass = NSClassFromString(@"MMServiceCenter");
    if (!CContactMgrClass || !MMServiceCenterClass) return;
    
    id serviceCenter = [MMServiceCenterClass performSelector:@selector(defaultCenter)];
    CContactMgr *contactMgr = [serviceCenter getService:CContactMgrClass];
    if (!contactMgr) return;
    
    CContact *selfContact = [contactMgr getSelfContact];
    if (!selfContact) return;
    
    // 检查发送者
    BOOL isSender = [wrap.m_nsFromUsr isEqualToString:selfContact.m_nsUsrName];
    BOOL isGroupChat = [wrap.m_nsFromUsr containsString:@"@chatroom"];
    
    // 群聊过滤检查
    if (config.groupFilterEnabled && isGroupChat) {
        if ([config.filteredGroups containsObject:wrap.m_nsFromUsr]) {
            return; // 过滤该群聊
        }
    }
    
    // 是否抢自己红包检查
    if (isSender && !config.catchSelfRedEnvelop) {
        return; // 不抢自己发的红包
    }
    
    // 解析红包URL
    NSString *nativeUrl = wrap.m_oWCPayInfoItem.m_c2cNativeUrl;
    if (!nativeUrl) return;
    
    NSString *queryString = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
    NSDictionary *urlDict = dictionaryWithDecodedComponents(queryString, @"&");
    
    if (!urlDict[@"sendid"] || !urlDict[@"channelid"]) return;
    
    // 创建红包参数
    DDRedEnvelopParam *param = [[DDRedEnvelopParam alloc] init];
    param.msgType = urlDict[@"msgtype"];
    param.sendId = urlDict[@"sendid"];
    param.channelId = urlDict[@"channelid"];
    param.nickName = [selfContact getContactDisplayName];
    param.headImg = selfContact.m_nsHeadImgUrl;
    param.nativeUrl = nativeUrl;
    param.sessionUserName = isGroupChat ? wrap.m_nsFromUsr : wrap.m_nsFromUsr;
    param.sign = urlDict[@"sign"];
    param.isGroupSender = isSender && isGroupChat;
    
    // 添加到队列
    [[DDRedEnvelopParamQueue sharedQueue] enqueue:param];
    
    // 发送查询请求
    NSMutableDictionary *queryParams = [NSMutableDictionary dictionary];
    queryParams[@"agreeDuty"] = @"0";
    queryParams[@"channelId"] = param.channelId;
    queryParams[@"inWay"] = @"0";
    queryParams[@"msgType"] = param.msgType;
    queryParams[@"nativeUrl"] = param.nativeUrl;
    queryParams[@"sendId"] = param.sendId;
    
    Class WCRedEnvelopesLogicMgrClass = NSClassFromString(@"WCRedEnvelopesLogicMgr");
    if (WCRedEnvelopesLogicMgrClass) {
        WCRedEnvelopesLogicMgr *logicMgr = [serviceCenter getService:WCRedEnvelopesLogicMgrClass];
        if (logicMgr) {
            [logicMgr ReceiverQueryRedEnvelopesRequest:queryParams];
        }
    }
}

%end

// Hook WCRedEnvelopesLogicMgr 处理红包响应
%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(HongBaoRes *)arg1 Request:(HongBaoReq *)arg2 {
    %orig;
    
    DDRedEnvelopConfig *config = [DDRedEnvelopConfig sharedConfig];
    if (!config.autoRedEnvelop) return;
    
    // 只处理查询响应 (cgiCmdid == 3)
    if (arg1.cgiCmdid != 3) return;
    
    // 解析响应数据
    NSDictionary *response = JSONObjectFromData(arg1.retText);
    if (!response) return;
    
    // 检查红包状态
    if ([response[@"receiveStatus"] integerValue] == 2) return; // 已经抢过
    if ([response[@"hbStatus"] integerValue] == 4) return; // 红包已抢完
    if (!response[@"timingIdentifier"]) return; // 没有timingIdentifier
    
    // 从队列获取参数
    DDRedEnvelopParam *param = [[DDRedEnvelopParamQueue sharedQueue] dequeue];
    if (!param) return;
    
    param.timingIdentifier = response[@"timingIdentifier"];
    
    // 计算延迟时间
    NSTimeInterval delay = 0;
    if (config.redEnvelopDelayEnabled) {
        delay = config.redEnvelopDelay / 1000.0;
    }
    
    // 创建抢红包任务
    void (^openRedEnvelopTask)(void) = ^{
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            NSMutableDictionary *openParams = [NSMutableDictionary dictionary];
            openParams[@"agreeDuty"] = @"0";
            openParams[@"channelId"] = param.channelId;
            openParams[@"inWay"] = @"0";
            openParams[@"msgType"] = param.msgType;
            openParams[@"nativeUrl"] = param.nativeUrl;
            openParams[@"sendId"] = param.sendId;
            openParams[@"timingIdentifier"] = param.timingIdentifier;
            
            [self OpenRedEnvelopesRequest:openParams];
        });
    };
    
    // 根据设置选择任务执行方式
    if (config.preventMultipleCatch) {
        [[DDRedEnvelopTaskManager sharedManager] addSerialTask:openRedEnvelopTask];
    } else {
        [[DDRedEnvelopTaskManager sharedManager] addNormalTask:openRedEnvelopTask];
    }
}

%end