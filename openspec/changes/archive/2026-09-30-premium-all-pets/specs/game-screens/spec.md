## MODIFIED Requirements

### Requirement: Страница ПРЕМИУМ
В сумке перед TIME SHALL быть пункт PREMIUM (значок алмаза). Его страница SHALL показывать состав: ALL PETS, 50 PILLS, 25 SYRINGES, 25 UMBRELLAS и подсказку «B BUY»; B — купить (оплата — заглушка в тестовых сборках). Купленный Premium SHALL показывать «OWNED» вместо «B BUY», и B MUST ничего не выдавать повторно. C — назад в сумку.

#### Scenario: Купить Premium
- **WHEN** в тестовой сборке игрок на странице PREMIUM жмёт B
- **THEN** все питомцы открыты, таблеток +50, шприцев +25, зонтиков +25, на странице OWNED

#### Scenario: Повторно
- **WHEN** Premium уже куплен и игрок жмёт B
- **THEN** ничего не добавляется
