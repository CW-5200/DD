#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface DDBlurConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL blurEnabled;
@end

static NSString * const kDDBlurEnabledKey = @"DDBlurBackgroundEnabled";

@implementation DDBlurConfig

+ (instancetype)sharedConfig {
    static DDBlurConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [DDBlurConfig new];
    });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        _blurEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kDDBlurEnabledKey];
        
        if ([[NSUserDefaults standardUserDefaults] objectForKey:kDDBlurEnabledKey] == nil) {
            _blurEnabled = NO;
            [[NSUserDefaults standardUserDefaults] setBool:_blurEnabled forKey:kDDBlurEnabledKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
    return self;
}

- (void)setBlurEnabled:(BOOL)blurEnabled {
    _blurEnabled = blurEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:blurEnabled forKey:kDDBlurEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

@interface DDBlurSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation DDBlurSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD后台模糊";
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
    NSString *cellIdentifier = @"DDBlurSwitchCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    
    cell.textLabel.text = @"后台模糊";
    
    UISwitch *switchView = [[UISwitch alloc] init];
    switchView.onTintColor = [UIColor systemBlueColor];
    switchView.on = [DDBlurConfig sharedConfig].blurEnabled;
    [switchView addTarget:self action:@selector(blurSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    cell.accessoryView = switchView;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 20.0;
}

- (void)blurSwitchChanged:(UISwitch *)sender {
    [DDBlurConfig sharedConfig].blurEnabled = sender.isOn;
}

@end

@interface MicroMessengerAppDelegate : UIResponder <UIApplicationDelegate>
@property (strong, nonatomic) UIWindow *window;
@end

static UIVisualEffectView *_blurView = nil;

%hook MicroMessengerAppDelegate

- (void)applicationDidEnterBackground:(UIApplication*)application 
{
    %orig;
    
    if (![DDBlurConfig sharedConfig].blurEnabled || !self.window)
        return;

    if (!_blurView) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        _blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        _blurView.frame = self.window.bounds;
    } else {
        _blurView.frame = self.window.bounds;
    }
    
    [self.window addSubview:_blurView];
}

- (void)applicationWillEnterForeground:(UIApplication*)application
{
    %orig;
    
    if (_blurView) {
        [_blurView removeFromSuperview];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    %orig;
    
    if (_blurView && _blurView.superview) {
        [_blurView removeFromSuperview];
    }
}

%end

%ctor {
    @autoreleasepool {
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD后台模糊" 
                version:@"1.0.0" 
                controller:@"DDBlurSettingsViewController"];
        }
    }
}