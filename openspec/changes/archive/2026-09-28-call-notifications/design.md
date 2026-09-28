## Context

`Calls.next_call(state, quiet, now, profile)` уже считает, когда и почему питомец позовёт (симуляция на копиях, тихие часы, зонтики). `main.gd` сохраняет игру на `NOTIFICATION_APPLICATION_PAUSED / FOCUS_OUT / WM_CLOSE_REQUEST`; догонялка времени идёт в `Game.tick` и при запуске. Android-доставки пока нет — её даст плагин в следующем change.

## Goals / Non-Goals

**Goals:** вся логика уведомлений — чистые функции, проверяемые тестами на ПК; одна точка доставки, в которую следующий change подключит Android.
**Non-Goals:** Kotlin-плагин, разрешение Android 13+, нажатие на уведомление (открывает игру по умолчанию), несколько уведомлений вперёд.

## Decisions

### D1. Чистые функции в `Calls`
- `Calls.plan(state, quiet, now, profile, name) -> Dictionary`: `{}` (мёртв / нет зова) или `{"at", "title", "body"}`; `at = max(next_call.at, now + REMIND_AFTER)`, `REMIND_AFTER = 15 мин`.
- `Calls.text(reasons, name) -> String` — порядок поводов уже задан в `Calls.reasons()` (dead, sick, poop, hungry, sad) — **меняем порядок на dead, sick, hungry, poop, sad**, чтобы главный повод шёл первым; `+N` — `reasons.size() - 1`.
- `Calls.punish_ignored(state, quiet, now)`: если `pending_call_at > 0`, `now > pending_call_at + IGNORE_AFTER` (15 мин) и `not Decay.is_night(pending_call_at, quiet)` → `care_mistakes += 1`; в любом случае `pending_call_at = 0`.
Экран выбора — решает вызывающий (`main.gd` не зовёт `plan`, если `not game.savable()`).

### D2. `pending_call_at` в `PetState`
Float, 0 — зова нет. Пишется в `save.json` при уходе (план считается до сохранения) — штраф работает и после полного закрытия приложения.

### D3. Точка доставки `Notifier`
`scripts/notifier.gd`, `class_name Notifier`, статические `schedule(at, title, body)` и `cancel()`. Если `Engine.has_singleton("TamahochiNotify")` — вызывает плагин (имя синглтона зафиксирует следующий change), иначе `print("notify at HH:MM: body")`. Тестам не нужен — тестируются чистые функции.

### D4. Порядок в `main.gd`
- Уход (`PAUSED`, `FOCUS_OUT`, `WM_CLOSE_REQUEST`): если есть живой питомец — `plan` → `state.pending_call_at = at` (или 0) → `Notifier.schedule/cancel` → сохранить.
- Возврат (`_ready` после загрузки, `RESUMED`, `FOCUS_IN`): `Notifier.cancel()`, `Calls.punish_ignored` **до** досчёта времени (при запуске — до `Decay.advance`, при выходе из фона — до ближайшего `tick`), сохранить.
`FOCUS_OUT`/`FOCUS_IN` на ПК срабатывают при переключении окон — это и есть «ушёл/вернулся», поведение одинаковое.

## Risks / Trade-offs

- [Штраф применяется до досчёта времени, хотя по сути случился в `at + 15 мин`] → если за время отсутствия ребёнок вырос во взрослого, штраф уже не повлияет на облик; редкий случай, упрощение сознательное (`ponytail`-комментарий в коде).
- [Порядок поводов в `Calls.reasons()` меняется] → тесты, сравнивающие список поводов, обновляются.
- [Без плагина на Android уведомления не придут] → ожидаемо до следующего change; игра не ломается (D3).
