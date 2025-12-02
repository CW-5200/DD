#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#define PLUGIN_NAME @"DD助手"
#define PLUGIN_VERSION @"1.0.0"

static NSString * const kHideOtherAvatarKey = @"com.dd.assistant.hide.other.avatar";
static NSString * const kHideSelfAvatarKey = @"com.dd.assistant.hide.self.avatar";
static NSString * const kPreventRevokeEnabledKey = @"com.dd.assistant.prevent.revoke.enabled";
static NSString * const kHideChatTimeLabelKey = @"com.dd.assistant.hide.chat.time.label";
static NSString * const kMessageTimeEnabledKey = @"com.dd.assistant.message.time.enabled";
static NSString * const kGameCheatEnabledKey = @"com.dd.assistant.game.cheat.enabled";
static NSString * const kMessageTimeFontSizeKey = @"com.dd.assistant.messageTime.fontSize";
static NSString * const kMessageTimeBoldFontKey = @"com.dd.assistant.messageTime.boldFont";
static NSString * const kMessageTimeShowBelowAvatarKey = @"com.dd.assistant.messageTime.showBelowAvatar";
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

static CGFloat const kDefaultFontSize = 7.0f;
static CGFloat const kMaxLabelWidth = 90.0f;
static BOOL g_hasPluginsMgr = NO;
static char kMessageTimeKey;
static char kTimeViewKey;
static NSString * const kWCOriginalContacts = @"通讯录";
static BOOL gFriendsCountEnabled = NO;
static NSString *gFriendsCountReplacement = nil;
static BOOL gWalletBalanceEnabled = NO;
static NSString *gWalletBalanceReplacement = nil;

@interface AvatarSettingsViewController : UITableViewController {
    NSArray *_settings;
}
@end

@interface MessageSettingsViewController : UITableViewController {
    NSArray *_mainSettings;
    NSArray *_timeSettings;
    BOOL _messageTimeEnabled;
}
@end

@interface GameSettingsViewController : UITableViewController <UITextFieldDelegate> {
    NSArray *_settings;
    UITextField *_friendsCountField;
    UITextField *_walletBalanceField;
    UIButton *_friendsCountConfirmButton;
    UIButton *_walletBalanceConfirmButton;
}
@end

@interface CSTouchTrailViewController : UITableViewController
@end

@interface DDAssistantSettingsViewController : UITableViewController {
    NSArray *_sections;
}
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
@end

@interface WCTableViewSectionManager : NSObject
+ (instancetype)sectionInfoHeader:(NSString *)header;
+ (instancetype)sectionInfoDefaut;
- (void)addCell:(WCTableViewCellManager *)cell;
@end

@interface WCTableViewManager : NSObject
- (void)insertSection:(id)section At:(NSInteger)index;
- (id)getTableView;
@end

@interface MMTableView : UITableView
@end

@interface NewSettingViewController : UIViewController {
    WCTableViewManager *m_tableViewMgr;
}
- (void)reloadTableData;
@end

@interface CContact : NSObject
@property(copy, nonatomic) NSString *m_nsUsrName;
@property(copy, nonatomic) NSString *m_nsNickName;
@property(copy, nonatomic) NSString *m_nsRemark;
@end

@interface BaseMsgContentViewController : UIViewController
- (CContact *)GetContact;
@end

@interface CommonMessageViewModel : NSObject
- (BOOL)isSender;
- (BOOL)isShowHeadImage;
@property(retain, nonatomic) id messageWrap;
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
- (instancetype)initWithMsgType:(unsigned int)type;
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

static NSString* getTimeStringFromTimestamp(unsigned int timestamp) {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd\nHH:mm:ss"];
    return [formatter stringFromDate:date];
}

static BOOL isMessageTimeEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kMessageTimeEnabledKey];
}

static BOOL isPreventRevokeEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kPreventRevokeEnabledKey];
}

static BOOL isGameCheatEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kGameCheatEnabledKey];
}

static BOOL isFriendsCountEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kFriendsCountEnabledKey];
}

static BOOL isWalletBalanceEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kWalletBalanceEnabledKey];
}

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
            return [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        }
        return contact.m_nsNickName ?: contact.m_nsUsrName;
    } else {
        if (contact.m_nsRemark.length > 0) return contact.m_nsRemark;
        if (contact.m_nsNickName.length > 0) return contact.m_nsNickName;
        return contact.m_nsUsrName ?: @"对方";
    }
}

static NSString* formatTimeString(unsigned int timestamp) {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    return [formatter stringFromDate:date];
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

@implementation AvatarSettingsViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"头像设置";
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _settings = @[@"隐藏对方头像", @"隐藏自己头像"];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _settings.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *cellTitle = _settings[indexPath.row];
    cell.textLabel.text = cellTitle;
    UISwitch *switchView = [[UISwitch alloc] init];
    if (indexPath.row == 0) {
        switchView.on = [defaults boolForKey:kHideOtherAvatarKey];
        [switchView addTarget:self action:@selector(hideOtherAvatarChanged:) forControlEvents:UIControlEventValueChanged];
    } else {
        switchView.on = [defaults boolForKey:kHideSelfAvatarKey];
        [switchView addTarget:self action:@selector(hideSelfAvatarChanged:) forControlEvents:UIControlEventValueChanged];
    }
    cell.accessoryView = switchView;
    return cell;
}
- (void)hideOtherAvatarChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kHideOtherAvatarKey];
}
- (void)hideSelfAvatarChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kHideSelfAvatarKey];
}
@end

@implementation MessageSettingsViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"消息设置";
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _mainSettings = @[@"消息防撤提示", @"隐藏自带时间", @"显示精确时间"];
    _timeSettings = @[@"头像下方", @"使用粗体", @"字体大小"];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    _messageTimeEnabled = [defaults boolForKey:kMessageTimeEnabledKey];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return _mainSettings.count;
    } else {
        return _messageTimeEnabled ? _timeSettings.count : 0;
    }
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 1 && indexPath.row == 2) {
        return 120.0;
    }
    return 44.0;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MainCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MainCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        NSString *cellTitle = _mainSettings[indexPath.row];
        cell.textLabel.text = cellTitle;
        UISwitch *switchView = [[UISwitch alloc] init];
        if (indexPath.row == 0) {
            switchView.on = [defaults boolForKey:kPreventRevokeEnabledKey];
            [switchView addTarget:self action:@selector(preventRevokeChanged:) forControlEvents:UIControlEventValueChanged];
        } else if (indexPath.row == 1) {
            switchView.on = [defaults boolForKey:kHideChatTimeLabelKey];
            [switchView addTarget:self action:@selector(hideChatTimeLabelChanged:) forControlEvents:UIControlEventValueChanged];
        } else {
            switchView.on = [defaults boolForKey:kMessageTimeEnabledKey];
            [switchView addTarget:self action:@selector(messageTimeEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        }
        cell.accessoryView = switchView;
        return cell;
    } else {
        if (indexPath.row == 0 || indexPath.row == 1) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TimeSwitchCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"TimeSwitchCell"];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
            }
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSString *cellTitle = _timeSettings[indexPath.row];
            cell.textLabel.text = cellTitle;
            UISwitch *switchView = [[UISwitch alloc] init];
            if (indexPath.row == 0) {
                switchView.on = [defaults boolForKey:kMessageTimeShowBelowAvatarKey];
                [switchView addTarget:self action:@selector(belowAvatarChanged:) forControlEvents:UIControlEventValueChanged];
            } else {
                switchView.on = [defaults boolForKey:kMessageTimeBoldFontKey];
                [switchView addTarget:self action:@selector(boldFontChanged:) forControlEvents:UIControlEventValueChanged];
            }
            cell.accessoryView = switchView;
            return cell;
        } else {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FontSizeCell"];
            if (!cell) {
                cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"FontSizeCell"];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                cell.backgroundColor = [UIColor clearColor];
                UILabel *sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 10, 200, 30)];
                sizeLabel.text = @"字体大小";
                sizeLabel.tag = 100;
                [cell.contentView addSubview:sizeLabel];
                UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(20, 45, cell.contentView.frame.size.width - 40, 30)];
                slider.minimumValue = 5.0;
                slider.maximumValue = 20.0;
                slider.tag = 101;
                [slider addTarget:self action:@selector(fontSizeChanged:) forControlEvents:UIControlEventValueChanged];
                [cell.contentView addSubview:slider];
                UILabel *previewLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 80, cell.contentView.frame.size.width - 40, 30)];
                previewLabel.text = @"预览文本 12:34:56";
                previewLabel.textAlignment = NSTextAlignmentCenter;
                previewLabel.textColor = [UIColor colorWithWhite:0.5 alpha:0.8];
                previewLabel.tag = 102;
                [cell.contentView addSubview:previewLabel];
            }
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            CGFloat currentSize = [defaults floatForKey:kMessageTimeFontSizeKey];
            if (currentSize == 0) currentSize = kDefaultFontSize;
            BOOL boldFont = [defaults boolForKey:kMessageTimeBoldFontKey];
            UISlider *slider = (UISlider *)[cell.contentView viewWithTag:101];
            UILabel *previewLabel = (UILabel *)[cell.contentView viewWithTag:102];
            if (slider) {
                slider.value = currentSize;
            }
            if (previewLabel) {
                if (boldFont) {
                    previewLabel.font = [UIFont boldSystemFontOfSize:currentSize];
                } else {
                    previewLabel.font = [UIFont systemFontOfSize:currentSize];
                }
            }
            return cell;
        }
    }
}
- (void)messageTimeEnabledChanged:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.isOn forKey:kMessageTimeEnabledKey];
    [defaults synchronize];
    _messageTimeEnabled = sender.isOn;
    NSIndexSet *sectionSet = [NSIndexSet indexSetWithIndex:1];
    [self.tableView reloadSections:sectionSet withRowAnimation:UITableViewRowAnimationFade];
}
- (void)preventRevokeChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kPreventRevokeEnabledKey];
}
- (void)hideChatTimeLabelChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kHideChatTimeLabelKey];
}
- (void)belowAvatarChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kMessageTimeShowBelowAvatarKey];
    [self.tableView reloadData];
}
- (void)boldFontChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kMessageTimeBoldFontKey];
    [self.tableView reloadData];
}
- (void)fontSizeChanged:(UISlider *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setFloat:sender.value forKey:kMessageTimeFontSizeKey];
    [defaults synchronize];
    for (UITableViewCell *cell in self.tableView.visibleCells) {
        if ([cell.reuseIdentifier isEqualToString:@"FontSizeCell"]) {
            UILabel *previewLabel = (UILabel *)[cell.contentView viewWithTag:102];
            BOOL boldFont = [defaults boolForKey:kMessageTimeBoldFontKey];
            if (previewLabel) {
                if (boldFont) {
                    previewLabel.font = [UIFont boldSystemFontOfSize:sender.value];
                } else {
                    previewLabel.font = [UIFont systemFontOfSize:sender.value];
                }
            }
            break;
        }
    }
}
@end

@implementation GameSettingsViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"娱乐功能";
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _settings = @[@"骰子猜拳控制", @"好友数量自定义", @"好友数量输入框", @"钱包余额自定义", @"钱包余额输入框"];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL friendsCountEnabled = [defaults boolForKey:kFriendsCountEnabledKey];
    BOOL walletBalanceEnabled = [defaults boolForKey:kWalletBalanceEnabledKey];
    int rowCount = 1;
    rowCount += 1;
    if (friendsCountEnabled) {
        rowCount += 1;
    }
    rowCount += 1;
    if (walletBalanceEnabled) {
        rowCount += 1;
    }
    return rowCount;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL friendsCountEnabled = [defaults boolForKey:kFriendsCountEnabledKey];
    BOOL walletBalanceEnabled = [defaults boolForKey:kWalletBalanceEnabledKey];
    int rowIndex = indexPath.row;
    if (rowIndex == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"GameCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"GameCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        NSString *cellTitle = _settings[0];
        cell.textLabel.text = cellTitle;
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [defaults boolForKey:kGameCheatEnabledKey];
        [switchView addTarget:self action:@selector(gameCheatEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
        return cell;
    }
    rowIndex -= 1;
    if (rowIndex == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FriendsCountSwitchCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"FriendsCountSwitchCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        cell.textLabel.text = @"好友数量自定义";
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = friendsCountEnabled;
        [switchView addTarget:self action:@selector(friendsCountEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
        return cell;
    }
    rowIndex -= 1;
    if (friendsCountEnabled && rowIndex == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FriendsCountInputCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"FriendsCountInputCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor clearColor];
            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(20, 7, self.view.frame.size.width - 140, 30)];
            textField.borderStyle = UITextBorderStyleRoundedRect;
            textField.placeholder = @"输入好友数量（如：999）";
            textField.keyboardType = UIKeyboardTypeNumberPad;
            textField.delegate = self;
            textField.clearButtonMode = UITextFieldViewModeWhileEditing;
            [cell.contentView addSubview:textField];
            _friendsCountField = textField;
            UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
            confirmButton.frame = CGRectMake(self.view.frame.size.width - 110, 7, 80, 30);
            [confirmButton setTitle:@"确认" forState:UIControlStateNormal];
            [confirmButton addTarget:self action:@selector(friendsCountConfirmTapped:) forControlEvents:UIControlEventTouchUpInside];
            [cell.contentView addSubview:confirmButton];
            _friendsCountConfirmButton = confirmButton;
            NSString *friendsCountValue = [defaults objectForKey:kFriendsCountValueKey];
            if (friendsCountValue && [friendsCountValue length] > 0) {
                textField.text = friendsCountValue;
            }
        }
        return cell;
    }
    if (friendsCountEnabled) {
        rowIndex -= 1;
    }
    if (rowIndex == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WalletBalanceSwitchCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"WalletBalanceSwitchCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        cell.textLabel.text = @"钱包余额自定义";
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = walletBalanceEnabled;
        [switchView addTarget:self action:@selector(walletBalanceEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
        return cell;
    }
    rowIndex -= 1;
    if (walletBalanceEnabled && rowIndex == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WalletBalanceInputCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"WalletBalanceInputCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor clearColor];
            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(20, 7, self.view.frame.size.width - 140, 30)];
            textField.borderStyle = UITextBorderStyleRoundedRect;
            textField.placeholder = @"输入余额（如：9999.99）";
            textField.keyboardType = UIKeyboardTypeDecimalPad;
            textField.delegate = self;
            textField.clearButtonMode = UITextFieldViewModeWhileEditing;
            [cell.contentView addSubview:textField];
            _walletBalanceField = textField;
            UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
            confirmButton.frame = CGRectMake(self.view.frame.size.width - 110, 7, 80, 30);
            [confirmButton setTitle:@"确认" forState:UIControlStateNormal];
            [confirmButton addTarget:self action:@selector(walletBalanceConfirmTapped:) forControlEvents:UIControlEventTouchUpInside];
            [cell.contentView addSubview:confirmButton];
            _walletBalanceConfirmButton = confirmButton;
            NSString *walletBalanceValue = [defaults objectForKey:kWalletBalanceValueKey];
            if (walletBalanceValue && [walletBalanceValue length] > 0) {
                textField.text = walletBalanceValue;
            }
        }
        return cell;
    }
    return [[UITableViewCell alloc] init];
}
- (void)gameCheatEnabledChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kGameCheatEnabledKey];
}
- (void)friendsCountEnabledChanged:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.isOn forKey:kFriendsCountEnabledKey];
    [defaults synchronize];
    [self.tableView reloadData];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                        CFSTR("com.dd.assistant.settings_changed"),
                                        NULL,
                                        NULL,
                                        YES);
}
- (void)walletBalanceEnabledChanged:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.isOn forKey:kWalletBalanceEnabledKey];
    [defaults synchronize];
    [self.tableView reloadData];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                        CFSTR("com.dd.assistant.settings_changed"),
                                        NULL,
                                        NULL,
                                        YES);
}
- (void)friendsCountConfirmTapped:(UIButton *)sender {
    if (_friendsCountField) {
        [_friendsCountField resignFirstResponder];
        [self saveFriendsCountValue];
    }
}
- (void)walletBalanceConfirmTapped:(UIButton *)sender {
    if (_walletBalanceField) {
        [_walletBalanceField resignFirstResponder];
        [self saveWalletBalanceValue];
    }
}
- (void)saveFriendsCountValue {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *text = _friendsCountField.text;
    if (text && [text length] > 0) {
        [defaults setObject:text forKey:kFriendsCountValueKey];
        [defaults setObject:text forKey:kWCFriendsCountReplacementKey];
    } else {
        [defaults removeObjectForKey:kFriendsCountValueKey];
        [defaults removeObjectForKey:kWCFriendsCountReplacementKey];
    }
    [defaults synchronize];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                        CFSTR("com.dd.assistant.settings_changed"),
                                        NULL,
                                        NULL,
                                        YES);
}
- (void)saveWalletBalanceValue {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *text = _walletBalanceField.text;
    if (text && [text length] > 0) {
        [defaults setObject:text forKey:kWalletBalanceValueKey];
        [defaults setObject:text forKey:kWCWalletBalanceReplacementKey];
    } else {
        [defaults removeObjectForKey:kWalletBalanceValueKey];
        [defaults removeObjectForKey:kWCWalletBalanceReplacementKey];
    }
    [defaults synchronize];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                        CFSTR("com.dd.assistant.settings_changed"),
                                        NULL,
                                        NULL,
                                        YES);
}
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}
- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField == _friendsCountField) {
        [self saveFriendsCountValue];
    } 
    else if (textField == _walletBalanceField) {
        [self saveWalletBalanceValue];
    }
}
- (void)keyboardWillShow:(NSNotification *)notification {
    CGRect keyboardFrame = [[notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = keyboardFrame.size.height;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0, 0, keyboardHeight, 0);
    self.tableView.contentInset = contentInsets;
    self.tableView.scrollIndicatorInsets = contentInsets;
}
- (void)keyboardWillHide:(NSNotification *)notification {
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.tableView.contentInset = contentInsets;
    self.tableView.scrollIndicatorInsets = contentInsets;
}
@end

@implementation CSTouchTrailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"触摸轨迹";
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(screenCaptureDidChange)
                                               name:UIScreenCapturedDidChangeNotification
                                             object:nil];
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL isTrailEnabled = [defaults boolForKey:kTouchTrailKey];
    
    return isTrailEnabled ? 3 : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (indexPath.row == 0) {
        cell.textLabel.text = @"启用触摸轨迹";
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [defaults boolForKey:kTouchTrailKey];
        [switchView addTarget:self action:@selector(trailEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    } else if (indexPath.row == 1) {
        cell.textLabel.text = @"仅在录屏时显示";
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [defaults boolForKey:kTouchTrailOnlyWhenRecordingKey];
        [switchView addTarget:self action:@selector(onlyWhenRecordingChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    } else if (indexPath.row == 2) {
        cell.textLabel.text = @"拖尾效果";
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [defaults boolForKey:kTouchTrailTailEnabledKey];
        [switchView addTarget:self action:@selector(tailEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    }
    
    return cell;
}

- (void)trailEnabledChanged:(UISwitch *)sender {
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
    
    [self.tableView reloadData];
}

- (void)onlyWhenRecordingChanged:(UISwitch *)sender {
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
}

- (void)tailEnabledChanged:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.isOn forKey:kTouchTrailTailEnabledKey];
    [defaults synchronize];
}

@end

@implementation DDAssistantSettingsViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = PLUGIN_NAME;
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _sections = @[
        @[@"头像设置"],
        @[@"消息设置"],
        @[@"娱乐功能"],
        @[@"触摸轨迹"]
    ];
}
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return _sections.count;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_sections[section] count];
}
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return 20.0;
    }
    return 10.0;
}
- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, [self tableView:tableView heightForHeaderInSection:section])];
    headerView.backgroundColor = [UIColor clearColor];
    return headerView;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    NSString *cellTitle = _sections[indexPath.section][indexPath.row];
    cell.textLabel.text = cellTitle;
    return cell;
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    UIViewController *targetVC = nil;
    if (indexPath.section == 0) {
        targetVC = [[AvatarSettingsViewController alloc] init];
    } else if (indexPath.section == 1) {
        targetVC = [[MessageSettingsViewController alloc] init];
    } else if (indexPath.section == 2) {
        targetVC = [[GameSettingsViewController alloc] init];
    } else if (indexPath.section == 3) {
        targetVC = [[CSTouchTrailViewController alloc] init];
    }
    if (targetVC) {
        [self.navigationController pushViewController:targetVC animated:YES];
    }
}
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

%hook CommonMessageViewModel
- (BOOL)isShowHeadImage {
    BOOL original = %orig;
    if (!original) return original;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL hideOther = [defaults boolForKey:kHideOtherAvatarKey];
    BOOL hideSelf = [defaults boolForKey:kHideSelfAvatarKey];
    BOOL isSender = [self isSender];
    if (isSender && hideSelf) return NO;
    if (!isSender && hideOther) return NO;
    return original;
}
%end

%hook ChatTimeCellView
- (id)initWithViewModel:(id)arg1 {
    id view = %orig;
    if (view) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults boolForKey:kHideChatTimeLabelKey]) {
            [(UIView *)view setHidden:YES];
        }
    }
    return view;
}
%end

%hook ChatTimeViewModel
- (CGSize)measure:(CGSize)arg1 {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:kHideChatTimeLabelKey]) {
        return CGSizeMake(arg1.width, 0);
    }
    return %orig(arg1);
}
%end

%hook CMessageMgr
- (void)AddEmoticonMsg:(NSString *)msg MsgWrap:(CMessageWrap *)msgWrap {
    if (isGameCheatEnabled() && [msgWrap m_uiMessageType] == 47 && ([msgWrap m_uiGameType] == 2 || [msgWrap m_uiGameType] == 1)) {
        NSString *title = [msgWrap m_uiGameType] == 1 ? @"请选择石头/剪刀/布" : @"请选择点数";
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"请选择" message:title preferredStyle:UIAlertControllerStyleActionSheet];
        NSArray *actions;
        if ([msgWrap m_uiGameType] == 1) {
            actions = @[@"剪刀", @"石头", @"布"];
        } else {
            actions = @[@"1", @"2", @"3", @"4", @"5", @"6"];
        }
        for (int i = 0; i < actions.count; i++) {
            NSString *actionTitle = actions[i];
            UIAlertAction* action = [UIAlertAction actionWithTitle:actionTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                unsigned int gameContent;
                if ([msgWrap m_uiGameType] == 1) {
                    gameContent = i + 1;
                } else {
                    gameContent = i + 4;
                }
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            [alert addAction:action];
        }
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alert addAction:cancelAction];
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
            UIWindowScene *windowScene = nil;
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                    windowScene = (UIWindowScene *)scene;
                    break;
                }
            }
            UIWindow *window = windowScene.windows.firstObject;
            alert.popoverPresentationController.sourceView = window;
            alert.popoverPresentationController.sourceRect = CGRectMake(window.frame.size.width / 2, window.frame.size.height / 2, 0, 0);
            alert.popoverPresentationController.permittedArrowDirections = 0;
        }
        UIViewController *topController = nil;
        UIWindowScene *windowScene = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                windowScene = (UIWindowScene *)scene;
                break;
            }
        }
        if (windowScene) {
            UIWindow *window = windowScene.windows.firstObject;
            topController = window.rootViewController;
            while (topController.presentedViewController) {
                topController = topController.presentedViewController;
            }
            [topController presentViewController:alert animated:true completion:nil];
        }
        return;
    }
    %orig(msg, msgWrap);
}
%end

%hook CommonMessageCellView
- (id)initWithViewModel:(id)arg1 {
    id view = %orig;
    if (view && isMessageTimeEnabled()) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        CGFloat fontSize = [defaults floatForKey:kMessageTimeFontSizeKey];
        if (fontSize == 0) fontSize = kDefaultFontSize;
        UILabel *timeLabel = [[UILabel alloc] init];
        BOOL useBoldFont = [defaults boolForKey:kMessageTimeBoldFontKey];
        if (useBoldFont) {
            timeLabel.font = [UIFont boldSystemFontOfSize:fontSize];
        } else {
            timeLabel.font = [UIFont systemFontOfSize:fontSize];
        }
        timeLabel.textColor = [UIColor colorWithWhite:0.5 alpha:0.8];
        timeLabel.backgroundColor = [UIColor clearColor];
        timeLabel.numberOfLines = 0;
        timeLabel.textAlignment = NSTextAlignmentCenter;
        timeLabel.clipsToBounds = YES;
        timeLabel.frame = CGRectMake(0, 0, 50, 20);
        setTimeView(self, timeLabel);
    }
    return view;
}
- (void)updateNodeStatus {
    %orig;
    if (!isMessageTimeEnabled()) {
        UIView *timeView = getTimeView(self);
        if (timeView) timeView.hidden = YES;
        return;
    }
    CommonMessageViewModel *viewModel = [self viewModel];
    if (!viewModel) return;
    NSString *messageTime = getMessageTime(viewModel);
    if (messageTime.length > 0) {
        UILabel *timeLabel = (UILabel *)getTimeView(self);
        if (!timeLabel) return;
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        CGFloat fontSize = [defaults floatForKey:kMessageTimeFontSizeKey];
        if (fontSize == 0) fontSize = kDefaultFontSize;
        BOOL useBoldFont = [defaults boolForKey:kMessageTimeBoldFontKey];
        if (useBoldFont) {
            timeLabel.font = [UIFont boldSystemFontOfSize:fontSize];
        } else {
            timeLabel.font = [UIFont systemFontOfSize:fontSize];
        }
        timeLabel.hidden = NO;
        timeLabel.text = messageTime;
        CGFloat padding = 10.0;
        CGSize constraintSize = CGSizeMake(kMaxLabelWidth - padding, CGFLOAT_MAX);
        CGSize textSize = [messageTime boundingRectWithSize:constraintSize
                                                   options:NSStringDrawingUsesLineFragmentOrigin
                                                attributes:@{NSFontAttributeName: timeLabel.font}
                                                   context:nil].size;
        CGFloat labelWidth = textSize.width + padding;
        if (labelWidth > kMaxLabelWidth) labelWidth = kMaxLabelWidth;
        if (labelWidth < 30) labelWidth = 30;
        CGFloat labelHeight = textSize.height + 8.0;
        timeLabel.frame = CGRectMake(0, 0, labelWidth, labelHeight);
        CGFloat centerX = 0, centerY = 0;
        BOOL isSender = [viewModel isSender];
        BOOL showBelowAvatar = [[NSUserDefaults standardUserDefaults] boolForKey:kMessageTimeShowBelowAvatarKey];
        if (showBelowAvatar) {
            UIView *headImageView = nil;
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
                UIView *contentView = [self valueForKey:@"m_contentView"];
                if (contentView) {
                    if (isSender) {
                        centerX = CGRectGetMinX(contentView.frame) - 1 - timeLabel.bounds.size.width / 2;
                    } else {
                        centerX = CGRectGetMaxX(contentView.frame) + 1 + timeLabel.bounds.size.width / 2;
                    }
                    centerY = CGRectGetMaxY(contentView.frame) - timeLabel.bounds.size.height / 2;
                }
            }
        } else {
            UIView *contentView = [self valueForKey:@"m_contentView"];
            if (contentView) {
                if (isSender) {
                    centerX = CGRectGetMinX(contentView.frame) - 1 - timeLabel.bounds.size.width / 2;
                } else {
                    centerX = CGRectGetMaxX(contentView.frame) + 1 + timeLabel.bounds.size.width / 2;
                }
                centerY = CGRectGetMaxY(contentView.frame) - timeLabel.bounds.size.height / 2;
            } else {
                UIView *bgView = [self getBgImageView];
                if (bgView) {
                    if (isSender) {
                        centerX = CGRectGetMinX(bgView.frame) - 1 - timeLabel.bounds.size.width / 2;
                    } else {
                        centerX = CGRectGetMaxX(bgView.frame) + 1 + timeLabel.bounds.size.width / 2;
                    }
                    centerY = CGRectGetMaxY(bgView.frame) - timeLabel.bounds.size.height / 2;
                }
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
    if (!isMessageTimeEnabled()) return cell;
    Class ChatTableViewCellClass = objc_getClass("ChatTableViewCell");
    if (ChatTableViewCellClass && [cell isKindOfClass:ChatTableViewCellClass]) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            ChatTableViewCell *chatCell = (ChatTableViewCell *)cell;
            CommonMessageCellView *cellView = [chatCell cellView];
            if (!cellView) return;
            CommonMessageViewModel *viewModel = [cellView viewModel];
            if (!viewModel) return;
            if ([viewModel respondsToSelector:@selector(messageWrap)]) {
                CMessageWrap *messageWrap = [viewModel messageWrap];
                if (messageWrap && [messageWrap respondsToSelector:@selector(m_uiCreateTime)]) {
                    unsigned int createTime = [messageWrap m_uiCreateTime];
                    if (getMessageTime(viewModel) == nil) {
                        NSString *timeStr = getTimeStringFromTimestamp(createTime);
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
    if (!isPreventRevokeEnabled() || !msgWrap || !msgWrap.m_nsContent) {
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
    unsigned int tipTime = originalMsg.m_uiCreateTime + 1;
    NSString *timeString = formatTimeString(originalMsg.m_uiCreateTime);
    NSString *tipContent = [NSString stringWithFormat:@"%@ 已拦截 %@ 撤回的消息", timeString, displayName];
    CMessageWrap *tipMessage = [[%c(CMessageWrap) alloc] initWithMsgType:10000];
    [tipMessage setM_nsFromUsr:originalMsg.m_nsFromUsr];
    [tipMessage setM_nsToUsr:originalMsg.m_nsToUsr];
    [tipMessage setM_nsContent:tipContent];
    [tipMessage setM_uiStatus:4];
    [tipMessage setM_uiCreateTime:tipTime];
    [messageMgr AddLocalMsg:session MsgWrap:tipMessage fixTime:YES NewMsgArriveNotify:NO];
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

static NSMutableDictionary *touchViews = nil;
static NSMutableDictionary *touchTailViews = nil;
static NSMutableDictionary *touchLastPointTimes = nil;
static BOOL isTrailEnabled = NO;

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
            kHideOtherAvatarKey: @NO,
            kHideSelfAvatarKey: @NO,
            kHideChatTimeLabelKey: @NO,
            kGameCheatEnabledKey: @NO,
            kMessageTimeEnabledKey: @NO,
            kPreventRevokeEnabledKey: @NO,
            kMessageTimeFontSizeKey: @(kDefaultFontSize),
            kMessageTimeBoldFontKey: @YES,
            kMessageTimeShowBelowAvatarKey: @YES,
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
                    if ([key isEqualToString:kMessageTimeFontSizeKey]) {
                        [defaults setFloat:[value floatValue] forKey:key];
                    } else {
                        [defaults setBool:[value boolValue] forKey:key];
                    }
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