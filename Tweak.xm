// WeChatHelper.xm
// 微信小助手插件 - 核心功能版

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

#pragma mark - 微信内部类声明

@class CMessageWrap;
@class CContact;
@class WCPayInfoItem;
@class WCDataItem;
@class WCOperateFloatView;
@class WCTimelineMgr;
@class WCRedEnvelopesLogicMgr;
@class CMessageMgr;
@class NewSettingViewController;
@class MMServiceCenter;

#pragma mark - 配置类

@interface WeChatConfig : NSObject
+ (instancetype)shared;

// 抢红包配置
@property (nonatomic, assign) BOOL autoRedEnvelop;
@property (nonatomic, assign) NSInteger redEnvelopDelay;
@property (nonatomic, strong) NSArray *redEnvelopGroupFiter;
@property (nonatomic, strong) NSString *redEnvelopTextFiter;
@property (nonatomic, assign) BOOL personalRedEnvelopEnable;
@property (nonatomic, assign) BOOL redEnvelopCatchMe;
@property (nonatomic, assign) BOOL redEnvelopMultipleCatch;

// 朋友圈配置
@property (nonatomic, assign) BOOL timeLineForwardEnable;
@property (nonatomic, assign) BOOL likeCommentEnable;
@property (nonatomic, strong) NSNumber *likeCount;
@property (nonatomic, strong) NSNumber *commentCount;
@property (nonatomic, strong) NSString *comments;
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
- (UIButton *)shareButton {
    static char shareButtonKey;
    UIButton *btn = objc_getAssociatedObject(self, &shareButtonKey);
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@"转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(forwardTimeLineAction) forControlEvents:UIControlEventTouchUpInside];
        
        // 设置样式
        if ([self respondsToSelector:@selector(m_likeBtn)]) {
            id likeBtn = [self valueForKey:@"m_likeBtn"];
            if (likeBtn) {
                [btn setTitleColor:[likeBtn titleColorForState:0] forState:0];
                btn.titleLabel.font = [likeBtn titleLabel].font;
            }
        }
        
        [self addSubview:btn];
        
        objc_setAssociatedObject(self, &shareButtonKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

%new
- (UIImageView *)lineView2 {
    static char lineView2Key;
    UIImageView *imageView = objc_getAssociatedObject(self, &lineView2Key);
    if (!imageView) {
        // 尝试获取原始的线视图
        id originalLineView = [self valueForKey:@"m_lineView"];
        if (originalLineView && [originalLineView isKindOfClass:[UIImageView class]]) {
            imageView = [[UIImageView alloc] initWithImage:[originalLineView image]];
        } else {
            imageView = [[UIImageView alloc] init];
            imageView.backgroundColor = [UIColor lightGrayColor];
        }
        [self addSubview:imageView];
        objc_setAssociatedObject(self, &lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return imageView;
}

- (void)layoutSubviews {
    %orig;
    
    if ([WeChatConfig shared].timeLineForwardEnable) {
        UIButton *shareBtn = [self shareButton];
        UIImageView *lineView2 = [self lineView2];
        
        // 获取点赞按钮位置
        id likeBtn = [self valueForKey:@"m_likeBtn"];
        if (likeBtn && [likeBtn isKindOfClass:[UIView class]]) {
            UIView *likeButton = (UIView *)likeBtn;
            CGRect likeFrame = likeButton.frame;
            
            // 设置分享按钮位置（在点赞按钮右边）
            shareBtn.frame = CGRectMake(CGRectGetMaxX(likeFrame) + 10, likeFrame.origin.y, 
                                       likeFrame.size.width, likeFrame.size.height);
            
            // 设置分割线位置
            id originalLineView = [self valueForKey:@"m_lineView"];
            if (originalLineView && [originalLineView isKindOfClass:[UIView class]]) {
                UIView *originalLine = (UIView *)originalLineView;
                lineView2.frame = CGRectMake(CGRectGetMaxX(likeFrame) + likeFrame.size.width/2, 
                                            originalLine.frame.origin.y,
                                            originalLine.frame.size.width,
                                            originalLine.frame.size.height);
            }
        }
    }
}

%new
- (void)forwardTimeLineAction {
    // 尝试获取当前的数据项
    id dataItem = [self valueForKey:@"m_item"];
    if (!dataItem) return;
    
    // 查找导航控制器
    UIViewController *viewController = (UIViewController *)self;
    while (viewController && ![viewController isKindOfClass:[UINavigationController class]]) {
        viewController = viewController.parentViewController;
        if (!viewController) {
            viewController = [self valueForKey:@"_viewController"];
        }
    }
    
    if (viewController && [viewController isKindOfClass:[UINavigationController class]]) {
        // 尝试转发操作
        Class forwardClass = objc_getClass("WCForwardViewController");
        if (forwardClass) {
            // 使用运行时创建实例
            id forwardVC = [[forwardClass alloc] init];
            if ([forwardVC respondsToSelector:@selector(setDataItem:)]) {
                [forwardVC setValue:dataItem forKey:@"dataItem"];
                [viewController pushViewController:forwardVC animated:YES];
            }
        }
    }
}

%end

#pragma mark - 集赞助手功能

%hook WCTimelineMgr

%new
- (id)createFakeUserWithIndex:(int)index {
    // 尝试创建虚拟用户
    Class userClass = objc_getClass("WCUserComment");
    if (userClass) {
        id user = [[userClass alloc] init];
        [user setValue:[NSString stringWithFormat:@"fakeuser%d", index] forKey:@"username"];
        [user setValue:[NSString stringWithFormat:@"用户%d", index] forKey:@"nickname"];
        return user;
    }
    return nil;
}

%new
- (id)createFakeComment:(NSString *)content index:(int)index {
    // 尝试创建虚拟评论
    Class commentClass = objc_getClass("WCComment");
    if (commentClass) {
        id comment = [[commentClass alloc] init];
        [comment setValue:content forKey:@"content"];
        id user = [self createFakeUserWithIndex:index];
        if (user) {
            [comment setValue:user forKey:@"user"];
        }
        return comment;
    }
    return nil;
}

- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2 {
    if (![WeChatConfig shared].likeCommentEnable) {
        %orig(arg1, arg2);
        return;
    }
    
    // 检查是否有点赞标志
    NSNumber *likeFlag = [arg1 valueForKey:@"likeFlag"];
    if (likeFlag && [likeFlag boolValue]) {
        // 生成虚拟数据
        NSMutableArray *fakeComments = [NSMutableArray array];
        NSMutableArray *fakeLikes = [NSMutableArray array];
        
        WeChatConfig *config = [WeChatConfig shared];
        
        // 生成点赞用户
        for (int i = 0; i < [config.likeCount intValue]; i++) {
            id fakeUser = [self createFakeUserWithIndex:i];
            if (fakeUser) [fakeLikes addObject:fakeUser];
        }
        
        // 生成评论
        NSArray *commentArray = [config.comments componentsSeparatedByString:@",,"];
        for (int i = 0; i < MIN([config.commentCount intValue], commentArray.count); i++) {
            id fakeComment = [self createFakeComment:commentArray[i % commentArray.count] index:i];
            if (fakeComment) [fakeComments addObject:fakeComment];
        }
        
        // 设置数据
        [arg1 setValue:fakeComments forKey:@"commentUsers"];
        [arg1 setValue:@(fakeComments.count) forKey:@"commentCount"];
        [arg1 setValue:fakeLikes forKey:@"likeUsers"];
        [arg1 setValue:@(fakeLikes.count) forKey:@"likeCount"];
    }
    
    %orig(arg1, arg2);
}

%end

#pragma mark - 自动抢红包功能

%hook CMessageMgr

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
    
    // 获取服务中心
    Class mmServiceCenter = objc_getClass("MMServiceCenter");
    if (!mmServiceCenter) return;
    
    id serviceCenter = [mmServiceCenter performSelector:@selector(defaultCenter)];
    if (!serviceCenter) return;
    
    id logicMgr = [serviceCenter performSelector:@selector(getService:) withObject:logicMgrClass];
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
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    SEL selector = NSSelectorFromString(@"ReceiverQueryRedEnvelopesRequest:");
    if ([logicMgr respondsToSelector:selector]) {
        [logicMgr performSelector:selector withObject:requestParams];
    }
#pragma clang diagnostic pop
}

%new
- (void)handleRedEnvelopMessage:(id)wrap {
    WeChatConfig *config = [WeChatConfig shared];
    
    if (!config.autoRedEnvelop) return;
    
    // 获取消息内容
    NSString *content = [wrap valueForKey:@"m_nsContent"];
    NSString *fromUser = [wrap valueForKey:@"m_nsFromUsr"];
    
    if (!content || !fromUser) return;
    
    // 检查是否为红包消息
    if ([content rangeOfString:@"wxpay://"].location == NSNotFound) {
        return;
    }
    
    // 检查群聊过滤
    if ([fromUser rangeOfString:@"@chatroom"].location != NSNotFound) {
        if ([config.redEnvelopGroupFiter containsObject:fromUser]) {
            return; // 在过滤列表中，不抢
        }
    }
    
    // 检查关键词过滤
    if (config.redEnvelopTextFiter.length > 0) {
        NSRange range1 = [content rangeOfString:@"receivertitle><![CDATA["];
        NSRange range2 = [content rangeOfString:@"]]></receivertitle>"];
        if (range1.location != NSNotFound && range2.location != NSNotFound) {
            NSRange range3 = NSMakeRange(range1.location + range1.length, 
                                        range2.location - range1.location - range1.length);
            NSString *title = [content substringWithRange:range3];
            
            NSArray *keywords = [config.redEnvelopTextFiter componentsSeparatedByString:@","];
            for (NSString *keyword in keywords) {
                if ([title containsString:keyword]) {
                    return; // 包含关键词，不抢
                }
            }
        }
    }
    
    // 检查是否为个人红包
    BOOL isGroup = [fromUser rangeOfString:@"@chatroom"].location != NSNotFound;
    if (!isGroup && !config.personalRedEnvelopEnable) {
        return; // 不接收个人红包
    }
    
    // 解析红包信息
    id payInfo = [wrap valueForKey:@"m_oWCPayInfoItem"];
    NSString *nativeUrl = [payInfo valueForKey:@"m_c2cNativeUrl"];
    if (!nativeUrl) return;
    
    NSDictionary *params = [self parseRedEnvelopParams:nativeUrl];
    if (!params) return;
    
    // 延迟抢红包
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, 
                                            (int64_t)(config.redEnvelopDelay / 1000.0 * NSEC_PER_SEC));
    dispatch_after(delayTime, dispatch_get_main_queue(), ^{
        [self openRedEnvelopWithParams:params session:isGroup ? fromUser : nil];
    });
}

- (void)onNewSyncAddMessage:(id)wrap {
    %orig;
    
    // 获取消息类型
    NSNumber *msgType = [wrap valueForKey:@"m_uiMessageType"];
    if (!msgType) return;
    
    if ([msgType intValue] == 49) { // AppNode消息类型
        [self handleRedEnvelopMessage:wrap];
    }
}

%end

#pragma mark - 防止同时抢多个红包

%hook WCRedEnvelopesLogicMgr

static BOOL isOpeningRedEnvelop = NO;

%new
- (BOOL)isOpeningRedEnvelop {
    return isOpeningRedEnvelop;
}

%new
- (void)setOpeningRedEnvelop:(BOOL)opening {
    isOpeningRedEnvelop = opening;
}

- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    WeChatConfig *config = [WeChatConfig shared];
    
    if (config.redEnvelopMultipleCatch && isOpeningRedEnvelop) {
        // 正在抢红包中，延迟处理
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            isOpeningRedEnvelop = NO;
            %orig(arg1, arg2);
        });
        return;
    }
    
    isOpeningRedEnvelop = YES;
    %orig(arg1, arg2);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        isOpeningRedEnvelop = NO;
    });
}

%end

#pragma mark - 设置界面

%hook NewSettingViewController

%new
- (void)showHelperSettings {
    // 创建简单的设置界面
    UIViewController *settingsVC = [[UIViewController alloc] init];
    settingsVC.title = @"微信小助手设置";
    settingsVC.view.backgroundColor = [UIColor whiteColor];
    
    // 创建表格视图
    UITableView *tableView = [[UITableView alloc] initWithFrame:settingsVC.view.bounds style:UITableViewStyleGrouped];
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    tableView.dataSource = (id<UITableViewDataSource>)settingsVC;
    tableView.delegate = (id<UITableViewDelegate>)settingsVC;
    
    // 存储配置引用
    objc_setAssociatedObject(settingsVC, "tableView", tableView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(settingsVC, "config", [WeChatConfig shared], OBJC_ASSOCIATION_ASSIGN);
    
    [settingsVC.view addSubview:tableView];
    
    // 推送到导航控制器
    UIViewController *navController = (UIViewController *)self;
    while (navController && ![navController isKindOfClass:[UINavigationController class]]) {
        navController = navController.parentViewController;
    }
    
    if (navController && [navController isKindOfClass:[UINavigationController class]]) {
        [navController pushViewController:settingsVC animated:YES];
    }
}

- (void)reloadTableData {
    %orig;
    
    // 尝试获取表格管理器
    id tableViewMgr = [self valueForKey:@"m_tableViewMgr"];
    if (tableViewMgr) {
        // 获取第一个section
        id sections = [tableViewMgr valueForKey:@"sections"];
        if (sections && [sections isKindOfClass:[NSArray class]] && [sections count] > 0) {
            id firstSection = sections[0];
            
            // 创建小助手设置项
            Class cellManagerClass = objc_getClass("WCTableViewNormalCellManager");
            if (cellManagerClass) {
                id newCell = [cellManagerClass performSelector:@selector(normalCellForSel:target:title:)
                                                    withObject:@selector(showHelperSettings)
                                                    withObject:self
                                                    withObject:@"微信小助手"];
                
                if (newCell && [firstSection respondsToSelector:@selector(addCell:)]) {
                    [firstSection performSelector:@selector(addCell:) withObject:newCell];
                    
                    // 刷新表格
                    id tableView = [tableViewMgr performSelector:@selector(getTableView)];
                    if (tableView && [tableView respondsToSelector:@selector(reloadData)]) {
                        [tableView performSelector:@selector(reloadData)];
                    }
                }
            }
        }
    }
}

%end

#pragma mark - 设置界面扩展

@interface UIViewController (WeChatHelperSettings) <UITableViewDataSource, UITableViewDelegate>
@end

@implementation UIViewController (WeChatHelperSettings)

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3; // 朋友圈、抢红包、其他
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 3; // 朋友圈转发、集赞助手、点赞数、评论数
        case 1: return 6; // 自动抢红包、延迟、过滤等
        case 2: return 1; // 关于
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"朋友圈功能";
        case 1: return @"抢红包功能";
        case 2: return @"其他";
        default: return @"";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"WeChatHelperCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }
    
    WeChatConfig *config = [WeChatConfig shared];
    
    if (indexPath.section == 0) {
        // 朋友圈功能
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"朋友圈转发";
                cell.accessoryView = [self switchWithTag:100 on:config.timeLineForwardEnable];
                break;
            case 1:
                cell.textLabel.text = @"集赞助手";
                cell.accessoryView = [self switchWithTag:101 on:config.likeCommentEnable];
                break;
            case 2:
                cell.textLabel.text = @"点赞/评论数";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@/%@", config.likeCount, config.commentCount];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
        }
    } else if (indexPath.section == 1) {
        // 抢红包功能
        switch (indexPath.row) {
            case 0:
                cell.textLabel.text = @"自动抢红包";
                cell.accessoryView = [self switchWithTag:200 on:config.autoRedEnvelop];
                break;
            case 1:
                cell.textLabel.text = @"延迟抢红包";
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld毫秒", (long)config.redEnvelopDelay];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            case 2:
                cell.textLabel.text = @"接收个人红包";
                cell.accessoryView = [self switchWithTag:201 on:config.personalRedEnvelopEnable];
                break;
            case 3:
                cell.textLabel.text = @"关键词过滤";
                cell.detailTextLabel.text = config.redEnvelopTextFiter.length > 0 ? @"已设置" : @"未设置";
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            case 4:
                cell.textLabel.text = @"抢自己的红包";
                cell.accessoryView = [self switchWithTag:202 on:config.redEnvelopCatchMe];
                break;
            case 5:
                cell.textLabel.text = @"防止同时抢";
                cell.accessoryView = [self switchWithTag:203 on:config.redEnvelopMultipleCatch];
                break;
        }
    } else if (indexPath.section == 2) {
        // 其他
        cell.textLabel.text = @"关于微信小助手";
        cell.detailTextLabel.text = @"v1.0";
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (UISwitch *)switchWithTag:(NSInteger)tag on:(BOOL)on {
    UISwitch *switchView = [[UISwitch alloc] init];
    switchView.tag = tag;
    switchView.on = on;
    [switchView addTarget:self action:@selector(switchValueChanged:) forControlEvents:UIControlEventValueChanged];
    return switchView;
}

- (void)switchValueChanged:(UISwitch *)sender {
    WeChatConfig *config = [WeChatConfig shared];
    
    switch (sender.tag) {
        case 100: config.timeLineForwardEnable = sender.on; break;
        case 101: config.likeCommentEnable = sender.on; break;
        case 200: config.autoRedEnvelop = sender.on; break;
        case 201: config.personalRedEnvelopEnable = sender.on; break;
        case 202: config.redEnvelopCatchMe = sender.on; break;
        case 203: config.redEnvelopMultipleCatch = sender.on; break;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 0 && indexPath.row == 2) {
        // 设置点赞/评论数
        [self showLikeCommentSettings];
    } else if (indexPath.section == 1 && indexPath.row == 1) {
        // 设置延迟时间
        [self showDelaySettings];
    } else if (indexPath.section == 1 && indexPath.row == 3) {
        // 设置关键词过滤
        [self showKeywordSettings];
    } else if (indexPath.section == 2 && indexPath.row == 0) {
        // 显示关于信息
        [self showAbout];
    }
}

- (void)showLikeCommentSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置集赞参数"
                                                                   message:@"请设置点赞数和评论数"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"点赞数";
        textField.text = [[WeChatConfig shared].likeCount stringValue];
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"评论数";
        textField.text = [[WeChatConfig shared].commentCount stringValue];
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *likeField = alert.textFields[0];
        UITextField *commentField = alert.textFields[1];
        
        [WeChatConfig shared].likeCount = @([likeField.text intValue]);
        [WeChatConfig shared].commentCount = @([commentField.text intValue]);
        
        // 刷新表格
        UITableView *tableView = objc_getAssociatedObject(self, "tableView");
        [tableView reloadData];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showDelaySettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置延迟时间"
                                                                   message:@"单位：毫秒 (1000毫秒 = 1秒)"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"延迟时间";
        textField.text = [NSString stringWithFormat:@"%ld", (long)[WeChatConfig shared].redEnvelopDelay];
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *delayField = alert.textFields[0];
        [WeChatConfig shared].redEnvelopDelay = [delayField.text integerValue];
        
        // 刷新表格
        UITableView *tableView = objc_getAssociatedObject(self, "tableView");
        [tableView reloadData];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showKeywordSettings {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置关键词过滤"
                                                                   message:@"多个关键词用逗号分隔"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"关键词，如：罚款,测试,公司";
        textField.text = [WeChatConfig shared].redEnvelopTextFiter;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UITextField *keywordField = alert.textFields[0];
        [WeChatConfig shared].redEnvelopTextFiter = keywordField.text;
        
        // 刷新表格
        UITableView *tableView = objc_getAssociatedObject(self, "tableView");
        [tableView reloadData];
    }]];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showAbout {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"微信小助手"
                                                                   message:@"版本 1.0\n\n仅供学习交流使用\n请勿用于商业用途"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - 初始化

%ctor {
    @autoreleasepool {
        NSLog(@"微信小助手已加载 - 版本 1.0");
        
        // 初始化配置
        WeChatConfig *config = [WeChatConfig shared];
        NSLog(@"自动抢红包: %@", config.autoRedEnvelop ? @"开启" : @"关闭");
        NSLog(@"朋友圈转发: %@", config.timeLineForwardEnable ? @"开启" : @"关闭");
        NSLog(@"集赞助手: %@", config.likeCommentEnable ? @"开启" : @"关闭");
        
        // 注册hook
        %init;
    }
}