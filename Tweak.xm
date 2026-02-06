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
        NSString *base64Str = @"PD94bWwgdmVyc2lvbj0iMS4wIiBzdGFuZGFsb25lPSJubyI/PjwhRE9DVFlQRSBzdmcgUFVCTElDICItLy9XM0MvL0RURCBTVkcgMS4xLy9FTiIgImh0dHA6Ly93d3cudzMub3JnL0dyYXBoaWNzL1NWRy8xLjEvRFREL3N2ZzExLmR0ZCI+PHN2ZyBjbGFzcz0iaWNvbiIgd2lkdGg9IjIwMHB4IiBoZWlnaHQ9IjIwMC4wMHB4IiB2aWV3Qm94PSIwIDAgMTAyNCAxMDI0IiB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyI+PHBhdGggZD0iTTc2OC45NyAxMjcuOTZIMjU1LjAzYy04MS44NyAwLTE0OC40OCA2Ni42MS0xNDguNDggMTQ4LjQ4djM0Mi42MmMwIDgxLjg4IDY2LjYxIDE0OC40OCAxNDguNDggMTQ4LjQ4aDY1LjY2djEwOC40OGMwIDcuMjEgMy44OCAxMy44NSAxMC4xNSAxNy40YTE5Ljk3MyAxOS45NzMgMCAwIDAgMjAuMTQtMC4yNWwyMDkuMzktMTI1LjYzaDIwOC42YzgxLjg3IDAgMTQ4LjQ4LTY2LjYxIDE0OC40OC0xNDguNDhWMjc2LjQ1YzAtODEuODgtNjYuNjEtMTQ4LjQ5LTE0OC40OC0xNDguNDl6IG0xMDguNDggNDkxLjExYzAgNTkuODItNDguNjcgMTA4LjQ4LTEwOC40OCAxMDguNDhINTU0LjgzYy0zLjYyIDAtNy4xOCAwLjk5LTEwLjI5IDIuODVMMzYwLjY5IDg0MC43MXYtOTMuMTZjMC0xMS4wNS04Ljk1LTIwLTIwLTIwaC04NS42NmMtNTkuODIgMC0xMDguNDgtNDguNjctMTA4LjQ4LTEwOC40OFYyNzYuNDVjMC01OS44MiA0OC42Ny0xMDguNDggMTA4LjQ4LTEwOC40OGg1MTMuOTRjNTkuODIgMCAxMDguNDggNDguNjcgMTA4LjQ4IDEwOC40OHYzNDIuNjJ6IiBmaWxsPSIjMzMzMzMzIiAvPjxwYXRoIGQ9Ik02OTkuMzIgNDU5LjcyYzAuMjEtMC4yOCAwLjQzLTAuNTYgMC42My0wLjg1IDAuMTktMC4yOCAwLjM2LTAuNTggMC41My0wLjg3IDAuMTYtMC4yNyAwLjMzLTAuNTMgMC40OC0wLjgxIDAuMTYtMC4zIDAuMjktMC42IDAuNDMtMC45IDAuMTQtMC4yOSAwLjI4LTAuNTggMC40MS0wLjg3IDAuMTItMC4yOSAwLjIyLTAuNTkgMC4zMi0wLjg4IDAuMTItMC4zMiAwLjI0LTAuNjQgMC4zNC0wLjk2IDAuMDktMC4yOSAwLjE1LTAuNTkgMC4yMy0wLjg5IDAuMDktMC4zNCAwLjE4LTAuNjcgMC4yNS0xLjAxIDAuMDctMC4zNCAwLjExLTAuNjggMC4xNi0xLjAzIDAuMDQtMC4zIDAuMS0wLjYgMC4xMy0wLjkxIDAuMDYtMC42MyAwLjA5LTEuMjUgMC4xLTEuODh2LTAuMDktMC4wOWMwLTAuNjMtMC4wMy0xLjI2LTAuMS0xLjg4LTAuMDMtMC4zMS0wLjA5LTAuNjEtMC4xMy0wLjkxLTAuMDUtMC4zNC0wLjA5LTAuNjktMC4xNi0xLjAzLTAuMDctMC4zNC0wLjE2LTAuNjctMC4yNS0xLjAxLTAuMDctMC4zLTAuMTQtMC41OS0wLjIzLTAuODktMC4xLTAuMzMtMC4yMi0wLjY0LTAuMzQtMC45Ni0wLjExLTAuMy0wLjItMC41OS0wLjMyLTAuODktMC4xMi0wLjMtMC4yNy0wLjU4LTAuNDEtMC44Ny0wLjE0LTAuMy0wLjI4LTAuNjEtMC40My0wLjktMC4xNS0wLjI4LTAuMzItMC41NC0wLjQ4LTAuODEtMC4xNy0wLjI5LTAuMzQtMC41OS0wLjUzLTAuODctMC4yLTAuMjktMC40Mi0wLjU3LTAuNjMtMC44NS0wLjE4LTAuMjQtMC4zNS0wLjQ5LTAuNTQtMC43Mi0wLjQtMC40OS0wLjgzLTAuOTYtMS4yOC0xLjQxbC0wLjA1LTAuMDUtMTI4LjQ4LTEyOC41Yy03LjgxLTcuODEtMjAuNDctNy44MS0yOC4yOSAwLTcuODEgNy44MS03LjgxIDIwLjQ3IDAgMjguMjhsOTQuMzQgOTQuMzRIMzQwLjY5Yy0xMS4wNSAwLTIwIDguOTUtMjAgMjBzOC45NSAyMCAyMCAyMGgyOTQuMzRsLTk0LjM0IDk0LjM0Yy03LjgxIDcuODEtNy44MSAyMC40NyAwIDI4LjI5IDMuOTEgMy45MSA5LjAyIDUuODYgMTQuMTQgNS44NnMxMC4yNC0xLjk1IDE0LjE0LTUuODZMNjk3LjQ1IDQ2MS45bDAuMDUtMC4wNWMwLjQ1LTAuNDUgMC44Ny0wLjkyIDEuMjgtMS40MSAwLjE5LTAuMjQgMC4zNi0wLjQ4IDAuNTQtMC43MnoiIGZpbGw9IiMzMzMzMzMiIC8+PC9zdmc+";
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