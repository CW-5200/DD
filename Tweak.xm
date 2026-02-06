// DDTimeLineForward.xm
// DD朋友圈转发插件 v1.0.0
// Created by DeepSeek AI Assistant

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 定义插件配置key
#define DDTimeLineForwardEnableKey @"DDTimeLineForwardEnable"

@interface WCOperateFloatView : UIView {
    UIImageView *m_lineView;
}
@property(readonly, nonatomic) UIButton *m_likeBtn;
@property(readonly, nonatomic) WCDataItem *m_item;
@property(nonatomic, weak) UINavigationController *navigationController;
@end

@interface WCDataItem : NSObject
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

// Hook WCOperateFloatView 添加转发按钮
%hook WCOperateFloatView

%new
- (UIButton *)dd_shareBtn {
    static char dd_shareBtnKey;
    UIButton *btn = objc_getAssociatedObject(self, &dd_shareBtnKey);
    
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(dd_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        [btn setTitleColor:self.m_likeBtn.currentTitleColor forState:0];
        btn.titleLabel.font = self.m_likeBtn.titleLabel.font;
        [self.m_likeBtn.superview addSubview:btn];
        
        // 转发图标 (base64 encoded PNG)
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0F2A+cpEGbBkqSmfXlQXOBZjbgYgCDwIIDXZQ0aCrQzOaABWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:0];
        [btn setTintColor:self.m_likeBtn.tintColor];
        
        objc_setAssociatedObject(self, &dd_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

%new
- (UIImageView *)dd_lineView2 {
    static char dd_lineView2Key;
    UIImageView *imageView = objc_getAssociatedObject(self, &dd_lineView2Key);
    
    if (!imageView) {
        imageView = [[UIImageView alloc] initWithImage:m_lineView.image];
        [self.m_likeBtn.superview addSubview:imageView];
        objc_setAssociatedObject(self, &dd_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return imageView;
}

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig(arg1, arg2);
    
    if ([DDTimeLineForwardManager isEnabled]) {
        // 调整布局，为转发按钮腾出空间
        self.frame = CGRectOffset(CGRectInset(self.frame, self.frame.size.width / -4, 0), self.frame.size.width / -4, 0);
        
        // 设置转发按钮位置
        self.dd_shareBtn.frame = CGRectOffset(self.m_likeBtn.frame, self.m_likeBtn.frame.size.width * 2, 0);
        
        // 设置第二条分割线位置
        self.dd_lineView2.frame = CGRectOffset(m_lineView.frame, [self buttonWidth:self.m_likeBtn], 0);
    }
}

%new
- (void)dd_forwordTimeLine:(id)arg1 {
    WCForwardViewController *forwardVC = [[objc_getClass("WCForwardViewController") alloc] initWithDataItem:self.m_item];
    [self.navigationController pushViewController:forwardVC animated:YES];
}

%end

// Hook MMTipsViewController 获取文本输入
%hook MMTipsViewController
%new
- (NSString *)text {
    return [self valueForKeyPath:@"_tipsTextView.text"];
}
%end

// Hook WCTimelineMgr 处理朋友圈数据
%hook WCTimelineMgr
- (void)modifyDataItem:(WCDataItem *)arg1 notify:(BOOL)arg2 {
    // 这里保留了原插件中的点赞评论功能，但可以根据需要移除
    // 朋友圈转发插件主要关注转发功能
    %orig(arg1, arg2);
}
%end

// 插件注册
%ctor {
    @autoreleasepool {
        // 注册插件到微信插件管理器
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerSwitchWithTitle:@"DD朋友圈转发" key:DDTimeLineForwardEnableKey];
        }
        
        // 初始化默认设置
        if (![[NSUserDefaults standardUserDefaults] objectForKey:DDTimeLineForwardEnableKey]) {
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:DDTimeLineForwardEnableKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
        
        NSLog(@"[DD朋友圈转发] 插件已加载 v1.0.0");
    }
}