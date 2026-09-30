package ru.historycoffee.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    /**
     * Отдельные каналы уведомлений: служебные (ответ на обращение) и новости и акции (реклама —
     * только с согласия гостя). Гость может выключить любой канал в настройках Android отдельно.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        manager.createNotificationChannel(
            NotificationChannel("service", "Ответы на обращения", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Ответ кофейни на вашу жалобу, предложение или благодарность"
            },
        )
        manager.createNotificationChannel(
            NotificationChannel("news", "Новости и акции", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Новинки меню, события и акции — только если вы дали на это согласие"
            },
        )
    }
}
