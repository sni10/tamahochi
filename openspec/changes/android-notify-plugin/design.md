## Context

`scripts/notifier.gd` вызывает синглтон `TamahochiNotify` (`schedule(at: int, title, body)`, `cancel()`), если он есть, иначе пишет в лог. Экспорт Android — Gradle-сборка с шаблоном `android/` (генерируется, в git не хранится). Версии шаблона Godot 4.7.2: AGP 8.6.1, Kotlin 2.1.21, Gradle 8.11.1, JDK 17, compileSdk/targetSdk 36, minSdk 24.

## Goals / Non-Goals

**Goals:** один зов в системе, переживает выгрузку и перезагрузку; сборка плагина воспроизводима локально и в CI.
**Non-Goals:** точные будильники (решено — примерно), несколько уведомлений, свой звук/вибрация (B.3), iOS.

## Decisions

### D1. Плагин Godot Android v2 в `android_plugin/`
Отдельный Gradle-проект библиотеки: класс `TamahochiNotifyPlugin : GodotPlugin`, `getPluginName() = "TamahochiNotify"`, методы `@UsedByGodot schedule(atSec: Long, title: String, body: String)` и `cancel()`. Зависимость `compileOnly("org.godotengine:godot:4.7.2.stable")` (Maven Central, проверено: последняя версия — 4.7.2.stable) и `androidx.core:core`. Регистрация — `<meta-data android:name="org.godotengine.plugin.v2.TamahochiNotify" android:value="...TamahochiNotifyPlugin"/>` в манифесте библиотеки. Gradle-обёртка — своя (8.11.1), версии — как у шаблона Godot.
*Альтернатива:* сторонний плагин уведомлений — зависимость от чужого кода и его совместимости с 4.7; своих ~150 строк проще.

### D2. Будильник и показ
`AlarmManager.setAndAllowWhileIdle(RTC_WAKEUP, atMs, pi)` — неточный, без разрешения на точные будильники. `PendingIntent` на `CallReceiver` (`BroadcastReceiver`, не экспортируется) с заголовком и текстом в extras, `FLAG_IMMUTABLE | FLAG_UPDATE_CURRENT` и один requestCode — новый зов заменяет прежний. Receiver показывает уведомление через `NotificationCompat` в канале `calls` (создаётся при первом показе, важность `IMPORTANCE_HIGH` — всплывает баннером сверху экрана, со звуком, и остаётся в шторке), маленькая иконка — векторный drawable в ресурсах плагина, `contentIntent` — `getLaunchIntentForPackage`, `setAutoCancel(true)`. `cancel()` — `alarmManager.cancel(pi)` + `NotificationManagerCompat.cancel(id)` + очистка сохранённого зова.

### D3. Перезагрузка
`schedule` сохраняет момент/заголовок/текст в `SharedPreferences`; `BootReceiver` (`BOOT_COMPLETED`, разрешение `RECEIVE_BOOT_COMPLETED`) перепланирует сохранённый зов, прошедший — показывает сразу. После показа запись удаляется.

### D4. Подключение к экспорту
Редакторный плагин `addons/tamahochi_notify/` (`plugin.cfg`, `export_plugin.gd` с `EditorExportPlugin`): `_supports_platform` — Android, `_get_android_libraries` — путь к `android_plugin/build/outputs/aar/…-release.aar` (для debug-экспорта — debug AAR), `_get_android_dependencies` — `androidx.core:core:<версия>`. Включается в `project.godot` (`[editor_plugins]`). AAR — артефакт сборки, в git не хранится; перед экспортом: `android_plugin/gradlew assembleRelease assembleDebug` (локально и шагом в CI).

### D5. Разрешение
В пресет — `permissions/post_notifications=true`. Экран объяснения — новый режим `"notify_ask"` в `Game`: текст на ЖК («I WILL CALL YOU / WHEN I NEED YOU» и «B OK»), B → `OS.request_permission("android.permission.POST_NOTIFICATIONS")`, режим → `select`/`idle`. Показ один раз: флаг `notify_asked` в `Settings` (`settings.json`). Показывается только если `OS.get_name() == "Android"` и API ≥ 33 (узнаём через плагин: метод `sdk_int()`), иначе сразу помечается как показанный.

## Risks / Trade-offs

- [Производители (Xiaomi, Huawei) убивают будильники фоновых приложений] → в игре ничего не просим: неточный будильник через `AlarmManager` — стандартный путь, на большинстве телефонов работает. Подсказку «уведомления не приходят? разрешите автозапуск» — в описание в Google Play / FAQ (B.6) и, возможно, на экран настроек (B.3), только если на реальных тестерах всплывёт.
- [Проверка на эмуляторе требует ждать ~15 мин реального времени (зов с поводом «уже есть»)] → ждём в фоне; отладочных сокращений в код не добавляем.
