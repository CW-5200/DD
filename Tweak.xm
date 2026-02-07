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
        // 预渲染的18x18图标（白色箭头图标）
        // 这是硬编码的PNG base64数据，避免运行时绘制
        NSString *base64String = @"iVBORw0KGgoAAAANSUhEUgAAABIAAAASCAYAAABWzo5XAAAAAXNSR0IArs4c6QAAAVlpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IlhNUCBDb3JlIDUuNC4wIj4KICAgPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4KICAgICAgPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIKICAgICAgICAgICAgeG1sbnM6dGlmZj0iaHR0cDovL25zLmFkb2JlLmNvbS90aWZmLzEuMC8iPgogICAgICAgICA8dGlmZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVudGF0aW9uPgogICAgICA8L3JkZjpEZXNjcmlwdGlvbj4KICAgPC9yZGY6UkRGPgo8L3g6eG1wbWV0YT4KTMInWQAAANxJREFUOBGtVLsRwyAQrO7BKVy4p+gglZv8Tdyl3lI/QZJz5s6g8Y89HobDnKA8v0IIiQ/2nHP53a21uq7r9/VTnueTECJZ2x6UJBN8No/jeBJF0QkAJcaYLY7j8+A4TkL0l4AH14Oqqg8IfGM8YMV8hXz7CgAAAABJRU5ErkJggg==";
        
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64String options:NSDataBase64DecodingIgnoreUnknownCharacters];
        icon = [UIImage imageWithData:imageData scale:3.0]; // @3x scale for retina
        icon = [icon imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    });
    return icon;
}

@end

__attribute__((constructor)) static void entry() {
    @autoreleasepool {
        // 预加载图标，避免第一次使用时延迟
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
    
    // 直接使用系统字体和颜色，避免从likeBtn获取时的延迟
    UIColor *titleColor = [UIColor whiteColor];
    UIFont *font = [UIFont systemFontOfSize:14];
    
    static char shareBtnKey;
    UIButton *shareBtn = objc_getAssociatedObject(self, &shareBtnKey);
    if (!shareBtn) {
        shareBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [shareBtn setTitle:@" 转发" forState:UIControlStateNormal];
        [shareBtn setTitleColor:titleColor forState:UIControlStateNormal];
        shareBtn.titleLabel.font = font;
        [shareBtn setImage:[UIImage forwardIcon] forState:UIControlStateNormal];
        [shareBtn addTarget:self action:@selector(xxx_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        // 立即设置尺寸，避免布局延迟
        shareBtn.frame = CGRectMake(0, 0, 60, likeBtn.frame.size.height);
        [shareBtn sizeToFit];
        
        [likeBtn.superview addSubview:shareBtn];
        objc_setAssociatedObject(self, &shareBtnKey, shareBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        // 立即布局
        [likeBtn.superview setNeedsLayout];
        [likeBtn.superview layoutIfNeeded];
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
    
    // 立即计算并设置shareBtn的位置
    CGFloat shareBtnX = CGRectGetMaxX(likeBtn.frame) + likeBtn.frame.size.width;
    shareBtn.frame = CGRectMake(shareBtnX, likeBtn.frame.origin.y, 
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
    
    // 强制立即显示
    [shareBtn setNeedsDisplay];
    [shareBtn.superview setNeedsLayout];
    [shareBtn.superview layoutIfNeeded];
}

@end