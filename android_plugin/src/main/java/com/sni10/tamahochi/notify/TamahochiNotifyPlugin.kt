package com.sni10.tamahochi.notify

import android.content.ActivityNotFoundException
import android.content.Intent
import android.os.Build
import android.provider.Settings
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot

/** Синглтон `TamahochiNotify` для GDScript (scripts/notifier.gd). */
class TamahochiNotifyPlugin(godot: Godot) : GodotPlugin(godot) {

    override fun getPluginName() = "TamahochiNotify"

    /** Запланировать зов на момент [atSec] (unix-время, секунды); прежний заменяется. */
    @UsedByGodot
    fun schedule(atSec: Long, title: String, body: String) {
        val ctx = activity?.applicationContext ?: return
        Calls.save(ctx, atSec * 1000, title, body)
        Calls.arm(ctx)
    }

    /** Снять запланированный зов и убрать показанное уведомление. */
    @UsedByGodot
    fun cancel() {
        activity?.applicationContext?.let { Calls.cancel(it) }
    }

    /** Версия Android: экран разрешения нужен только с API 33. */
    @UsedByGodot
    fun sdk_int(): Int = Build.VERSION.SDK_INT

    /** Системные настройки уведомлений игры (звук, вибрация); false — открыть нечем. */
    @UsedByGodot
    fun open_settings(): Boolean {
        val act = activity ?: return false
        Calls.ensureChannel(act)
        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, act.packageName)
                .putExtra(Settings.EXTRA_CHANNEL_ID, Calls.CHANNEL)
        } else {
            Intent("android.settings.APP_NOTIFICATION_SETTINGS")
                .putExtra("app_package", act.packageName)
                .putExtra("app_uid", act.applicationInfo.uid)
        }
        // Без resolveActivity: на Android 11+ видимость пакетов может скрыть системный экран настроек.
        act.runOnUiThread {
            try {
                act.startActivity(intent)
            } catch (_: ActivityNotFoundException) {
                // экран настроек пропал между проверкой и открытием — ничего не делаем
            }
        }
        return true
    }
}
