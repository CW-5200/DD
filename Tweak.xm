#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 插件管理接口

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
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
    _messageFilterEnabled = messageFilterEnabled;
    [[NSUserDefaults standardUserDefaults] setBool:messageFilterEnabled forKey:kDDMessageFilterEnabledKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
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
    [DDMessageFilterConfig sharedConfig].messageFilterEnabled = sender.isOn;
}

@end

#pragma mark - Hook相关的接口声明

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

#pragma mark - 统一的过滤函数

static NSMutableArray *filterMessageWrapArray(NSMutableArray *msgList) {
    if (!msgList) return [NSMutableArray array];
    
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    if (!config.messageFilterEnabled) {
        return msgList;
    }
    
    NSMutableArray *filteredList = [NSMutableArray array];
    
    for (id msg in msgList) {
        if ([msg isKindOfClass:objc_getClass("CMessageWrap")]) {
            CMessageWrap *wrap = (CMessageWrap *)msg;
            
            BOOL shouldIgnore = [config shouldIgnoreMessageFromUser:wrap.m_nsFromUsr 
                                                             toUser:wrap.m_nsToUsr];
            
            if (!shouldIgnore) {
                [filteredList addObject:msg];
            }
        } else {
            [filteredList addObject:msg];
        }
    }
    
    return filteredList;
}

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
    
    if (!config.messageFilterEnabled) {
        return result;
    }
    
    if (config.chatIgnoreInfo[arg1] && [config.chatIgnoreInfo[arg1] boolValue]) {
        return [NSMutableArray array];
    }
    
    if ([result isKindOfClass:[NSMutableArray class]]) {
        return filterMessageWrapArray(result);
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
        @try {
            NSMutableArray *msgList = [self valueForKey:@"m_arrMsgList"];
            
            if (msgList && [msgList isKindOfClass:[NSMutableArray class]]) {
                NSMutableArray *filteredList = filterMessageWrapArray(msgList);
                
                if (filteredList.count == 0) {
                    [self setValue:[NSMutableArray array] forKey:@"m_arrMsgList"];
                    return YES;
                }
                
                [self setValue:filteredList forKey:@"m_arrMsgList"];
            }
        } @catch (NSException *exception) {
            // 保持静默，不记录日志
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

- (void)chatFilter_handleIgnoreChatRoom:(UISwitch *)sender {
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    
    if (!config.messageFilterEnabled) {
        sender.on = NO;
        return;
    }
    
    NSString *usrName = config.curUsrName;
    
    if (sender.on) {
        config.chatIgnoreInfo[usrName] = @(sender.on);
    } else {
        [config.chatIgnoreInfo removeObjectForKey:usrName];
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