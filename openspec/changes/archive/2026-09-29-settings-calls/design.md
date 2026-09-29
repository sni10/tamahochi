## Context

Экран SETTINGS (`Game._draw_settings`) — поля FROM и TO (`settings_field` 0/1), строка NOW; открывается из сумки. Зов планирует `main._leave()` через `Calls.plan` → `Notifier.schedule`; канал уведомлений «Pet calls» создаётся в плагине при первом показе.

## Goals / Non-Goals

**Goals:** выключить зов и попасть в системные настройки звука, не выходя из стиля ЖК.
**Non-Goals:** нативный экран настроек, свои звук/вибрация, восстановление покупок (B.4).

## Decisions

### D1. Поля экрана
`settings_field` 0..3: FROM, TO, CALLS, SOUND. A — следующее по кругу. Раскладка на ЖК (между пунктирами y 36–131): `QUIET HOURS` 42, FROM 54, TO 72 (часы крупно ×2), `CALLS ON|OFF` 94, `SOUND` 104, `NOW ЧЧ:ММ` 120. Подсказка внизу зависит от поля: FROM/TO — `A NEXT  B +1`, CALLS — `A NEXT  B SET` (`ON/OFF` не влезает в 72 px), SOUND — `A NEXT  B OPEN`.

### D2. Выключенный зов
`Settings.calls_enabled` (по умолчанию `true`, в `settings.json`). В `main._leave()`: если выключен — `Notifier.cancel()` и `pending_call_at = 0` (нет плана — нет штрафа), иначе как сейчас. Логику кладём в `main.gd`, а не в `Calls.plan`, — `plan` остаётся чистым расчётом.

### D3. Открытие системных настроек
Плагин: `@UsedByGodot open_settings(): Boolean` — создаёт канал «Pet calls» (идемпотентно, та же функция, что при показе), затем `Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS` с `EXTRA_APP_PACKAGE` и `EXTRA_CHANNEL_ID="calls"` (API 26+; ниже — `ACTION_APP_NOTIFICATION_SETTINGS`), `FLAG_ACTIVITY_NEW_TASK`. `Notifier.open_settings() -> bool` — `false` без плагина (ПК). `Game` не зовёт Android сам: B на SOUND ставит флаг `open_notify_settings_wanted`, `main._press` вызывает `Notifier.open_settings()`; при `false` (ПК) ставит `game.settings_note = "NOT HERE"` — надпись на месте NOW, пропадает при следующем нажатии.

## Risks / Trade-offs

- [Производители меняют экраны настроек (Xiaomi HyperOS, раньше MIUI)] → `ACTION_CHANNEL_NOTIFICATION_SETTINGS` может открыть общий экран уведомлений приложения — приемлемо, звук настраивается и там. Проверяем на Redmi Note Pro 5G с HyperOS.
- [Экран настроек тесный] → раскладка D1 проверяется рендером PNG.
