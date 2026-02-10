#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

#pragma mark - WeChat内部类声明

@interface CMessageWrap : NSObject
@property(nonatomic) unsigned int m_uiMessageType;
@property(retain, nonatomic) NSString *m_nsFromUsr;
@property(retain, nonatomic) NSString *m_nsToUsr;
@property(nonatomic) unsigned int m_uiMesLocalID;
@property(nonatomic) unsigned int m_uiCreateTime;
@property(nonatomic) unsigned int m_uiStatus;
@property(nonatomic) unsigned int m_uiDownloadStatus;
@property(retain, nonatomic) id m_nsMsgSource;
@property(retain, nonatomic) id m_dtVoice;
@property(nonatomic) unsigned int m_uiVoiceFormat;
@property(nonatomic) unsigned int m_uiVoiceTime;
@property(retain, nonatomic) NSString *m_nsContent;
- (id)initWithMsgType:(long long)arg1;
- (void)UpdateContent:(id)arg1;
+ (BOOL)isSenderFromMsgWrap:(CMessageWrap *)msgWrap;
@end

@interface CContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@end

@interface CUtility : NSObject
+ (NSString *)GetPathOfMesAudio:(NSString *)arg1 LocalID:(unsigned long)arg2 DocPath:(NSString *)arg3;
+ (NSString *)GetDocPath;
@end

@interface CBaseFile : NSObject
+ (BOOL)FileExist:(NSString *)arg1;
@end

@interface MMContext : NSObject
+ (id)activeUserContext;
- (id)getService:(Class)cls;
@end

@interface CMessageMgr : NSObject
- (void)AddLocalMsg:(id)arg1 MsgWrap:(id)arg2;
@end

@interface AudioSender : NSObject
@property(retain, nonatomic) id m_upload;
@end

@interface MMNewUploadVoiceMgr : NSObject
- (void)ResendVoiceMsg:(NSString *)toUser MsgWrap:(CMessageWrap *)msgWrap;
@end

@interface MMNewSessionMgr : NSObject
- (unsigned long)GenSendMsgTime;
@end

@interface ForwardMsgUtil : NSObject
+ (void)ForwardMsg:(CMessageWrap *)msgWrap ToContact:(CContact *)forwardContact Scene:(unsigned int)scene forwardType:(unsigned int)type editImageAttr:(id)editImageAttr;
@end

@interface VoiceMessageCellView : UIView
- (void)doForward;
- (NSArray *)operationMenuItems;
@end

// 微信的菜单项类
@interface MMMenuItem : NSObject
- (instancetype)initWithTitle:(NSString *)title target:(id)target action:(SEL)action;
@end

#pragma mark - 主插件代码

%hook VoiceMessageCellView

- (NSArray *)operationMenuItems{
    // 获取原始菜单项
    NSArray *originalItems = %orig;
    if (!originalItems) {
        originalItems = @[];
    }
    
    // 转换为可变数组
    NSMutableArray *menuItems = [originalItems mutableCopy];
    
    // 创建转发语音菜单项
    MMMenuItem *voiceTransmitItem = [[%c(MMMenuItem) alloc] initWithTitle:@"转发语音" target:self action:@selector(handleForwardAction:)];
    
    if (voiceTransmitItem) {
        // 插入到索引1的位置（通常在复制之后，其他选项之前）
        NSUInteger insertIndex = MIN(1, menuItems.count);
        [menuItems insertObject:voiceTransmitItem atIndex:insertIndex];
    }
    
    return menuItems;
}

- (void)handleForwardAction:(id)arg1{
    // 调用微信原生的doForward方法
    // 使用performSelector避免编译时检查
    if ([self respondsToSelector:@selector(doForward)]) {
        [self performSelector:@selector(doForward) withObject:nil afterDelay:0];
    }
}

%end

#pragma mark - 构造函数

%ctor {
    @autoreleasepool {
        // 初始化代码
        NSLog(@"[语音转发插件] 已加载");
    }
}