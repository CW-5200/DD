#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>

#define PLUGIN_NAME @"DD助手"
#define PLUGIN_VERSION @"1.0.0"

// MARK: - 原有常量定义
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

// MARK: - 新增常量定义
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

// MARK: - 新增配置管理
static BOOL gFakeLocationEnabled = NO;
static double gFakeLatitude = 39.9035;
static double gFakeLongitude = 116.3976;
static BOOL gCustomStepsEnabled = NO;
static NSInteger gCustomStepsValue = 8888;
static NSDate *gLastStepsUpdateDate = nil;

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

static BOOL isFakeLocationEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kFakeLocationEnabledKey];
}

static BOOL isCustomStepsEnabled() {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kCustomStepsEnabledKey];
}

static double getFakeLatitude() {
    return [[NSUserDefaults standardUserDefaults] doubleForKey:kFakeLatitudeKey];
}

static double getFakeLongitude() {
    return [[NSUserDefaults standardUserDefaults] doubleForKey:kFakeLongitudeKey];
}

static NSInteger getCustomStepsValue() {
    NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:kCustomStepsValueKey];
    return value > 0 ? value : 8888;
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
    
    // 加载好友和钱包设置
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
    
    // 加载位置和步数设置
    gFakeLocationEnabled = [defaults boolForKey:kFakeLocationEnabledKey];
    gFakeLatitude = [defaults doubleForKey:kFakeLatitudeKey];
    gFakeLongitude = [defaults doubleForKey:kFakeLongitudeKey];
    
    // 默认位置设为北京天安门
    if (gFakeLatitude == 0 && gFakeLongitude == 0) {
        gFakeLatitude = 39.9035;
        gFakeLongitude = 116.3976;
        [defaults setDouble:gFakeLatitude forKey:kFakeLatitudeKey];
        [defaults setDouble:gFakeLongitude forKey:kFakeLongitudeKey];
        [defaults synchronize];
    }
    
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
}

// MARK: - 辅助函数
static BOOL isToday(NSDate *date) {
    if (!date) return NO;
    
    NSCalendar *calendar = [NSCalendar currentCalendar];
    NSDateComponents *dateComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:date];
    NSDateComponents *todayComponents = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:[NSDate date]];
    
    return (dateComponents.year == todayComponents.year &&
            dateComponents.month == todayComponents.month &&
            dateComponents.day == todayComponents.day);
}

// MARK: - 地图选择视图控制器
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
    
    // 设置导航栏
    [self setupNavigationBar];
    
    // 创建地图视图
    self.mapView = [[MKMapView alloc] init];
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = YES;
    self.mapView.showsCompass = YES;
    self.mapView.showsScale = YES;
    self.mapView.pointOfInterestFilter = [MKPointOfInterestFilter filterIncludingAllCategories];
    
    // 添加圆角效果
    self.mapView.layer.cornerRadius = 12;
    self.mapView.layer.masksToBounds = YES;
    self.mapView.layer.shadowColor = [[UIColor blackColor] CGColor];
    self.mapView.layer.shadowOffset = CGSizeMake(0, 2);
    self.mapView.layer.shadowRadius = 8;
    self.mapView.layer.shadowOpacity = 0.15;
    
    [self.view addSubview:self.mapView];
    
    // 创建搜索容器
    UIView *searchContainer = [[UIView alloc] init];
    searchContainer.backgroundColor = [UIColor clearColor];
    
    // 添加模糊效果
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blurView.layer.cornerRadius = 12;
    blurView.layer.masksToBounds = YES;
    
    // 创建搜索栏
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.delegate = self;
    self.searchBar.placeholder = @"搜索地点或输入坐标";
    self.searchBar.searchBarStyle = UISearchBarStyleDefault;
    self.searchBar.barTintColor = [UIColor clearColor];
    self.searchBar.backgroundImage = [[UIImage alloc] init]; // 移除背景
    
    // 设置搜索文本框样式
    UITextField *searchTextField = self.searchBar.searchTextField;
    searchTextField.backgroundColor = [UIColor secondarySystemBackgroundColor];
    searchTextField.layer.cornerRadius = 10;
    searchTextField.layer.masksToBounds = YES;
    searchTextField.clearButtonMode = UITextFieldViewModeWhileEditing;
    
    [blurView.contentView addSubview:self.searchBar];
    [searchContainer addSubview:blurView];
    [self.view addSubview:searchContainer];
    
    // 添加提示标签
    UILabel *hintLabel = [[UILabel alloc] init];
    hintLabel.text = @"长按地图选择位置";
    hintLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    hintLabel.textAlignment = NSTextAlignmentCenter;
    hintLabel.textColor = [UIColor secondaryLabelColor];
    hintLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:hintLabel];
    
    // 使用AutoLayout
    searchContainer.translatesAutoresizingMaskIntoConstraints = NO;
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.mapView.translatesAutoresizingMaskIntoConstraints = NO;
    hintLabel.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        // 搜索容器
        [searchContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:12],
        [searchContainer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [searchContainer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [searchContainer.heightAnchor constraintEqualToConstant:52],
        
        // 模糊视图
        [blurView.leadingAnchor constraintEqualToAnchor:searchContainer.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:searchContainer.trailingAnchor],
        [blurView.topAnchor constraintEqualToAnchor:searchContainer.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:searchContainer.bottomAnchor],
        
        // 搜索栏
        [self.searchBar.leadingAnchor constraintEqualToAnchor:blurView.leadingAnchor],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:blurView.trailingAnchor],
        [self.searchBar.topAnchor constraintEqualToAnchor:blurView.topAnchor],
        [self.searchBar.bottomAnchor constraintEqualToAnchor:blurView.bottomAnchor],
        
        // 地图
        [self.mapView.topAnchor constraintEqualToAnchor:searchContainer.bottomAnchor constant:16],
        [self.mapView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.mapView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.mapView.bottomAnchor constraintEqualToAnchor:hintLabel.topAnchor constant:-12],
        
        // 提示标签
        [hintLabel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],
        [hintLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [hintLabel.heightAnchor constraintEqualToConstant:20]
    ]];
    
    // 添加长按手势
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] 
                                               initWithTarget:self 
                                               action:@selector(handleMapLongPress:)];
    [self.mapView addGestureRecognizer:longPress];
    
    // 初始化地理编码器
    self.geocoder = [[CLGeocoder alloc] init];
    
    // 设置初始位置
    CLLocationCoordinate2D initialCoord = CLLocationCoordinate2DMake(getFakeLatitude(), getFakeLongitude());
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(initialCoord, 1000, 1000);
    [self.mapView setRegion:region animated:YES];
    
    // 添加现有位置标注
    MKPointAnnotation *existingAnnotation = [[MKPointAnnotation alloc] init];
    existingAnnotation.coordinate = initialCoord;
    existingAnnotation.title = @"当前位置";
    [self.mapView addAnnotation:existingAnnotation];
}

- (void)setupNavigationBar {
    // 将X图标改为"取消"文字按钮
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle:@"取消"
                                                                     style:UIBarButtonItemStylePlain
                                                                    target:self
                                                                    action:@selector(closeMapSelection)];
    self.navigationItem.leftBarButtonItem = cancelButton;
    
    // 添加确认按钮
    UIBarButtonItem *confirmButton = [[UIBarButtonItem alloc] initWithTitle:@"确认"
                                                                      style:UIBarButtonItemStyleDone
                                                                     target:self
                                                                     action:@selector(confirmMapSelection)];
    self.navigationItem.rightBarButtonItem = confirmButton;
    
    // 设置导航栏外观
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = [UIColor systemBackgroundColor];
    appearance.titleTextAttributes = @{
        NSForegroundColorAttributeName: [UIColor labelColor],
        NSFontAttributeName: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold]
    };
    appearance.shadowColor = [UIColor separatorColor];
    
    self.navigationController.navigationBar.standardAppearance = appearance;
    self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
}

- (void)closeMapSelection {
    [self.navigationController dismissViewControllerAnimated:YES completion:nil];
}

- (void)handleMapLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        // 震动反馈
        UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        [feedback impactOccurred];
        
        // 清除之前的选择标注
        NSMutableArray *annotationsToRemove = [NSMutableArray array];
        for (id<MKAnnotation> annotation in self.mapView.annotations) {
            if ([annotation.title isEqualToString:@"选择的位置"]) {
                [annotationsToRemove addObject:annotation];
            }
        }
        [self.mapView removeAnnotations:annotationsToRemove];
        
        // 获取点击位置
        CGPoint touchPoint = [gesture locationInView:self.mapView];
        CLLocationCoordinate2D coordinate = [self.mapView convertPoint:touchPoint 
                                                  toCoordinateFromView:self.mapView];
        
        // 添加标注
        MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
        annotation.coordinate = coordinate;
        annotation.title = @"选择的位置";
        
        // 地理编码获取地点名称
        CLLocation *location = [[CLLocation alloc] initWithLatitude:coordinate.latitude 
                                                          longitude:coordinate.longitude];
        [self.geocoder reverseGeocodeLocation:location completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
            if (!error && placemarks.count > 0) {
                CLPlacemark *placemark = placemarks.firstObject;
                NSString *address = [self formatPlacemarkAddress:placemark];
                annotation.subtitle = address;
                self.searchBar.text = address;
            } else {
                annotation.subtitle = [NSString stringWithFormat:@"%.4f, %.4f", coordinate.latitude, coordinate.longitude];
                self.searchBar.text = [NSString stringWithFormat:@"%.4f, %.4f", coordinate.latitude, coordinate.longitude];
            }
        }];
        
        [self.mapView addAnnotation:annotation];
        
        // 聚焦到标注位置
        MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coordinate, 500, 500);
        [self.mapView setRegion:region animated:YES];
        
        // 选中标注
        [self.mapView selectAnnotation:annotation animated:YES];
    }
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
    // 找到选择的位置标注
    MKPointAnnotation *selectedAnnotation = nil;
    for (id<MKAnnotation> annotation in self.mapView.annotations) {
        if ([annotation.title isEqualToString:@"选择的位置"]) {
            selectedAnnotation = (MKPointAnnotation *)annotation;
            break;
        }
    }
    
    if (selectedAnnotation) {
        CLLocationCoordinate2D coordinate = selectedAnnotation.coordinate;
        
        // 保存位置
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setDouble:coordinate.latitude forKey:kFakeLatitudeKey];
        [defaults setDouble:coordinate.longitude forKey:kFakeLongitudeKey];
        [defaults synchronize];
        
        // 震动反馈确认
        UINotificationFeedbackGenerator *feedback = [[UINotificationFeedbackGenerator alloc] init];
        [feedback notificationOccurred:UINotificationFeedbackTypeSuccess];
        
        if (self.completionHandler) {
            self.completionHandler(coordinate);
        }
        
        [self.navigationController dismissViewControllerAnimated:YES completion:^{
            // 发送设置变更通知
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                CFSTR("com.dd.assistant.settings_changed"),
                                                NULL,
                                                NULL,
                                                YES);
        }];
    } else {
        [self showAlertWithTitle:@"提示" message:@"请先在地图上选择一个位置"];
    }
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title 
                                                                   message:message 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - MKMapViewDelegate
- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) return nil;
    
    static NSString *annotationId = @"customAnnotation";
    MKMarkerAnnotationView *markerView = (MKMarkerAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:annotationId];
    
    if (!markerView) {
        markerView = [[MKMarkerAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:annotationId];
        markerView.canShowCallout = YES;
        markerView.animatesWhenAdded = YES;
        markerView.glyphTintColor = [UIColor whiteColor];
        
        // 添加详情按钮
        UIButton *detailButton = [UIButton buttonWithType:UIButtonTypeDetailDisclosure];
        markerView.rightCalloutAccessoryView = detailButton;
        
        // 添加阴影
        markerView.layer.shadowColor = [[UIColor blackColor] CGColor];
        markerView.layer.shadowOffset = CGSizeMake(0, 2);
        markerView.layer.shadowRadius = 4;
        markerView.layer.shadowOpacity = 0.3;
    } else {
        markerView.annotation = annotation;
    }
    
    // 根据标注类型设置样式
    if ([annotation.title isEqualToString:@"当前位置"]) {
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
        self.searchBar.text = [NSString stringWithFormat:@"%.4f, %.4f", 
                              annotation.coordinate.latitude, 
                              annotation.coordinate.longitude];
        [self.searchBar becomeFirstResponder];
    }
}

#pragma mark - UISearchBarDelegate
- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    
    NSString *searchText = searchBar.text;
    if (searchText.length == 0) return;
    
    // 检查是否是坐标格式
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
    
    // 地理编码搜索
    [self.geocoder geocodeAddressString:searchText completionHandler:^(NSArray<CLPlacemark *> *placemarks, NSError *error) {
        if (error) {
            [self showAlertWithTitle:@"搜索失败" message:@"未找到该地点，请尝试输入坐标格式：纬度,经度"];
            return;
        }
        
        if (placemarks.count > 0) {
            CLPlacemark *placemark = placemarks.firstObject;
            [self addSelectedAnnotationAtCoordinate:placemark.location.coordinate withSubtitle:[self formatPlacemarkAddress:placemark]];
        }
    }];
}

- (void)addSelectedAnnotationAtCoordinate:(CLLocationCoordinate2D)coordinate withSubtitle:(NSString *)subtitle {
    // 清除之前的选择标注
    NSMutableArray *annotationsToRemove = [NSMutableArray array];
    for (id<MKAnnotation> annotation in self.mapView.annotations) {
        if ([annotation.title isEqualToString:@"选择的位置"]) {
            [annotationsToRemove addObject:annotation];
        }
    }
    [self.mapView removeAnnotations:annotationsToRemove];
    
    // 添加新的标注
    MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
    annotation.coordinate = coordinate;
    annotation.title = @"选择的位置";
    annotation.subtitle = subtitle;
    [self.mapView addAnnotation:annotation];
    
    // 调整地图区域
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coordinate, 1000, 1000);
    [self.mapView setRegion:region animated:YES];
    
    // 选中标注
    [self.mapView selectAnnotation:annotation animated:YES];
}

@end

@interface WCActionSheet : NSObject
- (id)initWithTitle:(NSString *)title cancelButtonTitle:(NSString *)cancelButtonTitle;
- (id)initWithTitle:(NSString *)title;
- (id)init;
- (void)addButtonWithTitle:(NSString *)title eventAction:(void(^)(void))eventAction;
- (void)showInView:(UIView *)view;
@end

@interface MessageSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
    NSArray *_settings;
}
@property (nonatomic, strong) UITableView *tableView;
@end

@interface GameSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate> {
    NSArray *_settings;
    UITextField *_friendsCountField;
    UITextField *_walletBalanceField;
    UITextField *_customStepsField;
    UIButton *_friendsCountConfirmButton;
    UIButton *_walletBalanceConfirmButton;
    UIButton *_customStepsConfirmButton;
}
@property (nonatomic, strong) UITableView *tableView;
@end

@interface CSTouchTrailViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@end

@interface DDAssistantSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
    NSArray *_sections;
}
@property (nonatomic, strong) UITableView *tableView;
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

// MARK: - 新增类声明
@interface MMLocationMgr : NSObject
- (void)locationManager:(id)arg1 didUpdateToLocation:(id)arg2 fromLocation:(id)arg3;
- (void)locationManager:(id)arg1 didUpdateLocations:(NSArray *)arg2;
@end

@interface WCDeviceStepObject : NSObject
- (unsigned int)m7StepCount;
- (unsigned int)hkStepCount;
@end

@interface WCDataItem : NSObject
- (unsigned int)stepCount;
@end

@interface WCLocationInfo : NSObject
- (double)latitude;
- (double)longitude;
@end

@interface MicroMessengerAppDelegate : NSObject
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions;
@end

@implementation MessageSettingsViewController

- (void)loadView {
    [super loadView];
    [self setupTableView];
}

- (void)setupTableView {
    if (@available(iOS 13.0, *)) {
        self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    } else {
        self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    }
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"消息设置";
    
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    } else {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _settings = @[@"消息防撤提示", @"隐藏自带时间", @"头像时间标签"];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _settings.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"MessageSettingsCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        if (@available(iOS 13.0, *)) {
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        }
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *cellTitle = _settings[indexPath.row];
    cell.textLabel.text = cellTitle;
    
    if (@available(iOS 13.0, *)) {
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    }
    
    UISwitch *switchView = [[UISwitch alloc] init];
    if (@available(iOS 13.0, *)) {
        switchView.onTintColor = [UIColor systemBlueColor];
    }
    
    if (indexPath.row == 0) {
        switchView.on = [defaults boolForKey:kPreventRevokeEnabledKey];
        [switchView addTarget:self action:@selector(preventRevokeChanged:) forControlEvents:UIControlEventValueChanged];
    } else if (indexPath.row == 1) {
        switchView.on = [defaults boolForKey:kHideChatTimeLabelKey];
        [switchView addTarget:self action:@selector(hideChatTimeLabelChanged:) forControlEvents:UIControlEventValueChanged];
    } else if (indexPath.row == 2) {
        switchView.on = [defaults boolForKey:kMessageTimeBelowAvatarKey];
        [switchView addTarget:self action:@selector(messageTimeBelowAvatarChanged:) forControlEvents:UIControlEventValueChanged];
    }
    
    cell.accessoryView = switchView;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 30)];
    headerView.backgroundColor = [UIColor clearColor];
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 10.0;
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

@implementation GameSettingsViewController

- (void)loadView {
    [super loadView];
    [self setupTableView];
}

- (void)setupTableView {
    if (@available(iOS 13.0, *)) {
        self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    } else {
        self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    }
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"娱乐功能";
    
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    } else {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _settings = @[@"骰子猜拳控制", @"好友数量自定义", @"好友数量输入框", @"钱包余额自定义", @"钱包余额输入框", @"运动步数自定义", @"运动步数输入框", @"微信位置自定义", @"地图选择位置"];
    
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
    BOOL customStepsEnabled = [defaults boolForKey:kCustomStepsEnabledKey];
    BOOL fakeLocationEnabled = [defaults boolForKey:kFakeLocationEnabledKey];
    
    int rowCount = 1; // 骰子猜拳控制
    rowCount += 1; // 好友数量自定义开关
    if (friendsCountEnabled) {
        rowCount += 1; // 好友数量输入框
    }
    rowCount += 1; // 钱包余额自定义开关
    if (walletBalanceEnabled) {
        rowCount += 1; // 钱包余额输入框
    }
    rowCount += 1; // 运动步数自定义开关
    if (customStepsEnabled) {
        rowCount += 1; // 运动步数输入框
    }
    rowCount += 1; // 微信位置自定义开关
    if (fakeLocationEnabled) {
        rowCount += 1; // 地图选择位置
    }
    
    return rowCount;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([self isInputCellAtIndexPath:indexPath]) {
        return 60.0;
    }
    return 50.0;
}

- (BOOL)isInputCellAtIndexPath:(NSIndexPath *)indexPath {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL friendsCountEnabled = [defaults boolForKey:kFriendsCountEnabledKey];
    BOOL walletBalanceEnabled = [defaults boolForKey:kWalletBalanceEnabledKey];
    BOOL customStepsEnabled = [defaults boolForKey:kCustomStepsEnabledKey];
    BOOL fakeLocationEnabled = [defaults boolForKey:kFakeLocationEnabledKey];
    
    int rowIndex = indexPath.row;
    
    // 骰子猜拳控制
    if (rowIndex == 0) return NO;
    rowIndex -= 1;
    
    // 好友数量自定义开关
    if (rowIndex == 0) return NO;
    rowIndex -= 1;
    
    // 好友数量输入框
    if (friendsCountEnabled && rowIndex == 0) return YES;
    if (friendsCountEnabled) {
        rowIndex -= 1;
    }
    
    // 钱包余额自定义开关
    if (rowIndex == 0) return NO;
    rowIndex -= 1;
    
    // 钱包余额输入框
    if (walletBalanceEnabled && rowIndex == 0) return YES;
    if (walletBalanceEnabled) {
        rowIndex -= 1;
    }
    
    // 运动步数自定义开关
    if (rowIndex == 0) return NO;
    rowIndex -= 1;
    
    // 运动步数输入框
    if (customStepsEnabled && rowIndex == 0) return YES;
    if (customStepsEnabled) {
        rowIndex -= 1;
    }
    
    // 微信位置自定义开关
    if (rowIndex == 0) return NO;
    rowIndex -= 1;
    
    // 地图选择位置
    if (fakeLocationEnabled && rowIndex == 0) return NO; // 不是输入框，是按钮
    
    return NO;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL friendsCountEnabled = [defaults boolForKey:kFriendsCountEnabledKey];
    BOOL walletBalanceEnabled = [defaults boolForKey:kWalletBalanceEnabledKey];
    BOOL customStepsEnabled = [defaults boolForKey:kCustomStepsEnabledKey];
    BOOL fakeLocationEnabled = [defaults boolForKey:kFakeLocationEnabledKey];
    
    int rowIndex = indexPath.row;
    
    // 骰子猜拳控制
    if (rowIndex == 0) {
        NSString *cellIdentifier = @"GameCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            }
        }
        cell.textLabel.text = @"骰子猜拳控制";
        
        if (@available(iOS 13.0, *)) {
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        }
        
        UISwitch *switchView = [[UISwitch alloc] init];
        if (@available(iOS 13.0, *)) {
            switchView.onTintColor = [UIColor systemBlueColor];
        }
        switchView.on = [defaults boolForKey:kGameCheatEnabledKey];
        [switchView addTarget:self action:@selector(gameCheatEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
        return cell;
    }
    
    rowIndex -= 1;
    
    // 好友数量自定义开关
    if (rowIndex == 0) {
        NSString *cellIdentifier = @"FriendsCountSwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            }
        }
        cell.textLabel.text = @"好友数量自定义";
        
        if (@available(iOS 13.0, *)) {
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        }
        
        UISwitch *switchView = [[UISwitch alloc] init];
        if (@available(iOS 13.0, *)) {
            switchView.onTintColor = [UIColor systemBlueColor];
        }
        switchView.on = friendsCountEnabled;
        [switchView addTarget:self action:@selector(friendsCountEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
        return cell;
    }
    
    rowIndex -= 1;
    
    // 好友数量输入框
    if (friendsCountEnabled && rowIndex == 0) {
        NSString *cellIdentifier = @"FriendsCountInputCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            }
            
            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(20, 10, self.view.frame.size.width - 140, 40)];
            textField.borderStyle = UITextBorderStyleRoundedRect;
            textField.placeholder = @"输入好友数量（如：999）";
            textField.keyboardType = UIKeyboardTypeNumberPad;
            textField.delegate = self;
            textField.clearButtonMode = UITextFieldViewModeWhileEditing;
            
            if (@available(iOS 13.0, *)) {
                textField.backgroundColor = [UIColor tertiarySystemBackgroundColor];
                textField.textColor = [UIColor labelColor];
            }
            
            [cell.contentView addSubview:textField];
            _friendsCountField = textField;
            
            UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
            confirmButton.frame = CGRectMake(self.view.frame.size.width - 110, 10, 80, 40);
            [confirmButton setTitle:@"确认" forState:UIControlStateNormal];
            
            if (@available(iOS 13.0, *)) {
                confirmButton.tintColor = [UIColor systemBlueColor];
            }
            
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
    
    // 钱包余额自定义开关
    if (rowIndex == 0) {
        NSString *cellIdentifier = @"WalletBalanceSwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            }
        }
        cell.textLabel.text = @"钱包余额自定义";
        
        if (@available(iOS 13.0, *)) {
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        }
        
        UISwitch *switchView = [[UISwitch alloc] init];
        if (@available(iOS 13.0, *)) {
            switchView.onTintColor = [UIColor systemBlueColor];
        }
        switchView.on = walletBalanceEnabled;
        [switchView addTarget:self action:@selector(walletBalanceEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
        return cell;
    }
    
    rowIndex -= 1;
    
    // 钱包余额输入框
    if (walletBalanceEnabled && rowIndex == 0) {
        NSString *cellIdentifier = @"WalletBalanceInputCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            }
            
            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(20, 10, self.view.frame.size.width - 140, 40)];
            textField.borderStyle = UITextBorderStyleRoundedRect;
            textField.placeholder = @"输入余额（如：9999.99）";
            textField.keyboardType = UIKeyboardTypeDecimalPad;
            textField.delegate = self;
            textField.clearButtonMode = UITextFieldViewModeWhileEditing;
            
            if (@available(iOS 13.0, *)) {
                textField.backgroundColor = [UIColor tertiarySystemBackgroundColor];
                textField.textColor = [UIColor labelColor];
            }
            
            [cell.contentView addSubview:textField];
            _walletBalanceField = textField;
            
            UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
            confirmButton.frame = CGRectMake(self.view.frame.size.width - 110, 10, 80, 40);
            [confirmButton setTitle:@"确认" forState:UIControlStateNormal];
            
            if (@available(iOS 13.0, *)) {
                confirmButton.tintColor = [UIColor systemBlueColor];
            }
            
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
    
    if (walletBalanceEnabled) {
        rowIndex -= 1;
    }
    
    // 运动步数自定义开关
    if (rowIndex == 0) {
        NSString *cellIdentifier = @"CustomStepsSwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            }
        }
        cell.textLabel.text = @"运动步数自定义";
        
        if (@available(iOS 13.0, *)) {
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        }
        
        UISwitch *switchView = [[UISwitch alloc] init];
        if (@available(iOS 13.0, *)) {
            switchView.onTintColor = [UIColor systemBlueColor];
        }
        switchView.on = customStepsEnabled;
        [switchView addTarget:self action:@selector(customStepsEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
        return cell;
    }
    
    rowIndex -= 1;
    
    // 运动步数输入框
    if (customStepsEnabled && rowIndex == 0) {
        NSString *cellIdentifier = @"CustomStepsInputCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            }
            
            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(20, 10, self.view.frame.size.width - 140, 40)];
            textField.borderStyle = UITextBorderStyleRoundedRect;
            textField.placeholder = @"输入步数（如：8888）";
            textField.keyboardType = UIKeyboardTypeNumberPad;
            textField.delegate = self;
            textField.clearButtonMode = UITextFieldViewModeWhileEditing;
            
            if (@available(iOS 13.0, *)) {
                textField.backgroundColor = [UIColor tertiarySystemBackgroundColor];
                textField.textColor = [UIColor labelColor];
            }
            
            [cell.contentView addSubview:textField];
            _customStepsField = textField;
            
            UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
            confirmButton.frame = CGRectMake(self.view.frame.size.width - 110, 10, 80, 40);
            [confirmButton setTitle:@"确认" forState:UIControlStateNormal];
            
            if (@available(iOS 13.0, *)) {
                confirmButton.tintColor = [UIColor systemBlueColor];
            }
            
            [confirmButton addTarget:self action:@selector(customStepsConfirmTapped:) forControlEvents:UIControlEventTouchUpInside];
            [cell.contentView addSubview:confirmButton];
            _customStepsConfirmButton = confirmButton;
            
            NSInteger stepsValue = [defaults integerForKey:kCustomStepsValueKey];
            if (stepsValue > 0) {
                textField.text = [NSString stringWithFormat:@"%ld", (long)stepsValue];
            }
        }
        return cell;
    }
    
    if (customStepsEnabled) {
        rowIndex -= 1;
    }
    
    // 微信位置自定义开关
    if (rowIndex == 0) {
        NSString *cellIdentifier = @"FakeLocationSwitchCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            }
        }
        cell.textLabel.text = @"微信位置自定义";
        
        if (@available(iOS 13.0, *)) {
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        }
        
        UISwitch *switchView = [[UISwitch alloc] init];
        if (@available(iOS 13.0, *)) {
            switchView.onTintColor = [UIColor systemBlueColor];
        }
        switchView.on = fakeLocationEnabled;
        [switchView addTarget:self action:@selector(fakeLocationEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
        return cell;
    }
    
    rowIndex -= 1;
    
    // 地图选择位置
    if (fakeLocationEnabled && rowIndex == 0) {
        NSString *cellIdentifier = @"MapSelectionCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            }
        }
        
        // 显示当前位置信息
        double latitude = [defaults doubleForKey:kFakeLatitudeKey];
        double longitude = [defaults doubleForKey:kFakeLongitudeKey];
        
        if (@available(iOS 14.0, *)) {
            UIListContentConfiguration *content = [UIListContentConfiguration subtitleCellConfiguration];
            content.text = @"打开地图自定义";
            content.secondaryText = [NSString stringWithFormat:@"当前：%.4f, %.4f", latitude, longitude];
            content.textProperties.color = [UIColor labelColor];
            content.secondaryTextProperties.color = [UIColor secondaryLabelColor];
            cell.contentConfiguration = content;
        } else {
            cell.textLabel.text = @"打开地图自定义";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"当前：%.4f, %.4f", latitude, longitude];
            if (@available(iOS 13.0, *)) {
                cell.textLabel.textColor = [UIColor labelColor];
                cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
            }
        }
        
        return cell;
    }
    
    return [[UITableViewCell alloc] init];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 30)];
    headerView.backgroundColor = [UIColor clearColor];
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 10.0;
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

- (void)fakeLocationEnabledChanged:(UISwitch *)sender {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:sender.isOn forKey:kFakeLocationEnabledKey];
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

- (void)saveCustomStepsValue {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *text = _customStepsField.text;
    
    if (text && [text length] > 0) {
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
    
    // 如果输入无效，恢复默认值
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
    } 
    else if (textField == _walletBalanceField) {
        [self saveWalletBalanceValue];
    }
    else if (textField == _customStepsField) {
        [self saveCustomStepsValue];
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL fakeLocationEnabled = [defaults boolForKey:kFakeLocationEnabledKey];
    
    // 检查是否是地图选择位置行
    if (fakeLocationEnabled) {
        NSInteger rowIndex = indexPath.row;
        BOOL friendsCountEnabled = [defaults boolForKey:kFriendsCountEnabledKey];
        BOOL walletBalanceEnabled = [defaults boolForKey:kWalletBalanceEnabledKey];
        BOOL customStepsEnabled = [defaults boolForKey:kCustomStepsEnabledKey];
        
        // 计算地图选择位置行的索引
        int targetRow = 1; // 骰子猜拳控制
        targetRow += 1; // 好友数量自定义开关
        if (friendsCountEnabled) {
            targetRow += 1; // 好友数量输入框
        }
        targetRow += 1; // 钱包余额自定义开关
        if (walletBalanceEnabled) {
            targetRow += 1; // 钱包余额输入框
        }
        targetRow += 1; // 运动步数自定义开关
        if (customStepsEnabled) {
            targetRow += 1; // 运动步数输入框
        }
        targetRow += 1; // 微信位置自定义开关
        
        if (rowIndex == targetRow) {
            // 打开地图选择界面
            [self showMapSelection];
        }
    }
}

- (void)showMapSelection {
    LocationMapViewController *mapVC = [[LocationMapViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:mapVC];
    
    // 使用SheetPresentationController
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    if (@available(iOS 15.0, *)) {
        nav.sheetPresentationController.preferredCornerRadius = 16;
        nav.sheetPresentationController.detents = @[
            [UISheetPresentationControllerDetent mediumDetent],
            [UISheetPresentationControllerDetent largeDetent]
        ];
        nav.sheetPresentationController.prefersGrabberVisible = YES;
        nav.sheetPresentationController.prefersScrollingExpandsWhenScrolledToEdge = NO;
    }
    
    __weak typeof(self) weakSelf = self;
    mapVC.completionHandler = ^(CLLocationCoordinate2D coordinate) {
        [weakSelf.tableView reloadData];
    };
    
    [self presentViewController:nav animated:YES completion:nil];
}

@end

@implementation CSTouchTrailViewController

- (void)loadView {
    [super loadView];
    [self setupTableView];
}

- (void)setupTableView {
    if (@available(iOS 13.0, *)) {
        self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    } else {
        self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    }
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"触摸轨迹";
    
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    } else {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
    
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
    NSString *cellIdentifier = @"CSTouchTrailCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        if (@available(iOS 13.0, *)) {
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        }
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (@available(iOS 13.0, *)) {
        cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
    }
    
    if (indexPath.row == 0) {
        cell.textLabel.text = @"启用触摸轨迹";
        UISwitch *switchView = [[UISwitch alloc] init];
        if (@available(iOS 13.0, *)) {
            switchView.onTintColor = [UIColor systemBlueColor];
        }
        switchView.on = [defaults boolForKey:kTouchTrailKey];
        [switchView addTarget:self action:@selector(trailEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    } else if (indexPath.row == 1) {
        cell.textLabel.text = @"仅在录屏显示";
        UISwitch *switchView = [[UISwitch alloc] init];
        if (@available(iOS 13.0, *)) {
            switchView.onTintColor = [UIColor systemBlueColor];
        }
        switchView.on = [defaults boolForKey:kTouchTrailOnlyWhenRecordingKey];
        [switchView addTarget:self action:@selector(onlyWhenRecordingChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    } else if (indexPath.row == 2) {
        cell.textLabel.text = @"使用拖尾效果";
        UISwitch *switchView = [[UISwitch alloc] init];
        if (@available(iOS 13.0, *)) {
            switchView.onTintColor = [UIColor systemBlueColor];
        }
        switchView.on = [defaults boolForKey:kTouchTrailTailEnabledKey];
        [switchView addTarget:self action:@selector(tailEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 30)];
    headerView.backgroundColor = [UIColor clearColor];
    return headerView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 10.0;
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

- (void)loadView {
    [super loadView];
    [self setupTableView];
}

- (void)setupTableView {
    if (@available(iOS 13.0, *)) {
        self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    } else {
        self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    }
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = PLUGIN_NAME;
    
    if (@available(iOS 13.0, *)) {
        self.view.backgroundColor = [UIColor systemBackgroundColor];
        self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeAutomatic;
    } else {
        self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _sections = @[
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"DDAssistantCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        if (@available(iOS 13.0, *)) {
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
            cell.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
        }
    }
    
    NSString *cellTitle = _sections[indexPath.section][indexPath.row];
    cell.textLabel.text = cellTitle;
    
    if (@available(iOS 13.0, *)) {
        UIImage *iconImage = nil;
        if (indexPath.section == 0) {
            iconImage = [UIImage systemImageNamed:@"message.fill"];
        } else if (indexPath.section == 1) {
            iconImage = [UIImage systemImageNamed:@"gamecontroller.fill"];
        } else if (indexPath.section == 2) {
            iconImage = [UIImage systemImageNamed:@"cursorarrow.motionlines"];
        }
        
        if (iconImage) {
            cell.imageView.image = iconImage;
            cell.imageView.tintColor = [UIColor systemBlueColor];
        }
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 55.0;
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

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    UIViewController *targetVC = nil;
    if (indexPath.section == 0) {
        targetVC = [[MessageSettingsViewController alloc] init];
    } else if (indexPath.section == 1) {
        targetVC = [[GameSettingsViewController alloc] init];
    } else if (indexPath.section == 2) {
        targetVC = [[CSTouchTrailViewController alloc] init];
    }
    
    if (targetVC) {
        [self.navigationController pushViewController:targetVC animated:YES];
    }
}

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

// MARK: - Hook 实现

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
        NSString *title = @"";
        WCActionSheet *actionSheet = nil;
        
        if ([msgWrap m_uiGameType] == 1) {
            title = @"请选择猜拳结果";
            actionSheet = [[%c(WCActionSheet) alloc] initWithTitle:title];
            
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
            
        } else if ([msgWrap m_uiGameType] == 2) {
            title = @"请选择骰子点数";
            actionSheet = [[%c(WCActionSheet) alloc] initWithTitle:title];
            
            [actionSheet addButtonWithTitle:@"1点" eventAction:^{
                unsigned int gameContent = 4;
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
            [actionSheet addButtonWithTitle:@"2点" eventAction:^{
                unsigned int gameContent = 5;
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
            [actionSheet addButtonWithTitle:@"3点" eventAction:^{
                unsigned int gameContent = 6;
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
            [actionSheet addButtonWithTitle:@"4点" eventAction:^{
                unsigned int gameContent = 7;
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
            [actionSheet addButtonWithTitle:@"5点" eventAction:^{
                unsigned int gameContent = 8;
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
            
            [actionSheet addButtonWithTitle:@"6点" eventAction:^{
                unsigned int gameContent = 9;
                NSString *md5 = [objc_getClass("GameController") getMD5ByGameContent:gameContent];
                if (md5) {
                    [msgWrap setM_nsEmoticonMD5:md5];
                    [msgWrap setM_uiGameContent:gameContent];
                }
                %orig(msg, msgWrap);
            }];
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

// MARK: - 新增 Hook 实现

%hook MMLocationMgr

- (void)locationManager:(id)arg1 didUpdateToLocation:(id)arg2 fromLocation:(id)arg3 {
    if (isFakeLocationEnabled()) {
        CLLocation *fakeLocation = [[CLLocation alloc] initWithLatitude:getFakeLatitude() 
                                                              longitude:getFakeLongitude()];
        %orig(arg1, fakeLocation, arg3);
    } else {
        %orig(arg1, arg2, arg3);
    }
}

- (void)locationManager:(id)arg1 didUpdateLocations:(NSArray *)arg2 {
    if (isFakeLocationEnabled()) {
        CLLocation *fakeLocation = [[CLLocation alloc] initWithLatitude:getFakeLatitude() 
                                                              longitude:getFakeLongitude()];
        %orig(arg1, @[fakeLocation]);
    } else {
        %orig(arg1, arg2);
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

%hook WCLocationInfo

- (double)latitude {
    if (isFakeLocationEnabled()) {
        return getFakeLatitude();
    }
    
    return %orig;
}

- (double)longitude {
    if (isFakeLocationEnabled()) {
        return getFakeLongitude();
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
            kFakeLocationEnabledKey: @NO,
            kCustomStepsEnabledKey: @NO,
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
        
        // 设置默认位置
        if ([defaults doubleForKey:kFakeLatitudeKey] == 0 && [defaults doubleForKey:kFakeLongitudeKey] == 0) {
            [defaults setDouble:39.9035 forKey:kFakeLatitudeKey];
            [defaults setDouble:116.3976 forKey:kFakeLongitudeKey];
        }
        
        // 设置默认步数
        if ([defaults integerForKey:kCustomStepsValueKey] == 0) {
            [defaults setInteger:8888 forKey:kCustomStepsValueKey];
        }
        
        // 设置默认最后更新时间
        if (![defaults objectForKey:kLastStepsUpdateDateKey]) {
            [defaults setObject:[NSDate date] forKey:kLastStepsUpdateDateKey];
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