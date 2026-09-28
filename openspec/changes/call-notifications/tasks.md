## 1. Чистая логика (Calls)

- [x] 1.1 Порядок поводов в `Calls.reasons()`: dead, sick, hungry, poop, sad; `Calls.text(reasons, name)`; проверка: тесты — «Time to clean up!», «CAT is hungry!», «CAT is sick! (+2)», «CAT has passed away»; старый тест поводов обновлён
- [x] 1.2 `Calls.plan(state, quiet, now, profile, name)` по D1; проверка: тесты сценариев спеки — сытый днём → ~5 ч, «Time to clean up!»; повод уже есть → ровно через 15 мин; кучка к 02:00 при тихих 22–08 → 08:00; мёртвый → `{}`
- [x] 1.3 `PetState.pending_call_at` (0 по умолчанию, в FIELDS) и `Calls.punish_ignored(state, quiet, now)` по D1; проверка: тесты — зов 12:00, вернулся 13:00 → +1; вернулся 12:10 → 0; повторный вызов → без второго штрафа; зов в тихие часы → 0; старый `save.json` → 0

## 2. Доставка и жизненный цикл

- [x] 2.1 `scripts/notifier.gd` по D3 (на ПК — строка в лог); проверка: headless-запуск главной сцены с уведомлениями ухода/возврата — в выводе «notify at 02:17: CAT — Time to clean up!» и «notify cancelled», ошибок нет
- [x] 2.2 `main.gd` по D4: план и сохранение при уходе, отмена и штраф при возврате (и при запуске до `Decay.advance`); проверка: тот же headless-сценарий — при уходе план через 5 ч и `pending_call_at` в `save.json`; при возврате план отменён, зов часовой давности → +1 ошибка, `pending_call_at` = 0 (сохранения разработчика восстановлены из копии)

## 3. Приёмка

- [x] 3.1 Полный прогон тестов; PLAN.md B.2 — логика готова, Android-доставка — следующий change
