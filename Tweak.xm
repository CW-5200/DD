//  DD朋友圈转发.m
//  DD朋友圈转发插件 v1.0.0
//  基于DKWechatHelper提取的核心功能
//
//  Created by DKJone
//  Copyright © 2023 DD插件. All rights reserved.

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
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

@interface WCOperateFloatView : UIView
@property(readonly, nonatomic) UIButton *m_likeBtn;
@property(readonly, nonatomic) UIButton *m_commentBtn;
@property(readonly, nonatomic) WCDataItem *m_item;
@property(nonatomic, weak) UINavigationController *navigationController;
- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2;
- (double)buttonWidth:(id)arg1;
- (void)hide;
@end

// MARK: - 插件管理接口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// MARK: - 配置管理
@interface DDTimeLineForwardConfig : NSObject
+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL enabled;
@end

@implementation DDTimeLineForwardConfig

+ (instancetype)sharedConfig {
    static DDTimeLineForwardConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [DDTimeLineForwardConfig new];
    });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        _enabled = [[NSUserDefaults standardUserDefaults] boolForKey:DDTimeLineForwardEnableKey];
        
        // 默认设置
        if ([[NSUserDefaults standardUserDefaults] objectForKey:DDTimeLineForwardEnableKey] == nil) {
            _enabled = YES; // 默认开启
            [[NSUserDefaults standardUserDefaults] setBool:_enabled forKey:DDTimeLineForwardEnableKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
    return self;
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:DDTimeLineForwardEnableKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

// MARK: - 设置界面
@interface DDTimeLineForwardSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation DDTimeLineForwardSettingsViewController

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
    static NSString *cellIdentifier = @"DDTimeLineForwardSwitchCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        cell.textLabel.text = @"启用朋友圈转发";
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.onTintColor = [UIColor systemBlueColor];
        switchView.on = [DDTimeLineForwardConfig sharedConfig].enabled;
        [switchView addTarget:self action:@selector(forwardSwitchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 20.0;
}

- (void)forwardSwitchChanged:(UISwitch *)sender {
    [DDTimeLineForwardConfig sharedConfig].enabled = sender.isOn;
}

@end

// MARK: - WCOperateFloatView 扩展 (添加转发功能)
@implementation NSObject (DDTimeLineForward)

static void (*originalShowIMP)(id, SEL, id, struct CGPoint) = NULL;

// 动态添加分享按钮属性
- (UIButton *)dd_shareBtn {
    static char dd_shareBtnKey;
    UIButton *btn = objc_getAssociatedObject(self, &dd_shareBtnKey);
    
    if (!btn) {
        WCOperateFloatView *floatView = (WCOperateFloatView *)self;
        
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(dd_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        if (floatView.m_likeBtn) {
            [btn setTitleColor:[floatView.m_likeBtn titleColorForState:UIControlStateNormal] forState:UIControlStateNormal];
            btn.titleLabel.font = floatView.m_likeBtn.titleLabel.font;
        }
        
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaAZWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:UIControlStateNormal];
        btn.tintColor = [btn titleColorForState:UIControlStateNormal];
        
        objc_setAssociatedObject(self, &dd_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

// 动态添加分割线属性
- (UIImageView *)dd_lineView2 {
    static char dd_lineView2Key;
    UIImageView *imageView = objc_getAssociatedObject(self, &dd_lineView2Key);
    
    if (!imageView) {
        WCOperateFloatView *floatView = (WCOperateFloatView *)self;
        
        unsigned int outCount = 0;
        Ivar *ivars = class_copyIvarList([floatView class], &outCount);
        UIImageView *originalLineView = nil;
        
        for (unsigned int i = 0; i < outCount; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            if (name && strstr(name, "lineView")) {
                originalLineView = object_getIvar(floatView, ivar);
                break;
            }
        }
        free(ivars);
        
        if (originalLineView && originalLineView.image) {
            imageView = [[UIImageView alloc] initWithImage:originalLineView.image];
        }
        
        objc_setAssociatedObject(self, &dd_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return imageView;
}

// 获取原始分割线
- (UIImageView *)dd_originalLineView {
    WCOperateFloatView *floatView = (WCOperateFloatView *)self;
    unsigned int outCount = 0;
    Ivar *ivars = class_copyIvarList([floatView class], &outCount);
    UIImageView *originalLineView = nil;
    
    for (unsigned int i = 0; i < outCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name && strstr(name, "lineView")) {
            originalLineView = object_getIvar(floatView, ivar);
            break;
        }
    }
    free(ivars);
    
    return originalLineView;
}

// 转发按钮点击事件
- (void)dd_forwordTimeLine:(id)arg1 {
    if (![DDTimeLineForwardConfig sharedConfig].enabled) return;
    
    WCOperateFloatView *floatView = (WCOperateFloatView *)self;
    
    Class forwardViewControllerClass = objc_getClass("WCForwardViewController");
    if (forwardViewControllerClass) {
        id forwardVC = [[forwardViewControllerClass alloc] initWithDataItem:floatView.m_item];
        if (forwardVC && floatView.navigationController) {
            [floatView.navigationController pushViewController:forwardVC animated:YES];
        }
        [floatView hide];
    }
}

// Hook显示方法
- (void)dd_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    if (originalShowIMP) {
        originalShowIMP(self, _cmd, arg1, arg2);
    }
    
    if (![DDTimeLineForwardConfig sharedConfig].enabled) return;
    
    WCOperateFloatView *floatView = (WCOperateFloatView *)self;
    
    CGRect frame = floatView.frame;
    frame = CGRectInset(frame, frame.size.width / -4, 0);
    frame = CGRectOffset(frame, frame.size.width / -4, 0);
    floatView.frame = frame;
    
    UIButton *shareBtn = [floatView dd_shareBtn];
    if (floatView.m_likeBtn) {
        CGRect likeBtnFrame = floatView.m_likeBtn.frame;
        shareBtn.frame = CGRectOffset(likeBtnFrame, likeBtnFrame.size.width * 2, 0);
        
        if (shareBtn.superview != floatView) {
            [floatView addSubview:shareBtn];
        }
    }
    
    UIImageView *originalLineView = [floatView dd_originalLineView];
    UIImageView *lineView2 = [floatView dd_lineView2];
    
    if (originalLineView && floatView.m_likeBtn && lineView2) {
        CGRect originalLineFrame = originalLineView.frame;
        lineView2.frame = CGRectOffset(originalLineFrame, [floatView buttonWidth:floatView.m_likeBtn], 0);
        
        if (lineView2.superview != floatView) {
            [floatView addSubview:lineView2];
        }
    }
    
    [floatView layoutIfNeeded];
}

@end

// MARK: - 插件加载
__attribute__((constructor))
static void DDTimeLineForwardPluginLoad() {
    @autoreleasepool {
        // 注册到插件管理器
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD朋友圈转发" 
                version:@"1.0.0" 
                controller:@"DDTimeLineForwardSettingsViewController"];
        }
        
        // Hook WCOperateFloatView的showWithItemData:tipPoint:方法
        Class floatViewClass = objc_getClass("WCOperateFloatView");
        if (floatViewClass) {
            Method originalMethod = class_getInstanceMethod(floatViewClass, @selector(showWithItemData:tipPoint:));
            Method swizzledMethod = class_getInstanceMethod(floatViewClass, @selector(dd_showWithItemData:tipPoint:));
            
            if (originalMethod && swizzledMethod) {
                originalShowIMP = (void (*)(id, SEL, id, struct CGPoint))method_getImplementation(originalMethod);
                method_exchangeImplementations(originalMethod, swizzledMethod);
            }
        }
    }
}