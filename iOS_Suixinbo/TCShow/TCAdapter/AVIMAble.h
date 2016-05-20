//
//  AVIMAble.h
//  TCShow
//
//  Created by AlexiChen on 16/4/11.
//  Copyright © 2016年 AlexiChen. All rights reserved.
//

#import <Foundation/Foundation.h>



// 前缀解释:
// IM: IMSDK相关
// AV: AVSDK相关
// TC: Tencent Clound

typedef void (^TCAVCompletion)(BOOL succ, NSString *tip);


// ===========================================
// 直播中经常用到的IMSDK返回的User信息
// IMSDK，返回的抽像登录用户
// 实现协议的类记得重写NSObject - (BOOL)isEqual:(id)object;方法，判断的时候使用imUserId进行判断
@protocol IMUserAble <NSObject>


@required

// 两个用户是否相同，可通过比较imUserId来判断
// 用户IMSDK的identigier
- (NSString *)imUserId;

// 用户昵称
- (NSString *)imUserName;

// 用户头像地址
- (NSString *)imUserIconUrl;

@end

// ===========================================

typedef NS_ENUM(NSInteger, AVCtrlState)
{
    // 常用事件
    EAVCtrlState_Speaker = 0x01,                // 是否开启了扬声器
    EAVCtrlState_Mic = 0x01 << 1,               // 是否开启了麦克风
    EAVCtrlState_Camera = 0x01 << 2,            // 是否打开了相机
    EAVCtrlState_Beauty = 0x01 << 3,            // 是否打开了美颜：注意打开开相，
    
    //    EAVCtrlState_Camera = 0x01 << 2,            // 是否打开了相机
    //    EAVCtrlState_FrontCamera = 0x01 << 3,       // 是否是前置摄像头
    EAVCtrlState_All = EAVCtrlState_Mic | EAVCtrlState_Speaker | EAVCtrlState_Camera | EAVCtrlState_Beauty,
};

// 直播中用户的配置
// 直播中要用到的
// 简单的个人
@protocol AVUserAble <IMUserAble>

@required
@property (nonatomic, assign) NSInteger avCtrlState;

@end


// 多人互动时用户的状态
// 暂未使用到
typedef NS_ENUM(NSInteger, AVMultiUserState)
{
    AVMultiUser_Guest = 0X01,                         // 普通观众
    
    AVMultiUser_Interact_Inviting = 0X01 << 1,        // 邀请状态
    AVMultiUser_Interact_Connecting = 0X01 << 2,      // 连接状态，请求画面
    AVMultiUser_Interact = 0X01 << 3,                 // 互动成功
    AVMultiUser_Interact_Losting = 0X01 << 4,         // 互动过程中，用户黑屏，无画面
    // 用户自定状态
    AVMultiUser_Host = 0XFF,                          // 主播，最高优先级
};

@protocol AVMultiUserAble <AVUserAble>

@required

@property (nonatomic, assign) NSInteger avMultiUserState;       // 多人互动时IM配置

// 互动时，用户画面显示的屏幕上的区域（opengl相关的位置）
@property (nonatomic, assign) CGRect avInteractArea;

// 互动时，因opengl放在最底层，之上是的自定义交互层，通常会完全盖住opengl
// 用户要想与小画面进行交互的时候，必须在交互层上放一层透明的大小相同的控件，能过操作此控件来操作小窗口画面
// 全屏交互的用户该值为空
// 业务中若不存在交互逻辑，则不用填
@property (nonatomic, weak) UIView *avInvisibleInteractView;

@end


// 当前登录IMSDK的用户信息
@protocol IMHostAble <IMUserAble>

@required

// 当前App对应的AppID
- (NSString *)imSDKAppId;

// 当前App的AccountType
- (NSString *)imSDKAccountType;

@end


@protocol AVRoomAble <NSObject>

@required

// 聊天室Id
@property (nonatomic, copy) NSString *liveIMChatRoomId;

// 当前主播信息
- (id<IMUserAble>)liveHost;

// 直播房间Id
- (int)liveAVRoomId;

// 直播标题，用于创建直播IM聊天室，不能为空
- (NSString *)liveTitle;

@end



// =======================================================

typedef NS_ENUM(NSInteger, AVIMCommand) {
    
    AVIMCMD_Text = -1,          // 普通的聊天消息
    
    AVIMCMD_None,               // 无事件：0
    
    // 以下事件为TCAdapter内部处理的通用事件
    AVIMCMD_EnterLive,          // 用户加入直播, Group消息 ： 1
    AVIMCMD_ExitLive,           // 用户退出直播, Group消息 ： 2
    AVIMCMD_Praise,             // 点赞消息, Demo中使用Group消息 ： 3
    
    // 中间预留扩展
    
    AVIMCMD_Custom = 0x100,     // 用户自定义消息类型开始值
    
    /*
     * 用户在中间根据业务需要，添加自身需要的自定义字段
     *
     * AVIMCMD_Custom_Focus,        // 关注
     * AVIMCMD_Custom_UnFocus,      // 取消关注
     */
    
    
    AVIMCMD_Multi = 0x800,              // 多人互动消息类型 ： 2048
    
    AVIMCMD_Multi_Host_Invite,          // 多人主播发送邀请消息, C2C消息 ： 2049
    AVIMCMD_Multi_CancelInteract,       // 已进入互动时，断开互动，Group消息，带断开者的imUsreid参数 ： 2050
    AVIMCMD_Multi_Interact_Join,        // 多人互动方收到AVIMCMD_Multi_Host_Invite多人邀请后，同意，C2C消息 ： 2051
    AVIMCMD_Multi_Interact_Refuse,      // 多人互动方收到AVIMCMD_Multi_Invite多人邀请后，拒绝，C2C消息 ： 2052
    
    // =======================
    // 暂未处理以下
    AVIMCMD_Multi_Host_EnableInteractMic,  // 主播打开互动者Mic，C2C消息 ： 2053
    AVIMCMD_Multi_Host_DisableInteractMic, // 主播关闭互动者Mic，C2C消息 ：2054
    AVIMCMD_Multi_Host_EnableInteractCamera, // 主播打开互动者Camera，C2C消息 ：2055
    AVIMCMD_Multi_Host_DisableInteractCamera, // 主播打开互动者Camera，C2C消息 ： 2056
    // ==========================
    
    
    AVIMCMD_Multi_Host_CancelInvite,            // 取消互动, 主播向发送AVIMCMD_Multi_Host_Invite的人，再发送取消邀请， 已发送邀请消息, C2C消息 ： 2057
    AVIMCMD_Multi_Host_ControlCamera,           // 主动控制互动观众摄像头, 主播向互动观众发送,互动观众接收时, 根据本地摄像头状态，来控制摄像头开关（即控制对方视频是否上行视频）， C2C消息 ： 2058
    AVIMCMD_Multi_Host_ControlMic,              // 主动控制互动观众Mic, 主播向互动观众发送,互动观众接收时, 根据本地MIC状态,来控制摄像头开关（即控制对方视频是否上行音频），C2C消息 ： 2059
    
    
    
    // 中间预留以备多人互动扩展
    
    AVIMCMD_Multi_Custom = 0x1000,          // 用户自定义的多人消息类型起始值 ： 4096
    
    /*
     * 用户在中间根据业务需要，添加自身需要的自定义字段
     *
     * AVIMCMD_Multi_Custom_XXX,
     * AVIMCMD_Multi_Custom_XXXX,
     */
    
};


// 直播中用到的IM消息类型
// 直播过程中只能显示简单的文本消息
// 关于消息的显示尽量做简单，以减少直播过程中IM消息量过大时直播视频不流畅
@protocol AVIMMsgAble <NSObject>

@required
// 在渲染前，先计算渲染的内容
- (void)prepareForRender;

- (NSInteger)msgType;

@end





