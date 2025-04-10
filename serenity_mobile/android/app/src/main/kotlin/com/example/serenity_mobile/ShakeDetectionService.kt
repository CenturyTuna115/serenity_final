package com.example.serenity_mobile

import android.app.Service
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.IBinder
import android.os.PowerManager
import kotlin.math.abs

class ShakeDetectionService : Service(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private lateinit var wakeLock: PowerManager.WakeLock
    private var lastShakeTime: Long = 0
    private val shakeThreshold = 15f
    private var lastX = 0f
    private var lastY = 0f
    private var lastZ = 0f

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "SerenityApp::ShakeDetectionWakeLock"
        )
        wakeLock.acquire(10*60*1000L /*10 minutes*/)
        startService()
    }

    private fun startService() {
        // Background service implementation
        sensorManager.registerListener(
            this,
            sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER),
            SensorManager.SENSOR_DELAY_NORMAL
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        sensorManager.registerListener(
            this,
            sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER),
            SensorManager.SENSOR_DELAY_NORMAL
        )
        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        sensorManager.unregisterListener(this)
        if (wakeLock.isHeld) {
            wakeLock.release()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onSensorChanged(event: SensorEvent?) {
        event?.let {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastShakeTime > 1000) { // 1 second cooldown
                val deltaX = abs(it.values[0] - lastX)
                val deltaY = abs(it.values[1] - lastY)
                val deltaZ = abs(it.values[2] - lastZ)

                if (deltaX > shakeThreshold || deltaY > shakeThreshold || deltaZ > shakeThreshold) {
                    lastShakeTime = currentTime
                    // Broadcast shake event to Flutter
                    sendBroadcast(Intent("SHAKE_DETECTED"))
                }

                lastX = it.values[0]
                lastY = it.values[1]
                lastZ = it.values[2]
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
