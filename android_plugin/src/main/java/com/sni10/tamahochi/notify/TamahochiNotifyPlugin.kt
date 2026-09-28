package com.sni10.tamahochi.notify

import android.os.Build
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
}
