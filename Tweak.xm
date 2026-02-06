#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - 类声明

@interface WCPluginsMgr : NSObject
+ (instancetype)sharedInstance;
- (void)registerControllerWithTitle:(NSString *)title version:(NSString *)version controller:(NSString *)controller;
@end

@interface CContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@property(retain, nonatomic) NSString *m_nsNickName;
@property(retain, nonatomic) NSString *m_nsRemark;
@property(retain, nonatomic) NSString *m_nsHeadImgUrl;
@property(nonatomic) unsigned int m_uiSex;
- (BOOL)isBrandContact;
@end

@interface CContactMgr : NSObject
- (NSArray *)getContactList:(unsigned int)arg1 contactType:(unsigned int)arg2;
@end

@interface MMContext : NSObject
@property (readonly, nonatomic) NSString *userName;
+ (id)activeUserContext;
- (id)getService:(Class)cls;
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
@property(retain, nonatomic) NSString *username;
@property(retain, nonatomic) NSMutableArray *commentUsers;
@property(nonatomic) int commentCount;
@property(nonatomic) BOOL likeFlag;
@property(nonatomic) unsigned int createtime;
@end

@interface WCTimelineMgr : NSObject
- (void)modifyDataItem:(WCDataItem *)arg1 notify:(BOOL)arg2;
@end

#pragma mark - 配置管理

@interface DDLikeHelperConfig : NSObject

@property(class, nonatomic, assign) BOOL likeCommentEnable;
@property(class, nonatomic, strong) NSNumber *likeCount;
@property(class, nonatomic, strong) NSNumber *commentCount;
@property(class, nonatomic, strong) NSString *comments;

@end

static NSString * const kDDLikeCommentEnableKey = @"DDLikeCommentEnable";
static NSString * const kDDLikeCountKey = @"DDLikeCount";
static NSString * const kDDCommentCountKey = @"DDCommentCount";
static NSString * const kDDCommentsKey = @"DDComments";

@implementation DDLikeHelperConfig

+ (BOOL)likeCommentEnable {
    return [[NSUserDefaults standardUserDefaults] boolForKey:kDDLikeCommentEnableKey];
}

+ (void)setLikeCommentEnable:(BOOL)value {
    [[NSUserDefaults standardUserDefaults] setBool:value forKey:kDDLikeCommentEnableKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSNumber *)likeCount {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kDDLikeCountKey];
}

+ (void)setLikeCount:(NSNumber *)value {
    if (value) {
        [[NSUserDefaults standardUserDefaults] setObject:value forKey:kDDLikeCountKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDDLikeCountKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSNumber *)commentCount {
    return [[NSUserDefaults standardUserDefaults] objectForKey:kDDCommentCountKey];
}

+ (void)setCommentCount:(NSNumber *)value {
    if (value) {
        [[NSUserDefaults standardUserDefaults] setObject:value forKey:kDDCommentCountKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDDCommentCountKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)comments {
    NSString *value = [[NSUserDefaults standardUserDefaults] stringForKey:kDDCommentsKey];
    return value ? value : @"赞-👍";
}

+ (void)setComments:(NSString *)value {
    if (value && value.length > 0) {
        [[NSUserDefaults standardUserDefaults] setObject:value forKey:kDDCommentsKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kDDCommentsKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

@end

#pragma mark - 核心功能

@interface DDLikeHelper : NSObject

+ (instancetype)shared;
+ (NSArray<CContact *> *)allFriends;
+ (NSMutableArray<WCUserComment *> *)commentUsers;
+ (NSMutableArray<WCUserComment *> *)commentWith:(WCDataItem *)origItem;

@end

@implementation DDLikeHelper

+ (instancetype)shared {
    static DDLikeHelper *helper = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        helper = [[DDLikeHelper alloc] init];
    });
    return helper;
}

+ (NSArray<CContact *> *)allFriends {
    static NSArray *allFriends = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableArray *friends = [NSMutableArray array];
        
        MMContext *context = [objc_getClass("MMContext") activeUserContext];
        CContactMgr *contactMgr = [context getService:objc_getClass("CContactMgr")];
        
        NSArray *contacts = [contactMgr getContactList:1 contactType:0];
        for (CContact *contact in contacts) {
            if (![contact isBrandContact] && contact.m_uiSex != 0) {
                [friends addObject:contact];
            }
        }
        allFriends = [friends copy];
    });
    return allFriends;
}

+ (NSMutableArray<WCUserComment *> *)commentUsers {
    NSNumber *likeCount = DDLikeHelperConfig.likeCount;
    if (!likeCount) {
        return [NSMutableArray array];
    }
    
    NSMutableArray *likeCommentUsers = [NSMutableArray array];
    [[self allFriends] enumerateObjectsUsingBlock:^(CContact *curAddContact, NSUInteger idx, BOOL *stop) {
        if (idx >= likeCount.integerValue) {
            *stop = YES;
            return;
        }
        WCUserComment *likeComment = [[objc_getClass("WCUserComment") alloc] init];
        likeComment.username = curAddContact.m_nsUsrName;
        likeComment.nickname = curAddContact.m_nsNickName;
        likeComment.type = 2;
        likeComment.commentID = [NSString stringWithFormat:@"%lu", (unsigned long)idx];
        likeComment.createTime = [[NSDate date] timeIntervalSince1970];
        [likeCommentUsers addObject:likeComment];
    }];
    return likeCommentUsers;
}

+ (NSMutableArray<WCUserComment *> *)commentWith:(WCDataItem *)origItem {
    NSNumber *commentCount = DDLikeHelperConfig.commentCount;
    if (!commentCount) {
        return origItem.commentUsers;
    }
    
    NSMutableArray *origComment = origItem.commentUsers;
    
    if (origComment.count >= commentCount.intValue) {
        return origComment;
    }
    
    NSMutableArray *newComments = [NSMutableArray array];
    [newComments addObjectsFromArray:origComment];
    
    NSArray<NSString *> *defaultComments = [DDLikeHelperConfig.comments componentsSeparatedByString:@"-"];
    
    int timeInterval = [NSDate date].timeIntervalSince1970 - origItem.createtime;
    
    [[self allFriends] enumerateObjectsUsingBlock:^(CContact *curAddContact, NSUInteger idx, BOOL *stop) {
        if (idx + origComment.count >= commentCount.intValue) {
            *stop = YES;
            return;
        }
        
        WCUserComment *newComment = [[objc_getClass("WCUserComment") alloc] init];
        newComment.username = curAddContact.m_nsUsrName;
        newComment.nickname = curAddContact.m_nsNickName;
        newComment.type = 2;
        newComment.commentID = [NSString stringWithFormat:@"%lu", (unsigned long)idx + origComment.count];
        newComment.createTime = [NSDate date].timeIntervalSince1970 - arc4random() % timeInterval;
        newComment.content = defaultComments[arc4random() % defaultComments.count];
        [newComments addObject:newComment];
    }];
    
    [newComments sortUsingComparator:^NSComparisonResult(WCUserComment *obj1, WCUserComment *obj2) {
        return obj1.createTime < obj2.createTime ? NSOrderedAscending : NSOrderedDescending;
    }];
    
    return newComments;
}

@end

#pragma mark - 设置界面

@interface DDLikeHelperSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UITextField *likeCountField;
@property (nonatomic, strong) UITextField *commentCountField;
@property (nonatomic, strong) UITextField *commentsField;

@end

@implementation DDLikeHelperSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"DD集赞助手";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    self.tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleInsetGrouped];
    self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (!DDLikeHelperConfig.likeCommentEnable) {
        return 1;
    }
    return 4;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) {
        return [self createSwitchCell];
    } else if (indexPath.row == 1) {
        return [self createLikeCountInputCell];
    } else if (indexPath.row == 2) {
        return [self createCommentCountInputCell];
    } else {
        return [self createCommentsInputCell];
    }
}

- (UITableViewCell *)createSwitchCell {
    NSString *cellIdentifier = @"DDLikeHelperSwitchCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    
    cell.textLabel.text = @"启用集赞助手";
    
    UISwitch *switchView = [[UISwitch alloc] init];
    switchView.onTintColor = [UIColor systemBlueColor];
    switchView.on = DDLikeHelperConfig.likeCommentEnable;
    [switchView addTarget:self action:@selector(likeCommentEnableChanged:) forControlEvents:UIControlEventValueChanged];
    
    cell.accessoryView = switchView;
    return cell;
}

- (UITableViewCell *)createLikeCountInputCell {
    NSString *cellIdentifier = @"DDLikeCountInputCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(20, 10, self.view.frame.size.width - 140, 40)];
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.placeholder = @"输入点赞数（如：5）";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.delegate = self;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.backgroundColor = [UIColor tertiarySystemBackgroundColor];
        textField.textColor = [UIColor labelColor];
        [cell.contentView addSubview:textField];
        self.likeCountField = textField;
        
        UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
        confirmButton.frame = CGRectMake(self.view.frame.size.width - 110, 10, 80, 40);
        [confirmButton setTitle:@"确认" forState:UIControlStateNormal];
        confirmButton.tintColor = [UIColor systemBlueColor];
        [confirmButton addTarget:self action:@selector(likeCountConfirmTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        [cell.contentView addSubview:confirmButton];
    }
    
    NSNumber *likeCount = DDLikeHelperConfig.likeCount;
    self.likeCountField.text = likeCount ? likeCount.stringValue : @"";
    
    return cell;
}

- (UITableViewCell *)createCommentCountInputCell {
    NSString *cellIdentifier = @"DDCommentCountInputCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(20, 10, self.view.frame.size.width - 140, 40)];
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.placeholder = @"输入评论数（如：5）";
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.delegate = self;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.backgroundColor = [UIColor tertiarySystemBackgroundColor];
        textField.textColor = [UIColor labelColor];
        [cell.contentView addSubview:textField];
        self.commentCountField = textField;
        
        UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
        confirmButton.frame = CGRectMake(self.view.frame.size.width - 110, 10, 80, 40);
        [confirmButton setTitle:@"确认" forState:UIControlStateNormal];
        confirmButton.tintColor = [UIColor systemBlueColor];
        [confirmButton addTarget:self action:@selector(commentCountConfirmTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        [cell.contentView addSubview:confirmButton];
    }
    
    NSNumber *commentCount = DDLikeHelperConfig.commentCount;
    self.commentCountField.text = commentCount ? commentCount.stringValue : @"";
    
    return cell;
}

- (UITableViewCell *)createCommentsInputCell {
    NSString *cellIdentifier = @"DDCommentsInputCell";
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        
        UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(20, 10, self.view.frame.size.width - 140, 40)];
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.placeholder = @"评论内容用“-”分隔";
        textField.keyboardType = UIKeyboardTypeDefault;
        textField.delegate = self;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.backgroundColor = [UIColor tertiarySystemBackgroundColor];
        textField.textColor = [UIColor labelColor];
        [cell.contentView addSubview:textField];
        self.commentsField = textField;
        
        UIButton *confirmButton = [UIButton buttonWithType:UIButtonTypeSystem];
        confirmButton.frame = CGRectMake(self.view.frame.size.width - 110, 10, 80, 40);
        [confirmButton setTitle:@"确认" forState:UIControlStateNormal];
        confirmButton.tintColor = [UIColor systemBlueColor];
        [confirmButton addTarget:self action:@selector(commentsConfirmTapped:) forControlEvents:UIControlEventTouchUpInside];
        
        [cell.contentView addSubview:confirmButton];
    }
    
    NSString *comments = DDLikeHelperConfig.comments;
    self.commentsField.text = comments;
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row == 0) return 50.0;
    return 60.0;
}

- (void)likeCommentEnableChanged:(UISwitch *)sender {
    DDLikeHelperConfig.likeCommentEnable = sender.isOn;
    [self.tableView reloadData];
}

- (void)likeCountConfirmTapped:(UIButton *)sender {
    if (_likeCountField) {
        [_likeCountField resignFirstResponder];
        [self saveLikeCountValue];
    }
}

- (void)commentCountConfirmTapped:(UIButton *)sender {
    if (_commentCountField) {
        [_commentCountField resignFirstResponder];
        [self saveCommentCountValue];
    }
}

- (void)commentsConfirmTapped:(UIButton *)sender {
    if (_commentsField) {
        [_commentsField resignFirstResponder];
        [self saveCommentsValue];
    }
}

- (void)saveLikeCountValue {
    NSString *text = _likeCountField.text;
    if (text && text.length > 0) {
        NSInteger likeCount = [text integerValue];
        if (likeCount > 0) {
            DDLikeHelperConfig.likeCount = @(likeCount);
        } else {
            DDLikeHelperConfig.likeCount = nil;
            _likeCountField.text = @"";
        }
    } else {
        DDLikeHelperConfig.likeCount = nil;
    }
}

- (void)saveCommentCountValue {
    NSString *text = _commentCountField.text;
    if (text && text.length > 0) {
        NSInteger commentCount = [text integerValue];
        if (commentCount > 0) {
            DDLikeHelperConfig.commentCount = @(commentCount);
        } else {
            DDLikeHelperConfig.commentCount = nil;
            _commentCountField.text = @"";
        }
    } else {
        DDLikeHelperConfig.commentCount = nil;
    }
}

- (void)saveCommentsValue {
    NSString *text = _commentsField.text;
    if (text && text.length > 0) {
        DDLikeHelperConfig.comments = text;
    } else {
        DDLikeHelperConfig.comments = nil;
        _commentsField.text = @"赞-👍";
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField == _likeCountField) {
        [self saveLikeCountValue];
    } else if (textField == _commentCountField) {
        [self saveCommentCountValue];
    } else if (textField == _commentsField) {
        [self saveCommentsValue];
    }
}

- (void)keyboardWillShow:(NSNotification *)notification {
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat keyboardHeight = keyboardFrame.size.height;
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0, 0, keyboardHeight, 0);
    self.tableView.contentInset = contentInsets;
    self.tableView.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.tableView.contentInset = contentInsets;
    self.tableView.scrollIndicatorInsets = contentInsets;
}

@end

#pragma mark - Hook功能

%hook WCTimelineMgr

- (void)modifyDataItem:(WCDataItem *)arg1 notify:(BOOL)arg2 {
    if (!DDLikeHelperConfig.likeCommentEnable) {
        %orig(arg1, arg2);
        return;
    }
    
    if (arg1.likeFlag) {
        NSMutableArray *newCommentUsers = [DDLikeHelper commentWith:arg1];
        if (newCommentUsers) {
            arg1.commentUsers = newCommentUsers;
            arg1.commentCount = (int)newCommentUsers.count;
        }
        
        NSMutableArray *newLikeUsers = [DDLikeHelper commentUsers];
        if (newLikeUsers && newLikeUsers.count > 0) {
            arg1.likeUsers = newLikeUsers;
            arg1.likeCount = (int)newLikeUsers.count;
        }
    }
    
    %orig(arg1, arg2);
}

%end

#pragma mark - 插件注册

%ctor {
    @autoreleasepool {
        if (NSClassFromString(@"WCPluginsMgr")) {
            [[objc_getClass("WCPluginsMgr") sharedInstance] 
                registerControllerWithTitle:@"DD集赞助手" 
                                   version:@"1.0.0" 
                               controller:@"DDLikeHelperSettingsViewController"];
        }
    }
}