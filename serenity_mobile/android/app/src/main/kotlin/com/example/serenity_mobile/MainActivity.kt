package com.example.serenity_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.util.Log
import androidx.localbroadcastmanager.content.LocalBroadcastManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.serenity_mobile/service"
    private lateinit var methodChannel: MethodChannel
    private lateinit var shakeDetector: ShakeDetector
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "shake_detection_channel",
                "Shake Detection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Used for emergency shake detection"
            }
            val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize and register MethodChannel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "onShake" -> {
                    // Handle shake event if needed
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        // Register EventChannel
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, 
            "com.example.serenity_mobile/shake_events").setStreamHandler(
                ShakeDetectionEventChannel(this)
            )
    }

    override fun onResume() {
        super.onResume()
        shakeDetector = ShakeDetector(this) {
            methodChannel.invokeMethod("onShake", null)
        }
        shakeDetector.start()
    }

    override fun onPause() {
        super.onPause()
        shakeDetector.stop()
    }
}
