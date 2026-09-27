"""Эволюция: стадии роста и выбор взрослого облика по качеству ухода.

EGG ──► BABY ──► CHILD ──► ADULT_GOOD / ADULT_NORMAL / ADULT_BAD

Возраст считается в игровом времени (state.age), поэтому работает и офлайн, и с --speed.
"""

from state import PetState

MINUTE, HOUR = 60.0, 3600.0

EGG, BABY, CHILD = "egg", "baby", "child"
ADULT_GOOD, ADULT_NORMAL, ADULT_BAD = "adult_good", "adult_normal", "adult_bad"
ADULTS = (ADULT_GOOD, ADULT_NORMAL, ADULT_BAD)

# До какого возраста длится стадия.
EGG_UNTIL = 5 * MINUTE
BABY_UNTIL = 24 * HOUR
CHILD_UNTIL = 72 * HOUR

# Ошибки ухода → взрослый облик.
GOOD_MAX_MISTAKES = 2
NORMAL_MAX_MISTAKES = 6

# Малыши быстрее голодают и чаще какают.
HUNGER_FACTOR = {BABY: 1.5, CHILD: 1.2}
DIGESTION_FACTOR = {BABY: 1.5, CHILD: 1.2}

DIRTY_MISTAKE_AFTER = 3 * HOUR  # столько кучка может лежать, прежде чем это станет ошибкой


def adult_for(mistakes: int) -> str:
    if mistakes <= GOOD_MAX_MISTAKES:
        return ADULT_GOOD
    if mistakes <= NORMAL_MAX_MISTAKES:
        return ADULT_NORMAL
    return ADULT_BAD


def grow(s: PetState) -> None:
    """Перевести питомца на следующую стадию, если он дорос."""
    if s.stage == EGG and s.age >= EGG_UNTIL:
        s.stage = BABY
    elif s.stage == BABY and s.age >= BABY_UNTIL:
        s.stage = CHILD
    elif s.stage == CHILD and s.age >= CHILD_UNTIL:
        s.stage = adult_for(s.care_mistakes)
