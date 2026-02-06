#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - WCOperateFloatView 朋友圈转发功能

@interface WCOperateFloatView : UIView
@property (nonatomic, weak) UINavigationController *navigationController;
@property (nonatomic, strong) WCDataItem *m_item;
@property (nonatomic, readonly) UIButton *m_likeBtn;
@end

@interface WCDataItem : NSObject
@end

@interface WCForwardViewController : UIViewController
- (instancetype)initWithDataItem:(WCDataItem *)item;
@end

@interface WCOperateFloatView (ForwardExtension)
@property (nonatomic, strong) UIButton *m_shareBtn;
@property (nonatomic, strong) UIImageView *m_lineView2;
@end

@implementation WCOperateFloatView (ForwardExtension)

static char m_shareBtnKey;
static char m_lineView2Key;

- (UIButton *)m_shareBtn {
    UIButton *btn = objc_getAssociatedObject(self, &m_shareBtnKey);
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        [btn setTitleColor:self.m_likeBtn.currentTitleColor forState:UIControlStateNormal];
        btn.titleLabel.font = self.m_likeBtn.titleLabel.font;
        [self.m_likeBtn.superview addSubview:btn];
        
        // Base64 编码的分享图标
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaAZWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveO34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:UIControlStateNormal];
        [btn setTintColor:self.m_likeBtn.tintColor];
        
        objc_setAssociatedObject(self, &m_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

- (UIImageView *)m_lineView2 {
    UIImageView *imageView = objc_getAssociatedObject(self, &m_lineView2Key);
    if (!imageView) {
        // 获取原始的 m_lineView
        Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
        UIImageView *originalLineView = object_getIvar(self, lineViewIvar);
        
        imageView = [[UIImageView alloc] initWithImage:originalLineView.image];
        [self.m_likeBtn.superview addSubview:imageView];
        objc_setAssociatedObject(self, &m_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return imageView;
}

- (void)forwordTimeLine:(id)sender {
    if (self.m_item && self.navigationController) {
        WCForwardViewController *forwardVC = [[objc_getClass("WCForwardViewController") alloc] initWithDataItem:self.m_item];
        [self.navigationController pushViewController:forwardVC animated:YES];
    }
}

- (double)buttonWidth:(UIButton *)button {
    return [button.titleLabel sizeThatFits:CGSizeMake(CGFLOAT_MAX, button.frame.size.height)].width + 30;
}

@end

#pragma mark - 方法交换实现

@implementation WCOperateFloatView (ForwardSwizzle)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 交换 showWithItemData:tipPoint: 方法
        Class class = [self class];
        
        SEL originalSelector = @selector(showWithItemData:tipPoint:);
        SEL swizzledSelector = @selector(swizzled_showWithItemData:tipPoint:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL didAddMethod = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (void)swizzled_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    // 调用原始方法
    [self swizzled_showWithItemData:arg1 tipPoint:arg2];
    
    // 调整布局，为转发按钮腾出空间
    CGRect frame = self.frame;
    frame = CGRectOffset(CGRectInset(frame, frame.size.width / -4, 0), frame.size.width / -4, 0);
    self.frame = frame;
    
    // 设置转发按钮的位置
    self.m_shareBtn.frame = CGRectOffset(self.m_likeBtn.frame, self.m_likeBtn.frame.size.width * 2, 0);
    
    // 设置第二条分割线的位置
    Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
    UIImageView *originalLineView = object_getIvar(self, lineViewIvar);
    self.m_lineView2.frame = CGRectOffset(originalLineView.frame, [self buttonWidth:self.m_likeBtn], 0);
}

@end