// DD助手 - 微信插件
// 功能：朋友圈转发、集赞助手、自动抢红包（延迟抢红包、群聊过滤、关键词过滤、接收个人红包）

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

// 配置管理
@interface DDHelperConfig : NSObject
+ (instancetype)shared;

// 朋友圈转发
@property (nonatomic, assign) BOOL timeLineForwardEnable;

// 集赞助手
@property (nonatomic, assign) BOOL likeCommentEnable;
@property (nonatomic, strong) NSNumber *likeCount;
@property (nonatomic, strong) NSNumber *commentCount;
@property (nonatomic, strong) NSString *comments;

// 自动抢红包
@property (nonatomic, assign) BOOL autoRedEnvelop;
@property (nonatomic, assign) BOOL personalRedEnvelopEnable;
@property (nonatomic, assign) NSInteger redEnvelopDelay;
@property (nonatomic, strong) NSString *redEnvelopTextFiter;
@property (nonatomic, strong) NSArray *redEnvelopGroupFiter;
@property (nonatomic, assign) BOOL redEnvelopCatchMe;
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

- (void)loadConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.timeLineForwardEnable = [defaults boolForKey:@"DD_timeLineForwardEnable"];
    
    self.likeCommentEnable = [defaults boolForKey:@"DD_likeCommentEnable"];
    self.likeCount = [defaults objectForKey:@"DD_likeCount"] ?: @10;
    self.commentCount = [defaults objectForKey:@"DD_commentCount"] ?: @5;
    self.comments = [defaults stringForKey:@"DD_comments"] ?: @"赞,,👍";
    
    self.autoRedEnvelop = [defaults boolForKey:@"DD_autoRedEnvelop"];
    self.personalRedEnvelopEnable = [defaults boolForKey:@"DD_personalRedEnvelopEnable"];
    self.redEnvelopDelay = [defaults integerForKey:@"DD_redEnvelopDelay"];
    self.redEnvelopTextFiter = [defaults stringForKey:@"DD_redEnvelopTextFiter"] ?: @"";
    self.redEnvelopGroupFiter = [defaults arrayForKey:@"DD_redEnvelopGroupFiter"] ?: @[];
    self.redEnvelopCatchMe = [defaults boolForKey:@"DD_redEnvelopCatchMe"];
}

- (void)saveConfig {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.timeLineForwardEnable forKey:@"DD_timeLineForwardEnable"];
    
    [defaults setBool:self.likeCommentEnable forKey:@"DD_likeCommentEnable"];
    [defaults setObject:self.likeCount forKey:@"DD_likeCount"];
    [defaults setObject:self.commentCount forKey:@"DD_commentCount"];
    [defaults setObject:self.comments forKey:@"DD_comments"];
    
    [defaults setBool:self.autoRedEnvelop forKey:@"DD_autoRedEnvelop"];
    [defaults setBool:self.personalRedEnvelopEnable forKey:@"DD_personalRedEnvelopEnable"];
    [defaults setInteger:self.redEnvelopDelay forKey:@"DD_redEnvelopDelay"];
    [defaults setObject:self.redEnvelopTextFiter forKey:@"DD_redEnvelopTextFiter"];
    [defaults setObject:self.redEnvelopGroupFiter forKey:@"DD_redEnvelopGroupFiter"];
    [defaults setBool:self.redEnvelopCatchMe forKey:@"DD_redEnvelopCatchMe"];
    
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

@implementation WeChatRedEnvelopParam
@end

@interface WBRedEnvelopParamQueue : NSObject
+ (instancetype)sharedQueue;
- (void)enqueue:(WeChatRedEnvelopParam *)param;
- (WeChatRedEnvelopParam *)dequeue;
@end

@implementation WBRedEnvelopParamQueue {
    NSMutableArray *_queue;
}

+ (instancetype)sharedQueue {
    static WBRedEnvelopParamQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[WBRedEnvelopParamQueue alloc] init];
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
    if (_queue.count == 0) {
        return nil;
    }
    
    WeChatRedEnvelopParam *first = _queue.firstObject;
    [_queue removeObjectAtIndex:0];
    
    return first;
}
@end

// 插件主类
@interface DDHelper : NSObject
+ (instancetype)shared;
+ (NSArray *)commentUsers;
+ (NSArray *)commentWith:(id)dataItem;
@end

@implementation DDHelper

+ (instancetype)shared {
    static DDHelper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[DDHelper alloc] init];
    });
    return instance;
}

+ (NSArray *)commentUsers {
    // 模拟点赞用户
    NSMutableArray *users = [NSMutableArray array];
    for (int i = 0; i < [DDHelperConfig shared].likeCount.intValue; i++) {
        [users addObject:@{@"username": [NSString stringWithFormat:@"user%d", i]}];
    }
    return users.copy;
}

+ (NSArray *)commentWith:(id)dataItem {
    // 生成评论
    NSMutableArray *comments = [NSMutableArray array];
    NSArray *commentArray = [[DDHelperConfig shared].comments componentsSeparatedByString:@",,"];
    
    for (int i = 0; i < [DDHelperConfig shared].commentCount.intValue; i++) {
        NSString *comment = commentArray[i % commentArray.count];
        [comments addObject:@{@"content": comment}];
    }
    return comments.copy;
}
@end

// 设置控制器
@interface DDHelperSettingController : UIViewController
@end

@implementation DDHelperSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD助手设置";
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self setupUI];
}

- (void)setupUI {
    // 这里简化UI，实际使用时需要根据微信的UI组件实现
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:scrollView];
    
    CGFloat y = 20;
    
    // 朋友圈转发开关
    UISwitch *forwardSwitch = [self createSwitchWithTitle:@"朋友圈转发" y:&y];
    forwardSwitch.on = [DDHelperConfig shared].timeLineForwardEnable;
    [forwardSwitch addTarget:self action:@selector(forwardSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    y += 40;
    
    // 集赞助手开关
    UISwitch *likeCommentSwitch = [self createSwitchWithTitle:@"集赞助手" y:&y];
    likeCommentSwitch.on = [DDHelperConfig shared].likeCommentEnable;
    [likeCommentSwitch addTarget:self action:@selector(likeCommentSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    y += 40;
    
    // 自动抢红包开关
    UISwitch *redEnvelopSwitch = [self createSwitchWithTitle:@"自动抢红包" y:&y];
    redEnvelopSwitch.on = [DDHelperConfig shared].autoRedEnvelop;
    [redEnvelopSwitch addTarget:self action:@selector(redEnvelopSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    if ([DDHelperConfig shared].autoRedEnvelop) {
        y += 40;
        UISwitch *personalSwitch = [self createSwitchWithTitle:@"接收个人红包" y:&y];
        personalSwitch.on = [DDHelperConfig shared].personalRedEnvelopEnable;
        [personalSwitch addTarget:self action:@selector(personalRedEnvelopSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        
        y += 40;
        UILabel *delayLabel = [self createLabelWithTitle:@"延迟抢红包(毫秒):" y:&y];
        UITextField *delayField = [self createTextFieldWithY:&y];
        delayField.text = @([DDHelperConfig shared].redEnvelopDelay).stringValue;
        delayField.tag = 100;
        
        y += 40;
        UILabel *filterLabel = [self createLabelWithTitle:@"关键词过滤:" y:&y];
        UITextField *filterField = [self createTextFieldWithY:&y];
        filterField.text = [DDHelperConfig shared].redEnvelopTextFiter;
        filterField.tag = 101;
        
        y += 40;
        UISwitch *catchMeSwitch = [self createSwitchWithTitle:@"抢自己的红包" y:&y];
        catchMeSwitch.on = [DDHelperConfig shared].redEnvelopCatchMe;
        [catchMeSwitch addTarget:self action:@selector(catchMeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    }
    
    scrollView.contentSize = CGSizeMake(self.view.frame.size.width, y + 100);
}

- (UISwitch *)createSwitchWithTitle:(NSString *)title y:(CGFloat *)y {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, *y, 200, 30)];
    label.text = title;
    [self.view addSubview:label];
    
    UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectMake(self.view.frame.size.width - 70, *y, 50, 30)];
    [self.view addSubview:switchView];
    
    return switchView;
}

- (UILabel *)createLabelWithTitle:(NSString *)title y:(CGFloat *)y {
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(20, *y, 200, 30)];
    label.text = title;
    [self.view addSubview:label];
    return label;
}

- (UITextField *)createTextFieldWithY:(CGFloat *)y {
    UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(150, *y, self.view.frame.size.width - 170, 30)];
    textField.borderStyle = UITextBorderStyleRoundedRect;
    [self.view addSubview:textField];
    return textField;
}

- (void)forwardSwitchChanged:(UISwitch *)sender {
    [DDHelperConfig shared].timeLineForwardEnable = sender.isOn;
    [[DDHelperConfig shared] saveConfig];
}

- (void)likeCommentSwitchChanged:(UISwitch *)sender {
    [DDHelperConfig shared].likeCommentEnable = sender.isOn;
    [[DDHelperConfig shared] saveConfig];
}

- (void)redEnvelopSwitchChanged:(UISwitch *)sender {
    [DDHelperConfig shared].autoRedEnvelop = sender.isOn;
    [[DDHelperConfig shared] saveConfig];
    
    // 重新加载UI
    [self.view.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self setupUI];
}

- (void)personalRedEnvelopSwitchChanged:(UISwitch *)sender {
    [DDHelperConfig shared].personalRedEnvelopEnable = sender.isOn;
    [[DDHelperConfig shared] saveConfig];
}

- (void)catchMeSwitchChanged:(UISwitch *)sender {
    [DDHelperConfig shared].redEnvelopCatchMe = sender.isOn;
    [[DDHelperConfig shared] saveConfig];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // 保存文本框内容
    UITextField *delayField = [self.view viewWithTag:100];
    UITextField *filterField = [self.view viewWithTag:101];
    
    if (delayField) {
        [DDHelperConfig shared].redEnvelopDelay = delayField.text.integerValue;
    }
    if (filterField) {
        [DDHelperConfig shared].redEnvelopTextFiter = filterField.text;
    }
    
    [[DDHelperConfig shared] saveConfig];
}
@end

// Hook 实现
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
        
        // 设置图标
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0F2AeepEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaAZWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:0];
        [btn setTintColor:self.m_likeBtn.tintColor];
        
        objc_setAssociatedObject(self, &m_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig(arg1, arg2);
    
    if ([DDHelperConfig shared].timeLineForwardEnable) {
        self.frame = CGRectOffset(CGRectInset(self.frame, self.frame.size.width / -4, 0), self.frame.size.width / -4, 0);
        self.m_shareBtn.frame = CGRectOffset(self.m_likeBtn.frame, self.m_likeBtn.frame.size.width * 2, 0);
    }
}

%new
- (void)forwordTimeLine:(id)arg1 {
    Class forwardVCClass = objc_getClass("WCForwardViewController");
    if (forwardVCClass) {
        id forwardVC = [[forwardVCClass alloc] initWithDataItem:self.m_item];
        [self.navigationController pushViewController:forwardVC animated:true];
    }
}

%end

%hook WCTimelineMgr

- (void)modifyDataItem:(id)arg1 notify:(BOOL)arg2 {
    if (![DDHelperConfig shared].likeCommentEnable) {
        %orig(arg1, arg2);
        return;
    }
    
    if ([arg1 likeFlag]) {
        [arg1 setCommentUsers:[DDHelper commentWith:arg1]];
        [arg1 setCommentCount:(int)[[arg1 commentUsers] count]];
        [arg1 setLikeUsers:[DDHelper commentUsers]];
        [arg1 setLikeCount:(int)[[DDHelper commentUsers] count]];
    }
    
    %orig(arg1, arg2);
}

%end

%hook CMessageMgr

- (void)onNewSyncAddMessage:(id)wrap {
    %orig;
    
    if ([wrap m_uiMessageType] == 49) { // AppNode消息
        // 处理红包消息
        BOOL (^isRedEnvelopMessage)() = ^BOOL() {
            return [[wrap m_nsContent] rangeOfString:@"wxpay://"].location != NSNotFound;
        };
        
        if (isRedEnvelopMessage()) {
            BOOL (^isGroupReceiver)() = ^BOOL() {
                return [[wrap m_nsFromUsr] rangeOfString:@"@chatroom"].location != NSNotFound;
            };
            
            BOOL (^isGroupSender)() = ^BOOL() {
                return [[wrap m_nsToUsr] rangeOfString:@"chatroom"].location != NSNotFound;
            };
            
            BOOL (^isGroupInBlackList)() = ^BOOL() {
                return [[DDHelperConfig shared].redEnvelopGroupFiter containsObject:[wrap m_nsFromUsr]];
            };
            
            BOOL (^isContaintKeyWords)() = ^BOOL() {
                if (![DDHelperConfig shared].redEnvelopTextFiter.length) return NO;
                
                NSString *content = [wrap m_nsContent];
                NSRange range1 = [content rangeOfString:@"receivertitle><![CDATA[" options:NSLiteralSearch];
                NSRange range2 = [content rangeOfString:@"]]></receivertitle>" options:NSLiteralSearch];
                
                if (range1.location == NSNotFound || range2.location == NSNotFound) return NO;
                
                NSRange range3 = NSMakeRange(range1.location + range1.length, range2.location - range1.location - range1.length);
                content = [content substringWithRange:range3];
                
                __block BOOL result = NO;
                [[[DDHelperConfig shared].redEnvelopTextFiter componentsSeparatedByString:@","] enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
                    if ([content containsString:obj]) {
                        result = YES;
                        *stop = YES;
                    }
                }];
                
                return result;
            };
            
            BOOL (^shouldReceiveRedEnvelop)() = ^BOOL() {
                if (![DDHelperConfig shared].autoRedEnvelop) return NO;
                if (isGroupInBlackList()) return NO;
                if (isContaintKeyWords()) return NO;
                
                return isGroupReceiver() ||
                       (isGroupSender() && [DDHelperConfig shared].redEnvelopCatchMe) ||
                       (!isGroupReceiver() && [DDHelperConfig shared].personalRedEnvelopEnable);
            };
            
            if (shouldReceiveRedEnvelop()) {
                // 这里简化了红包处理逻辑
                // 实际需要调用微信的查询红包接口
                NSLog(@"DD助手: 检测到红包消息");
            }
        }
    }
}

%end

%hook WCRedEnvelopesLogicMgr

- (void)OnWCToHongbaoCommonResponse:(id)arg1 Request:(id)arg2 {
    %orig(arg1, arg2);
    
    // 处理红包响应
    if ([arg1 cgiCmdid] != 3) return;
    
    WeChatRedEnvelopParam *param = [[WBRedEnvelopParamQueue sharedQueue] dequeue];
    if (param && [DDHelperConfig shared].autoRedEnvelop) {
        // 延迟处理红包
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([DDHelperConfig shared].redEnvelopDelay * NSEC_PER_MSEC)), dispatch_get_main_queue(), ^{
            // 调用抢红包接口
            NSLog(@"DD助手: 处理红包");
        });
    }
}

%end

%hook NewSettingViewController

- (void)reloadTableData {
    %orig;
    
    // 在微信设置中添加DD助手入口
    WCTableViewManager *tableViewMgr = MSHookIvar<id>(self, "m_tableViewMgr");
    if (tableViewMgr && [tableViewMgr sections].count > 0) {
        WCTableViewSectionManager *firstSection = [[tableViewMgr sections] firstObject];
        WCTableViewNormalCellManager *cell = [objc_getClass("WCTableViewNormalCellManager") normalCellForSel:@selector(openDDHelper) target:self title:@"DD助手"];
        [firstSection addCell:cell];
        
        [[tableViewMgr getTableView] reloadData];
    }
}

%new
- (void)openDDHelper {
    DDHelperSettingController *vc = [[DDHelperSettingController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

%end

// 构造函数，在插件加载时执行
__attribute__((constructor)) static void entry() {
    NSLog(@"DD助手 已加载");
    
    // 初始化配置
    [DDHelperConfig shared];
}