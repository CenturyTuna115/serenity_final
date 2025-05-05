package com.example.serenity_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.plugin.common.EventChannel

class ShakeDetectionEventChannel(private val context: Context) : EventChannel.StreamHandler {
    private var shakeReceiver: BroadcastReceiver? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        shakeReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action == "com.example.serenity_mobile.SHAKE_DETECTED") {
                    events.success("shake_detected")
                }
            }
        }
        
        LocalBroadcastManager.getInstance(context).registerReceiver(
            shakeReceiver!!,
            IntentFilter("com.example.serenity_mobile.SHAKE_DETECTED")
        )
    }

    override fun onCancel(arguments: Any?) {
        shakeReceiver?.let {
            LocalBroadcastManager.getInstance(context).unregisterReceiver(it)
            shakeReceiver = null
        }
    }
}
