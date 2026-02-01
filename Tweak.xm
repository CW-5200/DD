#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 插件管理接口

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

#pragma mark - CContactMgr 接口声明

@interface CContactMgr : NSObject
+ (instancetype)sharedInstance;
- (id)getContactByName:(id)arg1;
- (BOOL)ChangeNotifyStatus:(id)arg1 withStatus:(BOOL)arg2 sync:(BOOL)arg3;
- (BOOL)ChangeNotifyStatusForChatRoom:(id)arg1 withStatus:(BOOL)arg2 sync:(BOOL)arg3;
@end

#pragma mark - 配置管理

@interface DDMessageFilterConfig : NSObject

+ (instancetype)sharedConfig;
@property (assign, nonatomic) BOOL messageFilterEnabled;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSNumber *> *chatIgnoreInfo;
@property (copy, nonatomic) NSString *curUsrName;

- (void)saveChatIgnoreNameListToLocalFile;
- (void)loadChatIgnoreNameListFromLocalFile;
- (BOOL)shouldIgnoreMessageFromUser:(NSString *)fromUser toUser:(NSString *)toUser;
- (void)syncDoNotDisturbForAllIgnoredContacts;

@end

static NSString * const kDDMessageFilterEnabledKey = @"DDMessageFilterEnabled";
static NSString * const kDDChatFilterIgnoreListKey = @"DDChatFilter_IgnoreList";

@implementation DDMessageFilterConfig

+ (instancetype)sharedConfig {
    static DDMessageFilterConfig *config = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        config = [DDMessageFilterConfig new];
    });
    return config;
}

- (instancetype)init {
    if (self = [super init]) {
        _chatIgnoreInfo = [NSMutableDictionary dictionary];
        
        _messageFilterEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kDDMessageFilterEnabledKey];
        
        if ([[NSUserDefaults standardUserDefaults] objectForKey:kDDMessageFilterEnabledKey] == nil) {
            _messageFilterEnabled = NO;
            [[NSUserDefaults standardUserDefaults] setBool:_messageFilterEnabled forKey:kDDMessageFilterEnabledKey];
        }
        
        [self loadChatIgnoreNameListFromLocalFile];
    }
    return self;
}

- (void)setMessageFilterEnabled:(BOOL)messageFilterEnabled {
    BOOL oldValue = _messageFilterEnabled;
    _messageFilterEnabled = messageFilterEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:messageFilterEnabled forKey:kDDMessageFilterEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if (messageFilterEnabled && !oldValue) {
        [self syncDoNotDisturbForAllIgnoredContacts];
    }
}

- (void)saveChatIgnoreNameListToLocalFile {
    [[NSUserDefaults standardUserDefaults] setObject:self.chatIgnoreInfo forKey:kDDChatFilterIgnoreListKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)loadChatIgnoreNameListFromLocalFile {
    NSDictionary *saved = [[NSUserDefaults standardUserDefaults] objectForKey:kDDChatFilterIgnoreListKey];
    if (saved) {
        self.chatIgnoreInfo = [saved mutableCopy];
    }
}

- (BOOL)shouldIgnoreMessageFromUser:(NSString *)fromUser toUser:(NSString *)toUser {
    if (!fromUser) return NO;
    if (!self.messageFilterEnabled) {
        return NO;
    }
    return self.chatIgnoreInfo[fromUser] ? [self.chatIgnoreInfo[fromUser] boolValue] : NO;
}

- (void)syncDoNotDisturbForAllIgnoredContacts {
    if (!self.messageFilterEnabled) {
        return;
    }
    
    for (NSString *contactName in self.chatIgnoreInfo.allKeys) {
        if ([self.chatIgnoreInfo[contactName] boolValue]) {
            [self setDoNotDisturbForContact:contactName enable:YES];
        }
    }
}

- (BOOL)setDoNotDisturbForContact:(NSString *)contactName enable:(BOOL)enable {
    Class CContactMgrClass = objc_getClass("CContactMgr");
    if (!CContactMgrClass || ![CContactMgrClass respondsToSelector:@selector(sharedInstance)]) {
        return NO;
    }
    
    CContactMgr *contactMgr = (CContactMgr *)[CContactMgrClass sharedInstance];
    id contact = nil;
    
    if ([contactMgr respondsToSelector:@selector(getContactByName:)]) {
        contact = [contactMgr getContactByName:contactName];
    }
    
    if (!contact) {
        return NO;
    }
    
    BOOL isChatRoom = NO;
    // 使用运行时方法检查是否为群聊
    if ([contact respondsToSelector:@selector(isChatRoom)]) {
        // 使用performSelector来避免编译错误
        isChatRoom = ((BOOL (*)(id, SEL))[contact methodForSelector:@selector(isChatRoom)])(contact, @selector(isChatRoom));
    }
    
    BOOL success = NO;
    
    if (isChatRoom) {
        if ([contactMgr respondsToSelector:@selector(ChangeNotifyStatusForChatRoom:withStatus:sync:)]) {
            success = [contactMgr ChangeNotifyStatusForChatRoom:contact withStatus:enable sync:YES];
        }
    } else {
        if ([contactMgr respondsToSelector:@selector(ChangeNotifyStatus:withStatus:sync:)]) {
            success = [contactMgr ChangeNotifyStatus:contact withStatus:enable sync:YES];
        }
    }
    
    return success;
}

@end

#pragma mark - 设置界面

@interface DDMessageFilterSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) UITableView *tableView;

@end

@implementation DDMessageFilterSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD消息屏蔽";
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
    NSString *cellIdentifier = @"DDMessageFilterCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    
    cell.textLabel.text = @"启用消息屏蔽";
    
    UISwitch *switchView = [[UISwitch alloc] init];
    switchView.onTintColor = [UIColor systemBlueColor];
    switchView.on = [DDMessageFilterConfig sharedConfig].messageFilterEnabled;
    [switchView addTarget:self action:@selector(messageFilterSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    cell.accessoryView = switchView;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 20.0;
}

- (void)messageFilterSwitchChanged:(UISwitch *)sender {
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    config.messageFilterEnabled = sender.isOn;
}

@end

#pragma mark - Hook相关接口声明

@interface CMessageWrap : NSObject
@property (retain, nonatomic) NSString *m_nsFromUsr;
@property (retain, nonatomic) NSString *m_nsToUsr;
@end

@interface CMessageMgr : NSObject
- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap;
- (id)GetMsgByCreateTime:(id)arg1 FromID:(unsigned int)arg2 FromCreateTime:(unsigned int)arg3 Limit:(int)arg4 LeftCount:(unsigned int *)arg5 FromSequence:(unsigned int)arg6;
- (void)AddLocalMsg:(id)arg1 MsgWrap:(id)arg2 fixTime:(BOOL)arg3 NewMsgArriveNotify:(BOOL)arg4;
@end

@interface SyncCmdHandler : NSObject
- (BOOL)BatchAddMsg:(BOOL)arg1 ShowPush:(BOOL)arg2;
@end

@interface BaseMsgContentViewController : UIViewController
- (id)GetContact;
@end

@interface CContact : NSObject
@property (retain, nonatomic) NSString *m_nsUsrName;
- (BOOL)isChatRoom;
@end

@interface WCTableViewManager : NSObject
- (id)getTableView;
- (id)getSectionAt:(unsigned long long)arg1;
@end

@interface MMTableViewInfo : WCTableViewManager
@end

@interface WCTableViewSectionManager : NSObject
+ (id)sectionInfoDefaut;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewNormalCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
@end

@interface ChatRoomInfoViewController : UIViewController
@end

@interface AddContactToChatRoomViewController : UIViewController
@end

#pragma mark - Hook逻辑

%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap {
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    if (config.messageFilterEnabled && [config shouldIgnoreMessageFromUser:wrap.m_nsFromUsr toUser:wrap.m_nsToUsr]) {
        return;
    }
    %orig;
}

- (id)GetMsgByCreateTime:(id)arg1 FromID:(unsigned int)arg2 FromCreateTime:(unsigned int)arg3 Limit:(int)arg4 LeftCount:(unsigned int *)arg5 FromSequence:(unsigned int)arg6 {
    id result = %orig;
    
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    if (config.messageFilterEnabled && config.chatIgnoreInfo[arg1] && [config.chatIgnoreInfo[arg1] boolValue]) {
        return [NSMutableArray array];
    }
    
    return result;
}

- (void)AddLocalMsg:(id)arg1 MsgWrap:(CMessageWrap *)arg2 fixTime:(BOOL)arg3 NewMsgArriveNotify:(BOOL)arg4 {
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    if (config.messageFilterEnabled && [config shouldIgnoreMessageFromUser:arg2.m_nsFromUsr toUser:arg1]) {
        return;
    }
    %orig;
}

%end

%hook SyncCmdHandler

- (BOOL)BatchAddMsg:(BOOL)arg1 ShowPush:(BOOL)arg2 {
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    
    if (config.messageFilterEnabled) {
        NSMutableArray *msgList = [self valueForKey:@"m_arrMsgList"];
        
        if (msgList && [msgList isKindOfClass:[NSMutableArray class]]) {
            NSMutableArray *filteredList = [NSMutableArray array];
            for (id msg in msgList) {
                if ([msg isKindOfClass:objc_getClass("CMessageWrap")]) {
                    CMessageWrap *wrap = (CMessageWrap *)msg;
                    if (![config shouldIgnoreMessageFromUser:wrap.m_nsFromUsr toUser:wrap.m_nsToUsr]) {
                        [filteredList addObject:msg];
                    }
                } else {
                    [filteredList addObject:msg];
                }
            }
            [self setValue:filteredList forKey:@"m_arrMsgList"];
        }
    }
    return %orig;
}

%end

%hook BaseMsgContentViewController

- (void)viewDidAppear:(BOOL)arg1 {
    %orig;
    
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    if (config.messageFilterEnabled) {
        CContact *contact = [self GetContact];
        if (contact && contact.m_nsUsrName) {
            config.curUsrName = contact.m_nsUsrName;
        }
    }
}

%end

%hook ChatRoomInfoViewController

- (void)reloadTableData {
    %orig;
    
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    if (!config.messageFilterEnabled) {
        return;
    }
    
    NSString *usrName = config.curUsrName;
    if (!usrName) return;
    
    id tableViewInfo = [self valueForKey:@"m_tableViewInfo"];
    if (![tableViewInfo respondsToSelector:@selector(getSectionAt:)]) {
        return;
    }
    
    WCTableViewSectionManager *sectionMgr = [tableViewInfo getSectionAt:3];
    
    BOOL isIgnored = config.chatIgnoreInfo[usrName] ? [config.chatIgnoreInfo[usrName] boolValue] : NO;
    WCTableViewNormalCellManager *ignoreCell = [objc_getClass("WCTableViewNormalCellManager") 
                                               switchCellForSel:@selector(chatFilter_handleIgnoreChatRoom:) 
                                               target:self 
                                               title:@"屏蔽消息" 
                                               on:isIgnored];
    [sectionMgr addCell:ignoreCell];
    
    if ([tableViewInfo respondsToSelector:@selector(getTableView)]) {
        UITableView *tableView = [tableViewInfo getTableView];
        [tableView reloadData];
    }
}

%end

%hook AddContactToChatRoomViewController

- (void)reloadTableData {
    %orig;
    
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    if (!config.messageFilterEnabled) {
        return;
    }
    
    NSString *usrName = config.curUsrName;
    if (!usrName) return;
    
    id tableViewInfo = [self valueForKey:@"m_tableViewInfo"];
    if (![tableViewInfo respondsToSelector:@selector(getSectionAt:)]) {
        return;
    }
    
    WCTableViewSectionManager *sectionMgr = [tableViewInfo getSectionAt:2];
    
    BOOL isIgnored = config.chatIgnoreInfo[usrName] ? [config.chatIgnoreInfo[usrName] boolValue] : NO;
    WCTableViewNormalCellManager *ignoreCell = [objc_getClass("WCTableViewNormalCellManager") 
                                               switchCellForSel:@selector(chatFilter_handleIgnoreChatRoom:) 
                                               target:self 
                                               title:@"屏蔽消息" 
                                               on:isIgnored];
    [sectionMgr addCell:ignoreCell];
    
    if ([tableViewInfo respondsToSelector:@selector(getTableView)]) {
        UITableView *tableView = [tableViewInfo getTableView];
        [tableView reloadData];
    }
}

%end

%hook NSObject

%new
- (void)chatFilter_handleIgnoreChatRoom:(UISwitch *)sender {
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    
    if (!config.messageFilterEnabled) {
        sender.on = NO;
        return;
    }
    
    NSString *usrName = config.curUsrName;
    if (!usrName) return;
    
    if (sender.on) {
        config.chatIgnoreInfo[usrName] = @(sender.on);
        [config setDoNotDisturbForContact:usrName enable:YES];
    } else {
        [config.chatIgnoreInfo removeObjectForKey:usrName];
        [config setDoNotDisturbForContact:usrName enable:NO];
    }
    [config saveChatIgnoreNameListToLocalFile];
}

%end

#pragma mark - 插件注册

%ctor {
    @autoreleasepool {
        [DDMessageFilterConfig sharedConfig];
        
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD消息屏蔽" 
                version:@"1.0.0" 
                controller:@"DDMessageFilterSettingsViewController"];
        }
    }
}