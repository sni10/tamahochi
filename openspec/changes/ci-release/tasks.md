## 1. Ключ подписи

- [ ] 1.1 Создать release-keystore `keytool` из JDK 17 вне репозитория (`%USERPROFILE%\.tamahochi\release.keystore`), случайный пароль; проверка: `keytool -list` показывает алиас `tamahochi`, `git status` чист
- [ ] 1.2 Секреты `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_ALIAS`, `ANDROID_KEYSTORE_PASSWORD` в репозитории (с подтверждения пользователя — `gh secret set`); проверка: `gh secret list` показывает три секрета

## 2. Workflow

- [ ] 2.1 `.github/workflows/release.yml`: job `test` — setup Godot (кэш), `--import`, `run_tests.gd`; триггеры PR и push в `main`; проверка: `gh workflow view` / локальная сверка YAML (`actionlint`, если доступен)
- [ ] 2.2 Job `release` (`needs: test`, push в `main`, `concurrency: release`): JDK 17, шаблоны (кэш), editor settings, версия по D3, keystore по D4, `--install-android-build-template --export-release`, `gh release create` по D5; без секрета — явная ошибка
- [ ] 2.3 `export_presets.cfg`: `version/code`, `version/name` — заглушки для CI; проверка: локальная сборка по-прежнему проходит

## 3. Проверка

- [ ] 3.1 Прогон на ветке через `workflow_dispatch` (без публикации) или первый PR → зелёный `test`; после merge — релиз `v0.0.3` с `tamahochi-v0.0.3.apk` и исходниками; проверка: `gh release view v0.0.3`
- [ ] 3.2 APK из релиза ставится на эмулятор поверх — `adb install -r`, `dumpsys package` показывает versionName `0.0.3`
- [ ] 3.3 PLAN.md: раздел про релизы — как выпускается версия, где ключ, что будет при его потере
