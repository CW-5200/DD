// DD集赞助手.xm
// Created for iOS 15.0+
// 功能：朋友圈自动点赞和评论，使用真实好友用户名

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

// 微信内部类声明
@interface CContact : NSObject
@property (nonatomic, copy) NSString *m_nsUsrName;
@property (nonatomic, copy) NSString *m_nsNickName;
@property (nonatomic, copy) NSString *m_nsRemark;
- (BOOL)isBrandContact;
@end

@interface CContactMgr : NSObject
- (id)getSelfContact;
- (id)getContactByName:(id)arg1;
- (NSArray *)getContactList:(unsigned int)arg1 contactType:(unsigned int)arg2;
@end

@interface WCUserComment : NSObject
@property (retain, nonatomic) NSString *nickname;
@property (retain, nonatomic) NSString *username;
@property (retain, nonatomic) NSString *content;
@property (retain, nonatomic) NSString *commentID;
@property (nonatomic) int type;
@property (nonatomic) unsigned int createTime;
@end

@interface WCDataItem : NSObject
@property (retain, nonatomic) NSMutableArray *likeUsers;
@property (nonatomic) int likeCount;
@property (retain, nonatomic) NSMutableArray *commentUsers;
@property (nonatomic) int commentCount;
@property (nonatomic) BOOL likeFlag;
@property (nonatomic) unsigned int createtime;
@end

@interface WCTimelineMgr : NSObject
- (void)modifyDataItem:(WCDataItem *)arg1 notify:(BOOL)arg2;
@end

@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)service;
@end

// 插件管理入口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

// 配置管理
@interface DDLikeAssistantConfig : NSObject
+ (instancetype)shared;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, strong) NSString *comments;
@property (nonatomic, strong) NSNumber *likeCount;
@property (nonatomic, strong) NSNumber *commentCount;
@end

@implementation DDLikeAssistantConfig
+ (instancetype)shared {
    static DDLikeAssistantConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[DDLikeAssistantConfig alloc] init];
    });
    return config;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _enabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"DDLikeAssistantEnable"];
        _comments = [[NSUserDefaults standardUserDefaults] stringForKey:@"DDLikeAssistantComments"] ?: @"赞,👍,太棒了";
        _likeCount = [[NSUserDefaults standardUserDefaults] objectForKey:@"DDLikeAssistantLikeCount"] ?: @5;
        _commentCount = [[NSUserDefaults standardUserDefaults] objectForKey:@"DDLikeAssistantCommentCount"] ?: @3;
    }
    return self;
}

- (void)setEnabled:(BOOL)enabled {
    _enabled = enabled;
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"DDLikeAssistantEnable"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setComments:(NSString *)comments {
    _comments = comments;
    [[NSUserDefaults standardUserDefaults] setObject:comments forKey:@"DDLikeAssistantComments"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setLikeCount:(NSNumber *)likeCount {
    _likeCount = likeCount;
    [[NSUserDefaults standardUserDefaults] setObject:likeCount forKey:@"DDLikeAssistantLikeCount"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)setCommentCount:(NSNumber *)commentCount {
    _commentCount = commentCount;
    [[NSUserDefaults standardUserDefaults] setObject:commentCount forKey:@"DDLikeAssistantCommentCount"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
@end

// 主逻辑
@interface DDLikeAssistant : NSObject
+ (NSArray<CContact*> *)allFriends;
+ (NSMutableArray<WCUserComment *>*)commentUsers;
+ (NSMutableArray<WCUserComment *>*)commentWith:(WCDataItem *)origItem;
@end

@implementation DDLikeAssistant

+ (NSArray<CContact*> *)allFriends {
    static NSArray *friends = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *friendList = [NSMutableArray array];
        CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
        NSArray* contacts = [contactMgr getContactList:1 contactType:0];
        
        for(CContact* contact in contacts) {
            // 排除公众号和特殊账号
            if (![contact isBrandContact] && 
                ![contact.m_nsUsrName containsString:@"@openim"] &&
                ![contact.m_nsUsrName hasPrefix:@"gh_"]) {
                [friendList addObject:contact];
            }
        }
        friends = [friendList copy];
    });
    return friends;
}

+ (NSMutableArray<WCUserComment *>*)commentUsers {
    NSMutableArray* likeCommentUsers = [NSMutableArray array];
    NSArray<CContact*> *allFriends = [self allFriends];
    NSInteger maxCount = MIN([DDLikeAssistantConfig shared].likeCount.integerValue, allFriends.count);
    
    [allFriends enumerateObjectsUsingBlock:^(CContact *curAddContact, NSUInteger idx, BOOL * _Nonnull stop) {
        WCUserComment* likeComment = [[objc_getClass("WCUserComment") alloc] init];
        likeComment.username = curAddContact.m_nsUsrName;
        likeComment.nickname = curAddContact.m_nsRemark.length ? curAddContact.m_nsRemark : curAddContact.m_nsNickName;
        likeComment.type = 2; // 点赞类型
        likeComment.commentID = [NSString stringWithFormat:@"%lu", (unsigned long)idx];
        likeComment.createTime = [[NSDate date] timeIntervalSince1970];
        [likeCommentUsers addObject:likeComment];
        
        if (idx >= maxCount - 1) {
            *stop = YES;
        }
    }];
    return likeCommentUsers;
}

+ (NSMutableArray<WCUserComment *>*)commentWith:(WCDataItem *)origItem {
    NSMutableArray* origComment = origItem.commentUsers;
    NSInteger targetCount = [DDLikeAssistantConfig shared].commentCount.integerValue;
    
    if (origComment.count >= targetCount) { 
        return origComment;
    }
    
    NSMutableArray* newComments = [NSMutableArray array];
    [newComments addObjectsFromArray:origComment];
    
    NSArray<NSString *> *defaultComments = [[DDLikeAssistantConfig shared].comments componentsSeparatedByString:@","];
    if (defaultComments.count == 0) {
        defaultComments = @[@"赞", @"👍", @"太棒了"];
    }
    
    NSArray<CContact*> *allFriends = [self allFriends];
    NSInteger timeInterval = [[NSDate date] timeIntervalSince1970] - origItem.createtime;
    
    // 添加新评论
    [allFriends enumerateObjectsUsingBlock:^(CContact *curAddContact, NSUInteger idx, BOOL * _Nonnull stop) {
        WCUserComment* newComment = [[objc_getClass("WCUserComment") alloc] init];
        newComment.username = curAddContact.m_nsUsrName;
        newComment.nickname = curAddContact.m_nsRemark.length ? curAddContact.m_nsRemark : curAddContact.m_nsNickName;
        newComment.type = 2; // 评论类型
        newComment.commentID = [NSString stringWithFormat:@"%lu", (unsigned long)idx + origComment.count];
        newComment.createTime = [[NSDate date] timeIntervalSince1970] - arc4random() % timeInterval;
        newComment.content = defaultComments[arc4random() % defaultComments.count];
        [newComments addObject:newComment];
        
        if (newComments.count >= targetCount) {
            *stop = YES;
        }
    }];
    
    // 按时间排序
    [newComments sortUsingComparator:^NSComparisonResult(WCUserComment* obj1, WCUserComment *obj2) {
        return obj1.createTime < obj2.createTime ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    return newComments;
}

@end

// Hook 微信朋友圈管理
%hook WCTimelineMgr

- (void)modifyDataItem:(WCDataItem *)arg1 notify:(BOOL)arg2 {
    if (![DDLikeAssistantConfig shared].enabled) {
        %orig(arg1, arg2);
        return;
    }
    
    if (arg1.likeFlag) {
        // 添加真实好友的评论
        arg1.commentUsers = [DDLikeAssistant commentWith:arg1];
        arg1.commentCount = (int)arg1.commentUsers.count;
        
        // 添加真实好友的点赞
        arg1.likeUsers = [DDLikeAssistant commentUsers];
        arg1.likeCount = (int)arg1.likeUsers.count;
    }
    
    %orig(arg1, arg2);
}

%end

// 插件设置界面
@interface DDLikeAssistantSettingsController : UIViewController
@property (nonatomic, strong) UISwitch *enabledSwitch;
@property (nonatomic, strong) UITextField *commentsField;
@property (nonatomic, strong) UITextField *likeCountField;
@property (nonatomic, strong) UITextField *commentCountField;
@end

@implementation DDLikeAssistantSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD集赞助手设置";
    self.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1];
    
    // 启用开关
    UILabel *enabledLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 200, 40)];
    enabledLabel.text = @"启用集赞助手";
    enabledLabel.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:enabledLabel];
    
    _enabledSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(250, 105, 0, 0)];
    _enabledSwitch.on = [DDLikeAssistantConfig shared].enabled;
    [_enabledSwitch addTarget:self action:@selector(enabledChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_enabledSwitch];
    
    // 评论内容
    UILabel *commentsLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 160, 300, 30)];
    commentsLabel.text = @"评论内容（用逗号分隔）:";
    commentsLabel.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:commentsLabel];
    
    _commentsField = [[UITextField alloc] initWithFrame:CGRectMake(20, 190, 300, 40)];
    _commentsField.borderStyle = UITextBorderStyleRoundedRect;
    _commentsField.text = [DDLikeAssistantConfig shared].comments;
    _commentsField.placeholder = @"例如：赞,👍,太棒了";
    [self.view addSubview:_commentsField];
    
    // 点赞人数
    UILabel *likeCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 250, 200, 30)];
    likeCountLabel.text = @"点赞人数:";
    likeCountLabel.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:likeCountLabel];
    
    _likeCountField = [[UITextField alloc] initWithFrame:CGRectMake(20, 280, 100, 40)];
    _likeCountField.borderStyle = UITextBorderStyleRoundedRect;
    _likeCountField.keyboardType = UIKeyboardTypeNumberPad;
    _likeCountField.text = [NSString stringWithFormat:@"%@", [DDLikeAssistantConfig shared].likeCount];
    [self.view addSubview:_likeCountField];
    
    // 评论人数
    UILabel *commentCountLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 340, 200, 30)];
    commentCountLabel.text = @"评论人数:";
    commentCountLabel.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:commentCountLabel];
    
    _commentCountField = [[UITextField alloc] initWithFrame:CGRectMake(20, 370, 100, 40)];
    _commentCountField.borderStyle = UITextBorderStyleRoundedRect;
    _commentCountField.keyboardType = UIKeyboardTypeNumberPad;
    _commentCountField.text = [NSString stringWithFormat:@"%@", [DDLikeAssistantConfig shared].commentCount];
    [self.view addSubview:_commentCountField];
    
    // 保存按钮
    UIButton *saveButton = [UIButton buttonWithType:UIButtonTypeSystem];
    saveButton.frame = CGRectMake(20, 450, 300, 44);
    saveButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    [saveButton setTitle:@"保存设置" forState:UIControlStateNormal];
    [saveButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    saveButton.layer.cornerRadius = 8;
    [saveButton addTarget:self action:@selector(saveSettings) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:saveButton];
}

- (void)enabledChanged:(UISwitch *)sender {
    [DDLikeAssistantConfig shared].enabled = sender.on;
}

- (void)saveSettings {
    [DDLikeAssistantConfig shared].comments = _commentsField.text ?: @"赞,👍,太棒了";
    [DDLikeAssistantConfig shared].likeCount = @([_likeCountField.text integerValue] ?: 5);
    [DDLikeAssistantConfig shared].commentCount = @([_commentCountField.text integerValue] ?: 3);
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" 
                                                                   message:@"设置已保存" 
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

// 插件初始化
%ctor {
    @autoreleasepool {
        // 检查iOS版本
        if (@available(iOS 15.0, *)) {
            NSLog(@"DD集赞助手: iOS 15.0+ 系统，开始初始化");
            
            // 延迟执行，确保微信完全启动
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (NSClassFromString(@"WCPluginsMgr")) {
                    // 注册插件到管理入口
                    [[objc_getClass("WCPluginsMgr") sharedInstance] 
                        registerControllerWithTitle:@"DD集赞助手" 
                                           version:@"1.0" 
                                        controller:@"DDLikeAssistantSettingsController"];
                    
                    NSLog(@"DD集赞助手: 插件注册成功");
                } else {
                    NSLog(@"DD集赞助手: 错误 - 未找到WCPluginsMgr");
                }
            });
        } else {
            NSLog(@"DD集赞助手: 不支持iOS 15.0以下系统");
        }
    }
}