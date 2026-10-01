## ADDED Requirements

### Requirement: Поддержка 32-битных устройств
APK SHALL содержать нативные библиотеки для armeabi-v7a наряду с arm64-v8a (и x86_64 для эмулятора), чтобы устанавливаться на телефоны с 32-битной сборкой Android.

#### Scenario: Redmi 9C
- **WHEN** APK устанавливается на Xiaomi Redmi 9C NFC (MIUI 12, Android 10, 32-битная система)
- **THEN** установка проходит, игра запускается

#### Scenario: Состав APK
- **WHEN** собран релизный APK
- **THEN** в нём есть `lib/armeabi-v7a/` и `lib/arm64-v8a/`
