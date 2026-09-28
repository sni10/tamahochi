## Context

Godot-проект в корне репозитория, рендер `gl_compatibility` (подходит для большинства Android-устройств), ориентация портрет уже задана в `project.godot`. Спрайты — не ресурсы Godot, а `.txt`, их экспорт по умолчанию не включает. Android Studio, SDK и JDK 17 устанавливаются пользователем.

## Goals / Non-Goals

**Goals:** отладочный APK из консоли, запуск на эмуляторе, Android-часть открывается в Android Studio; GDScript редактируется в Rider.
**Non-Goals:** релизная подпись, AAB, иконки/скриншоты стора, плагины.

## Decisions

### D1. Gradle-сборка с шаблоном `android/` сразу
Пресет с `gradle_build/use_gradle_build=true` и установленным шаблоном (Project → Install Android Build Template). Без Gradle APK собирается быстрее, но Kotlin-плагин уведомлений (B.2) всё равно потребует Gradle, а `android/build` — это то, что открывается в Android Studio.
*Альтернатива:* сначала без Gradle — лишний переход позже, выигрыша нет.

### D2. `include_filter="assets/*"` в пресете
Godot экспортирует только ресурсы; `.txt` нужно включить фильтром, иначе на устройстве `Sprites` не найдёт файлы и игра выйдет с ошибкой.

### D3. Что в git
В git: только `export_presets.cfg`. Не в git: `build/` (APK) и весь `android/` — шаблон целиком генерируется Godot (`--install-android-build-template`), внутри 1+ ГБ сборки Gradle и библиотек движка, своих правок в нём нет. Появятся правки (плагин B.2) — пересмотреть. Отладочный keystore — из Editor Settings Godot, в репозиторий не кладём.

### D4. Проверка через adb
Установка и запуск: `adb install -r build/tamahochi-debug.apk`, логи `adb logcat -s godot`. «Перезапуск» — смахнуть из недавних и открыть.

## Risks / Trade-offs

- [Версии SDK/build-tools, которые ждёт Godot 4.7, расходятся с установленными] → ставить через SDK Manager те, что указаны в документации экспорта Godot 4.7.
- [Эмулятор на Intel UHD медленный] → при проблемах проверять на телефоне по USB (отладка по USB).
