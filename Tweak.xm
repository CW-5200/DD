//  DD朋友圈转发.m
//  DD朋友圈转发插件 v1.0.0
//  基于DKWechatHelper提取的核心功能
//
//  Created by DKJone
//  Copyright © 2023 DD插件. All rights reserved.

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// MARK: - 插件配置
#define DDTimeLineForwardEnableKey @"DDTimeLineForwardEnable"

// MARK: - 微信核心类声明
@interface WCDataItem : NSObject
@property(retain, nonatomic) NSString *contentDesc;
@property(retain, nonatomic) id contentObj;
@end

@interface WCNewCommitViewController : UIViewController
@end

@interface WCForwardViewController : WCNewCommitViewController
- (id)initWithDataItem:(id)arg1;
@end

@interface WCOperateFloatView : UIView {
    UIImageView *m_lineView;
}
@property(readonly, nonatomic) UIButton *m_likeBtn;
@property(readonly, nonatomic) id m_item;
@property(nonatomic, weak) UINavigationController *navigationController;
@property(nonatomic, strong) UIButton *m_shareBtn;
@property(nonatomic, strong) UIImageView *m_lineView2;
- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2;
- (double)buttonWidth:(id)arg1;
- (void)hide;
- (void)forwordTimeLine:(id)arg1;
@end

@interface WCTableViewNormalCellManager : NSObject
+ (WCTableViewNormalCellManager *)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3;
+ (WCTableViewNormalCellManager *)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
@end

@interface MMUIViewController : UIViewController
@end

// MARK: - 插件配置管理
@interface DDTimeLineForwardConfig : NSObject
+ (BOOL)isEnabled;
+ (void)setEnabled:(BOOL)enabled;
@end

@implementation DDTimeLineForwardConfig

+ (BOOL)isEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:DDTimeLineForwardEnableKey];
}

+ (void)setEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:DDTimeLineForwardEnableKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

// MARK: - 插件设置控制器
@interface DDTimeLineForwardSettingController : MMUIViewController
@property (nonatomic, strong) id tableViewManager;
@end

@implementation DDTimeLineForwardSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD朋友圈转发设置";
    
    // 设置背景色
    self.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    
    // 创建表格
    CGRect frame = CGRectMake(0, 88, self.view.bounds.size.width, self.view.bounds.size.height - 88);
    self.tableViewManager = [[objc_getClass("MMTableViewInfo") alloc] initWithFrame:frame style:UITableViewStyleGrouped];
    
    // 获取section管理器
    id sectionManager = [objc_getClass("WCTableViewSectionManager") defaultSection];
    
    // 添加开关
    id switchCell = [objc_getClass("WCTableViewNormalCellManager") switchCellForSel:@selector(switchChanged:) 
                                                                              target:self 
                                                                              title:@"开启朋友圈转发" 
                                                                                 on:[DDTimeLineForwardConfig isEnabled]];
    [sectionManager addCell:switchCell];
    
    // 添加说明
    id descCell = [objc_getClass("WCTableViewNormalCellManager") normalCellForSel:nil 
                                                                           target:nil 
                                                                           title:@"说明：开启后在朋友圈长按可显示转发按钮"];
    [sectionManager addCell:descCell];
    
    // 将section添加到manager
    [self.tableViewManager addSection:sectionManager];
    
    // 将表格添加到视图
    id tableView = [self.tableViewManager getTableView];
    [self.view addSubview:tableView];
    
    // 添加导航按钮
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"返回" 
                                                                             style:UIBarButtonItemStylePlain 
                                                                            target:self 
                                                                            action:@selector(backAction)];
}

- (void)switchChanged:(UISwitch *)sender {
    [DDTimeLineForwardConfig setEnabled:sender.isOn];
}

- (void)backAction {
    [self.navigationController popViewControllerAnimated:YES];
}

@end

// MARK: - WCOperateFloatView 扩展 (添加转发功能)
@implementation NSObject (DDTimeLineForward)

// 动态添加分享按钮属性
- (UIButton *)dd_shareBtn {
    static char dd_shareBtnKey;
    UIButton *btn = objc_getAssociatedObject(self, &dd_shareBtnKey);
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(dd_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        // 使用动态颜色获取，与点赞按钮保持一致
        WCOperateFloatView *floatView = (WCOperateFloatView *)self;
        [btn setTitleColor:[floatView.m_likeBtn currentTitleColor] forState:UIControlStateNormal];
        btn.titleLabel.font = floatView.m_likeBtn.titleLabel.font;
        
        // 设置转发图标（使用原始base64字符串）
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaAZWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+rBvxtzjw8zsdX0+P9+F9O4zBeGg2HfQPudfVqA8HzKzQzLrz7qvZ0z8zUzUzOzNTfTbne0u7r2tWdvb1k+Fk2ZvZmpjptdmwPwTEOzWz/2f35N3A9f38X6b7WvtXxL7/8P/AJLmZ2aGbbhx65AAAAAElFTkSuQmCC";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:UIControlStateNormal];
        [btn setTintColor:floatView.m_likeBtn.tintColor];
        
        [floatView.m_likeBtn.superview addSubview:btn];
        objc_setAssociatedObject(self, &dd_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

// 动态添加分割线属性
- (UIImageView *)dd_lineView2 {
    static char dd_lineView2Key;
    UIImageView *imageView = objc_getAssociatedObject(self, &dd_lineView2Key);
    if (!imageView) {
        // 使用原始分割线的图片
        WCOperateFloatView *floatView = (WCOperateFloatView *)self;
        
        // 获取原始分割线的实例变量
        Ivar lineViewIvar = class_getInstanceVariable([floatView class], "m_lineView");
        UIImageView *originalLineView = object_getIvar(floatView, lineViewIvar);
        
        if (originalLineView && originalLineView.image) {
            imageView = [[UIImageView alloc] initWithImage:originalLineView.image];
        } else {
            // 备用：创建默认分割线
            imageView = [[UIImageView alloc] init];
            imageView.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
            imageView.frame = CGRectMake(0, 0, 1, 20);
        }
        
        [floatView.m_likeBtn.superview addSubview:imageView];
        objc_setAssociatedObject(self, &dd_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return imageView;
}

// 转发按钮点击事件
- (void)dd_forwordTimeLine:(id)arg1 {
    if (![DDTimeLineForwardConfig isEnabled]) return;
    
    WCOperateFloatView *floatView = (WCOperateFloatView *)self;
    WCForwardViewController *forwardVC = [[objc_getClass("WCForwardViewController") alloc] initWithDataItem:floatView.m_item];
    if (forwardVC && floatView.navigationController) {
        [floatView.navigationController pushViewController:forwardVC animated:YES];
    }
    [floatView hide];
}

// Hook显示方法
- (void)dd_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    // 调用原始方法
    [self dd_showWithItemData:arg1 tipPoint:arg2];
    
    if (![DDTimeLineForwardConfig isEnabled]) return;
    
    WCOperateFloatView *floatView = (WCOperateFloatView *)self;
    
    // 调整浮窗大小和位置以容纳转发按钮
    CGRect frame = floatView.frame;
    frame.size.width = frame.size.width * 1.5;
    frame.origin.x = frame.origin.x - frame.size.width / 3;
    floatView.frame = frame;
    
    // 添加转发按钮
    UIButton *shareBtn = [floatView dd_shareBtn];
    CGRect likeBtnFrame = [floatView.m_likeBtn frame];
    shareBtn.frame = CGRectOffset(likeBtnFrame, likeBtnFrame.size.width * 2, 0);
    
    // 添加分割线
    UIImageView *lineView2 = [floatView dd_lineView2];
    
    // 获取原始分割线位置
    Ivar lineViewIvar = class_getInstanceVariable([floatView class], "m_lineView");
    UIImageView *originalLineView = object_getIvar(floatView, lineViewIvar);
    
    if (originalLineView) {
        lineView2.frame = CGRectOffset(originalLineView.frame, [floatView buttonWidth:floatView.m_likeBtn], 0);
    }
}

@end

// MARK: - 插件管理器
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

// MARK: - 插件加载
__attribute__((constructor))
static void DDTimeLineForwardPluginLoad() {
    @autoreleasepool {
        // 延迟执行，确保主框架加载完成
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            
            // 注册到插件管理器
            if (NSClassFromString(@"WCPluginsMgr")) {
                [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD朋友圈转发" 
                                                                                   version:@"1.0.0" 
                                                                               controller:@"DDTimeLineForwardSettingController"];
            }
            
            // Hook WCOperateFloatView的showWithItemData:tipPoint:方法
            Class floatViewClass = objc_getClass("WCOperateFloatView");
            if (floatViewClass) {
                Method originalMethod = class_getInstanceMethod(floatViewClass, @selector(showWithItemData:tipPoint:));
                Method swizzledMethod = class_getInstanceMethod(floatViewClass, @selector(dd_showWithItemData:tipPoint:));
                
                if (originalMethod && swizzledMethod) {
                    method_exchangeImplementations(originalMethod, swizzledMethod);
                    NSLog(@"[DD朋友圈转发] 插件加载成功，版本 1.0.0");
                } else {
                    NSLog(@"[DD朋友圈转发] 方法交换失败");
                }
            } else {
                NSLog(@"[DD朋友圈转发] WCOperateFloatView类未找到");
            }
        });
    }
}