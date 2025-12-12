// DD集赞助手.xm
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

// 声明微信内部类
@interface WCDataItem : NSObject
@property (retain, nonatomic) NSMutableArray *likeUsers;
@property (nonatomic) int likeCount;
@property (retain, nonatomic) NSString *username;
@property (retain, nonatomic) NSMutableArray *commentUsers;
@property (nonatomic) int commentCount;
@end

@interface WCUserComment : NSObject
@property (retain, nonatomic) NSString *nickname;
@property (retain, nonatomic) NSString *username;
@property (retain, nonatomic) NSString *content;
@property (nonatomic) int type; // 1=点赞 2=评论
@property (nonatomic) unsigned int createTime;
@end

@interface CContact : NSObject
@property (retain, nonatomic) NSString *m_nsUsrName;
@property (retain, nonatomic) NSString *m_nsNickName;
@property (nonatomic) unsigned int m_uiType; // 联系人类型
@end

@interface CContactMgr : NSObject
- (id)getContactByName:(NSString *)name;
- (NSArray *)getAllContactUserName;
@end

@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)service;
@end

@interface SettingUtil : NSObject
+ (NSString *)getCurUsrName;
@end

// 插件管理接口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

// 设置页面控制器
@interface DDZanSettingViewController : UIViewController
@end

// 全局设置
static BOOL dd_pluginEnabled = YES;
static NSInteger dd_zanCount = 10;
static NSInteger dd_commentCount = 5;
static NSString *dd_customComments = @"高级\n点赞就完事了\n6666\n赞~\n这个不错\n牛皮\n厉害了\n不错哦\n真棒\n支持\n可以";

// 获取好友列表
NSArray* dd_getFriendList() {
    NSMutableArray *friends = [NSMutableArray array];
    
    @try {
        MMServiceCenter *center = [objc_getClass("MMServiceCenter") defaultCenter];
        CContactMgr *contactMgr = [center getService:objc_getClass("CContactMgr")];
        NSArray *allUsers = [[contactMgr getAllContactUserName] allObjects];
        
        for (NSString *userName in allUsers) {
            CContact *contact = [contactMgr getContactByName:userName];
            if (!contact) continue;
            
            // 只保留正常好友（排除公众号、群聊等）
            if (contact.m_uiType == 4) {
                [friends addObject:userName];
            }
        }
    } @catch (NSException *e) {
        // 静默处理异常
    }
    
    return [friends copy];
}

// 生成伪造点赞
NSMutableArray* dd_generateLikes() {
    NSMutableArray *newLikes = [NSMutableArray array];
    
    // 生成新的点赞
    NSArray *friends = dd_getFriendList();
    if (friends.count == 0 || dd_zanCount <= 0) {
        return newLikes;
    }
    
    NSUInteger count = MIN(dd_zanCount, friends.count);
    
    for (int i = 0; i < count; i++) {
        NSUInteger randomIndex = arc4random() % friends.count;
        NSString *userName = friends[randomIndex];
        
        @try {
            MMServiceCenter *center = [objc_getClass("MMServiceCenter") defaultCenter];
            CContactMgr *contactMgr = [center getService:objc_getClass("CContactMgr")];
            CContact *contact = [contactMgr getContactByName:userName];
            
            if (contact) {
                WCUserComment *like = [[objc_getClass("WCUserComment") alloc] init];
                like.username = userName;
                like.nickname = contact.m_nsNickName ?: userName;
                like.type = 1;
                like.createTime = (unsigned int)[[NSDate date] timeIntervalSince1970];
                
                [newLikes addObject:like];
            }
        } @catch (NSException *e) {
            // 静默处理异常
        }
    }
    
    return newLikes;
}

// 生成伪造评论
NSMutableArray* dd_generateComments() {
    NSMutableArray *newComments = [NSMutableArray array];
    
    // 生成新的评论
    NSArray *friends = dd_getFriendList();
    if (friends.count == 0 || dd_commentCount <= 0) {
        return newComments;
    }
    
    // 评论内容
    NSArray *commentTexts = [dd_customComments componentsSeparatedByString:@"\n"];
    if (commentTexts.count == 0) {
        commentTexts = @[@"高级", @"点赞就完事了", @"6666", @"赞~", @"这个不错", @"牛皮"];
    }
    
    NSUInteger count = MIN(dd_commentCount, friends.count);
    
    for (int i = 0; i < count; i++) {
        NSUInteger friendIndex = arc4random() % friends.count;
        NSString *userName = friends[friendIndex];
        
        @try {
            MMServiceCenter *center = [objc_getClass("MMServiceCenter") defaultCenter];
            CContactMgr *contactMgr = [center getService:objc_getClass("CContactMgr")];
            CContact *contact = [contactMgr getContactByName:userName];
            
            if (contact) {
                WCUserComment *comment = [[objc_getClass("WCUserComment") alloc] init];
                comment.username = userName;
                comment.nickname = contact.m_nsNickName ?: userName;
                comment.type = 2;
                comment.createTime = (unsigned int)[[NSDate date] timeIntervalSince1970];
                
                // 随机评论内容
                NSUInteger textIndex = arc4random() % commentTexts.count;
                comment.content = commentTexts[textIndex];
                
                [newComments addObject:comment];
            }
        } @catch (NSException *e) {
            // 静默处理异常
        }
    }
    
    return newComments;
}

#pragma mark - 设置页面
@implementation DDZanSettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD集赞助手";
    self.view.backgroundColor = [UIColor whiteColor];
    
    [self setupUI];
}

- (void)setupUI {
    // 创建滚动视图
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, 500);
    [self.view addSubview:scrollView];
    
    CGFloat y = 20;
    CGFloat width = self.view.bounds.size.width - 40;
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, width, 30)];
    titleLabel.text = @"DD集赞助手 v1.0";
    titleLabel.font = [UIFont boldSystemFontOfSize:20];
    [scrollView addSubview:titleLabel];
    
    y += 40;
    
    // 开关
    UISwitch *enableSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(20, y, 0, 0)];
    enableSwitch.on = dd_pluginEnabled;
    [enableSwitch addTarget:self action:@selector(enableChanged:) forControlEvents:UIControlEventValueChanged];
    [scrollView addSubview:enableSwitch];
    
    UILabel *enableLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, y, width-50, 30)];
    enableLabel.text = @"启用插件";
    [scrollView addSubview:enableLabel];
    
    y += 50;
    
    // 点赞数量
    UILabel *zanLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 120, 30)];
    zanLabel.text = @"点赞数量:";
    [scrollView addSubview:zanLabel];
    
    UIStepper *zanStepper = [[UIStepper alloc] initWithFrame:CGRectMake(150, y, 0, 0)];
    zanStepper.minimumValue = 0;
    zanStepper.maximumValue = 50;
    zanStepper.value = dd_zanCount;
    zanStepper.stepValue = 1;
    zanStepper.tag = 100;
    [zanStepper addTarget:self action:@selector(stepperChanged:) forControlEvents:UIControlEventValueChanged];
    [scrollView addSubview:zanStepper];
    
    UILabel *zanValue = [[UILabel alloc] initWithFrame:CGRectMake(250, y, 60, 30)];
    zanValue.text = [NSString stringWithFormat:@"%ld", (long)dd_zanCount];
    zanValue.tag = 101;
    [scrollView addSubview:zanValue];
    
    y += 50;
    
    // 评论数量
    UILabel *commentLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, 120, 30)];
    commentLabel.text = @"评论数量:";
    [scrollView addSubview:commentLabel];
    
    UIStepper *commentStepper = [[UIStepper alloc] initWithFrame:CGRectMake(150, y, 0, 0)];
    commentStepper.minimumValue = 0;
    commentStepper.maximumValue = 20;
    commentStepper.value = dd_commentCount;
    commentStepper.stepValue = 1;
    commentStepper.tag = 200;
    [commentStepper addTarget:self action:@selector(stepperChanged:) forControlEvents:UIControlEventValueChanged];
    [scrollView addSubview:commentStepper];
    
    UILabel *commentValue = [[UILabel alloc] initWithFrame:CGRectMake(250, y, 60, 30)];
    commentValue.text = [NSString stringWithFormat:@"%ld", (long)dd_commentCount];
    commentValue.tag = 201;
    [scrollView addSubview:commentValue];
    
    y += 50;
    
    // 自定义评论
    UILabel *customLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, width, 30)];
    customLabel.text = @"自定义评论（每行一条）:";
    [scrollView addSubview:customLabel];
    
    y += 35;
    
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(20, y, width, 150)];
    textView.text = dd_customComments;
    textView.layer.borderColor = [UIColor grayColor].CGColor;
    textView.layer.borderWidth = 1;
    textView.font = [UIFont systemFontOfSize:14];
    textView.tag = 400;
    [scrollView addSubview:textView];
    
    // 完成按钮
    UIButton *doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
    doneButton.frame = CGRectMake(20, y + 160, width, 44);
    [doneButton setTitle:@"完成" forState:UIControlStateNormal];
    [doneButton addTarget:self action:@selector(doneTapped) forControlEvents:UIControlEventTouchUpInside];
    doneButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
    doneButton.tintColor = [UIColor whiteColor];
    doneButton.layer.cornerRadius = 8;
    [scrollView addSubview:doneButton];
}

- (void)enableChanged:(UISwitch *)sender {
    dd_pluginEnabled = sender.on;
}

- (void)stepperChanged:(UIStepper *)sender {
    if (sender.tag == 100) { // 点赞
        dd_zanCount = sender.value;
        UILabel *label = [self.view viewWithTag:101];
        label.text = [NSString stringWithFormat:@"%ld", (long)dd_zanCount];
    } else if (sender.tag == 200) { // 评论
        dd_commentCount = sender.value;
        UILabel *label = [self.view viewWithTag:201];
        label.text = [NSString stringWithFormat:@"%ld", (long)dd_commentCount];
    }
}

- (void)doneTapped {
    UITextView *textView = [self.view viewWithTag:400];
    dd_customComments = textView.text ?: @"";
    
    [self.view endEditing:YES];
    [self.navigationController popViewControllerAnimated:YES];
}

@end

#pragma mark - Hook微信方法
%hook WCCommentDetailViewControllerFB

- (void)setDataItem:(WCDataItem *)dataItem {
    if (dd_pluginEnabled) {
        @try {
            NSString *currentUser = [objc_getClass("SettingUtil") getCurUsrName];
            if ([[dataItem username] isEqualToString:currentUser]) {
                NSMutableArray *newLikes = dd_generateLikes();
                NSMutableArray *newComments = dd_generateComments();
                
                dataItem.likeUsers = newLikes;
                dataItem.likeCount = (int)newLikes.count;
                dataItem.commentUsers = newComments;
                dataItem.commentCount = (int)newComments.count;
            }
        } @catch (NSException *e) {
            // 静默处理异常
        }
    }
    
    %orig;
}

%end

%hook WCTimelineMgr

- (void)onDataUpdated:(id)arg1 andData:(NSMutableArray *)data andAdData:(id)arg3 withChangedTime:(unsigned int)arg4 {
    if (dd_pluginEnabled) {
        @try {
            NSString *currentUser = [objc_getClass("SettingUtil") getCurUsrName];
            
            for (WCDataItem *item in data) {
                if ([[item username] isEqualToString:currentUser]) {
                    NSMutableArray *newLikes = dd_generateLikes();
                    NSMutableArray *newComments = dd_generateComments();
                    
                    item.likeUsers = newLikes;
                    item.likeCount = (int)newLikes.count;
                    item.commentUsers = newComments;
                    item.commentCount = (int)newComments.count;
                }
            }
        } @catch (NSException *e) {
            // 静默处理异常
        }
    }
    
    %orig;
}

%end

#pragma mark - 插件初始化
%ctor {
    @autoreleasepool {
        // 注册到插件管理系统
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD集赞助手" 
                version:@"1.0" 
                controller:@"DDZanSettingViewController"];
        }
        
        // 加载保存的设置
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if ([defaults objectForKey:@"DDZanEnabled"]) {
            dd_pluginEnabled = [defaults boolForKey:@"DDZanEnabled"];
            dd_zanCount = [defaults integerForKey:@"DDZanCount"];
            dd_commentCount = [defaults integerForKey:@"DDCommentCount"];
            dd_customComments = [defaults stringForKey:@"DDCustomComments"] ?: @"高级\n点赞就完事了\n6666\n赞~\n这个不错\n牛皮\n厉害了\n不错哦\n真棒\n支持\n可以";
        }
    }
}

// 保存设置
static void dd_saveSettings() {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:dd_pluginEnabled forKey:@"DDZanEnabled"];
    [defaults setInteger:dd_zanCount forKey:@"DDZanCount"];
    [defaults setInteger:dd_commentCount forKey:@"DDCommentCount"];
    [defaults setObject:dd_customComments forKey:@"DDCustomComments"];
    [defaults synchronize];
}

%hook DDZanSettingViewController

- (void)viewWillDisappear:(BOOL)animated {
    dd_saveSettings();
    %orig;
}

%end