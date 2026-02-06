#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

@interface WCOperateFloatView : UIView
@property(readonly, nonatomic) UIButton *m_likeBtn;
@property(readonly, nonatomic) id m_item;
@property(nonatomic) __weak UINavigationController *navigationController;
- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2;
- (double)buttonWidth:(id)arg1;
@end

@interface WCForwardViewController : UIViewController
- (id)initWithDataItem:(id)arg1;
@end

@implementation UIView (ForwardExtension)

#pragma mark - 提前创建图标和按钮，避免延迟
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 提前创建图标，避免首次使用时延迟
        [self forwardIconImage];
    });
}

+ (UIImage *)forwardIconImage {
    static UIImage *forwardIcon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize size = CGSizeMake(18, 18);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
        
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetStrokeColorWithColor(context, [UIColor whiteColor].CGColor);
        CGContextSetLineWidth(context, 1.2);
        CGContextSetLineCap(context, kCGLineCapRound);
        CGContextSetLineJoin(context, kCGLineJoinRound);
        
        CGFloat padding = 4.0;
        CGContextMoveToPoint(context, padding, padding);
        CGContextAddLineToPoint(context, size.width - padding, size.height / 2);
        CGContextAddLineToPoint(context, padding, size.height - padding);
        
        CGContextMoveToPoint(context, size.width - padding - 1.5, size.height / 2 - 4.0);
        CGContextAddLineToPoint(context, size.width - padding - 1.5, size.height / 2 + 4.0);
        
        CGContextStrokePath(context);
        
        forwardIcon = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        forwardIcon = [forwardIcon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    });
    return forwardIcon;
}

- (void)prepareForwardButtonIfNeeded {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 提前准备按钮相关资源
        [self m_shareBtn];
        [self m_lineView2];
    });
}

- (UIButton *)m_shareBtn {
    static char m_shareBtnKey;
    UIButton *btn = objc_getAssociatedObject(self, &m_shareBtnKey);
    if (!btn) {
        UIButton *likeBtn = [self valueForKey:@"m_likeBtn"];
        if (!likeBtn) return nil;
        
        UIColor *titleColor = [likeBtn titleColorForState:UIControlStateNormal];
        if (!titleColor) {
            titleColor = [UIColor whiteColor];
        }
        
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        [btn setTitleColor:titleColor forState:UIControlStateNormal];
        btn.titleLabel.font = likeBtn.titleLabel.font;
        
        UIImage *forwardIcon = [[self class] forwardIconImage];
        [btn setImage:forwardIcon forState:UIControlStateNormal];
        
        btn.tintColor = titleColor;
        btn.hidden = YES; // 初始隐藏，show时再显示
        
        [likeBtn.superview addSubview:btn];
        objc_setAssociatedObject(self, &m_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

- (UIImageView *)m_lineView2 {
    static char m_lineView2Key;
    UIImageView *imageView = objc_getAssociatedObject(self, &m_lineView2Key);
    if (!imageView) {
        Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
        UIImageView *originalLineView = lineViewIvar ? object_getIvar(self, lineViewIvar) : nil;
        
        if (!originalLineView) {
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

@end

#pragma mark - 优化后的Hook方法
__attribute__((constructor)) static void entry() {
    @autoreleasepool {
        Class cls = objc_getClass("WCOperateFloatView");
        if (!cls) return;
        
        // 使用更高效的方法交换方式
        Method originalMethod = class_getInstanceMethod(cls, @selector(showWithItemData:tipPoint:));
        Method newMethod = class_getInstanceMethod(cls, @selector(adjusted_showWithItemData:tipPoint:));
        
        if (originalMethod && newMethod) {
            method_exchangeImplementations(originalMethod, newMethod);
            
            // 预加载资源，减少首次显示延迟
            dispatch_async(dispatch_get_main_queue(), ^{
                // 在下一个run loop中预加载图标
                [UIView forwardIconImage];
            });
        }
    }
}

@implementation WCOperateFloatView (ForwardTweak)

- (void)adjusted_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    // 先调用原始方法显示基础布局
    [self adjusted_showWithItemData:arg1 tipPoint:arg2];
    
    // 快速设置转发按钮和分割线
    UIButton *likeBtn = [self valueForKey:@"m_likeBtn"];
    if (!likeBtn) return;
    
    // 提前创建按钮（如果还没创建）
    UIButton *shareBtn = [self m_shareBtn];
    UIImageView *lineView2 = [self m_lineView2];
    
    if (shareBtn && lineView2) {
        // 调整布局以适应转发按钮
        CGRect frame = self.frame;
        frame = CGRectOffset(CGRectInset(frame, frame.size.width / -4, 0), frame.size.width / -4, 0);
        self.frame = frame;
        
        // 设置转发按钮位置
        shareBtn.frame = CGRectOffset(likeBtn.frame, likeBtn.frame.size.width * 2, 0);
        shareBtn.hidden = NO;
        shareBtn.alpha = 1.0;
        
        // 设置第二条分割线位置
        Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
        UIImageView *originalLineView = lineViewIvar ? object_getIvar(self, lineViewIvar) : nil;
        
        if (originalLineView) {
            SEL buttonWidthSel = @selector(buttonWidth:);
            if ([self respondsToSelector:buttonWidthSel]) {
                // 直接调用方法，避免使用NSInvocation的开销
                IMP imp = [self methodForSelector:buttonWidthSel];
                CGFloat (*func)(id, SEL, id) = (CGFloat (*)(id, SEL, id))imp;
                CGFloat width = func(self, buttonWidthSel, likeBtn);
                lineView2.frame = CGRectOffset(originalLineView.frame, width, 0);
            }
        }
    }
}

@end