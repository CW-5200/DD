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
        // 使用iOS 13+系统图标
        UIImage *systemIcon = [UIImage systemImageNamed:@"arrowshape.turn.up.right.fill"];
        
        if (systemIcon) {
            // 配置图标为白色，适配黑暗模式
            UIImageConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:14 weight:UIImageSymbolWeightRegular];
            icon = [systemIcon imageByApplyingSymbolConfiguration:config];
            
            // 将图标渲染为白色
            icon = [icon imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        }
    });
    return icon;
}

@end

__attribute__((constructor)) static void entry() {
    @autoreleasepool {
        Class cls = objc_getClass("WCOperateFloatView");
        if (!cls) return;
        
        // 在运行时预先准备好按钮，避免第一次创建延迟
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            // 预创建按钮但不添加到视图
            UIButton *preparedBtn = [UIButton buttonWithType:UIButtonTypeSystem];
            [preparedBtn setTitle:@" 转发" forState:UIControlStateNormal];
            [preparedBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            preparedBtn.titleLabel.font = [UIFont systemFontOfSize:14];
            
            // 预加载图片
            UIImage *forwardImage = [UIImage forwardIcon];
            if (forwardImage) {
                [preparedBtn setImage:forwardImage forState:UIControlStateNormal];
            }
            
            [preparedBtn sizeToFit];
        });
        
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
    // 先调用原始方法，确保布局完成
    [self xxx_showWithItemData:arg1 tipPoint:arg2];
    
    UIButton *likeBtn = [self valueForKey:@"m_likeBtn"];
    if (!likeBtn) return;
    
    static char shareBtnKey;
    UIButton *shareBtn = objc_getAssociatedObject(self, &shareBtnKey);
    
    if (!shareBtn) {
        shareBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [shareBtn setTitle:@" 转发" forState:UIControlStateNormal];
        [shareBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        shareBtn.titleLabel.font = [UIFont systemFontOfSize:14];
        shareBtn.tintColor = [UIColor whiteColor]; // 确保图标颜色为白色
        
        UIImage *forwardImage = [UIImage forwardIcon];
        if (forwardImage) {
            [shareBtn setImage:forwardImage forState:UIControlStateNormal];
            
            // 调整图标位置：向右移动一点
            shareBtn.imageEdgeInsets = UIEdgeInsetsMake(0, 4, 0, -4);
            shareBtn.titleEdgeInsets = UIEdgeInsetsMake(0, 8, 0, -8);
        }
        
        [shareBtn addTarget:self action:@selector(xxx_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        // 提前计算尺寸
        [shareBtn sizeToFit];
        CGRect btnFrame = shareBtn.frame;
        btnFrame.size.height = likeBtn.frame.size.height;
        btnFrame.size.width += 12; // 增加宽度以便图标有更多空间
        shareBtn.frame = btnFrame;
        
        [likeBtn.superview addSubview:shareBtn];
        objc_setAssociatedObject(self, &shareBtnKey, shareBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
    
    // 调整整个浮窗的frame，为转发按钮腾出空间
    UIView *view = (UIView *)self;
    CGRect frame = view.frame;
    frame = CGRectOffset(CGRectInset(frame, frame.size.width / -4, 0), frame.size.width / -4, 0);
    view.frame = frame;
    
    // 立即设置转发按钮位置，放在点赞按钮右侧
    CGFloat shareBtnX = CGRectGetMaxX(likeBtn.frame) + likeBtn.frame.size.width * 0.8; // 稍微向右移动
    shareBtn.frame = CGRectMake(shareBtnX, 
                               likeBtn.frame.origin.y, 
                               CGRectGetWidth(shareBtn.frame), 
                               CGRectGetHeight(likeBtn.frame));
    
    // 确保按钮立即显示
    shareBtn.hidden = NO;
    [shareBtn.superview bringSubviewToFront:shareBtn];
    
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
    
    // 强制立即刷新显示
    [shareBtn layoutIfNeeded];
    [shareBtn setNeedsDisplay];
}

@end