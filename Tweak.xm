#import <UIKit/UIKit.h>

// 配置类
@interface WCPLRedEnvelopConfig : NSObject
@property (nonatomic, assign) BOOL autoReceiveEnable;
@property (nonatomic, assign) BOOL serialReceive;
@property (nonatomic, assign) NSInteger delaySeconds;
@property (nonatomic, assign) BOOL receiveSelfRedEnvelop;
@property (nonatomic, assign) BOOL personalRedEnvelopEnable;
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
        config.delaySeconds = 0;
        config.receiveSelfRedEnvelop = YES;
        config.personalRedEnvelopEnable = YES;
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

// 参数队列
@interface WCPLRedEnvelopParamQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(WeChatRedEnvelopParam *)param;
- (WeChatRedEnvelopParam *)dequeue;
- (WeChatRedEnvelopParam *)peek;
- (BOOL)isEmpty;
@end

@implementation WCPLRedEnvelopParamQueue {
    NSMutableArray *_queue;
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
    if (_queue.count == 0) return nil;
    WeChatRedEnvelopParam *first = _queue.firstObject;
    [_queue removeObjectAtIndex:0];
    return first;
}

- (WeChatRedEnvelopParam *)peek {
    return _queue.firstObject;
}

- (BOOL)isEmpty {
    return _queue.count == 0;
}
@end

// 任务管理器
@interface WCPLRedEnvelopTaskManager : NSObject
@property (nonatomic, assign, readonly) BOOL serialQueueIsEmpty;
+ (instancetype)sharedManager;
- (void)addSerialTask:(id)task;
- (void)addNormalTask:(id)task;
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

- (void)addSerialTask:(id)task {
    // 实现串行任务添加逻辑
}

- (void)addNormalTask:(id)task {
    // 实现普通任务添加逻辑
}
@end

// 红包操作类
@interface WCPLReceiveRedEnvelopOperation : NSObject
- (instancetype)initWithRedEnvelopParam:(WeChatRedEnvelopParam *)param delay:(unsigned int)delaySeconds;
@end

@implementation WCPLReceiveRedEnvelopOperation
- (instancetype)initWithRedEnvelopParam:(WeChatRedEnvelopParam *)param delay:(unsigned int)delaySeconds {
    return [super init];
}
@end

// 设置界面控制器
@interface DDRedEnvelopSettingsController : UIViewController
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *settings;
@end

@implementation DDRedEnvelopSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD红包设置";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    [self setupNavigationBar];
    [self setupTableView];
}

- (void)setupNavigationBar {
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"关闭" 
                                                                   style:UIBarButtonItemStylePlain
                                                                  target:self 
                                                                  action:@selector(closeSettings)];
    self.navigationItem.rightBarButtonItem = closeButton;
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (void)closeSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 4;
    if (section == 1) return 2;
    return 1;
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
                cell.textLabel.text = @"延迟抢红包";
                UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 30)];
                label.text = [NSString stringWithFormat:@"%ld秒", (long)config.delaySeconds];
                label.textAlignment = NSTextAlignmentRight;
                cell.accessoryView = label;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            }
            case 2: {
                cell.textLabel.text = @"串行抢红包";
                UISwitch *switchView = [[UISwitch alloc] init];
                switchView.on = config.serialReceive;
                [switchView addTarget:self action:@selector(serialReceiveSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = switchView;
                break;
            }
            case 3: {
                cell.textLabel.text = @"抢自己发的红包";
                UISwitch *switchView = [[UISwitch alloc] init];
                switchView.on = config.receiveSelfRedEnvelop;
                [switchView addTarget:self action:@selector(receiveSelfSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = switchView;
                break;
            }
        }
    } else if (indexPath.section == 1) {
        switch (indexPath.row) {
            case 0: {
                cell.textLabel.text = @"个人红包";
                UISwitch *switchView = [[UISwitch alloc] init];
                switchView.on = config.personalRedEnvelopEnable;
                [switchView addTarget:self action:@selector(personalSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                cell.accessoryView = switchView;
                break;
            }
            case 1: {
                cell.textLabel.text = @"黑名单";
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            }
        }
    } else {
        cell.textLabel.text = @"关于";
        cell.textLabel.textColor = [UIColor systemBlueColor];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"抢红包设置";
    if (section == 1) return @"其他设置";
    return @"";
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 0) return @"自动抢红包开启后，收到红包消息时会自动领取";
    if (section == 1) return @"黑名单中的群聊不会自动抢红包";
    return @"DD红包 v1.0.0";
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0 && indexPath.row == 1) {
        [self showDelaySetting];
    } else if (indexPath.section == 1 && indexPath.row == 1) {
        [self showBlackList];
    } else if (indexPath.section == 2) {
        [self showAbout];
    }
}

#pragma mark - Actions

- (void)autoReceiveSwitchChanged:(UISwitch *)sender {
    [WCPLRedEnvelopConfig sharedConfig].autoReceiveEnable = sender.on;
}

- (void)serialReceiveSwitchChanged:(UISwitch *)sender {
    [WCPLRedEnvelopConfig sharedConfig].serialReceive = sender.on;
}

- (void)receiveSelfSwitchChanged:(UISwitch *)sender {
    [WCPLRedEnvelopConfig sharedConfig].receiveSelfRedEnvelop = sender.on;
}

- (void)personalSwitchChanged:(UISwitch *)sender {
    [WCPLRedEnvelopConfig sharedConfig].personalRedEnvelopEnable = sender.on;
}

- (void)showDelaySetting {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"延迟时间"
                                                                   message:@"设置抢红包延迟时间（秒）"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.placeholder = @"输入延迟秒数";
        textField.text = [NSString stringWithFormat:@"%ld", (long)[WCPLRedEnvelopConfig sharedConfig].delaySeconds];
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSInteger delay = [alert.textFields.firstObject.text integerValue];
        [WCPLRedEnvelopConfig sharedConfig].delaySeconds = delay;
        [self.tableView reloadData];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showBlackList {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"黑名单"
                                                                   message:@"输入群聊ID（每行一个）"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(10, 50, 250, 100)];
    textView.backgroundColor = [UIColor systemGray6Color];
    textView.text = [[WCPLRedEnvelopConfig sharedConfig].blackList componentsJoinedByString:@"\n"];
    [alert.view addSubview:textView];
    
    alert.view.frame = CGRectMake(0, 0, 270, 200);
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = textView.text;
        NSArray *blackList = [text componentsSeparatedByString:@"\n"];
        [WCPLRedEnvelopConfig sharedConfig].blackList = blackList;
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAbout {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"DD红包"
                                                                   message:@"版本：1.0.0\n\n功能：自动抢微信红包"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

// Hook 逻辑
%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig;
    
    // 非参数查询请求
    if ([arg1 cgiCmdid] != 3) { return; }
    
    NSString *(^parseRequestSign)() = ^NSString *() {
        NSString *requestString = [[NSString alloc] initWithData:[arg2 reqText].buffer encoding:NSUTF8StringEncoding];
        NSDictionary *requestDictionary = [%c(WCBizUtil) dictionaryWithDecodedComponets:requestString separator:@"&"];
        NSString *nativeUrl = [[requestDictionary objectForKey:@"nativeUrl"] stringByRemovingPercentEncoding];
        NSDictionary *nativeUrlDict = [%c(WCBizUtil) dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
        
        return [nativeUrlDict objectForKey:@"sign"];
    };
    
    NSDictionary *responseDict = [[[NSString alloc] initWithData:[arg1 retText].buffer encoding:NSUTF8StringEncoding] JSONDictionary];
    
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
        
        if (mgrParams.isGroupSender) { 
            // 自己发红包的时候没有 sign 字段
            return [WCPLRedEnvelopConfig sharedConfig].autoReceiveEnable;
        } else {
            return [parseRequestSign() isEqualToString:mgrParams.sign] && [WCPLRedEnvelopConfig sharedConfig].autoReceiveEnable;
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
            serialDelaySeconds = configDelaySeconds;
        } else {
            serialDelaySeconds = 5;
        }
        
        return serialDelaySeconds;
    } else {
        return (unsigned int)configDelaySeconds;
    }
}

%end

%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(id)wrap {
    %orig;
    
    switch([wrap m_uiMessageType]) {
        case 49: { // AppNode
            /** 是否为红包消息 */
            BOOL (^isRedEnvelopMessage)() = ^BOOL() {
                return [[wrap m_nsContent] rangeOfString:@"wxpay://"].location != NSNotFound;
            };
            
            if (isRedEnvelopMessage()) { // 红包
                CContactMgr *contactManager = [[%c(MMServiceCenter) defaultCenter] getService:[%c(CContactMgr) class]];
                CContact *selfContact = [contactManager getSelfContact];
                
                BOOL (^isSender)() = ^BOOL() {
                    return [[wrap m_nsFromUsr] isEqualToString:[selfContact m_nsUsrName]];
                };
                
                /** 是否别人在群聊中发消息 */
                BOOL (^isGroupReceiver)() = ^BOOL() {
                    return [[wrap m_nsFromUsr] rangeOfString:@"@chatroom"].location != NSNotFound;
                };
                
                /** 是否自己在群聊中发消息 */
                BOOL (^isGroupSender)() = ^BOOL() {
                    return isSender() && [[wrap m_nsToUsr] rangeOfString:@"chatroom"].location != NSNotFound;
                };
                
                /** 是否抢自己发的红包 */
                BOOL (^isReceiveSelfRedEnvelop)() = ^BOOL() {
                    return [WCPLRedEnvelopConfig sharedConfig].receiveSelfRedEnvelop;
                };
                
                /** 是否在黑名单中 */
                BOOL (^isGroupInBlackList)() = ^BOOL() {
                    return [[WCPLRedEnvelopConfig sharedConfig].blackList containsObject:[wrap m_nsFromUsr]];
                };
                
                /** 是否自动抢红包 */
                BOOL (^shouldReceiveRedEnvelop)() = ^BOOL() {
                    if (![WCPLRedEnvelopConfig sharedConfig].autoReceiveEnable) { return NO; }
                    if (isGroupInBlackList()) { return NO; }
                    
                    return isGroupReceiver() || 
                           (isGroupSender() && isReceiveSelfRedEnvelop()) ||
                           (!isGroupReceiver() && !isGroupSender() && [WCPLRedEnvelopConfig sharedConfig].personalRedEnvelopEnable); 
                };
                
                if (shouldReceiveRedEnvelop()) {
                    // 解析红包参数并加入队列
                    NSString *nativeUrl = [[wrap m_nsContent] substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
                    NSDictionary *nativeUrlDict = [%c(WCBizUtil) dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
                    
                    WeChatRedEnvelopParam *param = [[WeChatRedEnvelopParam alloc] init];
                    param.msgType = nativeUrlDict[@"msgtype"];
                    param.sendId = nativeUrlDict[@"sendid"];
                    param.channelId = nativeUrlDict[@"channelid"];
                    param.nickName = [selfContact getContactDisplayName];
                    param.headImg = [selfContact m_nsHeadImgUrl];
                    param.nativeUrl = [wrap m_nsContent];
                    param.sessionUserName = isGroupSender() ? [wrap m_nsToUsr] : [wrap m_nsFromUsr];
                    param.sign = nativeUrlDict[@"sign"];
                    param.isGroupSender = isGroupSender();
                    
                    [[WCPLRedEnvelopParamQueue sharedQueue] enqueue:param];
                    
                    // 触发抢红包
                    WCRedEnvelopesLogicMgr *logicMgr = [[%c(MMServiceCenter) defaultCenter] getService:[%c(WCRedEnvelopesLogicMgr) class]];
                    [logicMgr OpenRedEnvelopesRequest:param];
                }
            }
            break;
        }
    }
}

%end

// 插件入口
%ctor {
    if (NSClassFromString(@"WCPluginsMgr")) {
        // 注册带设置页面的插件
        [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD红包" 
                                                                           version:@"1.0.0" 
                                                                       controller:@"DDRedEnvelopSettingsController"];
    }
}