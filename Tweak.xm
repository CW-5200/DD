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

@interface WCOperateFloatView : UIView
@property(readonly, nonatomic) UIButton *m_likeBtn;
@property(readonly, nonatomic) UIButton *m_commentBtn;
@property(readonly, nonatomic) WCDataItem *m_item;
@property(nonatomic, weak) UINavigationController *navigationController;
- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2;
- (double)buttonWidth:(id)arg1;
- (void)hide;
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

// C函数实现，用于方法交换
static void dd_showWithItemData_tipPoint(id self, SEL _cmd, id arg1, struct CGPoint arg2) {
    // 调用原始实现（经过交换后实际上是原始方法）
    void (*originalIMP)(id, SEL, id, struct CGPoint) = (void (*)(id, SEL, id, struct CGPoint))class_getMethodImplementation(object_getClass(self), @selector(dd_showWithItemData:tipPoint:));
    
    // 先调用原始方法
    if (originalIMP) {
        originalIMP(self, _cmd, arg1, arg2);
    }
    
    // 然后执行我们的自定义逻辑
    [self performSelector:@selector(dd_postShowProcessing)];
}

// MARK: - WCOperateFloatView 扩展 (添加转发功能)
@implementation NSObject (DDTimeLineForward)

// 动态添加分享按钮属性
- (UIButton *)dd_shareBtn {
    static char dd_shareBtnKey;
    UIButton *btn = objc_getAssociatedObject(self, &dd_shareBtnKey);
    if (!btn) {
        WCOperateFloatView *floatView = (WCOperateFloatView *)self;
        
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(dd_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        // 使用原始按钮的样式设置
        if (floatView.m_likeBtn) {
            [btn setTitleColor:[floatView.m_likeBtn titleColorForState:UIControlStateNormal] forState:UIControlStateNormal];
            btn.titleLabel.font = floatView.m_likeBtn.titleLabel.font;
        } else {
            [btn setTitleColor:[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0] forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:14];
        }
        
        // 设置转发图标（从原始文件的base64字符串）
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Unek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaAZWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvix4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKusMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        
        // 调整图片大小以匹配原始文件（大概20x20像素）
        CGSize newSize = CGSizeMake(20, 20);
        UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
        [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
        UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        [btn setImage:scaledImage forState:UIControlStateNormal];
        
        // 设置图片渲染模式，保持原始颜色
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
        
        // 尝试获取原始分割线
        UIImageView *originalLineView = nil;
        unsigned int outCount = 0;
        Ivar *ivars = class_copyIvarList([floatView class], &outCount);
        for (unsigned int i = 0; i < outCount; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            if (name && strstr(name, "lineView")) {
                originalLineView = object_getIvar(floatView, ivar);
                break;
            }
        }
        free(ivars);
        
        // 创建分割线，参考原始文件
        if (originalLineView && originalLineView.image) {
            imageView = [[UIImageView alloc] initWithImage:originalLineView.image];
        } else {
            imageView = [[UIImageView alloc] init];
            imageView.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
            imageView.frame = CGRectMake(0, 0, 1, 20);
        }
        
        objc_setAssociatedObject(self, &dd_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return imageView;
}

// 转发按钮点击事件
- (void)dd_forwordTimeLine:(id)arg1 {
    if (![DDTimeLineForwardConfig isEnabled]) return;
    
    WCOperateFloatView *floatView = (WCOperateFloatView *)self;
    
    // 创建转发控制器（参考原始文件）
    Class forwardViewControllerClass = objc_getClass("WCForwardViewController");
    if (forwardViewControllerClass) {
        id forwardVC = [[forwardViewControllerClass alloc] initWithDataItem:floatView.m_item];
        if (forwardVC && floatView.navigationController) {
            [floatView.navigationController pushViewController:forwardVC animated:YES];
        }
        [floatView hide];
    }
}

// 显示后的处理
- (void)dd_postShowProcessing {
    if (![DDTimeLineForwardConfig isEnabled]) return;
    
    WCOperateFloatView *floatView = (WCOperateFloatView *)self;
    
    // 参考原始文件：调整浮窗大小以容纳三个按钮
    CGRect frame = floatView.frame;
    frame = CGRectInset(frame, frame.size.width / -4, 0);
    frame = CGRectOffset(frame, frame.size.width / -4, 0);
    floatView.frame = frame;
    
    // 添加转发按钮
    UIButton *shareBtn = [floatView dd_shareBtn];
    if (floatView.m_likeBtn) {
        // 参考原始文件：转发按钮位置是点赞按钮向右移动两个按钮宽度
        CGRect likeBtnFrame = floatView.m_likeBtn.frame;
        shareBtn.frame = CGRectOffset(likeBtnFrame, likeBtnFrame.size.width * 2, 0);
        
        // 确保转发按钮在视图层级中
        if (shareBtn.superview != floatView) {
            [floatView addSubview:shareBtn];
        }
    }
    
    // 添加分割线
    UIImageView *lineView2 = [floatView dd_lineView2];
    UIImageView *originalLineView = nil;
    
    // 获取原始分割线
    unsigned int outCount = 0;
    Ivar *ivars = class_copyIvarList([floatView class], &outCount);
    for (unsigned int i = 0; i < outCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name && strstr(name, "lineView")) {
            originalLineView = object_getIvar(floatView, ivar);
            break;
        }
    }
    free(ivars);
    
    if (originalLineView && floatView.m_likeBtn) {
        // 参考原始文件：第二条分割线在第一条分割线向右移动一个按钮宽度处
        CGRect originalLineFrame = originalLineView.frame;
        lineView2.frame = CGRectOffset(originalLineFrame, [floatView buttonWidth:floatView.m_likeBtn], 0);
        
        // 确保分割线在视图层级中
        if (lineView2.superview != floatView) {
            [floatView addSubview:lineView2];
        }
    }
    
    // 重新布局以确保所有按钮正确显示
    [floatView layoutIfNeeded];
}

// Hook显示方法 - 这是被交换的方法
- (void)dd_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    // 调用原始方法
    [self dd_showWithItemData:arg1 tipPoint:arg2];
    
    // 执行后处理
    [self dd_postShowProcessing];
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
                [[objc_getClass("WCPluginsMgr") sharedInstance] registerSwitchWithTitle:@"DD朋友圈转发" 
                                                                                   key:DDTimeLineForwardEnableKey];
            }
            
            // Hook WCOperateFloatView的showWithItemData:tipPoint:方法
            Class floatViewClass = objc_getClass("WCOperateFloatView");
            if (floatViewClass) {
                // 检查原始方法是否存在
                SEL originalSelector = @selector(showWithItemData:tipPoint:);
                SEL swizzledSelector = @selector(dd_showWithItemData:tipPoint:);
                
                Method originalMethod = class_getInstanceMethod(floatViewClass, originalSelector);
                Method swizzledMethod = class_getInstanceMethod(floatViewClass, swizzledSelector);
                
                if (originalMethod && swizzledMethod) {
                    // 直接交换方法
                    method_exchangeImplementations(originalMethod, swizzledMethod);
                    
                    NSLog(@"[DD朋友圈转发] 插件加载成功，版本 1.0.0");
                } else {
                    NSLog(@"[DD朋友圈转发] 方法交换失败，originalMethod: %p, swizzledMethod: %p", originalMethod, swizzledMethod);
                }
            } else {
                NSLog(@"[DD朋友圈转发] WCOperateFloatView类未找到");
            }
        });
    }
}