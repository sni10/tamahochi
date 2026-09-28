## 1. Окружение (делает пользователь)

- [x] 1.1 Android Studio: в SDK Manager — Platform-Tools, Build-Tools и платформа, которые требует Godot 4.7; создать эмулятор (AVD); проверка: `adb version` работает, эмулятор загружается
- [x] 1.2 JDK 17; в Godot Editor Settings → Export → Android указать пути к SDK и JDK; проверка: в редакторе нет предупреждения о путях Android

## 2. Экспорт

- [x] 2.1 `export_presets.cfg`: пресет «Android» — пакет `com.sni10.tamahochi`, имя Tamahochi, портрет, `include_filter="assets/*"`, `export_path="build/tamahochi-debug.apk"`, Gradle-сборка; `.gitignore`: `build/`; проверка: пресет виден в Project → Export
- [x] 2.2 Установить Android Build Template (`android/`, флаг `--install-android-build-template`), `android/` целиком в `.gitignore` (генерируется, 1+ ГБ); проверка: Gradle-сборка шаблона прошла при экспорте, `git status` не показывает `android/`
- [x] 2.3 Сборка из консоли `godot --headless --path . --export-debug "Android" build/tamahochi-debug.apk`; проверка: файл появился, `git status` его не показывает
- [x] 2.4 `project.godot`: `textures/vram_compression/import_etc2_astc=true` — без него Godot отказывается экспортировать под Android; проверка: экспорт проходит (предупреждение об отсутствии иконки — B.6)

## 3. Проверка на эмуляторе

- [x] 3.1 `adb install -r build/tamahochi-debug.apk` и запуск; проверка: пакет `com.sni10.tamahochi` установлен, экран выбора с 5 видами, в `adb logcat -s godot` нет ошибок ассетов, поворот экрана не меняет ориентацию
- [x] 3.2 Касания и сохранение: выбрать BLOB касанием, свернуть (Home), убить процесс (`am force-stop`), открыть; проверка: тот же питомец, досчёт времени (вылупился за время закрытия), `save.json` в данных приложения. Кормление новорождённого по правилам — отказ (сытость ≥ 95), поэтому «сытость учтена» проверяется на голодном питомце позже
- [x] 3.2a Кнопки A/B/C масштабируются от ширины экрана (база — окно ПК 540 px): на телефоне 1440 px они были ~5% ширины; проверка: скриншот эмулятора — кнопки крупные, на ПК размер прежний
- [x] 3.3 PLAN.md: в B.1 отметить проверку на Android, добавить команды сборки и установки
