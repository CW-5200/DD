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
        }
        
        // 使用原始代码中的Base64图标
        NSString *base64Str = @"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
AAAAAElFTkSuQmCC";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:UIControlStateNormal];
        
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

// Hook显示方法 - 这是被交换的方法
- (void)dd_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    // 保存原始实现
    static void (*originalIMP)(id, SEL, id, struct CGPoint) = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        originalIMP = (void (*)(id, SEL, id, struct CGPoint))method_getImplementation(class_getInstanceMethod([self class], @selector(dd_showWithItemData:tipPoint:)));
    });
    
    // 调用原始方法
    if (originalIMP) {
        originalIMP(self, _cmd, arg1, arg2);
    }
    
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
                // 使用更安全的方法交换方式
                Method originalMethod = class_getInstanceMethod(floatViewClass, @selector(showWithItemData:tipPoint:));
                Method swizzledMethod = class_getInstanceMethod(floatViewClass, @selector(dd_showWithItemData:tipPoint:));
                
                if (originalMethod && swizzledMethod) {
                    // 检查是否已经交换过
                    BOOL didAddMethod = class_addMethod(floatViewClass,
                                                       @selector(showWithItemData:tipPoint:),
                                                       method_getImplementation(swizzledMethod),
                                                       method_getTypeEncoding(swizzledMethod));
                    
                    if (didAddMethod) {
                        // 添加成功，替换原始方法
                        class_replaceMethod(floatViewClass,
                                          @selector(dd_showWithItemData:tipPoint:),
                                          method_getImplementation(originalMethod),
                                          method_getTypeEncoding(originalMethod));
                    } else {
                        // 添加失败，直接交换
                        method_exchangeImplementations(originalMethod, swizzledMethod);
                    }
                    
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