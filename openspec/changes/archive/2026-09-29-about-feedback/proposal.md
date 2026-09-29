## Why

Перед закрытым тестом (B.6) тестировщикам нужен простой способ написать разработчику, а игре — страница «о программе» с версией, чтобы в отзыве было понятно, о какой сборке речь.

## What Changes

- В сумке — пятый пункт **ABOUT** (после SETTINGS): название, версия, «MADE BY SNI10», «WITH LOVE TO PETS», подсказка «B FEEDBACK».
- B на ABOUT открывает почтовое приложение с готовым письмом на `d.strelets.a@gmail.com`: тема «Tamahochi feedback», в теле — версия игры, модель устройства, ОС и её версия.
- Версия приложения доступна игре во время работы: CI проставляет её не только в APK, но и в `application/config/version` проекта.

## Capabilities

### New Capabilities

### Modified Capabilities
- `game-screens`: добавляется требование «Страница About и отзыв».

## Impact

`scripts/game.gd` (пункт сумки, экран), `scripts/main.gd` (открытие письма), `assets/ui.txt` (иконка `icon_about`), `scripts/sprites.gd`, `.github/workflows/release.yml` (версия в `project.godot`), тесты. Плагин и Android-код не меняются — письмо открывается стандартным `mailto:`.
