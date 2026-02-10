#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

// 微信内部类声明
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

@interface MMServiceCenter : NSObject
+ (id)defaultCenter;
- (id)getService:(Class)aClass;
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

// VoiceMessageCellView 声明（需要声明 doForward 方法）
@interface VoiceMessageCellView : UIView
- (void)doForward;
- (NSArray *)operationMenuItems;
@end

// 主插件代码
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
    // 检查是否为语音消息（0x22 是语音消息类型）
    if(msgWrap.m_uiMessageType == 0x22){
        // 判断是发送者还是接收者
        BOOL isSender = [%c(CMessageWrap) isSenderFromMsgWrap:msgWrap];
        
        // 获取语音文件路径
        NSString *voicePath = [%c(CUtility) GetPathOfMesAudio:isSender ? msgWrap.m_nsToUsr : msgWrap.m_nsFromUsr 
                                                     LocalID:msgWrap.m_uiMesLocalID 
                                                     DocPath:[%c(CUtility) GetDocPath]];
        
        // 检查语音文件是否存在
        if([%c(CBaseFile) FileExist:voicePath]){
            // 创建新的语音消息
            CMessageWrap *newMsgWrap = [[%c(CMessageWrap) alloc] initWithMsgType:0x22];
            
            // 设置发送者和接收者
            if(isSender){
                newMsgWrap.m_nsFromUsr = msgWrap.m_nsFromUsr;
                newMsgWrap.m_nsToUsr = msgWrap.m_nsToUsr;
            } else {
                newMsgWrap.m_nsFromUsr = msgWrap.m_nsToUsr;
                newMsgWrap.m_nsToUsr = msgWrap.m_nsFromUsr;
            }
            
            // 设置消息源
            newMsgWrap.m_nsMsgSource = msgWrap.m_nsMsgSource;
            newMsgWrap.m_uiStatus = 0x1;
            newMsgWrap.m_uiDownloadStatus = 0x9;
            
            // 获取会话管理器并生成发送时间
            MMNewSessionMgr *sessionMgr = [[%c(MMServiceCenter) defaultCenter] getService:%c(MMNewSessionMgr)];
            NSInteger genSendTime = [sessionMgr GenSendMsgTime];
            newMsgWrap.m_uiCreateTime = genSendTime;
            
            // 读取语音数据
            NSData *voiceData = [NSData dataWithContentsOfFile:voicePath];
            newMsgWrap.m_dtVoice = voiceData;
            newMsgWrap.m_uiVoiceFormat = msgWrap.m_uiVoiceFormat;
            newMsgWrap.m_uiVoiceTime = msgWrap.m_uiVoiceTime;
            
            // 更新消息内容
            [newMsgWrap UpdateContent:nil];
            
            // 添加到消息管理器
            CMessageMgr *msgMgr = [[%c(MMServiceCenter) defaultCenter] getService:%c(CMessageMgr)];
            [msgMgr AddLocalMsg:forwardContact.m_nsUsrName MsgWrap:newMsgWrap];
            
            // 重新设置下载状态
            newMsgWrap.m_uiDownloadStatus = 0x9;
            
            // 获取音频发送器并重新发送语音消息
            AudioSender *audioSender = [[%c(MMServiceCenter) defaultCenter] getService:%c(AudioSender)];
            MMNewUploadVoiceMgr *uploadVoiceMgr = MSHookIvar<MMNewUploadVoiceMgr *>(audioSender,"m_upload");
            [uploadVoiceMgr ResendVoiceMsg:forwardContact.m_nsUsrName MsgWrap:newMsgWrap];
        }
    } else {
        // 非语音消息使用原始转发逻辑
        %orig;
    }
}

%end