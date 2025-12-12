#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 微信类声明
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
@property (retain, nonatomic) NSString *commentID;
@property (nonatomic) int type; // 1=点赞 2=评论
@property (nonatomic) unsigned int createTime;
@end

@interface CContact : NSObject
@property (nonatomic, copy) NSString *m_nsUsrName;
@property (nonatomic, copy) NSString *m_nsNickName;
@property (nonatomic, assign) unsigned int m_uiType;
@property (nonatomic, assign) int m_uiFriendScene;
@end

@interface CContactMgr : NSObject
- (id)getSelfContact;
- (id)getContactByName:(id)arg1;
- (id)getAllContactUserName;
@end

@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)service;
@end

@interface SettingUtil : NSObject
+ (NSString*)getCurUsrName;
@end

@interface WCCommentDetailViewControllerFB : NSObject
@property (nonatomic, copy) WCDataItem *dataItem;
@end

@interface WCTimelineMgr : NSObject
- (void)onDataUpdated:(id)arg1 andData:(NSMutableArray*)data andAdData:(id)arg3 withChangedTime:(unsigned int)arg4;
@end

@interface MicroMessengerAppDelegate : NSObject
- (bool)application:(id)application didFinishLaunchingWithOptions:(id)options;
@end

#pragma mark - 插件管理接口
@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
- (void)registerSwitchWithTitle:(NSString *)title key:(NSString *)key;
@end

#pragma mark - 设置控制器
@interface DDZanAssistantViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) NSArray *settings;
@end

@implementation DDZanAssistantViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD集赞助手";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    // 设置列表
    self.settings = @[
        @{@"title": @"开启插件功能", @"type": @"switch", @"key": @"kDDOpenZan"},
        @{@"title": @"点赞数量", @"type": @"input", @"key": @"kDDZanCount", @"placeholder": @"输入点赞数"},
        @{@"title": @"评论数量", @"type": @"input", @"key": @"kDDCmtCount", @"placeholder": @"输入评论数"},
        @{@"title": @"保留原始赞/评论", @"type": @"switch", @"key": @"kDDKeepOld"},
        @{@"title": @"每次随机刷新", @"type": @"switch", @"key": @"kDDRandomPerOpen"},
        @{@"title": @"允许非好友", @"type": @"switch", @"key": @"kDDNotFriendZan"},
        @{@"title": @"允许重复点赞", @"type": @"switch", @"key": @"kDDFriendZanRepeat"}
    ];
    
    // 创建表格
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
}

#pragma mark - UITableViewDataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.settings.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
    }
    
    NSDictionary *setting = self.settings[indexPath.row];
    cell.textLabel.text = setting[@"title"];
    
    if ([setting[@"type"] isEqualToString:@"switch"]) {
        UISwitch *switchView = [[UISwitch alloc] init];
        BOOL isOn = [[NSUserDefaults standardUserDefaults] boolForKey:setting[@"key"]];
        switchView.on = isOn;
        [switchView addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
        switchView.tag = indexPath.row;
        cell.accessoryView = switchView;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    } else {
        UILabel *valueLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 60, 30)];
        NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:setting[@"key"]];
        valueLabel.text = value > 0 ? [NSString stringWithFormat:@"%ld", (long)value] : @"未设置";
        valueLabel.textColor = [UIColor grayColor];
        cell.accessoryView = valueLabel;
        cell.selectionStyle = UITableViewCellSelectionStyleDefault;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSDictionary *setting = self.settings[indexPath.row];
    if ([setting[@"type"] isEqualToString:@"input"]) {
        [self showInputAlert:setting];
    }
}

- (void)switchChanged:(UISwitch *)sender {
    NSDictionary *setting = self.settings[sender.tag];
    [[NSUserDefaults standardUserDefaults] setBool:sender.on forKey:setting[@"key"]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // 清除好友缓存
    if ([setting[@"key"] isEqualToString:@"kDDNotFriendZan"]) {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"kDDFriendListCache"];
    }
}

- (void)showInputAlert:(NSDictionary *)setting {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:setting[@"title"]
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = setting[@"placeholder"];
        textField.keyboardType = UIKeyboardTypeNumberPad;
        NSInteger value = [[NSUserDefaults standardUserDefaults] integerForKey:setting[@"key"]];
        if (value > 0) {
            textField.text = [NSString stringWithFormat:@"%ld", (long)value];
        }
    }];
    
    [alert addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *text = alert.textFields.firstObject.text;
        NSInteger value = [text integerValue];
        [[NSUserDefaults standardUserDefaults] setInteger:value forKey:setting[@"key"]];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self.tableView reloadData];
    }]];
    
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - 核心功能
static NSArray* dd_getFriendList() {
    // 检查缓存
    NSArray* cache = [[NSUserDefaults standardUserDefaults] objectForKey:@"kDDFriendListCache"];
    if (cache && [cache count] > 0) {
        return cache;
    }

    NSMutableArray* friendList = [NSMutableArray array];
    CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
    NSArray* allUserNameArr = [[contactMgr getAllContactUserName] allObjects];
    
    BOOL allowNonFriend = [[NSUserDefaults standardUserDefaults] boolForKey:@"kDDNotFriendZan"];
    
    for(NSString* userName in allUserNameArr) {
        CContact* contact = [contactMgr getContactByName:userName];
        if (contact) {
            // 过滤公众号、群聊等
            if (contact.m_uiType != 1 && contact.m_uiType != 2 && contact.m_uiType != 3) {
                if (allowNonFriend || contact.m_uiFriendScene != 0) {
                    [friendList addObject:userName];
                }
            }
        }
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:friendList forKey:@"kDDFriendListCache"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    return friendList;
}

static NSMutableArray* dd_fakeLike(NSMutableArray* origLikeUsers) {
    BOOL randomPerOpen = [[NSUserDefaults standardUserDefaults] boolForKey:@"kDDRandomPerOpen"];
    if (!randomPerOpen) {
        NSData *lastData = [[NSUserDefaults standardUserDefaults] objectForKey:@"kDDLastLikeUsers"];
        if (lastData) {
            return [NSKeyedUnarchiver unarchiveObjectWithData:lastData];
        }
    }
    
    NSMutableArray* newLikeUsers = [NSMutableArray array];
    BOOL keepOld = [[NSUserDefaults standardUserDefaults] boolForKey:@"kDDKeepOld"];
    
    if (keepOld && origLikeUsers.count > 0) {
        [newLikeUsers addObjectsFromArray:origLikeUsers];
    }
    
    NSInteger zanCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"kDDZanCount"];
    if (zanCount <= 0) {
        return newLikeUsers;
    }
    
    NSArray* friendList = dd_getFriendList();
    NSMutableArray* availableFriends = [friendList mutableCopy];
    BOOL allowRepeat = [[NSUserDefaults standardUserDefaults] boolForKey:@"kDDFriendZanRepeat"];
    
    CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
    
    for (int i = 0; i < zanCount && availableFriends.count > 0; i++) {
        NSUInteger idx = arc4random() % availableFriends.count;
        NSString* userName = availableFriends[idx];
        CContact* contact = [contactMgr getContactByName:userName];
        
        if (contact) {
            WCUserComment* like = [[objc_getClass("WCUserComment") alloc] init];
            like.username = userName;
            like.nickname = [contact m_nsNickName];
            like.type = 1;
            like.createTime = (unsigned int)[[NSDate date] timeIntervalSince1970];
            
            [newLikeUsers addObject:like];
        }
        
        if (!allowRepeat) {
            [availableFriends removeObjectAtIndex:idx];
        }
    }
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:newLikeUsers];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"kDDLastLikeUsers"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    return newLikeUsers;
}

static NSMutableArray* dd_fakeComment(NSMutableArray* origCommentUsers) {
    BOOL randomPerOpen = [[NSUserDefaults standardUserDefaults] boolForKey:@"kDDRandomPerOpen"];
    if (!randomPerOpen) {
        NSData *lastData = [[NSUserDefaults standardUserDefaults] objectForKey:@"kDDLastCommentUsers"];
        if (lastData) {
            return [NSKeyedUnarchiver unarchiveObjectWithData:lastData];
        }
    }
    
    NSMutableArray* newCommentUsers = [NSMutableArray array];
    BOOL keepOld = [[NSUserDefaults standardUserDefaults] boolForKey:@"kDDKeepOld"];
    
    if (keepOld && origCommentUsers.count > 0) {
        [newCommentUsers addObjectsFromArray:origCommentUsers];
    }
    
    NSInteger cmtCount = [[NSUserDefaults standardUserDefaults] integerForKey:@"kDDCmtCount"];
    if (cmtCount <= 0) {
        return newCommentUsers;
    }
    
    NSArray* friendList = dd_getFriendList();
    if (friendList.count == 0) return newCommentUsers;
    
    CContactMgr *contactMgr = [[objc_getClass("MMServiceCenter") defaultCenter] getService:objc_getClass("CContactMgr")];
    NSArray* defaultComments = @[@"点赞！", @"666", @"优秀", @"支持一下", @"棒棒的", @"不错哦", @"👍", @"👏"];
    
    for (int i = 0; i < cmtCount; i++) {
        NSUInteger friendIdx = arc4random() % friendList.count;
        NSString* userName = friendList[friendIdx];
        CContact* contact = [contactMgr getContactByName:userName];
        
        if (contact) {
            WCUserComment* comment = [[objc_getClass("WCUserComment") alloc] init];
            comment.username = userName;
            comment.nickname = [contact m_nsNickName];
            comment.type = 2;
            comment.createTime = (unsigned int)[[NSDate date] timeIntervalSince1970];
            
            NSUInteger cmtIdx = arc4random() % defaultComments.count;
            comment.content = defaultComments[cmtIdx];
            
            [newCommentUsers addObject:comment];
        }
    }
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:newCommentUsers];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"kDDLastCommentUsers"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    return newCommentUsers;
}

#pragma mark - Hooks
%hook MicroMessengerAppDelegate

- (bool)application:(id)application didFinishLaunchingWithOptions:(id)options {
    // 启动时清除缓存，重新获取好友列表
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"kDDFriendListCache"];
    dd_getFriendList();
    
    return %orig;
}

%end

%hook WCCommentDetailViewControllerFB

- (void)setDataItem:(WCDataItem*)dataItem {
    BOOL isEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"kDDOpenZan"];
    if (!isEnabled) {
        %orig;
        return;
    }
    
    NSString* curUserName = [dataItem username];
    NSString* myName = [objc_getClass("SettingUtil") getCurUsrName];
    
    if ([curUserName isEqualToString:myName]) {
        NSMutableArray* origLikeUsers = [dataItem likeUsers];
        NSMutableArray* origCommentUsers = [dataItem commentUsers];
        
        NSMutableArray* newLikeUsers = dd_fakeLike(origLikeUsers);
        NSMutableArray* newCommentUsers = dd_fakeComment(origCommentUsers);
        
        [dataItem setLikeUsers:newLikeUsers];
        [dataItem setLikeCount:(int)newLikeUsers.count];
        [dataItem setCommentUsers:newCommentUsers];
        [dataItem setCommentCount:(int)newCommentUsers.count];
    }
    
    %orig;
}

%end

%hook WCTimelineMgr

- (void)onDataUpdated:(id)arg1 andData:(NSMutableArray*)data andAdData:(id)arg3 withChangedTime:(unsigned int)arg4 {
    BOOL isEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:@"kDDOpenZan"];
    if (!isEnabled) {
        %orig;
        return;
    }
    
    NSString* myName = [objc_getClass("SettingUtil") getCurUsrName];
    
    for (WCDataItem* item in data) {
        if ([[item username] isEqualToString:myName]) {
            NSMutableArray* likeUsers = [item likeUsers];
            NSMutableArray* commentUsers = [item commentUsers];
            
            [item setLikeUsers:dd_fakeLike(likeUsers)];
            [item setLikeCount:(int)[[item likeUsers] count]];
            [item setCommentUsers:dd_fakeComment(commentUsers)];
            [item setCommentCount:(int)[[item commentUsers] count]];
        }
    }
    
    %orig;
}

%end

#pragma mark - 插件注册
%ctor {
    @autoreleasepool {
        // 注册到插件管理器
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] registerControllerWithTitle:@"DD集赞助手" 
                                                                               version:@"1.0.0" 
                                                                            controller:@"DDZanAssistantViewController"];
        }
        
        // 设置默认值
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (![defaults objectForKey:@"kDDZanCount"]) {
            [defaults setInteger:10 forKey:@"kDDZanCount"];
        }
        if (![defaults objectForKey:@"kDDCmtCount"]) {
            [defaults setInteger:5 forKey:@"kDDCmtCount"];
        }
        [defaults synchronize];
    }
}