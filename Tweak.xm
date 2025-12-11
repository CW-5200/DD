// WeChatHelper.xm
// 微信小助手插件 - 核心功能版

%config(generator = internal)

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

#pragma mark - 配置类

@interface WeChatConfig : NSObject
+ (instancetype)shared;

// 抢红包配置
@property (nonatomic, assign) BOOL autoRedEnvelop;          // 自动抢红包
@property (nonatomic, assign) NSInteger redEnvelopDelay;   // 延迟时间（毫秒）
@property (nonatomic, strong) NSArray *redEnvelopGroupFiter; // 过滤的群聊
@property (nonatomic, strong) NSString *redEnvelopTextFiter; // 关键词过滤
@property (nonatomic, assign) BOOL personalRedEnvelopEnable; // 接收个人红包
@property (nonatomic, assign) BOOL redEnvelopCatchMe;        // 抢自己的红包
@property (nonatomic, assign) BOOL redEnvelopMultipleCatch;  // 防止同时抢多个红包

// 朋友圈配置
@property (nonatomic, assign) BOOL timeLineForwardEnable;   // 朋友圈转发
@property (nonatomic, assign) BOOL likeCommentEnable;       // 集赞助手
@property (nonatomic, strong) NSNumber *likeCount;          // 点赞数
@property (nonatomic, strong) NSNumber *commentCount;       // 评论数
@property (nonatomic, strong) NSString *comments;           // 评论内容
@end

#pragma mark - 数据结构

@interface CMessageWrap : NSObject
@property (nonatomic, strong) NSString *m_nsContent;
@property (nonatomic, strong) NSString *m_nsFromUsr;
@property (nonatomic, strong) NSString *m_nsToUsr;
@property (nonatomic, assign) NSUInteger m_uiMessageType;
@property (nonatomic, assign) NSUInteger m_uiGameType;
@property (nonatomic, strong) NSString *m_nsEmoticonMD5;
@property (nonatomic, assign) NSUInteger m_uiGameContent;
- (id)m_oWCPayInfoItem;
@end

@interface CContact : NSObject
@property (nonatomic, strong) NSString *m_nsUsrName;
@property (nonatomic, strong) NSString *m_nsHeadImgUrl;
- (NSString *)getContactDisplayName;
@end

@interface WCPayInfoItem : NSObject
@property (nonatomic, strong) NSString *m_c2cNativeUrl;
@end

@interface WCDataItem : NSObject
@property (nonatomic, assign) BOOL likeFlag;
@property (nonatomic, strong) NSArray *commentUsers;
@property (nonatomic, assign) int commentCount;
@property (nonatomic, strong) NSArray *likeUsers;
@property (nonatomic, assign) int likeCount;
@end

@interface WCOperateFloatView : UIView
@property (nonatomic, strong) UIButton *m_likeBtn;
@property (nonatomic, strong) id m_item;
@end

#pragma mark - 配置实现

@implementation WeChatConfig

+ (instancetype)shared {
    static WeChatConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WeChatConfig alloc] init];
        
        // 默认配置
        instance.autoRedEnvelop = YES;
        instance.redEnvelopDelay = 0;
        instance.redEnvelopGroupFiter = @[];
        instance.redEnvelopTextFiter = @"";
        instance.personalRedEnvelopEnable = YES;
        instance.redEnvelopCatchMe = NO;
        instance.redEnvelopMultipleCatch = YES;
        
        instance.timeLineForwardEnable = YES;
        instance.likeCommentEnable = NO;
        instance.likeCount = @10;
        instance.commentCount = @5;
        instance.comments = @"赞,,👍";
    });
    return instance;
}

@end

#pragma mark - 朋友圈转发功能

%hook WCOperateFloatView

%new
- (UIButton *)m_shareBtn {
    static char m_shareBtnKey;
    UIButton *btn = objc_getAssociatedObject(self, &m_shareBtnKey);
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        [btn setTitleColor:self.m_likeBtn.currentTitleColor forState:0];
        btn.titleLabel.font = self.m_likeBtn.titleLabel.font;
        [self.m_likeBtn.superview addSubview:btn];
        
        // 转发图标（Base64编码的图片）
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaABWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:0];
        [btn setTintColor:self.m_likeBtn.tintColor];
        
        objc_setAssociatedObject(self, &m_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

%new
- (UIImageView *)m_lineView2 {
    static char m_lineView2Key;
    UIImageView *imageView = objc_getAssociatedObject(self, &m_lineView2Key);
    if (!imageView) {
        imageView = [[UIImageView alloc] initWithImage:MSHookIvar<UIImageView *>(self, "m_lineView").image];
        [self.m_likeBtn.superview addSubview:imageView];
        objc_setAssociatedObject(self, &m_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return imageView;
}

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig(arg1, arg2);
    
    if ([WeChatConfig shared].timeLineForwardEnable) {
        self.frame = CGRectOffset(CGRectInset(self.frame, self.frame.size.width / -4, 0), self.frame.size.width / -4, 0);
        self.m_shareBtn.frame = CGRectOffset(self.m_likeBtn.frame, self.m_likeBtn.frame.size.width * 2, 0);
        self.m_lineView2.frame = CGRectOffset(MSHookIvar<UIImageView *>(self, "m_lineView").frame, [self buttonWidth:self.m_likeBtn], 0);
    }
}

%new
- (void)forwordTimeLine:(id)arg1 {
    // 转发朋友圈逻辑
    Class forwardClass = objc_getClass("WCForwardViewController");
    if (forwardClass) {
        id forwardVC = [[forwardClass alloc] initWithDataItem:self.m_item];
        UIViewController *navController = (UIViewController *)self;
        while (navController && ![navController isKindOfClass:[UINavigationController class]]) {
            navController = navController.parentViewController;
        }
        if (navController) {
            [navController pushViewController:forwardVC animated:YES];
        }
    }
}

%end

#pragma mark - 集赞助手功能

%hook WCTimelineMgr

- (void)modifyDataItem:(WCDataItem *)arg1 notify:(BOOL)arg2 {
    if (![WeChatConfig shared].likeCommentEnable) {
        %orig(arg1, arg2);
        return;
    }
    
    if (arg1.likeFlag) {
        // 自动集赞逻辑
        NSMutableArray *fakeComments = [NSMutableArray array];
        NSMutableArray *fakeLikes = [NSMutableArray array];
        
        // 生成点赞用户
        for (int i = 0; i < [WeChatConfig shared].likeCount.intValue; i++) {
            id fakeUser = [self createFakeUserWithIndex:i];
            if (fakeUser) [fakeLikes addObject:fakeUser];
        }
        
        // 生成评论
        NSArray *commentArray = [[WeChatConfig shared].comments componentsSeparatedByString:@",,"];
        for (int i = 0; i < MIN([WeChatConfig shared].commentCount.intValue, commentArray.count); i++) {
            id fakeComment = [self createFakeComment:commentArray[i % commentArray.count] index:i];
            if (fakeComment) [fakeComments addObject:fakeComment];
        }
        
        arg1.commentUsers = fakeComments;
        arg1.commentCount = (int)fakeComments.count;
        arg1.likeUsers = fakeLikes;
        arg1.likeCount = (int)fakeLikes.count;
    }
    
    %orig(arg1, arg2);
}

%new
- (id)createFakeUserWithIndex:(int)index {
    // 创建虚拟用户
    Class userClass = objc_getClass("WCUserComment");
    if (userClass) {
        id user = [[userClass alloc] init];
        [user setValue:[NSString stringWithFormat:@"用户%d", index] forKey:@"username"];
        [user setValue:[NSString stringWithFormat:@"昵称%d", index] forKey:@"nickname"];
        return user;
    }
    return nil;
}

%new
- (id)createFakeComment:(NSString *)content index:(int)index {
    // 创建虚拟评论
    Class commentClass = objc_getClass("WCComment");
    if (commentClass) {
        id comment = [[commentClass alloc] init];
        [comment setValue:content forKey:@"content"];
        id user = [self createFakeUserWithIndex:index];
        [comment setValue:user forKey:@"user"];
        return comment;
    }
    return nil;
}

%end

#pragma mark - 自动抢红包功能

%hook CMessageMgr

- (void)onNewSyncAddMessage:(CMessageWrap *)wrap {
    %orig(wrap);
    
    if (wrap.m_uiMessageType == 49) { // AppNode消息类型
        // 判断是否为红包消息
        if ([wrap.m_nsContent rangeOfString:@"wxpay://"].location != NSNotFound) {
            [self handleRedEnvelopMessage:wrap];
        }
    }
}

%new
- (void)handleRedEnvelopMessage:(CMessageWrap *)wrap {
    WeChatConfig *config = [WeChatConfig shared];
    
    if (!config.autoRedEnvelop) return;
    
    // 检查群聊过滤
    NSString *fromUser = wrap.m_nsFromUsr;
    if ([fromUser rangeOfString:@"@chatroom"].location != NSNotFound) {
        if ([config.redEnvelopGroupFiter containsObject:fromUser]) {
            return; // 在过滤列表中，不抢
        }
    }
    
    // 检查关键词过滤
    if (config.redEnvelopTextFiter.length > 0) {
        NSString *content = wrap.m_nsContent;
        NSRange range1 = [content rangeOfString:@"receivertitle><![CDATA[" options:NSLiteralSearch];
        NSRange range2 = [content rangeOfString:@"]]></receivertitle>" options:NSLiteralSearch];
        if (range1.location != NSNotFound && range2.location != NSNotFound) {
            NSRange range3 = NSMakeRange(range1.location + range1.length, range2.location - range1.location - range1.length);
            content = [content substringWithRange:range3];
            
            NSArray *keywords = [config.redEnvelopTextFiter componentsSeparatedByString:@","];
            for (NSString *keyword in keywords) {
                if ([content containsString:keyword]) {
                    return; // 包含关键词，不抢
                }
            }
        }
    }
    
    // 检查是否为个人红包
    BOOL isGroup = [fromUser rangeOfString:@"@chatroom"].location != NSNotFound;
    BOOL isPersonal = !isGroup;
    
    if (isPersonal && !config.personalRedEnvelopEnable) {
        return; // 不接收个人红包
    }
    
    // 检查是否抢自己的红包
    BOOL isFromSelf = NO; // 需要获取当前用户信息判断
    if (isFromSelf && !config.redEnvelopCatchMe) {
        return; // 不抢自己的红包
    }
    
    // 解析红包信息
    NSString *nativeUrl = [[wrap.m_oWCPayInfoItem valueForKey:@"m_c2cNativeUrl"] description];
    if (!nativeUrl) return;
    
    // 提取红包参数
    NSDictionary *params = [self parseRedEnvelopParams:nativeUrl];
    if (!params) return;
    
    // 延迟抢红包
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(config.redEnvelopDelay / 1000.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self openRedEnvelopWithParams:params session:isGroup ? fromUser : nil];
    });
}

%new
- (NSDictionary *)parseRedEnvelopParams:(NSString *)nativeUrl {
    if (![nativeUrl hasPrefix:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"]) {
        return nil;
    }
    
    NSString *paramsString = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    
    NSArray *components = [paramsString componentsSeparatedByString:@"&"];
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
    
    return params;
}

%new
- (void)openRedEnvelopWithParams:(NSDictionary *)params session:(NSString *)session {
    // 调用微信打开红包的接口
    Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
    if (!logicMgrClass) return;
    
    id logicMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:logicMgrClass];
    if (!logicMgr) return;
    
    NSMutableDictionary *requestParams = [NSMutableDictionary dictionary];
    requestParams[@"agreeDuty"] = @"0";
    requestParams[@"channelId"] = params[@"channelid"] ?: @"";
    requestParams[@"inWay"] = @"0";
    requestParams[@"msgType"] = params[@"msgtype"] ?: @"";
    requestParams[@"sendId"] = params[@"sendid"] ?: @"";
    
    if (session) {
        requestParams[@"sessionUserName"] = session;
    }
    
    // 调用打开红包的方法
    SEL selector = NSSelectorFromString(@"ReceiverQueryRedEnvelopesRequest:");
    if ([logicMgr respondsToSelector:selector]) {
        [logicMgr performSelector:selector withObject:requestParams];
    }
}

%end

#pragma mark - 防止同时抢多个红包

%hook WCRedEnvelopesLogicMgr

%new
- (BOOL)isOpeningRedEnvelop {
    static BOOL isOpening = NO;
    return isOpening;
}

%new
- (void)setOpeningRedEnvelop:(BOOL)opening {
    static BOOL isOpening = NO;
    isOpening = opening;
}

- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    WeChatConfig *config = [WeChatConfig shared];
    
    if (config.redEnvelopMultipleCatch && [self isOpeningRedEnvelop]) {
        // 正在抢红包中，延迟处理
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setOpeningRedEnvelop:NO];
            %orig(arg1, arg2);
        });
    } else {
        [self setOpeningRedEnvelop:YES];
        %orig(arg1, arg2);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setOpeningRedEnvelop:NO];
        });
    }
}

%end

#pragma mark - 设置界面

%hook NewSettingViewController

- (void)reloadTableData {
    %orig;
    
    // 添加"微信小助手"设置项
    WCTableViewManager *tableViewMgr = MSHookIvar<id>(self, "m_tableViewMgr");
    if (tableViewMgr) {
        Class cellManagerClass = objc_getClass("WCTableViewNormalCellManager");
        if (cellManagerClass) {
            id newCell = [cellManagerClass normalCellForSel:@selector(showHelperSettings) target:self title:@"微信小助手"];
            if (newCell) {
                WCTableViewSectionManager *firstSection = [tableViewMgr.sections firstObject];
                if (firstSection) {
                    [firstSection addCell:newCell];
                    MMTableView *tableView = [tableViewMgr getTableView];
                    [tableView reloadData];
                }
            }
        }
    }
}

%new
- (void)showHelperSettings {
    // 创建并显示设置界面
    UIViewController *settingsVC = [self createHelperSettingsController];
    if (settingsVC) {
        [self.navigationController pushViewController:settingsVC animated:YES];
    }
}

%new
- (UIViewController *)createHelperSettingsController {
    Class tableViewControllerClass = objc_getClass("MMTableViewController");
    if (!tableViewControllerClass) return nil;
    
    UIViewController *vc = [[tableViewControllerClass alloc] init];
    vc.title = @"微信小助手设置";
    
    // 创建表格
    CGRect tableFrame = CGRectMake(0, 0, vc.view.frame.size.width, vc.view.frame.size.height);
    UITableView *tableView = [[UITableView alloc] initWithFrame:tableFrame style:UITableViewStyleGrouped];
    tableView.dataSource = vc;
    tableView.delegate = vc;
    [vc.view addSubview:tableView];
    
    // 保存tableView引用
    objc_setAssociatedObject(vc, @"helperTableView", tableView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    return vc;
}

%end

#pragma mark - 初始化

static void __attribute__((constructor)) initialize(void) {
    NSLog(@"微信小助手已加载");
    
    // 检查配置
    WeChatConfig *config = [WeChatConfig shared];
    NSLog(@"自动抢红包: %@", config.autoRedEnvelop ? @"开启" : @"关闭");
    NSLog(@"朋友圈转发: %@", config.timeLineForwardEnable ? @"开启" : @"关闭");
    NSLog(@"集赞助手: %@", config.likeCommentEnable ? @"开启" : @"关闭");
}