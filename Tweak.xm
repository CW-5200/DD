// DDZanHelper.xm
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - 插件管理器接口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

#pragma mark - 微信相关类声明
@interface CContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@property(retain, nonatomic) NSString *m_nsNickName;
@property(assign, nonatomic) int m_uiType;
@property(assign, nonatomic) int m_uiFriendScene;
@end

@interface WCDataItem : NSObject
@property(retain, nonatomic) NSString *username;
@property(retain, nonatomic) NSMutableArray *likeUsers;
@property(retain, nonatomic) NSMutableArray *commentUsers;
@property(assign, nonatomic) int likeCount;
@property(assign, nonatomic) int commentCount;
@end

@interface WCUserComment : NSObject
@property(retain, nonatomic) NSString *username;
@property(retain, nonatomic) NSString *nickname;
@property(retain, nonatomic) NSString *content;
@property(assign, nonatomic) int type; // 1:点赞 2:评论
@property(assign, nonatomic) unsigned int createTime;
@end

@interface CContactMgr : NSObject
- (id)getAllContactUserName;
- (id)getContactByName:(id)arg1;
@end

@interface SettingUtil : NSObject
+ (NSString *)getCurUsrName;
@end

@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)service;
@end

@interface WCTimelineMgr : NSObject
- (void)onDataUpdated:(id)arg1 andData:(NSMutableArray *)data andAdData:(id)arg3 withChangedTime:(unsigned int)arg4;
@end

#pragma mark - 设置控制器
@interface DDZanSettingViewController : UIViewController
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *settings;
@end

@implementation DDZanSettingViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD集赞助手";
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 创建表格
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
    // 初始化设置项
    self.settings = @[
        @{@"type": @"switch", @"title": @"启用插件", @"key": @"DDZan_Enabled"},
        @{@"type": @"input", @"title": @"点赞数量", @"key": @"DDZan_LikeCount", @"placeholder": @"输入点赞数量"},
        @{@"type": @"input", @"title": @"评论数量", @"key": @"DDZan_CommentCount", @"placeholder": @"输入评论数量"},
        @{@"type": @"multiline", @"title": @"自定义评论", @"key": @"DDZan_CustomComments", @"placeholder": @"每行一条评论"}
    ];
}

#pragma mark - UITableView DataSource & Delegate
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.settings.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *setting = self.settings[indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }
    
    cell.textLabel.text = setting[@"title"];
    
    if ([setting[@"type"] isEqualToString:@"switch"]) {
        UISwitch *switchView = [[UISwitch alloc] init];
        switchView.on = [[NSUserDefaults standardUserDefaults] boolForKey:setting[@"key"]];
        [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        switchView.tag = indexPath.row;
        cell.accessoryView = switchView;
        cell.detailTextLabel.text = @"";
    } else {
        cell.accessoryView = nil;
        cell.detailTextLabel.text = [[NSUserDefaults standardUserDefaults] stringForKey:setting[@"key"]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *setting = self.settings[indexPath.row];
    if ([setting[@"type"] isEqualToString:@"input"]) {
        [self showInputAlertForSetting:setting];
    } else if ([setting[@"type"] isEqualToString:@"multiline"]) {
        [self showMultilineAlertForSetting:setting];
    }
}

- (void)switchChanged:(UISwitch *)sender {
    NSDictionary *setting = self.settings[sender.tag];
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:setting[@"key"]];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)showInputAlertForSetting:(NSDictionary *)setting {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:setting[@"title"]
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = setting[@"placeholder"];
        textField.text = [[NSUserDefaults standardUserDefaults] stringForKey:setting[@"key"]];
        textField.keyboardType = UIKeyboardTypeNumberPad;
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *value = alert.textFields.firstObject.text;
        if (value) {
            [[NSUserDefaults standardUserDefaults] setObject:value forKey:setting[@"key"]];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.tableView reloadData];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showMultilineAlertForSetting:(NSDictionary *)setting {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:setting[@"title"]
                                                                   message:@"每行一条评论内容"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = setting[@"placeholder"];
        textField.text = [[NSUserDefaults standardUserDefaults] stringForKey:setting[@"key"]];
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *value = alert.textFields.firstObject.text;
        if (value) {
            [[NSUserDefaults standardUserDefaults] setObject:value forKey:setting[@"key"]];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.tableView reloadData];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - 核心功能
%group Main

// 获取联系人列表
static NSArray *getFriendList() {
    static NSArray *cachedList = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
        NSArray *allUsernames = [[contactMgr getAllContactUserName] allObjects];
        NSMutableArray *friends = [NSMutableArray array];
        
        for (NSString *username in allUsernames) {
            CContact *contact = [contactMgr getContactByName:username];
            // 过滤掉公众号和群聊
            if (contact.m_uiType != 1 && contact.m_uiType != 2 && contact.m_uiType != 3) {
                // 只保留好友
                if (contact.m_uiFriendScene != 0) {
                    [friends addObject:username];
                }
            }
        }
        
        cachedList = [friends copy];
    });
    
    return cachedList;
}

// 生成随机点赞
static NSMutableArray *generateFakeLikes(NSMutableArray *originalLikes) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DDZan_Enabled"]) {
        return originalLikes;
    }
    
    NSInteger targetCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"DDZan_LikeCount"];
    if (targetCount <= 0) return originalLikes;
    
    NSArray *friends = getFriendList();
    if (friends.count == 0) return originalLikes;
    
    NSMutableArray *newLikes = [NSMutableArray array];
    if (originalLikes) [newLikes addObjectsFromArray:originalLikes];
    
    // 确保不重复
    NSMutableArray *availableFriends = [friends mutableCopy];
    for (WCUserComment *like in originalLikes) {
        [availableFriends removeObject:like.username];
    }
    
    CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
    
    for (int i = 0; i < MIN(targetCount, availableFriends.count); i++) {
        NSString *username = availableFriends[i];
        CContact *contact = [contactMgr getContactByName:username];
        
        WCUserComment *fakeLike = [objc_getClass("WCUserComment") new];
        fakeLike.username = username;
        fakeLike.nickname = contact.m_nsNickName ?: username;
        fakeLike.type = 1; // 点赞
        fakeLike.createTime = (unsigned int)[[NSDate date] timeIntervalSince1970];
        
        [newLikes addObject:fakeLike];
    }
    
    return newLikes;
}

// 生成随机评论
static NSMutableArray *generateFakeComments(NSMutableArray *originalComments) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DDZan_Enabled"]) {
        return originalComments;
    }
    
    NSInteger targetCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"DDZan_CommentCount"];
    if (targetCount <= 0) return originalComments;
    
    NSArray *friends = getFriendList();
    if (friends.count == 0) return originalComments;
    
    NSString *customCommentsStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"DDZan_CustomComments"];
    NSArray *commentTemplates = customCommentsStr.length > 0 ? 
        [customCommentsStr componentsSeparatedByString:@"\n"] : 
        @[@"赞一个", @"不错哦", @"666", @"优秀", @"可以可以"];
    
    NSMutableArray *newComments = [NSMutableArray array];
    if (originalComments) [newComments addObjectsFromArray:originalComments];
    
    CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
    
    for (int i = 0; i < MIN(targetCount, friends.count); i++) {
        NSString *username = friends[i];
        CContact *contact = [contactMgr getContactByName:username];
        
        WCUserComment *fakeComment = [objc_getClass("WCUserComment") new];
        fakeComment.username = username;
        fakeComment.nickname = contact.m_nsNickName ?: username;
        fakeComment.type = 2; // 评论
        fakeComment.createTime = (unsigned int)[[NSDate date] timeIntervalSince1970];
        
        // 随机选择评论内容
        NSString *randomComment = commentTemplates[arc4random_uniform((uint32_t)commentTemplates.count)];
        fakeComment.content = randomComment;
        
        [newComments addObject:fakeComment];
    }
    
    return newComments;
}

%hook WCTimelineMgr

- (void)onDataUpdated:(id)arg1 andData:(NSMutableArray *)data andAdData:(id)arg3 withChangedTime:(unsigned int)arg4 {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DDZan_Enabled"]) {
        %orig;
        return;
    }
    
    NSString *myUsername = [objc_getClass("SettingUtil") getCurUsrName];
    
    for (WCDataItem *item in data) {
        if ([item.username isEqualToString:myUsername]) {
            // 处理点赞
            NSMutableArray *originalLikes = item.likeUsers;
            NSMutableArray *fakeLikes = generateFakeLikes(originalLikes);
            item.likeUsers = fakeLikes;
            item.likeCount = (int)fakeLikes.count;
            
            // 处理评论
            NSMutableArray *originalComments = item.commentUsers;
            NSMutableArray *fakeComments = generateFakeComments(originalComments);
            item.commentUsers = fakeComments;
            item.commentCount = (int)fakeComments.count;
        }
    }
    
    %orig;
}

%end

%end // Main group

#pragma mark - 插件注册
%ctor {
    @autoreleasepool {
        // 注册到插件管理器
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD集赞助手" 
                                   version:@"1.0" 
                               controller:@"DDZanSettingViewController"];
        }
        
        // 初始化默认设置
        NSDictionary *defaults = @{
            @"DDZan_Enabled": @YES,
            @"DDZan_LikeCount": @"10",
            @"DDZan_CommentCount": @"5",
            @"DDZan_CustomComments": @"赞一个\n不错哦\n666\n优秀\n可以可以"
        };
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        for (NSString *key in defaults) {
            if (![userDefaults objectForKey:key]) {
                [userDefaults setObject:defaults[key] forKey:key];
            }
        }
        [userDefaults synchronize];
        
        // 激活主功能组
        %init(Main);
    }
}