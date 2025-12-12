// DDZanAssistant.xm
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
@interface DDZanSettingViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
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
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        cell.accessoryView = nil;
        cell.detailTextLabel.text = [[NSUserDefaults standardUserDefaults] stringForKey:setting[@"key"]];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
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
    
    // 清除缓存以便重新生成
    if ([setting[@"key"] isEqualToString:@"DDZan_Enabled"]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"DDZan_FriendCache"];
    }
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
        if (value && value.length > 0) {
            [[NSUserDefaults standardUserDefaults] setObject:value forKey:setting[@"key"]];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.tableView reloadData];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)showMultilineAlertForSetting:(NSDictionary *)setting {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:setting[@"title"]
                                                                   message:@"每行一条评论内容，输入完成后点击确定"
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectMake(10, 50, 250, 150)];
    textView.text = [[NSUserDefaults standardUserDefaults] stringForKey:setting[@"key"]];
    textView.font = [UIFont systemFontOfSize:14];
    textView.layer.borderColor = [UIColor lightGrayColor].CGColor;
    textView.layer.borderWidth = 1.0;
    textView.layer.cornerRadius = 5.0;
    
    UIViewController *vc = [UIViewController new];
    vc.view = textView;
    [alert setValue:vc forKey:@"contentViewController"];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *value = textView.text;
        if (value) {
            [[NSUserDefaults standardUserDefaults] setObject:value forKey:setting[@"key"]];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self.tableView reloadData];
        }
    }]];
    
    [self presentViewController:alert animated:YES completion:^{
        [textView becomeFirstResponder];
    }];
}

@end

#pragma mark - 核心功能
%group Main

// 获取联系人列表
static NSArray *getFriendList() {
    // 检查缓存
    NSData *cachedData = [[NSUserDefaults standardUserDefaults] objectForKey:@"DDZan_FriendCache"];
    if (cachedData) {
        NSError *error;
        NSArray *cachedList = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSArray class] fromData:cachedData error:&error];
        if (cachedList && cachedList.count > 0) {
            return cachedList;
        }
    }
    
    // 获取联系人管理器
    MMServiceCenter *serviceCenter = [objc_getClass("MMServiceCenter") defaultCenter];
    CContactMgr *contactMgr = [serviceCenter getService:objc_getClass("CContactMgr")];
    
    if (!contactMgr) return @[];
    
    // 获取所有联系人
    NSSet *allUsernamesSet = [contactMgr getAllContactUserName];
    if (!allUsernamesSet) return @[];
    
    NSArray *allUsernames = [allUsernamesSet allObjects];
    NSMutableArray *friends = [NSMutableArray array];
    
    for (NSString *username in allUsernames) {
        @autoreleasepool {
            CContact *contact = [contactMgr getContactByName:username];
            if (contact) {
                // 过滤掉公众号(1)、群聊(2)、企业号(3)等
                int contactType = [contact m_uiType];
                if (contactType != 1 && contactType != 2 && contactType != 3) {
                    // 确保是好友（m_uiFriendScene != 0 表示是好友）
                    int friendScene = [contact m_uiFriendScene];
                    if (friendScene != 0) {
                        NSString *nickname = [contact m_nsNickName];
                        NSString *displayName = nickname ? nickname : username;
                        [friends addObject:@{
                            @"username": username,
                            @"nickname": displayName
                        }];
                    }
                }
            }
        }
    }
    
    // 缓存结果
    if (friends.count > 0) {
        NSError *error;
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:friends requiringSecureCoding:NO error:&error];
        if (data && !error) {
            [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"DDZan_FriendCache"];
            [[NSUserDefaults standardUserDefaults] synchronize];
        }
    }
    
    return [friends copy];
}

// 生成随机点赞
static NSMutableArray *generateFakeLikes(NSMutableArray *originalLikes, NSString *ownerUsername) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DDZan_Enabled"]) {
        return originalLikes;
    }
    
    NSInteger targetCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"DDZan_LikeCount"];
    if (targetCount <= 0) return originalLikes ?: [NSMutableArray array];
    
    NSArray *friends = getFriendList();
    if (friends.count == 0) return originalLikes ?: [NSMutableArray array];
    
    NSMutableArray *newLikes = [NSMutableArray array];
    if (originalLikes && originalLikes.count > 0) {
        [newLikes addObjectsFromArray:originalLikes];
    }
    
    // 确保不重复
    NSMutableArray *availableFriends = [friends mutableCopy];
    for (id like in newLikes) {
        if ([like respondsToSelector:@selector(username)]) {
            NSString *existingUsername = [like username];
            // 修复：使用正确的过滤方式
            NSMutableArray *toRemove = [NSMutableArray array];
            for (NSDictionary *friendInfo in availableFriends) {
                if ([friendInfo[@"username"] isEqualToString:existingUsername]) {
                    [toRemove addObject:friendInfo];
                }
            }
            [availableFriends removeObjectsInArray:toRemove];
        }
    }
    
    // 如果可用好友不足，直接返回现有数据
    if (availableFriends.count == 0) return newLikes;
    
    // 生成新的点赞
    for (int i = 0; i < MIN(targetCount, availableFriends.count); i++) {
        NSDictionary *friendInfo = availableFriends[i];
        NSString *username = friendInfo[@"username"];
        NSString *nickname = friendInfo[@"nickname"];
        
        // 避免给自己点赞
        if ([username isEqualToString:ownerUsername]) continue;
        
        // 创建点赞对象
        WCUserComment *fakeLike = [[objc_getClass("WCUserComment") alloc] init];
        [fakeLike setUsername:username];
        [fakeLike setNickname:nickname];
        [fakeLike setType:1]; // 1:点赞
        [fakeLike setCreateTime:(unsigned int)[[NSDate date] timeIntervalSince1970]];
        
        [newLikes addObject:fakeLike];
    }
    
    return newLikes;
}

// 生成随机评论
static NSMutableArray *generateFakeComments(NSMutableArray *originalComments, NSString *ownerUsername) {
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DDZan_Enabled"]) {
        return originalComments;
    }
    
    NSInteger targetCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"DDZan_CommentCount"];
    if (targetCount <= 0) return originalComments ?: [NSMutableArray array];
    
    NSArray *friends = getFriendList();
    if (friends.count == 0) return originalComments ?: [NSMutableArray array];
    
    // 获取自定义评论内容
    NSString *customCommentsStr = [[NSUserDefaults standardUserDefaults] stringForKey:@"DDZan_CustomComments"];
    NSArray *commentTemplates = @[@"👍 赞一个", @"👍 不错哦", @"👍 666", @"👍 优秀", @"👍 可以可以"];
    
    if (customCommentsStr && customCommentsStr.length > 0) {
        commentTemplates = [customCommentsStr componentsSeparatedByString:@"\n"];
        // 过滤空行
        NSMutableArray *filtered = [NSMutableArray array];
        for (NSString *line in commentTemplates) {
            if (line.length > 0) {
                [filtered addObject:line];
            }
        }
        commentTemplates = filtered;
    }
    
    if (commentTemplates.count == 0) {
        commentTemplates = @[@"👍 赞一个", @"👍 不错哦", @"👍 666", @"👍 优秀", @"👍 可以可以"];
    }
    
    NSMutableArray *newComments = [NSMutableArray array];
    if (originalComments && originalComments.count > 0) {
        [newComments addObjectsFromArray:originalComments];
    }
    
    // 确保不重复
    NSMutableArray *availableFriends = [friends mutableCopy];
    for (id comment in newComments) {
        if ([comment respondsToSelector:@selector(username)]) {
            NSString *existingUsername = [comment username];
            // 修复：使用正确的过滤方式
            NSMutableArray *toRemove = [NSMutableArray array];
            for (NSDictionary *friendInfo in availableFriends) {
                if ([friendInfo[@"username"] isEqualToString:existingUsername]) {
                    [toRemove addObject:friendInfo];
                }
            }
            [availableFriends removeObjectsInArray:toRemove];
        }
    }
    
    // 如果可用好友不足，直接返回现有数据
    if (availableFriends.count == 0) return newComments;
    
    // 生成新的评论
    for (int i = 0; i < MIN(targetCount, availableFriends.count); i++) {
        NSDictionary *friendInfo = availableFriends[i];
        NSString *username = friendInfo[@"username"];
        NSString *nickname = friendInfo[@"nickname"];
        
        // 避免给自己评论
        if ([username isEqualToString:ownerUsername]) continue;
        
        // 创建评论对象
        WCUserComment *fakeComment = [[objc_getClass("WCUserComment") alloc] init];
        [fakeComment setUsername:username];
        [fakeComment setNickname:nickname];
        [fakeComment setType:2]; // 2:评论
        [fakeComment setCreateTime:(unsigned int)[[NSDate date] timeIntervalSince1970]];
        
        // 随机选择评论内容
        NSUInteger randomIndex = arc4random_uniform((uint32_t)commentTemplates.count);
        NSString *randomComment = commentTemplates[randomIndex];
        [fakeComment setContent:randomComment];
        
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
    
    NSString *myUsername = nil;
    if ([objc_getClass("SettingUtil") respondsToSelector:@selector(getCurUsrName)]) {
        myUsername = [objc_getClass("SettingUtil") getCurUsrName];
    }
    
    if (!myUsername || myUsername.length == 0) {
        %orig;
        return;
    }
    
    for (WCDataItem *item in data) {
        if (![item respondsToSelector:@selector(username)]) continue;
        
        NSString *itemUsername = [item username];
        if ([itemUsername isEqualToString:myUsername]) {
            // 处理点赞
            NSMutableArray *originalLikes = [item likeUsers];
            NSMutableArray *fakeLikes = generateFakeLikes(originalLikes, myUsername);
            [item setLikeUsers:fakeLikes];
            [item setLikeCount:(int)fakeLikes.count];
            
            // 处理评论
            NSMutableArray *originalComments = [item commentUsers];
            NSMutableArray *fakeComments = generateFakeComments(originalComments, myUsername);
            [item setCommentUsers:fakeComments];
            [item setCommentCount:(int)fakeComments.count];
        }
    }
    
    %orig;
}

%end

%end // Main group

#pragma mark - 插件注册和初始化
%ctor {
    @autoreleasepool {
        NSLog(@"[DD集赞助手] 插件加载");
        
        // 注册到插件管理器
        if (NSClassFromString(@"WCPluginsMgr")) {
            NSLog(@"[DD集赞助手] 注册到插件管理器");
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD集赞助手" 
                                   version:@"1.0" 
                               controller:@"DDZanSettingViewController"];
        }
        
        // 初始化默认设置
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSDictionary *defaults = @{
            @"DDZan_Enabled": @YES,
            @"DDZan_LikeCount": @"10",
            @"DDZan_CommentCount": @"5",
            @"DDZan_CustomComments": @"👍 赞一个\n👍 不错哦\n👍 666\n👍 优秀\n👍 可以可以"
        };
        
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