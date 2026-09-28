## Context

Прототип — ~1200 строк Python в 10 модулях (`state`, `decay`, `evolution`, `sprites`, `lcd`, `game`, `shop`, `player`, `settings`, `storage`, `app`, `main`). Логика уже отделена от отрисовки: `Game` рисует в абстрактный `lcd` через `clear/set/hline/blit/erase/flush`, `decay` — чистые функции над `PetState`. Это позволяет переводить модули почти построчно. Godot 4.7.2 установлен, доступен через MCP (запуск, отладочный вывод, сцены). Мотивация — proposal.md, требования — specs/.

## Goals / Non-Goals

**Goals:**
- Построчный перевод: у каждого Python-модуля есть очевидный GDScript-двойник с теми же константами и именами функций — чтобы правки баланса в прототипе переносились механически.
- Автоматическая проверка паритета симуляции с Python и совпадения ассетов.
- Играбельно на ПК (окно) и готово к экспорту на Android без изменений кода.

**Non-Goals:**
- Экспорт APK/AAB, подпись, иконки (B.6), уведомления (B.2), биллинг/реклама (B.4).
- Любые изменения правил, баланса и спрайтов.
- Редактор спрайтов, импорт в PNG, TileMap/AnimatedSprite — ЖК рисуется только кодом.

## Decisions

### D1. Папка `godot/`, проект целиком внутри
`godot/project.godot` — корень Godot-проекта. Латиница вместо «ГОДОТ»: кириллица в пути ломает часть инструментов сборки Android (Gradle/aapt) и CI. Переименовать можно одной командой, код от имени папки не зависит.
*Альтернатива:* Godot-проект в корне репозитория (тогда `res://assets` = общие ассеты без копии) — отвергнуто: Godot начнёт импортировать всё подряд, смешаются два проекта.

### D2. Ассеты — копия в `godot/assets/` + проверка совпадения
`res://` не видит файлы вне папки проекта, а в экспорт попадает только содержимое `res://`. Поэтому `assets/` копируется в `godot/assets/`, а тест сравнивает оба дерева побайтно и называет расходящийся файл. Источник правды — корневой `assets/`; синхронизация — одна команда копирования (записана в README-комментарии теста).
*Альтернативы:* symlink/junction — git на Windows хранит их ненадёжно; скрипт автосинхронизации при сборке — лишняя инфраструктура, пока художник один.

### D3. Структура кода — зеркало Python-модулей
```
godot/
  project.godot           портрет 540×1170, стартовая сцена main.tscn
  main.tscn               корень Control + main.gd (≙ app.py + main.py)
  scripts/
    pet_state.gd          class_name PetState  (≙ state.py; to_dict/from_dict)
    evolution.gd          class_name Evolution (static, ≙ evolution.py)
    decay.gd              class_name Decay     (static, ≙ decay.py)
    sprites.gd            class_name Sprites   (≙ sprites.py; Sprite, Look, PetSkin)
    lcd.gd                class_name Lcd extends Control (≙ lcd.py)
    game.gd               class_name Game      (≙ game.py; логика + render(lcd))
    shop.gd               class_name Shop      (≙ shop.py)
    storage.gd            class_name Storage   (≙ storage.py + player.py + settings.py)
  tests/
    run_tests.gd          SceneTree-скрипт: юнит-проверки, ассеты, паритет
    make_parity.py        генерирует tests/parity_expected.json из прототипа
    parity_expected.json
  assets/                 копия корневого assets/
```
`Profile` и `Settings` — по 2–3 поля, живут в `storage.gd` как маленькие внутренние классы, без отдельных файлов. Статика через `class_name` вместо autoload — меньше глобального состояния, тесты вызывают функции напрямую.

### D4. Спрайты — загрузка один раз, статический кэш
`Sprites` при первом обращении парсит `res://assets/*.txt` в объекты `Sprite` (`w`, `h`, `rows: Array[PackedByteArray]`). Ошибка ассета → `push_error` с сообщением как в прототипе + `get_tree().quit(1)` (в тестах — assert). Папки питомцев перечисляются `DirAccess.get_directories_at("res://assets/pets")`.
Экспорт: `.txt` не ресурс Godot, поэтому в пресете экспорта нужен `include_filter="assets/*"` — фиксируется в Risks, делается в B.6.

### D5. ЖК — `Control._draw()` по буферу
`Lcd` держит `PackedByteArray` 72×156; API `clear/set_px/hline/blit/erase` как в прототипе (`set` занят в Object → `set_px`). `flush()` = `queue_redraw()`. В `_draw()` — подложка, затем по пикселю: тень (для включённых) и прямоугольник. Размер пикселя = `floor(min(w/72, h/156))` от собственного размера контрола, зазор 1 px при пикселе ≥ 4, тень `max(1, pixel/5)`, центрирование.
~11 тыс. `draw_rect` ×2 раза в секунду — дёшево; частичная перерисовка (как `_drawn` в tkinter) не нужна, Godot всё равно перерисовывает весь CanvasItem.
*Альтернатива:* `Image` 72×156 → `ImageTexture` с `TEXTURE_FILTER_NEAREST` — быстрее, но теряются зазоры/«призраки»/тени, ради которых экран и задуман.

### D6. Время и местные часы
`Time.get_unix_time_from_system()` ≙ `time.time()`. Местный час для ночи и дня таблеток: `Time.get_datetime_dict_from_unix_time(clock + tz_bias*60)`, где `tz_bias` = `Time.get_time_zone_from_system().bias`, вычисленный один раз. Это отличается от `time.localtime` только на стыке перехода на летнее время — см. Risks. Функция `local_time(clock)` одна на весь проект (в `decay.gd`), чтобы подмена в тестах была в одном месте.

### D7. Игровой цикл и жизненный цикл приложения
`Timer` 0,5 с → `game.tick()` → `game.render(lcd)`. `tick()` сам вызывает `Decay.advance(now)`, поэтому возврат из фона догоняется первым же тиком, а эволюция «пока были в фоне» показывается тем же кодом, что в живой игре. Сохранение: `Timer` 60 с, `NOTIFICATION_APPLICATION_PAUSED`, `NOTIFICATION_APPLICATION_FOCUS_OUT`, `NOTIFICATION_WM_CLOSE_REQUEST`. При запуске — как `main.py`: загрузить, `advance`, при смене стадии `start_evolution`.

### D8. Кнопки и ввод
`HBoxContainer` из трёх `Button` со `StyleBoxFlat` (круг, цвета корпуса прототипа: `#f2b8c6` корпус, `#f5d45c`/`#d9b53a` кнопка, `#4a4458` рамка), сигнал `pressed` (срабатывает при отпускании над кнопкой). `Button` уже умеет «нажатое» состояние и касания (эмуляция тача мышью включена в проекте). Клавиатура — `_unhandled_key_input`, таблица `KEYS` как в `app.py` по `unicode` и `keycode`. Отладочные покупки — только при `OS.is_debug_build()`.

### D9. Хранилище
`user://save.json`, `settings.json`, `player.json`. Запись: `FileAccess` в `*.tmp` → `DirAccess.rename_absolute(tmp, path)`. Чтение: `JSON.parse_string`; не словарь → значение по умолчанию. Имена полей JSON — те же, что в Python, поэтому сохранение прототипа читается как есть. Числа из JSON приходят как float — `from_dict` приводит `int`-поля (`care_mistakes`, `poops`, `pills_used`) явно.

### D10. Паритет через эталонный JSON
`tests/make_parity.py` импортирует модули прототипа (`sys.path` = корень репо), прогоняет сценарии через `decay.apply` при `quiet=None` и при тихих часах с фиксированным `clock` и пишет `{сценарий: {start, seconds, quiet, grow, expected}}`. `run_tests.gd` прогоняет те же входы через `Decay.apply` и сравнивает поля (float — с допуском 1e-6). Сценарии с ночью генерируются с `clock`, взятым в полдень местного времени машины-генератора, и сравниваются на той же машине (см. Risks). Запуск: `godot --headless --path godot -s res://tests/run_tests.gd`, код выхода ≠ 0 при падении.
*Альтернатива:* гонять Python из Godot через `OS.execute` — тесты зависели бы от Python в окружении Godot; JSON-эталон проще и детерминирован.

### D11. Отладочные аргументы
`OS.get_cmdline_user_args()` → `--speed N`, `--grow N` (всё после `--`). Разбор — 5 строк в `main.gd`.

## Risks / Trade-offs

- [DST: фиксированный сдвиг часового пояса ≠ `time.localtime` на стыке перехода] → ошибка максимум в час на границе тихих часов дважды в год; приемлемо для игры. Паритетные сценарии с ночью не пересекают переходы.
- [Паритет ночных сценариев зависит от часового пояса машины] → эталон перегенерируется `make_parity.py` на той же машине; дневные сценарии (`quiet=None`) от пояса не зависят.
- [`round()` в GDScript — «от нуля», в Python — банковское] → влияет только на ширину заливки шкалы на 1 пиксель при ровно .5; визуально несущественно, логики не касается.
- [`.txt` не попадут в APK без include-фильтра] → зафиксировать в задачах B.6; на ПК и в редакторе работает.
- [`DirAccess.rename_absolute` поверх существующего файла на Android/Windows] → проверить тестом «перезапись существующего сохранения»; при отказе — удалить старый и переименовать (окно риска минимально).
- [Копия ассетов расходится с корнем] → тест совпадения ассетов (D2) падает и называет файл.
- [Случайная прогулка питомца (`random`)] → в паритет не входит, это только отрисовка.

## Migration Plan

Прототип и Godot живут параллельно. Сохранения Python можно вручную скопировать в папку `user://` Godot (формат совместим). Откат — удалить `godot/`; Python не затронут.
