#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

// 插件名称和版本
#define PLUGIN_NAME @"虚拟视频"
#define PLUGIN_VERSION @"1.0.0"

// 插件管理接口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

// 设置控制器
@interface VirtualVideoSettingsController : UIViewController <UITableViewDataSource, UITableViewDelegate>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *videoOptions;
@property (nonatomic, strong) NSString *selectedVideo;
@property (nonatomic, assign) BOOL isEnabled;
@end

@implementation VirtualVideoSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = PLUGIN_NAME;
    self.videoOptions = @[@"视频1", @"视频2"];
    
    // 加载设置
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.selectedVideo = [defaults objectForKey:@"VirtualVideo_Selected"] ?: @"视频1";
    self.isEnabled = [defaults boolForKey:@"VirtualVideo_Enabled"];
    
    // 创建表格视图
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    return self.videoOptions.count;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) return @"插件开关";
    return @"选择视频";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
    }
    
    if (indexPath.section == 0) {
        cell.textLabel.text = @"启用虚拟视频";
        UISwitch *switchControl = [[UISwitch alloc] init];
        switchControl.on = self.isEnabled;
        [switchControl addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchControl;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        NSString *videoName = self.videoOptions[indexPath.row];
        cell.textLabel.text = videoName;
        cell.accessoryType = [videoName isEqualToString:self.selectedVideo] ? 
            UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (void)switchChanged:(UISwitch *)sender {
    self.isEnabled = sender.isOn;
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.isEnabled forKey:@"VirtualVideo_Enabled"];
    [defaults synchronize];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 1) {
        self.selectedVideo = self.videoOptions[indexPath.row];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:self.selectedVideo forKey:@"VirtualVideo_Selected"];
        [defaults synchronize];
        
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:1] 
                 withRowAnimation:UITableViewRowAnimationNone];
    }
}

@end

// 全局变量
static BOOL isVideoReplaceEnabled = NO;
static NSString *selectedVideoPath = nil;
static int statusBarTapCount = 0;
static NSTimeInterval lastStatusBarTapTime = 0;

// 前向声明
static void showVideoSelectionMenu(void);
static void handleVideoSelection(NSString *videoName);
static void setupVideoReplacement(void);
static void disableVideoReplacement(void);
static void setupStatusBarTripleTap(UIViewController *viewController);
static void createSampleVideoAtPath(NSString *path);

// 摄像头相关接口
@interface AVCaptureDevice (Private)
+ (id)deviceWithUniqueID:(id)arg1;
@end

// 钩子AVCaptureDevice
%hook AVCaptureDevice

+ (id)deviceWithUniqueID:(id)arg1 {
    if (isVideoReplaceEnabled && selectedVideoPath) {
        // 检查是否启用并选择了视频
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL enabled = [defaults boolForKey:@"VirtualVideo_Enabled"];
        if (enabled) {
            // 返回虚拟视频设备
            // 这里需要实现实际的视频源替换
            // 暂时返回原始设备
        }
    }
    return %orig;
}

%end

// 钩子AVCaptureSession
%hook AVCaptureSession

- (void)startRunning {
    if (isVideoReplaceEnabled && selectedVideoPath) {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL enabled = [defaults boolForKey:@"VirtualVideo_Enabled"];
        if (enabled) {
            // 启动虚拟视频会话
            setupVideoReplacement();
            return;
        }
    }
    %orig;
}

%end

// 创建示例视频（修复了self错误）
static void createSampleVideoAtPath(NSString *path) {
    // 这里可以创建示例视频文件的代码
    // 暂时留空
    // 示例：创建目录
    NSString *directory = [path stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
}

// 设置视频替换
static void setupVideoReplacement(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *selectedVideo = [defaults objectForKey:@"VirtualVideo_Selected"] ?: @"视频1";
    BOOL enabled = [defaults boolForKey:@"VirtualVideo_Enabled"];
    
    if (!enabled) {
        disableVideoReplacement();
        return;
    }
    
    // 设置视频路径
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *videosPath = [documentsPath stringByAppendingPathComponent:@"VirtualVideo"];
    selectedVideoPath = [videosPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.mp4", selectedVideo]];
    
    // 检查视频文件是否存在
    if ([[NSFileManager defaultManager] fileExistsAtPath:selectedVideoPath]) {
        isVideoReplaceEnabled = YES;
        // 这里可以添加视频替换的具体实现
    } else {
        // 视频文件不存在，创建示例视频
        createSampleVideoAtPath(selectedVideoPath);
        isVideoReplaceEnabled = YES;
    }
}

// 禁用视频替换
static void disableVideoReplacement(void) {
    isVideoReplaceEnabled = NO;
    selectedVideoPath = nil;
}

// 处理视频选择
static void handleVideoSelection(NSString *videoName) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:videoName forKey:@"VirtualVideo_Selected"];
    [defaults synchronize];
    
    // 重新设置视频替换
    setupVideoReplacement();
}

// 获取当前活动窗口（适配iOS 13.0+）
static UIWindow *getActiveWindow(void) {
    UIWindow *activeWindow = nil;
    
    if (@available(iOS 13.0, *)) {
        NSSet *connectedScenes = [UIApplication sharedApplication].connectedScenes;
        for (UIScene *scene in connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive && 
                [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *window in windowScene.windows) {
                    if (window.isKeyWindow) {
                        activeWindow = window;
                        break;
                    }
                }
                if (activeWindow) break;
            }
        }
    } else {
        activeWindow = [[UIApplication sharedApplication] windows].firstObject;
    }
    
    return activeWindow;
}

// 显示视频选择菜单
static void showVideoSelectionMenu(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 检查是否启用插件
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        BOOL enabled = [defaults boolForKey:@"VirtualVideo_Enabled"];
        
        if (!enabled) {
            return;
        }
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:PLUGIN_NAME
                                                                       message:@"请选择虚拟视频"
                                                                preferredStyle:UIAlertControllerStyleActionSheet];
        
        // 添加视频选项
        NSArray *videos = @[@"视频1", @"视频2"];
        for (NSString *video in videos) {
            UIAlertAction *action = [UIAlertAction actionWithTitle:video
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
                handleVideoSelection(video);
            }];
            [alert addAction:action];
        }
        
        // 添加取消操作
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                               style:UIAlertActionStyleCancel
                                                             handler:nil];
        [alert addAction:cancelAction];
        
        // 添加设置选项
        UIAlertAction *settingsAction = [UIAlertAction actionWithTitle:@"插件设置"
                                                                 style:UIAlertActionStyleDefault
                                                               handler:^(UIAlertAction * _Nonnull action) {
            // 跳转到设置页面
            VirtualVideoSettingsController *settings = [[VirtualVideoSettingsController alloc] init];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
            nav.modalPresentationStyle = UIModalPresentationFormSheet;
            
            UIWindow *window = getActiveWindow();
            
            if (window) {
                UIViewController *topController = window.rootViewController;
                while (topController.presentedViewController) {
                    topController = topController.presentedViewController;
                }
                [topController presentViewController:nav animated:YES completion:nil];
            }
        }];
        [alert addAction:settingsAction];
        
        // 查找顶层视图控制器
        UIWindow *window = getActiveWindow();
        
        if (window) {
            UIViewController *topController = window.rootViewController;
            while (topController.presentedViewController) {
                topController = topController.presentedViewController;
            }
            
            [topController presentViewController:alert animated:YES completion:nil];
        }
    });
}

// 状态栏三击检测
static void setupStatusBarTripleTap(UIViewController *viewController) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = getActiveWindow();
        
        if (window) {
            // 创建一个覆盖状态栏区域的视图
            UIView *tapView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, window.bounds.size.width, 40)];
            tapView.backgroundColor = [UIColor clearColor];
            tapView.tag = 20241213; // 使用唯一tag
            tapView.userInteractionEnabled = YES;
            
            // 移除旧的视图
            for (UIView *subview in window.subviews) {
                if (subview.tag == 20241213) {
                    [subview removeFromSuperview];
                    break;
                }
            }
            
            // 添加三击手势识别器
            UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:viewController 
                                                                                        action:@selector(handleStatusBarTripleTap:)];
            tripleTap.numberOfTapsRequired = 3;
            tripleTap.numberOfTouchesRequired = 1;
            [tapView addGestureRecognizer:tripleTap];
            
            // 添加单击手势以避免干扰其他操作
            UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:nil action:nil];
            singleTap.numberOfTapsRequired = 1;
            [tapView addGestureRecognizer:singleTap];
            
            [window addSubview:tapView];
            [window bringSubviewToFront:tapView];
        }
    });
}

// 钩子UIViewController
%hook UIViewController

// 状态栏三击处理
%new
- (void)handleStatusBarTripleTap:(UITapGestureRecognizer *)gesture {
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    
    // 检查时间间隔，确保是快速三击
    if (currentTime - lastStatusBarTapTime > 1.0) {
        statusBarTapCount = 0;
    }
    
    statusBarTapCount++;
    lastStatusBarTapTime = currentTime;
    
    if (statusBarTapCount >= 3) {
        statusBarTapCount = 0;
        showVideoSelectionMenu();
    }
}

// 视图控制器出现时设置状态栏点击检测
- (void)viewDidAppear:(BOOL)animated {
    %orig;
    
    // 只在iOS 15.0+系统运行
    if (@available(iOS 15.0, *)) {
        // 设置状态栏三击检测
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            setupStatusBarTripleTap(self);
        });
    }
}

%end

// 插件构造函数
%ctor {
    @autoreleasepool {
        // 检查iOS版本
        if (@available(iOS 15.0, *)) {
            // 注册到插件管理器
            Class WCPluginsMgrClass = NSClassFromString(@"WCPluginsMgr");
            if (WCPluginsMgrClass) {
                // 注册带设置页面的插件
                [[WCPluginsMgrClass sharedInstance] registerControllerWithTitle:PLUGIN_NAME 
                                                                       version:PLUGIN_VERSION 
                                                                    controller:@"VirtualVideoSettingsController"];
                
                // 也可以同时注册开关
                [[WCPluginsMgrClass sharedInstance] registerSwitchWithTitle:PLUGIN_NAME 
                                                                        key:@"VirtualVideo_Enabled"];
            }
            
            // 初始化默认设置
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            if (![defaults objectForKey:@"VirtualVideo_Enabled"]) {
                [defaults setBool:YES forKey:@"VirtualVideo_Enabled"];
            }
            if (![defaults objectForKey:@"VirtualVideo_Selected"]) {
                [defaults setObject:@"视频1" forKey:@"VirtualVideo_Selected"];
            }
            [defaults synchronize];
            
            // 设置初始状态
            setupVideoReplacement();
        }
    }
}