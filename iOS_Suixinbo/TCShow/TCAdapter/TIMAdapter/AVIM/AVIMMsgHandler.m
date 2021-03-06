//
//  AVIMMsgHandler.m
//  TCShow
//
//  Created by AlexiChen on 15/11/21.
//  Copyright © 2015年 AlexiChen. All rights reserved.
//

#import "AVIMMsgHandler.h"
#import "TIMUserProfile+IMUserAble.h"

@implementation AVIMMsgHandler

- (void)dealloc
{
    DebugLog(@"%@ [%@] Release", self, [_imRoomInfo liveIMChatRoomId]);
    [self releaseIMRef];
    
}

- (void)releaseIMRef
{
    [[TIMManager sharedInstance] setMessageListener:nil];
    
    
    //#pragma clang diagnostic push
    //#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    //    [[TIMManager sharedInstance] setGroupMemberListener:nil];
    //#pragma clang diagnostic pop
}

- (instancetype)initWith:(id<AVRoomAble>)imRoom
{
    if (self = [super init])
    {
        NSString *cid = [imRoom liveIMChatRoomId];
        DebugLog(@"-----IMSDK监听群消息>>>>>群号[%@]", cid);
        _imRoomInfo = imRoom;
        
        // 为了不影响视频，runloop线程优先级较低，用户可根据自身需要去调整
        _msgRunLoop = [[AVIMRunLoop alloc] init];
        
        // 看情况是否可换成并发队DISPATCH_QUEUE_CONCURRENT 或 DISPATCH_QUEUE_SERIAL
        //        _recvMsgQueue = dispatch_queue_create("AVIMMsgHandler_RecvMsgQueue", DISPATCH_QUEUE_CONCURRENT);
        
        [[TIMManager sharedInstance] setMessageListener:self];
        
        // 示例中使用自定义上线消息作更新，不监听群成员变化消息
        //#pragma clang diagnostic push
        //#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        // [[TIMManager sharedInstance] setGroupMemberListener:self];
        //#pragma clang diagnostic pop
        _chatRoomConversation = [[TIMManager sharedInstance] getConversation:TIM_GROUP receiver:cid];
    }
    return self;
}


// 进入直播间
- (void)enterLiveChatRoom:(TIMSucc)block fail:(TIMFail)fail;
{
    AVIMCMD *cmd = [[AVIMCMD alloc] initWith:AVIMCMD_EnterLive];
    [self sendCustomGroupMsg:cmd succ:block fail:fail];
}

// 退出直播间
- (void)exitLiveChatRoom:(TIMSucc)block fail:(TIMFail)fail;
{
    AVIMCMD *cmd = [[AVIMCMD alloc] initWith:AVIMCMD_ExitLive];
    [self sendCustomGroupMsg:cmd succ:block fail:fail];
}



- (void)sendMessage:(NSString *)msg
{
    if (msg.length == 0)
    {
        DebugLog(@"发关的消息为空");
        return;
    }
    
    TIMTextElem *textElem = [[TIMTextElem alloc] init];
    [textElem setText:msg];
    
    TIMMessage *timMsg = [[TIMMessage alloc] init];
    [timMsg addElem:textElem];
    
    [_chatRoomConversation sendMessage:timMsg succ:^{
        // TODO:添加到缓存列表中
        [self onRecvGroupSender:[IMAPlatform sharedInstance].host textMsg:msg];
    } fail:^(int code, NSString *msg) {
        DebugLog(@"发送消息失败：%@", timMsg);
    }];
}


- (void)sendCustomGroupMsg:(AVIMCMD *)cmd succ:(TIMSucc)succ fail:(TIMFail)fail
{
    if (cmd)
    {
        TIMCustomElem *elem = [[TIMCustomElem alloc] init];
        elem.data = [cmd packToSendData];
        
        TIMMessage *timMsg = [[TIMMessage alloc] init];
        [timMsg addElem:elem];
        
        [_chatRoomConversation sendMessage:timMsg succ:succ fail:^(int code, NSString *msg) {
            DebugLog(@"发送消息失败：%@", timMsg);
            if (fail)
            {
                fail(code, msg);
            }
        }];
    }
}

- (void)sendCustomC2CMsg:(AVIMCMD *)cmd toUser:(id<IMUserAble>)recv succ:(TIMSucc)succ fail:(TIMFail)fail
{
    if (cmd && recv)
    {
        TIMConversation *conv = [[TIMManager sharedInstance] getConversation:TIM_C2C receiver:[recv imUserId]];
        
        TIMCustomElem *elem = [[TIMCustomElem alloc] init];
        elem.data = [cmd packToSendData];
        
        
        TIMMessage *timMsg = [[TIMMessage alloc] init];
        [timMsg addElem:elem];
        
        [conv sendMessage:timMsg succ:succ fail:^(int code, NSString *msg) {
            DebugLog(@"发送消息失败：%@", timMsg);
            if (fail)
            {
                fail(code, msg);
            }
        }];
    }
}

- (void)onRecvSystem:(TIMMessage *)msg
{
    for(int index = 0; index < [msg elemCount]; index++)
    {
        TIMElem *elem = [msg getElem:index];
        
        if ([elem isKindOfClass:[TIMGroupSystemElem class]])
        {
            TIMGroupSystemElem *item = (TIMGroupSystemElem *)elem;
            
            if ([item.group isEqualToString:[_imRoomInfo liveIMChatRoomId]])
            {
                // 只处理群解散消息
                if (item.type == TIM_GROUP_SYSTEM_DELETE_GROUP_TYPE)
                {
                    // 有人退群
                    dispatch_async(dispatch_get_main_queue(), ^{
                        // 系统退群，后台自动解散
                        if (_roomIMListner && [_roomIMListner respondsToSelector:@selector(onIMHandler:deleteGroup:)])
                        {
                            [_roomIMListner onIMHandler:self deleteGroup:item.opUserInfo];
                        }
                    });
                }
            }
        }
    }
    
}


- (void)onRecvGroup:(TIMMessage *)msg
{
    id<IMUserAble> info = [msg GetSenderProfile];
    if (!info)
    {
        info = [msg GetSenderGroupMemberProfile];
    }
    for(int index = 0; index < [msg elemCount]; index++)
    {
        TIMElem *elem = [msg getElem:index];
        if([elem isKindOfClass:[TIMTextElem class]])
        {
            //消息
            TIMTextElem *textElem = (TIMTextElem *)elem;
            NSString *msgText = textElem.text;
            [self onRecvGroupSender:info textMsg:msgText];
        }
        else if([elem isKindOfClass:[TIMCustomElem class]])
        {
            // 自定义消息
            [self onRecvGroupSender:info customMsg:(TIMCustomElem *)elem];
        }
    }
}

- (void)onRecvC2C:(TIMMessage *)msg
{
    id<IMUserAble> profile = [msg GetSenderProfile];
    if (!profile)
    {
        // C2C时获取到消息GetSenderProfile为空
        NSString *recv = [[msg getConversation] getReceiver];
        profile = [self syncGetC2CUserInfo:recv];
    }
    
    // 未处理C2C文本消息
    for(int index = 0; index < [msg elemCount]; index++)
    {
        TIMElem *elem = [msg getElem:index];
        //        if([elem isKindOfClass:[TIMTextElem class]])
        //        {
        //            //消息
        //            TIMTextElem *textElem = (TIMTextElem *)elem;
        //            NSString *msgText = textElem.text;
        //            [self onRecvC2CSender:profile textMsg:msgText];
        //        }
        //        else
        // 只处理C2C自定义消息，不处理其他类型聊天消息
        if([elem isKindOfClass:[TIMCustomElem class]])
        {
            // 自定义消息
            [self onRecvC2CSender:profile customMsg:(TIMCustomElem *)elem];
        }
    }
}


- (void)onHandleNewMessage:(NSArray *)msgs
{
    for(TIMMessage *msg in msgs)
    {
        TIMConversationType conType = msg.getConversation.getType;
        
        switch (conType)
        {
            case TIM_C2C:
            {
                [self onRecvC2C:msg];
            }
                break;
            case TIM_GROUP:
            {
                if([[msg.getConversation getReceiver] isEqualToString:[_imRoomInfo liveIMChatRoomId]])
                {
                    // 处理群聊天消息
                    // 只接受来自该聊天室的消息
                    [self onRecvGroup:msg];
                }
            }
                break;
            case TIM_SYSTEM:
            {
                [self onRecvSystem:msg];
            }
                break;
            default:
                break;
        }
    }
}

- (void)onNewMessage:(NSArray *)msgs
{
    [self performSelector:@selector(onHandleNewMessage:) onThread:_msgRunLoop.thread withObject:msgs waitUntilDone:NO];
}

- (void)notifyUsers:(NSArray *)array tipType:(TIMGroupTipsType)tipType
{
    switch (tipType)
    {
        case TIM_GROUP_TIPS_JOIN:
        {
            // 有人加群
            dispatch_async(dispatch_get_main_queue(), ^{
                if (_roomIMListner && array.count > 0 && [_roomIMListner respondsToSelector:@selector(onIMHandler:joinGroup:)])
                {
                    [_roomIMListner onIMHandler:self joinGroup:array];
                }
            });
        }
            break;
            
        case TIM_GROUP_TIPS_QUIT:
        {
            // 有人退群
            dispatch_async(dispatch_get_main_queue(), ^{
                if (_roomIMListner && [_roomIMListner respondsToSelector:@selector(onIMHandler:exitGroup:)])
                {
                    [_roomIMListner onIMHandler:self exitGroup:array];
                }
            });
        }
            break;
            
        default:
            break;
    }
}

@end


@implementation AVIMMsgHandler (ProtectedMethod)

// 供子类重写

- (id<IMUserAble>)syncGetC2CUserInfo:(NSString *)identifier
{
    if ([[[_imRoomInfo liveHost] imUserId] isEqualToString:identifier])
    {
        // 主播发过来的消息
        return [_imRoomInfo liveHost];
    }
    else
    {
        
        TIMUserProfile *profile = [[TIMUserProfile alloc] init];
        profile.identifier = identifier;
        return profile;
    }
}

- (void)sendLikeMessage
{
    // do nothing
    AVIMCMD *cmd = [[AVIMCMD alloc] initWith:AVIMCMD_Praise];
    
    TIMCustomElem *elem = [[TIMCustomElem alloc] init];
    elem.data = [cmd packToSendData];
    
    TIMMessage *timMsg = [[TIMMessage alloc] init];
    [timMsg addElem:elem];
    
    [_chatRoomConversation sendLikeMessage:timMsg succ:nil fail:nil];
    
}
// 收到群自定义消息处理
- (void)onRecvGroupSender:(id<IMUserAble>)sender textMsg:(NSString *)msg
{
    id<AVIMMsgAble> cachedMsg = [self cacheRecvGroupSender:sender textMsg:msg];
    if (cachedMsg)
    {
        [self performSelectorOnMainThread:@selector(onRecvGroupMsgInMainThread:) withObject:cachedMsg waitUntilDone:YES];
    }
}

- (void)onRecvGroupMsgInMainThread:(id<AVIMMsgAble>)cachedMsg
{
    [_roomIMListner onIMHandler:self recvGroupMsg:cachedMsg];
}

// 收到群自定义消息处理
- (void)onRecvGroupSender:(id<IMUserAble>)sender customMsg:(TIMCustomElem *)msg
{
    id<AVIMMsgAble> cachedMsg = [self cacheRecvGroupSender:sender customMsg:msg];
    if (cachedMsg)
    {
        NSInteger type = [cachedMsg msgType];
        BOOL hasHandle = YES;
        if (type > 0 && sender)
        {
           
            switch (type)
            {
                case AVIMCMD_EnterLive:
                {
                    AVIMMsg *enterMsg = [self onRecvSenderEnterLiveRoom:sender];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        DebugLog(@"收到消息：%@", enterMsg);
                        if (enterMsg)
                        {
                            [_roomIMListner onIMHandler:self recvGroupMsg:enterMsg];
                        }
                        
                        [_roomIMListner onIMHandler:self joinGroup:@[sender]];
                    });
                }
                    break;
                case AVIMCMD_ExitLive:
                {
                    AVIMMsg *exitMsg = [self onRecvSenderExitLiveRoom:sender];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        DebugLog(@"收到消息：%@", exitMsg);
                        
                        if (exitMsg)
                        {
                            [_roomIMListner onIMHandler:self recvGroupMsg:exitMsg];
                        }

                        if ([[sender imUserId] isEqualToString:[[_imRoomInfo liveHost] imUserId]])
                        {
                            DebugLog(@"主播主动退群");
                            // 主播主动退群，结束直播
                            [_roomIMListner onIMHandler:self deleteGroup:sender];
                        }
                        else
                        {
                            [_roomIMListner onIMHandler:self exitGroup:@[sender]];
                        }
                    });
                }
                    break;
                    
                default:
                    hasHandle = [self onHandleRecvMultiGroupSender:sender customMsg:cachedMsg];
                    break;
            }
        }
        
        if (!hasHandle)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [_roomIMListner onIMHandler:self recvCustomGroup:cachedMsg];
            });
        }
    }
}

- (BOOL)onHandleRecvMultiGroupSender:(id<IMUserAble>)sender customMsg:(id<AVIMMsgAble>)cachedMsg
{
    return NO;
}

// 收到C2C自定义消息
- (void)onRecvC2CSender:(id<IMUserAble>)sender customMsg:(TIMCustomElem *)msg
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // Demo中此类不处理C2C消息
        id<AVIMMsgAble> cachedMsg =[self cacheRecvC2CSender:sender customMsg:msg];
        if (cachedMsg)
        {
            DebugLog(@"收到消息：%@", cachedMsg);
            [_roomIMListner onIMHandler:self recvCustomC2C:cachedMsg];
        }
    });
}

- (id<AVIMMsgAble>)cacheRecvGroupSender:(id<IMUserAble>)sender textMsg:(NSString *)msg
{
    AVIMMsg *amsg = [[AVIMMsg alloc] initWith:sender message:msg];
    [amsg prepareForRender];
    return amsg;
}

- (id<AVIMMsgAble>)onRecvSenderEnterLiveRoom:(id<IMUserAble>)sender
{
    AVIMMsg *amsg = [[AVIMMsg alloc] initWith:sender message:@"进来了"];
    [amsg prepareForRender];
    return amsg;
}
- (id<AVIMMsgAble>)onRecvSenderExitLiveRoom:(id<IMUserAble>)sender
{
    AVIMMsg *amsg = [[AVIMMsg alloc] initWith:sender message:@"离开了"];
    [amsg prepareForRender];
    return amsg;
}

- (id<AVIMMsgAble>)cacheRecvGroupSender:(id<IMUserAble>)sender customMsg:(TIMCustomElem *)msg
{
    NSString *datastring = [[NSString alloc] initWithData:msg.data encoding:NSUTF8StringEncoding];
    AVIMCMD *cmsg = [NSObject parse:[AVIMCMD class] jsonString:datastring];
    cmsg.sender = sender;
    [cmsg prepareForRender];
    return cmsg;
}

- (id<AVIMMsgAble>)cacheRecvC2CSender:(id<IMUserAble>)sender customMsg:(TIMCustomElem *)msg
{
    NSString *datastring = [[NSString alloc] initWithData:msg.data encoding:NSUTF8StringEncoding];
    AVIMCMD *cmsg = [NSObject parse:[AVIMCMD class] jsonString:datastring];
    cmsg.sender = sender;
    [cmsg prepareForRender];
    return cmsg;
    
}

@end
