package com.tencent.qcloud.suixinbo.presenters.viewinface;


/**
 * 登录回调
 */
public interface LoginView extends MvpView{

    void LoginSucc();

    void LoginFail();
}
