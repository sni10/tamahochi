## Why

Игровая логика уже решает, когда и с каким текстом позвать игрока (`Calls.plan`, `Notifier`), но на Android уведомление не приходит: в Godot нет встроенных локальных уведомлений. Вторая часть B.2 — Android-доставка, иначе «зов игрока» не работает.

## What Changes

- Kotlin-плагин Godot (Android plugin v2) `TamahochiNotify` в `android_plugin/`: `schedule(at, title, body)` ставит обычный (не точный) будильник Android, по нему показывается системное уведомление; `cancel()` снимает и будильник, и показанное уведомление.
- Нажатие на уведомление открывает игру. Запланированный зов переживает перезагрузку телефона.
- Разрешение на уведомления (Android 13+): один раз при первом запуске — экран с объяснением на ЖК, затем системный запрос; отказ не ломает игру.
- Сборка: AAR плагина собирается Gradle-ом; подключается в экспорт через редакторный плагин `addons/tamahochi_notify/`; CI собирает AAR перед экспортом APK.

## Capabilities

### New Capabilities
- `android-notifications`: доставка зова на Android — системное уведомление в запланированный момент, отмена, открытие игры, перезагрузка, разрешение.

### Modified Capabilities

## Impact

- Новое: `android_plugin/` (Gradle-проект Kotlin, AAR), `addons/tamahochi_notify/` (plugin.cfg, export_plugin.gd), экран разрешения в `game.gd`, флаг в `settings.json`.
- `project.godot`: включённый редакторный плагин; `export_presets.cfg`: разрешение `POST_NOTIFICATIONS`.
- `.github/workflows/release.yml`: шаг сборки AAR.
- `Notifier` (`scripts/notifier.gd`) уже вызывает синглтон `TamahochiNotify` — меняться не должен.
