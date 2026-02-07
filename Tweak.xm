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

@implementation UIImage (ForwardIcon)

+ (UIImage *)forwardIcon {
    static UIImage *icon = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 直接使用iOS 13+系统图标，立即加载无延迟
        icon = [UIImage systemImageNamed:@"arrowshape.turn.up.right.fill"];
        
        if (icon) {
            // 调整图标大小适配按钮
            CGSize newSize = CGSizeMake(16, 16);
            UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
            [icon drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
            icon = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
        }
        
        icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    });
    return icon;
}

@end

__attribute__((constructor)) static void entry() {
    @autoreleasepool {
        // 预加载系统图标
        dispatch_async(dispatch_get_main_queue(), ^{
            [UIImage forwardIcon];
        });
        
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
            WCForwardViewController *forwardVC = [[forwardVCClass alloc] initWithDataItem:dataItem];
            UINavigationController *navController = [self valueForKey:@"navigationController"];
            if (navController) {
                [navController pushViewController:forwardVC animated:YES];
            }
        }
    }
}

- (void)xxx_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    // 先调用原始方法
    [self xxx_showWithItemData:arg1 tipPoint:arg2];
    
    UIButton *likeBtn = [self valueForKey:@"m_likeBtn"];
    if (!likeBtn) return;
    
    // 直接使用系统样式，避免延迟
    UIColor *titleColor = [UIColor whiteColor];
    UIFont *font = [UIFont systemFontOfSize:14];
    
    static char shareBtnKey;
    UIButton *shareBtn = objc_getAssociatedObject(self, &shareBtnKey);
    if (!shareBtn) {
        shareBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [shareBtn setTitle:@" 转发" forState:UIControlStateNormal];
        [shareBtn setTitleColor:titleColor forState:UIControlStateNormal];
        shareBtn.titleLabel.font = font;
        
        // 使用预加载的系统图标
        UIImage *forwardImage = [UIImage forwardIcon];
        if (forwardImage) {
            [shareBtn setImage:forwardImage forState:UIControlStateNormal];
        }
        
        [shareBtn addTarget:self action:@selector(xxx_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        // 立即计算尺寸
        [shareBtn sizeToFit];
        CGRect btnFrame = shareBtn.frame;
        btnFrame.size.height = likeBtn.frame.size.height;
        shareBtn.frame = btnFrame;
        
        [likeBtn.superview addSubview:shareBtn];
        objc_setAssociatedObject(self, &shareBtnKey, shareBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // 强制立即布局
        [shareBtn.superview setNeedsLayout];
        [shareBtn.superview layoutIfNeeded];
    }
    
    static char lineViewKey;
    UIImageView *lineView2 = objc_getAssociatedObject(self, &lineViewKey);
    if (!lineView2) {
        Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
        UIImageView *originalLineView = lineViewIvar ? object_getIvar(self, lineViewIvar) : nil;
        
        if (originalLineView && [originalLineView isKindOfClass:[UIImageView class]]) {
            lineView2 = [[UIImageView alloc] initWithImage:originalLineView.image];
            [likeBtn.superview addSubview:lineView2];
            objc_setAssociatedObject(self, &lineViewKey, lineView2, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    UIView *view = (UIView *)self;
    CGRect frame = view.frame;
    frame = CGRectOffset(CGRectInset(frame, frame.size.width / -4, 0), frame.size.width / -4, 0);
    view.frame = frame;
    
    // 立即设置转发按钮位置
    CGFloat shareBtnX = CGRectGetMaxX(likeBtn.frame) + likeBtn.frame.size.width;
    shareBtn.frame = CGRectMake(shareBtnX, 
                               likeBtn.frame.origin.y, 
                               CGRectGetWidth(shareBtn.frame), 
                               CGRectGetHeight(likeBtn.frame));
    
    if (lineView2) {
        Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
        UIImageView *originalLineView = lineViewIvar ? object_getIvar(self, lineViewIvar) : nil;
        
        if (originalLineView) {
            CGFloat width = likeBtn.frame.size.width;
            if ([self respondsToSelector:@selector(buttonWidth:)]) {
                width = [(id)self buttonWidth:likeBtn];
            }
            lineView2.frame = CGRectOffset(originalLineView.frame, width, 0);
        }
    }
    
    // 确保立即显示
    [shareBtn setNeedsDisplay];
    [shareBtn layoutIfNeeded];
}

@end