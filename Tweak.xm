//
//  DDAssistant.xm
//  DD助手 - 微信功能增强插件
//  支持iOS 15.0+
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CaptainHook/CaptainHook.h>

// 插件配置
@interface DDAssistantConfig : NSObject
@property (nonatomic, assign) BOOL autoRedEnvelopEnabled;
@property (nonatomic, assign) BOOL timelineForwardEnabled;
@property (nonatomic, assign) BOOL likeCommentEnabled;
@property (nonatomic, strong) NSNumber *likeCount;
@property (nonatomic, strong) NSNumber *commentCount;
@property (nonatomic, strong) NSString *comments;

+ (instancetype)sharedConfig;
- (void)saveSettings;
@end

@implementation DDAssistantConfig

+ (instancetype)sharedConfig {
    static DDAssistantConfig *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        [sharedInstance loadSettings];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _autoRedEnvelopEnabled = YES;
        _timelineForwardEnabled = YES;
        _likeCommentEnabled = YES;
        _likeCount = @10;
        _commentCount = @5;
        _comments = @"赞,,👍,,太棒了";
    }
    return self;
}

- (void)loadSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _autoRedEnvelopEnabled = [defaults boolForKey:@"DDAssistantAutoRedEnvelop"] ?: YES;
    _timelineForwardEnabled = [defaults boolForKey:@"DDAssistantTimelineForward"] ?: YES;
    _likeCommentEnabled = [defaults boolForKey:@"DDAssistantLikeComment"] ?: YES;
    _likeCount = [defaults objectForKey:@"DDAssistantLikeCount"] ?: @10;
    _commentCount = [defaults objectForKey:@"DDAssistantCommentCount"] ?: @5;
    _comments = [defaults stringForKey:@"DDAssistantComments"] ?: @"赞,,👍,,太棒了";
}

- (void)saveSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:_autoRedEnvelopEnabled forKey:@"DDAssistantAutoRedEnvelop"];
    [defaults setBool:_timelineForwardEnabled forKey:@"DDAssistantTimelineForward"];
    [defaults setBool:_likeCommentEnabled forKey:@"DDAssistantLikeComment"];
    [defaults setObject:_likeCount forKey:@"DDAssistantLikeCount"];
    [defaults setObject:_commentCount forKey:@"DDAssistantCommentCount"];
    [defaults setObject:_comments forKey:@"DDAssistantComments"];
    [defaults synchronize];
}

@end

// 设置界面控制器
@interface DDAssistantSettingController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
    UITableView *_tableView;
}

@end

@implementation DDAssistantSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"DD助手设置";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    // 创建表格
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tableView];
    
    // 导航栏按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(closeSettings)];
    self.navigationItem.rightBarButtonItem = closeButton;
}

- (void)closeSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1; // 自动抢红包
        case 1: return 1; // 朋友圈转发
        case 2: return 4; // 集赞助手
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"自动抢红包";
        case 1: return @"朋友圈功能";
        case 2: return @"集赞助手";
        default: return @"";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"Cell"];
    }
    
    DDAssistantConfig *config = [DDAssistantConfig sharedConfig];
    
    switch (indexPath.section) {
        case 0: {
            cell.textLabel.text = @"自动抢红包";
            UISwitch *switchView = [[UISwitch alloc] init];
            switchView.on = config.autoRedEnvelopEnabled;
            [switchView addTarget:self action:@selector(autoRedEnvelopSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = switchView;
            cell.detailTextLabel.text = @"自动抢红包功能";
            break;
        }
            
        case 1: {
            cell.textLabel.text = @"朋友圈转发";
            UISwitch *switchView = [[UISwitch alloc] init];
            switchView.on = config.timelineForwardEnabled;
            [switchView addTarget:self action:@selector(timelineForwardSwitchChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = switchView;
            cell.detailTextLabel.text = @"启用朋友圈转发功能";
            break;
        }
            
        case 2: {
            switch (indexPath.row) {
                case 0:
                    cell.textLabel.text = @"集赞助手";
                    cell.detailTextLabel.text = @"自动点赞和评论";
                    {
                        UISwitch *switchView = [[UISwitch alloc] init];
                        switchView.on = config.likeCommentEnabled;
                        [switchView addTarget:self action:@selector(likeCommentSwitchChanged:) forControlEvents:UIControlEventValueChanged];
                        cell.accessoryView = switchView;
                    }
                    break;
                    
                case 1:
                    cell.textLabel.text = @"点赞数量";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", config.likeCount];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    break;
                    
                case 2:
                    cell.textLabel.text = @"评论数量";
                    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", config.commentCount];
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    break;
                    
                case 3:
                    cell.textLabel.text = @"评论内容";
                    cell.detailTextLabel.text = config.comments;
                    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                    break;
            }
            break;
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 2) {
        DDAssistantConfig *config = [DDAssistantConfig sharedConfig];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置" message:@"" preferredStyle:UIAlertControllerStyleAlert];
        
        switch (indexPath.row) {
            case 1: {
                alert.title = @"设置点赞数量";
                [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                    textField.text = [config.likeCount stringValue];
                    textField.keyboardType = UIKeyboardTypeNumberPad;
                }];
                [self addSaveActionToAlert:alert forType:1];
                break;
            }
                
            case 2: {
                alert.title = @"设置评论数量";
                [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                    textField.text = [config.commentCount stringValue];
                    textField.keyboardType = UIKeyboardTypeNumberPad;
                }];
                [self addSaveActionToAlert:alert forType:2];
                break;
            }
                
            case 3: {
                alert.title = @"设置评论内容";
                [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                    textField.text = config.comments;
                }];
                [self addSaveActionToAlert:alert forType:3];
                break;
            }
        }
        
        if (alert.actions.count > 0) {
            [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
}

- (void)addSaveActionToAlert:(UIAlertController *)alert forType:(NSInteger)type {
    [alert addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textField = alert.textFields.firstObject;
        DDAssistantConfig *config = [DDAssistantConfig sharedConfig];
        
        switch (type) {
            case 1:
                config.likeCount = @([textField.text integerValue]);
                break;
            case 2:
                config.commentCount = @([textField.text integerValue]);
                break;
            case 3:
                config.comments = textField.text;
                break;
        }
        
        [config saveSettings];
        [self->_tableView reloadData];
    }]];
}

#pragma mark - Switch Actions

- (void)autoRedEnvelopSwitchChanged:(UISwitch *)sender {
    [DDAssistantConfig sharedConfig].autoRedEnvelopEnabled = sender.on;
    [[DDAssistantConfig sharedConfig] saveSettings];
}

- (void)timelineForwardSwitchChanged:(UISwitch *)sender {
    [DDAssistantConfig sharedConfig].timelineForwardEnabled = sender.on;
    [[DDAssistantConfig sharedConfig] saveSettings];
}

- (void)likeCommentSwitchChanged:(UISwitch *)sender {
    [DDAssistantConfig sharedConfig].likeCommentEnabled = sender.on;
    [[DDAssistantConfig sharedConfig] saveSettings];
}

@end

// 插件管理器接口
CHDeclareClass(WCPluginsMgr);

// 微信类声明
CHDeclareClass(CMessageMgr);
CHDeclareClass(WCRedEnvelopesLogicMgr);
CHDeclareClass(WCOperateFloatView);
CHDeclareClass(WCTimelineMgr);
CHDeclareClass(WCDataItem);
CHDeclareClass(CContactMgr);

// 自动抢红包逻辑
CHMethod2(void, CMessageMgr, onNewSyncAddMessage, id, arg1) {
    CHSuper2(CMessageMgr, onNewSyncAddMessage, arg1);
    
    DDAssistantConfig *config = [DDAssistantConfig sharedConfig];
    if (!config.autoRedEnvelopEnabled) return;
    
    // 红包消息处理逻辑（基于文档2中的实现）
    if ([arg1 isKindOfClass:objc_getClass("CMessageWrap")]) {
        id msgWrap = arg1;
        NSInteger msgType = [msgWrap m_uiMessageType];
        
        if (msgType == 49) { // AppNode消息类型，包含红包
            NSString *content = [msgWrap m_nsContent];
            if ([content containsString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao"]) {
                NSLog(@"[DD助手] 检测到红包消息");
                // 这里实现自动抢红包逻辑
                [self handleRedEnvelopMessage:msgWrap];
            }
        }
    }
}

CHOptimizedMethod1(self, void, CMessageMgr, handleRedEnvelopMessage, id, msgWrap) {
    // 实现红包处理逻辑
    DDAssistantConfig *config = [DDAssistantConfig sharedConfig];
    if (!config.autoRedEnvelopEnabled) return;
    
    // 获取红包参数
    NSString *nativeUrl = [[[msgWrap m_oWCPayInfoItem] m_c2cNativeUrl] stringByRemovingPercentEncoding];
    if (!nativeUrl) return;
    
    // 解析红包参数
    NSDictionary *params = [self parseRedEnvelopParams:nativeUrl];
    if (!params) return;
    
    NSLog(@"[DD助手] 准备抢红包，参数: %@", params);
    
    // 调用抢红包逻辑
    [self queryRedEnvelopWithParams:params messageWrap:msgWrap];
}

CHOptimizedMethod1(self, NSDictionary *, CMessageMgr, parseRedEnvelopParams, NSString *, nativeUrl) {
    // 解析红包URL参数
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    NSArray *components = [nativeUrl componentsSeparatedByString:@"&"];
    for (NSString *component in components) {
        NSArray *keyValue = [component componentsSeparatedByString:@"="];
        if (keyValue.count == 2) {
            params[keyValue[0]] = keyValue[1];
        }
    }
    
    return params.count > 0 ? params : nil;
}

CHOptimizedMethod2(self, void, CMessageMgr, queryRedEnvelopWithParams, NSDictionary *, params, messageWrap, id, msgWrap) {
    // 查询红包详情并抢红包
    Class redEnvelopLogicMgr = objc_getClass("WCRedEnvelopesLogicMgr");
    if (redEnvelopLogicMgr) {
        // 构造查询参数
        NSMutableDictionary *queryParams = [NSMutableDictionary dictionary];
        queryParams[@"agreeDuty"] = @"0";
        queryParams[@"channelId"] = params[@"channelid"] ?: @"";
        queryParams[@"inWay"] = @"0";
        queryParams[@"msgType"] = params[@"msgtype"] ?: @"1";
        queryParams[@"nativeUrl"] = [[msgWrap m_oWCPayInfoItem] m_c2cNativeUrl];
        queryParams[@"sendId"] = params[@"sendid"] ?: @"";
        
        // 执行查询
        id logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:redEnvelopLogicMgr];
        if ([logicMgr respondsToSelector:@selector(ReceiverQueryRedEnvelopesRequest:)]) {
            [logicMgr ReceiverQueryRedEnvelopesRequest:queryParams];
            NSLog(@"[DD助手] 已发送红包查询请求");
        }
    }
}

// 朋友圈转发功能
CHMethod2(void, WCOperateFloatView, showWithItemData, id, arg1, tipPoint, struct CGPoint, arg2) {
    CHSuper2(WCOperateFloatView, showWithItemData, arg1, tipPoint, arg2);
    
    DDAssistantConfig *config = [DDAssistantConfig sharedConfig];
    if (!config.timelineForwardEnabled) return;
    
    // 添加转发按钮
    [self addForwardButtonToFloatView];
}

CHOptimizedMethod0(self, void, WCOperateFloatView, addForwardButtonToFloatView) {
    // 创建转发按钮
    UIButton *forwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [forwardButton setTitle:@"转发" forState:UIControlStateNormal];
    [forwardButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
    [forwardButton addTarget:self action:@selector(forwardTimelineItem) forControlEvents:UIControlEventTouchUpInside];
    
    // 调整浮窗布局以容纳转发按钮
    [self adjustFloatViewLayoutForForwardButton:forwardButton];
}

CHOptimizedMethod1(self, void, WCOperateFloatView, adjustFloatViewLayoutForForwardButton, UIButton *, forwardButton) {
    // 调整布局逻辑
    UIView *contentView = [self valueForKey:@"m_contentView"];
    if (contentView) {
        forwardButton.frame = CGRectMake(0, 0, 60, 30);
        [contentView addSubview:forwardButton];
    }
}

CHMethod0(self, void, WCOperateFloatView, forwardTimelineItem) {
    DDAssistantConfig *config = [DDAssistantConfig sharedConfig];
    if (!config.timelineForwardEnabled) return;
    
    // 获取当前朋友圈项
    id dataItem = [self valueForKey:@"m_item"];
    if (!dataItem) return;
    
    // 创建转发控制器
    Class forwardClass = objc_getClass("WCForwardViewController");
    if (forwardClass) {
        id forwardVC = [[forwardClass alloc] initWithDataItem:dataItem];
        if (forwardVC) {
            // 获取当前导航控制器并推送
            UINavigationController *navController = [self valueForKey:@"navigationController"];
            if (navController) {
                [navController pushViewController:forwardVC animated:YES];
            }
        }
    }
    
    [self hide];
}

// 集赞助手功能
CHMethod2(void, WCTimelineMgr, modifyDataItem, id, arg1, notify, BOOL, arg2) {
    CHSuper2(WCTimelineMgr, modifyDataItem, arg1, notify, arg2);
    
    DDAssistantConfig *config = [DDAssistantConfig sharedConfig];
    if (!config.likeCommentEnabled) return;
    
    if ([arg1 isKindOfClass:objc_getClass("WCDataItem")]) {
        WCDataItem *dataItem = (WCDataItem *)arg1;
        
        // 检查是否是需要集赞的朋友圈
        if ([self shouldAutoLikeComment:dataItem]) {
            [self autoLikeAndComment:dataItem];
        }
    }
}

CHOptimizedMethod1(self, BOOL, WCTimelineMgr, shouldAutoLikeComment, id, dataItem) {
    // 判断是否应该自动点赞评论
    // 这里可以根据需要添加更复杂的判断逻辑
    return YES;
}

CHOptimizedMethod1(self, void, WCTimelineMgr, autoLikeAndComment, id, dataItem) {
    DDAssistantConfig *config = [DDAssistantConfig sharedConfig];
    
    // 自动点赞
    if (config.likeCount.integerValue > 0) {
        [self autoLikeDataItem:dataItem count:config.likeCount.integerValue];
    }
    
    // 自动评论
    if (config.commentCount.integerValue > 0 && config.comments.length > 0) {
        [self autoCommentDataItem:dataItem count:config.commentCount.integerValue comments:config.comments];
    }
}

CHOptimizedMethod2(self, void, WCTimelineMgr, autoLikeDataItem, id, dataItem, count, NSInteger, count) {
    // 实现自动点赞逻辑
    NSLog(@"[DD助手] 自动点赞 %ld 次", (long)count);
    
    // 这里需要调用微信的点赞接口
    // 由于微信内部实现复杂，这里简化处理
    if ([dataItem respondsToSelector:@selector(setLikeFlag:)]) {
        [dataItem setLikeFlag:YES];
    }
}

CHOptimizedMethod3(self, void, WCTimelineMgr, autoCommentDataItem, id, dataItem, count, NSInteger, count, comments, NSString *, comments) {
    // 实现自动评论逻辑
    NSLog(@"[DD助手] 自动评论 %ld 次，内容: %@", (long)count, comments);
    
    // 解析评论内容
    NSArray *commentArray = [comments componentsSeparatedByString:@",,"];
    
    // 这里需要调用微信的评论接口
    // 由于微信内部实现复杂，这里简化处理
}

// 获取好友列表（用于集赞助手）
CHMethod0(self, NSArray *, CContactMgr, getAllFriendContacts) {
    NSArray *friends = CHSuper0(self, CContactMgr, getAllFriendContacts);
    
    DDAssistantConfig *config = [DDAssistantConfig sharedConfig];
    if (config.likeCommentEnabled && friends) {
        NSLog(@"[DD助手] 获取到 %lu 个好友", (unsigned long)friends.count);
    }
    
    return friends;
}

// 插件注册
CHConstructor {
    @autoreleasepool {
        // 检查插件管理器是否存在
        if (NSClassFromString(@"WCPluginsMgr")) {
            // 注册带设置页面的插件
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD助手" 
                                                                               version:@"1.0.0" 
                                                                           controller:@"DDAssistantSettingController"];
            
            NSLog(@"[DD助手] 插件注册成功");
        }
        
        // 加载钩子
        CHLoadLateClass(WCPluginsMgr);
        CHLoadLateClass(CMessageMgr);
        CHLoadLateClass(WCRedEnvelopesLogicMgr);
        CHLoadLateClass(WCOperateFloatView);
        CHLoadLateClass(WCTimelineMgr);
        CHLoadLateClass(WCDataItem);
        CHLoadLateClass(CContactMgr);
        
        // 自动抢红包钩子
        CHHook2(CMessageMgr, onNewSyncAddMessage);
        
        // 朋友圈转发钩子
        CHHook2(WCOperateFloatView, showWithItemData, tipPoint);
        
        // 集赞助手钩子
        CHHook2(WCTimelineMgr, modifyDataItem, notify);
        
        // 好友列表钩子（用于集赞）
        CHHook0(CContactMgr, getAllFriendContacts);
    }
}

@end
