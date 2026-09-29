## 1. Настройки и зов

- [x] 1.1 `Settings.calls_enabled` (по умолчанию true, в `to_dict/from_dict`); проверка: тесты — старый `settings.json` → true, круговая сериализация
- [x] 1.2 Экран SETTINGS по D1: поля FROM/TO/CALLS/SOUND, A по кругу, B на CALLS переключает и ставит `settings_changed`, B на SOUND ставит `open_notify_settings_wanted`, подсказки по полю, `settings_note`; проверка: тесты — B на CALLS → OFF и сохранение; A четыре раза → снова FROM; B на SOUND → флаг; рендер PNG экрана — строки не налезают
- [x] 1.3 `main._leave()` по D2 (зов выключен → отмена, `pending_call_at = 0`); `main._press` — открытие настроек и `NOT HERE` по D3; проверка: headless-сценарий как в B.2 — при CALLS OFF в логе «notify cancelled», в `save.json` `pending_call_at` = 0; на ПК SOUND → надпись NOT HERE

## 2. Android

- [x] 2.1 Плагин: `open_settings()` по D3, `Notifier.open_settings()`; проверка: на эмуляторе (данные очищены, уведомлений не было) SETTINGS → SOUND → B открывает экран канала «Pet calls», назад — игра; на Xiaomi (HyperOS) — открывается экран уведомлений Tamahochi (канала или приложения) — проверено пользователем на эмуляторе (API 35): SOUND открывает системные настройки, CALLS переключается

## 3. Приёмка

- [x] 3.1 Полный прогон тестов, запуск через MCP; PLAN.md B.3 — переписать под урезанный вариант (почему нет нативного экрана и своих звука/вибрации)
