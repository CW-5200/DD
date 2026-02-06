#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

@interface CContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@property(retain, nonatomic) NSString *m_nsNickName;
@end

@interface WCDataItem : NSObject
@property(retain, nonatomic) NSString *contentDesc;
@end

@interface WCForwardViewController : UIViewController
- (id)initWithDataItem:(id)arg1;
@end

@interface WCOperateFloatView : UIView
@property(readonly, nonatomic) UIButton *m_likeBtn;
@property(readonly, nonatomic) WCDataItem *m_item;
@property(nonatomic) __weak UINavigationController *navigationController;
- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2;
- (double)buttonWidth:(id)arg1;
@end

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

@interface DDForwardConfig : NSObject
+ (BOOL)isEnabled;
+ (void)setEnabled:(BOOL)enabled;
@end

@implementation DDForwardConfig
+ (NSString *)configKey {
    return @"DDForwardTimeLineEnable";
}

+ (BOOL)isEnabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:[self configKey]];
}

+ (void)setEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:[self configKey]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
@end

%hook WCOperateFloatView

// 转发按钮点击事件
- (void)DD_forwordTimeLine:(id)arg1 {
    if (!DDForwardConfig.isEnabled) return;
    
    WCForwardViewController *forwardVC = [[objc_getClass("WCForwardViewController") alloc] initWithDataItem:self.m_item];
    [self.navigationController pushViewController:forwardVC animated:YES];
}

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig;
    
    if (!DDForwardConfig.isEnabled) return;
    
    // 获取关联对象键
    static char m_shareBtnKey;
    static char m_lineView2Key;
    
    // 设置转发按钮
    UIButton *shareBtn = objc_getAssociatedObject(self, &m_shareBtnKey);
    if (!shareBtn) {
        shareBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [shareBtn setTitle:@" 转发" forState:UIControlStateNormal];
        [shareBtn addTarget:self action:@selector(DD_forwordTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        [shareBtn setTitleColor:self.m_likeBtn.currentTitleColor forState:0];
        shareBtn.titleLabel.font = self.m_likeBtn.titleLabel.font;
        
        // 设置图标
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Oncek5z+c5z/n+n0f8c+ivPDMrAAVJG1l7mgWVga0saCvAKnCWBm0F2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzOaABWAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [shareBtn setImage:image forState:0];
        [shareBtn setTintColor:self.m_likeBtn.tintColor];
        
        objc_setAssociatedObject(self, &m_shareBtnKey, shareBtn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self.m_likeBtn.superview addSubview:shareBtn];
    }
    
    // 设置第二条分隔线
    UIImageView *lineView2 = objc_getAssociatedObject(self, &m_lineView2Key);
    if (!lineView2) {
        // 获取原始的分隔线视图
        UIImageView *originalLineView = nil;
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList([self class], &count);
        for (unsigned int i = 0; i < count; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            if (strstr(name, "m_lineView")) {
                originalLineView = object_getIvar(self, ivar);
                break;
            }
        }
        free(ivars);
        
        if (originalLineView && originalLineView.image) {
            lineView2 = [[UIImageView alloc] initWithImage:originalLineView.image];
            objc_setAssociatedObject(self, &m_lineView2Key, lineView2, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            [self.m_likeBtn.superview addSubview:lineView2];
        }
    }
    
    // 调整布局，为转发按钮腾出空间
    self.frame = CGRectOffset(CGRectInset(self.frame, self.frame.size.width / -4, 0), self.frame.size.width / -4, 0);
    
    // 更新按钮和分隔线位置
    if (shareBtn) {
        shareBtn.frame = CGRectOffset(self.m_likeBtn.frame, self.m_likeBtn.frame.size.width * 2, 0);
    }
    
    if (lineView2) {
        lineView2.frame = CGRectOffset(self.m_likeBtn.frame, [self buttonWidth:self.m_likeBtn], 0);
    }
}

%end

%ctor {
    if (NSClassFromString(@"WCPluginsMgr")) {
        [[objc_getClass("WCPluginsMgr") sharedInstance] registerSwitchWithTitle:@"DD朋友圈转发" key:@"DDForwardTimeLineEnable"];
    }
}