// CSRoundAvatar.xm
// iOS 微信圆形头像插件 - 默认生效，无需开关
// 适用于 MMHeadImageView 和 FakeHeadImageView 类

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <substrate.h>

// 声明MMHeadImageView类的接口
@interface MMHeadImageView : UIView
@property(readonly, nonatomic) BOOL bRoundedCorner;
@property(nonatomic) unsigned int conerSize;
@property(retain, nonatomic) UIView *headImageView;
- (void)setHeadImageViewCornerRadius:(double)arg1;
@end

// 声明FakeHeadImageView类接口
@interface FakeHeadImageView : UIView
@property(nonatomic) unsigned int conerSize;
@property(nonatomic) struct CGSize imageSize;
@property(nonatomic) unsigned char headCategory;
@property(nonatomic) unsigned char headUseScene;
@property(readonly, nonatomic) BOOL m_bRoundedCorner;
- (id)initWithRoundCorner:(BOOL)arg1;
@end

// Hook MMHeadImageView的初始化方法，强制设置为圆形
%hook MMHeadImageView

// Hook 初始化方法，强制设置为圆形
- (id)initWithUsrName:(id)arg1 headImgUrl:(id)arg2 bAutoUpdate:(BOOL)arg3 bRoundCorner:(BOOL)arg4 {
    // 强制启用圆形头像，忽略原始参数
    return %orig(arg1, arg2, arg3, YES);
}

// Hook layoutSubviews方法，确保圆角设置在布局后也有效
- (void)layoutSubviews {
    %orig;
    
    // 获取视图尺寸
    CGFloat width = self.frame.size.width;
    CGFloat height = self.frame.size.height;
    
    if (width > 0 && height > 0) {
        // 计算圆角半径 - 使用宽度的一半创建完全圆形
        CGFloat radius = MIN(width, height) / 2.0;
        
        // 应用圆角设置
        self.layer.cornerRadius = radius;
        self.layer.masksToBounds = YES;
        
        // 为内部头像视图也设置圆角
        if (self.headImageView) {
            CGFloat imageWidth = self.headImageView.frame.size.width;
            CGFloat imageHeight = self.headImageView.frame.size.height;
            
            if (imageWidth > 0 && imageHeight > 0) {
                CGFloat imageRadius = MIN(imageWidth, imageHeight) / 2.0;
                self.headImageView.layer.cornerRadius = imageRadius;
                self.headImageView.layer.masksToBounds = YES;
            }
        }
    }
}

// Hook conerSize属性的setter方法，确保圆角设置
- (void)setConerSize:(unsigned int)size {
    // 强制使用最大值，确保圆形
    %orig((unsigned int)(size * 1.0f));
}

%end

// Hook FakeHeadImageView 的初始化方法
%hook FakeHeadImageView

// Hook 初始化方法，强制设置为圆形
- (id)initWithRoundCorner:(BOOL)arg1 {
    // 强制启用圆形头像
    return %orig(YES);
}

// Hook layoutSubviews 方法来应用圆形设置
- (void)layoutSubviews {
    %orig;
    
    // 获取视图尺寸
    CGFloat width = self.frame.size.width;
    CGFloat height = self.frame.size.height;
    
    if (width > 0 && height > 0) {
        // 计算圆角半径 - 使用宽度的一半创建完全圆形
        CGFloat radius = MIN(width, height) / 2.0;
        
        // 应用圆角设置
        self.layer.cornerRadius = radius;
        self.layer.masksToBounds = YES;
        
        // 为内部头像视图也设置圆角 (m_headImageView)
        UIImageView *headImageView = MSHookIvar<UIImageView *>(self, "m_headImageView");
        if (headImageView) {
            CGFloat imageWidth = headImageView.frame.size.width;
            CGFloat imageHeight = headImageView.frame.size.height;
            
            if (imageWidth > 0 && imageHeight > 0) {
                CGFloat imageRadius = MIN(imageWidth, imageHeight) / 2.0;
                headImageView.layer.cornerRadius = imageRadius;
                headImageView.layer.masksToBounds = YES;
            }
        }
        
        // 边框视图也设置圆角 (m_borderImageView)
        UIImageView *borderImageView = MSHookIvar<UIImageView *>(self, "m_borderImageView");
        if (borderImageView) {
            CGFloat borderWidth = borderImageView.frame.size.width;
            CGFloat borderHeight = borderImageView.frame.size.height;
            
            if (borderWidth > 0 && borderHeight > 0) {
                CGFloat borderRadius = MIN(borderWidth, borderHeight) / 2.0;
                borderImageView.layer.cornerRadius = borderRadius;
                borderImageView.layer.masksToBounds = YES;
            }
        }
    }
}

// Hook conerSize属性的setter方法
- (void)setConerSize:(unsigned int)size {
    // 强制使用最大值，确保圆形
    %orig((unsigned int)(size * 1.0f));
}

%end

// 插件加载时打印日志
%ctor {
    NSLog(@"[CSRoundAvatar] 圆形头像插件已加载，所有头像将被设置为圆形");
}