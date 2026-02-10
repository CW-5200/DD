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

#pragma mark - 主插件代码
%hook VoiceMessageCellView

- (NSArray *)operationMenuItems{
    NSMutableArray *menuItems = [%orig mutableCopy];
    
    // 创建转发菜单项
    UIMenuItem *voiceTransmitItem = [[UIMenuItem alloc] initWithTitle:@"转发" action:@selector(onForward:)];
    [menuItems insertObject:voiceTransmitItem atIndex:1];
    
    return menuItems;
}

- (void)onForward:(id)arg1{
    // 调用 doForward 方法
    [self doForward];
}

%end

%hook ForwardMsgUtil

+ (void)ForwardMsg:(CMessageWrap *)msgWrap ToContact:(CContact *)forwardContact Scene:(unsigned int)scene forwardType:(unsigned int)type editImageAttr:(id)editImageAttr{
    
    // 检查是否为语音消息（34 是语音消息类型，0x22 的十进制是34）
    if(msgWrap.m_uiMessageType == 34){
        
        // 获取当前上下文
        MMContext *context = [%c(MMContext) activeUserContext];
        if (!context) {
            %orig;
            return;
        }
        
        // 判断是发送者还是接收者
        BOOL isSender = [%c(CMessageWrap) isSenderFromMsgWrap:msgWrap];
        
        // 获取语音文件路径 - 修正参数顺序
        NSString *userName = isSender ? msgWrap.m_nsFromUsr : msgWrap.m_nsToUsr;
        NSString *voicePath = [%c(CUtility) GetPathOfMesAudio:userName 
                                                     LocalID:msgWrap.m_uiMesLocalID 
                                                     DocPath:[%c(CUtility) GetDocPath]];
        
        // 检查语音文件是否存在
        if([%c(CBaseFile) FileExist:voicePath]){
            NSLog(@"[语音转发] 找到语音文件: %@", voicePath);
            
            // 创建新的语音消息
            CMessageWrap *newMsgWrap = [[%c(CMessageWrap) alloc] initWithMsgType:34];
            
            // 设置发送者和接收者 - 修正逻辑
            // 原始消息的发送者是当前用户，则新消息的发送者也是当前用户
            newMsgWrap.m_nsFromUsr = msgWrap.m_nsFromUsr;  // 保持原发送者
            newMsgWrap.m_nsToUsr = forwardContact.m_nsUsrName;  // 目标联系人
            
            // 设置消息源 - 如果存在
            if (msgWrap.m_nsMsgSource) {
                newMsgWrap.m_nsMsgSource = msgWrap.m_nsMsgSource;
            }
            
            newMsgWrap.m_uiStatus = 0x1;  // 消息状态
            newMsgWrap.m_uiDownloadStatus = 0x9;  // 下载状态
            
            // 获取会话管理器并生成发送时间
            MMNewSessionMgr *sessionMgr = [context getService:%c(MMNewSessionMgr)];
            if (sessionMgr) {
                NSInteger genSendTime = [sessionMgr GenSendMsgTime];
                newMsgWrap.m_uiCreateTime = genSendTime;
            } else {
                newMsgWrap.m_uiCreateTime = msgWrap.m_uiCreateTime;
            }
            
            // 读取语音数据
            NSData *voiceData = [NSData dataWithContentsOfFile:voicePath];
            if (voiceData && voiceData.length > 0) {
                newMsgWrap.m_dtVoice = voiceData;
                newMsgWrap.m_uiVoiceFormat = msgWrap.m_uiVoiceFormat;
                newMsgWrap.m_uiVoiceTime = msgWrap.m_uiVoiceTime;
                
                // 更新消息内容
                [newMsgWrap UpdateContent:nil];
                
                // 添加到消息管理器
                CMessageMgr *msgMgr = [context getService:%c(CMessageMgr)];
                if (msgMgr) {
                    [msgMgr AddLocalMsg:forwardContact.m_nsUsrName MsgWrap:newMsgWrap];
                    NSLog(@"[语音转发] 已添加本地消息");
                    
                    // 重新设置下载状态
                    newMsgWrap.m_uiDownloadStatus = 0x9;
                    
                    // 获取音频发送器并重新发送语音消息
                    AudioSender *audioSender = [context getService:%c(AudioSender)];
                    if (audioSender) {
                        MMNewUploadVoiceMgr *uploadVoiceMgr = MSHookIvar<MMNewUploadVoiceMgr *>(audioSender,"m_upload");
                        if (uploadVoiceMgr) {
                            [uploadVoiceMgr ResendVoiceMsg:forwardContact.m_nsUsrName MsgWrap:newMsgWrap];
                            NSLog(@"[语音转发] 已重新发送语音消息");
                        } else {
                            NSLog(@"[语音转发] 无法获取上传管理器");
                        }
                    } else {
                        NSLog(@"[语音转发] 无法获取音频发送器");
                    }
                } else {
                    NSLog(@"[语音转发] 无法获取消息管理器");
                }
            } else {
                NSLog(@"[语音转发] 语音数据为空或读取失败");
                %orig;  // 回退到原始转发
            }
        } else {
            NSLog(@"[语音转发] 语音文件不存在: %@", voicePath);
            %orig;  // 回退到原始转发
        }
    } else {
        // 非语音消息使用原始转发逻辑
        %orig;
    }
}

%end