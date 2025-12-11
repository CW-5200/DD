// WeChatHelper.xm
// 微信小助手插件 - 简化版

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - 配置管理

@interface WeChatConfig : NSObject
+ (instancetype)shared;

@property (nonatomic, assign) BOOL autoRedEnvelop;
@property (nonatomic, assign) NSInteger redEnvelopDelay;
@property (nonatomic, assign) BOOL personalRedEnvelopEnable;
@property (nonatomic, assign) BOOL timeLineForwardEnable;
@property (nonatomic, assign) BOOL likeCommentEnable;
@property (nonatomic, strong) NSNumber *likeCount;
@property (nonatomic, strong) NSNumber *commentCount;
@property (nonatomic, strong) NSString *comments;
@end

@implementation WeChatConfig

+ (instancetype)shared {
    static WeChatConfig *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[WeChatConfig alloc] init];
        
        // 默认配置
        instance.autoRedEnvelop = YES;
        instance.redEnvelopDelay = 0;
        instance.personalRedEnvelopEnable = YES;
        instance.timeLineForwardEnable = YES;
        instance.likeCommentEnable = NO;
        instance.likeCount = @10;
        instance.commentCount = @5;
        instance.comments = @"赞,,👍";
    });
    return instance;
}

@end

#pragma mark - 自动抢红包核心功能

// 使用objective-c运行时动态hook
__attribute__((constructor)) static void entry() {
    NSLog(@"微信小助手加载成功");
    
    // 动态hook关键方法
    [WeChatHelper setupHooks];
}

@interface WeChatHelper : NSObject
+ (void)setupHooks;
@end

@implementation WeChatHelper

+ (void)setupHooks {
    // 1. 设置界面添加入口
    Class newSettingClass = objc_getClass("NewSettingViewController");
    if (newSettingClass) {
        Method reloadTableData = class_getInstanceMethod(newSettingClass, @selector(reloadTableData));
        if (reloadTableData) {
            method_setImplementation(reloadTableData, (IMP)newReloadTableData);
        }
    }
    
    // 2. 消息处理 - 红包检测
    Class messageMgrClass = objc_getClass("CMessageMgr");
    if (messageMgrClass) {
        Method onNewSyncAddMessage = class_getInstanceMethod(messageMgrClass, @selector(onNewSyncAddMessage:));
        if (onNewSyncAddMessage) {
            method_setImplementation(onNewSyncAddMessage, (IMP)newOnNewSyncAddMessage);
        }
    }
    
    // 3. 朋友圈相关
    [self setupTimelineHooks];
    
    NSLog(@"微信小助手hook设置完成");
}

+ (void)setupTimelineHooks {
    // 朋友圈操作视图
    Class floatViewClass = objc_getClass("WCOperateFloatView");
    if (floatViewClass) {
        Method showMethod = class_getInstanceMethod(floatViewClass, @selector(showWithItemData:tipPoint:));
        if (showMethod) {
            method_setImplementation(showMethod, (IMP)newShowWithItemData);
        }
        
        // 添加转发按钮点击方法
        class_addMethod(floatViewClass, @selector(forwardButtonTapped), (IMP)forwardButtonTapped, "v@:");
    }
}

#pragma mark - 设置界面修改

static void newReloadTableData(id self, SEL _cmd) {
    // 调用原始方法
    void (*original)(id, SEL) = (void (*)(id, SEL))class_getMethodImplementation([self class], @selector(reloadTableData));
    if (original) {
        original(self, _cmd);
    }
    
    // 尝试添加设置项
    [self performSelector:@selector(addHelperSettingItem)];
}

#pragma mark - 红包处理

static void newOnNewSyncAddMessage(id self, SEL _cmd, id wrap) {
    // 调用原始方法
    void (*original)(id, SEL, id) = (void (*)(id, SEL, id))class_getMethodImplementation([self class], @selector(onNewSyncAddMessage:));
    if (original) {
        original(self, _cmd, wrap);
    }
    
    // 处理红包消息
    [self performSelector:@selector(handleRedEnvelopIfNeeded:) withObject:wrap];
}

#pragma mark - 朋友圈转发

static void newShowWithItemData(id self, SEL _cmd, id data, CGPoint point) {
    // 调用原始方法
    void (*original)(id, SEL, id, CGPoint) = (void (*)(id, SEL, id, CGPoint))class_getMethodImplementation([self class], @selector(showWithItemData:tipPoint:));
    if (original) {
        original(self, _cmd, data, point);
    }
    
    // 添加转发按钮
    if ([WeChatConfig shared].timeLineForwardEnable) {
        [self performSelector:@selector(addForwardButton)];
    }
}

static void forwardButtonTapped(id self, SEL _cmd) {
    NSLog(@"朋友圈转发按钮点击");
    // 这里可以实现转发逻辑
}

@end

#pragma mark - 类别扩展

@implementation NSObject (WeChatHelper)

- (void)addHelperSettingItem {
    @try {
        // 使用KVC获取表格管理器
        id tableViewMgr = [self valueForKey:@"m_tableViewMgr"];
        if (tableViewMgr) {
            // 创建设置项
            Class cellManagerClass = objc_getClass("WCTableViewNormalCellManager");
            if (cellManagerClass) {
                id newCell = [cellManagerClass performSelector:@selector(normalCellForSel:target:title:) 
                                                    withObject:@selector(showHelperSettings)
                                                    withObject:self
                                                    withObject:@"微信小助手"];
                
                if (newCell) {
                    // 获取第一个section
                    id sections = [tableViewMgr valueForKey:@"sections"];
                    if (sections && [sections count] > 0) {
                        id firstSection = sections[0];
                        [firstSection performSelector:@selector(addCell:) withObject:newCell];
                        
                        // 刷新表格
                        id tableView = [tableViewMgr performSelector:@selector(getTableView)];
                        if (tableView) {
                            [tableView performSelector:@selector(reloadData)];
                        }
                    }
                }
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"添加设置项失败: %@", exception);
    }
}

- (void)showHelperSettings {
    NSLog(@"显示小助手设置");
    // 创建简单的设置界面
    UIViewController *settingsVC = [[UIViewController alloc] init];
    settingsVC.title = @"微信小助手";
    settingsVC.view.backgroundColor = [UIColor whiteColor];
    
    // 查找导航控制器
    UIViewController *currentVC = (UIViewController *)self;
    UIViewController *navController = currentVC.navigationController;
    if (navController) {
        [navController pushViewController:settingsVC animated:YES];
    }
}

- (void)handleRedEnvelopIfNeeded:(id)wrap {
    @try {
        if (![WeChatConfig shared].autoRedEnvelop) return;
        
        // 获取消息内容
        NSString *content = [wrap valueForKey:@"m_nsContent"];
        if (!content) return;
        
        // 检查是否为红包消息
        if ([content containsString:@"wxpay://"]) {
            NSLog(@"检测到红包消息");
            
            // 检查是否为个人红包
            NSString *fromUser = [wrap valueForKey:@"m_nsFromUsr"];
            BOOL isGroup = [fromUser containsString:@"@chatroom"];
            
            if (!isGroup && ![WeChatConfig shared].personalRedEnvelopEnable) {
                return; // 不接收个人红包
            }
            
            // 延迟抢红包
            dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, 
                                                 (int64_t)([WeChatConfig shared].redEnvelopDelay * NSEC_PER_MSEC));
            dispatch_after(delay, dispatch_get_main_queue(), ^{
                [self openRedEnvelop:wrap];
            });
        }
    } @catch (NSException *exception) {
        NSLog(@"处理红包失败: %@", exception);
    }
}

- (void)openRedEnvelop:(id)wrap {
    @try {
        // 获取支付信息
        id payInfo = [wrap valueForKey:@"m_oWCPayInfoItem"];
        if (!payInfo) return;
        
        NSString *nativeUrl = [payInfo valueForKey:@"m_c2cNativeUrl"];
        if (!nativeUrl) return;
        
        // 解析红包参数
        NSDictionary *params = [self parseRedEnvelopParams:nativeUrl];
        if (!params) return;
        
        // 调用微信的红包逻辑
        Class logicMgrClass = objc_getClass("WCRedEnvelopesLogicMgr");
        if (!logicMgrClass) return;
        
        id logicMgr = [[objc_getClass("MMServiceCenter") performSelector:@selector(defaultCenter)] 
                       performSelector:@selector(getService:) withObject:logicMgrClass];
        if (!logicMgr) return;
        
        NSMutableDictionary *requestParams = [NSMutableDictionary dictionary];
        requestParams[@"agreeDuty"] = @"0";
        requestParams[@"channelId"] = params[@"channelid"] ?: @"";
        requestParams[@"inWay"] = @"0";
        requestParams[@"msgType"] = params[@"msgtype"] ?: @"";
        requestParams[@"sendId"] = params[@"sendid"] ?: @"";
        
        // 获取会话
        NSString *fromUser = [wrap valueForKey:@"m_nsFromUsr"];
        if ([fromUser containsString:@"@chatroom"]) {
            requestParams[@"sessionUserName"] = fromUser;
        }
        
        // 调用打开红包的方法
        SEL selector = NSSelectorFromString(@"ReceiverQueryRedEnvelopesRequest:");
        if ([logicMgr respondsToSelector:selector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [logicMgr performSelector:selector withObject:requestParams];
#pragma clang diagnostic pop
        }
    } @catch (NSException *exception) {
        NSLog(@"打开红包失败: %@", exception);
    }
}

- (NSDictionary *)parseRedEnvelopParams:(NSString *)nativeUrl {
    @try {
        if (![nativeUrl hasPrefix:@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?"]) {
            return nil;
        }
        
        NSString *paramsString = [nativeUrl substringFromIndex:[@"wxpay://c2cbizmessagehandler/hongbao/receivehongbao?" length]];
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        
        NSArray *components = [paramsString componentsSeparatedByString:@"&"];
        for (NSString *component in components) {
            NSArray *keyValue = [component componentsSeparatedByString:@"="];
            if (keyValue.count == 2) {
                NSString *key = [keyValue[0] stringByRemovingPercentEncoding];
                NSString *value = [keyValue[1] stringByRemovingPercentEncoding];
                if (key && value) {
                    params[key] = value;
                }
            }
        }
        
        return params;
    } @catch (NSException *exception) {
        return nil;
    }
}

- (void)addForwardButton {
    @try {
        // 检查是否已经添加过按钮
        static char forwardButtonKey;
        UIButton *forwardButton = objc_getAssociatedObject(self, &forwardButtonKey);
        
        if (!forwardButton) {
            forwardButton = [UIButton buttonWithType:UIButtonTypeCustom];
            [forwardButton setTitle:@"转发" forState:UIControlStateNormal];
            [forwardButton setTitleColor:[UIColor systemBlueColor] forState:UIControlStateNormal];
            forwardButton.titleLabel.font = [UIFont systemFontOfSize:14];
            forwardButton.frame = CGRectMake(0, 0, 60, 30);
            [forwardButton addTarget:self action:@selector(forwardButtonTapped) forControlEvents:UIControlEventTouchUpInside];
            
            // 添加到视图
            if ([self isKindOfClass:[UIView class]]) {
                [(UIView *)self addSubview:forwardButton];
            }
            
            objc_setAssociatedObject(self, &forwardButtonKey, forwardButton, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        
        // 调整按钮位置
        id likeButton = [self valueForKey:@"m_likeBtn"];
        if (likeButton && [likeButton isKindOfClass:[UIView class]]) {
            UIView *likeBtn = (UIView *)likeButton;
            forwardButton.frame = CGRectMake(CGRectGetMaxX(likeBtn.frame) + 10, 
                                           likeBtn.frame.origin.y,
                                           likeBtn.frame.size.width,
                                           likeBtn.frame.size.height);
        }
    } @catch (NSException *exception) {
        NSLog(@"添加转发按钮失败: %@", exception);
    }
}

@end

#pragma mark - 简化的控制文件

// Makefile 内容：
// ARCHS = arm64 arm64e
// TARGET = iphone:clang:latest:13.0
// INSTALL_TARGET_PROCESSES = WeChat
// 
// include $(THEOS)/makefiles/common.mk
// 
// TWEAK_NAME = WeChatHelper
// 
// WeChatHelper_FILES = Tweak.xm
// WeChatHelper_CFLAGS = -fobjc-arc -Wno-deprecated-declarations
// WeChatHelper_FRAMEWORKS = UIKit Foundation
// 
// include $(THEOS_MAKE_PATH)/tweak.mk

// control 文件内容：
// Package: com.yourcompany.wechelper
// Name: WeChat Helper
// Version: 1.0
// Architecture: iphoneos-arm
// Description: 微信小助手 - 自动抢红包、朋友圈转发、集赞助手
// Author: Your Name
// Maintainer: Your Name
// Depends: mobilesubstrate
// Section: Tweaks