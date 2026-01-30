
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 插件管理接口

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

#pragma mark - 微信相关接口声明

@interface CMessageWrap : NSObject
@property (retain, nonatomic) NSString *m_nsFromUsr;
@property (retain, nonatomic) NSString *m_nsToUsr;
@property (assign, nonatomic) unsigned int m_uiMessageType;
@property (retain, nonatomic) NSString *m_nsContent;
@property (retain, nonatomic) id m_oWCPayInfoItem;
@property (retain, nonatomic) NSString *m_nsMsgSource;
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
+ (id)sectionInfoHeader:(id)arg1 Footer:(id)arg2;
- (void)addCell:(id)arg1;
@end

@interface WCTableViewNormalCellManager : NSObject
+ (id)switchCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 on:(BOOL)arg4;
+ (id)normalCellForSel:(SEL)arg1 target:(id)arg2 title:(id)arg3 rightValue:(id)arg4 accessoryType:(long long)arg5;
+ (id)normalCellForTitle:(id)arg1 rightValue:(id)arg2;
@end

@interface ChatRoomInfoViewController : UIViewController
@end

@interface AddContactToChatRoomViewController : UIViewController
@end

@interface NewSettingViewController : UIViewController
- (void)reloadTableData;
@end

#pragma mark - 配置管理

@interface DDMessageFilterConfig : NSObject

+ (instancetype)sharedConfig;

@property (assign, nonatomic) BOOL messageFilterEnabled;
@property (strong, nonatomic) NSMutableDictionary<NSString *, NSNumber *> *chatIgnoreInfo;
@property (copy, nonatomic) NSString *curUsrName;

- (void)saveChatIgnoreNameListToLocalFile;
- (void)loadChatIgnoreNameListFromLocalFile;
- (BOOL)shouldIgnoreMessageFromUser:(NSString *)fromUser toUser:(NSString *)toUser messageType:(unsigned int)messageType;

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
        
        // 加载消息过滤开关
        _messageFilterEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:kDDMessageFilterEnabledKey];
        
        // 如果没有设置过，默认为NO
        if ([[NSUserDefaults standardUserDefaults] objectForKey:kDDMessageFilterEnabledKey] == nil) {
            _messageFilterEnabled = NO;
            [[NSUserDefaults standardUserDefaults] setBool:_messageFilterEnabled forKey:kDDMessageFilterEnabledKey];
        }
        
        // 加载忽略列表
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

- (BOOL)shouldIgnoreMessageFromUser:(NSString *)fromUser toUser:(NSString *)toUser messageType:(unsigned int)messageType {
    if (!fromUser) return NO;
    if (!self.messageFilterEnabled) {
        return NO;
    }
    
    // 检查是否是黑名单中的联系人
    BOOL shouldIgnore = self.chatIgnoreInfo[fromUser] ? [self.chatIgnoreInfo[fromUser] boolValue] : NO;
    
    // 如果是红包消息（type=49），特殊处理：屏蔽消息但保留红包入口
    if (shouldIgnore && messageType == 49) {
        // 红包消息需要特殊处理，返回NO让红包正常显示但不显示通知
        return NO;
    }
    
    return shouldIgnore;
}

@end

#pragma mark - Hook逻辑

%hook CMessageMgr

- (void)AsyncOnAddMsg:(NSString *)msg MsgWrap:(CMessageWrap *)wrap {
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    
    // 检查是否需要屏蔽此消息
    BOOL shouldIgnore = [config shouldIgnoreMessageFromUser:wrap.m_nsFromUsr 
                                                    toUser:wrap.m_nsToUsr 
                                               messageType:wrap.m_uiMessageType];
    
    if (shouldIgnore) {
        // 如果是红包消息，保留但设置消息来源为特殊标记
        if (wrap.m_uiMessageType == 49) {
            // 红包消息：保留但不显示通知
            wrap.m_nsMsgSource = @"DD_FILTERED_RED_ENVELOPE";
        } else {
            // 普通消息：直接返回，不处理
            return;
        }
    }
    
    %orig;
}

- (id)GetMsgByCreateTime:(id)arg1 FromID:(unsigned int)arg2 FromCreateTime:(unsigned int)arg3 Limit:(int)arg4 LeftCount:(unsigned int *)arg5 FromSequence:(unsigned int)arg6 {
    id result = %orig;
    
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    if (config.messageFilterEnabled && config.chatIgnoreInfo[arg1] && [config.chatIgnoreInfo[arg1] boolValue]) {
        // 返回空数组，表示没有消息
        return [NSMutableArray array];
    }
    
    return result;
}

- (void)AddLocalMsg:(id)arg1 MsgWrap:(CMessageWrap *)arg2 fixTime:(BOOL)arg3 NewMsgArriveNotify:(BOOL)arg4 {
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    
    BOOL shouldIgnore = [config shouldIgnoreMessageFromUser:arg2.m_nsFromUsr 
                                                    toUser:arg1 
                                               messageType:arg2.m_uiMessageType];
    
    if (shouldIgnore) {
        // 如果消息被屏蔽，检查是否是红包消息
        if (arg2.m_uiMessageType == 49) {
            // 红包消息：仍然添加但不显示通知
            arg2.m_nsMsgSource = @"DD_FILTERED_RED_ENVELOPE";
            // 调用原始方法，但设置不通知
            %orig(arg1, arg2, fixTime, NO);
        } else {
            // 普通消息：直接返回，不添加
            return;
        }
    } else {
        %orig(arg1, arg2, fixTime, NewMsgArriveNotify);
    }
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
                    
                    BOOL shouldIgnore = [config shouldIgnoreMessageFromUser:wrap.m_nsFromUsr 
                                                                    toUser:wrap.m_nsToUsr 
                                                               messageType:wrap.m_uiMessageType];
                    
                    if (!shouldIgnore) {
                        [filteredList addObject:msg];
                    } else if (wrap.m_uiMessageType == 49) {
                        // 红包消息特殊处理：保留但不显示推送
                        wrap.m_nsMsgSource = @"DD_FILTERED_RED_ENVELOPE";
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
    
    // 获取合适的section，尝试多个section
    WCTableViewSectionManager *sectionMgr = nil;
    for (int i = 0; i < 5; i++) {
        @try {
            sectionMgr = [tableViewInfo getSectionAt:i];
            if (sectionMgr) break;
        } @catch (NSException *exception) {
            continue;
        }
    }
    
    if (!sectionMgr) return;
    
    BOOL isIgnored = config.chatIgnoreInfo[usrName] ? [config.chatIgnoreInfo[usrName] boolValue] : NO;
    WCTableViewNormalCellManager *ignoreCell = [objc_getClass("WCTableViewNormalCellManager") 
                                               switchCellForSel:@selector(dd_handleIgnoreChatRoom:) 
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
    
    // 获取合适的section，尝试多个section
    WCTableViewSectionManager *sectionMgr = nil;
    for (int i = 0; i < 5; i++) {
        @try {
            sectionMgr = [tableViewInfo getSectionAt:i];
            if (sectionMgr) break;
        } @catch (NSException *exception) {
            continue;
        }
    }
    
    if (!sectionMgr) return;
    
    BOOL isIgnored = config.chatIgnoreInfo[usrName] ? [config.chatIgnoreInfo[usrName] boolValue] : NO;
    WCTableViewNormalCellManager *ignoreCell = [objc_getClass("WCTableViewNormalCellManager") 
                                               switchCellForSel:@selector(dd_handleIgnoreChatRoom:) 
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

%hook NewSettingViewController

- (void)reloadTableData {
    %orig;
    
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    
    WCTableViewManager *tableViewMgr = MSHookIvar<id>(self, "m_tableViewMgr");
    if (!tableViewMgr) return;
    
    WCTableViewSectionManager *sectionMgr = [objc_getClass("WCTableViewSectionManager") sectionInfoDefaut];
    
    NSString *rightValue = config.messageFilterEnabled ? @"已开启" : @"已关闭";
    WCTableViewNormalCellManager *filterCell = [objc_getClass("WCTableViewNormalCellManager") 
                                               normalCellForSel:@selector(dd_openFilterSettings) 
                                               target:self 
                                               title:@"DD消息屏蔽" 
                                               rightValue:rightValue 
                                               accessoryType:1];
    [sectionMgr addCell:filterCell];
    
    [tableViewMgr insertSection:sectionMgr At:0];
    
    MMTableView *tableView = [tableViewMgr getTableView];
    [tableView reloadData];
}

%end

%hook NSObject

%new
- (void)dd_handleIgnoreChatRoom:(UISwitch *)sender {
    DDMessageFilterConfig *config = [DDMessageFilterConfig sharedConfig];
    
    if (!config.messageFilterEnabled) {
        sender.on = NO;
        // 如果消息屏蔽功能未开启，提示用户
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"提示" 
                                                                       message:@"请先在插件管理中开启DD消息屏蔽功能" 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil]];
        [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    NSString *usrName = config.curUsrName;
    if (!usrName) {
        sender.on = NO;
        return;
    }
    
    if (sender.on) {
        config.chatIgnoreInfo[usrName] = @(sender.on);
    } else {
        [config.chatIgnoreInfo removeObjectForKey:usrName];
    }
    [config saveChatIgnoreNameListToLocalFile];
}

%new
- (void)dd_openFilterSettings {
    // 创建一个简单的设置页面
    UIViewController *settingsVC = [[UIViewController alloc] init];
    settingsVC.title = @"DD消息屏蔽设置";
    settingsVC.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // 创建开关控件
    UISwitch *filterSwitch = [[UISwitch alloc] init];
    filterSwitch.onTintColor = [UIColor systemBlueColor];
    filterSwitch.on = [DDMessageFilterConfig sharedConfig].messageFilterEnabled;
    [filterSwitch addTarget:self action:@selector(dd_filterSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    // 创建标签
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 100, 200, 40)];
    titleLabel.text = @"启用消息屏蔽";
    titleLabel.font = [UIFont systemFontOfSize:16];
    
    UILabel *descLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 150, 300, 80)];
    descLabel.text = @"开启后，可以在群聊或联系人设置中屏蔽指定联系人的消息。\n\n注意：红包消息不会被完全屏蔽，但不会显示通知。";
    descLabel.font = [UIFont systemFontOfSize:14];
    descLabel.textColor = [UIColor secondaryLabelColor];
    descLabel.numberOfLines = 0;
    
    // 布局
    filterSwitch.frame = CGRectMake(settingsVC.view.bounds.size.width - 70, 105, 50, 30);
    
    [settingsVC.view addSubview:titleLabel];
    [settingsVC.view addSubview:descLabel];
    [settingsVC.view addSubview:filterSwitch];
    
    // 获取当前导航控制器并推送
    UINavigationController *navController = nil;
    UIResponder *responder = self;
    while (responder && ![responder isKindOfClass:[UIViewController class]]) {
        responder = [responder nextResponder];
    }
    
    UIViewController *currentVC = (UIViewController *)responder;
    if ([currentVC isKindOfClass:[UINavigationController class]]) {
        navController = (UINavigationController *)currentVC;
    } else if (currentVC.navigationController) {
        navController = currentVC.navigationController;
    }
    
    if (navController) {
        [navController pushViewController:settingsVC animated:YES];
    } else {
        // 如果找不到导航控制器，以模态方式显示
        UINavigationController *modalNav = [[UINavigationController alloc] initWithRootViewController:settingsVC];
        settingsVC.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"关闭" 
                                                                                       style:UIBarButtonItemStylePlain 
                                                                                      target:self 
                                                                                      action:@selector(dd_dismissSettings)];
        [currentVC presentViewController:modalNav animated:YES completion:nil];
    }
}

%new
- (void)dd_filterSwitchChanged:(UISwitch *)sender {
    [DDMessageFilterConfig sharedConfig].messageFilterEnabled = sender.isOn;
}

%new
- (void)dd_dismissSettings {
    UIViewController *currentVC = nil;
    UIResponder *responder = self;
    while (responder && ![responder isKindOfClass:[UIViewController class]]) {
        responder = [responder nextResponder];
    }
    currentVC = (UIViewController *)responder;
    
    [currentVC dismissViewControllerAnimated:YES completion:nil];
}

%end

#pragma mark - 插件注册

%ctor {
    @autoreleasepool {
        // 初始化配置
        [DDMessageFilterConfig sharedConfig];
        
        // 注册插件到插件管理器
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD消息屏蔽" 
                version:@"1.0.0" 
                controller:@"DDMessageFilterSettingsViewController"];
        }
    }
}