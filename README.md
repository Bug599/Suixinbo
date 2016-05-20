# 随心播
新版本随心播经过重构，完善了功能，处理了大量的异常情况，请开发者在编码过程中注意
异常情况包括如下：
1. 退后台恢复 ：android后台进程不被杀掉，可正常恢复，画面/声音正常；
2. 闹钟 ：android直播过程中有闹钟，关闭闹钟返回直播，观众和主播画面/声音正常
3. 播放音频中断：使用QQ音乐后台播放，再进入，声音正常
4. 后台播放视频中断：优酷播放视频，然后再进随心播，正常
5. 视频通话中断 ：中断后可正常恢复直播
6. 语音电话中断：ＱＱ语音电话，进入直播正常
7. 电话中断: 手机通话中断，前台挂接电话，后台挂接电话均正常
8. android杀掉进程后，<90S,再创建直播，在直播间的观众可以正常恢复声音/画面；
9. android杀掉进程后，>90S，后台自动关闭房间

随心播的Spear的配置参见图片
iOS：  https://raw.githubusercontent.com/zhaoyang21cn/Suixinbo/master/QQ%E6%88%AA%E5%9B%BE20160520170339.jpg
Android：  https://raw.githubusercontent.com/zhaoyang21cn/Suixinbo/master/QQ%E6%88%AA%E5%9B%BE20160520170326.jpg
