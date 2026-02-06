// DDTimeLineForward.m
// DD朋友圈转发插件
// 版本：1.0.0

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// MARK: - 插件管理器接口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

// MARK: - 配置管理器
@interface DDTimeLineForwardConfig : NSObject
+ (BOOL)timeLineForwardEnable;
+ (void)setTimeLineForwardEnable:(BOOL)value;
@end

@implementation DDTimeLineForwardConfig

+ (NSString *)userDefaultsKey {
    return @"DDTimeLineForwardEnable";
}

+ (BOOL)timeLineForwardEnable {
    return [[NSUserDefaults standardUserDefaults] boolForKey:[self userDefaultsKey]];
}

+ (void)setTimeLineForwardEnable:(BOOL)value {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:[self userDefaultsKey]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

// MARK: - Hook实现
__attribute__((constructor)) static void DDTimeLineForwardSetup() {
    @autoreleasepool {
        // 注册到插件管理器
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerSwitchWithTitle:@"DD朋友圈转发" key:@"DDTimeLineForwardEnable"];
        }
        
        // 等待UI初始化完成
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self setupHooks];
        });
    }
}

// MARK: - Hook WCOperateFloatView
@interface WCOperateFloatView (DDTimeLineForward)
@property (nonatomic, strong) UIButton *dd_shareBtn;
@property (nonatomic, strong) UIImageView *dd_lineView2;
- (void)dd_forwordTimeLine:(id)sender;
- (void)dd_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2;
@end

@implementation WCOperateFloatView (DDTimeLineForward)

static char ddShareBtnKey;
static char ddLineView2Key;

- (UIButton *)dd_shareBtn {
    return objc_getAssociatedObject(self, &ddShareBtnKey);
}

- (void)setDd_shareBtn:(UIButton *)dd_shareBtn {
    objc_setAssociatedObject(self, &ddShareBtnKey, dd_shareBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIImageView *)dd_lineView2 {
    return objc_getAssociatedObject(self, &ddLineView2Key);
}

- (void)setDd_lineView2:(UIImageView *)dd_lineView2 {
    objc_setAssociatedObject(self, &ddLineView2Key, dd_lineView2, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)dd_forwordTimeLine:(id)sender {
    if (![DDTimeLineForwardConfig timeLineForwardEnable]) return;
    
    // 获取当前的数据项并转发
    id dataItem = [self valueForKey:@"m_item"];
    if (dataItem) {
        Class forwardVCClass = objc_getClass("WCForwardViewController");
        if (forwardVCClass) {
            id forwardVC = [[forwardVCClass alloc] initWithDataItem:dataItem];
            UINavigationController *navController = (UINavigationController *)[self valueForKey:@"navigationController"];
            if (navController && [navController respondsToSelector:@selector(pushViewController:animated:)]) {
                [navController pushViewController:forwardVC animated:YES];
            }
        }
    }
}

- (void)dd_showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    // 调用原始方法
    SEL originalSelector = NSSelectorFromString(@"showWithItemData:tipPoint:");
    IMP originalImp = class_getMethodImplementation([self class], originalSelector);
    if (originalImp) {
        ((void (*)(id, SEL, id, CGPoint))originalImp)(self, originalSelector, arg1, arg2);
    }
    
    // 如果转发功能未开启，直接返回
    if (![DDTimeLineForwardConfig timeLineForwardEnable]) return;
    
    // 添加转发按钮
    if (!self.dd_shareBtn) {
        // 获取点赞按钮作为样式参考
        UIButton *likeBtn = [self valueForKey:@"m_likeBtn"];
        if (!likeBtn) return;
        
        // 创建转发按钮
        UIButton *shareBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [shareBtn setTitle:@" 转发" forState:UIControlStateNormal];
        [shareBtn addTarget:self action:@selector(dd_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        [shareBtn setTitleColor:[likeBtn titleColorForState:UIControlStateNormal] forState:UIControlStateNormal];
        shareBtn.titleLabel.font = likeBtn.titleLabel.font;
        
        // 添加转发图标
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaABWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        if (image) {
            [shareBtn setImage:image forState:UIControlStateNormal];
            [shareBtn setTintColor:[likeBtn tintColor]];
        }
        
        [likeBtn.superview addSubview:shareBtn];
        self.dd_shareBtn = shareBtn;
        
        // 创建分隔线
        UIImageView *lineView2 = [[UIImageView alloc] initWithImage:[self findOriginalLineView].image];
        [likeBtn.superview addSubview:lineView2];
        self.dd_lineView2 = lineView2;
    }
    
    // 调整布局
    if ([DDTimeLineForwardConfig timeLineForwardEnable]) {
        UIButton *likeBtn = [self valueForKey:@"m_likeBtn"];
        if (likeBtn && self.dd_shareBtn && self.dd_lineView2) {
            // 调整整个浮窗的宽度
            CGRect frame = self.frame;
            frame = CGRectOffset(CGRectInset(frame, frame.size.width / -4, 0), frame.size.width / -4, 0);
            self.frame = frame;
            
            // 调整转发按钮位置
            self.dd_shareBtn.frame = CGRectOffset(likeBtn.frame, likeBtn.frame.size.width * 2, 0);
            
            // 调整分隔线位置
            UIImageView *originalLineView = [self findOriginalLineView];
            if (originalLineView) {
                CGRect lineFrame = originalLineView.frame;
                lineFrame = CGRectOffset(lineFrame, [self buttonWidth:likeBtn], 0);
                self.dd_lineView2.frame = lineFrame;
            }
        }
    }
}

// 辅助方法
- (UIImageView *)findOriginalLineView {
    unsigned int count = 0;
    Ivar *ivars = class_copyIvarList([self class], &count);
    UIImageView *originalLineView = nil;
    
    for (unsigned int i = 0; i < count; i++) {
        Ivar ivar = ivars[i];
        const char *name = ivar_getName(ivar);
        const char *type = ivar_getTypeEncoding(ivar);
        
        if (strstr(type, "UIImageView") && strstr(name, "line")) {
            originalLineView = object_getIvar(self, ivar);
            break;
        }
    }
    
    free(ivars);
    return originalLineView;
}

- (double)buttonWidth:(UIButton *)button {
    // 计算按钮宽度
    NSString *title = [button titleForState:UIControlStateNormal];
    UIImage *image = [button imageForState:UIControlStateNormal];
    
    CGSize titleSize = [title sizeWithAttributes:@{NSFontAttributeName: button.titleLabel.font}];
    CGFloat width = titleSize.width;
    if (image) {
        width += image.size.width + 5; // 图片和文字间距
    }
    width += 20; // 左右边距
    
    return width;
}

@end

// MARK: - 设置Hook
static void setupHooks() {
    Class class = objc_getClass("WCOperateFloatView");
    if (!class) return;
    
    SEL originalSelector = NSSelectorFromString(@"showWithItemData:tipPoint:");
    SEL swizzledSelector = NSSelectorFromString(@"dd_showWithItemData:tipPoint:");
    
    Method originalMethod = class_getInstanceMethod(class, originalSelector);
    Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
    
    if (!originalMethod || !swizzledMethod) return;
    
    BOOL didAddMethod = class_addMethod(class,
                                        originalSelector,
                                        method_getImplementation(swizzledMethod),
                                        method_getTypeEncoding(swizzledMethod));
    
    if (didAddMethod) {
        class_replaceMethod(class,
                            swizzledSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
    } else {
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}