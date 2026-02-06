#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString * const DDTimeLineForwardEnableKey = @"DDTimeLineForwardEnable";

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface DDTimeLineForwardConfig : NSObject
@property (assign, nonatomic) BOOL enabled;
+ (instancetype)sharedConfig;
@end

@implementation DDTimeLineForwardConfig

+ (instancetype)sharedConfig {
    static DDTimeLineForwardConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [DDTimeLineForwardConfig new];
        config.enabled = [[NSUserDefaults standardUserDefaults] boolForKey:DDTimeLineForwardEnableKey];
        
        if ([[NSUserDefaults standardUserDefaults] objectForKey:DDTimeLineForwardEnableKey] == nil) {
            config.enabled = NO;
            [[NSUserDefaults standardUserDefaults] setBool:config.enabled forKey:DDTimeLineForwardEnableKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    });
    return config;
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:DDTimeLineForwardEnableKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

@interface DDTimeLineForwardSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@end

@implementation DDTimeLineForwardSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD朋友圈转发";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"DDTimeLineForwardSwitchCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        cell.textLabel.text = @"启用朋友圈转发";
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.onTintColor = [UIColor systemBlueColor];
        switchView.on = [DDTimeLineForwardConfig sharedConfig].enabled;
        [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 20.0;
}

- (void)switchChanged:(UISwitch *)sender {
    [DDTimeLineForwardConfig sharedConfig].enabled = sender.isOn;
}

@end

// 使用分类来添加方法，避免编译时类型检查
@interface UIView (DDTimeLineForwardPrivate)
- (void)dd_forwardTimeLine:(id)arg1;
- (UIButton *)dd_shareBtn;
- (UIImageView *)dd_lineView2;
@end

@implementation UIView (DDTimeLineForwardPrivate)

- (void)dd_forwardTimeLine:(id)arg1 {
    if (![DDTimeLineForwardConfig sharedConfig].enabled) return;
    
    Class forwardViewControllerClass = objc_getClass("WCForwardViewController");
    if (forwardViewControllerClass) {
        id m_item = [self valueForKey:@"m_item"];
        if (m_item) {
            id forwardVC = [[forwardViewControllerClass alloc] 
                            performSelector:@selector(initWithDataItem:) 
                            withObject:m_item];
            if (forwardVC) {
                id navigationController = [self valueForKey:@"navigationController"];
                if (navigationController) {
                    [navigationController performSelector:@selector(pushViewController:animated:) 
                                               withObject:forwardVC 
                                               withObject:@(YES)];
                }
            }
        }
        [self performSelector:@selector(hide)];
    }
}

- (UIButton *)dd_shareBtn {
    static char dd_shareBtnKey;
    UIButton *btn = objc_getAssociatedObject(self, &dd_shareBtnKey);
    
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(dd_forwardTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        id m_likeBtn = [self valueForKey:@"m_likeBtn"];
        if (m_likeBtn) {
            UIColor *titleColor = [m_likeBtn valueForKeyPath:@"titleColorForState.0"];
            if (titleColor) {
                [btn setTitleColor:titleColor forState:UIControlStateNormal];
            }
            
            id titleLabel = [m_likeBtn valueForKey:@"titleLabel"];
            if (titleLabel) {
                UIFont *font = [titleLabel valueForKey:@"font"];
                if (font) {
                    btn.titleLabel.font = font;
                }
            }
        }
        
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0H2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzM0A6WAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str 
                                                               options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:UIControlStateNormal];
        btn.tintColor = [btn titleColorForState:UIControlStateNormal];
        
        objc_setAssociatedObject(self, &dd_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

- (UIImageView *)dd_lineView2 {
    static char dd_lineView2Key;
    UIImageView *imageView = objc_getAssociatedObject(self, &dd_lineView2Key);
    
    if (!imageView) {
        unsigned int outCount = 0;
        Ivar *ivars = class_copyIvarList([self class], &outCount);
        
        for (unsigned int i = 0; i < outCount; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            if (name && strstr(name, "lineView")) {
                id originalLineView = object_getIvar(self, ivar);
                if (originalLineView) {
                    UIImage *image = [originalLineView valueForKey:@"image"];
                    if (image) {
                        imageView = [[UIImageView alloc] initWithImage:image];
                        objc_setAssociatedObject(self, &dd_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    }
                }
                break;
            }
        }
        free(ivars);
    }
    return imageView;
}

@end

// 使用 %hook 来替换方法
%hook WCOperateFloatView

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig;
    
    if (![DDTimeLineForwardConfig sharedConfig].enabled) return;
    
    CGRect frame = self.frame;
    frame = CGRectInset(frame, frame.size.width / -4, 0);
    frame = CGRectOffset(frame, frame.size.width / -4, 0);
    self.frame = frame;
    
    UIButton *shareBtn = [self dd_shareBtn];
    if (shareBtn) {
        [shareBtn removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
        [shareBtn addTarget:self action:@selector(dd_forwardTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        
        id m_likeBtn = [self valueForKey:@"m_likeBtn"];
        if (m_likeBtn) {
            CGRect likeBtnFrame = [m_likeBtn frame];
            shareBtn.frame = CGRectOffset(likeBtnFrame, likeBtnFrame.size.width * 2, 0);
            
            if (shareBtn.superview != self) {
                [self addSubview:shareBtn];
            }
        }
    }
    
    UIImageView *lineView2 = [self dd_lineView2];
    if (lineView2) {
        unsigned int outCount = 0;
        Ivar *ivars = class_copyIvarList([self class], &outCount);
        id originalLineView = nil;
        
        for (unsigned int i = 0; i < outCount; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            if (name && strstr(name, "lineView")) {
                originalLineView = object_getIvar(self, ivar);
                break;
            }
        }
        free(ivars);
        
        id m_likeBtn = [self valueForKey:@"m_likeBtn"];
        if (originalLineView && m_likeBtn) {
            CGRect originalLineFrame = [originalLineView frame];
            
            CGFloat buttonWidth = 0;
            if ([self respondsToSelector:@selector(buttonWidth:)]) {
                NSNumber *widthNum = [self performSelector:@selector(buttonWidth:) withObject:m_likeBtn];
                if (widthNum) {
                    buttonWidth = [widthNum floatValue];
                }
            } else {
                buttonWidth = [m_likeBtn frame].size.width;
            }
            
            lineView2.frame = CGRectOffset(originalLineFrame, buttonWidth, 0);
            
            if (lineView2.superview != self) {
                [self addSubview:lineView2];
            }
        }
    }
    
    [self layoutIfNeeded];
}

%end

%ctor {
    @autoreleasepool {
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD朋友圈转发" 
                version:@"1.0.0" 
                controller:@"DDTimeLineForwardSettingsViewController"];
        }
    }
}