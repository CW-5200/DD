// DD集赞助手.xm
// Created by 集赞助手插件
// 仅支持iOS 15.0+

#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <Foundation/Foundation.h>

// 微信基础类声明
@interface CContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@property(retain, nonatomic) NSString *m_nsNickName;
@end

@interface WCUserComment : NSObject
@property(retain, nonatomic) NSString *nickname;
@property(retain, nonatomic) NSString *username;
@property(retain, nonatomic) NSString *content;
@property(retain, nonatomic) NSString *commentID;
@property(nonatomic) int type;
@property(nonatomic) unsigned int createTime;
@end

@interface WCDataItem : NSObject
@property(retain, nonatomic) NSMutableArray *likeUsers;
@property(nonatomic) int likeCount;
@property(retain, nonatomic) NSMutableArray *commentUsers;
@property(nonatomic) int commentCount;
@property(nonatomic) BOOL likeFlag;
@end

@interface WCTimelineMgr : NSObject
- (void)modifyDataItem:(WCDataItem *)arg1 notify:(BOOL)arg2;
@end

@interface CContactMgr : NSObject
- (NSArray *)getContactList:(unsigned int)arg1 contactType:(unsigned int)arg2;
@end

@interface MMServiceCenter : NSObject
+ (id)defaultCenter;
- (id)getService:(Class)arg1;
@end

// 插件配置管理
@interface DDLikeAssistConfig : NSObject
+ (instancetype)shared;
@property (nonatomic, assign) BOOL enabled;
@property (nonatomic, assign) NSInteger likeCount;
@property (nonatomic, assign) NSInteger commentCount;
@property (nonatomic, strong) NSString *comments;
@end

@implementation DDLikeAssistConfig
+ (instancetype)shared {
    static DDLikeAssistConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [[DDLikeAssistConfig alloc] init];
        // 默认值
        config.likeCount = 10;
        config.commentCount = 5;
        config.comments = @"赞,,👍,,太棒了";
    });
    return config;
}

- (BOOL)enabled {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"DDLikeAssistEnabled"];
}

- (void)setEnabled:(BOOL)enabled {
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:@"DDLikeAssistEnabled"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSInteger)likeCount {
    NSInteger count = [[NSUserDefaults standardUserDefaults] integerForKey:@"DDLikeAssistLikeCount"];
    return count > 0 ? count : 10;
}

- (void)setLikeCount:(NSInteger)likeCount {
    [[NSUserDefaults standardUserDefaults] setInteger:likeCount forKey:@"DDLikeAssistLikeCount"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSInteger)commentCount {
    NSInteger count = [[NSUserDefaults standardUserDefaults] integerForKey:@"DDLikeAssistCommentCount"];
    return count > 0 ? count : 5;
}

- (void)setCommentCount:(NSInteger)commentCount {
    [[NSUserDefaults standardUserDefaults] setInteger:commentCount forKey:@"DDLikeAssistCommentCount"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)comments {
    NSString *comments = [[NSUserDefaults standardUserDefaults] stringForKey:@"DDLikeAssistComments"];
    return comments ? comments : @"赞,,👍,,太棒了";
}

- (void)setComments:(NSString *)comments {
    [[NSUserDefaults standardUserDefaults] setObject:comments forKey:@"DDLikeAssistComments"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
@end

// 集赞助手核心功能
@interface DDLikeAssist : NSObject
+ (instancetype)shared;
- (NSArray *)getAllFriends;
- (NSMutableArray *)generateLikeUsers;
- (NSMutableArray *)generateCommentUsers:(WCDataItem *)origItem;
@end

@implementation DDLikeAssist
+ (instancetype)shared {
    static DDLikeAssist *assist = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        assist = [[DDLikeAssist alloc] init];
    });
    return assist;
}

- (NSArray *)getAllFriends {
    static NSArray *cachedFriends = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *friends = [NSMutableArray array];
        @try {
            CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
            if (contactMgr) {
                NSArray *contacts = [contactMgr getContactList:1 contactType:0];
                for (CContact *contact in contacts) {
                    // 过滤品牌账号和性别为0的账号（可能是公众号）
                    if (![contact respondsToSelector:@selector(isBrandContact)] || 
                        (![(id)contact isBrandContact] && 
                         [contact respondsToSelector:@selector(m_uiSex)] && 
                         ((unsigned int)[contact performSelector:@selector(m_uiSex)] != 0))) {
                        [friends addObject:contact];
                    }
                }
            }
        } @catch (NSException *exception) {
            NSLog(@"DDLikeAssist: 获取好友列表失败: %@", exception);
        }
        cachedFriends = [friends copy];
    });
    return cachedFriends;
}

- (NSMutableArray *)generateLikeUsers {
    NSMutableArray *likeUsers = [NSMutableArray array];
    NSArray *friends = [self getAllFriends];
    NSInteger maxCount = MIN([DDLikeAssistConfig shared].likeCount, friends.count);
    
    for (int i = 0; i < maxCount; i++) {
        CContact *friend = friends[i];
        WCUserComment *likeComment = [[objc_getClass("WCUserComment") alloc] init];
        likeComment.username = friend.m_nsUsrName;
        likeComment.nickname = friend.m_nsNickName;
        likeComment.type = 2; // 点赞类型
        likeComment.commentID = [NSString stringWithFormat:@"%d", i];
        likeComment.createTime = (unsigned int)[[NSDate date] timeIntervalSince1970];
        [likeUsers addObject:likeComment];
    }
    
    return likeUsers;
}

- (NSMutableArray *)generateCommentUsers:(WCDataItem *)origItem {
    NSMutableArray *newComments = [NSMutableArray array];
    NSArray *origComments = origItem.commentUsers ?: @[];
    
    if (origComments.count >= [DDLikeAssistConfig shared].commentCount) {
        return [origComments mutableCopy];
    }
    
    NSArray *defaultComments = [[DDLikeAssistConfig shared].comments componentsSeparatedByString:@",,"];
    if (defaultComments.count == 0) {
        defaultComments = @[@"赞", @"👍", @"太棒了"];
    }
    
    NSArray *friends = [self getAllFriends];
    NSInteger maxCount = MIN([DDLikeAssistConfig shared].commentCount - origComments.count, friends.count);
    
    for (int i = 0; i < maxCount; i++) {
        CContact *friend = friends[i];
        WCUserComment *newComment = [[objc_getClass("WCUserComment") alloc] init];
        newComment.username = friend.m_nsUsrName;
        newComment.nickname = friend.m_nsNickName;
        newComment.type = 2; // 评论类型
        newComment.commentID = [NSString stringWithFormat:@"%d", (int)(i + origComments.count)];
        newComment.createTime = (unsigned int)([[NSDate date] timeIntervalSince1970] - arc4random() % 3600);
        newComment.content = defaultComments[arc4random() % defaultComments.count];
        [newComments addObject:newComment];
    }
    
    // 添加原始评论
    [newComments addObjectsFromArray:origComments];
    
    // 按时间排序
    [newComments sortUsingComparator:^NSComparisonResult(WCUserComment *obj1, WCUserComment *obj2) {
        return obj1.createTime < obj2.createTime ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    return newComments;
}
@end

// Hook WCTimelineMgr 实现集赞功能
%hook WCTimelineMgr

- (void)modifyDataItem:(WCDataItem *)arg1 notify:(BOOL)arg2 {
    if ([DDLikeAssistConfig shared].enabled && arg1.likeFlag) {
        // 生成点赞用户
        arg1.likeUsers = [[DDLikeAssist shared] generateLikeUsers];
        arg1.likeCount = (int)arg1.likeUsers.count;
        
        // 生成评论用户
        arg1.commentUsers = [[DDLikeAssist shared] generateCommentUsers:arg1];
        arg1.commentCount = (int)arg1.commentUsers.count;
    }
    
    %orig(arg1, arg2);
}

%end

// 设置界面控制器
@interface DDLikeAssistSettingController : UIViewController <UITableViewDelegate, UITableViewDataSource> {
    UITableView *_tableView;
}
@end

@implementation DDLikeAssistSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD集赞助手";
    self.view.backgroundColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    
    // 创建表格
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:_tableView];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 1; // 开关
        case 1: return 2; // 点赞数、评论数
        case 2: return 1; // 评论内容
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"功能开关";
        case 1: return @"数量设置";
        case 2: return @"评论内容";
        default: return @"";
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    if (section == 2) {
        return @"多个评论用英文双逗号分隔，例如：赞,,👍,,太棒了";
    }
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier];
    }
    
    DDLikeAssistConfig *config = [DDLikeAssistConfig shared];
    
    if (indexPath.section == 0) {
        // 开关
        cell.textLabel.text = @"启用集赞助手";
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = config.enabled;
        [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = switchView;
    } else if (indexPath.section == 1) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        if (indexPath.row == 0) {
            cell.textLabel.text = @"点赞数量";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)config.likeCount];
        } else {
            cell.textLabel.text = @"评论数量";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)config.commentCount];
        }
    } else if (indexPath.section == 2) {
        cell.textLabel.text = @"评论内容";
        cell.detailTextLabel.text = config.comments.length > 20 ? 
            [[config.comments substringToIndex:20] stringByAppendingString:@"..."] : config.comments;
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    DDLikeAssistConfig *config = [DDLikeAssistConfig shared];
    
    if (indexPath.section == 1) {
        // 数量设置
        NSString *title = indexPath.row == 0 ? @"设置点赞数量" : @"设置评论数量";
        NSInteger currentValue = indexPath.row == 0 ? config.likeCount : config.commentCount;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                       message:@"请输入数量"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = @"数量";
            textField.keyboardType = UIKeyboardTypeNumberPad;
            textField.text = [NSString stringWithFormat:@"%ld", (long)currentValue];
        }];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *text = alert.textFields.firstObject.text;
            NSInteger value = [text integerValue];
            
            if (value > 0) {
                if (indexPath.row == 0) {
                    config.likeCount = value;
                } else {
                    config.commentCount = value;
                }
                [_tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            }
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        
        [self presentViewController:alert animated:YES completion:nil];
        
    } else if (indexPath.section == 2) {
        // 评论内容
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"设置评论内容"
                                                                       message:@"多个评论用英文双逗号分隔"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = @"例如：赞,,👍,,太棒了";
            textField.text = config.comments;
        }];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSString *text = alert.textFields.firstObject.text;
            if (text.length > 0) {
                config.comments = text;
                [_tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            }
        }]];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)switchChanged:(UISwitch *)sender {
    [DDLikeAssistConfig shared].enabled = sender.isOn;
}

@end

// 插件管理入口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

// 插件初始化
__attribute__((constructor)) static void DDLikeAssistInit() {
    @autoreleasepool {
        // 延迟执行，确保微信完全启动
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (NSClassFromString(@"WCPluginsMgr")) {
                [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD集赞助手" 
                                                                                   version:@"1.0" 
                                                                               controller:@"DDLikeAssistSettingController"];
            }
        });
    }
}