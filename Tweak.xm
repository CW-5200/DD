//
//  DDHelper.xm
//  DD助手 - 微信增强插件
//
//  Created by DD助手 on 2024
//

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// 配置管理
@interface DDHelperConfig : NSObject
+ (instancetype)shared;
@property (nonatomic, assign) BOOL enableTimelineForward;      // 朋友圈转发
@property (nonatomic, assign) BOOL enableLikeAssistant;        // 集赞助手
@property (nonatomic, assign) NSInteger likeCount;             // 点赞数
@property (nonatomic, assign) NSInteger commentCount;          // 评论数
@property (nonatomic, copy) NSString *comments;                // 评论内容
@property (nonatomic, assign) BOOL enableAutoRedEnvelop;       // 自动抢红包
@property (nonatomic, assign) NSInteger redEnvelopDelay;       // 延迟抢红包(毫秒)
@property (nonatomic, copy) NSArray *redEnvelopGroupFilter;    // 群聊过滤
@property (nonatomic, copy) NSString *redEnvelopKeywordFilter; // 关键词过滤
@property (nonatomic, assign) BOOL enablePersonalRedEnvelop;   // 接收个人红包
@end

// 红包参数队列
@interface WeChatRedEnvelopParam : NSObject
@property (nonatomic, copy) NSString *msgType;
@property (nonatomic, copy) NSString *sendId;
@property (nonatomic, copy) NSString *channelId;
@property (nonatomic, copy) NSString *nickName;
@property (nonatomic, copy) NSString *headImg;
@property (nonatomic, copy) NSString *nativeUrl;
@property (nonatomic, copy) NSString *sessionUserName;
@property (nonatomic, copy) NSString *sign;
@property (nonatomic, copy) NSString *timingIdentifier;
@property (nonatomic, assign) BOOL isGroupSender;
@end

@interface WBRedEnvelopParamQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(WeChatRedEnvelopParam *)param;
- (WeChatRedEnvelopParam *)dequeue;
@end

// 红包任务管理器
@interface WBReceiveRedEnvelopOperation : NSOperation
- (instancetype)initWithRedEnvelopParam:(WeChatRedEnvelopParam *)param delay:(unsigned int)delaySeconds;
@end

@interface WBRedEnvelopTaskManager : NSObject
+ (instancetype)sharedManager;
- (void)addNormalTask:(WBReceiveRedEnvelopOperation *)operation;
- (void)addSerialTask:(WBReceiveRedEnvelopOperation *)operation;
@property (nonatomic, assign, readonly) BOOL serialQueueIsEmpty;
@end

// 微信类前向声明
@class CMessageWrap, CMessageMgr, CContactMgr, CContact, WCDataItem, WCTimelineMgr;
@class WCOperateFloatView, WCForwardViewController, WCRedEnvelopesLogicMgr;
@class MMServiceCenter, MMTipsViewController, NewSettingViewController;

// 配置实现
@implementation DDHelperConfig
+ (instancetype)shared {
    static DDHelperConfig *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
        [sharedInstance loadConfig];
    });
    return sharedInstance;
}

- (instancetype)init {
    if (self = [super init]) {
        _enableTimelineForward = NO;
        _enableLikeAssistant = NO;
        _likeCount = 10;
        _commentCount = 5;
        _comments = @"赞,,👍,,666";
        _enableAutoRedEnvelop = NO;
        _redEnvelopDelay = 0;
        _redEnvelopGroupFilter = @[];
        _redEnvelopKeywordFilter = @"";
        _enablePersonalRedEnvelop = YES;
    }
    return self;
}

- (void)loadConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _enableTimelineForward = [defaults boolForKey:@"DD_enableTimelineForward"];
    _enableLikeAssistant = [defaults boolForKey:@"DD_enableLikeAssistant"];
    _likeCount = [defaults integerForKey:@"DD_likeCount"];
    if (_likeCount == 0) _likeCount = 10;
    _commentCount = [defaults integerForKey:@"DD_commentCount"];
    if (_commentCount == 0) _commentCount = 5;
    _comments = [defaults stringForKey:@"DD_comments"] ?: @"赞,,👍,,666";
    _enableAutoRedEnvelop = [defaults boolForKey:@"DD_enableAutoRedEnvelop"];
    _redEnvelopDelay = [defaults integerForKey:@"DD_redEnvelopDelay"];
    _redEnvelopGroupFilter = [defaults arrayForKey:@"DD_redEnvelopGroupFilter"] ?: @[];
    _redEnvelopKeywordFilter = [defaults stringForKey:@"DD_redEnvelopKeywordFilter"] ?: @"";
    _enablePersonalRedEnvelop = [defaults boolForKey:@"DD_enablePersonalRedEnvelop"];
}

- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:_enableTimelineForward forKey:@"DD_enableTimelineForward"];
    [defaults setBool:_enableLikeAssistant forKey:@"DD_enableLikeAssistant"];
    [defaults setInteger:_likeCount forKey:@"DD_likeCount"];
    [defaults setInteger:_commentCount forKey:@"DD_commentCount"];
    [defaults setObject:_comments forKey:@"DD_comments"];
    [defaults setBool:_enableAutoRedEnvelop forKey:@"DD_enableAutoRedEnvelop"];
    [defaults setInteger:_redEnvelopDelay forKey:@"DD_redEnvelopDelay"];
    [defaults setObject:_redEnvelopGroupFilter forKey:@"DD_redEnvelopGroupFilter"];
    [defaults setObject:_redEnvelopKeywordFilter forKey:@"DD_redEnvelopKeywordFilter"];
    [defaults setBool:_enablePersonalRedEnvelop forKey:@"DD_enablePersonalRedEnvelop"];
    [defaults synchronize];
}
@end

// 设置界面
@interface DDHelperSettingController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *sections;
@end

@implementation DDHelperSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD助手设置";
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 创建导航栏按钮
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" 
                                                                             style:UIBarButtonItemStylePlain 
                                                                            target:self 
                                                                            action:@selector(close)];
    
    // 创建表格
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    [self.view addSubview:_tableView];
    
    // 初始化数据
    [self setupSections];
}

- (void)setupSections {
    NSMutableArray *sections = [NSMutableArray array];
    
    // 朋友圈转发
    NSMutableArray *timelineSection = [NSMutableArray array];
    [timelineSection addObject:@{
        @"title": @"朋友圈转发",
        @"type": @"switch",
        @"key": @"enableTimelineForward"
    }];
    [sections addObject:@{@"header": @"朋友圈功能", @"rows": timelineSection}];
    
    // 集赞助手
    NSMutableArray *likeSection = [NSMutableArray array];
    [likeSection addObject:@{
        @"title": @"集赞助手",
        @"type": @"switch",
        @"key": @"enableLikeAssistant"
    }];
    if ([DDHelperConfig shared].enableLikeAssistant) {
        [likeSection addObject:@{
            @"title": @"点赞数量",
            @"type": @"input",
            @"key": @"likeCount",
            @"value": @([DDHelperConfig shared].likeCount).stringValue
        }];
        [likeSection addObject:@{
            @"title": @"评论数量",
            @"type": @"input",
            @"key": @"commentCount",
            @"value": @([DDHelperConfig shared].commentCount).stringValue
        }];
        [likeSection addObject:@{
            @"title": @"评论内容",
            @"type": @"input",
            @"key": @"comments",
            @"value": [DDHelperConfig shared].comments
        }];
    }
    [sections addObject:@{@"header": @"集赞助手", @"rows": likeSection}];
    
    // 自动抢红包
    NSMutableArray *redEnvelopSection = [NSMutableArray array];
    [redEnvelopSection addObject:@{
        @"title": @"自动抢红包",
        @"type": @"switch",
        @"key": @"enableAutoRedEnvelop"
    }];
    if ([DDHelperConfig shared].enableAutoRedEnvelop) {
        [redEnvelopSection addObject:@{
            @"title": @"延迟抢红包(毫秒)",
            @"type": @"input",
            @"key": @"redEnvelopDelay",
            @"value": @([DDHelperConfig shared].redEnvelopDelay).stringValue
        }];
        [redEnvelopSection addObject:@{
            @"title": @"接收个人红包",
            @"type": @"switch",
            @"key": @"enablePersonalRedEnvelop"
        }];
        [redEnvelopSection addObject:@{
            @"title": @"关键词过滤",
            @"type": @"input",
            @"key": @"redEnvelopKeywordFilter",
            @"value": [DDHelperConfig shared].redEnvelopKeywordFilter
        }];
        [redEnvelopSection addObject:@{
            @"title": @"群聊过滤",
            @"type": @"action",
            @"key": @"redEnvelopGroupFilter",
            @"value": [NSString stringWithFormat:@"已过滤%lu个群", (unsigned long)[DDHelperConfig shared].redEnvelopGroupFilter.count]
        }];
    }
    [sections addObject:@{@"header": @"自动抢红包", @"rows": redEnvelopSection}];
    
    _sections = sections;
}

- (void)close {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_sections[section][@"rows"] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return _sections[section][@"header"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"DDHelperCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }
    
    NSDictionary *rowInfo = _sections[indexPath.section][@"rows"][indexPath.row];
    cell.textLabel.text = rowInfo[@"title"];
    
    if ([rowInfo[@"type"] isEqualToString:@"switch"]) {
        UISwitch *switchView = [[UISwitch alloc] init];
        BOOL isOn = [[DDHelperConfig shared] valueForKey:rowInfo[@"key"]] ? [[[DDHelperConfig shared] valueForKey:rowInfo[@"key"]] boolValue] : NO;
        [switchView setOn:isOn];
        [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        switchView.tag = indexPath.row + indexPath.section * 1000;
        cell.accessoryView = switchView;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else if ([rowInfo[@"type"] isEqualToString:@"input"] || [rowInfo[@"type"] isEqualToString:@"action"]) {
        cell.detailTextLabel.text = rowInfo[@"value"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *rowInfo = _sections[indexPath.section][@"rows"][indexPath.row];
    NSString *type = rowInfo[@"type"];
    NSString *key = rowInfo[@"key"];
    
    if ([type isEqualToString:@"input"]) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:rowInfo[@"title"]
                                                                       message:@"请输入"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.text = rowInfo[@"value"];
            textField.keyboardType = [key containsString:@"Count"] || [key containsString:@"Delay"] ? UIKeyboardTypeNumberPad : UIKeyboardTypeDefault;
        }];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *text = alert.textFields.firstObject.text;
            if ([key isEqualToString:@"likeCount"] || [key isEqualToString:@"commentCount"] || [key isEqualToString:@"redEnvelopDelay"]) {
                [[DDHelperConfig shared] setValue:@(text.integerValue) forKey:key];
            } else {
                [[DDHelperConfig shared] setValue:text forKey:key];
            }
            [[DDHelperConfig shared] saveConfig];
            [self setupSections];
            [self.tableView reloadData];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    } else if ([type isEqualToString:@"action"] && [key isEqualToString:@"redEnvelopGroupFilter"]) {
        // 群聊过滤选择界面
        [self showGroupFilterController];
    }
}

- (void)switchChanged:(UISwitch *)sender {
    NSInteger row = sender.tag % 1000;
    NSInteger section = sender.tag / 1000;
    
    NSDictionary *rowInfo = _sections[section][@"rows"][row];
    NSString *key = rowInfo[@"key"];
    
    [[DDHelperConfig shared] setValue:@(sender.isOn) forKey:key];
    [[DDHelperConfig shared] saveConfig];
    
    // 重新加载表格
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setupSections];
        [self.tableView reloadData];
    });
}

- (void)showGroupFilterController {
    // 这里应该实现群聊选择界面
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"群聊过滤" 
                                                                   message:@"此功能需要获取群聊列表" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
@end

// ====================== Hooks ======================

// 1. 朋友圈转发功能
%hook WCOperateFloatView

%new
- (UIButton *)dd_shareButton {
    static char shareButtonKey;
    UIButton *button = objc_getAssociatedObject(self, &shareButtonKey);
    if (!button && [DDHelperConfig shared].enableTimelineForward) {
        button = [UIButton buttonWithType:UIButtonTypeCustom];
        [button setTitle:@" 转发" forState:UIControlStateNormal];
        [button setTitleColor:self.m_likeBtn.currentTitleColor forState:UIControlStateNormal];
        button.titleLabel.font = self.m_likeBtn.titleLabel.font;
        [button addTarget:self action:@selector(dd_forwardTimeline:) forControlEvents:UIControlEventTouchUpInside];
        
        // 添加图标
        NSString *base64Icon = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAAsTAAALEwEAmpwYAAAAB3RJTUUH5gUXBzEZaYFaygAAARVJREFUOMu9lL1OAzEQhb9ZSBEnRQokFGkiCt5AafgJNFS8CB0VCq+CgoIixb0FCkJPQ0NFwysg/oRuV5Y8FEGOnIvsE9ks2rFnz3xzdgT/MCYaSlpOqSEp64ySNgU8AzeNhkraAl6AG0kfVUZJewIegWtJH7WMkvYB3APXkt6rjE1HI7T0yFTSddVoV9I5cCVpVtd4J2lWZyQwDcyGxgrYjjReSjoFupKeq0b7ko6AC0nPkca1pJ0oY+C5pJ2Q0QXwFzhrYNoF7oCrSKOArUjjpaR94EzSaxPD+WRHGRsZW+dwLOkg4d+jkj6jRpcg6Qj4lXSQKtuX9J2JhjUwB04l7bZdc9+5PQ+clXRUd4M1+bgM3/0H9gWcSPoe0vAHlwAAAABJRU5ErkJggg==";
        NSData *iconData = [[NSData alloc] initWithBase64EncodedString:base64Icon options:0];
        UIImage *icon = [UIImage imageWithData:iconData];
        [button setImage:icon forState:UIControlStateNormal];
        
        [self.m_likeBtn.superview addSubview:button];
        objc_setAssociatedObject(self, &shareButtonKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return button;
}

%new
- (UIImageView *)dd_separatorView {
    static char separatorKey;
    UIImageView *separator = objc_getAssociatedObject(self, &separatorKey);
    if (!separator && [DDHelperConfig shared].enableTimelineForward) {
        separator = [[UIImageView alloc] initWithImage:MSHookIvar<UIImageView *>(self, "m_lineView").image];
        [self.m_likeBtn.superview addSubview:separator];
        objc_setAssociatedObject(self, &separatorKey, separator, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return separator;
}

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig(arg1, arg2);
    
    if ([DDHelperConfig shared].enableTimelineForward) {
        // 调整布局，添加转发按钮
        CGRect frame = self.frame;
        frame.size.width *= 1.25; // 扩大宽度容纳转发按钮
        frame.origin.x -= frame.size.width * 0.1;
        self.frame = frame;
        
        // 布局转发按钮
        UIButton *shareBtn = [self dd_shareButton];
        UIImageView *separator = [self dd_separatorView];
        
        if (shareBtn && separator) {
            CGRect likeFrame = self.m_likeBtn.frame;
            shareBtn.frame = CGRectOffset(likeFrame, likeFrame.size.width * 2, 0);
            separator.frame = CGRectOffset(MSHookIvar<UIImageView *>(self, "m_lineView").frame, likeFrame.size.width, 0);
        }
    }
}

%new
- (void)dd_forwardTimeline:(id)sender {
    WCForwardViewController *forwardVC = [[objc_getClass("WCForwardViewController") alloc] initWithDataItem:self.m_item];
    UINavigationController *nav = self.navigationController;
    if (nav) {
        [nav pushViewController:forwardVC animated:YES];
    }
}

%end

// 2. 集赞助手功能
%hook WCTimelineMgr

- (void)modifyDataItem:(WCDataItem *)arg1 notify:(BOOL)arg2 {
    if ([DDHelperConfig shared].enableLikeAssistant && arg1.likeFlag) {
        // 获取好友列表
        CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
        NSArray *allContacts = [contactMgr getContactList:1 contactType:0];
        
        // 模拟点赞用户
        NSMutableArray *likeUsers = [NSMutableArray array];
        NSInteger likeCount = MIN([DDHelperConfig shared].likeCount, allContacts.count);
        
        for (int i = 0; i < likeCount && i < allContacts.count; i++) {
            CContact *contact = allContacts[i];
            // 创建点赞用户对象
            id likeUser = [[objc_getClass("WCLikeInfo") alloc] init];
            [likeUser setM_nsUsrName:[contact m_nsUsrName]];
            [likeUser setM_nsNickName:[contact getContactDisplayName]];
            [likeUsers addObject:likeUser];
        }
        
        // 模拟评论
        NSMutableArray *commentUsers = [NSMutableArray array];
        NSArray *commentTexts = [[DDHelperConfig shared].comments componentsSeparatedByString:@",,"];
        NSInteger commentCount = MIN([DDHelperConfig shared].commentCount, allContacts.count);
        
        for (int i = 0; i < commentCount && i < allContacts.count && i < commentTexts.count; i++) {
            CContact *contact = allContacts[i];
            NSString *commentText = commentTexts[i % commentTexts.count];
            
            // 创建评论对象
            id comment = [[objc_getClass("WCCommentInfo") alloc] init];
            [comment setM_nsUsrName:[contact m_nsUsrName]];
            [comment setM_nsNickName:[contact getContactDisplayName]];
            [comment setM_nsContent:commentText];
            [commentUsers addObject:comment];
        }
        
        // 更新数据
        [arg1 setLikeUsers:likeUsers];
        [arg1 setLikeCount:(int)likeUsers.count];
        [arg1 setCommentUsers:commentUsers];
        [arg1 setCommentCount:(int)commentUsers.count];
    }
    
    %orig(arg1, arg2);
}

%end

// 3. 自动抢红包功能
%hook CMessageMgr

- (void)onNewSyncAddMessage:(CMessageWrap *)wrap {
    %orig;
    
    // 只处理App消息类型（红包）
    if (wrap.m_uiMessageType == 49 && [DDHelperConfig shared].enableAutoRedEnvelop) {
        NSString *content = wrap.m_nsContent;
        
        // 检查是否为红包消息
        if ([content containsString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"]) {
            // 获取自身信息
            CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
            CContact *selfContact = [contactMgr getSelfContact];
            
            // 判断消息类型
            BOOL isFromGroup = [wrap.m_nsFromUsr containsString:@"@chatroom"];
            BOOL isFromSelf = [wrap.m_nsFromUsr isEqualToString:selfContact.m_nsUsrName];
            BOOL isPersonal = !isFromGroup;
            
            // 群聊过滤
            if (isFromGroup) {
                NSArray *filteredGroups = [DDHelperConfig shared].redEnvelopGroupFilter;
                if ([filteredGroups containsObject:wrap.m_nsFromUsr]) {
                    return; // 在过滤列表中，不抢
                }
            }
            
            // 关键词过滤
            NSString *keywordFilter = [DDHelperConfig shared].redEnvelopKeywordFilter;
            if (keywordFilter.length > 0) {
                // 从红包消息中提取标题
                NSRange titleStart = [content rangeOfString:@"<title><![CDATA["];
                NSRange titleEnd = [content rangeOfString:@"]]></title>"];
                if (titleStart.location != NSNotFound && titleEnd.location != NSNotFound) {
                    NSRange titleRange = NSMakeRange(titleStart.location + titleStart.length, 
                                                    titleEnd.location - (titleStart.location + titleStart.length));
                    NSString *title = [content substringWithRange:titleRange];
                    
                    NSArray *keywords = [keywordFilter componentsSeparatedByString:@","];
                    for (NSString *keyword in keywords) {
                        if ([title containsString:keyword]) {
                            return; // 包含关键词，不抢
                        }
                    }
                }
            }
            
            // 个人红包处理
            if (isPersonal && ![DDHelperConfig shared].enablePersonalRedEnvelop) {
                return; // 不接收个人红包
            }
            
            // 不抢自己发的红包（除非是群聊中自己发的）
            if (isFromSelf && !isFromGroup) {
                return;
            }
            
            // 解析红包参数
            NSRange nativeUrlStart = [content rangeOfString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"];
            if (nativeUrlStart.location != NSNotFound) {
                NSString *nativeUrl = [content substringFromIndex:nativeUrlStart.location];
                NSArray *components = [nativeUrl componentsSeparatedByString:@"&"];
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
                
                // 创建红包参数
                WeChatRedEnvelopParam *envelopParam = [[objc_getClass("WeChatRedEnvelopParam") alloc] init];
                envelopParam.msgType = params[@"msgtype"] ?: @"1";
                envelopParam.sendId = params[@"sendid"] ?: @"";
                envelopParam.channelId = params[@"channelid"] ?: @"1";
                envelopParam.nickName = [selfContact getContactDisplayName];
                envelopParam.headImg = [selfContact m_nsHeadImgUrl];
                envelopParam.nativeUrl = nativeUrl;
                envelopParam.sessionUserName = wrap.m_nsFromUsr;
                envelopParam.sign = params[@"sign"] ?: @"";
                envelopParam.isGroupSender = isFromGroup && isFromSelf;
                
                // 加入队列
                [[objc_getClass("WBRedEnvelopParamQueue") sharedQueue] enqueue:envelopParam];
                
                // 发送查询请求
                NSMutableDictionary *requestParams = [@{
                    @"agreeDuty": @"0",
                    @"channelId": envelopParam.channelId,
                    @"inWay": @"0",
                    @"msgType": envelopParam.msgType,
                    @"nativeUrl": envelopParam.nativeUrl,
                    @"sendId": envelopParam.sendId
                } mutableCopy];
                
                WCRedEnvelopesLogicMgr *logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] 
                                                   getService:objc_getClass("WCRedEnvelopesLogicMgr")];
                [logicMgr ReceiverQueryRedEnvelopesRequest:requestParams];
            }
        }
    }
}

%end

%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig(arg1, arg2);
    
    // 获取响应数据
    NSData *responseData = [arg1 performSelector:@selector(retText)];
    if (!responseData) return;
    
    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
    
    // 检查是否为红包查询响应
    NSInteger cgiCmdid = [[arg1 valueForKey:@"cgiCmdid"] integerValue];
    if (cgiCmdid != 3) return; // 3表示红包查询
    
    // 获取红包参数
    WeChatRedEnvelopParam *param = [[objc_getClass("WBRedEnvelopParamQueue") sharedQueue] dequeue];
    if (!param) return;
    
    // 检查是否可以抢红包
    NSInteger receiveStatus = [responseDict[@"receiveStatus"] integerValue];
    NSInteger hbStatus = [responseDict[@"hbStatus"] integerValue];
    NSString *timingIdentifier = responseDict[@"timingIdentifier"];
    
    if (receiveStatus == 2 || hbStatus == 4 || !timingIdentifier) {
        return; // 已抢过或红包已抢完
    }
    
    param.timingIdentifier = timingIdentifier;
    
    // 计算延迟
    unsigned int delay = (unsigned int)[DDHelperConfig shared].redEnvelopDelay;
    
    // 创建抢红包任务
    WBReceiveRedEnvelopOperation *operation = [[objc_getClass("WBReceiveRedEnvelopOperation") alloc] 
                                              initWithRedEnvelopParam:param delay:delay];
    
    // 添加到任务管理器
    [[objc_getClass("WBRedEnvelopTaskManager") sharedManager] addNormalTask:operation];
}

%end

// 4. 设置入口
%hook NewSettingViewController

- (void)reloadTableData {
    %orig;
    
    // 获取表格管理器
    id tableViewMgr = MSHookIvar<id>(self, "m_tableViewMgr");
    if (!tableViewMgr) return;
    
    // 获取第一个分区
    NSArray *sections = [tableViewMgr valueForKey:@"sections"];
    if (!sections || sections.count == 0) return;
    
    id firstSection = sections[0];
    
    // 创建DD助手设置项
    Class cellClass = objc_getClass("WCTableViewNormalCellManager");
    id ddHelperCell = [cellClass performSelector:@selector(normalCellForSel:target:title:)
                                      withObject:@selector(showDDHelperSettings)
                                      withObject:self
                                      withObject:@"DD助手设置"];
    
    // 添加到第一个分区
    [firstSection performSelector:@selector(addCell:) withObject:ddHelperCell];
    
    // 刷新表格
    UITableView *tableView = [tableViewMgr performSelector:@selector(getTableView)];
    [tableView reloadData];
}

%new
- (void)showDDHelperSettings {
    DDHelperSettingController *settingsVC = [[DDHelperSettingController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    nav.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

%end

// 5. 启动时加载
%ctor {
    @autoreleasepool {
        NSLog(@"🚀 DD助手已加载");
        
        // 初始化配置
        [DDHelperConfig shared];
        
        // 注册设置项
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification 
                                                          object:nil 
                                                           queue:nil 
                                                      usingBlock:^(NSNotification *note) {
            NSLog(@"✅ DD助手初始化完成");
        }];
    }
}