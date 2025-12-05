#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#define PLUGIN_NAME @"DD助手"
#define PLUGIN_VERSION @"1.0.0"

static NSString * const kPreventRevokeEnabledKey = @"com.dd.assistant.prevent.revoke.enabled";
static NSString * const kGameCheatEnabledKey = @"com.dd.assistant.game.cheat.enabled";
static NSString * const kMessageTimeBelowAvatarKey = @"com.dd.assistant.message.time.below.avatar";
static NSString * const kHideChatTimeLabelKey = @"com.dd.assistant.hide.chat.time.label";
static NSString * const kFriendsCountEnabledKey = @"com.dd.assistant.friends.count.enabled";
static NSString * const kFriendsCountValueKey = @"com.dd.assistant.friends.count.value";
static NSString * const kWCFriendsCountReplacementKey = @"com.wechat.tweak.friends_count_replacement";
static NSString * const kWalletBalanceEnabledKey = @"com.dd.assistant.wallet.balance.enabled";
static NSString * const kWalletBalanceValueKey = @"com.dd.assistant.wallet.balance.value";
static NSString * const kWCWalletBalanceReplacementKey = @"com.wechat.tweak.wallet_balance_replacement";

static NSString * const kTouchTrailKey = @"com.wechat.tweak.touch.trail.enabled";
static NSString * const kTouchTrailOnlyWhenRecordingKey = @"com.wechat.tweak.touch.trail.only.when.recording";
static NSString * const kTouchTrailDisplayStateKey = @"com.wechat.tweak.touch.trail.display.state";
static NSString * const kTouchTrailTailEnabledKey = @"com.wechat.tweak.touch.trail.tail.enabled";

static NSMutableDictionary *touchViews = nil;
static NSMutableDictionary *touchTailViews = nil;
static NSMutableDictionary *touchLastPointTimes = nil;
static BOOL isTrailEnabled = NO;

static char kMessageTimeKey;
static char kTimeViewKey;
static NSString * const kWCOriginalContacts = @"通讯录";
static BOOL gFriendsCountEnabled = NO;
static NSString *gFriendsCountReplacement = nil;
static BOOL gWalletBalanceEnabled = NO;
static NSString *gWalletBalanceReplacement = nil;
static BOOL g_hasPluginsMgr = NO;

@interface CContact : NSObject
@property(copy, nonatomic) NSString *m_nsUsrName;
@property(copy, nonatomic) NSString *m_nsNickName;
@property(copy, nonatomic) NSString *m_nsRemark;
@end

@interface CMessageWrap : NSObject
@property(nonatomic) unsigned int m_uiCreateTime;
@property(nonatomic) unsigned int m_uiMessageType;
@property(nonatomic) unsigned int m_uiGameType;
@property(nonatomic) unsigned int m_uiGameContent;
@property(copy, nonatomic) NSString *m_nsEmoticonMD5;
@property(copy, nonatomic) NSString *m_nsContent;
@property(copy, nonatomic) NSString *m_nsFromUsr;
@property(copy, nonatomic) NSString *m_nsToUsr;
@property(nonatomic) unsigned int m_uiStatus;
@property(readonly, nonatomic) BOOL IsImgMsg;
@property(readonly, nonatomic) BOOL IsVideoMsg;
@property(readonly, nonatomic) BOOL IsVoiceMsg;
@property(readonly, nonatomic) BOOL IsTextMsg;
@property(readonly, nonatomic) unsigned int m_uiMesLocalID;
- (instancetype)initWithMsgType:(unsigned int)type;
@end

static NSString* parseParam(NSString *content, NSString *begin, NSString *end) {
    if (!content) return nil;
    
    NSRange beginRange = [content rangeOfString:begin];
    NSRange endRange = [content rangeOfString:end];
    
    if (beginRange.location == NSNotFound || endRange.location == NSNotFound) return nil;
    if (endRange.location <= beginRange.location + begin.length) return nil;
    
    NSRange subRange = NSMakeRange(beginRange.location + begin.length, 
                                  endRange.location - (beginRange.location + begin.length));
    
    if (NSMaxRange(subRange) > content.length) return nil;
    
    return [content substringWithRange:subRange];
}

static NSString* getDisplayName(CContact *contact, BOOL isGroupChat, NSString *revokeContent) {
    if (isGroupChat) {
        NSString *name = parseParam(revokeContent, @"<![CDATA[", @"撤回了一条消息");
        if (name.length > 0) {
            name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            return [NSString stringWithFormat:@"\"%@\"", name];
        }
        return contact.m_nsNickName ? [NSString stringWithFormat:@"\"%@\"", contact.m_nsNickName] : contact.m_nsUsrName;
    } else {
        if (contact.m_nsRemark.length > 0) return [NSString stringWithFormat:@"\"%@\"", contact.m_nsRemark];
        if (contact.m_nsNickName.length > 0) return [NSString stringWithFormat:@"\"%@\"", contact.m_nsNickName];
        return contact.m_nsUsrName ? [NSString stringWithFormat:@"\"%@\"", contact.m_nsUsrName] : @"\"对方\"";
    }
}

static NSString* formatTimeString(unsigned int timestamp) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
    });
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
}

static NSString* getMessageContentAdapter(CMessageWrap *msgWrap) {
    switch (msgWrap.m_uiMessageType) {
        case 1: {
            NSString *content = msgWrap.m_nsContent;
            if (content.length > 30) {
                NSString *truncated = [content substringToIndex:27];
                return [NSString stringWithFormat:@"\"%@...\"", truncated];
            }
            return [NSString stringWithFormat:@"\"%@\"", content];
        }
        case 3:
            return @"\"图片\"";
        case 34:
            return @"\"语音\"";
        case 43:
            return @"\"视频\"";
        case 47:
            return @"\"表情\"";
        case 49:
            return @"\"链接\"";
        case 50:
            return @"\"视频号\"";
        case 62:
            return @"\"直播\"";
        default:
            return [NSString stringWithFormat:@"\"类型%d\"", (int)msgWrap.m_uiMessageType];
    }
}

static NSString* getDoubleLineTimeString(unsigned int timestamp) {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd\nHH:mm:ss"];
    return [formatter stringFromDate:date];
}

static BOOL isPreventRevokeEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kPreventRevokeEnabledKey];
}

static BOOL isGameCheatEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kGameCheatEnabledKey];
}

static BOOL isMessageTimeBelowAvatarEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kMessageTimeBelowAvatarKey];
}

static BOOL isHideChatTimeLabelEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kHideChatTimeLabelKey];
}

static BOOL isFriendsCountEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kFriendsCountEnabledKey];
}

static BOOL isWalletBalanceEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kWalletBalanceEnabledKey];
}

static void setMessageTime(id self, NSString *time) {
    objc_setAssociatedObject(self, &kMessageTimeKey, time, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static NSString *getMessageTime(id self) {
    return objc_getAssociatedObject(self, &kMessageTimeKey);
}

static void setTimeView(id self, UIView *view) {
    objc_setAssociatedObject(self, &kTimeViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIView *getTimeView(id self) {
    return objc_getAssociatedObject(self, &kTimeViewKey);
}

static void loadFriendsAndWalletSettings() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    gFriendsCountEnabled = [defaults boolForKey:kFriendsCountEnabledKey];
    NSString *friendsCountValue = [defaults objectForKey:kFriendsCountValueKey];
    if (friendsCountValue && [friendsCountValue length] > 0) {
        gFriendsCountReplacement = friendsCountValue;
    } else {
        gFriendsCountReplacement = nil;
    }
    gWalletBalanceEnabled = [defaults boolForKey:kWalletBalanceEnabledKey];
    NSString *walletBalanceValue = [defaults objectForKey:kWalletBalanceValueKey];
    if (walletBalanceValue && [walletBalanceValue length] > 0) {
        gWalletBalanceReplacement = walletBalanceValue;
    } else {
        gWalletBalanceReplacement = nil;
    }
}

@interface WCActionSheet : NSObject
- (id)initWithTitle:(NSString *)title cancelButtonTitle:(NSString *)cancelButtonTitle;
- (id)initWithTitle:(NSString *)title;
- (id)init;
- (void)addButtonWithTitle:(NSString *)title eventAction:(void(^)(void))eventAction;
- (void)showInView:(UIView *)view;
@end

@interface WBTouchTrailView : UIView
@property (nonatomic, strong) UIColor *trailColor;
@property (nonatomic, assign) CGFloat trailSize;
@property (nonatomic, assign) BOOL isMoving;
- (void)updateWithPoint:(CGPoint)point;
- (void)updateWithPoint:(CGPoint)point isMoving:(BOOL)isMoving;
@end

@interface WBTouchTrailDotView : UIView
@property (nonatomic, strong) UIColor *dotColor;
@property (nonatomic, assign) CGFloat dotSize;
- (instancetype)initWithPoint:(CGPoint)point 
                     dotColor:(UIColor *)dotColor 
                     dotSize:(CGFloat)dotSize 
                    duration:(CGFloat)duration;
@end

@interface TimeoutNumber : UIView
- (void)updateNumber:(unsigned long long)arg1;
- (void)defaultNumber:(unsigned long long)arg1;
@end

@interface ScrollNumber : UIView
- (void)updateNumber:(unsigned long long)arg1;
- (void)defaultNumber:(unsigned long long)arg1;
@end

@interface WCPayWalletEntryHeaderView : UIView
- (void)setupTimeoutNumber;
- (void)updateBalanceEntryView;
- (void)handleUpdateWalletBalance;
- (void)updateBalanceAndRefreshView;
- (id)valueForKey:(NSString *)key;
@end

@interface MMUILabel : UILabel
@end

@interface MFTitleView : UIView
- (void)updateTitleView:(unsigned int)arg1 title:(NSString *)title;
@end

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface WCTableViewCellManager : NSObject
+ (instancetype)normalCellForSel:(SEL)sel target:(id)target title:(NSString *)title;
+ (instancetype)switchCellForSel:(SEL)sel target:(id)target title:(NSString *)title isOn:(BOOL)isOn;
+ (instancetype)editorCellForSel:(SEL)sel target:(id)target title:(NSString *)title tip:(NSString *)tip focus:(BOOL)focus text:(NSString *)text;
+ (instancetype)normalCellForSel:(SEL)sel target:(id)target title:(NSString *)title rightValue:(NSString *)rightValue accessoryType:(long long)accessoryType;
@end

@interface WCTableViewSectionManager : NSObject
+ (instancetype)sectionInfoHeader:(NSString *)header;
+ (instancetype)sectionInfoDefaut;
- (void)addCell:(WCTableViewCellManager *)cell;
@end

@interface WCTableViewManager : NSObject
- (void)insertSection:(id)section At:(NSInteger)index;
- (id)getTableView;
- (void)reloadData;
@end

@interface MMTableView : UITableView
@end

@interface NewSettingViewController : UIViewController {
    WCTableViewManager *m_tableViewMgr;
}
- (void)reloadTableData;
@end

@interface BaseMsgContentViewController : UIViewController
- (CContact *)GetContact;
@end

@interface CommonMessageViewModel : NSObject
- (BOOL)isSender;
- (BOOL)isShowHeadImage;
@property(retain, nonatomic) id messageWrap;
@end

@interface TextMessageSubViewModel : CommonMessageViewModel
@property(readonly, nonatomic) CommonMessageViewModel *parentModel;
@property(readonly, nonatomic) NSArray *subViewModels;
@end

@interface CMessageMgr : NSObject
- (void)AddEmoticonMsg:(NSString *)msg MsgWrap:(CMessageWrap *)msgWrap;
- (void)AddLocalMsg:(NSString *)session MsgWrap:(CMessageWrap *)wrap fixTime:(BOOL)fix NewMsgArriveNotify:(BOOL)notify;
- (CMessageWrap *)GetMsg:(NSString *)session n64SvrID:(long long)svrID;
@end

@interface CContactMgr : NSObject
- (id)getContactByName:(NSString *)name;
@end

@interface CommonMessageCellView : UIView
@property(readonly, nonatomic) CommonMessageViewModel *viewModel;
@property(nonatomic, readonly) UIView *m_contentView;
- (UIView *)getBgImageView;
- (void)updateNodeStatus;
@end

@interface VoiceMessageCellView : CommonMessageCellView
@property(nonatomic, readonly) UILabel *m_secLabel;
@end

@interface ChatTimeCellView : UIView
- (id)initWithViewModel:(id)arg1;
@end

@interface ChatTimeViewModel : NSObject
- (CGSize)measure:(CGSize)arg1;
@end

@interface ChatTableViewCell : UITableViewCell
- (CommonMessageCellView *)cellView;
@end

@interface GameController : NSObject
+ (NSString *)getMD5ByGameContent:(unsigned int)gameContent;
@end

@interface MessageRevokeMgr : NSObject
- (void)onRevokeMsg:(CMessageWrap *)msgWrap;
@end

@interface MMServiceCenter : NSObject
- (id)getService:(Class)serviceClass;
@end

@interface MMContext : NSObject
@property(readonly, nonatomic) MMServiceCenter *serviceCenter;
@property(readonly, nonatomic) NSString *userName;
+ (id)activeUserContext;
- (id)getService:(Class)cls;
@end

@interface DDAssistantSettingsViewController : UIViewController
@end

@implementation WBTouchTrailDotView

- (instancetype)initWithPoint:(CGPoint)point 
                     dotColor:(UIColor *)dotColor 
                     dotSize:(CGFloat)dotSize 
                    duration:(CGFloat)duration {
    CGRect frame = CGRectMake(point.x - dotSize/2, point.y - dotSize/2, dotSize, dotSize);
    self = [super initWithFrame:frame];
    if (self) {
        self.dotColor = dotColor;
        self.dotSize = dotSize;
        self.userInteractionEnabled = NO;
        
        self.backgroundColor = dotColor;
        self.layer.cornerRadius = dotSize / 2;
        
        self.alpha = 0.7;
        [UIView animateWithDuration:duration animations:^{
            self.alpha = 0;
        } completion:^(BOOL finished) {
            [self removeFromSuperview];
        }];
    }
    return self;
}

@end

@implementation WBTouchTrailView

- (instancetype)init {
    self = [super initWithFrame:CGRectZero];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.trailColor = [UIColor redColor];
        self.trailSize = 25.0;
        self.isMoving = NO;
        
        self.layer.masksToBounds = NO;
    }
    return self;
}

- (void)updateWithPoint:(CGPoint)point {
    [self updateWithPoint:point isMoving:NO];
}

- (void)updateWithPoint:(CGPoint)point isMoving:(BOOL)isMoving {
    self.isMoving = isMoving;
    
    [self.layer removeAllAnimations];
    
    CGRect frame = CGRectMake(point.x - self.trailSize/2, point.y - self.trailSize/2, self.trailSize, self.trailSize);
    self.frame = frame;
    
    self.layer.cornerRadius = self.trailSize / 2;
    
    self.backgroundColor = self.trailColor;
    
    self.transform = CGAffineTransformIdentity;
    
    if (!isMoving) {
        self.alpha = 1.0;
        
        self.layer.shadowColor = self.trailColor.CGColor;
        self.layer.shadowOffset = CGSizeZero;
        self.layer.shadowOpacity = 0.5;
        self.layer.shadowRadius = 5.0;
        
        [UIView animateWithDuration:0.2 animations:^{
            self.alpha = 0.8;
            self.transform = CGAffineTransformMakeScale(0.9, 0.9);
        }];
    } else {
        self.alpha = 0.7;
        
        self.layer.shadowColor = self.trailColor.CGColor;
        self.layer.shadowOffset = CGSizeZero;
        self.layer.shadowOpacity = 0.3;
        self.layer.shadowRadius = 3.0;
    }
}

@end

@interface MessageSettingsViewController : UIViewController {
    WCTableViewManager *_tableViewMgr;
}
@end

@implementation MessageSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"消息设置";
    
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    } else {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
    
    // 创建表格管理器
    _tableViewMgr = [[objc_getClass("WCTableViewManager") alloc] init];
    UIView *tableView = [_tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:tableView];
    
    [self reloadTableData];
}

- (void)reloadTableData {
    // 清空所有section
    while ([_tableViewMgr numberOfSections] > 0) {
        [_tableViewMgr deleteSection:0];
    }
    
    // 消息防撤回设置
    WCTableViewSectionManager *revokeSection = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:@"消息防撤回"];
    WCTableViewCellManager *preventRevokeCell = [objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(togglePreventRevoke:) target:self title:@"防撤回提示" isOn:isPreventRevokeEnabled()];
    [revokeSection addCell:preventRevokeCell];
    [_tableViewMgr addSection:revokeSection];
    
    // 时间显示设置
    WCTableViewSectionManager *timeSection = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:@"时间显示"];
    WCTableViewCellManager *hideTimeCell = [objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(toggleHideChatTime:) target:self title:@"隐藏自带时间" isOn:isHideChatTimeLabelEnabled()];
    [timeSection addCell:hideTimeCell];
    
    WCTableViewCellManager *avatarTimeCell = [objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(toggleAvatarTime:) target:self title:@"头像时间标签" isOn:isMessageTimeBelowAvatarEnabled()];
    [timeSection addCell:avatarTimeCell];
    [_tableViewMgr addSection:timeSection];
    
    // 提示信息
    WCTableViewSectionManager *tipSection = [objc_getClass("WCTableViewSectionManager") sectionInfoDefaut];
    WCTableViewCellManager *tipCell = [objc_getClass("WCTableViewCellManager") normalCellForSel:nil target:nil title:@"开启后，消息防撤回功能会在对方撤回消息时显示提示" rightValue:nil accessoryType:0];
    [tipSection addCell:tipCell];
    [_tableViewMgr addSection:tipSection];
    
    [_tableViewMgr reloadData];
}

- (void)togglePreventRevoke:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kPreventRevokeEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)toggleHideChatTime:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kHideChatTimeLabelKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)toggleAvatarTime:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kMessageTimeBelowAvatarKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

@interface GameSettingsViewController : UIViewController {
    WCTableViewManager *_tableViewMgr;
}
@end

@implementation GameSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"娱乐功能";
    
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    } else {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
    
    // 创建表格管理器
    _tableViewMgr = [[objc_getClass("WCTableViewManager") alloc] init];
    UIView *tableView = [_tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:tableView];
    
    [self reloadTableData];
}

- (void)reloadTableData {
    // 清空所有section
    while ([_tableViewMgr numberOfSections] > 0) {
        [_tableViewMgr deleteSection:0];
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL friendsCountEnabled = isFriendsCountEnabled();
    BOOL walletBalanceEnabled = isWalletBalanceEnabled();
    
    // 游戏控制设置
    WCTableViewSectionManager *gameSection = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:@"游戏控制"];
    WCTableViewCellManager *gameCheatCell = [objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(toggleGameCheat:) target:self title:@"骰子猜拳控制" isOn:isGameCheatEnabled()];
    [gameSection addCell:gameCheatCell];
    [_tableViewMgr addSection:gameSection];
    
    // 好友数量设置
    WCTableViewSectionManager *friendsSection = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:@"好友数量"];
    WCTableViewCellManager *friendsSwitchCell = [objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(toggleFriendsCount:) target:self title:@"自定义好友数量" isOn:friendsCountEnabled];
    [friendsSection addCell:friendsSwitchCell];
    
    if (friendsCountEnabled) {
        NSString *friendsCountValue = [defaults objectForKey:kFriendsCountValueKey] ?: @"";
        WCTableViewCellManager *friendsInputCell = [objc_getClass("WCTableViewCellManager") editorCellForSel:@selector(friendsCountChanged:) target:self title:@"好友数量" tip:@"输入好友数量（如：999）" focus:NO text:friendsCountValue];
        [friendsSection addCell:friendsInputCell];
    }
    [_tableViewMgr addSection:friendsSection];
    
    // 钱包余额设置
    WCTableViewSectionManager *walletSection = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:@"钱包余额"];
    WCTableViewCellManager *walletSwitchCell = [objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(toggleWalletBalance:) target:self title:@"自定义钱包余额" isOn:walletBalanceEnabled];
    [walletSection addCell:walletSwitchCell];
    
    if (walletBalanceEnabled) {
        NSString *walletBalanceValue = [defaults objectForKey:kWalletBalanceValueKey] ?: @"";
        WCTableViewCellManager *walletInputCell = [objc_getClass("WCTableViewCellManager") editorCellForSel:@selector(walletBalanceChanged:) target:self title:@"余额数值" tip:@"输入余额（如：9999.99）" focus:NO text:walletBalanceValue];
        [walletSection addCell:walletInputCell];
    }
    [_tableViewMgr addSection:walletSection];
    
    // 提示信息
    WCTableViewSectionManager *tipSection = [objc_getClass("WCTableViewSectionManager") sectionInfoDefaut];
    WCTableViewCellManager *tipCell = [objc_getClass("WCTableViewCellManager") normalCellForSel:nil target:nil title:@"开启游戏控制后，发送骰子或猜拳时会弹出选择窗口" rightValue:nil accessoryType:0];
    [tipSection addCell:tipCell];
    [_tableViewMgr addSection:tipSection];
    
    [_tableViewMgr reloadData];
}

- (void)toggleGameCheat:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kGameCheatEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)toggleFriendsCount:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kFriendsCountEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 重新加载表格以显示/隐藏输入框
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadTableData];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                            CFSTR("com.dd.assistant.settings_changed"),
                                            NULL,
                                            NULL,
                                            YES);
    });
}

- (void)toggleWalletBalance:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kWalletBalanceEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 重新加载表格以显示/隐藏输入框
    dispatch_async(dispatch_get_main_queue(), ^{
        [self reloadTableData];
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                            CFSTR("com.dd.assistant.settings_changed"),
                                            NULL,
                                            NULL,
                                            YES);
    });
}

- (void)friendsCountChanged:(UITextField *)sender {
    NSString *text = sender.text;
    if (text && [text length] > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:text forKey:kFriendsCountValueKey];
        [[NSUserDefaults standardUserDefaults] setObject:text forKey:kWCFriendsCountReplacementKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kFriendsCountValueKey];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kWCFriendsCountReplacementKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                        CFSTR("com.dd.assistant.settings_changed"),
                                        NULL,
                                        NULL,
                                        YES);
}

- (void)walletBalanceChanged:(UITextField *)sender {
    NSString *text = sender.text;
    if (text && [text length] > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:text forKey:kWalletBalanceValueKey];
        [[NSUserDefaults standardUserDefaults] setObject:text forKey:kWCWalletBalanceReplacementKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kWalletBalanceValueKey];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kWCWalletBalanceReplacementKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                        CFSTR("com.dd.assistant.settings_changed"),
                                        NULL,
                                        NULL,
                                        YES);
}

@end

@interface CSTouchTrailViewController : UIViewController {
    WCTableViewManager *_tableViewMgr;
}
@end

@implementation CSTouchTrailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"触摸轨迹";
    
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    } else {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
    
    // 创建表格管理器
    _tableViewMgr = [[objc_getClass("WCTableViewManager") alloc] init];
    UIView *tableView = [_tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:tableView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(screenCaptureDidChange)
                                               name:UIScreenCapturedDidChangeNotification
                                             object:nil];
    
    [self reloadTableData];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)screenCaptureDidChange {
    BOOL isRecording = UIScreen.mainScreen.isCaptured;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL onlyWhenRecording = [defaults boolForKey:kTouchTrailOnlyWhenRecordingKey];
    BOOL trailEnabled = [defaults boolForKey:kTouchTrailKey];
    
    if (onlyWhenRecording) {
        BOOL shouldDisplay = isRecording && trailEnabled;
        [defaults setBool:shouldDisplay forKey:kTouchTrailDisplayStateKey];
        [defaults synchronize];
    } else if (trailEnabled) {
        [defaults setBool:YES forKey:kTouchTrailDisplayStateKey];
        [defaults synchronize];
    }
}

- (void)reloadTableData {
    // 清空所有section
    while ([_tableViewMgr numberOfSections] > 0) {
        [_tableViewMgr deleteSection:0];
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL isTrailEnabled = [defaults boolForKey:kTouchTrailKey];
    
    // 主要设置
    WCTableViewSectionManager *mainSection = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:@"触摸轨迹设置"];
    WCTableViewCellManager *trailSwitchCell = [objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(toggleTrailEnabled:) target:self title:@"启用触摸轨迹" isOn:isTrailEnabled];
    [mainSection addCell:trailSwitchCell];
    [_tableViewMgr addSection:mainSection];
    
    if (isTrailEnabled) {
        // 高级设置
        WCTableViewSectionManager *advancedSection = [objc_getClass("WCTableViewSectionManager") sectionInfoHeader:@"高级设置"];
        
        WCTableViewCellManager *onlyRecordingCell = [objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(toggleOnlyWhenRecording:) target:self title:@"仅在录屏显示" isOn:[defaults boolForKey:kTouchTrailOnlyWhenRecordingKey]];
        [advancedSection addCell:onlyRecordingCell];
        
        WCTableViewCellManager *tailEffectCell = [objc_getClass("WCTableViewCellManager") switchCellForSel:@selector(toggleTailEnabled:) target:self title:@"使用拖尾效果" isOn:[defaults boolForKey:kTouchTrailTailEnabledKey]];
        [advancedSection addCell:tailEffectCell];
        [_tableViewMgr addSection:advancedSection];
    }
    
    // 提示信息
    WCTableViewSectionManager *tipSection = [objc_getClass("WCTableViewSectionManager") sectionInfoDefaut];
    NSString *tipText = @"开启后会在屏幕上显示触摸轨迹，便于录屏演示或教学";
    if (isTrailEnabled && [defaults boolForKey:kTouchTrailOnlyWhenRecordingKey]) {
        tipText = @"已开启仅录屏显示模式，当检测到屏幕录制时会自动显示触摸轨迹";
    }
    WCTableViewCellManager *tipCell = [objc_getClass("WCTableViewCellManager") normalCellForSel:nil target:nil title:tipText rightValue:nil accessoryType:0];
    [tipSection addCell:tipCell];
    [_tableViewMgr addSection:tipSection];
    
    [_tableViewMgr reloadData];
}

- (void)toggleTrailEnabled:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.isOn forKey:kTouchTrailKey];
    
    BOOL onlyWhenRecording = [defaults boolForKey:kTouchTrailOnlyWhenRecordingKey];
    if (onlyWhenRecording) {
        BOOL isRecording = UIScreen.mainScreen.isCaptured;
        [defaults setBool:(sender.isOn && isRecording) forKey:kTouchTrailDisplayStateKey];
    } else {
        [defaults setBool:sender.isOn forKey:kTouchTrailDisplayStateKey];
    }
    
    [defaults synchronize];
    
    // 重新加载表格以显示/隐藏高级设置
    [self reloadTableData];
}

- (void)toggleOnlyWhenRecording:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.isOn forKey:kTouchTrailOnlyWhenRecordingKey];
    
    BOOL trailEnabled = [defaults boolForKey:kTouchTrailKey];
    if (sender.isOn) {
        BOOL isRecording = UIScreen.mainScreen.isCaptured;
        [defaults setBool:(trailEnabled && isRecording) forKey:kTouchTrailDisplayStateKey];
    } else {
        [defaults setBool:trailEnabled forKey:kTouchTrailDisplayStateKey];
    }
    
    [defaults synchronize];
    [self reloadTableData];
}

- (void)toggleTailEnabled:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kTouchTrailTailEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

@implementation DDAssistantSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = PLUGIN_NAME;
    
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    } else {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
    
    // 创建表格管理器
    WCTableViewManager *tableViewMgr = [[objc_getClass("WCTableViewManager") alloc] init];
    UIView *tableView = [tableViewMgr getTableView];
    tableView.frame = self.view.bounds;
    tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:tableView];
    
    // 创建section
    WCTableViewSectionManager *section = [objc_getClass("WCTableViewSectionManager") sectionInfoDefaut];
    
    // 消息设置
    WCTableViewCellManager *messageCell = [objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(openMessageSettings) target:self title:@"消息设置" rightValue:nil accessoryType:1];
    [section addCell:messageCell];
    
    // 娱乐功能
    WCTableViewCellManager *gameCell = [objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(openGameSettings) target:self title:@"娱乐功能" rightValue:nil accessoryType:1];
    [section addCell:gameCell];
    
    // 触摸轨迹
    WCTableViewCellManager *touchCell = [objc_getClass("WCTableViewCellManager") normalCellForSel:@selector(openTouchTrailSettings) target:self title:@"触摸轨迹" rightValue:nil accessoryType:1];
    [section addCell:touchCell];
    
    [tableViewMgr addSection:section];
    [tableViewMgr reloadData];
}

- (void)openMessageSettings {
    MessageSettingsViewController *vc = [[MessageSettingsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openGameSettings {
    GameSettingsViewController *vc = [[GameSettingsViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)openTouchTrailSettings {
    CSTouchTrailViewController *vc = [[CSTouchTrailViewController alloc] init];
    [self.navigationController pushViewController:vc animated:YES];
}

@end

%hook NewSettingViewController
- (void)reloadTableData {
    %orig;
    if (g_hasPluginsMgr) {
        return;
    }
    static char kDDAssistantAddedKey;
    if (objc_getAssociatedObject(self, &kDDAssistantAddedKey)) return;
    [self.view layoutIfNeeded];
    WCTableViewManager *tableViewMgr = nil;
    Ivar ivar = class_getInstanceVariable([self class], "m_tableViewMgr");
    if (ivar) {
        tableViewMgr = object_getIvar(self, ivar);
    }
    if (!tableViewMgr) return;
    WCTableViewSectionManager *sectionInfo = [%c(WCTableViewSectionManager) sectionInfoDefaut];
    WCTableViewCellManager *settingCell = [%c(WCTableViewCellManager) normalCellForSel:@selector(onDDAssistantClicked) target:self title:PLUGIN_NAME];
    [sectionInfo addCell:settingCell];
    [tableViewMgr insertSection:sectionInfo At:0];
    MMTableView *tableView = [tableViewMgr getTableView];
    [tableView reloadData];
    objc_setAssociatedObject(self, &kDDAssistantAddedKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%new
- (void)onDDAssistantClicked {
    DDAssistantSettingsViewController *settingsVC = [[DDAssistantSettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    if (@available(iOS 13.0, *)) {
        nav.modalPresentationStyle = UIModalPresentationPageSheet;
    } else {
        nav.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    [self presentViewController:nav animated:YES completion:nil];
}
%end

%hook ChatTimeCellView
- (id)initWithViewModel:(id)arg1 {
    id view = %orig;
    if (view && (isMessageTimeBelowAvatarEnabled() || isHideChatTimeLabelEnabled())) {
        [(UIView *)view setHidden:YES];
    }
    return view;
}
%end

%hook ChatTimeViewModel
- (CGSize)measure:(CGSize)arg1 {
    if (isMessageTimeBelowAvatarEnabled() || isHideChatTimeLabelEnabled()) {
        return CGSizeMake(arg1.width, 0);
    }
    return %orig(arg1);
}
%end

%hook CMessageMgr
- (void)AddEmoticonMsg:(NSString *)msg MsgWrap:(CMessageWrap *)msgWrap {
    if (isGameCheatEnabled() && [msgWrap m_uiMessageType] == 47 && ([msgWrap m_uiGameType] == 2 || [msgWrap m_uiGameType] == 1)) {
        // 创建WCActionSheet
        WCActionSheet *actionSheet = [[%c(WCActionSheet) alloc] initWithTitle:@""];
        
        if ([msgWrap m_uiGameType] == 1) { // 猜拳
            // 添加猜拳选项
            [actionSheet addButtonWithTitle:@"剪刀" eventAction:^{
                unsigned int gameContent = 1; // 剪刀对应1
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
            [actionSheet addButtonWithTitle:@"石头" eventAction:^{
                unsigned int gameContent = 2; // 石头对应2
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
            [actionSheet addButtonWithTitle:@"布" eventAction:^{
                unsigned int gameContent = 3; // 布对应3
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
        } else if ([msgWrap m_uiGameType] == 2) { // 骰子
            // 添加骰子点数选项
            [actionSheet addButtonWithTitle:@"1点" eventAction:^{
                unsigned int gameContent = 4; // 1点对应4
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
            [actionSheet addButtonWithTitle:@"2点" eventAction:^{
                unsigned int gameContent = 5; // 2点对应5
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
            [actionSheet addButtonWithTitle:@"3点" eventAction:^{
                unsigned int gameContent = 6; // 3点对应6
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
            [actionSheet addButtonWithTitle:@"4点" eventAction:^{
                unsigned int gameContent = 7; // 4点对应7
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
            [actionSheet addButtonWithTitle:@"5点" eventAction:^{
                unsigned int gameContent = 8; // 5点对应8
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
            [actionSheet addButtonWithTitle:@"6点" eventAction:^{
                unsigned int gameContent = 9; // 6点对应9
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
        }
        
        // 查找当前窗口并显示
        UIWindowScene *windowScene = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                windowScene = (UIWindowScene *)scene;
                break;
            }
        }
        
        if (windowScene) {
            UIWindow *window = windowScene.windows.firstObject;
            if (window && window.rootViewController) {
                [actionSheet showInView:window];
            }
        }
        
        return;
    }
    %orig(msg, msgWrap);
}
%end

%hook CommonMessageCellView
- (id)initWithViewModel:(id)arg1 {
    id view = %orig;
    if (view && isMessageTimeBelowAvatarEnabled()) {
        UILabel *timeLabel = [[UILabel alloc] init];
        timeLabel.backgroundColor = [UIColor clearColor];
        timeLabel.numberOfLines = 0;
        timeLabel.textAlignment = NSTextAlignmentCenter;
        timeLabel.clipsToBounds = YES;
        timeLabel.frame = CGRectMake(0, 0, 100, 30);
        setTimeView(self, timeLabel);
    }
    return view;
}

- (void)updateNodeStatus {
    %orig;
    
    if (!isMessageTimeBelowAvatarEnabled()) {
        UIView *timeView = getTimeView(self);
        if (timeView) timeView.hidden = YES;
        return;
    }
    
    CommonMessageViewModel *viewModel = [self viewModel];
    if (!viewModel) return;
    
    NSString *messageTime = getMessageTime(viewModel);
    if (messageTime.length > 0) {
        if ([messageTime isEqualToString:@"-1"]) {
            getTimeView(self).hidden = YES;
            return;
        }
        
        UILabel *timeLabel = (UILabel *)getTimeView(self);
        if (!timeLabel) return;
        
        timeLabel.hidden = NO;
        timeLabel.text = messageTime;
        
        timeLabel.font = [UIFont boldSystemFontOfSize:7.0];
        timeLabel.textColor = [UIColor colorWithWhite:0.5 alpha:0.8];
        timeLabel.numberOfLines = 2;
        
        CGSize constraintSize = CGSizeMake(80, CGFLOAT_MAX);
        CGSize textSize = [messageTime boundingRectWithSize:constraintSize
                                                   options:NSStringDrawingUsesLineFragmentOrigin
                                                attributes:@{NSFontAttributeName: timeLabel.font}
                                                   context:nil].size;
        
        CGFloat labelWidth = textSize.width + 8.0;
        CGFloat labelHeight = textSize.height + 4.0;
        timeLabel.frame = CGRectMake(0, 0, labelWidth, labelHeight);
        
        CGFloat centerX = 0, centerY = 0;
        BOOL isSender = [viewModel isSender];
        
        UIView *headImageView = nil;
        UIView *contentView = [self valueForKey:@"m_contentView"];
        
        for (UIView *subview in self.subviews) {
            if ([NSStringFromClass([subview class]) isEqualToString:@"MMHeadImageView"]) {
                headImageView = subview;
                break;
            }
        }
        
        if (headImageView) {
            centerX = CGRectGetMidX(headImageView.frame);
            CGFloat topY = CGRectGetMaxY(headImageView.frame);
            centerY = topY + (timeLabel.bounds.size.height / 2) - 7.0;
        } else {
            if (contentView) {
                if (isSender) {
                    centerX = CGRectGetMinX(contentView.frame) - 1 - timeLabel.bounds.size.width / 2;
                } else {
                    centerX = CGRectGetMaxX(contentView.frame) + 1 + timeLabel.bounds.size.width / 2;
                }
                centerY = CGRectGetMaxY(contentView.frame) - timeLabel.bounds.size.height / 2;
            }
        }
        
        timeLabel.center = CGPointMake(centerX, centerY);
        
        if (![timeLabel isDescendantOfView:self]) {
            [self addSubview:timeLabel];
        }
        [self bringSubviewToFront:timeLabel];
    } else {
        getTimeView(self).hidden = YES;
    }
}

%end

%hook BaseMsgContentViewController
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = %orig;
    
    if (!isMessageTimeBelowAvatarEnabled()) {
        return cell;
    }
    
    Class ChatTableViewCellClass = objc_getClass("ChatTableViewCell");
    if (ChatTableViewCellClass && [cell isKindOfClass:ChatTableViewCellClass]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            ChatTableViewCell *chatCell = (ChatTableViewCell *)cell;
            CommonMessageCellView *cellView = [chatCell cellView];
            if (!cellView) return;
            
            id viewModel = [cellView valueForKey:@"viewModel"];
            if (!viewModel) return;
            
            if ([viewModel respondsToSelector:@selector(messageWrap)]) {
                CMessageWrap *messageWrap = [viewModel messageWrap];
                if (messageWrap && [messageWrap respondsToSelector:@selector(m_uiCreateTime)]) {
                    unsigned int createTime = messageWrap.m_uiCreateTime;
                    
                    if ([viewModel isKindOfClass:objc_getClass("TextMessageSubViewModel")]) {
                        TextMessageSubViewModel *textSubModel = (TextMessageSubViewModel *)viewModel;
                        id parentModel = [textSubModel valueForKey:@"parentModel"];
                        
                        NSArray *subViewModels = [parentModel valueForKey:@"subViewModels"];
                        
                        if (subViewModels.count > 0) {
                            if ([subViewModels indexOfObject:textSubModel] == 0) {
                                NSString *timeStr = getDoubleLineTimeString(createTime);
                                setMessageTime(viewModel, timeStr);
                            } else {
                                setMessageTime(viewModel, @"-1");
                            }
                        }
                    } 
                    else if (getMessageTime(viewModel) == nil) {
                        NSString *timeStr = getDoubleLineTimeString(createTime);
                        setMessageTime(viewModel, timeStr);
                    }
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if ([cellView respondsToSelector:@selector(updateNodeStatus)]) {
                            [cellView updateNodeStatus];
                        }
                    });
                }
            }
        });
    }
    
    return cell;
}
%end

%hook MessageRevokeMgr

- (void)onRevokeMsg:(CMessageWrap *)msgWrap {
    BOOL isEnabled = isPreventRevokeEnabled();
    
    if (!isEnabled) {
        %orig;
        return;
    }
    
    if (!msgWrap || !msgWrap.m_nsContent) {
        %orig;
        return;
    }
    
    NSString *msgContent = msgWrap.m_nsContent;
    NSString *session = parseParam(msgContent, @"<session>", @"</session>");
    NSString *newMsgID = parseParam(msgContent, @"<newmsgid>", @"</newmsgid>");
    
    if (session.length == 0 || newMsgID.length == 0) {
        %orig;
        return;
    }
    
    MMContext *context = [%c(MMContext) activeUserContext];
    if (!context) {
        %orig;
        return;
    }
    
    MMServiceCenter *serviceCenter = context.serviceCenter;
    if (!serviceCenter) {
        %orig;
        return;
    }
    
    CContactMgr *contactMgr = [serviceCenter getService:%c(CContactMgr)];
    CMessageMgr *messageMgr = [serviceCenter getService:%c(CMessageMgr)];
    
    if (!contactMgr || !messageMgr) {
        %orig;
        return;
    }
    
    CContact *contact = [contactMgr getContactByName:msgWrap.m_nsFromUsr];
    BOOL isGroupChat = [msgWrap.m_nsFromUsr hasSuffix:@"@chatroom"];
    NSString *displayName = getDisplayName(contact, isGroupChat, msgContent);
    
    CMessageWrap *originalMsg = [messageMgr GetMsg:session n64SvrID:[newMsgID longLongValue]];
    if (!originalMsg) {
        %orig;
        return;
    }
    
    NSString *currentUserName = context.userName;
    BOOL isSelfRevoke = [msgWrap.m_nsFromUsr isEqualToString:currentUserName] || 
                       [originalMsg.m_nsFromUsr isEqualToString:currentUserName];
    
    if (isSelfRevoke) {
        %orig;
        return;
    }
    
    NSString *timeString = formatTimeString(originalMsg.m_uiCreateTime);
    NSString *originalContent = getMessageContentAdapter(originalMsg);
    
    NSString *newContent;
    if (isGroupChat) {
        newContent = [NSString stringWithFormat:@"⚠️拦截通知⚠️\n时间: %@\n操作: %@ 撤回了一条消息\n内容: %@", 
                     timeString, displayName, originalContent];
    } else {
        newContent = [NSString stringWithFormat:@"⚠️拦截通知⚠️\n时间: %@\n操作: %@ 撤回了一条消息\n内容: %@", 
                     timeString, displayName, originalContent];
    }
    
    CMessageWrap *newMsg = [[%c(CMessageWrap) alloc] initWithMsgType:10000];
    [newMsg setM_nsFromUsr:msgWrap.m_nsFromUsr];
    [newMsg setM_nsToUsr:msgWrap.m_nsToUsr];
    [newMsg setM_nsContent:newContent];
    [newMsg setM_uiStatus:4];
    [newMsg setM_uiCreateTime:originalMsg.m_uiCreateTime];
    
    [messageMgr AddLocalMsg:session MsgWrap:newMsg fixTime:YES NewMsgArriveNotify:NO];
}

%end

%hook MMUILabel
- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }
    if (isFriendsCountEnabled() && gFriendsCountReplacement && [gFriendsCountReplacement length] > 0) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\d+个朋友$" options:0 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
        if (match) {
            NSString *customText = [NSString stringWithFormat:@"%@个朋友", gFriendsCountReplacement];
            %orig(customText);
            return;
        }
    }
    %orig;
}
- (void)setAttributedText:(NSAttributedString *)attributedText {
    if (!attributedText) {
        %orig;
        return;
    }
    NSString *originalString = [attributedText string];
    if (isFriendsCountEnabled() && gFriendsCountReplacement && [gFriendsCountReplacement length] > 0) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^\\d+个朋友$" options:0 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:originalString options:0 range:NSMakeRange(0, originalString.length)];
        if (match) {
            NSString *customText = [NSString stringWithFormat:@"%@个朋友", gFriendsCountReplacement];
            NSMutableAttributedString *newAttributedText = [[NSMutableAttributedString alloc] initWithString:customText attributes:[attributedText attributesAtIndex:0 effectiveRange:NULL]];
            %orig(newAttributedText);
            return;
        }
    }
    %orig;
}
%end

%hook MFTitleView
- (void)updateTitleView:(unsigned int)arg1 title:(NSString *)title {
    if (!title) {
        %orig;
        return;
    }
    BOOL isContactsTitle = [title isEqualToString:kWCOriginalContacts];
    if (!isContactsTitle) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^通讯录\\(\\d+\\)$" options:0 error:nil];
        NSTextCheckingResult *match = [regex firstMatchInString:title options:0 range:NSMakeRange(0, title.length)];
        isContactsTitle = (match != nil);
    }
    if (isContactsTitle && isFriendsCountEnabled() && gFriendsCountReplacement && [gFriendsCountReplacement length] > 0) {
        %orig(arg1, gFriendsCountReplacement);
        return;
    }
    %orig;
}
%end

%hook WCPayWalletEntryHeaderView
- (void)handleUpdateWalletBalance {
    %orig;
    if (!isWalletBalanceEnabled() || !gWalletBalanceReplacement || [gWalletBalanceReplacement length] == 0) {
        return;
    }
    TimeoutNumber *timeoutNumber = [self valueForKey:@"_timeoutNumber"];
    if (timeoutNumber) {
        NSScanner *scanner = [NSScanner scannerWithString:gWalletBalanceReplacement];
        unsigned long long balanceValue = 0;
        if ([scanner scanUnsignedLongLong:&balanceValue]) {
            balanceValue = balanceValue * 100;
            [timeoutNumber updateNumber:balanceValue];
        } else {
            if (gWalletBalanceReplacement.length > 0) {
                unichar firstChar = [gWalletBalanceReplacement characterAtIndex:0];
                [timeoutNumber updateNumber:firstChar];
            }
        }
    }
}
- (void)setupTimeoutNumber {
    %orig;
    if (!isWalletBalanceEnabled() || !gWalletBalanceReplacement || [gWalletBalanceReplacement length] == 0) {
        return;
    }
    TimeoutNumber *timeoutNumber = [self valueForKey:@"_timeoutNumber"];
    if (timeoutNumber) {
        NSScanner *scanner = [NSScanner scannerWithString:gWalletBalanceReplacement];
        unsigned long long balanceValue = 0;
        if ([scanner scanUnsignedLongLong:&balanceValue]) {
            balanceValue = balanceValue * 100;
            [timeoutNumber updateNumber:balanceValue];
        } else {
            if (gWalletBalanceReplacement.length > 0) {
                unichar firstChar = [gWalletBalanceReplacement characterAtIndex:0];
                [timeoutNumber updateNumber:firstChar];
            }
        }
    }
}
- (void)updateBalanceEntryView {
    %orig;
    if (!isWalletBalanceEnabled() || !gWalletBalanceReplacement || [gWalletBalanceReplacement length] == 0) {
        return;
    }
    TimeoutNumber *timeoutNumber = [self valueForKey:@"_timeoutNumber"];
    if (timeoutNumber) {
        NSScanner *scanner = [NSScanner scannerWithString:gWalletBalanceReplacement];
        unsigned long long balanceValue = 0;
        if ([scanner scanUnsignedLongLong:&balanceValue]) {
            balanceValue = balanceValue * 100;
            [timeoutNumber updateNumber:balanceValue];
        } else {
            if (gWalletBalanceReplacement.length > 0) {
                unichar firstChar = [gWalletBalanceReplacement characterAtIndex:0];
                [timeoutNumber updateNumber:firstChar];
            }
        }
    }
    MMUILabel *balanceMoneyLabel = [self valueForKey:@"_balanceMoneyLabel"];
    if (balanceMoneyLabel) {
        NSString *originalText = balanceMoneyLabel.text;
        if (originalText && [originalText length] > 0) {
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\d+(\\.\\d+)?" options:0 error:nil];
            NSString *newText = [regex stringByReplacingMatchesInString:originalText options:0 range:NSMakeRange(0, originalText.length) withTemplate:gWalletBalanceReplacement];
            balanceMoneyLabel.text = newText;
        }
    }
}
- (void)updateBalanceAndRefreshView {
    %orig;
    if (!isWalletBalanceEnabled() || !gWalletBalanceReplacement || [gWalletBalanceReplacement length] == 0) {
        return;
    }
    TimeoutNumber *timeoutNumber = [self valueForKey:@"_timeoutNumber"];
    if (timeoutNumber) {
        NSScanner *scanner = [NSScanner scannerWithString:gWalletBalanceReplacement];
        unsigned long long balanceValue = 0;
        if ([scanner scanUnsignedLongLong:&balanceValue]) {
            balanceValue = balanceValue * 100;
            [timeoutNumber updateNumber:balanceValue];
        } else {
            if (gWalletBalanceReplacement.length > 0) {
                unichar firstChar = [gWalletBalanceReplacement characterAtIndex:0];
                [timeoutNumber updateNumber:firstChar];
            }
        }
    }
    MMUILabel *balanceMoneyLabel = [self valueForKey:@"_balanceMoneyLabel"];
    if (balanceMoneyLabel) {
        NSString *originalText = balanceMoneyLabel.text;
        if (originalText && [originalText length] > 0) {
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\d+(\\.\\d+)?" options:0 error:nil];
            NSString *newText = [regex stringByReplacingMatchesInString:originalText options:0 range:NSMakeRange(0, originalText.length) withTemplate:gWalletBalanceReplacement];
            balanceMoneyLabel.text = newText;
        }
    }
}
%end

%hook TimeoutNumber
- (void)updateNumber:(unsigned long long)arg1 {
    if (!isWalletBalanceEnabled() || !gWalletBalanceReplacement || [gWalletBalanceReplacement length] == 0) {
        %orig;
        return;
    }
    UIView *parentView = self.superview;
    while (parentView && ![parentView isKindOfClass:%c(WCPayWalletEntryHeaderView)]) {
        parentView = parentView.superview;
    }
    if (!parentView) {
        %orig;
        return;
    }
    NSScanner *scanner = [NSScanner scannerWithString:gWalletBalanceReplacement];
    unsigned long long balanceValue = 0;
    if ([scanner scanUnsignedLongLong:&balanceValue]) {
        balanceValue = balanceValue * 100;
        %orig(balanceValue);
    } else {
        if (gWalletBalanceReplacement.length > 0) {
            unichar firstChar = [gWalletBalanceReplacement characterAtIndex:0];
            %orig(firstChar);
        } else {
            %orig;
        }
    }
}
- (void)defaultNumber:(unsigned long long)arg1 {
    if (!isWalletBalanceEnabled() || !gWalletBalanceReplacement || [gWalletBalanceReplacement length] == 0) {
        %orig;
        return;
    }
    UIView *parentView = self.superview;
    while (parentView && ![parentView isKindOfClass:%c(WCPayWalletEntryHeaderView)]) {
        parentView = parentView.superview;
    }
    if (!parentView) {
        %orig;
        return;
    }
    NSScanner *scanner = [NSScanner scannerWithString:gWalletBalanceReplacement];
    unsigned long long balanceValue = 0;
    if ([scanner scanUnsignedLongLong:&balanceValue]) {
        balanceValue = balanceValue * 100;
        %orig(balanceValue);
    } else {
        if (gWalletBalanceReplacement.length > 0) {
            unichar firstChar = [gWalletBalanceReplacement characterAtIndex:0];
            %orig(firstChar);
        } else {
            %orig;
        }
    }
}
%end

%hook UIApplication

+ (void)load {
    %orig;
    touchViews = [NSMutableDictionary dictionary];
    touchTailViews = [NSMutableDictionary dictionary];
    touchLastPointTimes = [NSMutableDictionary dictionary];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    isTrailEnabled = [defaults boolForKey:kTouchTrailDisplayStateKey];
}

- (void)sendEvent:(UIEvent *)event {
    %orig;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL shouldShowTrail = [defaults boolForKey:kTouchTrailDisplayStateKey];
    
    if (shouldShowTrail != isTrailEnabled) {
        isTrailEnabled = shouldShowTrail;
        
        if (!isTrailEnabled) {
            [touchViews.allValues makeObjectsPerformSelector:@selector(removeFromSuperview)];
            [touchViews removeAllObjects];
            
            for (NSMutableArray *dotViews in touchTailViews.allValues) {
                [dotViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
            }
            [touchTailViews removeAllObjects];
            [touchLastPointTimes removeAllObjects];
        }
    }
    
    if (!isTrailEnabled) {
        return;
    }
    
    BOOL showTail = [defaults boolForKey:kTouchTrailTailEnabledKey];
    
    NSSet *allTouches = event.allTouches;
    for (UITouch *touch in allTouches) {
        CGPoint location = [touch locationInView:nil];
        NSValue *key = [NSValue valueWithPointer:(__bridge const void *)(touch)];
        WBTouchTrailView *trailView = touchViews[key];
        
        switch (touch.phase) {
            case UITouchPhaseBegan: {
                if (!trailView) {
                    trailView = [[WBTouchTrailView alloc] init];
                    trailView.trailSize = 25.0;
                    trailView.trailColor = [UIColor redColor];
                    
                    [touch.window addSubview:trailView];
                    touchViews[key] = trailView;
                }
                [trailView updateWithPoint:location isMoving:NO];
                
                if (showTail) {
                    touchTailViews[key] = [NSMutableArray array];
                    touchLastPointTimes[key] = @(CACurrentMediaTime());
                }
                break;
            }
            case UITouchPhaseMoved: {
                [trailView updateWithPoint:location isMoving:YES];
                
                if (showTail) {
                    NSMutableArray *tailDots = touchTailViews[key];
                    if (tailDots) {
                        NSTimeInterval now = CACurrentMediaTime();
                        NSTimeInterval lastTime = [touchLastPointTimes[key] doubleValue];
                        CGFloat timeDiff = now - lastTime;
                        
                        if (timeDiff >= 0.05) {
                            WBTouchTrailDotView *dotView = [[WBTouchTrailDotView alloc] initWithPoint:location 
                                                                                            dotColor:[UIColor redColor] 
                                                                                            dotSize:17.5
                                                                                           duration:0.8];
                            
                            [touch.window addSubview:dotView];
                            [tailDots addObject:dotView];
                            
                            touchLastPointTimes[key] = @(now);
                        }
                    }
                }
                break;
            }
            case UITouchPhaseEnded:
            case UITouchPhaseCancelled: {
                if (trailView) {
                    [UIView animateWithDuration:0.3 animations:^{
                        trailView.alpha = 0;
                    } completion:^(BOOL finished) {
                        [trailView removeFromSuperview];
                        [touchViews removeObjectForKey:key];
                    }];
                }
                
                [touchTailViews removeObjectForKey:key];
                [touchLastPointTimes removeObjectForKey:key];
                break;
            }
            default:
                break;
        }
    }
}

%end

%ctor {
    @autoreleasepool {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *defaultValues = @{
            kGameCheatEnabledKey: @NO,
            kPreventRevokeEnabledKey: @NO,
            kMessageTimeBelowAvatarKey: @NO,
            kHideChatTimeLabelKey: @NO,
            kFriendsCountEnabledKey: @NO,
            kWalletBalanceEnabledKey: @NO,
            kTouchTrailKey: @NO,
            kTouchTrailOnlyWhenRecordingKey: @NO,
            kTouchTrailDisplayStateKey: @NO,
            kTouchTrailTailEnabledKey: @NO
        };
        
        for (NSString *key in defaultValues) {
            if (![defaults objectForKey:key]) {
                id value = defaultValues[key];
                if ([value isKindOfClass:[NSNumber class]]) {
                    [defaults setBool:[value boolValue] forKey:key];
                }
            }
        }
        [defaults synchronize];
        loadFriendsAndWalletSettings();
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        (CFNotificationCallback)loadFriendsAndWalletSettings,
                                        CFSTR("com.dd.assistant.settings_changed"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        Class pluginsMgrClass = NSClassFromString(@"WCPluginsMgr");
        if (pluginsMgrClass && [pluginsMgrClass respondsToSelector:@selector(sharedInstance)]) {
            g_hasPluginsMgr = YES;
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:PLUGIN_NAME 
                version:PLUGIN_VERSION 
                controller:@"DDAssistantSettingsViewController"];
            NSLog(@"[DD助手] 插件已注册到插件管理器 - %@ v%@", PLUGIN_NAME, PLUGIN_VERSION);
        } else {
            g_hasPluginsMgr = NO;
            NSLog(@"[DD助手] 插件管理器未找到，将添加到微信设置页面 - %@ v%@", PLUGIN_NAME, PLUGIN_VERSION);
        }
    }
}