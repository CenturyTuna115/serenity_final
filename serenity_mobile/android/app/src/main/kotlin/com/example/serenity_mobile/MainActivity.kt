package com.example.serenity_mobile

import android.content.Intent
import android.content.IntentFilter
import android.util.Log
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.serenity_mobile/service"
    private lateinit var broadcastReceiver: ShakeBroadcastReceiver
    
    override fun getFlutterEngine(): FlutterEngine {
        return super.getFlutterEngine() ?: throw IllegalStateException("FlutterEngine not initialized")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    startService(Intent(this, ShakeDetectionService::class.java))
                    result.success(null)
                }
                "stopService" -> {
                    stopService(Intent(this, ShakeDetectionService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        broadcastReceiver = ShakeBroadcastReceiver()
        LocalBroadcastManager.getInstance(this).registerReceiver(
            broadcastReceiver,
            IntentFilter("SHAKE_DETECTED")
        )
    }

    override fun onPause() {
        super.onPause()
        LocalBroadcastManager.getInstance(this).unregisterReceiver(broadcastReceiver)
    }

    fun handleShakeEvent() {
        try {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, CHANNEL).invokeMethod("onShakeDetected", null)
            } ?: run {
                Log.e("MainActivity", "FlutterEngine not initialized")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "Error handling shake event", e)
        }
    }
}
