#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

// 声明必要的外部类
@interface WCOperateFloatView : UIView
@property (nonatomic, readonly) UIButton *m_likeBtn;
@property (nonatomic, readonly) UIButton *m_commentBtn;
@property (nonatomic, readonly) id m_item;
@property (nonatomic, weak) UINavigationController *navigationController;
- (double)buttonWidth:(id)arg1;
@end

@interface WCForwardViewController : UIViewController
- (id)initWithDataItem:(id)arg1;
@end

// 使用与原始文件相同的配置类
@interface DKHelperConfig : NSObject
+ (BOOL)timeLineForwardEnable;
+ (void)setTimeLineForwardEnable:(BOOL)value;
@end

// 开关状态读取宏 - 使用原始文件的配置类
#define DDForwardEnabled [DKHelperConfig timeLineForwardEnable]

// 关联对象键
static char kShareBtnKey;
static char kLineView2Key;

#pragma mark - Hook WCOperateFloatView
%hook WCOperateFloatView

%new
- (UIButton *)m_shareBtn {
    UIButton *btn = objc_getAssociatedObject(self, &kShareBtnKey);
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        [btn setTitleColor:self.m_likeBtn.currentTitleColor forState:0];
        btn.titleLabel.font = self.m_likeBtn.titleLabel.font;
        
        // Base64 图片（转发图标）
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Unek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaABWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:0];
        [btn setTintColor:self.m_likeBtn.tintColor];
        
        [self.m_likeBtn.superview addSubview:btn];
        objc_setAssociatedObject(self, &kShareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

%new
- (UIImageView *)m_lineView2 {
    UIImageView *imageView = objc_getAssociatedObject(self, &kLineView2Key);
    if (!imageView) {
        // 使用 MSHookIvar 访问私有变量 m_lineView
        UIImageView *originalLineView = MSHookIvar<UIImageView *>(self, "m_lineView");
        imageView = [[UIImageView alloc] initWithImage:originalLineView.image];
        [self.m_likeBtn.superview addSubview:imageView];
        objc_setAssociatedObject(self, &kLineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return imageView;
}

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig(arg1, arg2);
    
    // 检查是否启用朋友圈转发功能
    if (DDForwardEnabled) {
        // 调整整个浮窗的frame，为转发按钮腾出空间
        CGRect frame = self.frame;
        frame = CGRectInset(frame, frame.size.width / -4, 0);
        frame = CGRectOffset(frame, frame.size.width / -4, 0);
        self.frame = frame;
        
        // 设置转发按钮位置
        CGRect likeBtnFrame = self.m_likeBtn.frame;
        self.m_shareBtn.frame = CGRectOffset(likeBtnFrame, likeBtnFrame.size.width * 2, 0);
        
        // 设置分割线位置
        UIImageView *originalLineView = MSHookIvar<UIImageView *>(self, "m_lineView");
        CGRect lineFrame = originalLineView.frame;
        double buttonWidth = [self buttonWidth:self.m_likeBtn];
        self.m_lineView2.frame = CGRectOffset(lineFrame, buttonWidth, 0);
    }
}

%new
- (void)forwordTimeLine:(id)arg1 {
    // 检查是否启用朋友圈转发功能
    if (!DDForwardEnabled) return;
    
    // 创建转发页面
    Class WCForwardViewControllerClass = objc_getClass("WCForwardViewController");
    if (WCForwardViewControllerClass && self.m_item) {
        WCForwardViewController *forwardVC = [[WCForwardViewControllerClass alloc] initWithDataItem:self.m_item];
        if (forwardVC && self.navigationController) {
            [self.navigationController pushViewController:forwardVC animated:YES];
        }
    }
}

%end

#pragma mark - 初始化注册
%ctor {
    @autoreleasepool {
        // 注册插件到 WCPluginsMgr
        Class WCPluginsMgr = objc_getClass("WCPluginsMgr");
        if (WCPluginsMgr) {
            // 检查是否已有配置类
            Class DKHelperConfigClass = objc_getClass("DKHelperConfig");
            if (DKHelperConfigClass) {
                // 使用现有的配置系统
                NSLog(@"[DDForwardTimeLine] 使用 DKHelperConfig 配置系统");
            } else {
                // 注册新的开关
                [[WCPluginsMgr sharedInstance] registerSwitchWithTitle:@"DD朋友圈转发" key:@"DDForwardTimeLineEnable"];
                NSLog(@"[DDForwardTimeLine] 已注册到 WCPluginsMgr");
            }
        } else {
            NSLog(@"[DDForwardTimeLine] WCPluginsMgr 不存在，无法注册插件");
        }
    }
}