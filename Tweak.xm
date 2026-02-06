// ============ WeChatForwardTweak.xm ============
// 朋友圈转发功能插件
// 功能：在朋友圈浮窗菜单中添加“转发”按钮
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
static void swizzleMethod(Class class, SEL originalSelector, SEL swizzledSelector) {
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
    BOOL didAddMethod = class_addMethod(class, originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    if (didAddMethod) {
        class_replaceMethod(class, swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

// ============ 转发按钮图标 ============
static NSString *const kForwardIconBase64 = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaAZWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";

// ============ 转发功能实现 ============
@implementation WCOperateFloatView (ForwardExtension)

#pragma mark - 添加转发按钮
- (UIButton *)m_shareBtn {
    static char m_shareBtnKey;
    UIButton *btn = objc_getAssociatedObject(self, &m_shareBtnKey);
    if (!btn) {
        // 创建转发按钮
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        [btn setTitleColor:self.m_likeBtn.currentTitleColor forState:UIControlStateNormal];
        btn.titleLabel.font = self.m_likeBtn.titleLabel.font;
        
        // 设置按钮图标
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:kForwardIconBase64 
                                                               options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:UIControlStateNormal];
        [btn setTintColor:self.m_likeBtn.tintColor];
        
        // 添加到视图
        [self.m_likeBtn.superview addSubview:btn];
        objc_setAssociatedObject(self, &m_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

#pragma mark - 添加分割线
- (UIImageView *)m_lineView2 {
    static char m_lineView2Key;
    UIImageView *imageView = objc_getAssociatedObject(self, &m_lineView2Key);
    if (!imageView) {
        // 获取原始分割线
        UIImageView *originalLineView = nil;
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList([self class], &count);
        for (unsigned int i = 0; i < count; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            if (strstr(name, "m_lineView")) {
                originalLineView = object_getIvar(self, ivar);
                break;
            }
        }
        free(ivars);
        
        if (originalLineView) {
            imageView = [[UIImageView alloc] initWithImage:originalLineView.image];
            [self.m_likeBtn.superview addSubview:imageView];
            objc_setAssociatedObject(self, &m_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    return imageView;
}

#pragma mark - 转发操作
- (void)forwordTimeLine:(id)sender {
    Class forwardVCClass = objc_getClass("WCForwardViewController");
    if (forwardVCClass && self.m_item) {
        WCForwardViewController *forwardVC = [[forwardVCClass alloc] initWithDataItem:self.m_item];
        if (forwardVC && self.navigationController) {
            [self.navigationController pushViewController:forwardVC animated:YES];
        }
    }
}

#pragma mark - 布局调整
- (void)adjusted_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    // 调用原始方法
    [self adjusted_showWithItemData:arg1 tipPoint:arg2];
    
    // 调整布局以适应转发按钮
    CGRect frame = self.frame;
    frame = CGRectOffset(CGRectInset(frame, frame.size.width / -4, 0), frame.size.width / -4, 0);
    self.frame = frame;
    
    // 设置转发按钮位置
    self.m_shareBtn.frame = CGRectOffset(self.m_likeBtn.frame, self.m_likeBtn.frame.size.width * 2, 0);
    
    // 设置第二条分割线位置
    UIImageView *originalLineView = nil;
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList([self class], &count);
    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        if (strstr(name, "m_lineView")) {
            originalLineView = object_getIvar(self, ivar);
            break;
        }
    }
    free(ivars);
    
    if (originalLineView && self.m_lineView2) {
        self.m_lineView2.frame = CGRectOffset(originalLineView.frame, [self buttonWidth:self.m_likeBtn], 0);
    }
}

@end

// ============ 插件入口 ============
__attribute__((constructor)) static void entry() {
    @autoreleasepool {
        // Hook WCOperateFloatView的显示方法
        Class class = objc_getClass("WCOperateFloatView");
        if (class) {
            swizzleMethod(class, 
                         @selector(showWithItemData:tipPoint:), 
                         @selector(adjusted_showWithItemData:tipPoint:));
            NSLog(@"[WeChatForwardTweak] 朋友圈转发功能已启用");
        }
    }
}