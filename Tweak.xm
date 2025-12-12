// DDHelper.xm
#import <UIKit/UIKit.h>
#import <substrate.h>
#import <objc/runtime.h>

// 配置管理器
@interface DDHelperConfig : NSObject
+ (instancetype)shared;
@property (nonatomic, assign) BOOL autoRedEnvelop;
@property (nonatomic, assign) BOOL timeLineForward;
@property (nonatomic, assign) BOOL likeCommentEnable;
@property (nonatomic, assign) NSInteger redEnvelopDelay;
@property (nonatomic, assign) BOOL redEnvelopCatchMe;
@property (nonatomic, assign) BOOL personalRedEnvelopEnable;
@property (nonatomic, assign) NSInteger likeCount;
@property (nonatomic, assign) NSInteger commentCount;
@property (nonatomic, copy) NSString *comments;
@end

@implementation DDHelperConfig
+ (instancetype)shared {
    static DDHelperConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[DDHelperConfig alloc] init];
        // 默认值
        config.redEnvelopDelay = 0;
        config.likeCount = 20;
        config.commentCount = 10;
        config.comments = @"赞,👍,真棒,好厉害";
    });
    return config;
}

- (void)setAutoRedEnvelop:(BOOL)autoRedEnvelop {
    [[NSUserDefaults standardUserDefaults] setBool:autoRedEnvelop forKey:@"DDHelperAutoRedEnvelop"];
}

- (BOOL)autoRedEnvelop {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DDHelperAutoRedEnvelop"];
}

- (void)setTimeLineForward:(BOOL)timeLineForward {
    [[NSUserDefaults standardUserDefaults] setBool:timeLineForward forKey:@"DDHelperTimeLineForward"];
}

- (BOOL)timeLineForward {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DDHelperTimeLineForward"];
}

- (void)setLikeCommentEnable:(BOOL)likeCommentEnable {
    [[NSUserDefaults standardUserDefaults] setBool:likeCommentEnable forKey:@"DDHelperLikeCommentEnable"];
}

- (BOOL)likeCommentEnable {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DDHelperLikeCommentEnable"];
}

- (void)setRedEnvelopDelay:(NSInteger)redEnvelopDelay {
    [[NSUserDefaults standardUserDefaults] setInteger:redEnvelopDelay forKey:@"DDHelperRedEnvelopDelay"];
}

- (NSInteger)redEnvelopDelay {
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"DDHelperRedEnvelopDelay"];
}

- (void)setRedEnvelopCatchMe:(BOOL)redEnvelopCatchMe {
    [[NSUserDefaults standardUserDefaults] setBool:redEnvelopCatchMe forKey:@"DDHelperRedEnvelopCatchMe"];
}

- (BOOL)redEnvelopCatchMe {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DDHelperRedEnvelopCatchMe"];
}

- (void)setPersonalRedEnvelopEnable:(BOOL)personalRedEnvelopEnable {
    [[NSUserDefaults standardUserDefaults] setBool:personalRedEnvelopEnable forKey:@"DDHelperPersonalRedEnvelopEnable"];
}

- (BOOL)personalRedEnvelopEnable {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DDHelperPersonalRedEnvelopEnable"];
}

- (void)setLikeCount:(NSInteger)likeCount {
    [[NSUserDefaults standardUserDefaults] setInteger:likeCount forKey:@"DDHelperLikeCount"];
}

- (NSInteger)likeCount {
    NSInteger count = [[NSUserDefaults standardUserDefaults] integerForKey:@"DDHelperLikeCount"];
    return count > 0 ? count : 20;
}

- (void)setCommentCount:(NSInteger)commentCount {
    [[NSUserDefaults standardUserDefaults] setInteger:commentCount forKey:@"DDHelperCommentCount"];
}

- (NSInteger)commentCount {
    NSInteger count = [[NSUserDefaults standardUserDefaults] integerForKey:@"DDHelperCommentCount"];
    return count > 0 ? count : 10;
}

- (void)setComments:(NSString *)comments {
    [[NSUserDefaults standardUserDefaults] setObject:comments forKey:@"DDHelperComments"];
}

- (NSString *)comments {
    NSString *str = [[NSUserDefaults standardUserDefaults] stringForKey:@"DDHelperComments"];
    return str ?: @"赞,👍,真棒,好厉害";
}
@end

// 微信红包参数队列
@interface DDRedEnvelopParam : NSObject
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

@implementation DDRedEnvelopParam
@end

@interface DDRedEnvelopQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(DDRedEnvelopParam *)param;
- (DDRedEnvelopParam *)dequeue;
- (BOOL)isEmpty;
@end

@implementation DDRedEnvelopQueue {
    NSMutableArray *_queue;
}

+ (instancetype)sharedQueue {
    static DDRedEnvelopQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[DDRedEnvelopQueue alloc] init];
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
    [_queue addObject:param];
}

- (DDRedEnvelopParam *)dequeue {
    if (_queue.count == 0) return nil;
    DDRedEnvelopParam *first = _queue.firstObject;
    [_queue removeObjectAtIndex:0];
    return first;
}

- (BOOL)isEmpty {
    return _queue.count == 0;
}
@end

// 自动抢红包功能
%hook CMessageMgr

- (void)onNewSyncAddMessage:(id)arg1 {
    %orig;
    
    if (![DDHelperConfig shared].autoRedEnvelop) return;
    
    // 检查是否是红包消息
    if ([arg1 isKindOfClass:objc_getClass("CMessageWrap")]) {
        id wrap = arg1;
        NSInteger msgType = [[wrap valueForKey:@"m_uiMessageType"] integerValue];
        
        if (msgType == 49) { // App消息
            NSString *content = [wrap valueForKey:@"m_nsContent"];
            if ([content containsString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao"]) {
                // 解析红包参数
                NSRange range = [content rangeOfString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"];
                if (range.location != NSNotFound) {
                    NSString *queryString = [content substringFromIndex:range.location + range.length];
                    NSArray *components = [queryString componentsSeparatedByString:@"&"];
                    NSMutableDictionary *params = [NSMutableDictionary dictionary];
                    
                    for (NSString *component in components) {
                        NSArray *keyValue = [component componentsSeparatedByString:@"="];
                        if (keyValue.count == 2) {
                            params[keyValue[0]] = keyValue[1];
                        }
                    }
                    
                    // 判断是否应该抢
                    NSString *fromUser = [wrap valueForKey:@"m_nsFromUsr"];
                    BOOL isGroup = [fromUser containsString:@"@chatroom"];
                    BOOL isSelf = NO; // 需要获取自己的用户名
                    
                    Class contactMgrClass = objc_getClass("CContactMgr");
                    if (contactMgrClass) {
                        id contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:contactMgrClass];
                        id selfContact = [contactMgr getSelfContact];
                        NSString *selfUserName = [selfContact valueForKey:@"m_nsUsrName"];
                        isSelf = [fromUser isEqualToString:selfUserName];
                    }
                    
                    BOOL shouldCatch = YES;
                    if (isGroup) {
                        // 群红包
                        if (isSelf && ![DDHelperConfig shared].redEnvelopCatchMe) {
                            shouldCatch = NO;
                        }
                    } else {
                        // 个人红包
                        shouldCatch = [DDHelperConfig shared].personalRedEnvelopEnable;
                    }
                    
                    if (shouldCatch) {
                        // 存储参数
                        DDRedEnvelopParam *param = [[DDRedEnvelopParam alloc] init];
                        param.msgType = params[@"msgtype"];
                        param.sendId = params[@"sendid"];
                        param.channelId = params[@"channelid"];
                        param.nativeUrl = [[wrap valueForKey:@"m_oWCPayInfoItem"] valueForKey:@"m_c2cNativeUrl"];
                        param.sign = params[@"sign"];
                        param.sessionUserName = fromUser;
                        param.isGroupSender = isSelf;
                        
                        [[DDRedEnvelopQueue sharedQueue] enqueue:param];
                        
                        // 延迟抢红包
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([DDHelperConfig shared].redEnvelopDelay * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                            [self openRedEnvelopWithParam:param];
                        });
                    }
                }
            }
        }
    }
}

- (void)openRedEnvelopWithParam:(DDRedEnvelopParam *)param {
    if (!param) return;
    
    NSMutableDictionary *requestParams = [NSMutableDictionary dictionary];
    requestParams[@"agreeDuty"] = @"0";
    requestParams[@"channelId"] = param.channelId;
    requestParams[@"inWay"] = @"0";
    requestParams[@"msgType"] = param.msgType;
    requestParams[@"nativeUrl"] = param.nativeUrl;
    requestParams[@"sendId"] = param.sendId;
    
    if (param.timingIdentifier) {
        requestParams[@"timingIdentifier"] = param.timingIdentifier;
    }
    
    Class redEnvelopClass = objc_getClass("WCRedEnvelopesLogicMgr");
    if (redEnvelopClass) {
        id logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:redEnvelopClass];
        if ([logicMgr respondsToSelector:@selector(OpenRedEnvelopesRequest:)]) {
            [logicMgr OpenRedEnvelopesRequest:requestParams];
        }
    }
}

%end

%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig;
    
    // 处理红包查询响应
    NSInteger cmdId = [[arg1 valueForKey:@"cgiCmdid"] integerValue];
    if (cmdId == 3) { // 查询红包详情响应
        NSData *retData = [[arg1 valueForKey:@"retText"] valueForKey:@"buffer"];
        if (retData) {
            NSDictionary *response = [NSJSONSerialization JSONObjectWithData:retData options:0 error:nil];
            NSString *timingIdentifier = response[@"timingIdentifier"];
            
            if (timingIdentifier) {
                DDRedEnvelopParam *param = [[DDRedEnvelopQueue sharedQueue] dequeue];
                if (param) {
                    param.timingIdentifier = timingIdentifier;
                    
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([DDHelperConfig shared].redEnvelopDelay * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
                        CMessageMgr *msgMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CMessageMgr")];
                        [msgMgr openRedEnvelopWithParam:param];
                    });
                }
            }
        }
    }
}

%end

// 朋友圈转发功能
%hook WCOperateFloatView

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig;
    
    if (![DDHelperConfig shared].timeLineForward) return;
    
    // 添加转发按钮
    UIButton *forwardBtn = objc_getAssociatedObject(self, @"DDForwardButton");
    if (!forwardBtn) {
        forwardBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [forwardBtn setTitle:@"转发" forState:UIControlStateNormal];
        [forwardBtn setTitleColor:[UIColor colorWithRed:0.2 green:0.5 blue:0.8 alpha:1] forState:UIControlStateNormal];
        forwardBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        [forwardBtn addTarget:self action:@selector(dd_forwardTimeline:) forControlEvents:UIControlEventTouchUpInside];
        
        UIView *superview = [self valueForKey:@"m_likeBtn"];
        if ([superview isKindOfClass:[UIView class]]) {
            [superview.superview addSubview:forwardBtn];
            
            // 调整布局
            CGRect frame = [[self valueForKey:@"m_likeBtn"] frame];
            forwardBtn.frame = CGRectMake(frame.origin.x + frame.size.width * 2 + 10, frame.origin.y, frame.size.width, frame.size.height);
            
            objc_setAssociatedObject(self, @"DDForwardButton", forwardBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    forwardBtn.hidden = NO;
}

- (void)dd_forwardTimeline:(id)sender {
    id dataItem = [self valueForKey:@"m_item"];
    if (dataItem) {
        Class forwardVCClass = objc_getClass("WCForwardViewController");
        if (forwardVCClass) {
            id forwardVC = [[forwardVCClass alloc] initWithDataItem:dataItem];
            UINavigationController *nav = [self valueForKey:@"navigationController"];
            if (nav) {
                [nav pushViewController:forwardVC animated:YES];
            }
        }
    }
}

%end

// 集赞助手功能
%hook WCTimelineMgr

- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2 {
    if ([DDHelperConfig shared].likeCommentEnable) {
        // 修改点赞和评论数据
        [self dd_addFakeLikeAndComment:arg1];
    }
    
    %orig;
}

- (void)dd_addFakeLikeAndComment:(id)dataItem {
    if (!dataItem) return;
    
    // 获取真实好友列表
    NSMutableArray *realFriends = [self dd_getRealFriends];
    
    // 设置点赞
    NSInteger likeCount = [DDHelperConfig shared].likeCount;
    NSInteger actualLikeCount = MIN(likeCount, realFriends.count);
    
    NSMutableArray *likeUsers = [dataItem valueForKey:@"likeUsers"];
    if (!likeUsers) {
        likeUsers = [NSMutableArray array];
        [dataItem setValue:likeUsers forKey:@"likeUsers"];
    }
    
    // 清空现有点赞，添加新的
    [likeUsers removeAllObjects];
    
    for (int i = 0; i < actualLikeCount; i++) {
        id contact = realFriends[i % realFriends.count];
        id likeUser = [self dd_createFakeLikeUserFromContact:contact];
        [likeUsers addObject:likeUser];
    }
    
    [dataItem setValue:@(actualLikeCount) forKey:@"likeCount"];
    
    // 设置评论
    NSInteger commentCount = [DDHelperConfig shared].commentCount;
    NSInteger actualCommentCount = MIN(commentCount, realFriends.count);
    
    NSMutableArray *commentUsers = [dataItem valueForKey:@"commentUsers"];
    if (!commentUsers) {
        commentUsers = [NSMutableArray array];
        [dataItem setValue:commentUsers forKey:@"commentUsers"];
    }
    
    // 保留真实评论，添加新的
    NSArray *existingComments = [commentUsers copy];
    [commentUsers removeAllObjects];
    
    NSArray *comments = [[DDHelperConfig shared].comments componentsSeparatedByString:@","];
    if (comments.count == 0) {
        comments = @[@"赞", @"👍", @"真棒"];
    }
    
    for (int i = 0; i < actualCommentCount; i++) {
        id contact = realFriends[i % realFriends.count];
        id commentUser = [self dd_createFakeCommentUserFromContact:contact 
                                                       commentText:comments[i % comments.count]];
        [commentUsers addObject:commentUser];
    }
    
    // 添加回真实评论
    [commentUsers addObjectsFromArray:existingComments];
    
    [dataItem setValue:@(commentUsers.count) forKey:@"commentCount"];
}

- (NSMutableArray *)dd_getRealFriends {
    NSMutableArray *friends = [NSMutableArray array];
    
    Class contactMgrClass = objc_getClass("CContactMgr");
    if (contactMgrClass) {
        id contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:contactMgrClass];
        
        // 获取好友列表
        if ([contactMgr respondsToSelector:@selector(getContactList:contactType:)]) {
            NSArray *contactList = [contactMgr getContactList:1 contactType:0];
            
            for (id contact in contactList) {
                // 过滤公众号和自己
                BOOL isBrand = [[contact valueForKey:@"isBrandContact"] boolValue];
                BOOL isSelf = [[contact valueForKey:@"m_uiSex"] integerValue] == 0;
                
                if (!isBrand && !isSelf) {
                    [friends addObject:contact];
                }
            }
        }
    }
    
    return friends;
}

- (id)dd_createFakeLikeUserFromContact:(id)contact {
    Class userCommentClass = objc_getClass("WCUserComment");
    if (!userCommentClass) return nil;
    
    id likeUser = [[userCommentClass alloc] init];
    [likeUser setValue:[contact valueForKey:@"m_nsUsrName"] forKey:@"username"];
    [likeUser setValue:[contact valueForKey:@"m_nsNickName"] forKey:@"nickname"];
    [likeUser setValue:@(2) forKey:@"type"]; // 2表示点赞
    [likeUser setValue:@([[NSDate date] timeIntervalSince1970]) forKey:@"createTime"];
    
    return likeUser;
}

- (id)dd_createFakeCommentUserFromContact:(id)contact commentText:(NSString *)text {
    Class userCommentClass = objc_getClass("WCUserComment");
    if (!userCommentClass) return nil;
    
    id commentUser = [[userCommentClass alloc] init];
    [commentUser setValue:[contact valueForKey:@"m_nsUsrName"] forKey:@"username"];
    [commentUser setValue:[contact valueForKey:@"m_nsNickName"] forKey:@"nickname"];
    [commentUser setValue:@(1) forKey:@"type"]; // 1表示评论
    [commentUser setValue:text forKey:@"content"];
    [commentUser setValue:@([[NSDate date] timeIntervalSince1970]) forKey:@"createTime"];
    
    return commentUser;
}

%end

// 设置界面控制器
@interface DDHelperSettingController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *settings;
@end

@implementation DDHelperSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD助手设置";
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 创建表格
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
    // 设置数据
    self.settings = @[
        @{
            @"title": @"自动抢红包",
            @"type": @"switch",
            @"key": @"DDHelperAutoRedEnvelop"
        },
        @{
            @"title": @"抢红包延迟(毫秒)",
            @"type": @"input",
            @"key": @"DDHelperRedEnvelopDelay",
            @"valueType": @"number"
        },
        @{
            @"title": @"抢自己的红包",
            @"type": @"switch",
            @"key": @"DDHelperRedEnvelopCatchMe"
        },
        @{
            @"title": @"抢个人红包",
            @"type": @"switch",
            @"key": @"DDHelperPersonalRedEnvelopEnable"
        },
        @{
            @"title": @"朋友圈转发",
            @"type": @"switch",
            @"key": @"DDHelperTimeLineForward"
        },
        @{
            @"title": @"集赞助手",
            @"type": @"switch",
            @"key": @"DDHelperLikeCommentEnable"
        },
        @{
            @"title": @"点赞数量",
            @"type": @"input",
            @"key": @"DDHelperLikeCount",
            @"valueType": @"number"
        },
        @{
            @"title": @"评论数量",
            @"type": @"input",
            @"key": @"DDHelperCommentCount",
            @"valueType": @"number"
        },
        @{
            @"title": @"评论内容(用逗号分隔)",
            @"type": @"input",
            @"key": @"DDHelperComments",
            @"valueType": @"text"
        }
    ];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.settings.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
    }
    
    NSDictionary *setting = self.settings[indexPath.row];
    NSString *type = setting[@"type"];
    NSString *title = setting[@"title"];
    NSString *key = setting[@"key"];
    
    cell.textLabel.text = title;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if ([type isEqualToString:@"switch"]) {
        UISwitch *switchView = [[UISwitch alloc] init];
        BOOL isOn = [[NSUserDefaults standardUserDefaults] boolForKey:key];
        switchView.on = isOn;
        [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        switchView.tag = indexPath.row;
        cell.accessoryView = switchView;
    } else if ([type isEqualToString:@"input"]) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        // 显示当前值
        NSString *valueType = setting[@"valueType"];
        if ([valueType isEqualToString:@"number"]) {
            NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:key];
            if (value == 0) {
                if ([key isEqualToString:@"DDHelperLikeCount"]) value = 20;
                else if ([key isEqualToString:@"DDHelperCommentCount"]) value = 10;
            }
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)value];
        } else {
            NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:key];
            if (!value) {
                value = @"赞,👍,真棒,好厉害";
            }
            cell.detailTextLabel.text = value;
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *setting = self.settings[indexPath.row];
    NSString *type = setting[@"type"];
    
    if ([type isEqualToString:@"input"]) {
        NSString *title = setting[@"title"];
        NSString *key = setting[@"key"];
        NSString *valueType = setting[@"valueType"];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:@"请输入新值"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            if ([valueType isEqualToString:@"number"]) {
                NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:key];
                if (value == 0) {
                    if ([key isEqualToString:@"DDHelperLikeCount"]) value = 20;
                    else if ([key isEqualToString:@"DDHelperCommentCount"]) value = 10;
                    else if ([key isEqualToString:@"DDHelperRedEnvelopDelay"]) value = 0;
                }
                textField.text = [NSString stringWithFormat:@"%ld", (long)value];
                textField.keyboardType = UIKeyboardTypeNumberPad;
            } else {
                NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:key];
                textField.text = value ?: @"赞,👍,真棒,好厉害";
            }
        }];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *value = alert.textFields.firstObject.text;
            if ([valueType isEqualToString:@"number"]) {
                [[NSUserDefaults standardUserDefaults] setInteger:value.integerValue forKey:key];
            } else {
                [[NSUserDefaults standardUserDefaults] setObject:value forKey:key];
            }
            [self.tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
        }]];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

#pragma mark - Actions

- (void)switchChanged:(UISwitch *)sender {
    NSInteger index = sender.tag;
    if (index >= 0 && index < self.settings.count) {
        NSDictionary *setting = self.settings[index];
        NSString *key = setting[@"key"];
        [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:key];
    }
}

@end

// 插件注册
%ctor {
    @autoreleasepool {
        // 检查iOS版本
        if (@available(iOS 15.0, *)) {
            // 注册到插件管理系统
            if (NSClassFromString(@"WCPluginsMgr")) {
                [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD助手" 
                                                                                   version:@"1.0.0" 
                                                                               controller:@"DDHelperSettingController"];
            }
        }
    }
}