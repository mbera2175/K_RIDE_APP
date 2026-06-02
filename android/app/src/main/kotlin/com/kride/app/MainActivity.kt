package com.kride.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        createDriverNotificationChannel()
        super.onCreate(savedInstanceState)
    }

    private fun createDriverNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "kride_driver_channel",
                "KRide Driver",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Foreground service notifications for KRide driver online status"
                setShowBadge(false)
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
