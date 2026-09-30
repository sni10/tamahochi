## 1. Реализация

- [x] 1.1 `Settings.time_speed` (по умолчанию 1, в `settings.json`); `icon_time` (ui.txt 12×12); в `Game`: флаг `tester`, пункт TIME в сумке только при `tester`, B — следующая скорость (1/10/60/600) → `speed` и `settings_changed`; значок «X<скорость>» в комнате; проверка: тесты — без `tester` в сумке 5 пунктов и TIME недоступен; с `tester` B на TIME: 1 → 10 → 60 → 600 → 1, сохранение; значок в комнате при ×10 и нет при ×1; старый `settings.json` → 1
- [x] 1.2 `main.gd`: `tester = OS.is_debug_build() or OS.has_feature("tester")`; скорость = `--speed`, иначе `settings.time_speed` (только при `tester`); `export_presets.cfg`: `custom_features="tester"`; проверка: рендер PNG сумки и комнаты; на эмуляторе TIME виден, ×60 ускоряет — проверено пользователем на эмуляторе

## 2. Приёмка

- [x] 2.1 Прогон тестов, MCP; PLAN.md — раздел «тестовые сборки» и пункт в B.6 «снять метку `tester` для продакшена»
