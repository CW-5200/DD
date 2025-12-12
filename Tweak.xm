/*
 DD助手 - 微信功能增强插件
 支持：iOS 15.0+
 功能：自动抢红包、朋友圈转发、集赞助手
*/

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <CaptainHook/CaptainHook.h>
#import <objc/runtime.h>

#pragma mark - 配置文件管理

@interface DDHelperConfig : NSObject

@property (nonatomic, assign) BOOL autoRedEnvelopEnable;          // 自动抢红包开关
@property (nonatomic, assign) BOOL redEnvelopBackgroundEnable;    // 后台抢红包
@property (nonatomic, assign) BOOL redEnvelopCatchSelf;           // 抢自己发的红包
@property (nonatomic, assign) BOOL personalRedEnvelopEnable;      // 接收个人红包
@property (nonatomic, assign) BOOL preventMultipleCatch;          // 防止同时抢多个
@property (nonatomic, assign) NSInteger redEnvelopDelay;          // 抢红包延迟(毫秒)
@property (nonatomic, copy) NSString *redEnvelopTextFilter;       // 关键词过滤
@property (nonatomic, strong) NSArray *redEnvelopGroupFilter;     // 群聊过滤
@property (nonatomic, assign) BOOL timeLineForwardEnable;         // 朋友圈转发开关
@property (nonatomic, assign) BOOL likeCommentEnable;             // 集赞助手开关
@property (nonatomic, strong) NSNumber *likeCount;                // 点赞数
@property (nonatomic, strong) NSNumber *commentCount;             // 评论数
@property (nonatomic, copy) NSString *comments;                   // 评论内容
@property (nonatomic, strong) NSMutableDictionary *realUsernames; // 真实用户名映射

+ (instancetype)shared;

@end

@implementation DDHelperConfig

+ (instancetype)shared {
    static DDHelperConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DDHelperConfig alloc] init];
        [instance loadConfig];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _autoRedEnvelopEnable = NO;
        _redEnvelopBackgroundEnable = NO;
        _redEnvelopCatchSelf = NO;
        _personalRedEnvelopEnable = YES;
        _preventMultipleCatch = YES;
        _redEnvelopDelay = 0;
        _redEnvelopTextFilter = @"";
        _redEnvelopGroupFilter = @[];
        _timeLineForwardEnable = NO;
        _likeCommentEnable = NO;
        _likeCount = @10;
        _commentCount = @5;
        _comments = @"赞,👍,太棒了";
        _realUsernames = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)loadConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _autoRedEnvelopEnable = [defaults boolForKey:@"DD_autoRedEnvelopEnable"];
    _redEnvelopBackgroundEnable = [defaults boolForKey:@"DD_redEnvelopBackgroundEnable"];
    _redEnvelopCatchSelf = [defaults boolForKey:@"DD_redEnvelopCatchSelf"];
    _personalRedEnvelopEnable = [defaults boolForKey:@"DD_personalRedEnvelopEnable"];
    _preventMultipleCatch = [defaults boolForKey:@"DD_preventMultipleCatch"];
    _redEnvelopDelay = [defaults integerForKey:@"DD_redEnvelopDelay"];
    _redEnvelopTextFilter = [defaults stringForKey:@"DD_redEnvelopTextFilter"] ?: @"";
    _redEnvelopGroupFilter = [defaults arrayForKey:@"DD_redEnvelopGroupFilter"] ?: @[];
    _timeLineForwardEnable = [defaults boolForKey:@"DD_timeLineForwardEnable"];
    _likeCommentEnable = [defaults boolForKey:@"DD_likeCommentEnable"];
    _likeCount = @([defaults integerForKey:@"DD_likeCount"]);
    _commentCount = @([defaults integerForKey:@"DD_commentCount"]);
    _comments = [defaults stringForKey:@"DD_comments"] ?: @"赞,👍,太棒了";
    
    NSDictionary *savedUsernames = [defaults dictionaryForKey:@"DD_realUsernames"];
    if (savedUsernames) {
        _realUsernames = [savedUsernames mutableCopy];
    }
}

- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:_autoRedEnvelopEnable forKey:@"DD_autoRedEnvelopEnable"];
    [defaults setBool:_redEnvelopBackgroundEnable forKey:@"DD_redEnvelopBackgroundEnable"];
    [defaults setBool:_redEnvelopCatchSelf forKey:@"DD_redEnvelopCatchSelf"];
    [defaults setBool:_personalRedEnvelopEnable forKey:@"DD_personalRedEnvelopEnable"];
    [defaults setBool:_preventMultipleCatch forKey:@"DD_preventMultipleCatch"];
    [defaults setInteger:_redEnvelopDelay forKey:@"DD_redEnvelopDelay"];
    [defaults setObject:_redEnvelopTextFilter forKey:@"DD_redEnvelopTextFilter"];
    [defaults setObject:_redEnvelopGroupFilter forKey:@"DD_redEnvelopGroupFilter"];
    [defaults setBool:_timeLineForwardEnable forKey:@"DD_timeLineForwardEnable"];
    [defaults setBool:_likeCommentEnable forKey:@"DD_likeCommentEnable"];
    [defaults setInteger:[_likeCount integerValue] forKey:@"DD_likeCount"];
    [defaults setInteger:[_commentCount integerValue] forKey:@"DD_commentCount"];
    [defaults setObject:_comments forKey:@"DD_comments"];
    [defaults setObject:_realUsernames forKey:@"DD_realUsernames"];
    [defaults synchronize];
}

- (void)saveRealUsername:(NSString *)username forDisplayName:(NSString *)displayName {
    if (username && displayName) {
        self.realUsernames[displayName] = username;
        [self saveConfig];
    }
}

- (NSString *)realUsernameForDisplayName:(NSString *)displayName {
    return self.realUsernames[displayName];
}

@end

#pragma mark - 红包相关数据结构

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

@interface DDRedEnvelopParamQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(DDRedEnvelopParam *)param;
- (DDRedEnvelopParam *)dequeue;
- (BOOL)isEmpty;
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
        if (_queue.count == 0) {
            return nil;
        }
        DDRedEnvelopParam *first = _queue.firstObject;
        [_queue removeObjectAtIndex:0];
        return first;
    }
}

- (BOOL)isEmpty {
    @synchronized(self) {
        return _queue.count == 0;
    }
}

@end

@interface DDRedEnvelopTaskManager : NSObject
+ (instancetype)sharedManager;
- (void)addNormalTask:(id)operation;
- (void)addSerialTask:(id)operation;
- (BOOL)serialQueueIsEmpty;
@end

@implementation DDRedEnvelopTaskManager

+ (instancetype)sharedManager {
    static DDRedEnvelopTaskManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[DDRedEnvelopTaskManager alloc] init];
    });
    return manager;
}

- (void)addNormalTask:(id)operation {
    // 实现任务添加逻辑
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if ([operation respondsToSelector:@selector(main)]) {
            [operation performSelector:@selector(main)];
        }
    });
}

- (void)addSerialTask:(id)operation {
    // 实现串行任务添加逻辑
    [self addNormalTask:operation];
}

- (BOOL)serialQueueIsEmpty {
    return YES;
}

@end

#pragma mark - 微信类声明（简化版）

@interface CMessageWrap : NSObject
@property (nonatomic, strong) id m_oWCPayInfoItem;
@property (nonatomic, copy) NSString *m_nsContent;
@property (nonatomic, copy) NSString *m_nsToUsr;
@property (nonatomic, copy) NSString *m_nsFromUsr;
@property (nonatomic, assign) unsigned int m_uiMessageType;
@property (nonatomic, assign) unsigned int m_uiCreateTime;
@end

@interface CContact : NSObject
@property (nonatomic, copy) NSString *m_nsUsrName;
@property (nonatomic, copy) NSString *m_nsNickName;
@property (nonatomic, copy) NSString *m_nsRemark;
- (NSString *)getContactDisplayName;
@end

@interface CContactMgr : NSObject
- (CContact *)getSelfContact;
- (CContact *)getContactByName:(NSString *)name;
@end

@interface WCDataItem : NSObject
@property (nonatomic, strong) NSMutableArray *likeUsers;
@property (nonatomic, assign) int likeCount;
@property (nonatomic, strong) NSMutableArray *commentUsers;
@property (nonatomic, assign) int commentCount;
@property (nonatomic, assign) BOOL likeFlag;
@property (nonatomic, copy) NSString *username;
@end

@interface WCTimelineMgr : NSObject
- (void)modifyDataItem:(WCDataItem *)arg1 notify:(BOOL)arg2;
@end

@interface WCOperateFloatView : UIView
@property (nonatomic, weak) UINavigationController *navigationController;
@property (nonatomic, strong) UIButton *m_likeBtn;
@property (nonatomic, strong) WCDataItem *m_item;
- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2;
@end

@interface WCForwardViewController : UIViewController
- (instancetype)initWithDataItem:(WCDataItem *)arg1;
@end

@interface WCRedEnvelopesLogicMgr : NSObject
- (void)ReceiverQueryRedEnvelopesRequest:(NSDictionary *)params;
- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2;
@end

@interface CMessageMgr : NSObject
- (void)AddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap;
- (void)AddLocalMsg:(NSString *)session MsgWrap:(CMessageWrap *)wrap fixTime:(BOOL)fix NewMsgArriveNotify:(BOOL)notify;
- (void)onNewSyncAddMessage:(CMessageWrap *)wrap;
@end

@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)service;
@end

@interface WCBizUtil : NSObject
+ (NSDictionary *)dictionaryWithDecodedComponets:(NSString *)str separator:(NSString *)sep;
@end

#pragma mark - Hook实现

CHDeclareClass(CMessageMgr)

// 处理新消息（红包检测）
CHMethod1(void, CMessageMgr, onNewSyncAddMessage, CMessageWrap *, wrap) {
    CHSuper1(CMessageMgr, onNewSyncAddMessage, wrap);
    
    if (wrap.m_uiMessageType == 49) { // App消息类型，包含红包
        if (![DDHelperConfig shared].autoRedEnvelopEnable) return;
        
        NSString *content = wrap.m_nsContent;
        if ([content rangeOfString:@"wxpay://"].location == NSNotFound) return;
        
        // 获取联系人信息
        MMServiceCenter *serviceCenter = [objc_getClass("MMServiceCenter") defaultCenter];
        CContactMgr *contactMgr = [serviceCenter getService:objc_getClass("CContactMgr")];
        CContact *selfContact = [contactMgr getSelfContact];
        
        // 检查是否是红包消息
        BOOL (^isRedEnvelopMessage)() = ^BOOL {
            return [content rangeOfString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"].location != NSNotFound;
        };
        
        if (isRedEnvelopMessage()) {
            // 判断是否在群聊中
            BOOL isGroup = [wrap.m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound;
            BOOL isGroupSender = [wrap.m_nsFromUsr isEqualToString:selfContact.m_nsUsrName] && 
                                  [wrap.m_nsToUsr rangeOfString:@"chatroom"].location != NSNotFound;
            
            // 检查过滤条件
            BOOL shouldReceive = YES;
            
            // 群聊过滤
            if (isGroup && [[DDHelperConfig shared].redEnvelopGroupFilter containsObject:wrap.m_nsFromUsr]) {
                shouldReceive = NO;
            }
            
            // 关键词过滤
            if (shouldReceive && [DDHelperConfig shared].redEnvelopTextFilter.length > 0) {
                NSString *textFilter = [DDHelperConfig shared].redEnvelopTextFilter;
                NSArray *keywords = [textFilter componentsSeparatedByString:@","];
                for (NSString *keyword in keywords) {
                    if (keyword.length > 0 && [content containsString:keyword]) {
                        shouldReceive = NO;
                        break;
                    }
                }
            }
            
            // 个人红包开关
            if (!isGroup && ![[DDHelperConfig shared].redEnvelopTextFilter length] && ![DDHelperConfig shared].personalRedEnvelopEnable) {
                shouldReceive = NO;
            }
            
            // 不抢自己发的红包（除非开启）
            if (isGroupSender && ![DDHelperConfig shared].redEnvelopCatchSelf) {
                shouldReceive = NO;
            }
            
            if (shouldReceive) {
                // 解析红包参数
                NSRange range = [content rangeOfString:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"];
                if (range.location != NSNotFound) {
                    NSString *nativeUrl = [content substringFromIndex:range.location];
                    NSString *queryString = [nativeUrl substringFromIndex:range.length];
                    NSDictionary *params = [WCBizUtil dictionaryWithDecodedComponets:queryString separator:@"&"];
                    
                    if (params) {
                        // 查询红包信息
                        NSMutableDictionary *requestParams = [@{
                            @"agreeDuty": @"0",
                            @"channelId": params[@"channelid"] ?: @"",
                            @"inWay": @"0",
                            @"msgType": params[@"msgtype"] ?: @"1",
                            @"nativeUrl": nativeUrl,
                            @"sendId": params[@"sendid"] ?: @""
                        } mutableCopy];
                        
                        WCRedEnvelopesLogicMgr *logicMgr = [serviceCenter getService:objc_getClass("WCRedEnvelopesLogicMgr")];
                        if (logicMgr) {
                            // 存储红包参数
                            DDRedEnvelopParam *param = [[DDRedEnvelopParam alloc] init];
                            param.msgType = params[@"msgtype"];
                            param.sendId = params[@"sendid"];
                            param.channelId = params[@"channelid"];
                            param.nickName = [selfContact getContactDisplayName];
                            param.headImg = @"";
                            param.nativeUrl = nativeUrl;
                            param.sessionUserName = isGroupSender ? wrap.m_nsToUsr : wrap.m_nsFromUsr;
                            param.sign = params[@"sign"];
                            param.isGroupSender = isGroupSender;
                            
                            [[DDRedEnvelopParamQueue sharedQueue] enqueue:param];
                            
                            // 延迟执行
                            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([DDHelperConfig shared].redEnvelopDelay / 1000.0 * NSEC_PER_SEC)), 
                                         dispatch_get_main_queue(), ^{
                                [logicMgr ReceiverQueryRedEnvelopesRequest:requestParams];
                            });
                        }
                    }
                }
            }
        }
    }
}

CHConstructor {
    CHLoadLateClass(CMessageMgr);
    CHHook1(CMessageMgr, onNewSyncAddMessage);
}

#pragma mark - 朋友圈转发Hook

CHDeclareClass(WCOperateFloatView)

// 添加转发按钮
CHMethod2(void, WCOperateFloatView, showWithItemData, id, arg1, tipPoint, struct CGPoint, arg2) {
    CHSuper2(WCOperateFloatView, showWithItemData, arg1, tipPoint, arg2);
    
    if ([DDHelperConfig shared].timeLineForwardEnable) {
        // 查找现有的转发按钮或创建新的
        UIButton *forwardBtn = objc_getAssociatedObject(self, @"dd_forward_btn");
        if (!forwardBtn) {
            forwardBtn = [UIButton buttonWithType:UIButtonTypeCustom];
            [forwardBtn setTitle:@" 转发" forState:UIControlStateNormal];
            [forwardBtn setTitleColor:self.m_likeBtn.currentTitleColor forState:UIControlStateNormal];
            forwardBtn.titleLabel.font = self.m_likeBtn.titleLabel.font;
            [forwardBtn addTarget:self action:@selector(dd_forwardAction:) forControlEvents:UIControlEventTouchUpInside];
            
            // 设置图标
            NSString *base64Icon = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWVgS0saSvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaAZWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
            NSData *iconData = [[NSData alloc] initWithBase64EncodedString:base64Icon options:0];
            UIImage *icon = [UIImage imageWithData:iconData];
            [forwardBtn setImage:icon forState:UIControlStateNormal];
            
            [self addSubview:forwardBtn];
            objc_setAssociatedObject(self, @"dd_forward_btn", forwardBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        
        // 调整布局
        CGRect frame = self.frame;
        frame.size.width += 60;
        self.frame = frame;
        
        CGRect likeFrame = self.m_likeBtn.frame;
        forwardBtn.frame = CGRectMake(CGRectGetMaxX(likeFrame) + 10, likeFrame.origin.y, 50, likeFrame.size.height);
    }
}

// 转发按钮点击事件
- (void)dd_forwardAction:(UIButton *)sender {
    if (self.navigationController) {
        WCForwardViewController *forwardVC = [[objc_getClass("WCForwardViewController") alloc] initWithDataItem:self.m_item];
        [self.navigationController pushViewController:forwardVC animated:YES];
    }
}

CHConstructor {
    CHLoadLateClass(WCOperateFloatView);
    CHHook2(WCOperateFloatView, showWithItemData, tipPoint);
    
    // 添加转发方法
    Class class = objc_getClass("WCOperateFloatView");
    class_addMethod(class, @selector(dd_forwardAction:), 
                   imp_implementationWithBlock(^(id self, UIButton *sender) {
        [(WCOperateFloatView *)self dd_forwardAction:sender];
    }), "v@:@");
}

#pragma mark - 集赞助手Hook

CHDeclareClass(WCTimelineMgr)

// 修改朋友圈数据（集赞）
CHMethod2(void, WCTimelineMgr, modifyDataItem, WCDataItem *, arg1, notify, BOOL, arg2) {
    DDHelperConfig *config = [DDHelperConfig shared];
    
    if (config.likeCommentEnable && arg1.likeFlag) {
        // 获取联系人管理器
        MMServiceCenter *serviceCenter = [objc_getClass("MMServiceCenter") defaultCenter];
        CContactMgr *contactMgr = [serviceCenter getService:objc_getClass("CContactMgr")];
        
        // 生成点赞用户
        NSMutableArray *likeUsers = [NSMutableArray array];
        for (int i = 0; i < [config.likeCount integerValue]; i++) {
            @autoreleasepool {
                id likeUser = [[NSClassFromString(@"WCUserComment") alloc] init];
                if (likeUser) {
                    // 生成虚拟用户名
                    NSString *fakeUsername = [NSString stringWithFormat:@"wxid_%08x%08x", arc4random(), arc4random()];
                    NSString *displayName = [NSString stringWithFormat:@"用户%d", i+1];
                    
                    // 存储真实用户名映射
                    [config saveRealUsername:fakeUsername forDisplayName:displayName];
                    
                    [likeUser setValue:@(1) forKey:@"type"]; // 1表示点赞
                    [likeUser setValue:fakeUsername forKey:@"username"];
                    [likeUser setValue:displayName forKey:@"nickname"];
                    [likeUser setValue:@(arg1.createtime) forKey:@"createTime"];
                    
                    [likeUsers addObject:likeUser];
                }
            }
        }
        
        // 生成评论用户
        NSMutableArray *commentUsers = [NSMutableArray array];
        NSArray *commentTexts = [config.comments componentsSeparatedByString:@","];
        
        for (int i = 0; i < [config.commentCount integerValue] && i < commentTexts.count; i++) {
            @autoreleasepool {
                id commentUser = [[NSClassFromString(@"WCUserComment") alloc] init];
                if (commentUser) {
                    NSString *fakeUsername = [NSString stringWithFormat:@"wxid_%08x%08x", arc4random(), arc4random()];
                    NSString *displayName = [NSString stringWithFormat:@"好友%d", i+1];
                    
                    [config saveRealUsername:fakeUsername forDisplayName:displayName];
                    
                    [commentUser setValue:@(2) forKey:@"type"]; // 2表示评论
                    [commentUser setValue:fakeUsername forKey:@"username"];
                    [commentUser setValue:displayName forKey:@"nickname"];
                    [commentUser setValue:commentTexts[i] forKey:@"content"];
                    [commentUser setValue:@(arg1.createtime) forKey:@"createTime"];
                    
                    [commentUsers addObject:commentUser];
                }
            }
        }
        
        // 设置到数据项
        arg1.likeUsers = likeUsers;
        arg1.likeCount = (int)likeUsers.count;
        arg1.commentUsers = commentUsers;
        arg1.commentCount = (int)commentUsers.count;
    }
    
    CHSuper2(WCTimelineMgr, modifyDataItem, arg1, notify, arg2);
}

CHConstructor {
    CHLoadLateClass(WCTimelineMgr);
    CHHook2(WCTimelineMgr, modifyDataItem, notify);
}

#pragma mark - 红包响应处理Hook

CHDeclareClass(WCRedEnvelopesLogicMgr)

// 处理红包响应
CHMethod2(void, WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, id, arg1, Request, id, arg2) {
    CHSuper2(WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, arg1, Request, arg2);
    
    // 检查是否是查询响应
    NSInteger cgiCmdid = [[arg1 valueForKey:@"cgiCmdid"] integerValue];
    if (cgiCmdid != 3) return; // 3是查询命令
    
    if (![DDHelperConfig shared].autoRedEnvelopEnable) return;
    
    // 解析响应数据
    NSData *responseData = [[arg1 valueForKey:@"retText"] valueForKey:@"buffer"];
    NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:[responseString dataUsingEncoding:NSUTF8StringEncoding] 
                                                              options:0 
                                                                error:nil];
    
    if (!responseDict) return;
    
    // 检查红包状态
    NSInteger receiveStatus = [responseDict[@"receiveStatus"] integerValue];
    NSInteger hbStatus = [responseDict[@"hbStatus"] integerValue];
    NSString *timingIdentifier = responseDict[@"timingIdentifier"];
    
    if (receiveStatus == 2 || hbStatus == 4 || !timingIdentifier) {
        return; // 已抢过或红包已被抢完
    }
    
    // 获取红包参数
    DDRedEnvelopParam *param = [[DDRedEnvelopParamQueue sharedQueue] dequeue];
    if (!param) return;
    
    param.timingIdentifier = timingIdentifier;
    
    // 打开红包
    NSMutableDictionary *openParams = [@{
        @"agreeDuty": @"0",
        @"channelId": param.channelId ?: @"",
        @"inWay": @"0",
        @"msgType": param.msgType ?: @"1",
        @"nativeUrl": param.nativeUrl ?: @"",
        @"sendId": param.sendId ?: @"",
        @"timingIdentifier": timingIdentifier
    } mutableCopy];
    
    // 延迟打开（模拟手动操作）
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        // 这里应该调用打开红包的方法，但需要正确的类和方法名
        // 实际实现可能需要更精确的hook
    });
}

CHConstructor {
    CHLoadLateClass(WCRedEnvelopesLogicMgr);
    CHHook2(WCRedEnvelopesLogicMgr, OnWCToHongbaoCommonResponse, Request);
}

#pragma mark - 插件设置界面

@interface DDHelperSettingController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *sectionTitles;
@property (nonatomic, strong) NSArray *sectionData;

@end

@implementation DDHelperSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"DD助手设置";
    self.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.96 alpha:1.0];
    
    // 创建表格
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.tableView];
    
    // 创建关闭按钮
    UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithTitle:@"关闭" 
                                                                   style:UIBarButtonItemStylePlain 
                                                                  target:self 
                                                                  action:@selector(closeSettings)];
    self.navigationItem.leftBarButtonItem = closeButton;
    
    // 加载数据
    [self loadSectionData];
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    self.tableView.frame = self.view.bounds;
}

- (void)loadSectionData {
    DDHelperConfig *config = [DDHelperConfig shared];
    
    self.sectionTitles = @[@"自动抢红包", @"朋友圈转发", @"集赞助手", @"其他"];
    
    self.sectionData = @[
        @[ // 抢红包设置
            @{@"type": @"switch", @"title": @"自动抢红包", @"key": @"autoRedEnvelopEnable", @"value": @(config.autoRedEnvelopEnable)},
            @{@"type": @"switch", @"title": @"后台抢红包", @"key": @"redEnvelopBackgroundEnable", @"value": @(config.redEnvelopBackgroundEnable)},
            @{@"type": @"switch", @"title": @"抢自己发的红包", @"key": @"redEnvelopCatchSelf", @"value": @(config.redEnvelopCatchSelf)},
            @{@"type": @"switch", @"title": @"接收个人红包", @"key": @"personalRedEnvelopEnable", @"value": @(config.personalRedEnvelopEnable)},
            @{@"type": @"switch", @"title": @"防止同时抢多个", @"key": @"preventMultipleCatch", @"value": @(config.preventMultipleCatch)},
            @{@"type": @"input", @"title": @"延迟时间(毫秒)", @"key": @"redEnvelopDelay", @"value": @(config.redEnvelopDelay)},
            @{@"type": @"input", @"title": @"关键词过滤", @"key": @"redEnvelopTextFilter", @"value": config.redEnvelopTextFilter ?: @""}
        ],
        @[ // 朋友圈转发
            @{@"type": @"switch", @"title": @"朋友圈转发", @"key": @"timeLineForwardEnable", @"value": @(config.timeLineForwardEnable)}
        ],
        @[ // 集赞助手
            @{@"type": @"switch", @"title": @"集赞助手", @"key": @"likeCommentEnable", @"value": @(config.likeCommentEnable)},
            @{@"type": @"input", @"title": @"点赞数量", @"key": @"likeCount", @"value": config.likeCount},
            @{@"type": @"input", @"title": @"评论数量", @"key": @"commentCount", @"value": config.commentCount},
            @{@"type": @"input", @"title": @"评论内容(逗号分隔)", @"key": @"comments", @"value": config.comments ?: @""}
        ],
        @[ // 其他
            @{@"type": @"button", @"title": @"保存设置", @"action": @"saveSettings"},
            @{@"type": @"button", @"title": @"重置设置", @"action": @"resetSettings"},
            @{@"type": @"info", @"title": @"版本信息", @"value": @"DD助手 v1.0.0"}
        ]
    ];
}

#pragma mark - UITableView DataSource & Delegate

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
    cell.accessoryView = nil;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    
    if ([type isEqualToString:@"switch"]) {
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [item[@"value"] boolValue];
        switchView.tag = indexPath.section * 100 + indexPath.row;
        [switchView addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } 
    else if ([type isEqualToString:@"input"]) {
        id value = item[@"value"];
        if ([value isKindOfClass:[NSNumber class]]) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", value];
        } else {
            cell.detailTextLabel.text = value;
        }
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    else if ([type isEqualToString:@"button"]) {
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        cell.textLabel.textColor = [UIColor systemBlueColor];
    }
    else if ([type isEqualToString:@"info"]) {
        cell.detailTextLabel.text = item[@"value"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *item = self.sectionData[indexPath.section][indexPath.row];
    NSString *type = item[@"type"];
    NSString *title = item[@"title"];
    NSString *key = item[@"key"];
    id value = item[@"value"];
    
    if ([type isEqualToString:@"input"]) {
        [self showInputAlertForTitle:title key:key currentValue:value];
    }
    else if ([type isEqualToString:@"button"]) {
        NSString *action = item[@"action"];
        if ([action isEqualToString:@"saveSettings"]) {
            [self saveSettings];
        } else if ([action isEqualToString:@"resetSettings"]) {
            [self resetSettings];
        }
    }
}

#pragma mark - 事件处理

- (void)switchValueChanged:(UISwitch *)sender {
    NSInteger section = sender.tag / 100;
    NSInteger row = sender.tag % 100;
    
    if (section < self.sectionData.count && row < [self.sectionData[section] count]) {
        NSDictionary *item = self.sectionData[section][row];
        NSString *key = item[@"key"];
        
        DDHelperConfig *config = [DDHelperConfig shared];
        [config setValue:@(sender.isOn) forKey:key];
        [config saveConfig];
    }
}

- (void)showInputAlertForTitle:(NSString *)title key:(NSString *)key currentValue:(id)currentValue {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:@"请输入新值"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"请输入";
        if ([currentValue isKindOfClass:[NSNumber class]]) {
            textField.text = [NSString stringWithFormat:@"%@", currentValue];
            textField.keyboardType = UIKeyboardTypeNumberPad;
        } else {
            textField.text = currentValue;
            textField.keyboardType = UIKeyboardTypeDefault;
        }
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *newValue = alert.textFields.firstObject.text;
        DDHelperConfig *config = [DDHelperConfig shared];
        
        if ([key isEqualToString:@"redEnvelopDelay"] || 
            [key isEqualToString:@"likeCount"] || 
            [key isEqualToString:@"commentCount"]) {
            NSInteger intValue = [newValue integerValue];
            [config setValue:@(intValue) forKey:key];
        } else {
            [config setValue:newValue forKey:key];
        }
        
        [config saveConfig];
        [self loadSectionData];
        [self.tableView reloadData];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)saveSettings {
    [[DDHelperConfig shared] saveConfig];
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"保存成功"
                                                                   message:@"设置已保存"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)resetSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"确认重置"
                                                                   message:@"所有设置将恢复为默认值"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"重置" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        // 重置配置
        DDHelperConfig *config = [DDHelperConfig shared];
        config.autoRedEnvelopEnable = NO;
        config.redEnvelopBackgroundEnable = NO;
        config.redEnvelopCatchSelf = NO;
        config.personalRedEnvelopEnable = YES;
        config.preventMultipleCatch = YES;
        config.redEnvelopDelay = 0;
        config.redEnvelopTextFilter = @"";
        config.redEnvelopGroupFilter = @[];
        config.timeLineForwardEnable = NO;
        config.likeCommentEnable = NO;
        config.likeCount = @10;
        config.commentCount = @5;
        config.comments = @"赞,👍,太棒了";
        
        [config saveConfig];
        [self loadSectionData];
        [self.tableView reloadData];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)closeSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

#pragma mark - 插件注册入口

CHConstructor {
    @autoreleasepool {
        // 延迟执行，确保微信完全启动
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            // 检查插件管理器是否存在
            Class WCPluginsMgr = objc_getClass("WCPluginsMgr");
            if (WCPluginsMgr) {
                // 注册带设置页面的插件
                [[WCPluginsMgr sharedInstance] registerControllerWithTitle:@"DD助手" 
                                                                  version:@"1.0.0" 
                                                              controller:@"DDHelperSettingController"];
                
                NSLog(@"[DD助手] 插件注册成功");
            }
        });
    }
}

#pragma mark - 插件管理器实现

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

@implementation WCPluginsMgr

+ (instancetype)sharedInstance {
    static WCPluginsMgr *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WCPluginsMgr alloc] init];
    });
    return instance;
}

- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller {
    NSLog(@"[WCPluginsMgr] 注册插件: %@ v%@", title, version);
    
    // 这里可以添加插件到微信的插件管理界面
    // 实际实现需要根据微信的具体UI结构进行调整
    
    // 示例：在微信的"我"页面添加入口（需要精确的hook点）
    // 在实际插件中，这里需要hook微信的相应界面来添加我们的入口
}

- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key {
    NSLog(@"[WCPluginsMgr] 注册开关: %@", title);
}

@end