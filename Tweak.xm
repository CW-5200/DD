// WeChatForwardPlugin.xm
// 朋友圈转发插件 - 无需开关，默认生效

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 微信类声明
@interface WCDataItem : NSObject
@end

@interface WCForwardViewController : UIViewController
- (id)initWithDataItem:(id)arg1;
@end

@interface WCOperateFloatView : UIView {
    UIImageView *m_lineView;
}
@property(readonly, nonatomic) UIButton *m_likeBtn;
@property(readonly, nonatomic) UIButton *m_commentBtn;
@property(readonly, nonatomic) id m_item;
@property(nonatomic) __weak UINavigationController *navigationController;
- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2;
- (double)buttonWidth:(id)arg1;
@end

// Hook WCOperateFloatView 添加转发按钮
%hook WCOperateFloatView

%new
-(UIButton *)m_shareBtn {
    static char m_shareBtnKey;
    UIButton *btn = objc_getAssociatedObject(self, &m_shareBtnKey);
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        [btn setTitleColor:self.m_likeBtn.currentTitleColor forState:0];
        btn.titleLabel.font = self.m_likeBtn.titleLabel.font;
        [self.m_likeBtn.superview addSubview:btn];
        
        // 转发图标（base64编码）
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaAZWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzN0K3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:0];
        [btn setTintColor:self.m_likeBtn.tintColor];
        objc_setAssociatedObject(self, &m_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

%new
-(UIImageView *)m_lineView2 {
    static char m_lineView2Key;
    UIImageView *imageView = objc_getAssociatedObject(self, &m_lineView2Key);
    if (!imageView) {
        // 使用私有变量获取分割线图片
        UIImageView *originalLineView = MSHookIvar<UIImageView *>(self, "m_lineView");
        imageView = [[UIImageView alloc] initWithImage:originalLineView.image];
        [self.m_likeBtn.superview addSubview:imageView];
        objc_setAssociatedObject(self, &m_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return imageView;
}

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig(arg1, arg2);
    
    // 调整布局，为转发按钮腾出空间
    self.frame = CGRectOffset(CGRectInset(self.frame, self.frame.size.width / -4, 0), 
                             self.frame.size.width / -4, 0);
    
    // 设置转发按钮位置（在点赞按钮右侧两个按钮宽度处）
    self.m_shareBtn.frame = CGRectOffset(self.m_likeBtn.frame, 
                                        self.m_likeBtn.frame.size.width * 2, 0);
    
    // 设置第二条分割线位置
    self.m_lineView2.frame = CGRectOffset(MSHookIvar<UIImageView *>(self, "m_lineView").frame, 
                                         [self buttonWidth:self.m_likeBtn], 0);
}

%new
- (void)forwordTimeLine:(id)arg1 {
    // 获取当前朋友圈数据项并跳转到转发页面
    WCForwardViewController *forwardVC = [[objc_getClass("WCForwardViewController") alloc] initWithDataItem:self.m_item];
    [self.navigationController pushViewController:forwardVC animated:YES];
}

%end

// 构造函数 - 确保插件加载时生效
%ctor {
    NSLog(@"[WeChatForwardPlugin] 朋友圈转发插件已加载，默认生效");
}