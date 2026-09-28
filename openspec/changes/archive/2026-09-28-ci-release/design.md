## Context

Проект — Godot 4.7.2 в корне репозитория `sni10/tamahochi` (GitHub), экспорт Android уже настроен локально (`export_presets.cfg`, Gradle-шаблон ставится флагом `--install-android-build-template`). Теги `v0.0.1`, `v0.0.2` существуют.

## Goals / Non-Goals

**Goals:** тесты на PR; релиз с подписанным APK на каждый merge в `main`.
**Non-Goals:** AAB и выкладка в Google Play (B.6), сборка под ПК, changelog сверх `--generate-notes`.

## Decisions

### D1. Один workflow, две job
`.github/workflows/release.yml`: `test` (PR и push в `main`) и `release` (`needs: test`, только push в `main`). Раннер `ubuntu-latest`: там уже есть Android SDK (`$ANDROID_HOME`); JDK 17 — `actions/setup-java` (temurin).

### D2. Godot и шаблоны
Скачиваем `Godot_v4.7.2-stable_linux.x86_64.zip` и `Godot_v4.7.2-stable_export_templates.tpz` с релизов godotengine на GitHub, шаблоны распаковываем в `~/.local/share/godot/export_templates/4.7.2.stable/`. Оба кэшируются `actions/cache` по версии (архив шаблонов ~1,3 ГБ). Пути к SDK/JDK — в `~/.config/godot/editor_settings-4.7.tres`, записывается в CI.

### D3. Версия
`fetch-depth: 0`, последний тег `git describe --tags --abbrev=0 --match 'v*'` → патч +1. versionCode = `github.run_number` (строго растёт у этого workflow). Оба подставляются в `export_presets.cfg` (`version/name`, `version/code`) на лету, в репозитории — заглушки.

### D4. Подпись
Keystore создаётся один раз `keytool` из JDK 17 (RSA 2048, 10000 дней) — вне репозитория, у владельца. Секреты: `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD`. В CI декодируется во временный файл, Godot получает его через переменные `GODOT_ANDROID_KEYSTORE_RELEASE_PATH/USER/PASSWORD`; экспорт `--export-release`.

### D5. Публикация
`gh release create vX.Y.Z build/tamahochi-vX.Y.Z.apk --target $GITHUB_SHA --generate-notes` с `GITHUB_TOKEN` (`permissions: contents: write`) — создаёт тег и релиз; архивы исходников GitHub добавляет сам.

## Risks / Trade-offs

- [Потеря keystore] → обновления поверх станут невозможны (и в Google Play тоже) → хранить копию ключа и паролей вне ПК; в итоговом сообщении — напоминание.
- [Два merge подряд одновременно] → оба возьмут один тег → `concurrency: release` без отмены, второй ждёт первый.
- [Скачивание 1,3 ГБ шаблонов] → кэш; первый прогон долгий.
- [Версии Android SDK на раннере отличаются от локальных] → Gradle докачивает нужную платформу (лицензии на раннере приняты).
