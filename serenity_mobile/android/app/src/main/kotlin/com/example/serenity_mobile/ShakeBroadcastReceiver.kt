package com.example.serenity_mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import io.flutter.plugin.common.MethodChannel

class ShakeBroadcastReceiver(private val methodChannel: MethodChannel? = null) : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.example.serenity_mobile.SHAKE_DETECTED") {
            try {
                // Forward shake event via MethodChannel
                methodChannel?.invokeMethod("onShakeDetected", null)
            } catch (e: Exception) {
                Log.e("ShakeReceiver", "Error handling shake event", e)
            }
        }
    }
}
