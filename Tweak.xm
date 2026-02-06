#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString * const DDTimeLineForwardEnableKey = @"DDTimeLineForwardEnable";

@interface WCDataItem : NSObject
@property(retain, nonatomic) NSString *contentDesc;
@property(retain, nonatomic) id contentObj;
@end

@interface WCNewCommitViewController : UIViewController
@end

@interface WCForwardViewController : WCNewCommitViewController
- (id)initWithDataItem:(id)arg1;
@end

@interface WCOperateFloatView : UIView
@property(readonly, nonatomic) UIButton *m_likeBtn;
@property(readonly, nonatomic) UIButton *m_commentBtn;
@property(readonly, nonatomic) WCDataItem *m_item;
@property(nonatomic, weak) UINavigationController *navigationController;
- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2;
- (double)buttonWidth:(id)arg1;
- (void)hide;
@end

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

@interface WCOperateFloatView (DDTimeLineForwardMethods)
- (UIButton *)dd_shareBtn;
- (UIImageView *)dd_lineView2;
- (UIImageView *)dd_originalLineView;
@end

%hook WCOperateFloatView

- (UIButton *)dd_shareBtn {
    static char dd_shareBtnKey;
    UIButton *btn = objc_getAssociatedObject(self, &dd_shareBtnKey);
    if (!btn) {
        btn = [UIButton buttonWithType:UIButtonTypeCustom];
        [btn setTitle:@" 转发" forState:UIControlStateNormal];
        if (self.m_likeBtn) {
            [btn setTitleColor:[self.m_likeBtn titleColorForState:UIControlStateNormal] forState:UIControlStateNormal];
            btn.titleLabel.font = self.m_likeBtn.titleLabel.font;
        }
        NSString *base64Str = @"iVBORw0KGgoAAAANSUhEUgAAABQAAAAUCAYAAACNiR0NAAABf0lEQVQ4T62UvyuFYRTHP9/JJimjMpgYTBIDd5XEIIlB9x+Q5U5+xEIZLDabUoQsNtS9G5MyXImk3EHK/3B09Ly31/X+cG9Onek5z+c5z/l+n0f8c+ivPDMrAAVJG1l7mgWWgc0saCvAKnCWBm0H2A+cpEGbBkqSmfWlQXOBZjbgYgCDwIIDXZQ0aCrQzM0A6WAIuAEugaqk00jlJOgvYChaA6aAFeBY0nuaVRqhP4CxxQ9gVZJ3lhs/oAnt1ySN51JiBWa2FMYzW+/QzNwK3cCkpM+/As1sAjgAZiRVIsWKwHZ4Wo9NwFz5W2Ba0oXvi4Cu4L2kUrBEOzAMjIXsAjw7YrbpBZ6BeUlHURNu0h7gFXC/vQRlveM34AF4AipAG1AOxu4Me0qS9uM3cqB7bRS4A3y4556SvOt6hN8mAnrtoaTdxvE40H+QEcBP2pFUS5phBASu3eiS1pPqIuCWpKssMWLAPUl+k8T4fuiSfFaZEYBFSYtZhbmfQ95Bjetfmweww0YOfToAAAAASUVORK5CYII=";
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:base64Str options:NSDataBase64DecodingIgnoreUnknownCharacters];
        UIImage *image = [UIImage imageWithData:imageData];
        [btn setImage:image forState:UIControlStateNormal];
        btn.tintColor = [btn titleColorForState:UIControlStateNormal];
        objc_setAssociatedObject(self, &dd_shareBtnKey, btn, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return btn;
}

- (UIImageView *)dd_originalLineView {
    static char dd_originalLineViewKey;
    UIImageView *originalLineView = objc_getAssociatedObject(self, &dd_originalLineViewKey);
    if (!originalLineView) {
        unsigned int outCount = 0;
        Ivar *ivars = class_copyIvarList([self class], &outCount);
        for (unsigned int i = 0; i < outCount; i++) {
            Ivar ivar = ivars[i];
            const char *name = ivar_getName(ivar);
            if (name && strstr(name, "lineView")) {
                originalLineView = object_getIvar(self, ivar);
                break;
            }
        }
        free(ivars);
        if (originalLineView) {
            objc_setAssociatedObject(self, &dd_originalLineViewKey, originalLineView, OBJC_ASSOCIATION_ASSIGN);
        }
    }
    return originalLineView;
}

- (UIImageView *)dd_lineView2 {
    static char dd_lineView2Key;
    UIImageView *imageView = objc_getAssociatedObject(self, &dd_lineView2Key);
    if (!imageView) {
        UIImageView *originalLineView = [self dd_originalLineView];
        if (originalLineView && originalLineView.image) {
            imageView = [[UIImageView alloc] initWithImage:originalLineView.image];
            objc_setAssociatedObject(self, &dd_lineView2Key, imageView, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    return imageView;
}

%new
- (void)dd_forwardTimeLine:(id)arg1 {
    if (![DDTimeLineForwardConfig sharedConfig].enabled) return;
    Class forwardViewControllerClass = objc_getClass("WCForwardViewController");
    if (forwardViewControllerClass) {
        id forwardVC = [[forwardViewControllerClass alloc] initWithDataItem:self.m_item];
        if (forwardVC && self.navigationController) {
            [self.navigationController pushViewController:forwardVC animated:YES];
        }
        [self hide];
    }
}

- (void)showWithItemData:(id)arg1 tipPoint:(struct CGPoint)arg2 {
    %orig;
    if (![DDTimeLineForwardConfig sharedConfig].enabled) return;
    CGRect frame = self.frame;
    frame = CGRectInset(frame, frame.size.width / -4, 0);
    frame = CGRectOffset(frame, frame.size.width / -4, 0);
    self.frame = frame;
    UIButton *shareBtn = [self dd_shareBtn];
    if (self.m_likeBtn && shareBtn) {
        CGRect likeBtnFrame = self.m_likeBtn.frame;
        shareBtn.frame = CGRectOffset(likeBtnFrame, likeBtnFrame.size.width * 2, 0);
        [shareBtn addTarget:self action:@selector(dd_forwardTimeLine:) forControlEvents:UIControlEventTouchUpInside];
        if (shareBtn.superview != self) {
            [self addSubview:shareBtn];
        }
    }
    UIImageView *originalLineView = [self dd_originalLineView];
    UIImageView *lineView2 = [self dd_lineView2];
    if (originalLineView && self.m_likeBtn && lineView2) {
        CGRect originalLineFrame = originalLineView.frame;
        lineView2.frame = CGRectOffset(originalLineFrame, [self buttonWidth:self.m_likeBtn], 0);
        if (lineView2.superview != self) {
            [self addSubview:lineView2];
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