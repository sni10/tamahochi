package com.sni10.tamahochi.notify

import android.annotation.SuppressLint
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Один зов в системе: момент/заголовок/текст в SharedPreferences (переживают перезагрузку),
 * обычный (неточный) будильник, по нему — уведомление.
 */
object Calls {
    private const val PREFS = "tamahochi_notify"
    const val CHANNEL = "calls"
    private const val NOTIFICATION_ID = 1

    fun save(ctx: Context, atMs: Long, title: String, body: String) {
        prefs(ctx).edit().putLong("at", atMs).putString("title", title).putString("body", body).apply()
    }

    /** Поставить будильник на сохранённый зов; прошедший момент сработает сразу. */
    fun arm(ctx: Context) {
        val at = prefs(ctx).getLong("at", 0)
        if (at == 0L) return
        ctx.getSystemService(AlarmManager::class.java)
            .setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, alarmIntent(ctx))
    }

    fun cancel(ctx: Context) {
        ctx.getSystemService(AlarmManager::class.java).cancel(alarmIntent(ctx))
        NotificationManagerCompat.from(ctx).cancel(NOTIFICATION_ID)
        prefs(ctx).edit().clear().apply()
    }

    @SuppressLint("MissingPermission")  // без разрешения notify() молча не показывает — это и нужно
    fun show(ctx: Context) {
        val p = prefs(ctx)
        val title = p.getString("title", null) ?: return
        val body = p.getString("body", "") ?: ""
        p.edit().clear().apply()
        ensureChannel(ctx)
        val manager = NotificationManagerCompat.from(ctx)
        if (!manager.areNotificationsEnabled()) return
        val open = ctx.packageManager.getLaunchIntentForPackage(ctx.packageName)
        val notification = NotificationCompat.Builder(ctx, CHANNEL)
            .setSmallIcon(R.drawable.ic_tamahochi_call)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(
                PendingIntent.getActivity(
                    ctx, 0, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
            )
            .build()
        try {
            manager.notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // разрешение отозвали между проверкой и показом — просто без уведомления
        }
    }

    /** Канал «Pet calls»: звук и вибрацию в нём настраивает пользователь (создание идемпотентно). */
    fun ensureChannel(ctx: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            ctx.getSystemService(NotificationManager::class.java).createNotificationChannel(
                NotificationChannel(CHANNEL, "Pet calls", NotificationManager.IMPORTANCE_HIGH)
            )
        }
    }

    private fun alarmIntent(ctx: Context): PendingIntent = PendingIntent.getBroadcast(
        ctx, 0, Intent(ctx, CallReceiver::class.java),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

/** Будильник сработал — показать зов. */
class CallReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) = Calls.show(ctx)
}

/** После перезагрузки будильники сброшены — поставить сохранённый зов заново. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) Calls.arm(ctx)
    }
}
