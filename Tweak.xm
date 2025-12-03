[file name]: Tweak.xm
[file content begin]
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

// 图标管理类
@interface DDAssistantIconManager : NSObject
+ (UIImage *)iconForFeature:(NSString *)featureName;
+ (UIImage *)symbolWithName:(NSString *)name size:(CGFloat)size weight:(UIImageSymbolWeight)weight;
+ (UIImage *)gradientIconWithSymbol:(NSString *)symbolName size:(CGFloat)size color1:(UIColor *)color1 color2:(UIColor *)color2;
@end

@implementation DDAssistantIconManager

+ (UIImage *)iconForFeature:(NSString *)featureName {
    if (@available(iOS 13.0, *)) {
        if ([featureName isEqualToString:@"消息设置"]) {
            return [self gradientIconWithSymbol:@"message.fill" size:28 color1:[UIColor systemBlueColor] color2:[UIColor systemCyanColor]];
        } else if ([featureName isEqualToString:@"娱乐功能"]) {
            return [self gradientIconWithSymbol:@"gamecontroller.fill" size:28 color1:[UIColor systemPurpleColor] color2:[UIColor systemPinkColor]];
        } else if ([featureName isEqualToString:@"触摸轨迹"]) {
            return [self gradientIconWithSymbol:@"hand.draw.fill" size:28 color1:[UIColor systemOrangeColor] color2:[UIColor systemYellowColor]];
        } else if ([featureName isEqualToString:@"好友数量"]) {
            return [self gradientIconWithSymbol:@"person.3.fill" size:28 color1:[UIColor systemBlueColor] color2:[UIColor systemTealColor]];
        } else if ([featureName isEqualToString:@"钱包余额"]) {
            return [self gradientIconWithSymbol:@"dollarsign.circle.fill" size:28 color1:[UIColor systemGreenColor] color2:[UIColor systemBlueColor]];
        } else if ([featureName isEqualToString:@"防撤提示"]) {
            return [self gradientIconWithSymbol:@"arrow.uturn.backward.circle.fill" size:28 color1:[UIColor systemRedColor] color2:[UIColor systemOrangeColor]];
        } else if ([featureName isEqualToString:@"骰子控制"]) {
            return [self gradientIconWithSymbol:@"die.face.6.fill" size:28 color1:[UIColor systemPurpleColor] color2:[UIColor systemIndigoColor]];
        } else if ([featureName isEqualToString:@"录屏显示"]) {
            return [self gradientIconWithSymbol:@"record.circle.fill" size:28 color1:[UIColor systemRedColor] color2:[UIColor systemPinkColor]];
        }
    }
    return nil;
}

+ (UIImage *)symbolWithName:(NSString *)name size:(CGFloat)size weight:(UIImageSymbolWeight)weight {
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:size 
                                                                                           weight:weight
                                                                                            scale:UIImageSymbolScaleLarge];
        UIImage *image = [UIImage systemImageNamed:name withConfiguration:config];
        return image;
    }
    return nil;
}

+ (UIImage *)gradientIconWithSymbol:(NSString *)symbolName size:(CGFloat)size color1:(UIColor *)color1 color2:(UIColor *)color2 {
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:size 
                                                                                           weight:UIImageSymbolWeightSemibold
                                                                                            scale:UIImageSymbolScaleLarge];
        
        UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size + 16, size + 16)];
        
        return [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
            CGContextRef ctx = context.CGContext;
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            
            NSArray *colors = @[
                (__bridge id)color1.CGColor,
                (__bridge id)color2.CGColor
            ];
            
            CGFloat locations[] = {0.0, 1.0};
            CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, locations);
            
            CGRect rect = CGRectMake(2, 2, size + 12, size + 12);
            UIBezierPath *circlePath = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:(size + 12)/4];
            [circlePath addClip];
            
            CGContextDrawLinearGradient(ctx, gradient, 
                                      CGPointMake(0, 0), 
                                      CGPointMake(size + 16, size + 16), 
                                      0);
            
            UIImage *symbol = [UIImage systemImageNamed:symbolName withConfiguration:config];
            [symbol drawInRect:CGRectMake(8, 8, size, size)];
            
            CFRelease(gradient);
            CFRelease(colorSpace);
        }];
    }
    return nil;
}

@end

@interface MessageSettingsViewController : UITableViewController {
    NSArray *_settings;
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

@interface ModernDDAssistantSettingsViewController : UIViewController
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

@interface TextMessageSubViewModel : CommonMessageViewModel
@property(readonly, nonatomic) CommonMessageViewModel *parentModel;
@property(readonly, nonatomic) NSArray *subViewModels;
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

@implementation ModernDDAssistantSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // 设置iOS 13+现代风格
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    if (@available(iOS 13.0, *)) {
        // 创建动态模糊背景
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blurView.frame = self.view.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:blurView];
    }
    
    // 创建现代风格的UI
    [self setupModernUI];
}

- (void)setupModernUI {
    // 创建主容器
    UIView *mainContainer = [[UIView alloc] init];
    mainContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:mainContainer];
    
    // 应用图标
    UIImageView *appIconView = [[UIImageView alloc] init];
    appIconView.translatesAutoresizingMaskIntoConstraints = NO;
    appIconView.contentMode = UIViewContentModeScaleAspectFit;
    
    // 创建应用图标（使用渐变）
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(120, 120)];
    UIImage *appIcon = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull context) {
        CGRect rect = CGRectMake(0, 0, 120, 120);
        
        // 绘制渐变背景
        UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:28];
        [roundedRect addClip];
        
        // 创建渐变
        CGContextRef ctx = context.CGContext;
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        NSArray *colors = @[
            (__bridge id)[UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.35 green:0.34 blue:0.84 alpha:1.0].CGColor
        ];
        CGGradientRef gradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)colors, NULL);
        CGContextDrawLinearGradient(ctx, gradient, CGPointMake(0, 0), CGPointMake(120, 120), 0);
        
        // 绘制DD字母
        NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
        style.alignment = NSTextAlignmentCenter;
        
        NSDictionary *attributes = @{
            NSFontAttributeName: [UIFont systemFontOfSize:48 weight:UIFontWeightHeavy],
            NSForegroundColorAttributeName: [UIColor whiteColor],
            NSParagraphStyleAttributeName: style
        };
        
        [@"DD" drawInRect:CGRectMake(0, 35, 120, 50) withAttributes:attributes];
        
        CFRelease(gradient);
        CFRelease(colorSpace);
    }];
    
    appIconView.image = appIcon;
    appIconView.layer.shadowColor = [UIColor blackColor].CGColor;
    appIconView.layer.shadowOffset = CGSizeMake(0, 4);
    appIconView.layer.shadowOpacity = 0.2;
    appIconView.layer.shadowRadius = 8;
    [mainContainer addSubview:appIconView];
    
    // 应用名称
    UILabel *appNameLabel = [[UILabel alloc] init];
    appNameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    appNameLabel.text = PLUGIN_NAME;
    appNameLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightHeavy];
    appNameLabel.textColor = [UIColor labelColor];
    appNameLabel.textAlignment = NSTextAlignmentCenter;
    [mainContainer addSubview:appNameLabel];
    
    // 版本标签
    UILabel *versionLabel = [[UILabel alloc] init];
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    versionLabel.text = [NSString stringWithFormat:@"Version %@", PLUGIN_VERSION];
    versionLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    versionLabel.textColor = [UIColor secondaryLabelColor];
    versionLabel.textAlignment = NSTextAlignmentCenter;
    [mainContainer addSubview:versionLabel];
    
    // 功能卡片
    NSArray *features = @[
        @{
            @"title": @"消息设置",
            @"subtitle": @"防撤回、时间显示等",
            @"icon": @"message.fill",
            @"color": [UIColor systemBlueColor],
            @"targetVC": @"MessageSettingsViewController"
        },
        @{
            @"title": @"娱乐功能", 
            @"subtitle": @"游戏控制、好友数量",
            @"icon": @"gamecontroller.fill",
            @"color": [UIColor systemPurpleColor],
            @"targetVC": @"GameSettingsViewController"
        },
        @{
            @"title": @"触摸轨迹",
            @"subtitle": @"录屏触摸显示",
            @"icon": @"hand.draw.fill",
            @"color": [UIColor systemOrangeColor],
            @"targetVC": @"CSTouchTrailViewController"
        }
    ];
    
    UIStackView *cardsStack = [[UIStackView alloc] init];
    cardsStack.translatesAutoresizingMaskIntoConstraints = NO;
    cardsStack.axis = UILayoutConstraintAxisVertical;
    cardsStack.spacing = 16;
    cardsStack.distribution = UIStackViewDistributionFillEqually;
    [mainContainer addSubview:cardsStack];
    
    for (NSDictionary *feature in features) {
        UIControl *card = [self createFeatureCardWithTitle:feature[@"title"]
                                                  subtitle:feature[@"subtitle"]
                                                     icon:feature[@"icon"]
                                                     color:feature[@"color"]
                                                  targetVC:feature[@"targetVC"]];
        [cardsStack addArrangedSubview:card];
    }
    
    // 底部信息
    UILabel *footerLabel = [[UILabel alloc] init];
    footerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    footerLabel.text = @"✨ 让微信体验更美好";
    footerLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    footerLabel.textColor = [UIColor tertiaryLabelColor];
    footerLabel.textAlignment = NSTextAlignmentCenter;
    [mainContainer addSubview:footerLabel];
    
    // 约束
    [NSLayoutConstraint activateConstraints:@[
        [mainContainer.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:20],
        [mainContainer.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-20],
        [mainContainer.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
        [mainContainer.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        
        [appIconView.topAnchor constraintEqualToAnchor:mainContainer.topAnchor constant:20],
        [appIconView.centerXAnchor constraintEqualToAnchor:mainContainer.centerXAnchor],
        [appIconView.widthAnchor constraintEqualToConstant:120],
        [appIconView.heightAnchor constraintEqualToConstant:120],
        
        [appNameLabel.topAnchor constraintEqualToAnchor:appIconView.bottomAnchor constant:16],
        [appNameLabel.centerXAnchor constraintEqualToAnchor:mainContainer.centerXAnchor],
        
        [versionLabel.topAnchor constraintEqualToAnchor:appNameLabel.bottomAnchor constant:4],
        [versionLabel.centerXAnchor constraintEqualToAnchor:mainContainer.centerXAnchor],
        
        [cardsStack.topAnchor constraintEqualToAnchor:versionLabel.bottomAnchor constant:40],
        [cardsStack.leadingAnchor constraintEqualToAnchor:mainContainer.leadingAnchor],
        [cardsStack.trailingAnchor constraintEqualToAnchor:mainContainer.trailingAnchor],
        [cardsStack.heightAnchor constraintEqualToConstant:240],
        
        [footerLabel.bottomAnchor constraintEqualToAnchor:mainContainer.bottomAnchor constant:-20],
        [footerLabel.centerXAnchor constraintEqualToAnchor:mainContainer.centerXAnchor]
    ]];
}

- (UIControl *)createFeatureCardWithTitle:(NSString *)title 
                                 subtitle:(NSString *)subtitle 
                                    icon:(NSString *)iconName 
                                    color:(UIColor *)color
                                 targetVC:(NSString *)targetVCName {
    
    UIControl *card = [[UIControl alloc] init];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.backgroundColor = [UIColor secondarySystemBackgroundColor];
    card.layer.cornerRadius = 20;
    card.layer.cornerCurve = kCACornerCurveContinuous;
    
    // 添加阴影
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOffset = CGSizeMake(0, 2);
    card.layer.shadowOpacity = 0.1;
    card.layer.shadowRadius = 8;
    
    // 添加点击效果
    [card addTarget:self action:@selector(cardTouchDown:) forControlEvents:UIControlEventTouchDown];
    [card addTarget:self action:@selector(cardTouchUp:) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside];
    
    // 图标容器
    UIView *iconContainer = [[UIView alloc] init];
    iconContainer.translatesAutoresizingMaskIntoConstraints = NO;
    iconContainer.backgroundColor = color;
    iconContainer.layer.cornerRadius = 12;
    iconContainer.layer.cornerCurve = kCACornerCurveContinuous;
    [card addSubview:iconContainer];
    
    // 图标
    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.tintColor = [UIColor whiteColor];
    
    if (@available(iOS 13.0, *)) {
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:24 
                                                                                           weight:UIImageSymbolWeightSemibold];
        iconView.image = [[UIImage systemImageNamed:iconName withConfiguration:config] 
                         imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    [iconContainer addSubview:iconView];
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightSemibold];
    titleLabel.textColor = [UIColor labelColor];
    [card addSubview:titleLabel];
    
    // 副标题
    UILabel *subtitleLabel = [[UILabel alloc] init];
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    subtitleLabel.text = subtitle;
    subtitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    subtitleLabel.textColor = [UIColor secondaryLabelColor];
    [card addSubview:subtitleLabel];
    
    // 箭头
    UIImageView *arrowIcon = [[UIImageView alloc] init];
    arrowIcon.translatesAutoresizingMaskIntoConstraints = NO;
    arrowIcon.contentMode = UIViewContentModeScaleAspectFit;
    arrowIcon.tintColor = [UIColor tertiaryLabelColor];
    
    if (@available(iOS 13.0, *)) {
        arrowIcon.image = [UIImage systemImageNamed:@"chevron.right"];
    }
    [card addSubview:arrowIcon];
    
    // 约束
    [NSLayoutConstraint activateConstraints:@[
        [iconContainer.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:20],
        [iconContainer.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [iconContainer.widthAnchor constraintEqualToConstant:44],
        [iconContainer.heightAnchor constraintEqualToConstant:44],
        
        [iconView.centerXAnchor constraintEqualToAnchor:iconContainer.centerXAnchor],
        [iconView.centerYAnchor constraintEqualToAnchor:iconContainer.centerYAnchor],
        [iconView.widthAnchor constraintEqualToConstant:24],
        [iconView.heightAnchor constraintEqualToConstant:24],
        
        [titleLabel.leadingAnchor constraintEqualToAnchor:iconContainer.trailingAnchor constant:16],
        [titleLabel.topAnchor constraintEqualToAnchor:card.topAnchor constant:20],
        
        [subtitleLabel.leadingAnchor constraintEqualToAnchor:titleLabel.leadingAnchor],
        [subtitleLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [subtitleLabel.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-20],
        
        [arrowIcon.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-20],
        [arrowIcon.centerYAnchor constraintEqualToAnchor:card.centerYAnchor],
        [arrowIcon.widthAnchor constraintEqualToConstant:12],
        [arrowIcon.heightAnchor constraintEqualToConstant:20]
    ]];
    
    // 关联数据
    objc_setAssociatedObject(card, @"featureTitle", title, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(card, @"targetVC", targetVCName, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    return card;
}

- (void)cardTouchDown:(UIControl *)card {
    [UIView animateWithDuration:0.1 animations:^{
        card.transform = CGAffineTransformMakeScale(0.98, 0.98);
        card.backgroundColor = [UIColor tertiarySystemBackgroundColor];
    }];
}

- (void)cardTouchUp:(UIControl *)card {
    [UIView animateWithDuration:0.2 delay:0 usingSpringWithDamping:0.6 initialSpringVelocity:0.5 options:0 animations:^{
        card.transform = CGAffineTransformIdentity;
        card.backgroundColor = [UIColor secondarySystemBackgroundColor];
    } completion:^(BOOL finished) {
        // 处理点击
        NSString *featureTitle = objc_getAssociatedObject(card, @"featureTitle");
        NSString *targetVCName = objc_getAssociatedObject(card, @"targetVC");
        [self handleCardTap:featureTitle targetVC:targetVCName];
    }];
}

- (void)handleCardTap:(NSString *)featureTitle targetVC:(NSString *)targetVCName {
    UIViewController *targetVC = nil;
    
    if ([targetVCName isEqualToString:@"MessageSettingsViewController"]) {
        targetVC = [[MessageSettingsViewController alloc] init];
    } else if ([targetVCName isEqualToString:@"GameSettingsViewController"]) {
        targetVC = [[GameSettingsViewController alloc] init];
    } else if ([targetVCName isEqualToString:@"CSTouchTrailViewController"]) {
        targetVC = [[CSTouchTrailViewController alloc] init];
    }
    
    if (targetVC) {
        // 配置子页面的导航栏
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:targetVC];
        
        if (@available(iOS 13.0, *)) {
            // 现代导航栏样式
            UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
            [appearance configureWithOpaqueBackground];
            appearance.backgroundColor = [UIColor systemBackgroundColor];
            appearance.shadowColor = [UIColor clearColor];
            
            nav.navigationBar.standardAppearance = appearance;
            nav.navigationBar.scrollEdgeAppearance = appearance;
        }
        
        // 使用 sheet 呈现
        if (@available(iOS 15.0, *)) {
            nav.modalPresentationStyle = UIModalPresentationPageSheet;
            
            UISheetPresentationController *sheet = nav.sheetPresentationController;
            if (sheet) {
                sheet.preferredCornerRadius = 20;
                sheet.prefersGrabberVisible = YES;
                sheet.detents = @[
                    [UISheetPresentationControllerDetent mediumDetent],
                    [UISheetPresentationControllerDetent largeDetent]
                ];
                sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
            }
        } else if (@available(iOS 13.0, *)) {
            nav.modalPresentationStyle = UIModalPresentationAutomatic;
        } else {
            nav.modalPresentationStyle = UIModalPresentationFullScreen;
        }
        
        [self presentViewController:nav animated:YES completion:nil];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    // 隐藏导航栏
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    // 显示导航栏
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}

@end

@implementation MessageSettingsViewController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"消息设置";
    
    if (@available(iOS 13.0, *)) {
        self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.tableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    }
    
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    _settings = @[@"防撤提示", @"隐藏自带时间", @"头像时间标签"];
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _settings.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModernCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ModernCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        if (@available(iOS 13.0, *)) {
            cell.backgroundColor = [UIColor secondarySystemBackgroundColor];
        }
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *cellTitle = _settings[indexPath.row];
    cell.textLabel.text = cellTitle;
    
    // 添加图标
    if (@available(iOS 13.0, *)) {
        NSString *iconName = @"";
        UIColor *iconColor = [UIColor systemBlueColor];
        
        if (indexPath.row == 0) {
            iconName = @"arrow.uturn.backward.circle.fill";
            iconColor = [UIColor systemRedColor];
        } else if (indexPath.row == 1) {
            iconName = @"clock.fill";
            iconColor = [UIColor systemOrangeColor];
        } else if (indexPath.row == 2) {
            iconName = @"person.crop.circle.fill";
            iconColor = [UIColor systemGreenColor];
        }
        
        UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 
                                                                                           weight:UIImageSymbolWeightMedium];
        cell.imageView.image = [[UIImage systemImageNamed:iconName withConfiguration:config]
                               imageWithTintColor:iconColor renderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    
    UISwitch *switchView = [[UISwitch alloc] init];
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
    
    // 使用iOS 13+的开关样式
    if (@available(iOS 13.0, *)) {
        switchView.onTintColor = [UIColor systemBlueColor];
    }
    
    cell.accessoryView = switchView;
    return cell;
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
- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"娱乐功能";
    
    if (@available(iOS 13.0, *)) {
        self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.tableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
    }
    
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
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor secondarySystemBackgroundColor];
            }
        }
        NSString *cellTitle = _settings[0];
        cell.textLabel.text = cellTitle;
        
        // 添加图标
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 
                                                                                               weight:UIImageSymbolWeightMedium];
            cell.imageView.image = [[UIImage systemImageNamed:@"die.face.6.fill" withConfiguration:config]
                                   imageWithTintColor:[UIColor systemPurpleColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [defaults boolForKey:kGameCheatEnabledKey];
        [switchView addTarget:self action:@selector(gameCheatEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        
        if (@available(iOS 13.0, *)) {
            switchView.onTintColor = [UIColor systemPurpleColor];
        }
        
        cell.accessoryView = switchView;
        return cell;
    }
    
    rowIndex -= 1;
    if (rowIndex == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FriendsCountSwitchCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"FriendsCountSwitchCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor secondarySystemBackgroundColor];
            }
        }
        cell.textLabel.text = @"好友数量自定义";
        
        // 添加图标
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 
                                                                                               weight:UIImageSymbolWeightMedium];
            cell.imageView.image = [[UIImage systemImageNamed:@"person.3.fill" withConfiguration:config]
                                   imageWithTintColor:[UIColor systemBlueColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = friendsCountEnabled;
        [switchView addTarget:self action:@selector(friendsCountEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        
        if (@available(iOS 13.0, *)) {
            switchView.onTintColor = [UIColor systemBlueColor];
        }
        
        cell.accessoryView = switchView;
        return cell;
    }
    
    rowIndex -= 1;
    if (friendsCountEnabled && rowIndex == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FriendsCountInputCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"FriendsCountInputCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor tertiarySystemBackgroundColor];
            } else {
                cell.backgroundColor = [UIColor clearColor];
            }
            
            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(50, 7, self.view.frame.size.width - 160, 30)];
            textField.borderStyle = UITextBorderStyleRoundedRect;
            textField.placeholder = @"输入好友数量（如：999）";
            textField.keyboardType = UIKeyboardTypeNumberPad;
            textField.delegate = self;
            textField.clearButtonMode = UITextFieldViewModeWhileEditing;
            
            if (@available(iOS 13.0, *)) {
                textField.backgroundColor = [UIColor systemBackgroundColor];
                textField.textColor = [UIColor labelColor];
                textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:textField.placeholder 
                                                                                  attributes:@{NSForegroundColorAttributeName: [UIColor placeholderTextColor]}];
            }
            
            [cell.contentView addSubview:textField];
            _friendsCountField = textField;
            
            UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
            confirmButton.frame = CGRectMake(self.view.frame.size.width - 100, 7, 80, 30);
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
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor secondarySystemBackgroundColor];
            }
        }
        cell.textLabel.text = @"钱包余额自定义";
        
        // 添加图标
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 
                                                                                               weight:UIImageSymbolWeightMedium];
            cell.imageView.image = [[UIImage systemImageNamed:@"dollarsign.circle.fill" withConfiguration:config]
                                   imageWithTintColor:[UIColor systemGreenColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = walletBalanceEnabled;
        [switchView addTarget:self action:@selector(walletBalanceEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        
        if (@available(iOS 13.0, *)) {
            switchView.onTintColor = [UIColor systemGreenColor];
        }
        
        cell.accessoryView = switchView;
        return cell;
    }
    
    rowIndex -= 1;
    if (walletBalanceEnabled && rowIndex == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"WalletBalanceInputCell"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"WalletBalanceInputCell"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            
            if (@available(iOS 13.0, *)) {
                cell.backgroundColor = [UIColor tertiarySystemBackgroundColor];
            } else {
                cell.backgroundColor = [UIColor clearColor];
            }
            
            UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(50, 7, self.view.frame.size.width - 160, 30)];
            textField.borderStyle = UITextBorderStyleRoundedRect;
            textField.placeholder = @"输入余额（如：9999.99）";
            textField.keyboardType = UIKeyboardTypeDecimalPad;
            textField.delegate = self;
            textField.clearButtonMode = UITextFieldViewModeWhileEditing;
            
            if (@available(iOS 13.0, *)) {
                textField.backgroundColor = [UIColor systemBackgroundColor];
                textField.textColor = [UIColor labelColor];
                textField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:textField.placeholder 
                                                                                  attributes:@{NSForegroundColorAttributeName: [UIColor placeholderTextColor]}];
            }
            
            [cell.contentView addSubview:textField];
            _walletBalanceField = textField;
            
            UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
            confirmButton.frame = CGRectMake(self.view.frame.size.width - 100, 7, 80, 30);
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
    
    if (@available(iOS 13.0, *)) {
        self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    } else {
        self.tableView.backgroundColor = [UIColor groupTableViewBackgroundColor];
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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ModernCell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"ModernCell"];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        if (@available(iOS 13.0, *)) {
            cell.backgroundColor = [UIColor secondarySystemBackgroundColor];
        }
    }
    
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    if (indexPath.row == 0) {
        cell.textLabel.text = @"启用触摸轨迹";
        
        // 添加图标
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 
                                                                                               weight:UIImageSymbolWeightMedium];
            cell.imageView.image = [[UIImage systemImageNamed:@"hand.draw.fill" withConfiguration:config]
                                   imageWithTintColor:[UIColor systemOrangeColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [defaults boolForKey:kTouchTrailKey];
        [switchView addTarget:self action:@selector(trailEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        
        if (@available(iOS 13.0, *)) {
            switchView.onTintColor = [UIColor systemOrangeColor];
        }
        
        cell.accessoryView = switchView;
    } else if (indexPath.row == 1) {
        cell.textLabel.text = @"仅在录屏显示";
        
        // 添加图标
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 
                                                                                               weight:UIImageSymbolWeightMedium];
            cell.imageView.image = [[UIImage systemImageNamed:@"record.circle.fill" withConfiguration:config]
                                   imageWithTintColor:[UIColor systemRedColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [defaults boolForKey:kTouchTrailOnlyWhenRecordingKey];
        [switchView addTarget:self action:@selector(onlyWhenRecordingChanged:) forControlEvents:UIControlEventValueChanged];
        
        if (@available(iOS 13.0, *)) {
            switchView.onTintColor = [UIColor systemRedColor];
        }
        
        cell.accessoryView = switchView;
    } else if (indexPath.row == 2) {
        cell.textLabel.text = @"使用拖尾效果";
        
        // 添加图标
        if (@available(iOS 13.0, *)) {
            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:16 
                                                                                               weight:UIImageSymbolWeightMedium];
            cell.imageView.image = [[UIImage systemImageNamed:@"sparkles" withConfiguration:config]
                                   imageWithTintColor:[UIColor systemYellowColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [defaults boolForKey:kTouchTrailTailEnabledKey];
        [switchView addTarget:self action:@selector(tailEnabledChanged:) forControlEvents:UIControlEventValueChanged];
        
        if (@available(iOS 13.0, *)) {
            switchView.onTintColor = [UIColor systemYellowColor];
        }
        
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
        
        if (@available(iOS 13.0, *)) {
            self.layer.shadowColor = [UIColor.labelColor CGColor];
        } else {
            self.layer.shadowColor = [UIColor.blackColor CGColor];
        }
        self.layer.shadowOffset = CGSizeMake(0, 1);
        self.layer.shadowOpacity = 0.3;
        self.layer.shadowRadius = 2;
        
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
        
        if (@available(iOS 13.0, *)) {
            self.trailColor = [UIColor.systemRedColor colorWithAlphaComponent:0.7];
        } else {
            self.trailColor = [UIColor.redColor colorWithAlphaComponent:0.7];
        }
        
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
    
    // 创建带有图标的单元格
    WCTableViewCellManager *settingCell = nil;
    if (@available(iOS 13.0, *)) {
        // 创建一个自定义的单元格，带有图标
        settingCell = [%c(WCTableViewCellManager) normalCellForSel:@selector(onDDAssistantClicked) target:self title:PLUGIN_NAME];
    } else {
        settingCell = [%c(WCTableViewCellManager) normalCellForSel:@selector(onDDAssistantClicked) target:self title:PLUGIN_NAME];
    }
    
    [sectionInfo addCell:settingCell];
    [tableViewMgr insertSection:sectionInfo At:0];
    MMTableView *tableView = [tableViewMgr getTableView];
    [tableView reloadData];
    objc_setAssociatedObject(self, &kDDAssistantAddedKey, @(YES), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
%new
- (void)onDDAssistantClicked {
    ModernDDAssistantSettingsViewController *modernVC = [[ModernDDAssistantSettingsViewController alloc] init];
    
    // 使用现代风格导航控制器
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:modernVC];
    
    // 配置iOS 13+模态展示
    if (@available(iOS 13.0, *)) {
        // 配置导航栏外观
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = [UIColor systemBackgroundColor];
        
        navController.navigationBar.standardAppearance = appearance;
        navController.navigationBar.scrollEdgeAppearance = appearance;
        
        navController.modalPresentationStyle = UIModalPresentationPageSheet;
        
        // 配置 sheet 控制器
        if (@available(iOS 15.0, *)) {
            UISheetPresentationController *sheet = navController.sheetPresentationController;
            if (sheet) {
                // 设置首选展开状态为较大
                sheet.preferredCornerRadius = 20;
                sheet.prefersGrabberVisible = YES;
                sheet.detents = @[
                    [UISheetPresentationControllerDetent mediumDetent],
                    [UISheetPresentationControllerDetent largeDetent]
                ];
                sheet.selectedDetentIdentifier = UISheetPresentationControllerDetentIdentifierMedium;
                sheet.prefersScrollingExpandsWhenScrolledToEdge = NO;
            }
        }
    } else {
        navController.modalPresentationStyle = UIModalPresentationFullScreen;
    }
    
    [self presentViewController:navController animated:YES completion:nil];
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
        NSString *title = [msgWrap m_uiGameType] == 1 ? @"请选择石头/剪刀/布" : @"请选择点数";
        
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"请选择" 
                                                                       message:title 
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        
        // 配置现代样式
        if (@available(iOS 13.0, *)) {
            alert.view.tintColor = [UIColor labelColor];
        }
        
        NSArray *actions;
        if ([msgWrap m_uiGameType] == 1) {
            actions = @[@"剪刀", @"石头", @"布"];
        } else {
            actions = @[@"1", @"2", @"3", @"4", @"5", @"6"];
        }
        
        for (int i = 0; i < actions.count; i++) {
            NSString *actionTitle = actions[i];
            UIAlertAction* action = [UIAlertAction actionWithTitle:actionTitle 
                                                             style:UIAlertActionStyleDefault 
                                                           handler:^(UIAlertAction * _Nonnull action) {
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
            
            // 为不同选项添加图标
            if (@available(iOS 13.0, *)) {
                NSString *iconName = @"";
                if ([msgWrap m_uiGameType] == 1) {
                    if (i == 0) iconName = @"scissors";
                    else if (i == 1) iconName = @"circle.fill";
                    else if (i == 2) iconName = @"hand.raised.fill";
                } else {
                    iconName = [NSString stringWithFormat:@"%d.circle.fill", i + 1];
                }
                
                if (iconName.length > 0) {
                    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:18 
                                                                                                       weight:UIImageSymbolWeightMedium];
                    UIImage *icon = [UIImage systemImageNamed:iconName withConfiguration:config];
                    [action setValue:icon forKey:@"image"];
                }
            }
            
            [alert addAction:action];
        }
        
        UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"取消" 
                                                               style:UIAlertActionStyleCancel 
                                                             handler:nil];
        
        if (@available(iOS 13.0, *)) {
            [cancelAction setValue:[UIColor systemRedColor] forKey:@"titleTextColor"];
        }
        
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
        
        if (@available(iOS 13.0, *)) {
            timeLabel.textColor = [UIColor colorWithDynamicProvider:^UIColor * _Nonnull(UITraitCollection * _Nonnull traitCollection) {
                if (traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
                    return [UIColor colorWithWhite:0.7 alpha:0.8];
                } else {
                    return [UIColor colorWithWhite:0.5 alpha:0.8];
                }
            }];
        } else {
            timeLabel.textColor = [UIColor colorWithWhite:0.5 alpha:0.8];
        }
        
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
                    
                    if (@available(iOS 13.0, *)) {
                        trailView.trailColor = [UIColor.systemRedColor colorWithAlphaComponent:0.7];
                    } else {
                        trailView.trailColor = [UIColor.redColor colorWithAlphaComponent:0.7];
                    }
                    
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
                            UIColor *dotColor = nil;
                            if (@available(iOS 13.0, *)) {
                                dotColor = [UIColor.systemOrangeColor colorWithAlphaComponent:0.6];
                            } else {
                                dotColor = [UIColor.orangeColor colorWithAlphaComponent:0.6];
                            }
                            
                            WBTouchTrailDotView *dotView = [[WBTouchTrailDotView alloc] initWithPoint:location 
                                                                                            dotColor:dotColor 
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
                controller:@"ModernDDAssistantSettingsViewController"];
            NSLog(@"[DD助手] 插件已注册到插件管理器 - %@ v%@", PLUGIN_NAME, PLUGIN_VERSION);
        } else {
            g_hasPluginsMgr = NO;
            NSLog(@"[DD助手] 插件管理器未找到，将添加到微信设置页面 - %@ v%@", PLUGIN_NAME, PLUGIN_VERSION);
        }
    }
}
[file content end]