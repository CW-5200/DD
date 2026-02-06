// DDTimeLineForward.xm
// DD朋友圈转发插件 v1.0.0
// Created by DeepSeek AI Assistant

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// 定义插件配置key
#define DDTimeLineForwardEnableKey @"DDTimeLineForwardEnable"

// 声明微信类（来自原始代码）
@interface WCOperateFloatView : UIView {
    UIImageView *m_lineView;
}
@property(readonly, nonatomic) UIButton *m_likeBtn;
@property(readonly, nonatomic) UIButton *m_commentBtn;
@property(readonly, nonatomic) id m_item;
@property(nonatomic, weak) UINavigationController *navigationController;
- (double)buttonWidth:(UIButton *)button;
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
        
        // 使用与原始代码相同的方式设置颜色和字体
        [btn setTitleColor:[self.m_likeBtn titleColorForState:UIControlStateNormal] forState:UIControlStateNormal];
        btn.titleLabel.font = self.m_likeBtn.titleLabel.font;
        
        [self.m_likeBtn.superview addSubview:btn];
        
        // 转发图标 (base64 encoded PNG) - 与原始代码相同
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0H2A+cpEGbBkqSmfXlQXOBZjbgYgCDwIIDXZQ0aCrQzOaABWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:UIControlStateNormal];
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
        // 获取原始的分割线视图
        Ivar lineViewIvar = class_getInstanceVariable([self class], "m_lineView");
        UIImageView *originalLineView = object_getIvar(self, lineViewIvar);
        
        if (originalLineView && [originalLineView isKindOfClass:[UIImageView class]]) {
            imageView = [[UIImageView alloc] initWithImage:originalLineView.image];
        } else {
            // 如果获取失败，创建一个默认的分割线
            imageView = [[UIImageView alloc] init];
            imageView.backgroundColor = [UIColor colorWithWhite:0.8 alpha:1.0];
            imageView.frame = CGRectMake(0, 0, 0.5, 20);
        }
        
        [self.m_likeBtn.superview addSubview:imageView];
        objc_setAssociatedObject(self, &dd_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return imageView;
}

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig(arg1, arg2);
    
    if ([DDTimeLineForwardManager isEnabled]) {
        // 获取按钮宽度，与原始代码逻辑一致
        CGFloat buttonWidth = [self buttonWidth:self.m_likeBtn];
        
        // 调整布局，为转发按钮腾出空间
        CGRect originalFrame = self.frame;
        CGRect newFrame = CGRectMake(originalFrame.origin.x - buttonWidth, 
                                    originalFrame.origin.y, 
                                    originalFrame.size.width + buttonWidth, 
                                    originalFrame.size.height);
        self.frame = newFrame;
        
        // 设置转发按钮位置（在点赞和评论按钮之后）
        CGFloat shareBtnX = self.m_commentBtn.frame.origin.x + self.m_commentBtn.frame.size.width;
        self.dd_shareBtn.frame = CGRectMake(shareBtnX, 
                                           self.m_likeBtn.frame.origin.y, 
                                           buttonWidth, 
                                           self.m_likeBtn.frame.size.height);
        
        // 设置第二条分割线位置（在评论和转发按钮之间）
        self.dd_lineView2.frame = CGRectMake(self.m_commentBtn.frame.origin.x + self.m_commentBtn.frame.size.width,
                                            self.m_commentBtn.frame.origin.y + 8,
                                            0.5,
                                            self.m_commentBtn.frame.size.height - 16);
        self.dd_lineView2.hidden = NO;
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
    if (forwardVCClass) {
        // 尝试两种初始化方法（兼容不同版本的微信）
        id forwardVC = nil;
        if ([forwardVCClass instancesRespondToSelector:@selector(initWithDataItem:)]) {
            forwardVC = [[forwardVCClass alloc] initWithDataItem:self.m_item];
        } else if ([forwardVCClass instancesRespondToSelector:@selector(initWithDataItem:sessionID:)]) {
            forwardVC = [[forwardVCClass alloc] initWithDataItem:self.m_item sessionID:nil];
        }
        
        if (forwardVC && self.navigationController) {
            [self.navigationController pushViewController:forwardVC animated:YES];
        }
    }
}

%end

// 插件注册和初始化
%ctor {
    @autoreleasepool {
        // 注册插件到微信插件管理器
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerSwitchWithTitle:@"DD朋友圈转发" key:DDTimeLineForwardEnableKey];
            NSLog(@"[DD朋友圈转发] 插件已注册到插件管理器");
        }
        
        // 初始化默认设置（默认开启）
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults objectForKey:DDTimeLineForwardEnableKey]) {
            [defaults setBool:YES forKey:DDTimeLineForwardEnableKey];
            [defaults synchronize];
        }
        
        NSLog(@"[DD朋友圈转发] 插件已加载 v1.0.0，当前状态：%@", 
              [DDTimeLineForwardManager isEnabled] ? @"已启用" : @"已禁用");
    }
}