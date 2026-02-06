#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

// 声明必要的类
@interface WCDataItem : NSObject
@end

@interface WCForwardViewController : UIViewController
- (instancetype)initWithDataItem:(WCDataItem *)item;
@end

@interface WCOperateFloatView : UIView
@property (nonatomic, weak) UINavigationController *navigationController;
@property (nonatomic, strong) WCDataItem *m_item;
@property (nonatomic, readonly) UIButton *m_likeBtn;
@property (nonatomic, readonly) UIImageView *m_lineView;
- (double)buttonWidth:(UIButton *)button;
- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2;
@end

// 分类扩展
@interface WCOperateFloatView (ForwardExtension)
@property (nonatomic, strong) UIButton *m_shareBtn;
@property (nonatomic, strong) UIImageView *m_lineView2;
- (void)forwordTimeLine:(id)sender;
@end

// 实现分类
@implementation WCOperateFloatView (ForwardExtension)

static char m_shareBtnKey;
static char m_lineView2Key;

#pragma mark - 关联对象属性实现

// m_shareBtn的getter
- (UIButton *)m_shareBtn {
    UIButton *btn = objc_getAssociatedObject(self, &m_shareBtnKey);
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        // 使用当前按钮的样式
        if (self.m_likeBtn) {
            [btn setTitleColor:[self.m_likeBtn titleColorForState:UIControlStateNormal] forState:UIControlStateNormal];
            btn.titleLabel.font = self.m_likeBtn.titleLabel.font;
            [btn setTintColor:self.m_likeBtn.tintColor];
        } else {
            [btn setTitleColor:[UIColor darkTextColor] forState:UIControlStateNormal];
            btn.titleLabel.font = [UIFont systemFontOfSize:14];
        }
        
        // 添加分享图标
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Unek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaAZWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:UIControlStateNormal];
        
        // 添加到父视图
        if (self.m_likeBtn && self.m_likeBtn.superview) {
            [self.m_likeBtn.superview addSubview:btn];
        }
        
        objc_setAssociatedObject(self, &m_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

// m_shareBtn的setter
- (void)setM_shareBtn:(UIButton *)m_shareBtn {
    objc_setAssociatedObject(self, &m_shareBtnKey, m_shareBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

// m_lineView2的getter
- (UIImageView *)m_lineView2 {
    UIImageView *imageView = objc_getAssociatedObject(self, &m_lineView2Key);
    if (!imageView) {
        // 创建新的分割线
        if (self.m_lineView && self.m_lineView.image) {
            imageView = [[UIImageView alloc] initWithImage:self.m_lineView.image];
        } else {
            // 创建默认分割线
            imageView = [[UIImageView alloc] init];
            imageView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        }
        
        // 添加到父视图
        if (self.m_likeBtn && self.m_likeBtn.superview) {
            [self.m_likeBtn.superview addSubview:imageView];
        }
        
        objc_setAssociatedObject(self, &m_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return imageView;
}

// m_lineView2的setter
- (void)setM_lineView2:(UIImageView *)m_lineView2 {
    objc_setAssociatedObject(self, &m_lineView2Key, m_lineView2, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - 转发功能

// 转发按钮点击事件
- (void)forwordTimeLine:(id)sender {
    if (self.m_item && self.navigationController) {
        Class WCForwardViewControllerClass = objc_getClass("WCForwardViewController");
        if (WCForwardViewControllerClass) {
            // 使用runtime直接调用方法，避免ARC警告
            id forwardVC = ((id (*)(id, SEL, id))objc_msgSend)([WCForwardViewControllerClass alloc], @selector(initWithDataItem:), self.m_item);
            if (forwardVC && self.navigationController) {
                [self.navigationController pushViewController:forwardVC animated:YES];
            }
        }
    }
}

@end

#pragma mark - 方法交换实现

@implementation WCOperateFloatView (ForwardSwizzle)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 交换 showWithItemData:tipPoint: 方法
        Class clazz = objc_getClass("WCOperateFloatView");
        if (!clazz) return;
        
        SEL originalSelector = NSSelectorFromString(@"showWithItemData:tipPoint:");
        SEL swizzledSelector = @selector(swizzled_showWithItemData:tipPoint:);
        
        Method originalMethod = class_getInstanceMethod(clazz, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(clazz, swizzledSelector);
        
        // 如果当前类没有实现swizzled方法，先添加
        if (!class_addMethod(clazz, swizzledSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod))) {
            // 方法已经存在，直接交换
            method_exchangeImplementations(originalMethod, swizzledMethod);
        } else {
            // 添加成功，现在originalMethod指向原始实现，swizzledMethod指向交换后的实现
            // 重新获取swizzledMethod（因为刚添加的）
            swizzledMethod = class_getInstanceMethod(clazz, swizzledSelector);
            if (originalMethod && swizzledMethod) {
                method_exchangeImplementations(originalMethod, swizzledMethod);
            }
        }
    });
}

// 新的showWithItemData:tipPoint:实现
- (void)swizzled_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    // 调用原始方法
    [self swizzled_showWithItemData:arg1 tipPoint:arg2];
    
    // 确保有like按钮
    if (!self.m_likeBtn) return;
    
    // 调整布局，为转发按钮腾出空间
    CGRect frame = self.frame;
    CGFloat newWidth = frame.size.width * 1.5; // 增加50%的宽度
    CGFloat newX = frame.origin.x - (newWidth - frame.size.width) / 2;
    self.frame = CGRectMake(newX, frame.origin.y, newWidth, frame.size.height);
    
    // 设置转发按钮的位置（在点赞和评论按钮之间）
    if (self.m_shareBtn.superview == nil) {
        [self.m_likeBtn.superview addSubview:self.m_shareBtn];
    }
    
    CGFloat buttonWidth = CGRectGetWidth(self.m_likeBtn.frame);
    self.m_shareBtn.frame = CGRectMake(buttonWidth * 1, 0, buttonWidth, CGRectGetHeight(self.m_likeBtn.frame));
    
    // 设置第二条分割线的位置
    if (self.m_lineView2.superview == nil) {
        [self.m_likeBtn.superview addSubview:self.m_lineView2];
    }
    
    if (self.m_lineView) {
        CGRect lineFrame = self.m_lineView.frame;
        self.m_lineView2.frame = CGRectMake(buttonWidth * 1, lineFrame.origin.y, lineFrame.size.width, lineFrame.size.height);
    }
}

@end