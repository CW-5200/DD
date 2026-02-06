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

@implementation UIView (ForwardExtension)

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

- (void)adjusted_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    [self adjusted_showWithItemData:arg1 tipPoint:arg2];
    
    Class targetClass = objc_getClass("WCOperateFloatView");
    if (!targetClass || ![self isKindOfClass:targetClass]) {
        return;
    }
    
    UIView *view = (UIView *)self;
    CGRect frame = view.frame;
    frame = CGRectOffset(CGRectInset(frame, frame.size.width / -4, 0), frame.size.width / -4, 0);
    view.frame = frame;
    
    UIButton *likeBtn = [self valueForKey:@"m_likeBtn"];
    UIButton *shareBtn = [self m_shareBtn];
    if (likeBtn && shareBtn) {
        shareBtn.frame = CGRectOffset(likeBtn.frame, likeBtn.frame.size.width * 2, 0);
        shareBtn.hidden = NO;
        shareBtn.alpha = 1.0;
    }
    
    Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
    UIImageView *originalLineView = lineViewIvar ? object_getIvar(self, lineViewIvar) : nil;
    UIImageView *lineView2 = [self m_lineView2];
    
    if (originalLineView && lineView2) {
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

__attribute__((constructor)) static void entry() {
    @autoreleasepool {
        Class cls = objc_getClass("WCOperateFloatView");
        if (cls) {
            swizzleMethod(cls, 
                         @selector(showWithItemData:tipPoint:), 
                         @selector(adjusted_showWithItemData:tipPoint:));
        }
    }
}