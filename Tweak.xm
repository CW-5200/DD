#import <UIKit/UIKit.h>

// 从头文件获取正确的类型定义
typedef NS_ENUM(NSInteger, MessageType) {
    MessageTypeAppNode = 49
};

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

// 红包参数类 - 根据头文件调整
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
@interface DDRedEnvelopSettingsController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
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
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"Cell"];
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.textLabel.text = @"";
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    
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
                label.textColor = [UIColor secondaryLabelColor];
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
        [WCPLRedEnvelopConfig sharedConfig].delaySeconds = MAX(0, delay);
        [self.tableView reloadData];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showBlackList {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"黑名单"
                                                                   message:@"输入群聊ID（每行一个）"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UIViewController *contentVC = [[UIViewController alloc] init];
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(10, 10, 250, 150)];
    textView.backgroundColor = [UIColor systemGray6Color];
    textView.font = [UIFont systemFontOfSize:14];
    textView.text = [[WCPLRedEnvelopConfig sharedConfig].blackList componentsJoinedByString:@"\n"];
    [contentVC.view addSubview:textView];
    
    [alert setValue:contentVC forKey:@"contentViewController"];
    
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
    NSInteger cgiCmdid = (NSInteger)[arg1 performSelector:@selector(cgiCmdid)];
    if (cgiCmdid != 3) { return; }
    
    // 解析请求签名
    NSString *(^parseRequestSign)(void) = ^NSString *{
        id reqText = [arg2 performSelector:@selector(reqText)];
        NSData *bufferData = [reqText performSelector:@selector(buffer)];
        NSString *requestString = [[NSString alloc] initWithData:bufferData encoding:NSUTF8StringEncoding];
        
        // 使用WCBizUtil解析
        Class WCBizUtil = objc_getClass("WCBizUtil");
        if (!WCBizUtil) return nil;
        
        NSDictionary *requestDictionary = [WCBizUtil performSelector:@selector(dictionaryWithDecodedComponets:separator:) 
                                                          withObject:requestString 
                                                          withObject:@"&"];
        NSString *nativeUrl = [[requestDictionary objectForKey:@"nativeUrl"] stringByRemovingPercentEncoding];
        if (!nativeUrl) return nil;
        
        NSDictionary *nativeUrlDict = [WCBizUtil performSelector:@selector(dictionaryWithDecodedComponets:separator:) 
                                                      withObject:nativeUrl 
                                                      withObject:@"&"];
        return [nativeUrlDict objectForKey:@"sign"];
    };
    
    // 解析响应数据
    id retText = [arg1 performSelector:@selector(retText)];
    NSData *responseData = [retText performSelector:@selector(buffer)];
    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    
    // 解析JSON响应
    NSDictionary *responseDict = nil;
    if (responseString) {
        NSError *error = nil;
        responseDict = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] 
                                                       options:0 
                                                         error:&error];
    }
    
    if (!responseDict) return;
    
    // 从队列中获取红包参数
    WeChatRedEnvelopParam *mgrParams = [[WCPLRedEnvelopParamQueue sharedQueue] dequeue];
    if (!mgrParams) return;
    
    // 检查是否应该抢红包
    BOOL shouldReceiveRedEnvelop = NO;
    
    // 检查接收状态
    NSInteger receiveStatus = [responseDict[@"receiveStatus"] integerValue];
    NSInteger hbStatus = [responseDict[@"hbStatus"] integerValue];
    NSString *timingIdentifier = responseDict[@"timingIdentifier"];
    
    if (receiveStatus == 2) return; // 自己已经抢过
    if (hbStatus == 4) return;      // 红包被抢完
    if (!timingIdentifier) return;  // 没有timingIdentifier会被判定为使用外挂
    
    BOOL autoReceiveEnable = [WCPLRedEnvelopConfig sharedConfig].autoReceiveEnable;
    if (!autoReceiveEnable) return;
    
    if (mgrParams.isGroupSender) {
        // 自己发红包的时候没有 sign 字段
        shouldReceiveRedEnvelop = YES;
    } else {
        NSString *requestSign = parseRequestSign();
        shouldReceiveRedEnvelop = [requestSign isEqualToString:mgrParams.sign];
    }
    
    if (shouldReceiveRedEnvelop) {
        mgrParams.timingIdentifier = timingIdentifier;
        
        // 计算延迟
        unsigned int delaySeconds = 0;
        if ([WCPLRedEnvelopConfig sharedConfig].serialReceive) {
            if ([WCPLRedEnvelopTaskManager sharedManager].serialQueueIsEmpty) {
                delaySeconds = (unsigned int)[WCPLRedEnvelopConfig sharedConfig].delaySeconds;
            } else {
                delaySeconds = 5;
            }
        } else {
            delaySeconds = (unsigned int)[WCPLRedEnvelopConfig sharedConfig].delaySeconds;
        }
        
        // 创建抢红包操作
        WCPLReceiveRedEnvelopOperation *operation = [[WCPLReceiveRedEnvelopOperation alloc] initWithRedEnvelopParam:mgrParams delay:delaySeconds];
        
        // 添加到任务管理器
        if ([WCPLRedEnvelopConfig sharedConfig].serialReceive) {
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
    
    // 检查消息类型是否为AppNode（红包消息）
    NSUInteger messageType = (NSUInteger)[wrap m_uiMessageType];
    if (messageType != 49) { // AppNode类型
        return;
    }
    
    // 检查是否为红包消息
    NSString *content = [wrap m_nsContent];
    if (![content containsString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"]) {
        return;
    }
    
    // 获取自己的联系人信息
    Class MMServiceCenter = objc_getClass("MMServiceCenter");
    Class CContactMgr = objc_getClass("CContactMgr");
    
    if (!MMServiceCenter || !CContactMgr) return;
    
    MMServiceCenter *serviceCenter = [MMServiceCenter performSelector:@selector(defaultCenter)];
    CContactMgr *contactMgr = [serviceCenter getService:CContactMgr];
    CContact *selfContact = [contactMgr getSelfContact];
    
    if (!selfContact) return;
    
    // 解析消息相关信息
    NSString *fromUsr = [wrap m_nsFromUsr];
    NSString *toUsr = [wrap m_nsToUsr];
    NSString *selfUsrName = [selfContact m_nsUsrName];
    
    // 判断消息发送者
    BOOL isSender = [fromUsr isEqualToString:selfUsrName];
    BOOL isGroupReceiver = [fromUsr containsString:@"@chatroom"];
    BOOL isGroupSender = isSender && [toUsr containsString:@"chatroom"];
    
    // 检查是否在黑名单中
    BOOL isGroupInBlackList = [[WCPLRedEnvelopConfig sharedConfig].blackList containsObject:fromUsr];
    
    // 检查是否应该抢红包
    BOOL shouldReceiveRedEnvelop = NO;
    
    if (![WCPLRedEnvelopConfig sharedConfig].autoReceiveEnable) {
        return;
    }
    
    if (isGroupInBlackList) {
        return;
    }
    
    // 判断抢红包条件
    WCPLRedEnvelopConfig *config = [WCPLRedEnvelopConfig sharedConfig];
    
    if (isGroupReceiver) {
        // 群聊中别人发的红包
        shouldReceiveRedEnvelop = YES;
    } else if (isGroupSender && config.receiveSelfRedEnvelop) {
        // 群聊中自己发的红包
        shouldReceiveRedEnvelop = YES;
    } else if (!isGroupReceiver && !isGroupSender && config.personalRedEnvelopEnable) {
        // 个人红包
        shouldReceiveRedEnvelop = YES;
    }
    
    if (!shouldReceiveRedEnvelop) {
        return;
    }
    
    // 解析红包参数
    NSString *nativeUrl = content;
    if ([nativeUrl hasPrefix:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"]) {
        nativeUrl = [nativeUrl substringFromIndex:53]; // 移除前缀
    }
    
    // 使用WCBizUtil解析URL参数
    Class WCBizUtil = objc_getClass("WCBizUtil");
    if (!WCBizUtil) return;
    
    NSDictionary *nativeUrlDict = [WCBizUtil performSelector:@selector(dictionaryWithDecodedComponets:separator:) 
                                                  withObject:nativeUrl 
                                                  withObject:@"&"];
    
    if (!nativeUrlDict) return;
    
    // 创建红包参数对象
    WeChatRedEnvelopParam *param = [[WeChatRedEnvelopParam alloc] init];
    param.msgType = nativeUrlDict[@"msgtype"];
    param.sendId = nativeUrlDict[@"sendid"];
    param.channelId = nativeUrlDict[@"channelid"];
    param.nickName = [selfContact getContactDisplayName];
    param.headImg = [selfContact m_nsHeadImgUrl];
    param.nativeUrl = [wrap m_nsContent];
    param.sessionUserName = isGroupSender ? toUsr : fromUsr;
    param.sign = nativeUrlDict[@"sign"];
    param.isGroupSender = isGroupSender;
    
    // 将参数加入队列
    [[WCPLRedEnvelopParamQueue sharedQueue] enqueue:param];
    
    // 触发抢红包请求
    Class WCRedEnvelopesLogicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
    if (WCRedEnvelopesLogicMgrClass) {
        MMServiceCenter *serviceCenter = [MMServiceCenter performSelector:@selector(defaultCenter)];
        id logicMgr = [serviceCenter getService:WCRedEnvelopesLogicMgrClass];
        if (logicMgr && [logicMgr respondsToSelector:@selector(OpenRedEnvelopesRequest:)]) {
            [logicMgr OpenRedEnvelopesRequest:param];
        }
    }
}

%end

// 插件入口
%ctor {
    // 检查插件管理器是否存在
    Class WCPluginsMgr = objc_getClass("WCPluginsMgr");
    if (WCPluginsMgr) {
        // 使用安全的方式调用
        id sharedInstance = [WCPluginsMgr performSelector:@selector(sharedInstance)];
        if (sharedInstance) {
            // 注册带设置页面的插件
            [sharedInstance performSelector:@selector(registerControllerWithTitle:version:controller:) 
                                 withObject:@"DD红包" 
                                 withObject:@"1.0.0" 
                                 withObject:@"DDRedEnvelopSettingsController"];
        }
    }
    
    NSLog(@"DD红包插件已加载 v1.0.0");
}