// DDHelper.xm
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <CoreMotion/CoreMotion.h>

// 配置管理器
@interface DDHelperConfig : NSObject
+ (instancetype)shared;

// 自动抢红包设置
@property (nonatomic, assign) BOOL autoRedEnvelop;
@property (nonatomic, assign) NSInteger redEnvelopDelay;
@property (nonatomic, copy) NSString *redEnvelopTextFilter;
@property (nonatomic, copy) NSArray *redEnvelopGroupFilter;
@property (nonatomic, assign) BOOL redEnvelopCatchMe;
@property (nonatomic, assign) BOOL redEnvelopMultipleCatch;
@property (nonatomic, assign) BOOL personalRedEnvelopEnable;

// 朋友圈转发
@property (nonatomic, assign) BOOL timeLineForwardEnable;

// 集赞助手
@property (nonatomic, assign) BOOL likeCommentEnable;
@property (nonatomic, strong) NSNumber *likeCount;
@property (nonatomic, strong) NSNumber *commentCount;
@property (nonatomic, copy) NSString *comments;

// 通用
@property (nonatomic, assign) BOOL hasShowTips;
@end

@implementation DDHelperConfig
+ (instancetype)shared {
    static DDHelperConfig *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
        [shared loadConfig];
    });
    return shared;
}

- (void)loadConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 自动抢红包
    self.autoRedEnvelop = [defaults boolForKey:@"DD_autoRedEnvelop"];
    self.redEnvelopDelay = [defaults integerForKey:@"DD_redEnvelopDelay"];
    self.redEnvelopTextFilter = [defaults stringForKey:@"DD_redEnvelopTextFilter"] ?: @"";
    self.redEnvelopGroupFilter = [defaults arrayForKey:@"DD_redEnvelopGroupFilter"] ?: @[];
    self.redEnvelopCatchMe = [defaults boolForKey:@"DD_redEnvelopCatchMe"];
    self.redEnvelopMultipleCatch = [defaults boolForKey:@"DD_redEnvelopMultipleCatch"];
    self.personalRedEnvelopEnable = [defaults boolForKey:@"DD_personalRedEnvelopEnable"];
    
    // 朋友圈转发
    self.timeLineForwardEnable = [defaults boolForKey:@"DD_timeLineForwardEnable"];
    
    // 集赞助手
    self.likeCommentEnable = [defaults boolForKey:@"DD_likeCommentEnable"];
    self.likeCount = @([defaults integerForKey:@"DD_likeCount"] ?: 20);
    self.commentCount = @([defaults integerForKey:@"DD_commentCount"] ?: 10);
    self.comments = [defaults stringForKey:@"DD_comments"] ?: @"赞,,👍,,真不错";
    
    // 通用
    self.hasShowTips = [defaults boolForKey:@"DD_hasShowTips"];
}

- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    // 自动抢红包
    [defaults setBool:self.autoRedEnvelop forKey:@"DD_autoRedEnvelop"];
    [defaults setInteger:self.redEnvelopDelay forKey:@"DD_redEnvelopDelay"];
    [defaults setObject:self.redEnvelopTextFilter forKey:@"DD_redEnvelopTextFilter"];
    [defaults setObject:self.redEnvelopGroupFilter forKey:@"DD_redEnvelopGroupFilter"];
    [defaults setBool:self.redEnvelopCatchMe forKey:@"DD_redEnvelopCatchMe"];
    [defaults setBool:self.redEnvelopMultipleCatch forKey:@"DD_redEnvelopMultipleCatch"];
    [defaults setBool:self.personalRedEnvelopEnable forKey:@"DD_personalRedEnvelopEnable"];
    
    // 朋友圈转发
    [defaults setBool:self.timeLineForwardEnable forKey:@"DD_timeLineForwardEnable"];
    
    // 集赞助手
    [defaults setBool:self.likeCommentEnable forKey:@"DD_likeCommentEnable"];
    [defaults setInteger:self.likeCount.integerValue forKey:@"DD_likeCount"];
    [defaults setInteger:self.commentCount.integerValue forKey:@"DD_commentCount"];
    [defaults setObject:self.comments forKey:@"DD_comments"];
    
    [defaults setBool:self.hasShowTips forKey:@"DD_hasShowTips"];
    [defaults synchronize];
}
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

@interface WBRedEnvelopTaskManager : NSObject
+ (instancetype)sharedManager;
- (void)addNormalTask:(id)task;
- (void)addSerialTask:(id)task;
@property (nonatomic, assign, readonly) BOOL serialQueueIsEmpty;
@end

// 朋友圈数据项
@interface WCDataItem : NSObject
@property (nonatomic, assign) BOOL likeFlag;
@property (nonatomic, strong) NSMutableArray *commentUsers;
@property (nonatomic, assign) int commentCount;
@property (nonatomic, strong) NSMutableArray *likeUsers;
@property (nonatomic, assign) int likeCount;
@end

// 联系人
@interface CContact : NSObject
@property (nonatomic, copy) NSString *m_nsUsrName;
@property (nonatomic, copy) NSString *m_nsNickName;
@end

// 通讯录管理器
@interface CContactMgr : NSObject
- (CContact *)getSelfContact;
- (CContact *)getContactByName:(NSString *)username;
@end

// 服务管理中心
@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)className;
@end

// 消息包装
@interface CMessageWrap : NSObject
@property (nonatomic, assign) unsigned int m_uiMessageType;
@property (nonatomic, copy) NSString *m_nsContent;
@property (nonatomic, copy) NSString *m_nsFromUsr;
@property (nonatomic, copy) NSString *m_nsToUsr;
@property (nonatomic, assign) unsigned int m_uiGameType;
@property (nonatomic, assign) unsigned int m_uiGameContent;
@property (nonatomic, copy) NSString *m_nsEmoticonMD5;
@property (nonatomic, strong) id m_oWCPayInfoItem;
@end

// 消息管理器
@interface CMessageMgr : NSObject
- (void)AddEmoticonMsg:(NSString *)msg MsgWrap:(CMessageWrap *)msgWrap;
- (void)onNewSyncAddMessage:(CMessageWrap *)wrap;
- (id)GetMsg:(NSString *)session n64SvrID:(long long)svrID;
- (void)AddLocalMsg:(NSString *)session MsgWrap:(CMessageWrap *)msgWrap fixTime:(BOOL)fixTime NewMsgArriveNotify:(BOOL)notify;
- (void)RevokeMsg:(NSString *)session MsgWrap:(CMessageWrap *)msgWrap Counter:(unsigned int)counter;
@end

// 红包逻辑管理器
@interface WCRedEnvelopesLogicMgr : NSObject
- (void)ReceiverQueryRedEnvelopesRequest:(NSDictionary *)params;
- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2;
@end

// 朋友圈管理器
@interface WCTimelineMgr : NSObject
- (void)modifyDataItem:(WCDataItem *)arg1 notify:(BOOL)arg2;
@end

// 朋友圈操作浮动视图
@interface WCOperateFloatView : UIView
@property (nonatomic, strong) UIButton *m_likeBtn;
@property (nonatomic, strong) id m_item;
@property (nonatomic, weak) UINavigationController *navigationController;
- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2;
@end

// 转发视图控制器
@interface WCForwardViewController : UIViewController
- (instancetype)initWithDataItem:(id)dataItem;
@end

// 业务工具类
@interface WCBizUtil : NSObject
+ (NSDictionary *)dictionaryWithDecodedComponets:(NSString *)string separator:(NSString *)separator;
@end

// 设置视图控制器
@interface NewSettingViewController : UIViewController
- (void)reloadTableData;
@end

// DD助手设置界面
@interface DDHelperSettingController : UIViewController
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSMutableArray *sections;
@end

// 辅助类
@interface DDHelper : NSObject
+ (instancetype)shared;

// 集赞助手相关
@property (nonatomic, strong) NSMutableArray *commentUsers;
- (NSMutableArray *)commentWith:(WCDataItem *)item;

// 好友检测相关
@property (nonatomic, assign) BOOL checkFriendsEnd;
@property (nonatomic, strong) NSMutableArray *validFriends;
@property (nonatomic, strong) NSMutableArray *notFriends;
@property (nonatomic, strong) NSMutableArray *invalidFriends;
@property (nonatomic, strong) dispatch_semaphore_t friendCheckSem;
@property (nonatomic, strong) id currentCheckResult;
@end

// 红包任务操作
@interface WBReceiveRedEnvelopOperation : NSObject
- (instancetype)initWithRedEnvelopParam:(WeChatRedEnvelopParam *)param delay:(unsigned int)delay;
@end

// 字符串分类
@interface NSString (DDHelper)
- (NSString *)stringForKey:(NSString *)key;
- (NSDictionary *)JSONDictionary;
@end

@implementation NSString (DDHelper)
- (NSString *)stringForKey:(NSString *)key {
    return @"";
}

- (NSDictionary *)JSONDictionary {
    NSData *jsonData = [self dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) return nil;
    
    NSError *error;
    NSDictionary *dictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:&error];
    return dictionary;
}
@end

// 主逻辑实现
%group Ungrouped

// MARK: - 微信设置界面添加DD助手入口
%hook NewSettingViewController
- (void)reloadTableData {
    %orig;
    
    // 获取tableView管理器
    id tableViewMgr = MSHookIvar<id>(self, "m_tableViewMgr");
    if (!tableViewMgr) return;
    
    // 获取第一个section
    NSArray *sections = [tableViewMgr valueForKey:@"sections"];
    if (!sections.count) return;
    
    id firstSection = sections[0];
    
    // 创建DD助手cell
    Class WCTableViewNormalCellManager = objc_getClass("WCTableViewNormalCellManager");
    if (!WCTableViewNormalCellManager) return;
    
    SEL selector = @selector(openDDHelperSettings);
    id ddHelperCell = [WCTableViewNormalCellManager performSelector:@selector(normalCellForSel:target:title:) 
                                                         withObject:selector
                                                         withObject:self
                                                         withObject:@"DD助手"];
    
    // 添加到section
    [firstSection performSelector:@selector(addCell:) withObject:ddHelperCell];
    
    // 刷新表格
    id tableView = [tableViewMgr performSelector:@selector(getTableView)];
    if (tableView) {
        [tableView performSelector:@selector(reloadData)];
    }
}

%new
- (void)openDDHelperSettings {
    DDHelperSettingController *vc = [[DDHelperSettingController alloc] init];
    vc.modalPresentationStyle = UIModalPresentationFormSheet;
    if (@available(iOS 15.0, *)) {
        vc.sheetPresentationController.detents = @[[UISheetPresentationControllerDetent mediumDetent], 
                                                   [UISheetPresentationControllerDetent largeDetent]];
        vc.sheetPresentationController.prefersGrabberVisible = YES;
    }
    [self presentViewController:vc animated:YES completion:nil];
}
%end

// MARK: - 消息管理器Hook (自动抢红包核心逻辑)
%hook CMessageMgr
- (void)onNewSyncAddMessage:(CMessageWrap *)wrap {
    %orig;
    
    // 只处理AppNode消息类型(49)
    if (wrap.m_uiMessageType != 49) return;
    
    // 获取联系人管理器
    Class MMServiceCenter = objc_getClass("MMServiceCenter");
    Class CContactMgrClass = objc_getClass("CContactMgr");
    if (!MMServiceCenter || !CContactMgrClass) return;
    
    MMServiceCenter *serviceCenter = [MMServiceCenter performSelector:@selector(defaultCenter)];
    CContactMgr *contactMgr = [serviceCenter performSelector:@selector(getService:) withObject:CContactMgrClass];
    CContact *selfContact = [contactMgr getSelfContact];
    
    // 判断是否为红包消息
    BOOL isRedEnvelopMessage = [wrap.m_nsContent rangeOfString:@"wxpay://"].location != NSNotFound;
    if (!isRedEnvelopMessage) return;
    
    DDHelperConfig *config = [DDHelperConfig shared];
    if (!config.autoRedEnvelop) return;
    
    // 判断是否在群聊中
    BOOL isGroupReceiver = [wrap.m_nsFromUsr rangeOfString:@"@chatroom"].location != NSNotFound;
    BOOL isGroupSender = [[selfContact.m_nsUsrName isEqualToString:wrap.m_nsFromUsr] && 
                         [wrap.m_nsToUsr rangeOfString:@"chatroom"].location != NSNotFound];
    
    // 是否接收个人红包
    if (!isGroupReceiver && !config.personalRedEnvelopEnable) return;
    
    // 是否在黑名单群组中
    if (isGroupReceiver && [config.redEnvelopGroupFilter containsObject:wrap.m_nsFromUsr]) return;
    
    // 是否包含关键词过滤
    if (config.redEnvelopTextFilter.length > 0) {
        NSString *content = wrap.m_nsContent;
        NSRange range1 = [content rangeOfString:@"receivertitle><![CDATA["];
        NSRange range2 = [content rangeOfString:@"]]></receivertitle>"];
        if (range1.location != NSNotFound && range2.location != NSNotFound) {
            NSRange range3 = NSMakeRange(range1.location + range1.length, 
                                        range2.location - range1.location - range1.length);
            NSString *title = [content substringWithRange:range3];
            
            NSArray *keywords = [config.redEnvelopTextFilter componentsSeparatedByString:@","];
            for (NSString *keyword in keywords) {
                if ([title containsString:keyword]) {
                    return; // 包含过滤关键词，不抢
                }
            }
        }
    }
    
    // 是否抢自己的红包
    if (isGroupSender && !config.redEnvelopCatchMe) return;
    
    // 解析nativeUrl
    id payInfoItem = wrap.m_oWCPayInfoItem;
    if (!payInfoItem) return;
    
    NSString *nativeUrl = [payInfoItem performSelector:@selector(m_c2cNativeUrl)];
    if (!nativeUrl) return;
    
    // 解析参数
    NSString *queryString = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
    NSDictionary *nativeUrlDict = [WCBizUtil dictionaryWithDecodedComponets:queryString separator:@"&"];
    
    // 创建红包参数
    WeChatRedEnvelopParam *param = [[WeChatRedEnvelopParam alloc] init];
    param.msgType = [nativeUrlDict stringForKey:@"msgtype"];
    param.sendId = [nativeUrlDict stringForKey:@"sendid"];
    param.channelId = [nativeUrlDict stringForKey:@"channelid"];
    param.nickName = [selfContact.m_nsNickName];
    param.headImg = [selfContact performSelector:@selector(m_nsHeadImgUrl)];
    param.nativeUrl = nativeUrl;
    param.sessionUserName = isGroupSender ? wrap.m_nsToUsr : wrap.m_nsFromUsr;
    param.sign = [nativeUrlDict stringForKey:@"sign"];
    param.isGroupSender = isGroupSender;
    
    // 加入队列
    [[WBRedEnvelopParamQueue sharedQueue] enqueue:param];
    
    // 发起查询请求
    NSMutableDictionary *params = [@{
        @"agreeDuty": @"0",
        @"channelId": [nativeUrlDict stringForKey:@"channelid"],
        @"inWay": @"0",
        @"msgType": [nativeUrlDict stringForKey:@"msgtype"],
        @"nativeUrl": nativeUrl,
        @"sendId": [nativeUrlDict stringForKey:@"sendid"]
    } mutableCopy];
    
    WCRedEnvelopesLogicMgr *logicMgr = [serviceCenter performSelector:@selector(getService:) 
                                                           withObject:objc_getClass("WCRedEnvelopesLogicMgr")];
    [logicMgr ReceiverQueryRedEnvelopesRequest:params];
}
%end

// MARK: - 红包逻辑管理器Hook
%hook WCRedEnvelopesLogicMgr
- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig;
    
    // 获取响应数据
    NSData *retTextData = [arg1 performSelector:@selector(retText)];
    if (!retTextData) return;
    
    NSString *responseString = [[NSString alloc] initWithData:retTextData encoding:NSUTF8StringEncoding];
    NSDictionary *responseDict = [responseString JSONDictionary];
    
    // 获取请求数据
    NSData *reqTextData = [arg2 performSelector:@selector(reqText)];
    NSString *requestString = [[NSString alloc] initWithData:reqTextData encoding:NSUTF8StringEncoding];
    NSDictionary *requestDict = [WCBizUtil dictionaryWithDecodedComponets:requestString separator:@"&"];
    
    // 获取红包参数
    WeChatRedEnvelopParam *param = [[WBRedEnvelopParamQueue sharedQueue] dequeue];
    if (!param) return;
    
    // 检查是否应该抢红包
    BOOL shouldReceive = YES;
    
    // 检查响应状态
    if ([responseDict[@"receiveStatus"] integerValue] == 2) {
        shouldReceive = NO; // 已经抢过
    }
    
    if ([responseDict[@"hbStatus"] integerValue] == 4) {
        shouldReceive = NO; // 红包已被抢完
    }
    
    if (!responseDict[@"timingIdentifier"]) {
        shouldReceive = NO; // 没有timingIdentifier
    }
    
    // 检查签名（非自己发送的红包）
    if (!param.isGroupSender) {
        NSString *nativeUrl = [[requestDict stringForKey:@"nativeUrl"] stringByRemovingPercentEncoding];
        NSDictionary *nativeUrlDict = [WCBizUtil dictionaryWithDecodedComponets:nativeUrl separator:@"&"];
        NSString *requestSign = [nativeUrlDict stringForKey:@"sign"];
        
        if (![requestSign isEqualToString:param.sign]) {
            shouldReceive = NO;
        }
    }
    
    if (shouldReceive) {
        param.timingIdentifier = responseDict[@"timingIdentifier"];
        
        // 计算延迟
        unsigned int delay = 0;
        DDHelperConfig *config = [DDHelperConfig shared];
        
        if (config.redEnvelopDelay > 0) {
            if (config.redEnvelopMultipleCatch && 
                ![WBRedEnvelopTaskManager sharedManager].serialQueueIsEmpty) {
                delay = 15000; // 15秒延迟，防止同时抢多个
            } else {
                delay = (unsigned int)config.redEnvelopDelay;
            }
        }
        
        // 创建抢红包任务
        WBReceiveRedEnvelopOperation *operation = [[WBReceiveRedEnvelopOperation alloc] 
                                                   initWithRedEnvelopParam:param 
                                                   delay:delay];
        
        if (config.redEnvelopMultipleCatch) {
            [[WBRedEnvelopTaskManager sharedManager] addSerialTask:operation];
        } else {
            [[WBRedEnvelopTaskManager sharedManager] addNormalTask:operation];
        }
    }
}
%end

// MARK: - 朋友圈管理器Hook (集赞助手核心逻辑)
%hook WCTimelineMgr
- (void)modifyDataItem:(WCDataItem *)arg1 notify:(BOOL)arg2 {
    DDHelperConfig *config = [DDHelperConfig shared];
    
    if (!config.likeCommentEnable) {
        %orig(arg1, arg2);
        return;
    }
    
    if (arg1.likeFlag) {
        // 获取真实好友用户名
        NSMutableArray *realFriends = [NSMutableArray array];
        
        // 这里需要获取真实好友列表
        // 由于原代码复杂，这里简化为使用预设的评论用户
        DDHelper *helper = [DDHelper shared];
        NSArray *commentUsers = [helper commentWith:arg1];
        
        // 设置评论用户
        arg1.commentUsers = [commentUsers mutableCopy];
        arg1.commentCount = (int)commentUsers.count;
        
        // 设置点赞用户
        arg1.likeUsers = [helper.commentUsers mutableCopy];
        arg1.likeCount = (int)helper.commentUsers.count;
    }
    
    %orig(arg1, arg2);
}
%end

// MARK: - 朋友圈操作浮动视图Hook (朋友圈转发)
%hook WCOperateFloatView
- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig(arg1, arg2);
    
    DDHelperConfig *config = [DDHelperConfig shared];
    if (!config.timeLineForwardEnable) return;
    
    // 调整frame以容纳转发按钮
    CGRect frame = self.frame;
    frame = CGRectInset(frame, -frame.size.width / 4, 0);
    frame = CGRectOffset(frame, -frame.size.width / 4, 0);
    self.frame = frame;
    
    // 创建转发按钮
    static char forwardBtnKey;
    UIButton *forwardBtn = objc_getAssociatedObject(self, &forwardBtnKey);
    
    if (!forwardBtn) {
        forwardBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [forwardBtn setTitle:@" 转发" forState:UIControlStateNormal];
        [forwardBtn addTarget:self action:@selector(forwardTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        [forwardBtn setTitleColor:self.m_likeBtn.currentTitleColor forState:UIControlStateNormal];
        forwardBtn.titleLabel.font = self.m_likeBtn.titleLabel.font;
        
        // 设置图标（Base64编码的图标）
        NSString *base64Icon = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzUCAZWAIOAaWk06jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *iconData = [[NSData alloc] initWithBase64EncodedString:base64Icon options:0];
        UIImage *icon = [UIImage imageWithData:iconData];
        [forwardBtn setImage:icon forState:UIControlStateNormal];
        
        [self.m_likeBtn.superview addSubview:forwardBtn];
        objc_setAssociatedObject(self, &forwardBtnKey, forwardBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    // 设置转发按钮位置
    forwardBtn.frame = CGRectOffset(self.m_likeBtn.frame, self.m_likeBtn.frame.size.width * 2, 0);
}

%new
- (void)forwardTimeLine:(id)sender {
    if (!self.m_item) return;
    
    Class WCForwardViewControllerClass = objc_getClass("WCForwardViewController");
    if (!WCForwardViewControllerClass) return;
    
    WCForwardViewController *forwardVC = [[WCForwardViewControllerClass alloc] initWithDataItem:self.m_item];
    if (self.navigationController) {
        [self.navigationController pushViewController:forwardVC animated:YES];
    }
}
%end

// MARK: - DD助手设置界面实现
@implementation DDHelperSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (@available(iOS 15.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
    } else {
        self.view.backgroundColor = [UIColor whiteColor];
    }
    
    self.title = @"DD助手设置";
    
    // 创建导航栏
    UINavigationBar *navBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
    UINavigationItem *navItem = [[UINavigationItem alloc] initWithTitle:@"DD助手设置"];
    navItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                               target:self 
                                                                               action:@selector(dismissSettings)];
    [navBar setItems:@[navItem]];
    [self.view addSubview:navBar];
    
    // 创建表格
    self.tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 44, self.view.bounds.size.width, self.view.bounds.size.height - 44) 
                                                  style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
    // 加载设置项
    [self loadSettings];
    
    // 显示提示
    [self showTipsIfNeeded];
}

- (void)loadSettings {
    self.sections = [NSMutableArray array];
    
    // 第1部分：自动抢红包
    NSMutableArray *redEnvelopSection = [NSMutableArray array];
    
    // 自动抢红包开关
    [redEnvelopSection addObject:@{
        @"type": @"switch",
        @"title": @"自动抢红包",
        @"key": @"autoRedEnvelop",
        @"value": @([DDHelperConfig shared].autoRedEnvelop)
    }];
    
    if ([DDHelperConfig shared].autoRedEnvelop) {
        // 延迟设置
        [redEnvelopSection addObject:@{
            @"type": @"input",
            @"title": @"延迟抢红包(毫秒)",
            @"key": @"redEnvelopDelay",
            @"value": @([DDHelperConfig shared].redEnvelopDelay)
        }];
        
        // 关键词过滤
        [redEnvelopSection addObject:@{
            @"type": @"input",
            @"title": @"关键词过滤(逗号分隔)",
            @"key": @"redEnvelopTextFilter",
            @"value": [DDHelperConfig shared].redEnvelopTextFilter ?: @""
        }];
        
        // 个人红包开关
        [redEnvelopSection addObject:@{
            @"type": @"switch",
            @"title": @"接收个人红包",
            @"key": @"personalRedEnvelopEnable",
            @"value": @([DDHelperConfig shared].personalRedEnvelopEnable)
        }];
        
        // 抢自己红包开关
        [redEnvelopSection addObject:@{
            @"type": @"switch",
            @"title": @"抢自己的红包",
            @"key": @"redEnvelopCatchMe",
            @"value": @([DDHelperConfig shared].redEnvelopCatchMe)
        }];
        
        // 防止同时抢多个
        [redEnvelopSection addObject:@{
            @"type": @"switch",
            @"title": @"防止同时抢多个",
            @"key": @"redEnvelopMultipleCatch",
            @"value": @([DDHelperConfig shared].redEnvelopMultipleCatch)
        }];
    }
    
    [self.sections addObject:@{
        @"title": @"自动抢红包设置",
        @"items": redEnvelopSection
    }];
    
    // 第2部分：朋友圈转发
    NSMutableArray *timelineSection = [NSMutableArray array];
    [timelineSection addObject:@{
        @"type": @"switch",
        @"title": @"朋友圈转发",
        @"key": @"timeLineForwardEnable",
        @"value": @([DDHelperConfig shared].timeLineForwardEnable)
    }];
    
    [self.sections addObject:@{
        @"title": @"朋友圈功能",
        @"items": timelineSection
    }];
    
    // 第3部分：集赞助手
    NSMutableArray *likeCommentSection = [NSMutableArray array];
    [likeCommentSection addObject:@{
        @"type": @"switch",
        @"title": @"集赞助手",
        @"key": @"likeCommentEnable",
        @"value": @([DDHelperConfig shared].likeCommentEnable)
    }];
    
    if ([DDHelperConfig shared].likeCommentEnable) {
        // 点赞数设置
        [likeCommentSection addObject:@{
            @"type": @"input",
            @"title": @"点赞数量",
            @"key": @"likeCount",
            @"value": [DDHelperConfig shared].likeCount
        }];
        
        // 评论数设置
        [likeCommentSection addObject:@{
            @"type": @"input",
            @"title": @"评论数量",
            @"key": @"commentCount",
            @"value": [DDHelperConfig shared].commentCount
        }];
        
        // 评论内容设置
        [likeCommentSection addObject:@{
            @"type": @"input",
            @"title": @"评论内容(逗号分隔)",
            @"key": @"comments",
            @"value": [DDHelperConfig shared].comments ?: @""
        }];
    }
    
    [self.sections addObject:@{
        @"title": @"集赞助手设置",
        @"items": likeCommentSection
    }];
}

- (void)showTipsIfNeeded {
    DDHelperConfig *config = [DDHelperConfig shared];
    if (config.hasShowTips) return;
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"重要提示" 
                                                                   message:@"本插件仅供学习和娱乐使用，使用过程中请注意遵守相关法律法规和平台规则。由使用本插件产生的任何问题需由使用者自行承担。" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"我已明白" 
                                              style:UIAlertActionStyleDefault 
                                            handler:^(UIAlertAction * _Nonnull action) {
        config.hasShowTips = YES;
        [config saveConfig];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)dismissSettings {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableView DataSource & Delegate
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *sectionData = self.sections[section];
    NSArray *items = sectionData[@"items"];
    return items.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSDictionary *sectionData = self.sections[section];
    return sectionData[@"title"];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *sectionData = self.sections[indexPath.section];
    NSArray *items = sectionData[@"items"];
    NSDictionary *item = items[indexPath.row];
    
    NSString *type = item[@"type"];
    NSString *title = item[@"title"];
    id value = item[@"value"];
    
    if ([type isEqualToString:@"switch"]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SwitchCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"SwitchCell"];
        }
        
        cell.textLabel.text = title;
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [value boolValue];
        switchView.tag = indexPath.section * 100 + indexPath.row;
        [switchView addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
        
        cell.accessoryView = switchView;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        return cell;
    } else if ([type isEqualToString:@"input"]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"InputCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"InputCell"];
        }
        
        cell.textLabel.text = title;
        cell.detailTextLabel.text = [value description];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        return cell;
    }
    
    return [[UITableViewCell alloc] init];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *sectionData = self.sections[indexPath.section];
    NSArray *items = sectionData[@"items"];
    NSDictionary *item = items[indexPath.row];
    
    if ([item[@"type"] isEqualToString:@"input"]) {
        NSString *key = item[@"key"];
        NSString *title = item[@"title"];
        id currentValue = item[@"value"];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title 
                                                                       message:@"请输入新值" 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.text = [currentValue description];
            if ([key isEqualToString:@"redEnvelopDelay"]) {
                textField.keyboardType = UIKeyboardTypeNumberPad;
            }
        }];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" 
                                                  style:UIAlertActionStyleDefault 
                                                handler:^(UIAlertAction * _Nonnull action) {
            NSString *newValue = alert.textFields.firstObject.text;
            DDHelperConfig *config = [DDHelperConfig shared];
            
            if ([key isEqualToString:@"redEnvelopDelay"]) {
                config.redEnvelopDelay = [newValue integerValue];
            } else if ([key isEqualToString:@"redEnvelopTextFilter"]) {
                config.redEnvelopTextFilter = newValue;
            } else if ([key isEqualToString:@"likeCount"]) {
                config.likeCount = @([newValue integerValue]);
            } else if ([key isEqualToString:@"commentCount"]) {
                config.commentCount = @([newValue integerValue]);
            } else if ([key isEqualToString:@"comments"]) {
                config.comments = newValue;
            }
            
            [config saveConfig];
            [self loadSettings];
            [self.tableView reloadData];
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" 
                                                  style:UIAlertActionStyleCancel 
                                                handler:nil]];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)switchValueChanged:(UISwitch *)sender {
    NSInteger section = sender.tag / 100;
    NSInteger row = sender.tag % 100;
    
    NSDictionary *sectionData = self.sections[section];
    NSArray *items = sectionData[@"items"];
    NSDictionary *item = items[row];
    NSString *key = item[@"key"];
    
    DDHelperConfig *config = [DDHelperConfig shared];
    
    if ([key isEqualToString:@"autoRedEnvelop"]) {
        config.autoRedEnvelop = sender.isOn;
    } else if ([key isEqualToString:@"personalRedEnvelopEnable"]) {
        config.personalRedEnvelopEnable = sender.isOn;
    } else if ([key isEqualToString:@"redEnvelopCatchMe"]) {
        config.redEnvelopCatchMe = sender.isOn;
    } else if ([key isEqualToString:@"redEnvelopMultipleCatch"]) {
        config.redEnvelopMultipleCatch = sender.isOn;
    } else if ([key isEqualToString:@"timeLineForwardEnable"]) {
        config.timeLineForwardEnable = sender.isOn;
    } else if ([key isEqualToString:@"likeCommentEnable"]) {
        config.likeCommentEnable = sender.isOn;
    }
    
    [config saveConfig];
    
    // 重新加载设置（显示/隐藏相关选项）
    [self loadSettings];
    [self.tableView reloadData];
}

@end

// MARK: - DDHelper实现
@implementation DDHelper

+ (instancetype)shared {
    static DDHelper *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _commentUsers = [NSMutableArray array];
        _validFriends = [NSMutableArray array];
        _notFriends = [NSMutableArray array];
        _invalidFriends = [NSMutableArray array];
        _friendCheckSem = dispatch_semaphore_create(0);
    }
    return self;
}

- (NSMutableArray *)commentWith:(WCDataItem *)item {
    DDHelperConfig *config = [DDHelperConfig shared];
    NSMutableArray *comments = [NSMutableArray array];
    
    // 获取真实好友列表（这里需要实际获取好友列表的逻辑）
    // 由于原代码复杂，这里简化为创建模拟评论
    
    NSArray *commentTexts = [config.comments componentsSeparatedByString:@","];
    NSInteger commentCount = MIN(config.commentCount.integerValue, commentTexts.count);
    
    for (int i = 0; i < commentCount; i++) {
        if (i < commentTexts.count) {
            NSString *commentText = commentTexts[i];
            if (commentText.length > 0) {
                // 创建评论对象（这里需要实际评论对象的创建逻辑）
                // 简化为字符串数组
                [comments addObject:commentText];
            }
        }
    }
    
    // 生成点赞用户列表
    [_commentUsers removeAllObjects];
    NSInteger likeCount = MIN(config.likeCount.integerValue, 50); // 限制最多50个
    
    for (int i = 0; i < likeCount; i++) {
        // 这里应该添加真实好友用户名
        // 简化为模拟用户名
        NSString *fakeUsername = [NSString stringWithFormat:@"好友%d", i+1];
        [_commentUsers addObject:fakeUsername];
    }
    
    return comments;
}

@end

// 初始化Logos
%ctor {
    %init(Ungrouped);
    
    // 注册通知
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification 
                                                      object:nil 
                                                       queue:nil 
                                                  usingBlock:^(NSNotification *note) {
        NSLog(@"DD助手已加载 - 版本1.0");
    }];
}