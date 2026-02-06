#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <objc/message.h>

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

static UIImage *ForwardIconImage() {
    static UIImage *icon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(18, 18), NO, 0.0);
        
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSetStrokeColorWithColor(ctx, [UIColor whiteColor].CGColor);
        CGContextSetLineWidth(ctx, 1.2);
        CGContextSetLineCap(ctx, kCGLineCapRound);
        
        CGFloat p = 4.0;
        CGContextMoveToPoint(ctx, p, p);
        CGContextAddLineToPoint(ctx, 18 - p, 9);
        CGContextAddLineToPoint(ctx, p, 18 - p);
        
        CGContextMoveToPoint(ctx, 18 - p - 1.5, 5);
        CGContextAddLineToPoint(ctx, 18 - p - 1.5, 13);
        
        CGContextStrokePath(ctx);
        
        icon = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    });
    return icon;
}

__attribute__((constructor)) static void entry() {
    @autoreleasepool {
        Class cls = objc_getClass("WCOperateFloatView");
        if (!cls) return;
        
        Method original = class_getInstanceMethod(cls, @selector(showWithItemData:tipPoint:));
        Method swizzled = class_getInstanceMethod(cls, @selector(xxx_showWithItemData:tipPoint:));
        
        if (original && swizzled) {
            method_exchangeImplementations(original, swizzled);
        }
    }
}

@implementation NSObject (ForwardTweak)

- (void)xxx_forwordTimeLine:(id)sender {
    id dataItem = [self valueForKey:@"m_item"];
    if (dataItem) {
        Class forwardVCClass = objc_getClass("WCForwardViewController");
        if (forwardVCClass) {
            id forwardVC = ((id (*)(id, SEL, id))objc_msgSend)(
                ((id (*)(id, SEL))objc_msgSend)(forwardVCClass, @selector(alloc)),
                @selector(initWithDataItem:),
                dataItem
            );
            
            id navController = [self valueForKey:@"navigationController"];
            if (navController && [navController respondsToSelector:@selector(pushViewController:animated:)]) {
                [navController pushViewController:forwardVC animated:YES];
            }
        }
    }
}

- (void)xxx_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    [self xxx_showWithItemData:arg1 tipPoint:arg2];
    
    UIButton *likeBtn = [self valueForKey:@"m_likeBtn"];
    if (!likeBtn) return;
    
    static char shareBtnKey;
    UIButton *shareBtn = objc_getAssociatedObject(self, &shareBtnKey);
    
    static char lineViewKey;
    UIImageView *lineView2 = objc_getAssociatedObject(self, &lineViewKey);
    
    BOOL needCreate = !shareBtn;
    
    if (!shareBtn) {
        UIColor *titleColor = [likeBtn titleColorForState:UIControlStateNormal];
        if (!titleColor) titleColor = [UIColor whiteColor];
        
        shareBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [shareBtn setTitle:@" 转发" forState:UIControlStateNormal];
        [shareBtn setTitleColor:titleColor forState:UIControlStateNormal];
        shareBtn.titleLabel.font = likeBtn.titleLabel.font;
        [shareBtn setImage:ForwardIconImage() forState:UIControlStateNormal];
        [shareBtn addTarget:self action:@selector(xxx_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        if (likeBtn.superview) {
            [likeBtn.superview addSubview:shareBtn];
        }
        
        objc_setAssociatedObject(self, &shareBtnKey, shareBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    if (!lineView2) {
        Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
        UIImageView *originalLineView = lineViewIvar ? object_getIvar(self, lineViewIvar) : nil;
        
        if (originalLineView && [originalLineView isKindOfClass:[UIImageView class]]) {
            lineView2 = [[UIImageView alloc] initWithImage:originalLineView.image];
            
            if (likeBtn.superview) {
                [likeBtn.superview addSubview:lineView2];
            }
            
            objc_setAssociatedObject(self, &lineViewKey, lineView2, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    if (needCreate) {
        UIView *view = (UIView *)self;
        CGRect frame = view.frame;
        frame = CGRectOffset(CGRectInset(frame, frame.size.width / -4, 0), frame.size.width / -4, 0);
        view.frame = frame;
    }
    
    shareBtn.frame = CGRectOffset(likeBtn.frame, likeBtn.frame.size.width * 2, 0);
    
    if (lineView2) {
        Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
        UIImageView *originalLineView = lineViewIvar ? object_getIvar(self, lineViewIvar) : nil;
        
        if (originalLineView) {
            SEL buttonWidthSel = @selector(buttonWidth:);
            if ([self respondsToSelector:buttonWidthSel]) {
                IMP imp = [self methodForSelector:buttonWidthSel];
                CGFloat (*func)(id, SEL, id) = (CGFloat (*)(id, SEL, id))imp;
                CGFloat width = func(self, buttonWidthSel, likeBtn);
                lineView2.frame = CGRectOffset(originalLineView.frame, width, 0);
            }
        }
    }
}

@end