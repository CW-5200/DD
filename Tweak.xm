#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 插件管理接口

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

#pragma mark - 配置管理

@interface DDForwardConfig : NSObject

+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL forwardEnabled;

@end

static NSString * const kDDForwardEnabledKey = @"DDForwardEnabledKey";

@implementation DDForwardConfig

+ (instancetype)sharedConfig {
    static DDForwardConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [DDForwardConfig new];
    });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        _forwardEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kDDForwardEnabledKey];
    }
    return self;
}

- (void)setForwardEnabled:(BOOL)forwardEnabled {
    _forwardEnabled = forwardEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:forwardEnabled forKey:kDDForwardEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

#pragma mark - 设置界面

@interface DDForwardSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation DDForwardSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD朋友圈转发";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = @"DDForwardSwitchCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    
    cell.textLabel.text = @"启用朋友圈转发";
    
    UISwitch *switchView = [[UISwitch alloc] init];
    switchView.onTintColor = [UIColor systemBlueColor];
    switchView.on = [DDForwardConfig sharedConfig].forwardEnabled;
    [switchView addTarget:self action:@selector(forwardSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    cell.accessoryView = switchView;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 20.0;
}

- (void)forwardSwitchChanged:(UISwitch *)sender {
    [DDForwardConfig sharedConfig].forwardEnabled = sender.isOn;
}

@end

#pragma mark - 转发功能实现

@interface WCOperateFloatView : UIView
@property(readonly, nonatomic) UIButton *m_likeBtn;
@property(readonly, nonatomic) id m_item;
@property(nonatomic) __weak UINavigationController *navigationController;
- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2;
- (double)buttonWidth:(id)arg1;
@end

@interface WCForwardViewController : UIViewController
- (id)initWithDataItem:(id)arg1;
@end

@implementation UIImage (ForwardIcon)

+ (UIImage *)forwardIcon {
    static UIImage *icon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(18, 18), NO, 0.0);
        
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
        CGContextSetLineWidth(ctx, 1.2);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        
        CGFloat p = 4.0;
        CGContextMoveToPoint(ctx, p, p);
        CGContextAddLineToPoint(ctx, 18 - p, 9);
        CGContextAddLineToPoint(ctx, p, 18 - p);
        
        CGContextMoveToPoint(ctx, 18 - p - 1.5, 5);
        CGContextAddLineToPoint(ctx, 18 - p - 1.5, 13);
        
        CGContextStrokePath(ctx);
        
        icon = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    });
    return icon;
}

@end

%hook WCOperateFloatView

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig(arg1, arg2);
    
    if (![DDForwardConfig sharedConfig].forwardEnabled) {
        return;
    }
    
    UIButton *likeBtn = [self valueForKey:@"m_likeBtn"];
    if (!likeBtn) return;
    
    UIColor *titleColor = [likeBtn titleColorForState:UIControlStateNormal];
    if (!titleColor) titleColor = [UIColor whiteColor];
    
    static char shareBtnKey;
    UIButton *shareBtn = objc_getAssociatedObject(self, &shareBtnKey);
    if (!shareBtn) {
        shareBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [shareBtn setTitle:@" 转发" forState:UIControlStateNormal];
        [shareBtn setTitleColor:titleColor forState:UIControlStateNormal];
        shareBtn.titleLabel.font = likeBtn.titleLabel.font;
        [shareBtn setImage:[UIImage forwardIcon] forState:UIControlStateNormal];
        [shareBtn addTarget:self action:@selector(xxx_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        [likeBtn.superview addSubview:shareBtn];
        objc_setAssociatedObject(self, &shareBtnKey, shareBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    static char lineViewKey;
    UIImageView *lineView2 = objc_getAssociatedObject(self, &lineViewKey);
    if (!lineView2) {
        Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
        UIImageView *originalLineView = lineViewIvar ? object_getIvar(self, lineViewIvar) : nil;
        
        if (originalLineView && [originalLineView isKindOfClass:[UIImageView class]]) {
            lineView2 = [[UIImageView alloc] initWithImage:originalLineView.image];
            [likeBtn.superview addSubview:lineView2];
            objc_setAssociatedObject(self, &lineViewKey, lineView2, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    UIView *view = (UIView *)self;
    CGRect frame = view.frame;
    frame = CGRectOffset(CGRectInset(frame, frame.size.width / -4, 0), frame.size.width / -4, 0);
    view.frame = frame;
    
    shareBtn.frame = CGRectOffset(likeBtn.frame, likeBtn.frame.size.width * 2, 0);
    
    if (lineView2) {
        Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
        UIImageView *originalLineView = lineViewIvar ? object_getIvar(self, lineViewIvar) : nil;
        
        if (originalLineView) {
            SEL buttonWidthSel = @selector(buttonWidth:);
            if ([self respondsToSelector:buttonWidthSel]) {
                IMP imp = [self methodForSelector:buttonWidthSel];
                CGFloat (*func)(id, SEL, id) = (CGFloat (*)(id, SEL, id))imp;
                CGFloat width = func(self, buttonWidthSel, likeBtn);
                lineView2.frame = CGRectOffset(originalLineView.frame, width, 0);
            }
        }
    }
}

- (void)xxx_forwordTimeLine:(id)sender {
    id dataItem = [self valueForKey:@"m_item"];
    if (dataItem) {
        Class forwardVCClass = objc_getClass("WCForwardViewController");
        if (forwardVCClass) {
            WCForwardViewController *forwardVC = [[forwardVCClass alloc] initWithDataItem:dataItem];
            UINavigationController *navController = [self valueForKey:@"navigationController"];
            if (navController) {
                [navController pushViewController:forwardVC animated:YES];
            }
        }
    }
}

%end

#pragma mark - 插件注册

%ctor {
    @autoreleasepool {
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD朋友圈转发" 
                version:@"1.0.0" 
                controller:@"DDForwardSettingsViewController"];
        }
    }
}