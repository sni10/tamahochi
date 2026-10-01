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
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * Цепочка зовов в SharedPreferences (переживает перезагрузку): JSON [{"at" (unix, с), "title", "body"}, ...]
 * по возрастанию "at". Обычный (неточный) будильник на ближайший зов; сработал — уведомление и будильник на следующий.
 */
object Calls {
    private const val PREFS = "tamahochi_notify"
    const val CHANNEL = "calls"
    private const val NOTIFICATION_ID = 1
    const val TAG = "TamahochiNotify"  // adb logcat -s TamahochiNotify godot

    fun save(ctx: Context, json: String) {
        prefs(ctx).edit().putString("calls", json).apply()
        Log.i(TAG, "saved ${JSONArray(json).length()} calls")
    }

    /** Поставить будильник на ближайший сохранённый зов; прошедший момент сработает сразу. */
    fun arm(ctx: Context) {
        val next = load(ctx).firstOrNull() ?: run { Log.i(TAG, "arm: chain empty"); return }
        Log.i(TAG, "arm: ${java.util.Date(next.getLong("at") * 1000)} — ${next.getString("body")}")
        ctx.getSystemService(AlarmManager::class.java)
            .setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.getLong("at") * 1000, alarmIntent(ctx))
    }

    fun cancel(ctx: Context) {
        ctx.getSystemService(AlarmManager::class.java).cancel(alarmIntent(ctx))
        NotificationManagerCompat.from(ctx).cancel(NOTIFICATION_ID)
        prefs(ctx).edit().clear().apply()
        Log.i(TAG, "cancel")
    }

    /** Будильник сработал: показать последний наступивший зов (пропущенные — например, при выключенном
     *  телефоне — не показываем по одному), убрать наступившие и поставить будильник на следующий. */
    fun fire(ctx: Context) {
        val now = System.currentTimeMillis() / 1000 + 1
        val (due, rest) = load(ctx).partition { it.getLong("at") <= now }
        Log.i(TAG, "fire: due ${due.size}, left ${rest.size}")
        save(ctx, JSONArray(rest).toString())
        arm(ctx)
        due.lastOrNull()?.let { show(ctx, it.getString("title"), it.getString("body")) }
    }

    @SuppressLint("MissingPermission")  // без разрешения notify() молча не показывает — это и нужно
    private fun show(ctx: Context, title: String, body: String) {
        ensureChannel(ctx)
        val manager = NotificationManagerCompat.from(ctx)
        if (!manager.areNotificationsEnabled()) run { Log.w(TAG, "show: notifications disabled — $body"); return }
        Log.i(TAG, "show: $title — $body")
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

    private fun load(ctx: Context): List<JSONObject> {
        val arr = JSONArray(prefs(ctx).getString("calls", null) ?: return emptyList())
        return List(arr.length()) { arr.getJSONObject(it) }
    }

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

/** Будильник сработал — показать зов и завести следующий. */
class CallReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) = Calls.fire(ctx)
}

/** После перезагрузки будильники сброшены — поставить ближайший сохранённый зов заново. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            Log.i(Calls.TAG, "boot")
            Calls.arm(ctx)
        }
    }
}
