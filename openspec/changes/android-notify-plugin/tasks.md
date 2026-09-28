## 1. Kotlin-плагин

- [ ] 1.1 `android_plugin/`: Gradle-проект библиотеки (обёртка 8.11.1, AGP 8.6.1, Kotlin 2.1.21, JDK 17, compileSdk 36, minSdk 24), зависимость Godot `compileOnly`, `.gitignore` для `build/`, `.gradle/`; проверка: `gradlew assembleRelease assembleDebug` даёт два AAR
- [ ] 1.2 `TamahochiNotifyPlugin` (schedule / cancel / sdk_int), `CallReceiver`, `BootReceiver`, манифест (meta-data v2, receivers, `RECEIVE_BOOT_COMPLETED`, `POST_NOTIFICATIONS`), иконка уведомления, канал `calls` — по D1–D3; проверка: AAR собирается, `apkanalyzer`/`aapt2 dump xmltree` показывает meta-data и receivers в итоговом APK

## 2. Подключение к Godot

- [ ] 2.1 `addons/tamahochi_notify/` (plugin.cfg, export_plugin.gd) по D4, включить в `project.godot`; `export_presets.cfg`: `permissions/post_notifications=true`; проверка: экспорт APK проходит, в APK есть классы плагина (`TamahochiNotifyPlugin`)
- [ ] 2.2 Экран разрешения по D5 (режим `notify_ask`, флаг `Settings.notify_asked`); проверка: тесты — на не-Android флаг ставится без показа экрана; режим `notify_ask`: B → флаг, переход дальше; старый `settings.json` → флаг false

## 3. Проверка на эмуляторе

- [ ] 3.1 Первый запуск (данные очищены): экран объяснения → B → системный запрос → разрешить; повторный запуск — экрана нет; проверка: скриншоты
- [ ] 3.2 Свернуть с больным питомцем → через ~15 мин уведомление в шторке с текстом из `Calls.text`; нажатие открывает игру; проверка: `adb shell dumpsys notification | grep tamahochi`, скриншот шторки
- [ ] 3.3 Свернуть и вернуться до зова → уведомления нет; свернуть и перезагрузить эмулятор → уведомление приходит; отказ в разрешении → игра работает, уведомлений нет; проверка: `dumpsys alarm` / `dumpsys notification`

## 4. CI и план

- [ ] 4.1 `release.yml`: сборка AAR перед экспортом; проверка: `actionlint`; после merge — релиз с плагином (класс в APK)
- [ ] 4.2 PLAN.md B.2 — отметить доставку; README-заметка про автозапуск на Xiaomi/Huawei — в PLAN.md
