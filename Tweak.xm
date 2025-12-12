//
//  DDHelper.m
//  DD助手 - 微信增强插件
//  支持iOS15.0+
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
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

#pragma mark - 插件管理器接口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

#pragma mark - 微信类声明（简化版）
@interface CMessageWrap : NSObject
@property(retain, nonatomic) NSString *m_nsContent;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(nonatomic) int m_uiMessageType;
@property(retain, nonatomic) id m_oWCPayInfoItem;
@end

@interface WCPayInfoItem : NSObject
@property(retain, nonatomic) NSString *m_c2cNativeUrl;
@end

@interface CContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@property(retain, nonatomic) NSString *m_nsNickName;
@property(retain, nonatomic) NSString *m_nsRemark;
- (NSString *)getContactDisplayName;
@end

@interface CContactMgr : NSObject
- (CContact *)getSelfContact;
- (CContact *)getContactByName:(NSString *)name;
@end

@interface WCDataItem : NSObject
@property(retain, nonatomic) NSMutableArray *likeUsers;
@property(nonatomic) int likeCount;
@property(retain, nonatomic) NSMutableArray *commentUsers;
@property(nonatomic) int commentCount;
@property(retain, nonatomic) NSString *username;
@property(nonatomic) BOOL likeFlag;
@end

@interface WCUserComment : NSObject
@property(retain, nonatomic) NSString *nickname;
@property(retain, nonatomic) NSString *username;
@property(retain, nonatomic) NSString *content;
@property(nonatomic) int type; // 1:点赞 2:评论
@end

@interface WCRedEnvelopesLogicMgr : NSObject
- (void)OpenRedEnvelopesRequest:(id)arg1;
- (void)ReceiverQueryRedEnvelopesRequest:(id)arg1;
@end

@interface WCForwardViewController : UIViewController
- (id)initWithDataItem:(id)arg1;
@end

@interface MMServiceCenter : NSObject
+ (id)defaultCenter;
- (id)getService:(Class)service;
@end

@interface UIViewController (Navigation)
- (void)PushViewController:(UIViewController *)vc animated:(BOOL)animated;
@end

@interface WCBizUtil : NSObject
+ (id)dictionaryWithDecodedComponets:(id)arg1 separator:(id)arg2;
@end

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
            @{@"title": @"开启自动抢红包", @"type": @"switch", @"key": kAutoGrabRedEnvelopKey, @"value": @(config.autoGrabRedEnvelop)},
            @{@"title": @"延迟抢红包(毫秒)", @"type": @"input", @"key": kRedEnvelopDelayKey, @"value": @(config.redEnvelopDelay)},
            @{@"title": @"抢自己的红包", @"type": @"switch", @"key": kRedEnvelopCatchSelfKey, @"value": @(config.redEnvelopCatchSelf)},
            @{@"title": @"群聊黑名单", @"type": @"button", @"action": @"showBlackList"}
        ],
        @[
            @{@"title": @"开启朋友圈转发", @"type": @"switch", @"key": kTimeLineForwardKey, @"value": @(config.timeLineForward)}
        ],
        @[
            @{@"title": @"开启集赞助手", @"type": @"switch", @"key": kLikeCommentHelperKey, @"value": @(config.likeCommentHelper)},
            @{@"title": @"点赞数量", @"type": @"input", @"key": kLikeCountKey, @"value": @(config.likeCount)},
            @{@"title": @"评论数量", @"type": @"input", @"key": kCommentCountKey, @"value": @(config.commentCount)},
            @{@"title": @"评论内容(逗号分隔)", @"type": @"input", @"key": kCommentsKey, @"value": config.comments ?: @""}
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
    
    cell.textLabel.text = title;
    cell.detailTextLabel.text = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    
    DDHelperConfig *config = [DDHelperConfig sharedConfig];
    
    if ([type isEqualToString:@"switch"]) {
        UISwitch *switchView = [[UISwitch alloc] init];
        NSString *key = item[@"key"];
        
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
        NSString *key = item[@"key"];
        id value = item[@"value"];
        
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
CHDeclareClass(CMessageMgr);
CHDeclareClass(WCRedEnvelopesLogicMgr);
CHDeclareClass(WCOperateFloatView);
CHDeclareClass(WCTimelineMgr);

#pragma mark 1. 自动抢红包功能
CHMethod2(void, CMessageMgr, onNewSyncAddMessage, CMessageWrap *, wrap) {
    CHSuper2(CMessageMgr, onNewSyncAddMessage, wrap);
    
    if (![DDHelperConfig sharedConfig].autoGrabRedEnvelop) return;
    
    // 只处理红包消息
    if (wrap.m_uiMessageType != 49) return;
    if (![wrap.m_nsContent containsString:@"wxpay://"]) return;
    
    // 判断是否为群聊红包
    BOOL isGroup = [wrap.m_nsFromUsr containsString:@"@chatroom"];
    
    // 判断是否在黑名单中
    if (isGroup) {
        NSArray *blackList = [DDHelperConfig sharedConfig].redEnvelopBlackList;
        if ([blackList containsObject:wrap.m_nsFromUsr]) return;
    }
    
    // 判断是否抢自己的红包
    CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
    CContact *selfContact = [contactMgr getSelfContact];
    BOOL isSelf = [wrap.m_nsFromUsr isEqualToString:selfContact.m_nsUsrName];
    
    if (isSelf && ![DDHelperConfig sharedConfig].redEnvelopCatchSelf) return;
    
    // 解析红包URL
    NSString *nativeUrl = [(WCPayInfoItem *)wrap.m_oWCPayInfoItem m_c2cNativeUrl];
    NSString *urlParams = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
    
    NSDictionary *params = [objc_getClass("WCBizUtil") dictionaryWithDecodedComponets:urlParams separator:@"&"];
    
    // 创建红包参数
    DDRedEnvelopParam *param = [[DDRedEnvelopParam alloc] init];
    param.msgType = [params objectForKey:@"msgtype"];
    param.sendId = [params objectForKey:@"sendid"];
    param.channelId = [params objectForKey:@"channelid"];
    param.nickName = [selfContact getContactDisplayName];
    param.headImg = [selfContact m_nsHeadImgUrl];
    param.nativeUrl = nativeUrl;
    param.sessionUserName = wrap.m_nsFromUsr;
    param.sign = [params objectForKey:@"sign"];
    param.isGroupSender = NO;
    
    // 添加到队列
    [[DDRedEnvelopParamQueue sharedQueue] enqueue:param];
    
    // 延迟抢红包
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([DDHelperConfig sharedConfig].redEnvelopDelay * NSEC_PER_MSEC)), 
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
            
            WCRedEnvelopesLogicMgr *logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] 
                getService:objc_getClass("WCRedEnvelopesLogicMgr")];
            [logicMgr ReceiverQueryRedEnvelopesRequest:requestParams];
        }
    });
}

CHMethod2(void, WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, id, arg1, Request, id, arg2) {
    CHSuper2(WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, arg1, Request, arg2);
    
    if (![DDHelperConfig sharedConfig].autoGrabRedEnvelop) return;
    
    // 获取响应数据
    NSData *retData = [arg1 valueForKeyPath:@"retText.buffer"];
    NSString *retString = [[NSString alloc] initWithData:retData encoding:NSUTF8StringEncoding];
    NSDictionary *response = [retString JSONDictionary];
    
    if (!response || ![response[@"timingIdentifier"] length]) return;
    
    // 从队列获取参数
    DDRedEnvelopParam *param = [[DDRedEnvelopParamQueue sharedQueue] dequeue];
    if (!param) return;
    
    // 检查红包状态
    if ([response[@"hbStatus"] integerValue] == 4) return; // 红包已抢完
    if ([response[@"receiveStatus"] integerValue] == 2) return; // 已抢过
    
    param.timingIdentifier = response[@"timingIdentifier"];
    
    // 发送抢红包请求
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([DDHelperConfig sharedConfig].redEnvelopDelay * NSEC_PER_MSEC)), 
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
        
        WCRedEnvelopesLogicMgr *logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] 
            getService:objc_getClass("WCRedEnvelopesLogicMgr")];
        [logicMgr OpenRedEnvelopesRequest:openParams];
    });
}

#pragma mark 2. 朋友圈转发功能
CHMethod2(void, WCOperateFloatView, showWithItemData, id, arg1, tipPoint, CGPoint, arg2) {
    CHSuper2(WCOperateFloatView, showWithItemData, arg1, tipPoint, arg2);
    
    if (![DDHelperConfig sharedConfig].timeLineForward) return;
    
    // 获取like按钮的父视图
    UIView *likeBtn = [self valueForKey:@"m_likeBtn"];
    if (!likeBtn || !likeBtn.superview) return;
    
    // 创建转发按钮
    UIButton *forwardBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [forwardBtn setTitle:@"转发" forState:UIControlStateNormal];
    [forwardBtn setTitleColor:[likeBtn titleColorForState:UIControlStateNormal] forState:UIControlStateNormal];
    forwardBtn.titleLabel.font = [likeBtn titleLabel].font;
    [forwardBtn addTarget:self action:@selector(dd_forwardTimeLine:) forControlEvents:UIControlEventTouchUpInside];
    
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

CHMethod1(void, WCOperateFloatView, dd_forwardTimeLine, id, arg1) {
    // 获取朋友圈数据
    WCDataItem *dataItem = [self valueForKey:@"m_item"];
    if (!dataItem) return;
    
    // 创建转发控制器
    WCForwardViewController *forwardVC = [[objc_getClass("WCForwardViewController") alloc] initWithDataItem:dataItem];
    
    // 获取当前导航控制器
    UIViewController *currentVC = (UIViewController *)self;
    while (currentVC.parentViewController) {
        currentVC = currentVC.parentViewController;
    }
    
    if ([currentVC isKindOfClass:[UINavigationController class]]) {
        [(UINavigationController *)currentVC pushViewController:forwardVC animated:YES];
    } else if (currentVC.navigationController) {
        [currentVC.navigationController pushViewController:forwardVC animated:YES];
    }
}

#pragma mark 3. 集赞助手功能
CHMethod2(void, WCTimelineMgr, modifyDataItem, WCDataItem *, arg1, notify, BOOL, arg2) {
    if ([DDHelperConfig sharedConfig].likeCommentHelper) {
        [self dd_addLikeAndComments:arg1];
    }
    
    CHSuper2(WCTimelineMgr, modifyDataItem, arg1, notify, arg2);
}

CHMethod1(void, WCTimelineMgr, dd_addLikeAndComments, WCDataItem *, dataItem) {
    DDHelperConfig *config = [DDHelperConfig sharedConfig];
    
    // 获取好友列表（真实用户名）
    CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
    NSArray *allContacts = [contactMgr getContactList:2 contactType:0]; // 获取好友列表
    
    // 添加点赞
    if (!dataItem.likeUsers) {
        dataItem.likeUsers = [NSMutableArray array];
    }
    
    NSInteger likeCount = config.likeCount;
    if (likeCount > allContacts.count) {
        likeCount = allContacts.count;
    }
    
    for (int i = 0; i < likeCount && i < allContacts.count; i++) {
        CContact *contact = allContacts[i];
        WCUserComment *like = [[objc_getClass("WCUserComment") alloc] init];
        like.type = 1; // 点赞
        like.nickname = [contact getContactDisplayName];
        like.username = contact.m_nsUsrName;
        [dataItem.likeUsers addObject:like];
    }
    
    dataItem.likeCount = (int)dataItem.likeUsers.count;
    dataItem.likeFlag = YES;
    
    // 添加评论
    if (!dataItem.commentUsers) {
        dataItem.commentUsers = [NSMutableArray array];
    }
    
    NSInteger commentCount = config.commentCount;
    NSArray *comments = [config.comments componentsSeparatedByString:@","];
    
    for (int i = 0; i < commentCount && i < allContacts.count; i++) {
        CContact *contact = allContacts[i];
        WCUserComment *comment = [[objc_getClass("WCUserComment") alloc] init];
        comment.type = 2; // 评论
        comment.nickname = [contact getContactDisplayName];
        comment.username = contact.m_nsUsrName;
        
        // 随机选择评论内容
        if (comments.count > 0) {
            NSString *commentText = comments[arc4random_uniform((uint32_t)comments.count)];
            comment.content = commentText;
        } else {
            comment.content = @"赞！";
        }
        
        [dataItem.commentUsers addObject:comment];
    }
    
    dataItem.commentCount = (int)dataItem.commentUsers.count;
}

#pragma mark - 注册插件
CHConstructor {
    @autoreleasepool {
        // 延迟执行，确保微信初始化完成
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (NSClassFromString(@"WCPluginsMgr")) {
                // 注册带设置页面的插件
                [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD助手" 
                                                                                   version:@"1.0.0" 
                                                                               controller:@"DDHelperSettingController"];
            }
        });
        
        // Hook相关类
        CHLoadLateClass(CMessageMgr);
        CHHook2(CMessageMgr, onNewSyncAddMessage);
        
        CHLoadLateClass(WCRedEnvelopesLogicMgr);
        CHHook2(WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, Request);
        
        CHLoadLateClass(WCOperateFloatView);
        CHHook2(WCOperateFloatView, showWithItemData, tipPoint);
        CHClassHook1(WCOperateFloatView, dd_forwardTimeLine);
        
        CHLoadLateClass(WCTimelineMgr);
        CHHook2(WCTimelineMgr, modifyDataItem, notify);
        CHClassHook1(WCTimelineMgr, dd_addLikeAndComments);
    }
}

#pragma mark - 插件入口
__attribute__((constructor))
static void entry() {
    NSLog(@"=== DD助手插件已加载 ===");
}