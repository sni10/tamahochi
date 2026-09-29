## 1. Экран и письмо

- [x] 1.1 Иконка `icon_about` (ui.txt, 12×12) и константа; пункт ABOUT в сумке (после SETTINGS), режим `about`: B → `feedback_wanted`, C → сумка; экран по спеке; проверка: тесты — B на ABOUT в сумке → режим `about`; B → флаг; C → сумка на ABOUT; рендер PNG — строки влезают
- [x] 1.2 `Game.feedback_mailto()` — `mailto:` с темой и телом (версия `ProjectSettings application/config/version`, `OS.get_model_name()`, `OS.get_name()`, `OS.get_version()`), `uri_encode`; `main._press` → `OS.shell_open`; проверка: тест — ссылка начинается с `mailto:d.strelets.a@gmail.com?subject=Tamahochi%20feedback`, в теле версия; на ПК B открывает почтовый клиент (ручная проверка)

## 2. Версия и приёмка

- [x] 2.1 `release.yml`: шаг Version пишет `config/version` в `project.godot`; проверка: `actionlint`; локально `config/version="0.0.0"`
- [ ] 2.2 Прогон тестов, запуск через MCP; эмулятор — ABOUT → B открывает Gmail с письмом; PLAN.md — пункт About перед B.4
