#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 声明必要的类
@interface WCDataItem : NSObject
@end

@interface WCForwardViewController : UIViewController
- (instancetype)initWithDataItem:(WCDataItem *)item;
@end

// 这是一个简单的实现，不依赖具体的类结构
__attribute__((constructor)) static void entry() {
    @autoreleasepool {
        NSLog(@"[DD] Loading WeChat Moments Forward plugin...");
        
        // 交换 showWithItemData:tipPoint: 方法
        Class WCOperateFloatViewClass = objc_getClass("WCOperateFloatView");
        if (!WCOperateFloatViewClass) {
            NSLog(@"[DD] WCOperateFloatView class not found!");
            return;
        }
        
        // 获取原始方法
        SEL originalSelector = NSSelectorFromString(@"showWithItemData:tipPoint:");
        SEL swizzledSelector = @selector(dd_showWithItemData:tipPoint:);
        
        Method originalMethod = class_getInstanceMethod(WCOperateFloatViewClass, originalSelector);
        if (!originalMethod) {
            NSLog(@"[DD] Original method not found!");
            return;
        }
        
        // 添加新方法
        BOOL didAddMethod = class_addMethod(WCOperateFloatViewClass, 
                                           swizzledSelector, 
                                           (IMP)dd_showWithItemData, 
                                           "v@:@@{CGPoint=dd}");
        
        if (!didAddMethod) {
            NSLog(@"[DD] Failed to add method!");
            return;
        }
        
        // 交换方法
        Method swizzledMethod = class_getInstanceMethod(WCOperateFloatViewClass, swizzledSelector);
        method_exchangeImplementations(originalMethod, swizzledMethod);
        
        // 添加转发按钮点击方法
        class_addMethod(WCOperateFloatViewClass, 
                       @selector(dd_forwordTimeLine:), 
                       (IMP)dd_forwordTimeLine, 
                       "v@:@");
        
        NSLog(@"[DD] WeChat Moments Forward plugin loaded successfully!");
    }
}

// 转发按钮点击实现
static void dd_forwordTimeLine(id self, SEL _cmd, id sender) {
    // 获取item属性
    Ivar itemIvar = class_getInstanceVariable([self class], "m_item");
    id item = object_getIvar(self, itemIvar);
    
    // 获取navigationController属性
    Ivar navIvar = class_getInstanceVariable([self class], "m_navigationController");
    if (!navIvar) {
        navIvar = class_getInstanceVariable([self class], "_navigationController");
    }
    
    UINavigationController *navController = object_getIvar(self, navIvar);
    
    if (item && navController) {
        Class WCForwardViewControllerClass = objc_getClass("WCForwardViewController");
        if (WCForwardViewControllerClass) {
            // 创建转发页面
            id forwardVC = ((id (*)(id, SEL, id))objc_msgSend)([WCForwardViewControllerClass alloc], 
                                                               @selector(initWithDataItem:), 
                                                               item);
            if (forwardVC) {
                [navController pushViewController:forwardVC animated:YES];
            }
        }
    }
}

// 新的showWithItemData:tipPoint:实现
static void dd_showWithItemData(id self, SEL _cmd, id arg1, struct CGPoint arg2) {
    // 调用原始方法
    ((void (*)(id, SEL, id, struct CGPoint))objc_msgSend)(self, 
                                                         NSSelectorFromString(@"dd_showWithItemData:tipPoint:"), 
                                                         arg1, 
                                                         arg2);
    
    // 获取like按钮
    Ivar likeBtnIvar = class_getInstanceVariable([self class], "m_likeBtn");
    UIButton *likeBtn = object_getIvar(self, likeBtnIvar);
    
    if (!likeBtn) return;
    
    // 调整视图大小
    CGRect frame = self.frame;
    CGFloat newWidth = frame.size.width * 1.5;
    CGFloat newX = frame.origin.x - (newWidth - frame.size.width) / 2;
    self.frame = CGRectMake(newX, frame.origin.y, newWidth, frame.size.height);
    
    // 创建转发按钮
    UIButton *shareBtn = nil;
    static char shareBtnKey;
    shareBtn = objc_getAssociatedObject(self, &shareBtnKey);
    
    if (!shareBtn) {
        shareBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [shareBtn setTitle:@" 转发" forState:UIControlStateNormal];
        [shareBtn addTarget:self action:@selector(dd_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        // 设置样式
        [shareBtn setTitleColor:[likeBtn titleColorForState:UIControlStateNormal] forState:UIControlStateNormal];
        shareBtn.titleLabel.font = likeBtn.titleLabel.font;
        
        // 添加分享图标
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Unek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWVgc0saCvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaAZWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [shareBtn setImage:image forState:UIControlStateNormal];
        
        // 添加到视图
        [likeBtn.superview addSubview:shareBtn];
        objc_setAssociatedObject(self, &shareBtnKey, shareBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    // 设置转发按钮位置
    CGFloat buttonWidth = CGRectGetWidth(likeBtn.frame);
    shareBtn.frame = CGRectMake(buttonWidth, 0, buttonWidth, CGRectGetHeight(likeBtn.frame));
    
    // 创建第二条分割线
    UIImageView *lineView2 = nil;
    static char lineView2Key;
    lineView2 = objc_getAssociatedObject(self, &lineView2Key);
    
    if (!lineView2) {
        // 获取原始分割线
        Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
        if (!lineViewIvar) {
            lineViewIvar = class_getInstanceVariable([self class], "_lineView");
        }
        
        UIImageView *originalLineView = object_getIvar(self, lineViewIvar);
        
        if (originalLineView && originalLineView.image) {
            lineView2 = [[UIImageView alloc] initWithImage:originalLineView.image];
        } else {
            lineView2 = [[UIImageView alloc] init];
            lineView2.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
        }
        
        [likeBtn.superview addSubview:lineView2];
        objc_setAssociatedObject(self, &lineView2Key, lineView2, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    // 设置第二条分割线位置
    Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
    if (!lineViewIvar) {
        lineViewIvar = class_getInstanceVariable([self class], "_lineView");
    }
    
    UIImageView *originalLineView = object_getIvar(self, lineViewIvar);
    if (originalLineView) {
        CGRect lineFrame = originalLineView.frame;
        lineView2.frame = CGRectMake(buttonWidth, lineFrame.origin.y, lineFrame.size.width, lineFrame.size.height);
    }
}