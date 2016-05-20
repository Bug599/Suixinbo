package com.tencent.qcloud.suixinbo;

import android.app.Activity;
import android.app.Application;
import android.content.Context;

import com.tencent.qcloud.suixinbo.presenters.InitBusinessHelper;
import com.tencent.qcloud.suixinbo.utils.SxbLogImpl;

import java.util.LinkedList;
import java.util.List;


/**
 * 全局Application
 */
public class QavsdkApplication extends Application {

    private static QavsdkApplication app;
    private static Context context;
    private static List<Activity> activities;
    @Override
    public void onCreate() {
        super.onCreate();
        app = this;
        context = getApplicationContext();
        activities = new LinkedList<>();

        SxbLogImpl.init(getApplicationContext());

        //初始化APP
        InitBusinessHelper.initApp(context);

        //创建AVSDK 控制器类
    }

    public static Context getContext() {
        return context;
    }

    public static QavsdkApplication getInstance(){
        return app;
    }

    public static void addActivity(Activity activity){
        activities.add(activity);
    }

    public static void removeActivity(Activity activity){
        activities.remove(activity);
    }

    public static Activity getTopActivity(){
        if (0 != activities.size()){
            return activities.get(activities.size()-1);
        }

        return null;
    }

    public static void exitApplication(){
        for (Activity activity : activities){
            activity.finish();
        }
    }
}
