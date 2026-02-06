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
@property(readonly, nonatomic) id m_likeBtn;
@property(readonly, nonatomic) id m_item;
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

// MARK: - 图片处理工具
@interface UIImage (DDResize)
- (UIImage *)dd_resizedImageWithSize:(CGSize)size;
@end

@implementation UIImage (DDResize)

- (UIImage *)dd_resizedImageWithSize:(CGSize)size {
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
    [self drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *resizedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resizedImage;
}

@end

// MARK: - WCOperateFloatView 扩展 (添加转发功能)
@implementation NSObject (DDTimeLineForward)

// 图片缩放辅助方法
- (UIImage *)dd_resizedImage:(UIImage *)image size:(CGSize)size {
    if (!image) return nil;
    return [image dd_resizedImageWithSize:size];
}

// 动态添加分享按钮属性
- (UIButton *)dd_shareBtn {
    static char dd_shareBtnKey;
    UIButton *btn = objc_getAssociatedObject(self, &dd_shareBtnKey);
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(dd_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        [btn setTitleColor:[UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:1.0] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:14];
        
        // DeepSeek风格的分享图标
        NSString *deepSeekShareIcon = @"iVBORw0KGgoAAAANSUhEUgAAABgAAAAYCAYAAADgdz34AAAACXBIWXMAAAsTAAALEwEAmpwYAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAGKSURBVHgBpZYLbBRBFIbv7oKGSw1pTAiRagwqV4QoFTRyEwnBPmL0gX3QYBRRo4INaRDlEag2hMQHhDZIAg12pTEkoAnK8hLwAW2XUkmM2li8gFhKo7bU0tbe6V7cnu7MdXfd0U7ys5v577z2zMz5AFowk3Y7pJfCqwE0C7PZ5fJNvAT5TwCh6M9eG3FbFQw7pwY3rO3z3Tka0+L86nL+q41pJj2WQl5+XQJ40FOq31y/LtwkERiJQXgE0Jj4n7zMf40c5zuhQk7Mysigw2uXCerGYF/ss14FpQ65DTYQ9P2oc4Y8L8KQDHc0z2y6N8fXfl36P3MMh/YDCj97nt9cVxhq4EokTMMe7gnwLYCf57xHc/9jNChyLkTx4j6rI2vn4/n+9v5T1ggF39lyL+Vv9nf+J7SFO1Pz/AZ/11cAExAwPqjKJXr9vnXJopN4NYADM/h+q7fFfRFmE/21FkfnxBrE5+RZ7MdxKXAGYR9i8NpP5nI2i6PxKHyi5Y10lHc2r/0IYA5ubVrX46e7dHkA3z0AAAAASUVORK5CYII=";
        
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:deepSeekShareIcon options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        
        // 调整图标大小（16x16像素）
        UIImage *resizedImage = [self dd_resizedImage:image size:CGSizeMake(16, 16)];
        [btn setImage:resizedImage forState:UIControlStateNormal];
        
        // 调整图片和文字间距
        btn.imageEdgeInsets = UIEdgeInsetsMake(0, -2, 0, 2);
        btn.titleEdgeInsets = UIEdgeInsetsMake(0, 2, 0, -2);
        
        objc_setAssociatedObject(self, &dd_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

// 动态添加分割线属性
- (UIImageView *)dd_lineView2 {
    static char dd_lineView2Key;
    UIImageView *imageView = objc_getAssociatedObject(self, &dd_lineView2Key);
    if (!imageView) {
        // 创建分割线
        imageView = [[UIImageView alloc] init];
        imageView.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
        imageView.frame = CGRectMake(0, 0, 1, 20);
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

// 获取浮窗中的其他按钮，用于布局参考
- (NSArray *)dd_getAllButtons {
    WCOperateFloatView *floatView = (WCOperateFloatView *)self;
    NSMutableArray *buttons = [NSMutableArray array];
    
    // 通过运行时查找所有按钮
    unsigned int outCount = 0;
    Ivar *ivars = class_copyIvarList([floatView class], &outCount);
    for (unsigned int i = 0; i < outCount; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (name && (strstr(name, "Btn") || strstr(name, "btn"))) {
            id button = object_getIvar(floatView, ivar);
            if ([button isKindOfClass:[UIButton class]]) {
                [buttons addObject:button];
            }
        }
    }
    free(ivars);
    
    return [buttons sortedArrayUsingComparator:^NSComparisonResult(UIButton *btn1, UIButton *btn2) {
        return btn1.frame.origin.x > btn2.frame.origin.x ? NSOrderedDescending : NSOrderedAscending;
    }];
}

// Hook显示方法
- (void)dd_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    // 调用原始方法
    [self dd_showWithItemData:arg1 tipPoint:arg2];
    
    if (![DDTimeLineForwardConfig isEnabled]) return;
    
    WCOperateFloatView *floatView = (WCOperateFloatView *)self;
    
    // 先移除可能存在的旧转发按钮和分割线
    [[floatView dd_shareBtn] removeFromSuperview];
    [[floatView dd_lineView2] removeFromSuperview];
    
    // 获取所有按钮进行智能布局
    NSArray *allButtons = [self dd_getAllButtons];
    
    if (allButtons.count > 0) {
        // 取最后一个按钮作为参考
        UIButton *lastButton = [allButtons lastObject];
        CGFloat buttonWidth = CGRectGetWidth(lastButton.frame);
        CGFloat buttonHeight = CGRectGetHeight(lastButton.frame);
        CGFloat spacing = 0;
        
        // 计算按钮间距
        if (allButtons.count > 1) {
            UIButton *prevButton = allButtons[allButtons.count - 2];
            spacing = CGRectGetMinX(lastButton.frame) - CGRectGetMaxX(prevButton.frame);
        }
        
        // 调整浮窗大小
        CGRect frame = floatView.frame;
        frame.size.width += buttonWidth + spacing;
        floatView.frame = frame;
        
        // 添加转发按钮
        UIButton *shareBtn = [floatView dd_shareBtn];
        shareBtn.frame = CGRectMake(CGRectGetMaxX(lastButton.frame) + spacing, 
                                   CGRectGetMinY(lastButton.frame), 
                                   buttonWidth, 
                                   buttonHeight);
        [floatView addSubview:shareBtn];
        
        // 添加分割线
        UIImageView *originalLineView = nil;
        unsigned int outCount = 0;
        Ivar *ivars = class_copyIvarList([floatView class], &outCount);
        for (unsigned int i = 0; i < outCount; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            if (name && strstr(name, "lineView")) {
                originalLineView = object_getIvar(floatView, ivar);
                if (originalLineView) {
                    UIImageView *lineView2 = [floatView dd_lineView2];
                    lineView2.frame = CGRectMake(CGRectGetMaxX(originalLineView.frame) + buttonWidth,
                                                CGRectGetMinY(originalLineView.frame),
                                                CGRectGetWidth(originalLineView.frame),
                                                CGRectGetHeight(originalLineView.frame));
                    [floatView addSubview:lineView2];
                    break;
                }
            }
        }
        free(ivars);
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
                [[objc_getClass("WCPluginsMgr") sharedInstance] registerSwitchWithTitle:@"DD朋友圈转发" 
                                                                                   key:DDTimeLineForwardEnableKey];
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