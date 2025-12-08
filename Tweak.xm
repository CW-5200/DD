#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

#define PLUGIN_NAME @"DD助手"
#define PLUGIN_VERSION @"1.0.0"

// 设置键名定义
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
static NSString * const kFakeLocationEnabledKey = @"com.dd.assistant.fake.location.enabled";
static NSString * const kFakeLatitudeKey = @"com.dd.assistant.fake.latitude";
static NSString * const kFakeLongitudeKey = @"com.dd.assistant.fake.longitude";
static NSString * const kCustomStepsEnabledKey = @"com.dd.assistant.custom.steps.enabled";
static NSString * const kCustomStepsValueKey = @"com.dd.assistant.custom.steps.value";
static NSString * const kLastStepsUpdateDateKey = @"com.dd.assistant.last.steps.update.date";
static NSString * const kTouchTrailKey = @"com.wechat.tweak.touch.trail.enabled";
static NSString * const kTouchTrailOnlyWhenRecordingKey = @"com.wechat.tweak.touch.trail.only.when.recording";
static NSString * const kTouchTrailDisplayStateKey = @"com.wechat.tweak.touch.trail.display.state";
static NSString * const kTouchTrailTailEnabledKey = @"com.wechat.tweak.touch.trail.tail.enabled";

// 全局变量
static NSMutableDictionary *touchViews;
static NSMutableDictionary *touchTailViews;
static NSMutableDictionary *touchLastPointTimes;
static BOOL isTrailEnabled;
static char kMessageTimeKey;
static char kTimeViewKey;
static NSString * const kWCOriginalContacts = @"通讯录";
static BOOL gFriendsCountEnabled;
static NSString *gFriendsCountReplacement;
static BOOL gWalletBalanceEnabled;
static NSString *gWalletBalanceReplacement;
static BOOL g_hasPluginsMgr;
static BOOL gFakeLocationEnabled;
static double gFakeLatitude = 39.9035;
static double gFakeLongitude = 116.3976;
static BOOL gCustomStepsEnabled;
static NSInteger gCustomStepsValue;
static NSDate *gLastStepsUpdateDate;

// 工具函数
static NSString* parseParam(NSString *content, NSString *begin, NSString *end) {
    NSRange beginRange = [content rangeOfString:begin];
    NSRange endRange = [content rangeOfString:end];
    if (beginRange.location == NSNotFound || endRange.location <= beginRange.location + begin.length) return nil;
    return [content substringWithRange:NSMakeRange(beginRange.location + begin.length, endRange.location - (beginRange.location + begin.length))];
}

static NSString* getDisplayName(CContact *contact, BOOL isGroupChat, NSString *revokeContent) {
    if (isGroupChat) {
        NSString *name = parseParam(revokeContent, @"<![CDATA[", @"撤回了一条消息");
        return [NSString stringWithFormat:@"\"%@\"", name.length ? name : contact.m_nsNickName ?: contact.m_nsUsrName];
    } else {
        return [NSString stringWithFormat:@"\"%@\"", contact.m_nsRemark ?: contact.m_nsNickName ?: contact.m_nsUsrName ?: @"对方"];
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
        case 1: return [NSString stringWithFormat:@"\"%@...\"", msgWrap.m_nsContent.length > 30 ? [msgWrap.m_nsContent substringToIndex:27] : msgWrap.m_nsContent];
        case 3: return @"\"图片\"";
        case 34: return @"\"语音\"";
        case 43: return @"\"视频\"";
        case 47: return @"\"表情\"";
        case 49: return @"\"链接\"";
        case 50: return @"\"视频号\"";
        case 62: return @"\"直播\"";
        default: return [NSString stringWithFormat:@"\"类型%d\"", msgWrap.m_uiMessageType];
    }
}

static NSString* getDoubleLineTimeString(unsigned int timestamp) {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd\nHH:mm:ss";
    return [formatter stringFromDate:date];
}

static BOOL isToday(NSDate *date) {
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *components = [calendar components:NSCalendarUnitYear|NSCalendarUnitMonth|NSCalendarUnitDay fromDate:date];
    NSDate *today = [calendar dateFromComponents:components];
    return [today isEqualToDate:[calendar dateFromComponents:components]];
}

// 关联对象存取
static void setMessageTime(id self, NSString *time) { objc_setAssociatedObject(self, &kMessageTimeKey, time, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static NSString *getMessageTime(id self) { return objc_getAssociatedObject(self, &kMessageTimeKey); }
static void setTimeView(id self, UIView *view) { objc_setAssociatedObject(self, &kTimeViewKey, view, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static UIView *getTimeView(id self) { return objc_getAssociatedObject(self, &kTimeViewKey); }

// 主要功能实现
%hook NewSettingViewController
- (void)reloadTableData {
    %orig;
    if (g_hasPluginsMgr) return;
    
    static char kDDAssistantAddedKey;
    if (objc_getAssociatedObject(self, &kDDAssistantAddedKey)) return;
    
    WCTableViewManager *tableViewMgr = object_getIvar(self, class_getInstanceVariable([self class], "m_tableViewMgr"));
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
    [self presentViewController:nav animated:YES completion:nil];
}
%end

%hook ChatTimeCellView
- (id)initWithViewModel:(id)arg1 {
    id view = %orig;
    if (isMessageTimeBelowAvatarEnabled()) [(UIView *)view setHidden:YES];
    return view;
}
%end

%hook ChatTimeViewModel
- (CGSize)measure:(CGSize)arg1 {
    return isMessageTimeBelowAvatarEnabled() ? CGSizeMake(arg1.width, 0) : %orig(arg1);
}
%end

%hook CMessageMgr
- (void)AddEmoticonMsg:(NSString *)msg MsgWrap:(CMessageWrap *)msgWrap {
    if (isGameCheatEnabled() && msgWrap.m_uiMessageType == 47) {
        WCActionSheet *actionSheet = [[%c(WCActionSheet) alloc] initWithTitle:@"请选择操作"];
        
        if (msgWrap.m_uiGameType == 1) {
            [actionSheet addButtonWithTitle:@"剪刀" eventAction:^{
                [self setGameContent:msgWrap gameType:1];
            }];
            [actionSheet addButtonWithTitle:@"石头" eventAction:^{
                [self setGameContent:msgWrap gameType:2];
            }];
            [actionSheet addButtonWithTitle:@"布" eventAction:^{
                [self setGameContent:msgWrap gameType:3];
            }];
        } else if (msgWrap.m_uiGameType == 2) {
            for (int i = 1; i <= 6; i++) {
                [actionSheet addButtonWithTitle:[NSString stringWithFormat:@"%d点", i] eventAction:^{
                    [self setGameContent:msgWrap gameType:3+i];
                }];
            }
        }
        
        UIWindow *window = [[[UIApplication sharedApplication] connectedScenes] 
                           filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"activationState == %d", UISceneActivationStateForegroundActive]]
                           .firstObject.windows.firstObject;
        [actionSheet showInView:window];
        return;
    }
    %orig;
}

%new
- (void)setGameContent:(CMessageWrap *)msgWrap gameType:(NSInteger)type {
    unsigned int gameContent = type;
    NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
    if (md5) {
        [msgWrap setM_nsEmoticonMD5:md5];
        [msgWrap setM_uiGameContent:gameContent];
    }
    %orig(msgWrap);
}
%end

%hook CommonMessageCellView
- (void)updateNodeStatus {
    %orig;
    
    if (!isMessageTimeBelowAvatarEnabled()) return;
    
    CommonMessageViewModel *viewModel = [self viewModel];
    if (!viewModel) return;
    
    unsigned int createTime = [viewModel.messageWrap m_uiCreateTime];
    NSString *timeStr = isToday(createTime) ? formatTimeString(createTime) : getDoubleLineTimeString(createTime);
    
    setMessageTime(viewModel, timeStr);
    [self updateSubviews];
}

%new
- (void)updateSubviews {
    UILabel *timeLabel = getTimeView(self);
    if (!timeLabel) return;
    
    CommonMessageViewModel *viewModel = [self viewModel];
    if (!viewModel) return;
    
    CGFloat labelWidth = [timeLabel.text boundingRectWithSize:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX) 
                                                   options:NSStringDrawingUsesLineFragmentOrigin 
                                                attributes:@{NSFontAttributeName: timeLabel.font} 
                                                   context:nil].size.width + 8;
    
    CGFloat centerX = CGRectGetMidX([self headImageView].frame);
    CGFloat centerY = CGRectGetMaxY([self headImageView].frame) + 7;
    
    timeLabel.frame = CGRectMake(centerX - labelWidth/2, centerY - 10, labelWidth, 20);
    [self addSubview:timeLabel];
    [self bringSubviewToFront:timeLabel];
}
%end

%hook BaseMsgContentViewController
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = %orig;
    
    if (!isMessageTimeBelowAvatarEnabled()) return cell;
    
    Class ChatTableViewCellClass = objc_getClass("ChatTableViewCell");
    if ( return cell;
    
    CommonMessageCellView *cellView = [cell cellView];
    if (!cellView) return cell;
    
    CommonMessageViewModel *viewModel = [cellView viewModel];
    if (!viewModel) return cell;
    
    CMessageWrap *messageWrap = [viewModel messageWrap];
    if (!messageWrap) return cell;
    
    unsigned int createTime = messageWrap.m_uiCreateTime;
    NSString *timeStr = isToday(createTime) ? formatTimeString(createTime) : getDoubleLineTimeString(createTime);
    
    setMessageTime(viewModel, timeStr);
    [cellView updateNodeStatus];
    
    return cell;
}
%end

%hook MessageRevokeMgr
- (void)onRevokeMsg:(CMessageWrap *)msgWrap {
    if (!isPreventRevokeEnabled() || !msgWrap.m_nsContent) return %orig;
    
    NSString *session = parseParam(msgWrap.m_nsContent, @"<session>", @"</session>");
    NSString *newMsgID = parseParam(msgWrap.m_nsContent, @"<newmsgid>", @"</newmsgid>");
    
    if (session.length == 0 || newMsgID.length == 0) return %orig;
    
    MMContext *context = [%c(MMContext) activeUserContext];
    if (!context) return %orig;
    
    CContactMgr *contactMgr = [context.serviceCenter getService:%c(CContactMgr)];
    CMessageMgr *messageMgr = [context.serviceCenter getService:%c(CMessageMgr)];
    
    if (!contactMgr || !messageMgr) return %orig;
    
    CContact *contact = [contactMgr getContactByName:msgWrap.m_nsFromUsr];
    BOOL isGroupChat = [msgWrap.m_nsFromUsr hasSuffix:@"@chatroom"];
    NSString *displayName = getDisplayName(contact, isGroupChat, msgWrap.m_nsContent);
    
    CMessageWrap *originalMsg = [messageMgr GetMsg:session n64SvrID:[newMsgID longLongValue]];
    if (!originalMsg) return %orig;
    
    NSString *currentUserName = context.userName;
    if ([msgWrap.m_nsFromUsr isEqualToString:currentUserName] || [originalMsg.m_nsFromUsr isEqualToString:currentUserName]) return %orig;
    
    NSString *timeString = formatTimeString(originalMsg.m_uiCreateTime);
    NSString *originalContent = getMessageContentAdapter(originalMsg);
    NSString *newContent = [NSString stringWithFormat:@"⚠️拦截通知⚠️\n时间: %@\n操作: %@ 撤回了一条消息\n内容: %@", timeString, displayName, originalContent];
    
    CMessageWrap *newMsg = [[%c(CMessageWrap) alloc] initWithMsgType:10000];
    [newMsg setM_nsFromUsr:msgWrap.m_nsFromUsr];
    [newMsg setM_nsToUsr:msgWrap.m_nsToUsr];
    [newMsg setM_nsContent:newContent];
    [newMsg setM_uiStatus:4];
    [newMsg setM_uiCreateTime:originalMsg.m_uiCreateTime];
    
    [messageMgr AddLocalMsg:session MsgWrap:newMsg fixTime:YES NewMsgArriveNotify:NO];
}
%end

// 其他Hook实现（省略部分重复代码，保留结构）
// ...

%ctor {
    @autoreleasepool {
        touchViews = [NSMutableDictionary dictionary];
        touchTailViews = [NSMutableDictionary dictionary];
        touchLastPointTimes = [NSMutableDictionary dictionary];
        isTrailEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kTouchTrailDisplayStateKey];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *defaultValues = @{
            kGameCheatEnabledKey: @NO,
            kPreventRevokeEnabledKey: @NO,
            kMessageTimeBelowAvatarKey: @NO,
            kHideChatTimeLabelKey: @NO,
            kFriendsCountEnabledKey: @NO,
            kWalletBalanceEnabledKey: @NO,
            kFakeLocationEnabledKey: @NO,
            kCustomStepsEnabledKey: @NO,
            kTouchTrailKey: @NO,
            kTouchTrailOnlyWhenRecordingKey: @NO,
            kTouchTrailDisplayStateKey: @NO,
            kTouchTrailTailEnabledKey: @NO
        };
        
        [defaults registerDefaults:defaultValues];
        [defaults synchronize];
        
        loadAllSettings();
        
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        (CFNotificationCallback)loadAllSettings,
                                        CFSTR("com.dd.assistant.settings_changed"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        
        g_hasPluginsMgr = NSClassFromString(@"WCPluginsMgr") && [NSClassFromString(@"WCPluginsMgr") sharedInstance];
    }
}
