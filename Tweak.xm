// DDTimeLineForward.xm
// DD朋友圈转发插件 v1.0.0

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#define DDTimeLineForwardEnableKey @"DDTimeLineForwardEnable"

// 原始代码中定义的类和方法
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

// 使用原始代码中的关联对象方式添加属性
%hook WCOperateFloatView

%new
- (UIButton *)m_shareBtn {
    static char m_shareBtnKey;
    UIButton *btn = objc_getAssociatedObject(self, &m_shareBtnKey);
    
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        // 使用与点赞按钮相同的样式
        [btn setTitleColor:self.m_likeBtn.currentTitleColor forState:UIControlStateNormal];
        btn.titleLabel.font = self.m_likeBtn.titleLabel.font;
        
        [self.m_likeBtn.superview addSubview:btn];
        
        // 使用原始代码中的base64图标
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0H2A+cpEGbBkqSmfXlQXOBZjbgYgCDwIIDXZQ0aCrQzOaABWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4C12Q9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:UIControlStateNormal];
        [btn setTintColor:self.m_likeBtn.tintColor];
        
        objc_setAssociatedObject(self, &m_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

%new
- (UIImageView *)m_lineView2 {
    static char m_lineView2Key;
    UIImageView *imageView = objc_getAssociatedObject(self, &m_lineView2Key);
    
    if (!imageView) {
        // 创建分割线
        imageView = [[UIImageView alloc] initWithImage:MSHookIvar<UIImageView *>(self, "m_lineView").image];
        [self.m_likeBtn.superview addSubview:imageView];
        objc_setAssociatedObject(self, &m_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return imageView;
}

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig(arg1, arg2);
    
    if ([DDTimeLineForwardManager isEnabled]) {
        // 调整整个视图的frame，与原始代码一致
        self.frame = CGRectOffset(CGRectInset(self.frame, self.frame.size.width / -4, 0), 
                                 self.frame.size.width / -4, 0);
        
        // 设置转发按钮位置
        self.m_shareBtn.frame = CGRectOffset(self.m_likeBtn.frame, 
                                            self.m_likeBtn.frame.size.width * 2, 
                                            0);
        
        // 设置第二条分割线位置
        self.m_lineView2.frame = CGRectOffset(MSHookIvar<UIImageView *>(self, "m_lineView").frame, 
                                             [self buttonWidth:self.m_likeBtn], 
                                             0);
    }
}

%new
- (void)forwordTimeLine:(id)arg1 {
    if (![DDTimeLineForwardManager isEnabled]) return;
    
    // 使用原始代码中的转发逻辑
    WCForwardViewController *forwardVC = [[objc_getClass("WCForwardViewController") alloc] initWithDataItem:self.m_item];
    [self.navigationController pushViewController:forwardVC animated:YES];
}

%end

%ctor {
    @autoreleasepool {
        // 根据原始代码，插件管理器注册方式
        // 检查类是否存在
        if (NSClassFromString(@"WCPluginsMgr")) {
            // 尝试调用注册方法
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerSwitchWithTitle:@"DD朋友圈转发" key:DDTimeLineForwardEnableKey];
        }
        
        // 初始化默认设置（默认开启）
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults objectForKey:DDTimeLineForwardEnableKey]) {
            [defaults setBool:YES forKey:DDTimeLineForwardEnableKey];
            [defaults synchronize];
        }
    }
}