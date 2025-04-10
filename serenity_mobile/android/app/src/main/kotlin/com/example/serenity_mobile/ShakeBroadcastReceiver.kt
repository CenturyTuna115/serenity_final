package com.example.serenity_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class ShakeBroadcastReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "SHAKE_DETECTED") {
            try {
                val activity = context.applicationContext as? MainActivity
                if (activity == null) {
                    Log.e("ShakeReceiver", "Context is not MainActivity")
                    return
                }
                activity.handleShakeEvent()
            } catch (e: Exception) {
                Log.e("ShakeReceiver", "Error handling shake event", e)
            }
        }
    }
}
