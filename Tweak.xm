// DDMomentsAdRemover.xm
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 插件管理接口声明

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

#pragma mark - 配置管理

@interface DDMomentsAdRemoverConfig : NSObject

+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL enabled;

@end

static NSString * const kDDMomentsAdRemoverEnabledKey = @"DDMomentsAdRemoverEnabled";

@implementation DDMomentsAdRemoverConfig

+ (instancetype)sharedConfig {
    static DDMomentsAdRemoverConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [DDMomentsAdRemoverConfig new];
    });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        _enabled = [[NSUserDefaults standardUserDefaults] boolForKey:kDDMomentsAdRemoverEnabledKey];
        
        if ([[NSUserDefaults standardUserDefaults] objectForKey:kDDMomentsAdRemoverEnabledKey] == nil) {
            _enabled = NO;
            [[NSUserDefaults standardUserDefaults] setBool:_enabled forKey:kDDMomentsAdRemoverEnabledKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
    return self;
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kDDMomentsAdRemoverEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

#pragma mark - 设置界面

@interface DDMomentsAdRemoverSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation DDMomentsAdRemoverSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD朋友圈去广告";
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
    NSString *cellIdentifier = @"DDMomentsAdRemoverSwitchCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    
    cell.textLabel.text = @"朋友圈广告屏蔽";
    
    UISwitch *switchView = [[UISwitch alloc] init];
    switchView.onTintColor = [UIColor systemBlueColor];
    switchView.on = [DDMomentsAdRemoverConfig sharedConfig].enabled;
    [switchView addTarget:self action:@selector(adSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    cell.accessoryView = switchView;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 20.0;
}

- (void)adSwitchChanged:(UISwitch *)sender {
    [DDMomentsAdRemoverConfig sharedConfig].enabled = sender.isOn;
}

@end

#pragma mark - Hook逻辑

%hook WCAdvertiseStorage

- (void)setOAdvertiseData:(NSData *)oAdvertiseData {
    if (![DDMomentsAdRemoverConfig sharedConfig].enabled) {
        %orig;
        return;
    }
    
    return;
}

%end

#pragma mark - 插件注册

%ctor {
    @autoreleasepool {
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD朋友圈去广告" 
                version:@"1.0.0" 
                controller:@"DDMomentsAdRemoverSettingsViewController"];
        }
    }
}