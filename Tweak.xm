#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

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
static NSString * const kCustomStepsEnabledKey = @"com.dd.assistant.custom.steps.enabled";
static NSString * const kCustomStepsValueKey = @"com.dd.assistant.custom.steps.value";
static NSString * const kLastStepsUpdateDateKey = @"com.dd.assistant.last.steps.update.date";
static NSString * const kTouchTrailKey = @"com.wechat.tweak.touch.trail.enabled";
static NSString * const kTouchTrailOnlyWhenRecordingKey = @"com.wechat.tweak.touch.trail.only.when.recording";
static NSString * const kTouchTrailDisplayStateKey = @"com.wechat.tweak.touch.trail.display.state";
static NSString * const kTouchTrailTailEnabledKey = @"com.wechat.tweak.touch.trail.tail.enabled";
static NSString * const kLocationSpoofingEnabledKey = @"com.dd.assistant.location.spoofing.enabled";
static NSString * const kLatitudeKey = @"com.dd.assistant.location.latitude";
static NSString * const kLongitudeKey = @"com.dd.assistant.location.longitude";

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
static BOOL gCustomStepsEnabled = NO;
static NSInteger gCustomStepsValue = 8888;
static NSDate *gLastStepsUpdateDate = nil;
static BOOL gLocationSpoofingEnabled = NO;
static double gLatitude = 39.9042;
static double gLongitude = 116.4074;
static BOOL gLocationTemporarilyDisabled = NO;
static BOOL gLocationOriginalEnabledState = NO;

@interface CContact : NSObject
@property (copy, nonatomic) NSString *m_nsUsrName;
@property (copy, nonatomic) NSString *m_nsNickName;
@property (copy, nonatomic) NSString *m_nsRemark;
@end

@interface CMessageWrap : NSObject
@property (nonatomic) unsigned int m_uiCreateTime;
@property (nonatomic) unsigned int m_uiMessageType;
@property (nonatomic) unsigned int m_uiGameType;
@property (nonatomic) unsigned int m_uiGameContent;
@property (copy, nonatomic) NSString *m_nsEmoticonMD5;
@property (copy, nonatomic) NSString *m_nsContent;
@property (copy, nonatomic) NSString *m_nsFromUsr;
@property (copy, nonatomic) NSString *m_nsToUsr;
@property (nonatomic) unsigned int m_uiStatus;
@property (readonly, nonatomic) BOOL IsImgMsg;
@property (readonly, nonatomic) BOOL IsVideoMsg;
@property (readonly, nonatomic) BOOL IsVoiceMsg;
@property (readonly, nonatomic) BOOL IsTextMsg;
@property (readonly, nonatomic) unsigned int m_uiMesLocalID;
- (instancetype)initWithMsgType:(unsigned int)type;
@end

@interface WCActionSheet : NSObject
- (id)initWithTitle:(NSString *)title cancelButtonTitle:(NSString *)cancelButtonTitle;
- (id)initWithTitle:(NSString *)title;
- (id)init;
- (void)addButtonWithTitle:(NSString *)title eventAction:(void (^)(void))eventAction;
- (void)showInView:(UIView *)view;
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

@interface BaseMsgContentViewController : UIViewController
- (CContact *)GetContact;
@end

@interface CommonMessageViewModel : NSObject
- (BOOL)isSender;
- (BOOL)isShowHeadImage;
@property (retain, nonatomic) id messageWrap;
@end

@interface TextMessageSubViewModel : CommonMessageViewModel
@property (readonly, nonatomic) CommonMessageViewModel *parentModel;
@property (readonly, nonatomic) NSArray *subViewModels;
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
@property (readonly, nonatomic) CommonMessageViewModel *viewModel;
@property (nonatomic, readonly) UIView *m_contentView;
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
@property (readonly, nonatomic) MMServiceCenter *serviceCenter;
@property (readonly, nonatomic) NSString *userName;
+ (id)activeUserContext;
- (id)getService:(Class)cls;
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

@interface WCDeviceStepObject : NSObject
- (unsigned int)m7StepCount;
- (unsigned int)hkStepCount;
@end

@interface WCDataItem : NSObject
- (unsigned int)stepCount;
@end

static NSString *parseParam(NSString *content, NSString *begin, NSString *end) {
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

static NSString *getDisplayName(CContact *contact, BOOL isGroupChat, NSString *revokeContent) {
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

static NSString *formatTimeString(unsigned int timestamp) {
    static NSDateFormatter *formatter;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        formatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
    });
    return [formatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:timestamp]];
}

static NSString *getMessageContentAdapter(CMessageWrap *msgWrap) {
    switch (msgWrap.m_uiMessageType) {
        case 1: {
            NSString *content = msgWrap.m_nsContent;
            if (content.length > 30) {
                NSString *truncated = [content substringToIndex:27];
                return [NSString stringWithFormat:@"\"%@...\"", truncated];
            }
            return [NSString stringWithFormat:@"\"%@\"", content];
        }
        case 3: return @"\"图片\"";
        case 34: return @"\"语音\"";
        case 43: return @"\"视频\"";
        case 47: return @"\"表情\"";
        case 49: return @"\"链接\"";
        case 50: return @"\"视频号\"";
        case 62: return @"\"直播\"";
        default: return [NSString stringWithFormat:@"\"类型%d\"", (int)msgWrap.m_uiMessageType];
    }
}

static NSString *getDoubleLineTimeString(unsigned int timestamp) {
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:timestamp];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-MM-dd\nHH:mm:ss"];
    return [formatter stringFromDate:date];
}

static BOOL isToday(NSDate *date) {
    if (!date) return NO;
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
    NSDateComponents *todayComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:[NSDate date]];
    return (dateComponents.year == todayComponents.year &&
            dateComponents.month == todayComponents.month &&
            dateComponents.day == todayComponents.day);
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

static BOOL isCustomStepsEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kCustomStepsEnabledKey];
}

static NSInteger getCustomStepsValue() {
    NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:kCustomStepsValueKey];
    return value > 0 ? value : 8888;
}

static BOOL isLocationSpoofingEnabled() {
    return gLocationSpoofingEnabled && !gLocationTemporarilyDisabled;
}

static void enableLocationTemporaryDisable() {
    if (!gLocationTemporarilyDisabled) {
        gLocationOriginalEnabledState = gLocationSpoofingEnabled;
        gLocationTemporarilyDisabled = YES;
    }
}

static void disableLocationTemporaryDisable() {
    if (gLocationTemporarilyDisabled) {
        gLocationTemporarilyDisabled = NO;
    }
}

static CLLocation *getCurrentFakeLocation() {
    if (gLocationTemporarilyDisabled || !gLocationSpoofingEnabled) {
        return nil;
    }
    
    return [[CLLocation alloc]
        initWithCoordinate:CLLocationCoordinate2DMake(gLatitude, gLongitude)
        altitude:0
        horizontalAccuracy:5.0
        verticalAccuracy:3.0
        course:0.0
        speed:0.0
        timestamp:[NSDate date]];
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

static void loadAllSettings() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    gFriendsCountEnabled = [defaults boolForKey:kFriendsCountEnabledKey];
    NSString *friendsCountValue = [defaults objectForKey:kFriendsCountValueKey];
    gFriendsCountReplacement = (friendsCountValue && friendsCountValue.length > 0) ? friendsCountValue : nil;
    
    gWalletBalanceEnabled = [defaults boolForKey:kWalletBalanceEnabledKey];
    NSString *walletBalanceValue = [defaults objectForKey:kWalletBalanceValueKey];
    gWalletBalanceReplacement = (walletBalanceValue && walletBalanceValue.length > 0) ? walletBalanceValue : nil;
    
    gCustomStepsEnabled = [defaults boolForKey:kCustomStepsEnabledKey];
    NSInteger stepsValue = [defaults integerForKey:kCustomStepsValueKey];
    if (stepsValue == 0) {
        stepsValue = 8888;
        [defaults setInteger:stepsValue forKey:kCustomStepsValueKey];
        [defaults synchronize];
    }
    gCustomStepsValue = stepsValue;
    
    gLastStepsUpdateDate = [defaults objectForKey:kLastStepsUpdateDateKey];
    if (!gLastStepsUpdateDate) {
        gLastStepsUpdateDate = [NSDate date];
        [defaults setObject:gLastStepsUpdateDate forKey:kLastStepsUpdateDateKey];
        [defaults synchronize];
    }
    
    gLocationSpoofingEnabled = [defaults boolForKey:kLocationSpoofingEnabledKey];
    gLatitude = [defaults doubleForKey:kLatitudeKey];
    gLongitude = [defaults doubleForKey:kLongitudeKey];
    
    if (gLatitude == 0 && gLongitude == 0) {
        gLatitude = 39.9042;
        gLongitude = 116.4074;
    }
}

@interface LocationMapViewController : UIViewController <UISearchBarDelegate, MKMapViewDelegate>
@property (strong, nonatomic) MKMapView *mapView;
@property (strong, nonatomic) UISearchBar *searchBar;
@property (strong, nonatomic) CLGeocoder *geocoder;
@property (copy, nonatomic) void (^completionHandler)(CLLocationCoordinate2D coordinate);
@end

@implementation LocationMapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"选择位置";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    enableLocationTemporaryDisable();
    
    [self setupNavigationBar];
    [self setupUI];
    [self setupMap];
    
    self.geocoder = [[CLGeocoder alloc] init];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    disableLocationTemporaryDisable();
}

- (void)dealloc {
    disableLocationTemporaryDisable();
}

- (void)setupNavigationBar {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"返回" style:UIBarButtonItemStyleDone target:self action:@selector(closeMapSelection)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"确认" style:UIBarButtonItemStyleDone target:self action:@selector(confirmMapSelection)];
}

- (void)setupUI {
    UIView *searchContainer = [[UIView alloc] init];
    searchContainer.backgroundColor = [UIColor clearColor];
    
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.layer.cornerRadius = 12;
    blurView.layer.masksToBounds = YES;
    
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索地点或输入坐标（格式：纬度,经度）";
    self.searchBar.searchBarStyle = UISearchBarStyleDefault;
    self.searchBar.barTintColor = [UIColor clearColor];
    self.searchBar.backgroundImage = [[UIImage alloc] init];
    
    UITextField *searchTextField = self.searchBar.searchTextField;
    searchTextField.backgroundColor = [UIColor secondarySystemBackgroundColor];
    searchTextField.layer.cornerRadius = 10;
    searchTextField.layer.masksToBounds = YES;
    searchTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    
    [blurView.contentView addSubview:self.searchBar];
    [searchContainer addSubview:blurView];
    [self.view addSubview:searchContainer];
    
    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.text = @"长按地图可选择位置";
    hintLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    hintLabel.textAlignment = NSTextAlignmentCenter;
    hintLabel.textColor = [UIColor secondaryLabelColor];
    hintLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:hintLabel];
    
    searchContainer.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [searchContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [searchContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [searchContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [searchContainer.heightAnchor constraintEqualToConstant:52],
        
        [blurView.leadingAnchor constraintEqualToAnchor:searchContainer.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:searchContainer.trailingAnchor],
        [blurView.topAnchor constraintEqualToAnchor:searchContainer.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:searchContainer.bottomAnchor],
        
        [self.searchBar.leadingAnchor constraintEqualToAnchor:blurView.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:blurView.trailingAnchor],
        [self.searchBar.topAnchor constraintEqualToAnchor:blurView.topAnchor],
        [self.searchBar.bottomAnchor constraintEqualToAnchor:blurView.bottomAnchor],
        
        [hintLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],
        [hintLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [hintLabel.heightAnchor constraintEqualToConstant:20]
    ]];
}

- (void)setupMap {
    self.mapView = [[MKMapView alloc] init];
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = NO;
    self.mapView.showsCompass = YES;
    self.mapView.showsScale = YES;
    self.mapView.pointOfInterestFilter = [MKPointOfInterestFilter filterIncludingAllCategories];
    self.mapView.layer.cornerRadius = 12;
    self.mapView.layer.masksToBounds = YES;
    
    [self.view addSubview:self.mapView];
    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [self.mapView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor constant:16],
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.mapView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-40]
    ]];
    
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleMapLongPress:)];
    [self.mapView addGestureRecognizer:longPress];
    
    CLLocationCoordinate2D initialCoord = CLLocationCoordinate2DMake(gLatitude, gLongitude);
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(initialCoord, 1000, 1000);
    [self.mapView setRegion:region animated:YES];
    
    MKPointAnnotation *existingAnnotation = [[MKPointAnnotation alloc] init];
    existingAnnotation.coordinate = initialCoord;
    existingAnnotation.title = @"虚拟位置";
    [self.mapView addAnnotation:existingAnnotation];
}

- (void)closeMapSelection {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)handleMapLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
    
    NSMutableArray *annotationsToRemove = [NSMutableArray array];
    for (id<MKAnnotation> annotation in self.mapView.annotations) {
        if ([annotation.title isEqualToString:@"选择的位置"]) {
            [annotationsToRemove addObject:annotation];
        }
    }
    [self.mapView removeAnnotations:annotationsToRemove];
    
    CGPoint touchPoint = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:touchPoint toCoordinateFromView:self.mapView];
    
    MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
    annotation.coordinate = coordinate;
    annotation.title = @"选择的位置";
    
    CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude longitude:coordinate.longitude];
    [self.geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
        if (!error && placemarks.count > 0) {
            CLPlacemark *placemark = placemarks.firstObject;
            NSString *address = [self formatPlacemarkAddress:placemark];
            annotation.subtitle = address;
            self.searchBar.text = address;
        } else {
            annotation.subtitle = [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
            self.searchBar.text = [NSString stringWithFormat:@"%.6f, %.6f", coordinate.latitude, coordinate.longitude];
        }
    }];
    
    [self.mapView addAnnotation:annotation];
    
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coordinate, 500, 500);
    [self.mapView setRegion:region animated:YES];
    [self.mapView selectAnnotation:annotation animated:YES];
}

- (NSString *)formatPlacemarkAddress:(CLPlacemark *)placemark {
    NSMutableString *address = [NSMutableString string];
    if (placemark.name) [address appendString:placemark.name];
    if (placemark.locality) {
        if (address.length > 0) [address appendString:@", "];
        [address appendString:placemark.locality];
    }
    if (placemark.administrativeArea && ![placemark.administrativeArea isEqualToString:placemark.locality]) {
        if (address.length > 0) [address appendString:@", "];
        [address appendString:placemark.administrativeArea];
    }
    if (placemark.country) {
        if (address.length > 0) [address appendString:@", "];
        [address appendString:placemark.country];
    }
    return address.length > 0 ? address : @"未知地点";
}

- (void)confirmMapSelection {
    MKPointAnnotation *selectedAnnotation = nil;
    for (id<MKAnnotation> annotation in self.mapView.annotations) {
        if ([annotation.title isEqualToString:@"选择的位置"]) {
            selectedAnnotation = (MKPointAnnotation *)annotation;
            break;
        }
    }
    
    if (!selectedAnnotation) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" 
                                                                       message:@"请先在地图上选择一个位置" 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    CLLocationCoordinate2D coordinate = selectedAnnotation.coordinate;
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setDouble:coordinate.latitude forKey:kLatitudeKey];
    [defaults setDouble:coordinate.longitude forKey:kLongitudeKey];
    [defaults setBool:YES forKey:kLocationSpoofingEnabledKey];
    [defaults synchronize];
    
    loadAllSettings();
    
    UINotificationFeedbackGenerator *feedback = [[UINotificationFeedbackGenerator alloc] init];
    [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
    
    if (self.completionHandler) {
        self.completionHandler(coordinate);
    }
    
    [self.navigationController dismissViewControllerAnimated:YES completion:^{
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                            CFSTR("com.dd.assistant.settings_changed"),
                                            NULL,
                                            NULL,
                                            YES);
    }];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) return nil;
    
    static NSString *annotationId = @"customAnnotation";
    MKMarkerAnnotationView *markerView = (MKMarkerAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:annotationId];
    
    if (!markerView) {
        markerView = [[MKMarkerAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:annotationId];
        markerView.canShowCallout = YES;
        markerView.animatesWhenAdded = YES;
        markerView.glyphTintColor = [UIColor whiteColor];
        UIButton *detailButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        markerView.rightCalloutAccessoryView = detailButton;
    } else {
        markerView.annotation = annotation;
    }
    
    if ([annotation.title isEqualToString:@"虚拟位置"]) {
        markerView.markerTintColor = [UIColor systemGreenColor];
        markerView.glyphImage = [UIImage systemImageNamed:@"mappin.circle.fill"];
    } else if ([annotation.title isEqualToString:@"选择的位置"]) {
        markerView.markerTintColor = [UIColor systemBlueColor];
        markerView.glyphImage = [UIImage systemImageNamed:@"mappin"];
    }
    
    return markerView;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control {
    if ([view.annotation isKindOfClass:[MKPointAnnotation class]]) {
        MKPointAnnotation *annotation = (MKPointAnnotation *)view.annotation;
        self.searchBar.text = [NSString stringWithFormat:@"%.6f, %.6f", annotation.coordinate.latitude, annotation.coordinate.longitude];
        [self.searchBar becomeFirstResponder];
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    
    NSString *searchText = searchBar.text;
    if (searchText.length == 0) return;
    
    NSArray *components = [searchText componentsSeparatedByString:@","];
    if (components.count == 2) {
        NSString *latStr = [components[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        NSString *lngStr = [components[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        double lat = [latStr doubleValue];
        double lng = [lngStr doubleValue];
        
        if (lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180) {
            CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(lat, lng);
            [self addSelectedAnnotationAtCoordinate:coordinate withSubtitle:searchText];
            return;
        }
    }
    
    [self.geocoder geocodeAddressString:searchText completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
        if (error) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"搜索失败" 
                                                                           message:@"未找到该地点，请尝试输入坐标格式：纬度,经度" 
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        
        if (placemarks.count > 0) {
            CLPlacemark *placemark = placemarks.firstObject;
            [self addSelectedAnnotationAtCoordinate:placemark.location.coordinate withSubtitle:[self formatPlacemarkAddress:placemark]];
        }
    }];
}

- (void)addSelectedAnnotationAtCoordinate:(CLLocationCoordinate2D)coordinate withSubtitle:(NSString *)subtitle {
    NSMutableArray *annotationsToRemove = [NSMutableArray array];
    for (id<MKAnnotation> annotation in self.mapView.annotations) {
        if ([annotation.title isEqualToString:@"选择的位置"]) {
            [annotationsToRemove addObject:annotation];
        }
    }
    [self.mapView removeAnnotations:annotationsToRemove];
    
    MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
    annotation.coordinate = coordinate;
    annotation.title = @"选择的位置";
    annotation.subtitle = subtitle;
    [self.mapView addAnnotation:annotation];
    
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coordinate, 1000, 1000);
    [self.mapView setRegion:region animated:YES];
    [self.mapView selectAnnotation:annotation animated:YES];
}

@end

@interface MessageSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation MessageSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"消息设置";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 3;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"MessageSettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    UISwitch *switchView = [[UISwitch alloc] init];
    switchView.onTintColor = [UIColor systemBlueColor];
    
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"消息防撤提示";
            switchView.on = [defaults boolForKey:kPreventRevokeEnabledKey];
            [switchView addTarget:self action:@selector(preventRevokeChanged:) forControlEvents:UIControlEventValueChanged];
            break;
        case 1:
            cell.textLabel.text = @"隐藏自带时间";
            switchView.on = [defaults boolForKey:kHideChatTimeLabelKey];
            [switchView addTarget:self action:@selector(hideChatTimeLabelChanged:) forControlEvents:UIControlEventValueChanged];
            break;
        case 2:
            cell.textLabel.text = @"头像时间标签";
            switchView.on = [defaults boolForKey:kMessageTimeBelowAvatarKey];
            [switchView addTarget:self action:@selector(messageTimeBelowAvatarChanged:) forControlEvents:UIControlEventValueChanged];
            break;
    }
    
    cell.accessoryView = switchView;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

- (void)preventRevokeChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kPreventRevokeEnabledKey];
}

- (void)hideChatTimeLabelChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kHideChatTimeLabelKey];
}

- (void)messageTimeBelowAvatarChanged:(UISwitch *)sender {
    [[NSUserDefaults standardUserDefaults] setBool:sender.isOn forKey:kMessageTimeBelowAvatarKey];
}

@end

@interface GameSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *friendsCountField;
@property (nonatomic, strong) UITextField *walletBalanceField;
@property (nonatomic, strong) UITextField *customStepsField;
@property (nonatomic, strong) UIButton *friendsCountConfirmButton;
@property (nonatomic, strong) UIButton *walletBalanceConfirmButton;
@property (nonatomic, strong) UIButton *customStepsConfirmButton;
@end

@implementation GameSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"娱乐功能";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    int rowCount = 1;
    rowCount += 1;
    if ([defaults boolForKey:kFriendsCountEnabledKey]) rowCount += 1;
    rowCount += 1;
    if ([defaults boolForKey:kWalletBalanceEnabledKey]) rowCount += 1;
    rowCount += 1;
    if ([defaults boolForKey:kCustomStepsEnabledKey]) rowCount += 1;
    return rowCount;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return [self isInputCellAtIndexPath:indexPath] ? 60.0 : 50.0;
}

- (BOOL)isInputCellAtIndexPath:(NSIndexPath *)indexPath {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    int rowIndex = indexPath.row;
    
    if (rowIndex == 0) return NO;
    rowIndex -= 1;
    
    if (rowIndex == 0) return NO;
    rowIndex -= 1;
    
    if ([defaults boolForKey:kFriendsCountEnabledKey] && rowIndex == 0) return YES;
    if ([defaults boolForKey:kFriendsCountEnabledKey]) rowIndex -= 1;
    
    if (rowIndex == 0) return NO;
    rowIndex -= 1;
    
    if ([defaults boolForKey:kWalletBalanceEnabledKey] && rowIndex == 0) return YES;
    if ([defaults boolForKey:kWalletBalanceEnabledKey]) rowIndex -= 1;
    
    if (rowIndex == 0) return NO;
    rowIndex -= 1;
    
    if ([defaults boolForKey:kCustomStepsEnabledKey] && rowIndex == 0) return YES;
    
    return NO;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    int rowIndex = indexPath.row;
    
    if (rowIndex == 0) return [self createGameCell:defaults];
    rowIndex -= 1;
    if (rowIndex == 0) return [self createFriendsCountSwitchCell:defaults];
    rowIndex -= 1;
    if ([defaults boolForKey:kFriendsCountEnabledKey] && rowIndex == 0) return [self createFriendsCountInputCell:defaults];
    if ([defaults boolForKey:kFriendsCountEnabledKey]) rowIndex -= 1;
    if (rowIndex == 0) return [self createWalletBalanceSwitchCell:defaults];
    rowIndex -= 1;
    if ([defaults boolForKey:kWalletBalanceEnabledKey] && rowIndex == 0) return [self createWalletBalanceInputCell:defaults];
    if ([defaults boolForKey:kWalletBalanceEnabledKey]) rowIndex -= 1;
    if (rowIndex == 0) return [self createCustomStepsSwitchCell:defaults];
    rowIndex -= 1;
    if ([defaults boolForKey:kCustomStepsEnabledKey] && rowIndex == 0) return [self createCustomStepsInputCell:defaults];
    
    return [[UITableViewCell alloc] init];
}

- (UITableViewCell *)createGameCell:(NSUserDefaults *)defaults {
    UITableViewCell *cell = [self createSwitchCellWithIdentifier:@"GameCell" title:@"骰子猜拳控制"];
    UISwitch *switchView = (UISwitch *)cell.accessoryView;
    switchView.on = [defaults boolForKey:kGameCheatEnabledKey];
    [switchView addTarget:self action:@selector(gameCheatEnabledChanged:) forControlEvents:UIControlEventValueChanged];
    return cell;
}

- (UITableViewCell *)createFriendsCountSwitchCell:(NSUserDefaults *)defaults {
    UITableViewCell *cell = [self createSwitchCellWithIdentifier:@"FriendsCountSwitchCell" title:@"好友数量自定义"];
    UISwitch *switchView = (UISwitch *)cell.accessoryView;
    switchView.on = [defaults boolForKey:kFriendsCountEnabledKey];
    [switchView addTarget:self action:@selector(friendsCountEnabledChanged:) forControlEvents:UIControlEventValueChanged];
    return cell;
}

- (UITableViewCell *)createFriendsCountInputCell:(NSUserDefaults *)defaults {
    UITableViewCell *cell = [self createInputCellWithIdentifier:@"FriendsCountInputCell" placeholder:@"输入好友数量（如：999）" keyboardType:UIKeyboardTypeNumberPad];
    _friendsCountField = (UITextField *)[cell.contentView.subviews firstObject];
    NSString *friendsCountValue = [defaults objectForKey:kFriendsCountValueKey];
    if (friendsCountValue) _friendsCountField.text = friendsCountValue;
    return cell;
}

- (UITableViewCell *)createWalletBalanceSwitchCell:(NSUserDefaults *)defaults {
    UITableViewCell *cell = [self createSwitchCellWithIdentifier:@"WalletBalanceSwitchCell" title:@"钱包余额自定义"];
    UISwitch *switchView = (UISwitch *)cell.accessoryView;
    switchView.on = [defaults boolForKey:kWalletBalanceEnabledKey];
    [switchView addTarget:self action:@selector(walletBalanceEnabledChanged:) forControlEvents:UIControlEventValueChanged];
    return cell;
}

- (UITableViewCell *)createWalletBalanceInputCell:(NSUserDefaults *)defaults {
    UITableViewCell *cell = [self createInputCellWithIdentifier:@"WalletBalanceInputCell" placeholder:@"输入余额（如：9999.99）" keyboardType:UIKeyboardTypeDecimalPad];
    _walletBalanceField = (UITextField *)[cell.contentView.subviews firstObject];
    NSString *walletBalanceValue = [defaults objectForKey:kWalletBalanceValueKey];
    if (walletBalanceValue) _walletBalanceField.text = walletBalanceValue;
    return cell;
}

- (UITableViewCell *)createCustomStepsSwitchCell:(NSUserDefaults *)defaults {
    UITableViewCell *cell = [self createSwitchCellWithIdentifier:@"CustomStepsSwitchCell" title:@"运动步数自定义"];
    UISwitch *switchView = (UISwitch *)cell.accessoryView;
    switchView.on = [defaults boolForKey:kCustomStepsEnabledKey];
    [switchView addTarget:self action:@selector(customStepsEnabledChanged:) forControlEvents:UIControlEventValueChanged];
    return cell;
}

- (UITableViewCell *)createCustomStepsInputCell:(NSUserDefaults *)defaults {
    UITableViewCell *cell = [self createInputCellWithIdentifier:@"CustomStepsInputCell" placeholder:@"输入步数（如：8888）" keyboardType:UIKeyboardTypeNumberPad];
    _customStepsField = (UITextField *)[cell.contentView.subviews firstObject];
    NSInteger stepsValue = [defaults integerForKey:kCustomStepsValueKey];
    if (stepsValue > 0) _customStepsField.text = [NSString stringWithFormat:@"%ld", (long)stepsValue];
    return cell;
}

- (UITableViewCell *)createSwitchCellWithIdentifier:(NSString *)identifier title:(NSString *)title {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    cell.textLabel.text = title;
    
    UISwitch *switchView = [[UISwitch alloc] init];
    switchView.onTintColor = [UIColor systemBlueColor];
    cell.accessoryView = switchView;
    
    return cell;
}

- (UITableViewCell *)createInputCellWithIdentifier:(NSString *)identifier placeholder:(NSString *)placeholder keyboardType:(UIKeyboardType)keyboardType {
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(20, 10, self.view.frame.size.width - 140, 40)];
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.placeholder = placeholder;
        textField.keyboardType = keyboardType;
        textField.delegate = self;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.backgroundColor = [UIColor tertiarySystemBackgroundColor];
        textField.textColor = [UIColor labelColor];
        [cell.contentView addSubview:textField];
        
        UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
        confirmButton.frame = CGRectMake(self.view.frame.size.width - 110, 10, 80, 40);
        [confirmButton setTitle:@"确认" forState:UIControlStateNormal];
        confirmButton.tintColor = [UIColor systemBlueColor];
        
        if ([identifier isEqualToString:@"FriendsCountInputCell"]) {
            [confirmButton addTarget:self action:@selector(friendsCountConfirmTapped:) forControlEvents:UIControlEventTouchUpInside];
            _friendsCountConfirmButton = confirmButton;
        } else if ([identifier isEqualToString:@"WalletBalanceInputCell"]) {
            [confirmButton addTarget:self action:@selector(walletBalanceConfirmTapped:) forControlEvents:UIControlEventTouchUpInside];
            _walletBalanceConfirmButton = confirmButton;
        } else if ([identifier isEqualToString:@"CustomStepsInputCell"]) {
            [confirmButton addTarget:self action:@selector(customStepsConfirmTapped:) forControlEvents:UIControlEventTouchUpInside];
            _customStepsConfirmButton = confirmButton;
        }
        
        [cell.contentView addSubview:confirmButton];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
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

- (void)customStepsEnabledChanged:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.isOn forKey:kCustomStepsEnabledKey];
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

- (void)customStepsConfirmTapped:(UIButton *)sender {
    if (_customStepsField) {
        [_customStepsField resignFirstResponder];
        [self saveCustomStepsValue];
    }
}

- (void)saveFriendsCountValue {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *text = _friendsCountField.text;
    if (text && text.length > 0) {
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
    if (text && text.length > 0) {
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

- (void)saveCustomStepsValue {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *text = _customStepsField.text;
    
    if (text && text.length > 0) {
        NSInteger steps = [text integerValue];
        if (steps >= 0 && steps <= 100000) {
            [defaults setInteger:steps forKey:kCustomStepsValueKey];
            [defaults setObject:[NSDate date] forKey:kLastStepsUpdateDateKey];
            [defaults synchronize];
            
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                CFSTR("com.dd.assistant.settings_changed"),
                                                NULL,
                                                NULL,
                                                YES);
            return;
        }
    }
    
    [defaults setInteger:8888 forKey:kCustomStepsValueKey];
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
    } else if (textField == _walletBalanceField) {
        [self saveWalletBalanceValue];
    } else if (textField == _customStepsField) {
        [self saveCustomStepsValue];
    }
}

- (void)keyboardWillShow:(NSNotification *)notification {
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
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

@interface LocationSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation LocationSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"虚拟定位";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return gLocationSpoofingEnabled ? 2 : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        NSString *cellIdentifier = @"LocationSwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        }
        
        cell.textLabel.text = @"启用虚拟定位";
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.onTintColor = [UIColor systemBlueColor];
        switchView.on = gLocationSpoofingEnabled;
        [switchView addTarget:self action:@selector(locationSpoofingChanged:) forControlEvents:UIControlEventValueChanged];
        
        cell.accessoryView = switchView;
        return cell;
        
    } else {
        NSString *cellIdentifier = @"LocationMapCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        }
        
        cell.textLabel.text = @"打开地图设置";
        
        UILabel *detailLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, 20)];
        detailLabel.text = [NSString stringWithFormat:@"%.6f, %.6f", gLatitude, gLongitude];
        detailLabel.textColor = [UIColor secondaryLabelColor];
        detailLabel.font = [UIFont systemFontOfSize:14];
        detailLabel.textAlignment = NSTextAlignmentRight;
        cell.accessoryView = detailLabel;
        
        return cell;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.row == 1) {
        [self showMapSelection];
    }
}

- (void)showMapSelection {
    LocationMapViewController *mapVC = [[LocationMapViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:mapVC];
    
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    nav.sheetPresentationController.preferredCornerRadius = 16;
    
    nav.sheetPresentationController.detents = @[
        [UISheetPresentationControllerDetent mediumDetent],
        [UISheetPresentationControllerDetent largeDetent]
    ];
    nav.sheetPresentationController.prefersGrabberVisible = YES;
    
    __weak typeof(self) weakSelf = self;
    mapVC.completionHandler = ^(CLLocationCoordinate2D coordinate) {
        [weakSelf.tableView reloadData];
    };
    
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)locationSpoofingChanged:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.isOn forKey:kLocationSpoofingEnabledKey];
    [defaults synchronize];
    
    loadAllSettings();
    [self.tableView reloadData];
    
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                        CFSTR("com.dd.assistant.settings_changed"),
                                        NULL,
                                        NULL,
                                        YES);
}

@end

@interface CSTouchTrailViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation CSTouchTrailViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"触摸轨迹";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenCaptureDidChange) name:UIScreenCapturedDidChangeNotification object:nil];
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

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [defaults boolForKey:kTouchTrailKey] ? 3 : 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"CSTouchTrailCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    UISwitch *switchView = [[UISwitch alloc] init];
    switchView.onTintColor = [UIColor systemBlueColor];
    
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"启用触摸轨迹";
            switchView.on = [defaults boolForKey:kTouchTrailKey];
            [switchView addTarget:self action:@selector(trailEnabledChanged:) forControlEvents:UIControlEventValueChanged];
            break;
        case 1:
            cell.textLabel.text = @"仅在录屏显示";
            switchView.on = [defaults boolForKey:kTouchTrailOnlyWhenRecordingKey];
            [switchView addTarget:self action:@selector(onlyWhenRecordingChanged:) forControlEvents:UIControlEventValueChanged];
            break;
        case 2:
            cell.textLabel.text = @"使用拖尾效果";
            switchView.on = [defaults boolForKey:kTouchTrailTailEnabledKey];
            [switchView addTarget:self action:@selector(tailEnabledChanged:) forControlEvents:UIControlEventValueChanged];
            break;
    }
    
    cell.accessoryView = switchView;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
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

@interface DDAssistantSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation DDAssistantSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = PLUGIN_NAME;
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"DDAssistantCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    
    UIImage *iconImage = nil;
    NSString *cellTitle = @"";
    
    switch (indexPath.section) {
        case 0:
            cellTitle = @"消息设置";
            iconImage = [UIImage systemImageNamed:@"message.fill"];
            break;
        case 1:
            cellTitle = @"娱乐功能";
            iconImage = [UIImage systemImageNamed:@"gamecontroller.fill"];
            break;
        case 2:
            cellTitle = @"虚拟定位";
            iconImage = [UIImage systemImageNamed:@"location.fill"];
            break;
        case 3:
            cellTitle = @"触摸轨迹";
            iconImage = [UIImage systemImageNamed:@"cursorarrow.motionlines"];
            break;
    }
    
    cell.textLabel.text = cellTitle;
    if (iconImage) {
        cell.imageView.image = iconImage;
        cell.imageView.tintColor = [UIColor systemBlueColor];
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 55.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return section == 0 ? 20.0 : 10.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    UIViewController *targetVC = nil;
    switch (indexPath.section) {
        case 0: targetVC = [[MessageSettingsViewController alloc] init]; break;
        case 1: targetVC = [[GameSettingsViewController alloc] init]; break;
        case 2: targetVC = [[LocationSettingsViewController alloc] init]; break;
        case 3: targetVC = [[CSTouchTrailViewController alloc] init]; break;
    }
    
    if (targetVC) {
        [self.navigationController pushViewController:targetVC animated:YES];
    }
}

@end

@interface WBTouchTrailDotView : UIView
@property (nonatomic, strong) UIColor *dotColor;
@property (nonatomic, assign) CGFloat dotSize;
- (instancetype)initWithPoint:(CGPoint)point dotColor:(UIColor *)dotColor dotSize:(CGFloat)dotSize duration:(CGFloat)duration;
@end

@implementation WBTouchTrailDotView

- (instancetype)initWithPoint:(CGPoint)point dotColor:(UIColor *)dotColor dotSize:(CGFloat)dotSize duration:(CGFloat)duration {
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

@interface WBTouchTrailView : UIView
@property (nonatomic, strong) UIColor *trailColor;
@property (nonatomic, assign) CGFloat trailSize;
@property (nonatomic, assign) BOOL isMoving;
- (void)updateWithPoint:(CGPoint)point isMoving:(BOOL)isMoving;
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

%hook CLLocationManager

- (void)startUpdatingLocation {
    if (isLocationSpoofingEnabled()) {
        dispatch_async(dispatch_get_main_queue(), ^{
            CLLocation *fakeLocation = getCurrentFakeLocation();
            if (fakeLocation && self.delegate && [self.delegate respondsToSelector:@selector(locationManager:didUpdateLocations:)]) {
                [self.delegate locationManager:self didUpdateLocations:@[fakeLocation]];
            }
        });
    } else {
        %orig;
    }
}

- (void)stopUpdatingLocation {
    %orig;
}

- (CLAuthorizationStatus)authorizationStatus {
    if (isLocationSpoofingEnabled()) {
        return kCLAuthorizationStatusAuthorizedWhenInUse;
    }
    return %orig;
}

%end

%hook CLLocation

- (CLLocationCoordinate2D)coordinate {
    if (isLocationSpoofingEnabled()) {
        return CLLocationCoordinate2DMake(gLatitude, gLongitude);
    }
    return %orig;
}

- (CLLocationAccuracy)horizontalAccuracy {
    if (isLocationSpoofingEnabled()) {
        return 5.0;
    }
    return %orig;
}

%end

%hook NewSettingViewController
- (void)reloadTableData {
    %orig;
    if (g_hasPluginsMgr) return;
    
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
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
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
    if (isGameCheatEnabled() && msgWrap.m_uiMessageType == 47 && (msgWrap.m_uiGameType == 2 || msgWrap.m_uiGameType == 1)) {
        WCActionSheet *actionSheet = nil;
        
        if (msgWrap.m_uiGameType == 1) {
            actionSheet = [[%c(WCActionSheet) alloc] initWithTitle:@"请选择猜拳结果"];
            
            [actionSheet addButtonWithTitle:@"剪刀" eventAction:^{
                unsigned int gameContent = 1;
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
            [actionSheet addButtonWithTitle:@"石头" eventAction:^{
                unsigned int gameContent = 2;
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
            [actionSheet addButtonWithTitle:@"布" eventAction:^{
                unsigned int gameContent = 3;
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
        } else if (msgWrap.m_uiGameType == 2) {
            actionSheet = [[%c(WCActionSheet) alloc] initWithTitle:@"请选择骰子点数"];
            
            for (int i = 1; i <= 6; i++) {
                NSString *title = [NSString stringWithFormat:@"%d点", i];
                [actionSheet addButtonWithTitle:title eventAction:^{
                    unsigned int gameContent = 3 + i;
                    NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                    if (md5) {
                        [msgWrap setM_nsEmoticonMD5:md5];
                        [msgWrap setM_uiGameContent:gameContent];
                    }
                    %orig(msg, msgWrap);
                }];
            }
        }
        
        UIWindowScene *windowScene = nil;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                windowScene = (UIWindowScene *)scene;
                break;
            }
        }
        
        if (windowScene && actionSheet) {
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
        } else if (contentView) {
            if (isSender) {
                centerX = CGRectGetMinX(contentView.frame) - 1 - timeLabel.bounds.size.width / 2;
            } else {
                centerX = CGRectGetMaxX(contentView.frame) + 1 + timeLabel.bounds.size.width / 2;
            }
            centerY = CGRectGetMaxY(contentView.frame) - timeLabel.bounds.size.height / 2;
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
    
    if (!isMessageTimeBelowAvatarEnabled()) return cell;
    
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
                    } else if (getMessageTime(viewModel) == nil) {
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
    if (!isPreventRevokeEnabled()) {
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

%hook MMUILabel
- (void)setText:(NSString *)text {
    if (!text) {
        %orig;
        return;
    }
    if (isFriendsCountEnabled() && gFriendsCountReplacement && gFriendsCountReplacement.length > 0) {
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
    if (isFriendsCountEnabled() && gFriendsCountReplacement && gFriendsCountReplacement.length > 0) {
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
    if (isContactsTitle && isFriendsCountEnabled() && gFriendsCountReplacement && gFriendsCountReplacement.length > 0) {
        %orig(arg1, gFriendsCountReplacement);
        return;
    }
    %orig;
}
%end

%hook WCPayWalletEntryHeaderView
- (void)handleUpdateWalletBalance {
    %orig;
    if (!isWalletBalanceEnabled() || !gWalletBalanceReplacement || gWalletBalanceReplacement.length == 0) return;
    
    TimeoutNumber *timeoutNumber = [self valueForKey:@"_timeoutNumber"];
    if (timeoutNumber) {
        NSScanner *scanner = [NSScanner scannerWithString:gWalletBalanceReplacement];
        unsigned long long balanceValue = 0;
        if ([scanner scanUnsignedLongLong:&balanceValue]) {
            balanceValue = balanceValue * 100;
            [timeoutNumber updateNumber:balanceValue];
        } else if (gWalletBalanceReplacement.length > 0) {
            unichar firstChar = [gWalletBalanceReplacement characterAtIndex:0];
            [timeoutNumber updateNumber:firstChar];
        }
    }
}

- (void)setupTimeoutNumber {
    %orig;
    if (!isWalletBalanceEnabled() || !gWalletBalanceReplacement || gWalletBalanceReplacement.length == 0) return;
    
    TimeoutNumber *timeoutNumber = [self valueForKey:@"_timeoutNumber"];
    if (timeoutNumber) {
        NSScanner *scanner = [NSScanner scannerWithString:gWalletBalanceReplacement];
        unsigned long long balanceValue = 0;
        if ([scanner scanUnsignedLongLong:&balanceValue]) {
            balanceValue = balanceValue * 100;
            [timeoutNumber updateNumber:balanceValue];
        } else if (gWalletBalanceReplacement.length > 0) {
            unichar firstChar = [gWalletBalanceReplacement characterAtIndex:0];
            [timeoutNumber updateNumber:firstChar];
        }
    }
}

- (void)updateBalanceEntryView {
    %orig;
    if (!isWalletBalanceEnabled() || !gWalletBalanceReplacement || gWalletBalanceReplacement.length == 0) return;
    
    TimeoutNumber *timeoutNumber = [self valueForKey:@"_timeoutNumber"];
    if (timeoutNumber) {
        NSScanner *scanner = [NSScanner scannerWithString:gWalletBalanceReplacement];
        unsigned long long balanceValue = 0;
        if ([scanner scanUnsignedLongLong:&balanceValue]) {
            balanceValue = balanceValue * 100;
            [timeoutNumber updateNumber:balanceValue];
        } else if (gWalletBalanceReplacement.length > 0) {
            unichar firstChar = [gWalletBalanceReplacement characterAtIndex:0];
            [timeoutNumber updateNumber:firstChar];
        }
    }
    
    MMUILabel *balanceMoneyLabel = [self valueForKey:@"_balanceMoneyLabel"];
    if (balanceMoneyLabel && balanceMoneyLabel.text.length > 0) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\d+(\\.\\d+)?" options:0 error:nil];
        NSString *newText = [regex stringByReplacingMatchesInString:balanceMoneyLabel.text options:0 range:NSMakeRange(0, balanceMoneyLabel.text.length) withTemplate:gWalletBalanceReplacement];
        balanceMoneyLabel.text = newText;
    }
}

- (void)updateBalanceAndRefreshView {
    %orig;
    if (!isWalletBalanceEnabled() || !gWalletBalanceReplacement || gWalletBalanceReplacement.length == 0) return;
    
    TimeoutNumber *timeoutNumber = [self valueForKey:@"_timeoutNumber"];
    if (timeoutNumber) {
        NSScanner *scanner = [NSScanner scannerWithString:gWalletBalanceReplacement];
        unsigned long long balanceValue = 0;
        if ([scanner scanUnsignedLongLong:&balanceValue]) {
            balanceValue = balanceValue * 100;
            [timeoutNumber updateNumber:balanceValue];
        } else if (gWalletBalanceReplacement.length > 0) {
            unichar firstChar = [gWalletBalanceReplacement characterAtIndex:0];
            [timeoutNumber updateNumber:firstChar];
        }
    }
    
    MMUILabel *balanceMoneyLabel = [self valueForKey:@"_balanceMoneyLabel"];
    if (balanceMoneyLabel && balanceMoneyLabel.text.length > 0) {
        NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\d+(\\.\\d+)?" options:0 error:nil];
        NSString *newText = [regex stringByReplacingMatchesInString:balanceMoneyLabel.text options:0 range:NSMakeRange(0, balanceMoneyLabel.text.length) withTemplate:gWalletBalanceReplacement];
        balanceMoneyLabel.text = newText;
    }
}
%end

%hook TimeoutNumber
- (void)updateNumber:(unsigned long long)arg1 {
    if (!isWalletBalanceEnabled() || !gWalletBalanceReplacement || gWalletBalanceReplacement.length == 0) {
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
    } else if (gWalletBalanceReplacement.length > 0) {
        unichar firstChar = [gWalletBalanceReplacement characterAtIndex:0];
        %orig(firstChar);
    } else {
        %orig;
    }
}

- (void)defaultNumber:(unsigned long long)arg1 {
    if (!isWalletBalanceEnabled() || !gWalletBalanceReplacement || gWalletBalanceReplacement.length == 0) {
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
    } else if (gWalletBalanceReplacement.length > 0) {
        unichar firstChar = [gWalletBalanceReplacement characterAtIndex:0];
        %orig(firstChar);
    } else {
        %orig;
    }
}
%end

%hook WCDeviceStepObject
- (unsigned int)m7StepCount {
    if (isCustomStepsEnabled()) {
        NSDate *lastUpdateDate = [[NSUserDefaults standardUserDefaults] objectForKey:kLastStepsUpdateDateKey];
        if (!lastUpdateDate || !isToday(lastUpdateDate)) {
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kLastStepsUpdateDateKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        return (unsigned int)getCustomStepsValue();
    }
    return %orig;
}

- (unsigned int)hkStepCount {
    if (isCustomStepsEnabled()) {
        NSDate *lastUpdateDate = [[NSUserDefaults standardUserDefaults] objectForKey:kLastStepsUpdateDateKey];
        if (!lastUpdateDate || !isToday(lastUpdateDate)) {
            [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:kLastStepsUpdateDateKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        return (unsigned int)getCustomStepsValue();
    }
    return %orig;
}
%end

%hook WCDataItem
- (unsigned int)stepCount {
    if (isCustomStepsEnabled()) {
        return (unsigned int)getCustomStepsValue();
    }
    return %orig;
}
%end

%hook UIApplication
+ (void)load {
    %orig;
    touchViews = [NSMutableDictionary dictionary];
    touchTailViews = [NSMutableDictionary dictionary];
    touchLastPointTimes = [NSMutableDictionary dictionary];
    isTrailEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kTouchTrailDisplayStateKey];
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
    
    if (!isTrailEnabled) return;
    
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
            kCustomStepsEnabledKey: @NO,
            kTouchTrailKey: @NO,
            kTouchTrailOnlyWhenRecordingKey: @NO,
            kTouchTrailDisplayStateKey: @NO,
            kTouchTrailTailEnabledKey: @NO,
            kLocationSpoofingEnabledKey: @NO
        };
        
        for (NSString *key in defaultValues) {
            if (![defaults objectForKey:key]) {
                [defaults setBool:[defaultValues[key] boolValue] forKey:key];
            }
        }
        
        if ([defaults integerForKey:kCustomStepsValueKey] == 0) {
            [defaults setInteger:8888 forKey:kCustomStepsValueKey];
        }
        
        if (![defaults objectForKey:kLastStepsUpdateDateKey]) {
            [defaults setObject:[NSDate date] forKey:kLastStepsUpdateDateKey];
        }
        
        if ([defaults doubleForKey:kLatitudeKey] == 0 && [defaults doubleForKey:kLongitudeKey] == 0) {
            [defaults setDouble:39.9042 forKey:kLatitudeKey];
            [defaults setDouble:116.4074 forKey:kLongitudeKey];
        }
        
        [defaults synchronize];
        
        loadAllSettings();
        
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        NULL,
                                        (CFNotificationCallback)loadAllSettings,
                                        CFSTR("com.dd.assistant.settings_changed"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);
        
        Class pluginsMgrClass = NSClassFromString(@"WCPluginsMgr");
        if (pluginsMgrClass && [pluginsMgrClass respondsToSelector:@selector(sharedInstance)]) {
            g_hasPluginsMgr = YES;
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:PLUGIN_NAME version:PLUGIN_VERSION controller:@"DDAssistantSettingsViewController"];
        } else {
            g_hasPluginsMgr = NO;
        }
    }
}