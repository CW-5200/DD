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

static CGFloat const kDefaultFontSize = 7.0f;
static CGFloat const kMaxLabelWidth = 90.0f;

static BOOL g_hasPluginsMgr = NO;

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
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

static char kMessageTimeKey;
static char kTimeViewKey;

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

@interface AvatarSettingsViewController : UITableViewController {
    NSArray *_settings;
}
@end

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

@interface MessageSettingsViewController : UITableViewController {
    NSArray *_mainSettings;
    NSArray *_timeSettings;
    BOOL _messageTimeEnabled;
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

@interface GameSettingsViewController : UITableViewController {
    NSArray *_settings;
}
@end

@implementation GameSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"娱乐功能";
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    
    _settings = @[@"骰子猜拳控制"];
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
    switchView.on = [defaults boolForKey:kGameCheatEnabledKey];
    [switchView addTarget:self action:@selector(gameCheatEnabledChanged:) forControlEvents:UIControlEventValueChanged];
    
    cell.accessoryView = switchView;
    
    return cell;
}

- (void)gameCheatEnabledChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kGameCheatEnabledKey];
}

@end

@interface DDAssistantSettingsViewController : UITableViewController {
    NSArray *_sections;
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
        @[@"娱乐功能"]
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
    }
    
    if (targetVC) {
        [self.navigationController pushViewController:targetVC animated:YES];
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
            kMessageTimeShowBelowAvatarKey: @YES
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