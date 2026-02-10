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
@property(nonatomic) long long m_n64MesSvrID;
- (id)initWithMsgType:(long long)arg1;
- (void)UpdateContent:(id)arg1;
+ (BOOL)isSenderFromMsgWrap:(CMessageWrap *)msgWrap;
- (NSString *)GetChatName;
@end

@interface CContact : NSObject
@property(retain, nonatomic) NSString *m_nsUsrName;
@property(retain, nonatomic) NSString *m_nsNickName;
@end

@interface CContactMgr : NSObject
- (CContact *)getSelfContact;
- (CContact *)getContactByName:(NSString *)name;
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
- (CMessageWrap *)GetMsg:(NSString *)arg1 LocalID:(unsigned int)arg2;
- (void)AddLocalMsg:(id)arg1 MsgWrap:(id)arg2;
- (void)AddLocalMsg:(id)arg1 MsgWrap:(id)arg2 fixTime:(BOOL)arg3 NewMsgArriveNotify:(BOOL)arg4;
@end

@interface AudioSender : NSObject
@property(retain, nonatomic) id m_upload;
@end

@interface MMNewUploadVoiceMgr : NSObject
- (void)ResendVoiceMsg:(NSString *)toUser MsgWrap:(CMessageWrap *)msgWrap;
@end

@interface MMNewSessionMgr : NSObject
- (unsigned int)GenSendMsgTime;
@end

@interface ForwardMsgUtil : NSObject
+ (void)ForwardMsg:(CMessageWrap *)msgWrap ToContact:(CContact *)forwardContact Scene:(unsigned int)scene forwardType:(unsigned int)type editImageAttr:(id)editImageAttr;
+ (CMessageWrap *)GenForwardMsgFromMsgWrap:(CMessageWrap *)msgWrap ToContact:(CContact *)contact;
@end

@interface BaseChatViewModel : NSObject
@property(readonly, nonatomic) CMessageWrap *messageWrap;
@end

@interface BaseChatCellView : UIView
@property(readonly, nonatomic) BaseChatViewModel *viewModel;
@end

@interface VoiceMessageCellView : BaseChatCellView
- (void)doForward;
- (NSArray *)operationMenuItems;
- (void)onForward:(id)arg1;
@end

// 微信的菜单项类
@interface MMMenuItem : NSObject
- (instancetype)initWithTitle:(NSString *)title target:(id)target action:(SEL)action;
@end

@interface MMServiceCenter : NSObject
+ (id)defaultCenter;
- (id)getService:(Class)cls;
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
    // 尝试获取当前消息
    CMessageWrap *msgWrap = nil;
    
    @try {
        // 通过 viewModel 获取消息
        BaseChatViewModel *viewModel = [self viewModel];
        if (viewModel && [viewModel respondsToSelector:@selector(messageWrap)]) {
            msgWrap = [viewModel messageWrap];
        }
    } @catch (NSException *exception) {
        NSLog(@"[语音转发] 获取消息失败: %@", exception);
    }
    
    if (msgWrap && msgWrap.m_uiMessageType == 34) {
        // 保存消息到临时变量，用于转发
        static CMessageWrap *tempMsgWrap = nil;
        tempMsgWrap = msgWrap;
        
        // 获取当前聊天会话名称
        NSString *chatName = nil;
        @try {
            if ([msgWrap respondsToSelector:@selector(GetChatName)]) {
                chatName = [msgWrap GetChatName];
            }
        } @catch (NSException *exception) {
            chatName = msgWrap.m_nsFromUsr;
        }
        
        NSLog(@"[语音转发] 准备转发语音消息，来自: %@", chatName);
        
        // 调用 doForward 方法触发转发流程
        // 注意：这里的 doForward 会调用微信原生的转发逻辑
        // 我们需要 hook ForwardMsgUtil 来拦截并处理语音转发
        if ([self respondsToSelector:@selector(doForward)]) {
            [self doForward];
        }
    } else {
        NSLog(@"[语音转发] 不是语音消息或消息为空");
        if ([self respondsToSelector:@selector(doForward)]) {
            [self doForward];
        }
    }
}

%end

%hook ForwardMsgUtil

+ (void)ForwardMsg:(CMessageWrap *)msgWrap ToContact:(CContact *)forwardContact Scene:(unsigned int)scene forwardType:(unsigned int)type editImageAttr:(id)editImageAttr{
    
    NSLog(@"[语音转发] 进入转发方法，消息类型: %d", msgWrap.m_uiMessageType);
    
    // 检查是否为语音消息
    if (msgWrap.m_uiMessageType == 34) {
        NSLog(@"[语音转发] 检测到语音消息，开始处理");
        
        // 获取当前上下文
        MMContext *context = [%c(MMContext) activeUserContext];
        if (!context) {
            NSLog(@"[语音转发] 上下文为空，使用原始转发");
            %orig;
            return;
        }
        
        // 获取服务
        CContactMgr *contactMgr = [context getService:objc_getClass("CContactMgr")];
        CUtility *utility = [%c(CUtility) class];
        CBaseFile *fileUtil = [%c(CBaseFile) class];
        
        if (!contactMgr || !utility || !fileUtil) {
            NSLog(@"[语音转发] 获取服务失败，使用原始转发");
            %orig;
            return;
        }
        
        // 获取当前用户
        CContact *selfContact = [contactMgr getSelfContact];
        if (!selfContact) {
            NSLog(@"[语音转发] 获取当前用户失败，使用原始转发");
            %orig;
            return;
        }
        
        // 判断是发送者还是接收者
        BOOL isSender = [%c(CMessageWrap) isSenderFromMsgWrap:msgWrap];
        NSLog(@"[语音转发] 是否是发送者: %@", isSender ? @"是" : @"否");
        
        // 获取语音文件路径
        NSString *userName = isSender ? selfContact.m_nsUsrName : msgWrap.m_nsFromUsr;
        NSString *docPath = [utility GetDocPath];
        NSString *voicePath = [utility GetPathOfMesAudio:userName 
                                                 LocalID:msgWrap.m_uiMesLocalID 
                                                 DocPath:docPath];
        
        NSLog(@"[语音转发] 语音文件路径: %@", voicePath);
        
        // 检查语音文件是否存在
        if (!voicePath || ![fileUtil FileExist:voicePath]) {
            NSLog(@"[语音转发] 语音文件不存在，使用原始转发");
            %orig;
            return;
        }
        
        NSLog(@"[语音转发] 语音文件存在，开始转发");
        
        // 读取语音数据
        NSData *voiceData = [NSData dataWithContentsOfFile:voicePath];
        if (!voiceData || voiceData.length == 0) {
            NSLog(@"[语音转发] 读取语音数据失败，使用原始转发");
            %orig;
            return;
        }
        
        // 创建新的语音消息
        CMessageWrap *newMsgWrap = [[%c(CMessageWrap) alloc] initWithMsgType:34];
        if (!newMsgWrap) {
            NSLog(@"[语音转发] 创建新消息失败，使用原始转发");
            %orig;
            return;
        }
        
        // 设置发送者和接收者
        newMsgWrap.m_nsFromUsr = selfContact.m_nsUsrName;
        newMsgWrap.m_nsToUsr = forwardContact.m_nsUsrName;
        
        // 设置消息源（如果有）
        if (msgWrap.m_nsMsgSource) {
            newMsgWrap.m_nsMsgSource = msgWrap.m_nsMsgSource;
        }
        
        newMsgWrap.m_uiStatus = 0x1;  // 消息状态
        newMsgWrap.m_uiDownloadStatus = 0x9;  // 下载状态
        
        // 获取会话管理器并生成发送时间
        MMNewSessionMgr *sessionMgr = [context getService:objc_getClass("MMNewSessionMgr")];
        if (sessionMgr) {
            unsigned int genSendTime = [sessionMgr GenSendMsgTime];
            newMsgWrap.m_uiCreateTime = genSendTime;
            NSLog(@"[语音转发] 生成发送时间: %u", genSendTime);
        } else {
            newMsgWrap.m_uiCreateTime = msgWrap.m_uiCreateTime;
        }
        
        // 设置语音数据
        newMsgWrap.m_dtVoice = voiceData;
        newMsgWrap.m_uiVoiceFormat = msgWrap.m_uiVoiceFormat;
        newMsgWrap.m_uiVoiceTime = msgWrap.m_uiVoiceTime;
        
        // 更新消息内容
        [newMsgWrap UpdateContent:nil];
        
        // 添加到消息管理器
        CMessageMgr *msgMgr = [context getService:objc_getClass("CMessageMgr")];
        if (msgMgr) {
            // 尝试使用不同的方法添加消息
            if ([msgMgr respondsToSelector:@selector(AddLocalMsg:MsgWrap:fixTime:NewMsgArriveNotify:)]) {
                [msgMgr AddLocalMsg:forwardContact.m_nsUsrName MsgWrap:newMsgWrap fixTime:YES NewMsgArriveNotify:NO];
            } else if ([msgMgr respondsToSelector:@selector(AddLocalMsg:MsgWrap:)]) {
                [msgMgr AddLocalMsg:forwardContact.m_nsUsrName MsgWrap:newMsgWrap];
            }
            
            NSLog(@"[语音转发] 消息已添加到本地");
            
            // 获取音频发送器并重新发送语音消息
            AudioSender *audioSender = [context getService:objc_getClass("AudioSender")];
            if (audioSender) {
                // 尝试通过KVC获取上传管理器
                @try {
                    id uploadMgr = [audioSender valueForKey:@"m_upload"];
                    if (uploadMgr && [uploadMgr respondsToSelector:@selector(ResendVoiceMsg:MsgWrap:)]) {
                        [uploadMgr ResendVoiceMsg:forwardContact.m_nsUsrName MsgWrap:newMsgWrap];
                        NSLog(@"[语音转发] 已触发语音重新发送");
                    } else if ([audioSender respondsToSelector:@selector(ResendVoiceMsg:MsgWrap:)]) {
                        [audioSender ResendVoiceMsg:forwardContact.m_nsUsrName MsgWrap:newMsgWrap];
                        NSLog(@"[语音转发] 已触发语音重新发送");
                    }
                } @catch (NSException *exception) {
                    NSLog(@"[语音转发] 发送语音失败: %@", exception);
                }
            } else {
                NSLog(@"[语音转发] 无法获取音频发送器");
            }
        } else {
            NSLog(@"[语音转发] 无法获取消息管理器");
            %orig;
        }
        
        NSLog(@"[语音转发] 语音消息转发完成");
        
    } else {
        // 非语音消息使用原始转发逻辑
        %orig;
    }
}

%end

#pragma mark - 构造函数

%ctor {
    @autoreleasepool {
        // 初始化代码
        NSLog(@"[语音转发插件] 已加载 - 完整版本");
    }
}