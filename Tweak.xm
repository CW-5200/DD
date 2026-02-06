// ============ WeChatForwardTweak.xm ============
// 朋友圈转发功能插件
// 功能：在朋友圈浮窗菜单中添加"转发"按钮
// 生效条件：默认启用，无需设置开关

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// ============ 微信类声明 ============
@class WCDataItem, WCForwardViewController;

@interface WCOperateFloatView : UIView
@property(readonly, nonatomic) UIButton *m_likeBtn;
@property(readonly, nonatomic) WCDataItem *m_item;
@property(nonatomic) __weak UINavigationController *navigationController;
- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2;
- (double)buttonWidth:(id)arg1;
@end

@interface WCForwardViewController : UIViewController
- (id)initWithDataItem:(id)arg1;
@end

// ============ 运行时辅助 ============
static void swizzleMethod(Class cls, SEL originalSelector, SEL swizzledSelector) {
    Method originalMethod = class_getInstanceMethod(cls, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, swizzledSelector);
    
    BOOL didAddMethod = class_addMethod(cls, originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    if (didAddMethod) {
        class_replaceMethod(cls, swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

// ============ 转发功能实现 ============
// 使用 UIView 类别，因为 WCOperateFloatView 继承自 UIView
@implementation UIView (ForwardExtension)

#pragma mark - 创建白色转发图标
+ (UIImage *)forwardIconImage {
    static UIImage *forwardIcon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 创建一个 20x20 的白色箭头图标
        CGSize size = CGSizeMake(20, 20);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
        
        // 获取上下文
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        // 设置线条属性 - 使用白色
        CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextSetLineWidth(context, 1.5);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        
        // 绘制箭头（简单向右箭头）
        CGFloat padding = 4.0;
        CGContextMoveToPoint(context, padding, padding);
        CGContextAddLineToPoint(context, size.width - padding, size.height / 2);
        CGContextAddLineToPoint(context, padding, size.height - padding);
        
        // 绘制竖线（箭头旁边的竖线）
        CGContextMoveToPoint(context, size.width - padding - 2, size.height / 2 - 5);
        CGContextAddLineToPoint(context, size.width - padding - 2, size.height / 2 + 5);
        
        // 描边路径
        CGContextStrokePath(context);
        
        // 获取图片
        forwardIcon = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        // 设置渲染模式为原始模式，保持白色不变
        forwardIcon = [forwardIcon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    });
    return forwardIcon;
}

#pragma mark - 添加转发按钮
- (UIButton *)m_shareBtn {
    static char m_shareBtnKey;
    UIButton *btn = objc_getAssociatedObject(self, &m_shareBtnKey);
    if (!btn) {
        UIButton *likeBtn = [self valueForKey:@"m_likeBtn"];
        if (!likeBtn) return nil;
        
        // 获取原始按钮的文字颜色（应该是白色）
        UIColor *titleColor = [likeBtn titleColorForState:UIControlStateNormal];
        if (!titleColor) {
            // 如果没有获取到颜色，默认使用白色
            titleColor = [UIColor whiteColor];
        }
        
        // 创建转发按钮
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        // 使用点赞按钮的文字颜色
        [btn setTitleColor:titleColor forState:UIControlStateNormal];
        btn.titleLabel.font = likeBtn.titleLabel.font;
        
        // 设置按钮图标（使用白色图标）
        UIImage *forwardIcon = [[self class] forwardIconImage];
        [btn setImage:forwardIcon forState:UIControlStateNormal];
        
        // 设置按钮的 tintColor 为文字颜色，但图标已经使用白色原始模式，所以不会变色
        btn.tintColor = titleColor;
        
        // 添加到视图
        [likeBtn.superview addSubview:btn];
        objc_setAssociatedObject(self, &m_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

#pragma mark - 添加分割线
- (UIImageView *)m_lineView2 {
    static char m_lineView2Key;
    UIImageView *imageView = objc_getAssociatedObject(self, &m_lineView2Key);
    if (!imageView) {
        // 尝试获取原始分割线
        Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
        UIImageView *originalLineView = lineViewIvar ? object_getIvar(self, lineViewIvar) : nil;
        
        if (!originalLineView) {
            // 尝试通过遍历 ivars 查找
            unsigned int count = 0;
            Ivar *ivars = class_copyIvarList([self class], &count);
            for (unsigned int i = 0; i < count; i++) {
                const char *name = ivar_getName(ivars[i]);
                if (strstr(name, "lineView")) {
                    originalLineView = object_getIvar(self, ivars[i]);
                    break;
                }
            }
            free(ivars);
        }
        
        if (originalLineView && [originalLineView isKindOfClass:[UIImageView class]]) {
            imageView = [[UIImageView alloc] initWithImage:originalLineView.image];
            UIButton *likeBtn = [self valueForKey:@"m_likeBtn"];
            if (likeBtn && likeBtn.superview) {
                [likeBtn.superview addSubview:imageView];
                objc_setAssociatedObject(self, &m_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
    }
    return imageView;
}

#pragma mark - 转发操作
- (void)forwordTimeLine:(id)sender {
    id dataItem = [self valueForKey:@"m_item"];
    if (dataItem) {
        Class forwardVCClass = objc_getClass("WCForwardViewController");
        if (forwardVCClass) {
            WCForwardViewController *forwardVC = [[forwardVCClass alloc] initWithDataItem:dataItem];
            UINavigationController *navController = [self valueForKey:@"navigationController"];
            if (navController) {
                [navController pushViewController:forwardVC animated:YES];
            }
        }
    }
}

#pragma mark - 布局调整
- (void)adjusted_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    // 调用原始方法
    [self adjusted_showWithItemData:arg1 tipPoint:arg2];
    
    // 确保是 WCOperateFloatView 实例
    Class targetClass = objc_getClass("WCOperateFloatView");
    if (!targetClass || ![self isKindOfClass:targetClass]) {
        return;
    }
    
    // 调整布局以适应转发按钮
    UIView *view = (UIView *)self;
    CGRect frame = view.frame;
    frame = CGRectOffset(CGRectInset(frame, frame.size.width / -4, 0), frame.size.width / -4, 0);
    view.frame = frame;
    
    // 设置转发按钮位置
    UIButton *likeBtn = [self valueForKey:@"m_likeBtn"];
    UIButton *shareBtn = [self m_shareBtn];
    if (likeBtn && shareBtn) {
        shareBtn.frame = CGRectOffset(likeBtn.frame, likeBtn.frame.size.width * 2, 0);
        
        // 确保按钮可见
        shareBtn.hidden = NO;
        shareBtn.alpha = 1.0;
    }
    
    // 设置第二条分割线位置
    Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
    UIImageView *originalLineView = lineViewIvar ? object_getIvar(self, lineViewIvar) : nil;
    UIImageView *lineView2 = [self m_lineView2];
    
    if (originalLineView && lineView2) {
        // 动态调用 buttonWidth: 方法
        SEL buttonWidthSel = @selector(buttonWidth:);
        if ([self respondsToSelector:buttonWidthSel]) {
            NSMethodSignature *sig = [self methodSignatureForSelector:buttonWidthSel];
            NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:sig];
            [invocation setTarget:self];
            [invocation setSelector:buttonWidthSel];
            if (likeBtn) {
                [invocation setArgument:&likeBtn atIndex:2];
            }
            [invocation invoke];
            CGFloat width = 0;
            [invocation getReturnValue:&width];
            
            lineView2.frame = CGRectOffset(originalLineView.frame, width, 0);
        }
    }
}

@end

// ============ 插件入口 ============
__attribute__((constructor)) static void entry() {
    @autoreleasepool {
        // Hook WCOperateFloatView的显示方法
        Class cls = objc_getClass("WCOperateFloatView");
        if (cls) {
            swizzleMethod(cls, 
                         @selector(showWithItemData:tipPoint:), 
                         @selector(adjusted_showWithItemData:tipPoint:));
            NSLog(@"[WeChatForwardTweak] 朋友圈转发功能已启用");
        }
    }
}