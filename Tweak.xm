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
        UIImage *systemIcon = [UIImage systemImageNamed:@"arrowshape.turn.up.right.fill"];
        
        if (systemIcon) {
            // 调整图标大小适配按钮
            CGSize newSize = CGSizeMake(16, 16);
            UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0);
            [UIColor.whiteColor set]; // 确保图标是白色
            [systemIcon drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
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
        [UIImage forwardIcon];
        
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
    
    // 立即创建转发按钮，避免延迟
    static char shareBtnKey;
    UIButton *shareBtn = objc_getAssociatedObject(self, &shareBtnKey);
    if (!shareBtn) {
        shareBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        
        // 设置文字 - 向右移动图标
        [shareBtn setTitle:@" 转发" forState:UIControlStateNormal];
        [shareBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        shareBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        
        // 设置白色图标
        UIImage *forwardImage = [UIImage forwardIcon];
        if (forwardImage) {
            // 调整图标位置，向右移动2像素
            [shareBtn setImage:forwardImage forState:UIControlStateNormal];
            shareBtn.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 0);
            shareBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 2, 0, 0); // 文字向右移动2像素
        }
        
        [shareBtn addTarget:self action:@selector(xxx_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        // 立即设置尺寸
        [shareBtn sizeToFit];
        CGRect btnFrame = shareBtn.frame;
        btnFrame.size.height = likeBtn.frame.size.height;
        btnFrame.size.width += 8; // 增加宽度确保图标不靠左
        shareBtn.frame = btnFrame;
        
        [likeBtn.superview addSubview:shareBtn];
        objc_setAssociatedObject(self, &shareBtnKey, shareBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    // 立即计算并设置转发按钮位置
    CGFloat shareBtnX = CGRectGetMaxX(likeBtn.frame) + likeBtn.frame.size.width;
    CGRect shareBtnFrame = shareBtn.frame;
    shareBtnFrame.origin.x = shareBtnX;
    shareBtnFrame.origin.y = likeBtn.frame.origin.y;
    shareBtnFrame.size.height = likeBtn.frame.size.height;
    shareBtn.frame = shareBtnFrame;
    
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
    
    // 调整父视图的frame
    UIView *view = (UIView *)self;
    CGRect frame = view.frame;
    frame = CGRectOffset(CGRectInset(frame, frame.size.width / -4, 0), frame.size.width / -4, 0);
    view.frame = frame;
    
    // 设置分隔线位置
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