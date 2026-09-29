## ADDED Requirements

### Requirement: Страница About и отзыв
В сумке после SETTINGS SHALL быть пункт ABOUT. Экран ABOUT SHALL показывать строки «TAMAHOCHI», «V <версия>» (версия релиза; в локальной сборке — `0.0.0`), «MADE BY SNI10», «WITH LOVE», «TO PETS» и подсказки «B FEEDBACK», «C BACK». B SHALL открывать почтовое приложение с письмом на `d.strelets.a@gmail.com`, темой «Tamahochi feedback» и телом с версией игры, моделью устройства, названием и версией ОС; игрок дописывает текст сам. C SHALL возвращать в сумку.

#### Scenario: Открыть About
- **WHEN** игрок листает сумку до ABOUT и жмёт B
- **THEN** на экране название, версия и «MADE BY SNI10 / WITH LOVE / TO PETS»

#### Scenario: Написать отзыв
- **WHEN** на экране ABOUT игрок жмёт B
- **THEN** открывается почтовое приложение с адресом, темой «Tamahochi feedback» и версией игры в тексте письма

#### Scenario: Назад
- **WHEN** на экране ABOUT игрок жмёт C
- **THEN** снова сумка на пункте ABOUT
