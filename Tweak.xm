// Tweak.xm
// DD朋友圈转发 v1.0.0
// 严格按照原始文件实现

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// 原始文件中的类定义
@interface WCDataItem : NSObject
@end

@interface WCForwardViewController : UIViewController
- (id)initWithDataItem:(id)arg1;
@end

@interface WCOperateFloatView : UIView {
    UIImageView *m_lineView;
}
@property(readonly, nonatomic) UIButton *m_commentBtn;
@property(readonly, nonatomic) UIButton *m_likeBtn;
@property(nonatomic) __weak UINavigationController *navigationController;
@property(readonly, nonatomic) WCDataItem *m_item;
- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2;
- (double)buttonWidth:(id)arg1;
@end

// Hook实现 - 完全按照原始文件
%hook WCOperateFloatView

%new
- (UIButton *)m_shareBtn {
    static char m_shareBtnKey;
    UIButton *btn = objc_getAssociatedObject(self, &m_shareBtnKey);
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        [btn setTitleColor:self.m_likeBtn.currentTitleColor forState:0];
        btn.titleLabel.font = self.m_likeBtn.titleLabel.font;
        [self.m_likeBtn.superview addSubview:btn];
        
        // 原始文件中的base64图标数据
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaAZWAIuAEugaqk00jlJOgvYChaA6aAFeBY0lvaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        
        // 注意：原始文件中使用setImage:forState:0，而不是setImage:forState:UIControlStateNormal
        if (image) {
            [btn setImage:image forState:0]; // 注意这里用的是0，不是UIControlStateNormal
            [btn setTintColor:self.m_likeBtn.tintColor];
        }
        
        objc_setAssociatedObject(self, &m_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

%new
- (UIImageView *)m_lineView2 {
    static char m_lineView2Key;
    UIImageView *imageView = objc_getAssociatedObject(self, &m_lineView2Key);
    if (!imageView) {
        // 原始文件中使用MSHookIvar获取m_lineView
        UIImageView *originalLineView = MSHookIvar<UIImageView *>(self, "m_lineView");
        if (originalLineView && originalLineView.image) {
            imageView = [[UIImageView alloc] initWithImage:originalLineView.image];
            [self.m_likeBtn.superview addSubview:imageView];
            objc_setAssociatedObject(self, &m_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    return imageView;
}

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig(arg1, arg2);
    
    // 注意：原始文件中有判断if (DKHelperConfig.timeLineForwardEnable)
    // 我们这里是独立插件，默认启用转发功能
    
    // 调整frame：扩展宽度并左移
    // 原始代码：self.frame = CGRectOffset(CGRectInset(self.frame, self.frame.size.width / -4, 0), self.frame.size.width / -4,0);
    CGRect newFrame = self.frame;
    newFrame = CGRectInset(newFrame, newFrame.size.width / -4, 0);
    newFrame = CGRectOffset(newFrame, newFrame.size.width / -4, 0);
    self.frame = newFrame;
    
    // 设置转发按钮位置
    // 原始代码：self.m_shareBtn.frame = CGRectOffset(self.m_likeBtn.frame, self.m_likeBtn.frame.size.width * 2, 0);
    self.m_shareBtn.frame = CGRectOffset(self.m_likeBtn.frame, self.m_likeBtn.frame.size.width * 2, 0);
    
    // 设置分割线位置
    // 原始代码：self.m_lineView2.frame = CGRectOffset(MSHookIvar<UIImageView *>(self, "m_lineView").frame, [self buttonWidth:self.m_likeBtn], 0);
    UIImageView *originalLineView = MSHookIvar<UIImageView *>(self, "m_lineView");
    if (originalLineView && self.m_lineView2) {
        self.m_lineView2.frame = CGRectOffset(originalLineView.frame, [self buttonWidth:self.m_likeBtn], 0);
    }
}

%new
- (void)forwordTimeLine:(id)arg1 {
    // 原始代码中的方法名是forwordTimeLine:，注意拼写是"forword"不是"forward"
    Class WCForwardViewControllerClass = objc_getClass("WCForwardViewController");
    if (WCForwardViewControllerClass && self.m_item) {
        WCForwardViewController *forwardVC = [[WCForwardViewControllerClass alloc] initWithDataItem:self.m_item];
        if (forwardVC && self.navigationController) {
            [self.navigationController pushViewController:forwardVC animated:true];
        }
    }
}

%end