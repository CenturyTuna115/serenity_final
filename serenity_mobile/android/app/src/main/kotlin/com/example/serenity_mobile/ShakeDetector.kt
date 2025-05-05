package com.example.serenity_mobile

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlin.math.abs

class ShakeDetector(
    private val context: Context,
    private val onShake: () -> Unit
) : SensorEventListener {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private var lastShakeTime = 0L
    private val shakeThreshold = 15f
    private var lastX = 0f
    private var lastY = 0f
    private var lastZ = 0f

    fun start() {
        sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let { sensor ->
            sensorManager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    fun stop() {
        sensorManager.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        event?.let {
            val currentTime = System.currentTimeMillis()
            if (currentTime - lastShakeTime > 1000) {
                val deltaX = abs(it.values[0] - lastX)
                val deltaY = abs(it.values[1] - lastY)
                val deltaZ = abs(it.values[2] - lastZ)

                if (deltaX > shakeThreshold || deltaY > shakeThreshold || deltaZ > shakeThreshold) {
                    lastShakeTime = currentTime
                    onShake()
                }

                lastX = it.values[0]
                lastY = it.values[1]
                lastZ = it.values[2]
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
