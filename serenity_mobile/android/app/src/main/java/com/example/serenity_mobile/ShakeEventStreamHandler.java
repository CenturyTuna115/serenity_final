package com.example.serenity_mobile;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import androidx.localbroadcastmanager.content.LocalBroadcastManager;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.EventChannel.EventSink;

public class ShakeEventStreamHandler implements EventChannel.StreamHandler {
    private final Context context;
    private BroadcastReceiver shakeReceiver;

    public ShakeEventStreamHandler(Context context) {
        this.context = context;
    }

    @Override
    public void onListen(Object arguments, EventSink events) {
        shakeReceiver = new BroadcastReceiver() {
            @Override
            public void onReceive(Context context, Intent intent) {
                events.success("shake_detected");
            }
        };
        
        LocalBroadcastManager.getInstance(context)
            .registerReceiver(shakeReceiver, 
                new IntentFilter("com.example.serenity_mobile.SHAKE_DETECTED"));
    }

    @Override
    public void onCancel(Object arguments) {
        if (shakeReceiver != null) {
            LocalBroadcastManager.getInstance(context)
                .unregisterReceiver(shakeReceiver);
            shakeReceiver = null;
        }
    }
}
