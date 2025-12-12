//
//  DDAssistant.xm
//  DD助手 - 微信增强插件
//  支持iOS15.0+
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <CaptainHook/CaptainHook.h>

#pragma mark - 配置常量
#define kAutoGrabRedEnvelopKey @"DDHelper_AutoGrabRedEnvelop"
#define kTimeLineForwardKey @"DDHelper_TimeLineForward"
#define kLikeCommentHelperKey @"DDHelper_LikeCommentHelper"
#define kRedEnvelopDelayKey @"DDHelper_RedEnvelopDelay"
#define kRedEnvelopBlackListKey @"DDHelper_RedEnvelopBlackList"
#define kRedEnvelopCatchSelfKey @"DDHelper_RedEnvelopCatchSelf"
#define kLikeCountKey @"DDHelper_LikeCount"
#define kCommentCountKey @"DDHelper_CommentCount"
#define kCommentsKey @"DDHelper_Comments"

#pragma mark - 微信类声明
CHDeclareClass(CMessageWrap);
CHDeclareClass(CContact);
CHDeclareClass(CContactMgr);
CHDeclareClass(WCPayInfoItem);
CHDeclareClass(WCDataItem);
CHDeclareClass(WCUserComment);
CHDeclareClass(WCRedEnvelopesLogicMgr);
CHDeclareClass(WCOperateFloatView);
CHDeclareClass(WCForwardViewController);
CHDeclareClass(WCTimelineMgr);
CHDeclareClass(MMServiceCenter);
CHDeclareClass(UIViewController);

#pragma mark - 红包参数队列
@interface DDRedEnvelopParam : NSObject
@property(copy, nonatomic) NSString *msgType;
@property(copy, nonatomic) NSString *sendId;
@property(copy, nonatomic) NSString *channelId;
@property(copy, nonatomic) NSString *nickName;
@property(copy, nonatomic) NSString *headImg;
@property(copy, nonatomic) NSString *nativeUrl;
@property(copy, nonatomic) NSString *sessionUserName;
@property(copy, nonatomic) NSString *sign;
@property(copy, nonatomic) NSString *timingIdentifier;
@property(nonatomic) BOOL isGroupSender;
@end

@implementation DDRedEnvelopParam
@end

@interface DDRedEnvelopParamQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(DDRedEnvelopParam *)param;
- (DDRedEnvelopParam *)dequeue;
@end

@implementation DDRedEnvelopParamQueue {
    NSMutableArray *_queue;
}

+ (instancetype)sharedQueue {
    static DDRedEnvelopParamQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[DDRedEnvelopParamQueue alloc] init];
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

- (void)enqueue:(DDRedEnvelopParam *)param {
    @synchronized(self) {
        [_queue addObject:param];
    }
}

- (DDRedEnvelopParam *)dequeue {
    @synchronized(self) {
        if (_queue.count == 0) return nil;
        DDRedEnvelopParam *first = _queue.firstObject;
        [_queue removeObjectAtIndex:0];
        return first;
    }
}

@end

#pragma mark - 插件配置
@interface DDHelperConfig : NSObject
@property (nonatomic, assign) BOOL autoGrabRedEnvelop;
@property (nonatomic, assign) BOOL timeLineForward;
@property (nonatomic, assign) BOOL likeCommentHelper;
@property (nonatomic, assign) NSInteger redEnvelopDelay;
@property (nonatomic, strong) NSArray *redEnvelopBlackList;
@property (nonatomic, assign) BOOL redEnvelopCatchSelf;
@property (nonatomic, assign) NSInteger likeCount;
@property (nonatomic, assign) NSInteger commentCount;
@property (nonatomic, strong) NSString *comments;

+ (instancetype)sharedConfig;
- (void)saveConfig;
@end

@implementation DDHelperConfig

+ (instancetype)sharedConfig {
    static DDHelperConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[DDHelperConfig alloc] init];
        [config loadConfig];
    });
    return config;
}

- (void)loadConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.autoGrabRedEnvelop = [defaults boolForKey:kAutoGrabRedEnvelopKey];
    self.timeLineForward = [defaults boolForKey:kTimeLineForwardKey];
    self.likeCommentHelper = [defaults boolForKey:kLikeCommentHelperKey];
    self.redEnvelopDelay = [defaults integerForKey:kRedEnvelopDelayKey];
    self.redEnvelopBlackList = [defaults arrayForKey:kRedEnvelopBlackListKey] ?: @[];
    self.redEnvelopCatchSelf = [defaults boolForKey:kRedEnvelopCatchSelfKey];
    self.likeCount = [defaults integerForKey:kLikeCountKey] ?: 10;
    self.commentCount = [defaults integerForKey:kCommentCountKey] ?: 5;
    self.comments = [defaults stringForKey:kCommentsKey] ?: @"赞,,👍,,沙发";
}

- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.autoGrabRedEnvelop forKey:kAutoGrabRedEnvelopKey];
    [defaults setBool:self.timeLineForward forKey:kTimeLineForwardKey];
    [defaults setBool:self.likeCommentHelper forKey:kLikeCommentHelperKey];
    [defaults setInteger:self.redEnvelopDelay forKey:kRedEnvelopDelayKey];
    [defaults setObject:self.redEnvelopBlackList forKey:kRedEnvelopBlackListKey];
    [defaults setBool:self.redEnvelopCatchSelf forKey:kRedEnvelopCatchSelfKey];
    [defaults setInteger:self.likeCount forKey:kLikeCountKey];
    [defaults setInteger:self.commentCount forKey:kCommentCountKey];
    [defaults setObject:self.comments forKey:kCommentsKey];
    [defaults synchronize];
}

@end

#pragma mark - 插件设置界面
@interface DDHelperSettingController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *sectionTitles;
@property (nonatomic, strong) NSArray *sectionData;

@end

@implementation DDHelperSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"DD助手设置";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    // 适配iOS15+
    if (@available(iOS 15.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [UIColor systemBackgroundColor];
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
    }
    
    // 创建表格
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
    
    // 配置数据
    [self setupData];
    
    // 添加关闭按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemClose target:self action:@selector(close)];
    self.navigationItem.rightBarButtonItem = closeButton;
}

- (void)setupData {
    self.sectionTitles = @[@"自动抢红包", @"朋友圈转发", @"集赞助手"];
    
    DDHelperConfig *config = [DDHelperConfig sharedConfig];
    
    self.sectionData = @[
        @[
            @{@"title": @"开启自动抢红包", @"type": @"switch", @"key": kAutoGrabRedEnvelopKey},
            @{@"title": @"延迟抢红包(毫秒)", @"type": @"input", @"key": kRedEnvelopDelayKey},
            @{@"title": @"抢自己的红包", @"type": @"switch", @"key": kRedEnvelopCatchSelfKey},
            @{@"title": @"群聊黑名单", @"type": @"button", @"action": @"showBlackList"}
        ],
        @[
            @{@"title": @"开启朋友圈转发", @"type": @"switch", @"key": kTimeLineForwardKey}
        ],
        @[
            @{@"title": @"开启集赞助手", @"type": @"switch", @"key": kLikeCommentHelperKey},
            @{@"title": @"点赞数量", @"type": @"input", @"key": kLikeCountKey},
            @{@"title": @"评论数量", @"type": @"input", @"key": kCommentCountKey},
            @{@"title": @"评论内容(逗号分隔)", @"type": @"input", @"key": kCommentsKey}
        ]
    ];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sectionTitles.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.sectionData[section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sectionTitles[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"DDHelperCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *item = self.sectionData[indexPath.section][indexPath.row];
    NSString *type = item[@"type"];
    NSString *title = item[@"title"];
    NSString *key = item[@"key"];
    
    cell.textLabel.text = title;
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    
    DDHelperConfig *config = [DDHelperConfig sharedConfig];
    
    if ([type isEqualToString:@"switch"]) {
        UISwitch *switchView = [[UISwitch alloc] init];
        
        if ([key isEqualToString:kAutoGrabRedEnvelopKey]) {
            switchView.on = config.autoGrabRedEnvelop;
            [switchView addTarget:self action:@selector(autoGrabSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        } else if ([key isEqualToString:kTimeLineForwardKey]) {
            switchView.on = config.timeLineForward;
            [switchView addTarget:self action:@selector(timeLineSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        } else if ([key isEqualToString:kLikeCommentHelperKey]) {
            switchView.on = config.likeCommentHelper;
            [switchView addTarget:self action:@selector(likeCommentSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        } else if ([key isEqualToString:kRedEnvelopCatchSelfKey]) {
            switchView.on = config.redEnvelopCatchSelf;
            [switchView addTarget:self action:@selector(catchSelfSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        }
        
        cell.accessoryView = switchView;
    } else if ([type isEqualToString:@"input"]) {
        if ([key isEqualToString:kRedEnvelopDelayKey]) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)config.redEnvelopDelay];
        } else if ([key isEqualToString:kLikeCountKey]) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)config.likeCount];
        } else if ([key isEqualToString:kCommentCountKey]) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)config.commentCount];
        } else if ([key isEqualToString:kCommentsKey]) {
            cell.detailTextLabel.text = config.comments;
        }
        
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else if ([type isEqualToString:@"button"]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *item = self.sectionData[indexPath.section][indexPath.row];
    NSString *type = item[@"type"];
    NSString *key = item[@"key"];
    
    if ([type isEqualToString:@"input"]) {
        [self showInputAlertForKey:key];
    } else if ([type isEqualToString:@"button"]) {
        NSString *action = item[@"action"];
        if ([action isEqualToString:@"showBlackList"]) {
            [self showBlackList];
        }
    }
}

- (void)showInputAlertForKey:(NSString *)key {
    DDHelperConfig *config = [DDHelperConfig sharedConfig];
    
    NSString *title = @"";
    NSString *currentValue = @"";
    
    if ([key isEqualToString:kRedEnvelopDelayKey]) {
        title = @"输入延迟时间(毫秒)";
        currentValue = [NSString stringWithFormat:@"%ld", (long)config.redEnvelopDelay];
    } else if ([key isEqualToString:kLikeCountKey]) {
        title = @"输入点赞数量";
        currentValue = [NSString stringWithFormat:@"%ld", (long)config.likeCount];
    } else if ([key isEqualToString:kCommentCountKey]) {
        title = @"输入评论数量";
        currentValue = [NSString stringWithFormat:@"%ld", (long)config.commentCount];
    } else if ([key isEqualToString:kCommentsKey]) {
        title = @"输入评论内容(逗号分隔)";
        currentValue = config.comments;
    }
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.text = currentValue;
        if ([key isEqualToString:kRedEnvelopDelayKey] || 
            [key isEqualToString:kLikeCountKey] || 
            [key isEqualToString:kCommentCountKey]) {
            textField.keyboardType = UIKeyboardTypeNumberPad;
        }
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *textField = alert.textFields.firstObject;
        NSString *value = textField.text;
        
        if ([key isEqualToString:kRedEnvelopDelayKey]) {
            config.redEnvelopDelay = [value integerValue];
        } else if ([key isEqualToString:kLikeCountKey]) {
            config.likeCount = [value integerValue];
        } else if ([key isEqualToString:kCommentCountKey]) {
            config.commentCount = [value integerValue];
        } else if ([key isEqualToString:kCommentsKey]) {
            config.comments = value;
        }
        
        [config saveConfig];
        [self.tableView reloadData];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showBlackList {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"群聊黑名单" 
                                                                   message:@"暂时不支持设置，请稍后更新" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)autoGrabSwitchChanged:(UISwitch *)sender {
    [DDHelperConfig sharedConfig].autoGrabRedEnvelop = sender.on;
    [[DDHelperConfig sharedConfig] saveConfig];
}

- (void)timeLineSwitchChanged:(UISwitch *)sender {
    [DDHelperConfig sharedConfig].timeLineForward = sender.on;
    [[DDHelperConfig sharedConfig] saveConfig];
}

- (void)likeCommentSwitchChanged:(UISwitch *)sender {
    [DDHelperConfig sharedConfig].likeCommentHelper = sender.on;
    [[DDHelperConfig sharedConfig] saveConfig];
}

- (void)catchSelfSwitchChanged:(UISwitch *)sender {
    [DDHelperConfig sharedConfig].redEnvelopCatchSelf = sender.on;
    [[DDHelperConfig sharedConfig] saveConfig];
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - Hook实现

#pragma mark 1. 自动抢红包功能
CHDeclareClass(CMessageMgr);
CHDeclareClass(WCRedEnvelopesLogicMgr);

CHMethod(2, void, CMessageMgr, onNewSyncAddMessage, id, arg1, id, arg2) {
    CHSuper(2, CMessageMgr, onNewSyncAddMessage, arg1, arg2);
    
    if (![DDHelperConfig sharedConfig].autoGrabRedEnvelop) return;
    
    // 使用运行时获取属性值
    id wrap = arg1;
    
    // 获取消息类型
    int msgType = [[wrap valueForKey:@"m_uiMessageType"] intValue];
    if (msgType != 49) return;
    
    // 获取消息内容
    NSString *content = [wrap valueForKey:@"m_nsContent"];
    if (![content containsString:@"wxpay://"]) return;
    
    // 获取发送者
    NSString *fromUsr = [wrap valueForKey:@"m_nsFromUsr"];
    BOOL isGroup = [fromUsr containsString:@"@chatroom"];
    
    // 判断是否在黑名单中
    if (isGroup) {
        NSArray *blackList = [DDHelperConfig sharedConfig].redEnvelopBlackList;
        if ([blackList containsObject:fromUsr]) return;
    }
    
    // 获取支付信息
    id payInfo = [wrap valueForKey:@"m_oWCPayInfoItem"];
    if (!payInfo) return;
    
    // 获取原生URL
    NSString *nativeUrl = [payInfo valueForKey:@"m_c2cNativeUrl"];
    if (!nativeUrl) return;
    
    // 解析URL参数
    NSString *urlParams = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
    NSArray *components = [urlParams componentsSeparatedByString:@"&"];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    for (NSString *component in components) {
        NSArray *keyValue = [component componentsSeparatedByString:@"="];
        if (keyValue.count == 2) {
            NSString *key = [keyValue[0] stringByRemovingPercentEncoding];
            NSString *value = [keyValue[1] stringByRemovingPercentEncoding];
            if (key && value) {
                params[key] = value;
            }
        }
    }
    
    // 获取自身信息
    Class contactMgrClass = objc_getClass("CContactMgr");
    if (!contactMgrClass) return;
    
    id contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:contactMgrClass];
    id selfContact = [contactMgr getSelfContact];
    
    // 创建红包参数
    DDRedEnvelopParam *param = [[DDRedEnvelopParam alloc] init];
    param.msgType = params[@"msgtype"];
    param.sendId = params[@"sendid"];
    param.channelId = params[@"channelid"];
    param.nickName = [selfContact valueForKey:@"m_nsNickName"];
    param.headImg = [selfContact valueForKey:@"m_nsHeadImgUrl"];
    param.nativeUrl = nativeUrl;
    param.sessionUserName = fromUsr;
    param.sign = params[@"sign"];
    param.isGroupSender = NO;
    
    // 添加到队列
    [[DDRedEnvelopParamQueue sharedQueue] enqueue:param];
    
    // 延迟抢红包
    NSInteger delay = [DDHelperConfig sharedConfig].redEnvelopDelay;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_MSEC)), 
                   dispatch_get_main_queue(), ^{
        if ([DDHelperConfig sharedConfig].autoGrabRedEnvelop) {
            NSMutableDictionary *requestParams = [@{
                @"agreeDuty": @"0",
                @"channelId": param.channelId,
                @"inWay": @"0",
                @"msgType": param.msgType,
                @"nativeUrl": param.nativeUrl,
                @"sendId": param.sendId
            } mutableCopy];
            
            Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
            if (!logicMgrClass) return;
            
            id logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:logicMgrClass];
            if ([logicMgr respondsToSelector:@selector(ReceiverQueryRedEnvelopesRequest:)]) {
                [logicMgr ReceiverQueryRedEnvelopesRequest:requestParams];
            }
        }
    });
}

CHMethod(2, void, WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, id, arg1, Request, id, arg2) {
    CHSuper(2, WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, arg1, Request, arg2);
    
    if (![DDHelperConfig sharedConfig].autoGrabRedEnvelop) return;
    
    // 获取响应数据
    id retText = [arg1 valueForKeyPath:@"retText.buffer"];
    if (![retText isKindOfClass:[NSData class]]) return;
    
    NSData *retData = (NSData *)retText;
    NSError *error = nil;
    id response = [NSJSONSerialization JSONObjectWithData:retData options:0 error:&error];
    
    if (error || ![response isKindOfClass:[NSDictionary class]]) return;
    
    NSDictionary *responseDict = (NSDictionary *)response;
    if (!responseDict[@"timingIdentifier"]) return;
    
    // 从队列获取参数
    DDRedEnvelopParam *param = [[DDRedEnvelopParamQueue sharedQueue] dequeue];
    if (!param) return;
    
    // 检查红包状态
    if ([responseDict[@"hbStatus"] integerValue] == 4) return;
    if ([responseDict[@"receiveStatus"] integerValue] == 2) return;
    
    param.timingIdentifier = responseDict[@"timingIdentifier"];
    
    // 发送抢红包请求
    NSInteger delay = [DDHelperConfig sharedConfig].redEnvelopDelay;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_MSEC)), 
                   dispatch_get_main_queue(), ^{
        NSMutableDictionary *openParams = [@{
            @"channelId": param.channelId,
            @"msgType": param.msgType,
            @"sendId": param.sendId,
            @"timingIdentifier": param.timingIdentifier,
            @"agreeDuty": @"0",
            @"inWay": @"0",
            @"nativeUrl": param.nativeUrl,
            @"sessionUserName": param.sessionUserName,
            @"headImg": param.headImg,
            @"nickName": param.nickName
        } mutableCopy];
        
        Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
        if (!logicMgrClass) return;
        
        id logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:logicMgrClass];
        if ([logicMgr respondsToSelector:@selector(OpenRedEnvelopesRequest:)]) {
            [logicMgr OpenRedEnvelopesRequest:openParams];
        }
    });
}

#pragma mark 2. 朋友圈转发功能
CHDeclareClass(WCOperateFloatView);

CHMethod(2, void, WCOperateFloatView, showWithItemData, id, arg1, tipPoint, CGPoint, arg2) {
    CHSuper(2, WCOperateFloatView, showWithItemData, arg1, tipPoint, arg2);
    
    if (![DDHelperConfig sharedConfig].timeLineForward) return;
    
    // 使用运行时获取like按钮
    UIButton *likeBtn = [self valueForKey:@"m_likeBtn"];
    if (!likeBtn || !likeBtn.superview) return;
    
    // 检查是否已添加转发按钮
    UIButton *existingBtn = objc_getAssociatedObject(self, "dd_forwardBtn");
    if (existingBtn) {
        [existingBtn removeFromSuperview];
    }
    
    // 创建转发按钮
    UIButton *forwardBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [forwardBtn setTitle:@"转发" forState:UIControlStateNormal];
    [forwardBtn setTitleColor:[likeBtn titleColorForState:UIControlStateNormal] forState:UIControlStateNormal];
    forwardBtn.titleLabel.font = likeBtn.titleLabel.font;
    [forwardBtn addTarget:self action:@selector(dd_forwardTimeLine) forControlEvents:UIControlEventTouchUpInside];
    
    // 设置frame
    CGRect likeFrame = likeBtn.frame;
    forwardBtn.frame = CGRectMake(CGRectGetMaxX(likeFrame) + 10, 
                                   likeFrame.origin.y, 
                                   likeFrame.size.width, 
                                   likeFrame.size.height);
    
    [likeBtn.superview addSubview:forwardBtn];
    
    // 关联对象存储
    objc_setAssociatedObject(self, "dd_forwardBtn", forwardBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)dd_forwardTimeLine {
    // 获取朋友圈数据
    id dataItem = [self valueForKey:@"m_item"];
    if (!dataItem) return;
    
    // 创建转发控制器
    Class forwardVCClass = objc_getClass("WCForwardViewController");
    if (!forwardVCClass) return;
    
    id forwardVC = [[forwardVCClass alloc] initWithDataItem:dataItem];
    if (!forwardVC) return;
    
    // 获取当前导航控制器
    UIViewController *currentVC = (UIViewController *)self;
    while (currentVC.parentViewController) {
        currentVC = currentVC.parentViewController;
    }
    
    if ([currentVC isKindOfClass:[UINavigationController class]]) {
        [currentVC pushViewController:forwardVC animated:YES];
    } else if (currentVC.navigationController) {
        [currentVC.navigationController pushViewController:forwardVC animated:YES];
    }
}

#pragma mark 3. 集赞助手功能
CHDeclareClass(WCTimelineMgr);

CHMethod(2, void, WCTimelineMgr, modifyDataItem, id, arg1, notify, BOOL, arg2) {
    if ([DDHelperConfig sharedConfig].likeCommentHelper) {
        [self dd_addLikeAndComments:arg1];
    }
    
    CHSuper(2, WCTimelineMgr, modifyDataItem, arg1, notify, arg2);
}

- (void)dd_addLikeAndComments:(id)dataItem {
    DDHelperConfig *config = [DDHelperConfig sharedConfig];
    
    // 获取好友列表
    Class contactMgrClass = objc_getClass("CContactMgr");
    if (!contactMgrClass) return;
    
    id contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:contactMgrClass];
    
    // 尝试获取好友列表
    NSArray *allContacts = nil;
    if ([contactMgr respondsToSelector:@selector(getContactList:contactType:)]) {
        allContacts = [contactMgr getContactList:2 contactType:0];
    }
    
    if (!allContacts) allContacts = @[];
    
    // 添加点赞
    NSMutableArray *likeUsers = [dataItem valueForKey:@"likeUsers"];
    if (!likeUsers) {
        likeUsers = [NSMutableArray array];
        [dataItem setValue:likeUsers forKey:@"likeUsers"];
    }
    
    NSInteger likeCount = config.likeCount;
    if (likeCount > allContacts.count) {
        likeCount = allContacts.count;
    }
    
    for (int i = 0; i < likeCount && i < allContacts.count; i++) {
        id contact = allContacts[i];
        Class commentClass = objc_getClass("WCUserComment");
        if (!commentClass) continue;
        
        id like = [[commentClass alloc] init];
        if (!like) continue;
        
        [like setValue:@1 forKey:@"type"]; // 点赞
        [like setValue:[contact valueForKey:@"m_nsNickName"] forKey:@"nickname"];
        [like setValue:[contact valueForKey:@"m_nsUsrName"] forKey:@"username"];
        
        [likeUsers addObject:like];
    }
    
    [dataItem setValue:@((int)likeUsers.count) forKey:@"likeCount"];
    [dataItem setValue:@YES forKey:@"likeFlag"];
    
    // 添加评论
    NSMutableArray *commentUsers = [dataItem valueForKey:@"commentUsers"];
    if (!commentUsers) {
        commentUsers = [NSMutableArray array];
        [dataItem setValue:commentUsers forKey:@"commentUsers"];
    }
    
    NSInteger commentCount = config.commentCount;
    NSArray *comments = [config.comments componentsSeparatedByString:@","];
    
    for (int i = 0; i < commentCount && i < allContacts.count; i++) {
        id contact = allContacts[i];
        Class commentClass = objc_getClass("WCUserComment");
        if (!commentClass) continue;
        
        id comment = [[commentClass alloc] init];
        if (!comment) continue;
        
        [comment setValue:@2 forKey:@"type"]; // 评论
        [comment setValue:[contact valueForKey:@"m_nsNickName"] forKey:@"nickname"];
        [comment setValue:[contact valueForKey:@"m_nsUsrName"] forKey:@"username"];
        
        // 随机选择评论内容
        if (comments.count > 0) {
            NSString *commentText = comments[arc4random_uniform((uint32_t)comments.count)];
            [comment setValue:commentText forKey:@"content"];
        } else {
            [comment setValue:@"赞！" forKey:@"content"];
        }
        
        [commentUsers addObject:comment];
    }
    
    [dataItem setValue:@((int)commentUsers.count) forKey:@"commentCount"];
}

#pragma mark - 注册插件和Hook
CHConstructor {
    @autoreleasepool {
        // 延迟执行，确保微信初始化完成
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 注册插件设置界面
            Class pluginsMgrClass = objc_getClass("WCPluginsMgr");
            if (pluginsMgrClass) {
                id pluginsMgr = [pluginsMgrClass sharedInstance];
                if (pluginsMgr && [pluginsMgr respondsToSelector:@selector(registerControllerWithTitle:version:controller:)]) {
                    [pluginsMgr registerControllerWithTitle:@"DD助手" 
                                                   version:@"1.0.0" 
                                               controller:@"DDHelperSettingController"];
                }
            }
        });
        
        // Hook相关类
        CHLoadLateClass(CMessageMgr);
        CHHook(2, CMessageMgr, onNewSyncAddMessage, arg1, arg2);
        
        CHLoadLateClass(WCRedEnvelopesLogicMgr);
        CHHook(2, WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, Request);
        
        CHLoadLateClass(WCOperateFloatView);
        CHHook(2, WCOperateFloatView, showWithItemData, tipPoint);
        
        // 为WCOperateFloatView添加转发方法
        Class floatViewClass = objc_getClass("WCOperateFloatView");
        if (floatViewClass) {
            class_addMethod(floatViewClass, @selector(dd_forwardTimeLine), 
                           (IMP)dd_forwardTimeLine, "v@:");
        }
        
        CHLoadLateClass(WCTimelineMgr);
        CHHook(2, WCTimelineMgr, modifyDataItem, notify);
        
        // 为WCTimelineMgr添加集赞方法
        Class timelineMgrClass = objc_getClass("WCTimelineMgr");
        if (timelineMgrClass) {
            class_addMethod(timelineMgrClass, @selector(dd_addLikeAndComments:), 
                           (IMP)dd_addLikeAndComments, "v@:@");
        }
    }
}

// 转发方法的C函数实现
static void dd_forwardTimeLine(id self, SEL _cmd) {
    // 获取朋友圈数据
    id dataItem = [self valueForKey:@"m_item"];
    if (!dataItem) return;
    
    // 创建转发控制器
    Class forwardVCClass = objc_getClass("WCForwardViewController");
    if (!forwardVCClass) return;
    
    id forwardVC = [[forwardVCClass alloc] initWithDataItem:dataItem];
    if (!forwardVC) return;
    
    // 获取当前导航控制器
    UIViewController *currentVC = (UIViewController *)self;
    while (currentVC.parentViewController) {
        currentVC = currentVC.parentViewController;
    }
    
    if ([currentVC isKindOfClass:[UINavigationController class]]) {
        [currentVC pushViewController:forwardVC animated:YES];
    } else if (currentVC.navigationController) {
        [currentVC.navigationController pushViewController:forwardVC animated:YES];
    }
}

// 集赞方法的C函数实现
static void dd_addLikeAndComments(id self, SEL _cmd, id dataItem) {
    DDHelperConfig *config = [DDHelperConfig sharedConfig];
    
    // 获取好友列表
    Class contactMgrClass = objc_getClass("CContactMgr");
    if (!contactMgrClass) return;
    
    id contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:contactMgrClass];
    
    // 尝试获取好友列表
    NSArray *allContacts = nil;
    if ([contactMgr respondsToSelector:@selector(getContactList:contactType:)]) {
        allContacts = [contactMgr getContactList:2 contactType:0];
    }
    
    if (!allContacts) allContacts = @[];
    
    // 添加点赞
    NSMutableArray *likeUsers = [dataItem valueForKey:@"likeUsers"];
    if (!likeUsers) {
        likeUsers = [NSMutableArray array];
        [dataItem setValue:likeUsers forKey:@"likeUsers"];
    }
    
    NSInteger likeCount = config.likeCount;
    if (likeCount > allContacts.count) {
        likeCount = allContacts.count;
    }
    
    for (int i = 0; i < likeCount && i < allContacts.count; i++) {
        id contact = allContacts[i];
        Class commentClass = objc_getClass("WCUserComment");
        if (!commentClass) continue;
        
        id like = [[commentClass alloc] init];
        if (!like) continue;
        
        [like setValue:@1 forKey:@"type"];
        [like setValue:[contact valueForKey:@"m_nsNickName"] forKey:@"nickname"];
        [like setValue:[contact valueForKey:@"m_nsUsrName"] forKey:@"username"];
        
        [likeUsers addObject:like];
    }
    
    [dataItem setValue:@((int)likeUsers.count) forKey:@"likeCount"];
    [dataItem setValue:@YES forKey:@"likeFlag"];
    
    // 添加评论
    NSMutableArray *commentUsers = [dataItem valueForKey:@"commentUsers"];
    if (!commentUsers) {
        commentUsers = [NSMutableArray array];
        [dataItem setValue:commentUsers forKey:@"commentUsers"];
    }
    
    NSInteger commentCount = config.commentCount;
    NSArray *comments = [config.comments componentsSeparatedByString:@","];
    
    for (int i = 0; i < commentCount && i < allContacts.count; i++) {
        id contact = allContacts[i];
        Class commentClass = objc_getClass("WCUserComment");
        if (!commentClass) continue;
        
        id comment = [[commentClass alloc] init];
        if (!comment) continue;
        
        [comment setValue:@2 forKey:@"type"];
        [comment setValue:[contact valueForKey:@"m_nsNickName"] forKey:@"nickname"];
        [comment setValue:[contact valueForKey:@"m_nsUsrName"] forKey:@"username"];
        
        // 随机选择评论内容
        if (comments.count > 0) {
            NSString *commentText = comments[arc4random_uniform((uint32_t)comments.count)];
            [comment setValue:commentText forKey:@"content"];
        } else {
            [comment setValue:@"赞！" forKey:@"content"];
        }
        
        [commentUsers addObject:comment];
    }
    
    [dataItem setValue:@((int)commentUsers.count) forKey:@"commentCount"];
}

#pragma mark - 插件入口
__attribute__((constructor))
static void entry() {
    NSLog(@"=== DD助手插件已加载 ===");
}