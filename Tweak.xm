#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

// 插件管理接口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

// 设置页面控制器
@interface VirtualVideoSettingsController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *videoOptions;
@property (nonatomic, strong) NSString *selectedVideo;
@end

@implementation VirtualVideoSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"虚拟视频设置";
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 视频选项
    self.videoOptions = @[@"视频1", @"视频2"];
    
    // 加载已选择的视频
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    self.selectedVideo = [defaults stringForKey:@"SelectedVideo"] ?: @"视频1";
    
    // 创建表格
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tableView];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 2; // 启用开关
    } else {
        return self.videoOptions.count; // 视频选项
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"插件开关";
    } else {
        return @"选择视频源";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    if (indexPath.section == 0) {
        // 启用开关
        cell.textLabel.text = @"启用虚拟视频";
        
        // 创建开关
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"VirtualVideoEnabled"];
        [switchView addTarget:self action:@selector(toggleEnabled:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    } else {
        // 视频选项
        NSString *videoName = self.videoOptions[indexPath.row];
        cell.textLabel.text = videoName;
        
        // 显示选中标记
        if ([videoName isEqualToString:self.selectedVideo]) {
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        } else {
            cell.accessoryType = UITableViewCellAccessoryNone;
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 1) {
        // 选择视频
        NSString *selectedVideo = self.videoOptions[indexPath.row];
        self.selectedVideo = selectedVideo;
        
        // 保存选择
        [[NSUserDefaults standardUserDefaults] setObject:selectedVideo forKey:@"SelectedVideo"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        // 重新加载表格
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
    }
}

#pragma mark - 开关事件

- (void)toggleEnabled:(UISwitch *)switchView {
    [[NSUserDefaults standardUserDefaults] setBool:switchView.isOn forKey:@"VirtualVideoEnabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

// 全局变量
static BOOL isVideoReplaceEnabled = NO;
static NSString *selectedVideoPath = nil;
static UIViewController *currentViewController = nil;
static NSTimeInterval lastStatusBarTapTime = 0;
static int statusBarTapCount = 0;

// 函数声明
static void showVideoSelectionMenu(void);
static void handleVideoSelection(NSString *videoName);
static void setupVideoReplacement(void);
static void disableVideoReplacement(void);
static void showAlert(NSString *message);
static void setupStatusBarTripleTap(UIViewController *viewController);
static void checkStatusBarTripleTap(void);

// 显示弹窗
static void showAlert(NSString *message) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"虚拟视频" 
                                                                        message:message 
                                                                 preferredStyle:UIAlertControllerStyleAlert];
            
            UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确定" 
                                                            style:UIAlertActionStyleDefault 
                                                          handler:nil];
            [alert addAction:okAction];
            
            UIWindow *window = [UIApplication sharedApplication].keyWindow;
            if (!window) {
                window = [[UIApplication sharedApplication].windows firstObject];
            }
            
            if (window) {
                UIViewController *rootVC = window.rootViewController;
                while (rootVC.presentedViewController) {
                    rootVC = rootVC.presentedViewController;
                }
                [rootVC presentViewController:alert animated:YES completion:nil];
            }
        } @catch (NSException *exception) {
            NSLog(@"显示弹窗错误: %@", exception);
        }
    });
}

// 检查状态栏三击
static void checkStatusBarTripleTap(void) {
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval timeDiff = currentTime - lastStatusBarTapTime;
    
    if (timeDiff < 0.8) { // 0.8秒内完成三击
        statusBarTapCount++;
        
        if (statusBarTapCount >= 3) {
            statusBarTapCount = 0;
            showVideoSelectionMenu();
        }
    } else {
        statusBarTapCount = 1; // 重新开始计数
    }
    
    lastStatusBarTapTime = currentTime;
}

// 设置状态栏三击检测
static void setupStatusBarTripleTap(UIViewController *viewController) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        if (!window) {
            window = [[UIApplication sharedApplication].windows firstObject];
        }
        
        if (window) {
            // 创建状态栏区域的触摸检测视图
            UIView *tapView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, window.bounds.size.width, 44)];
            tapView.tag = 8888;
            tapView.userInteractionEnabled = YES;
            tapView.backgroundColor = [UIColor clearColor];
            
            // 移除旧的视图
            for (UIView *subview in window.subviews) {
                if (subview.tag == 8888) {
                    [subview removeFromSuperview];
                    break;
                }
            }
            
            // 添加三击手势
            UITapGestureRecognizer *tripleTap = [[UITapGestureRecognizer alloc] initWithTarget:viewController 
                                                                                        action:@selector(handleStatusBarTripleTap:)];
            tripleTap.numberOfTapsRequired = 3;
            [tapView addGestureRecognizer:tripleTap];
            
            [window addSubview:tapView];
            [window bringSubviewToFront:tapView];
        }
    });
}

// 处理视频选择
static void handleVideoSelection(NSString *videoName) {
    NSLog(@"已选择视频: %@", videoName);
    
    // 保存视频选择
    [[NSUserDefaults standardUserDefaults] setObject:videoName forKey:@"SelectedVideo"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 设置视频路径
    NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *videosPath = [documentsPath stringByAppendingPathComponent:@"Videos"];
    selectedVideoPath = [videosPath stringByAppendingPathComponent:videoName];
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:selectedVideoPath]) {
        isVideoReplaceEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"VirtualVideoEnabled"];
        if (isVideoReplaceEnabled) {
            setupVideoReplacement();
        }
        showAlert([NSString stringWithFormat:@"已选择: %@\n请确保插件已启用", videoName]);
    } else {
        showAlert(@"视频文件不存在\n请将视频文件放入Documents/Videos目录");
    }
}

// 视频选择菜单
static void showVideoSelectionMenu(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"虚拟视频"
                                                                    message:@"请选择一个视频源"
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
        
        // 添加启用/禁用选项
        BOOL isEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"VirtualVideoEnabled"];
        NSString *enableTitle = isEnabled ? @"禁用插件" : @"启用插件";
        UIAlertAction *enableAction = [UIAlertAction actionWithTitle:enableTitle
                                                             style:isEnabled ? UIAlertActionStyleDestructive : UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * _Nonnull action) {
            BOOL newState = !isEnabled;
            [[NSUserDefaults standardUserDefaults] setBool:newState forKey:@"VirtualVideoEnabled"];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            if (newState) {
                isVideoReplaceEnabled = YES;
                NSString *selectedVideo = [[NSUserDefaults standardUserDefaults] stringForKey:@"SelectedVideo"] ?: @"视频1";
                handleVideoSelection(selectedVideo);
            } else {
                isVideoReplaceEnabled = NO;
                showAlert(@"插件已禁用");
            }
        }];
        [alert addAction:enableAction];
        
        // 添加取消操作
        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消"
                                                             style:UIAlertActionStyleCancel
                                                           handler:nil];
        [alert addAction:cancelAction];
        
        // 显示菜单
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            NSSet *connectedScenes = [UIApplication sharedApplication].connectedScenes;
            for (UIScene *scene in connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *window in windowScene.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                    if (keyWindow) break;
                }
            }
        } else {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }
        
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].windows.firstObject;
        }
        
        if (keyWindow) {
            UIViewController *topController = keyWindow.rootViewController;
            while (topController.presentedViewController) {
                topController = topController.presentedViewController;
            }
            
            if (topController) {
                [topController presentViewController:alert animated:YES completion:nil];
            }
        }
    });
}

// 设置视频替换
static void setupVideoReplacement(void) {
    if (!isVideoReplaceEnabled || !selectedVideoPath) {
        return;
    }
    
    NSLog(@"正在设置视频替换...");
    // 这里添加视频替换的具体实现
    // 注意：实际实现需要复杂的视频流处理
}

// 禁用视频替换
static void disableVideoReplacement(void) {
    isVideoReplaceEnabled = NO;
    selectedVideoPath = nil;
    NSLog(@"已禁用视频替换");
}

// 摄像头钩子
%hook AVCaptureDevice

+ (id)deviceWithUniqueID:(id)arg1 {
    if (isVideoReplaceEnabled && selectedVideoPath) {
        NSLog(@"虚拟视频: 正在替换摄像头输入...");
        // 这里返回自定义的视频源
        return nil;
    }
    return %orig;
}

%end

// 视频会话钩子
%hook AVCaptureSession

- (void)startRunning {
    if (isVideoReplaceEnabled && selectedVideoPath) {
        NSLog(@"虚拟视频: 启动视频会话...");
        // 处理自定义视频会话
        return;
    }
    %orig;
}

%end

// UIViewController扩展
%hook UIViewController

%new
- (void)handleStatusBarTripleTap:(UITapGestureRecognizer *)gesture {
    checkStatusBarTripleTap();
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    currentViewController = self;
    
    // 设置状态栏三击检测
    setupStatusBarTripleTap(self);
    
    // 加载设置
    isVideoReplaceEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"VirtualVideoEnabled"];
    NSString *selectedVideo = [[NSUserDefaults standardUserDefaults] stringForKey:@"SelectedVideo"];
    if (selectedVideo) {
        handleVideoSelection(selectedVideo);
    }
}

%end

// 构造函数 - 插件入口
%ctor {
    @autoreleasepool {
        NSLog(@"虚拟视频插件 v1.0.0 已加载");
        
        // 初始化默认设置
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults objectForKey:@"VirtualVideoEnabled"]) {
            [defaults setBool:YES forKey:@"VirtualVideoEnabled"];
        }
        if (![defaults objectForKey:@"SelectedVideo"]) {
            [defaults setObject:@"视频1" forKey:@"SelectedVideo"];
        }
        [defaults synchronize];
        
        // 注册到插件管理器
        if (NSClassFromString(@"WCPluginsMgr")) {
            // 注册设置页面
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"虚拟视频" 
                                                                               version:@"1.0.0" 
                                                                            controller:@"VirtualVideoSettingsController"];
            
            // 注册开关
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerSwitchWithTitle:@"虚拟视频" 
                                                                                key:@"VirtualVideoEnabled"];
            
            NSLog(@"已注册到插件管理器");
        }
        
        // 初始化变量
        isVideoReplaceEnabled = [defaults boolForKey:@"VirtualVideoEnabled"];
        NSString *selectedVideo = [defaults stringForKey:@"SelectedVideo"];
        if (selectedVideo) {
            NSString *documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
            NSString *videosPath = [documentsPath stringByAppendingPathComponent:@"Videos"];
            selectedVideoPath = [videosPath stringByAppendingPathComponent:selectedVideo];
        }
    }
}