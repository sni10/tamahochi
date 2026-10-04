## Why

На Xiaomi Redmi 9C NFC (2020, MIUI 12, Android 10) APK не устанавливается: у телефона 64-битный процессор, но 32-битная сборка Android, а наш APK содержит только arm64-v8a и x86_64. Таких бюджетных телефонов много.

## What Changes

- В сборку Android добавляется архитектура **armeabi-v7a** (32-битный ARM). APK из релизов GitHub становится примерно на 40–50 МБ больше; в Google Play (AAB, B.6) каждый телефон скачает только свою архитектуру.

## Capabilities

### New Capabilities

### Modified Capabilities
- `android-build`: добавляется «Поддержка 32-битных устройств».

## Impact

`export_presets.cfg` (`architectures/armeabi-v7a=true`). Код игры и плагин уведомлений (чистый Kotlin, без нативных библиотек) не меняются.
