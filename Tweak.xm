// DDTimeLineForward.xm
// DD朋友圈转发插件 v1.0.0

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define DDTimeLineForwardEnableKey @"DDTimeLineForwardEnable"

// 声明微信相关类
@interface WCDataItem : NSObject
@end

@interface WCOperateFloatView : UIView {
    UIImageView *m_lineView;
}
@property(readonly, nonatomic) UIButton *m_likeBtn;
@property(readonly, nonatomic) UIButton *m_commentBtn;
@property(readonly, nonatomic) WCDataItem *m_item;
@property(nonatomic, weak) UINavigationController *navigationController;
- (double)buttonWidth:(UIButton *)button;
@end

@interface WCForwardViewController : UIViewController
- (id)initWithDataItem:(id)arg1;
@end

// 插件配置管理器
@interface DDTimeLineForwardManager : NSObject
+ (BOOL)isEnabled;
@end

@implementation DDTimeLineForwardManager
+ (BOOL)isEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:DDTimeLineForwardEnableKey];
}
@end

// 修复1: 使用Category而不是直接声明属性
@interface WCOperateFloatView (DDTimeLineForward)
@property (nonatomic, strong) UIButton *dd_shareBtn;
@property (nonatomic, strong) UIImageView *dd_lineView2;
@end

@implementation WCOperateFloatView (DDTimeLineForward)

- (UIButton *)dd_shareBtn {
    return objc_getAssociatedObject(self, @selector(dd_shareBtn));
}

- (void)setDd_shareBtn:(UIButton *)dd_shareBtn {
    objc_setAssociatedObject(self, @selector(dd_shareBtn), dd_shareBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIImageView *)dd_lineView2 {
    return objc_getAssociatedObject(self, @selector(dd_lineView2));
}

- (void)setDd_lineView2:(UIImageView *)dd_lineView2 {
    objc_setAssociatedObject(self, @selector(dd_lineView2), dd_lineView2, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

%hook WCOperateFloatView

%new
- (void)dd_setupShareButton {
    if (!self.dd_shareBtn) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(dd_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        // 使用与点赞按钮相同的样式
        [btn setTitleColor:[self.m_likeBtn titleColorForState:UIControlStateNormal] forState:UIControlStateNormal];
        btn.titleLabel.font = self.m_likeBtn.titleLabel.font;
        
        [self.m_likeBtn.superview addSubview:btn];
        
        // 使用原始代码中的base64图标
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWVgc0saCvAKnCWBm0H2A+cpEGbBkqSmfXlQXOBZjbgYgCDwIIDXZQ0aCrQzOaABWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4C12Q9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fqiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:UIControlStateNormal];
        [btn setTintColor:self.m_likeBtn.tintColor];
        
        self.dd_shareBtn = btn;
    }
}

%new
- (void)dd_setupLineView2 {
    if (!self.dd_lineView2) {
        // 获取原始分割线
        UIImageView *originalLineView = nil;
        unsigned int outCount = 0;
        Ivar *ivars = class_copyIvarList([self class], &outCount);
        for (unsigned int i = 0; i < outCount; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            if (strstr(name, "lineView")) {
                originalLineView = object_getIvar(self, ivar);
                break;
            }
        }
        free(ivars);
        
        UIImageView *imageView;
        if (originalLineView && [originalLineView isKindOfClass:[UIImageView class]]) {
            imageView = [[UIImageView alloc] initWithImage:originalLineView.image];
        } else {
            // 创建默认分割线
            imageView = [[UIImageView alloc] init];
            imageView.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
            imageView.frame = CGRectMake(0, 0, 0.5, 20);
        }
        
        [self.m_likeBtn.superview addSubview:imageView];
        self.dd_lineView2 = imageView;
    }
}

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig(arg1, arg2);
    
    if ([DDTimeLineForwardManager isEnabled]) {
        // 设置转发按钮和分割线
        [self dd_setupShareButton];
        [self dd_setupLineView2];
        
        // 调整整个视图的frame，与原始代码一致
        self.frame = CGRectOffset(CGRectInset(self.frame, self.frame.size.width / -4, 0), 
                                 self.frame.size.width / -4, 0);
        
        // 设置转发按钮位置
        self.dd_shareBtn.frame = CGRectOffset(self.m_likeBtn.frame, 
                                            self.m_likeBtn.frame.size.width * 2, 
                                            0);
        
        // 设置第二条分割线位置
        CGFloat buttonWidth = [self buttonWidth:self.m_likeBtn];
        self.dd_lineView2.frame = CGRectOffset(self.m_likeBtn.frame, buttonWidth, 0);
        self.dd_lineView2.hidden = NO;
        self.dd_shareBtn.hidden = NO;
    } else {
        // 如果功能关闭，隐藏转发按钮和第二条分割线
        self.dd_shareBtn.hidden = YES;
        self.dd_lineView2.hidden = YES;
    }
}

%new
- (void)dd_forwordTimeLine:(id)arg1 {
    if (![DDTimeLineForwardManager isEnabled]) return;
    
    // 使用原始代码中的转发逻辑
    Class forwardVCClass = objc_getClass("WCForwardViewController");
    if (forwardVCClass && self.m_item && self.navigationController) {
        WCForwardViewController *forwardVC = [[forwardVCClass alloc] initWithDataItem:self.m_item];
        if (forwardVC) {
            [self.navigationController pushViewController:forwardVC animated:YES];
        }
    }
}

%end

%ctor {
    @autoreleasepool {
        // 根据原始文件，插件管理器使用的是不同的方法
        // 原始文件使用的是: [objc_getClass("WCPluginsMgr") sharedInstance]
        // 但实际上微信的插件管理器可能有不同的实现
        
        // 修复2: 使用更通用的插件注册方式
        // 检查插件管理器是否存在
        Class pluginsMgrClass = objc_getClass("WCPluginsMgr");
        
        // 尝试不同的方法名
        SEL sharedSel = NSSelectorFromString(@"sharedInstance");
        SEL sharedMgrSel = NSSelectorFromString(@"sharedMgr");
        SEL defaultMgrSel = NSSelectorFromString(@"defaultMgr");
        
        id sharedMgr = nil;
        
        if (pluginsMgrClass) {
            // 尝试sharedInstance
            if ([pluginsMgrClass respondsToSelector:sharedSel]) {
                sharedMgr = ((id (*)(Class, SEL))[pluginsMgrClass methodForSelector:sharedSel])(pluginsMgrClass, sharedSel);
            }
            // 尝试sharedMgr
            else if ([pluginsMgrClass respondsToSelector:sharedMgrSel]) {
                sharedMgr = ((id (*)(Class, SEL))[pluginsMgrClass methodForSelector:sharedMgrSel])(pluginsMgrClass, sharedMgrSel);
            }
            // 尝试defaultMgr
            else if ([pluginsMgrClass respondsToSelector:defaultMgrSel]) {
                sharedMgr = ((id (*)(Class, SEL))[pluginsMgrClass methodForSelector:defaultMgrSel])(pluginsMgrClass, defaultMgrSel);
            }
            
            // 尝试注册插件
            if (sharedMgr) {
                SEL registerSel = NSSelectorFromString(@"registerSwitchWithTitle:key:");
                if ([sharedMgr respondsToSelector:registerSel]) {
                    ((void (*)(id, SEL, NSString *, NSString *))[sharedMgr methodForSelector:registerSel])(sharedMgr, registerSel, @"DD朋友圈转发", DDTimeLineForwardEnableKey);
                }
            }
        }
        
        // 初始化默认设置（默认开启）
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults objectForKey:DDTimeLineForwardEnableKey]) {
            [defaults setBool:YES forKey:DDTimeLineForwardEnableKey];
            [defaults synchronize];
        }
    }
}