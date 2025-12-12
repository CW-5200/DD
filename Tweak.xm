// DD集赞助手.xm
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#define DDLog(fmt, ...) NSLog(@"[DD集赞助手] " fmt, ##__VA_ARGS__)

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
@property (nonatomic) int m_uiFriendScene; // 是否是好友
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
static NSString *dd_customComments = @"高级\n点赞就完事了\n6666\n赞~\n这个不错\n牛皮";

// 获取好友列表（只获取真实好友）
NSArray* dd_getFriendList() {
    static NSArray *cachedList = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
        NSMutableArray *friends = [NSMutableArray array];
        
        @try {
            MMServiceCenter *center = [objc_getClass("MMServiceCenter") defaultCenter];
            CContactMgr *contactMgr = [center getService:objc_getClass("CContactMgr")];
            NSArray *allUsers = [[contactMgr getAllContactUserName] allObjects];
            
            for (NSString *userName in allUsers) {
                CContact *contact = [contactMgr getContactByName:userName];
                if (!contact) continue;
                
                // 只保留正常好友（过滤公众号、群聊等）
                if (contact.m_uiType == 4 && contact.m_uiFriendScene != 0) {
                    [friends addObject:userName];
                }
            }
            
            cachedList = [friends copy];
            DDLog(@"获取到 %lu 个好友", (unsigned long)friends.count);
        } @catch (NSException *e) {
            DDLog(@"获取好友列表失败: %@", e);
        }
    });
    
    return cachedList;
}

// 生成伪造点赞（从好友列表随机选择）
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
                like.type = 1; // 点赞
                like.createTime = (unsigned int)[[NSDate date] timeIntervalSince1970];
                
                [newLikes addObject:like];
            }
        } @catch (NSException *e) {
            DDLog(@"生成点赞失败: %@", e);
        }
    }
    
    DDLog(@"生成 %lu 个点赞", (unsigned long)newLikes.count);
    return newLikes;
}

// 生成伪造评论（从好友列表随机选择，内容从自定义评论中随机选择）
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
                comment.type = 2; // 评论
                comment.createTime = (unsigned int)[[NSDate date] timeIntervalSince1970];
                
                // 随机评论内容
                NSUInteger textIndex = arc4random() % commentTexts.count;
                comment.content = commentTexts[textIndex];
                
                [newComments addObject:comment];
            }
        } @catch (NSException *e) {
            DDLog(@"生成评论失败: %@", e);
        }
    }
    
    DDLog(@"生成 %lu 条评论", (unsigned long)newComments.count);
    return newComments;
}

#pragma mark - 设置页面
@implementation DDZanSettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD集赞助手";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self setupUI];
}

- (void)setupUI {
    // 创建滚动视图
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, 600);
    [self.view addSubview:scrollView];
    
    CGFloat y = 20;
    CGFloat width = self.view.bounds.size.width - 40;
    
    // 标题
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, width, 40)];
    titleLabel.text = @"DD集赞助手 v1.0";
    titleLabel.font = [UIFont boldSystemFontOfSize:24];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    [scrollView addSubview:titleLabel];
    
    y += 60;
    
    // 启用插件开关
    UIView *enableView = [self createSettingItemWithTitle:@"启用插件" 
                                                 subtitle:@"开启/关闭集赞助手功能" 
                                                 switchOn:dd_pluginEnabled 
                                                  atY:y 
                                                  tag:100];
    [scrollView addSubview:enableView];
    y += 70;
    
    // 点赞数量设置
    UIView *zanView = [self createNumberItemWithTitle:@"点赞数量" 
                                             subtitle:@"设置需要生成的点赞数量" 
                                               value:dd_zanCount 
                                                atY:y 
                                                tag:200];
    [scrollView addSubview:zanView];
    y += 70;
    
    // 评论数量设置
    UIView *commentView = [self createNumberItemWithTitle:@"评论数量" 
                                                 subtitle:@"设置需要生成的评论数量" 
                                                   value:dd_commentCount 
                                                    atY:y 
                                                    tag:300];
    [scrollView addSubview:commentView];
    y += 70;
    
    // 自定义评论内容
    UILabel *commentLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, width, 30)];
    commentLabel.text = @"自定义评论内容";
    commentLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    [scrollView addSubview:commentLabel];
    
    y += 35;
    
    UILabel *commentSubLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, width, 20)];
    commentSubLabel.text = @"每行一条评论，随机选择";
    commentSubLabel.font = [UIFont systemFontOfSize:14];
    commentSubLabel.textColor = [UIColor grayColor];
    [scrollView addSubview:commentSubLabel];
    
    y += 30;
    
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(20, y, width, 150)];
    textView.text = dd_customComments;
    textView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    textView.layer.borderWidth = 1;
    textView.layer.cornerRadius = 8;
    textView.font = [UIFont systemFontOfSize:14];
    textView.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
    textView.tag = 400;
    [scrollView addSubview:textView];
    
    y += 170;
    
    // 提示文字
    UILabel *tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y, width, 60)];
    tipLabel.text = @"提示：所有点赞和评论都从您的好友列表中随机生成真实用户名";
    tipLabel.font = [UIFont systemFontOfSize:13];
    tipLabel.textColor = [UIColor grayColor];
    tipLabel.numberOfLines = 3;
    tipLabel.textAlignment = NSTextAlignmentCenter;
    [scrollView addSubview:tipLabel];
    
    y += 70;
    
    // 完成按钮
    UIButton *doneButton = [UIButton buttonWithType:UIButtonTypeSystem];
    doneButton.frame = CGRectMake(20, y, width, 50);
    [doneButton setTitle:@"保存设置" forState:UIControlStateNormal];
    [doneButton addTarget:self action:@selector(doneTapped) forControlEvents:UIControlEventTouchUpInside];
    doneButton.backgroundColor = [UIColor systemBlueColor];
    doneButton.tintColor = [UIColor whiteColor];
    doneButton.layer.cornerRadius = 10;
    doneButton.titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [scrollView addSubview:doneButton];
    
    // 设置滚动视图内容高度
    scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, y + 80);
}

- (UIView *)createSettingItemWithTitle:(NSString *)title subtitle:(NSString *)subtitle switchOn:(BOOL)isOn atY:(CGFloat)y tag:(NSInteger)tag {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(20, y, self.view.bounds.size.width - 40, 60)];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, view.bounds.size.width - 80, 25)];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    [view addSubview:titleLabel];
    
    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 28, view.bounds.size.width - 80, 20)];
    subLabel.text = subtitle;
    subLabel.font = [UIFont systemFontOfSize:14];
    subLabel.textColor = [UIColor grayColor];
    [view addSubview:subLabel];
    
    UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectMake(view.bounds.size.width - 60, 15, 0, 0)];
    switchView.on = isOn;
    switchView.tag = tag;
    [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [view addSubview:switchView];
    
    return view;
}

- (UIView *)createNumberItemWithTitle:(NSString *)title subtitle:(NSString *)subtitle value:(NSInteger)value atY:(CGFloat)y tag:(NSInteger)tag {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(20, y, self.view.bounds.size.width - 40, 60)];
    
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, view.bounds.size.width - 80, 25)];
    titleLabel.text = title;
    titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    [view addSubview:titleLabel];
    
    UILabel *subLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 28, view.bounds.size.width - 80, 20)];
    subLabel.text = subtitle;
    subLabel.font = [UIFont systemFontOfSize:14];
    subLabel.textColor = [UIColor grayColor];
    [view addSubview:subLabel];
    
    // 数字显示
    UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(view.bounds.size.width - 60, 20, 40, 25)];
    valueLabel.text = [NSString stringWithFormat:@"%ld", (long)value];
    valueLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightMedium];
    valueLabel.textAlignment = NSTextAlignmentCenter;
    valueLabel.tag = tag + 1; // 值标签的tag是设置标签+1
    [view addSubview:valueLabel];
    
    // 减号按钮
    UIButton *minusBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    minusBtn.frame = CGRectMake(view.bounds.size.width - 130, 15, 30, 30);
    [minusBtn setTitle:@"-" forState:UIControlStateNormal];
    minusBtn.titleLabel.font = [UIFont boldSystemFontOfSize:24];
    minusBtn.tag = tag;
    [minusBtn addTarget:self action:@selector(numberButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:minusBtn];
    
    // 加号按钮
    UIButton *plusBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    plusBtn.frame = CGRectMake(view.bounds.size.width - 30, 15, 30, 30);
    [plusBtn setTitle:@"+" forState:UIControlStateNormal];
    plusBtn.titleLabel.font = [UIFont boldSystemFontOfSize:20];
    plusBtn.tag = tag + 10; // 加号按钮的tag是设置标签+10
    [plusBtn addTarget:self action:@selector(numberButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    [view addSubview:plusBtn];
    
    return view;
}

- (void)switchChanged:(UISwitch *)sender {
    if (sender.tag == 100) { // 启用插件开关
        dd_pluginEnabled = sender.on;
    }
}

- (void)numberButtonTapped:(UIButton *)sender {
    NSInteger baseTag = sender.tag;
    NSInteger settingTag;
    BOOL isPlus = NO;
    
    // 确定是哪个设置项
    if (baseTag >= 210) { // 加号按钮
        settingTag = baseTag - 10;
        isPlus = YES;
    } else { // 减号按钮
        settingTag = baseTag;
        isPlus = NO;
    }
    
    // 获取对应的值标签
    UILabel *valueLabel = [self.view viewWithTag:settingTag + 1];
    NSInteger currentValue = [valueLabel.text integerValue];
    
    // 更新值
    if (isPlus) {
        currentValue++;
        if (currentValue > 50) currentValue = 50;
    } else {
        currentValue--;
        if (currentValue < 0) currentValue = 0;
    }
    
    valueLabel.text = [NSString stringWithFormat:@"%ld", (long)currentValue];
    
    // 保存到对应的设置
    if (settingTag == 200) { // 点赞数量
        dd_zanCount = currentValue;
    } else if (settingTag == 300) { // 评论数量
        dd_commentCount = currentValue;
    }
}

- (void)doneTapped {
    // 保存自定义评论内容
    UITextView *textView = [self.view viewWithTag:400];
    dd_customComments = textView.text ?: @"";
    
    // 保存设置
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:dd_pluginEnabled forKey:@"DDZanEnabled"];
    [defaults setInteger:dd_zanCount forKey:@"DDZanCount"];
    [defaults setInteger:dd_commentCount forKey:@"DDCommentCount"];
    [defaults setObject:dd_customComments forKey:@"DDCustomComments"];
    [defaults synchronize];
    
    DDLog(@"设置已保存: 点赞=%ld, 评论=%ld", (long)dd_zanCount, (long)dd_commentCount);
    
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
            DDLog(@"处理朋友圈详情失败: %@", e);
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
            DDLog(@"处理时间线数据失败: %@", e);
        }
    }
    
    %orig;
}

%end

#pragma mark - 插件初始化
%ctor {
    @autoreleasepool {
        DDLog(@"DD集赞助手加载成功");
        
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
            dd_customComments = [defaults stringForKey:@"DDCustomComments"] ?: @"高级\n点赞就完事了\n6666\n赞~\n这个不错\n牛皮";
        }
        
        DDLog(@"初始化完成: 启用=%d, 点赞=%ld, 评论=%ld", 
              dd_pluginEnabled, (long)dd_zanCount, (long)dd_commentCount);
    }
}