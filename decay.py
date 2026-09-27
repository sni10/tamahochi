"""Деградация состояний со временем.

Все скорости заданы в единицах за час. Время обрабатывается шагами по минуте,
поэтому и живой тик, и догонялка после долгого офлайна дают одинаковый результат.
"""

import evolution
from state import PetState

HOUR = 3600.0
STEP = 60.0

SATIETY_AWAKE = -10.0
SATIETY_ASLEEP = -4.0
HAPPINESS_AWAKE = -8.0
HAPPINESS_ASLEEP = -2.0
ENERGY_AWAKE = -6.0
ENERGY_ASLEEP = +25.0

STARVING_DAMAGE = 12.0  # урон здоровью при нулевой сытости
SADNESS_DAMAGE = 4.0    # урон здоровью при нулевом счастье
HEALING = 5.0           # восстановление, когда питомец сыт и доволен
HEALING_THRESHOLD = 50.0

DIGESTION_RATE = 20.0   # само по себе — кучка раз в 5 часов, еда ускоряет (см. game.py)
MAX_POOPS = 3
POOP_DAMAGE = 3.0       # урон здоровью за каждую неубранную кучку
POOP_SADNESS = 3.0      # и дополнительная потеря счастья


def _clamp(value: float) -> float:
    return max(0.0, min(100.0, value))


def _step(s: PetState, seconds: float) -> None:
    s.age += seconds
    if s.stage == evolution.EGG:  # в яйце ничего не тратится, только растём
        evolution.grow(s)
        return

    h = seconds / HOUR
    hunger = evolution.HUNGER_FACTOR.get(s.stage, 1.0)
    satiety_before, happiness_before = s.satiety, s.happiness
    if s.sleeping:
        s.satiety = _clamp(s.satiety + SATIETY_ASLEEP * hunger * h)
        s.happiness = _clamp(s.happiness + HAPPINESS_ASLEEP * h)
        s.energy = _clamp(s.energy + ENERGY_ASLEEP * h)
    else:
        s.satiety = _clamp(s.satiety + SATIETY_AWAKE * hunger * h)
        s.happiness = _clamp(s.happiness + HAPPINESS_AWAKE * h)
        s.energy = _clamp(s.energy + ENERGY_AWAKE * h)

    s.digestion += DIGESTION_RATE * evolution.DIGESTION_FACTOR.get(s.stage, 1.0) * h
    if s.digestion >= 100:
        s.digestion -= 100
        s.poops = min(MAX_POOPS, s.poops + 1)
    s.happiness = _clamp(s.happiness - POOP_SADNESS * s.poops * h)

    # Ошибки ухода: довели до нуля сытость или счастье, долго не убирали.
    if satiety_before > 0 >= s.satiety:
        s.care_mistakes += 1
    if happiness_before > 0 >= s.happiness:
        s.care_mistakes += 1
    if s.poops:
        s.dirty_time += seconds
        if s.dirty_time >= evolution.DIRTY_MISTAKE_AFTER:
            s.care_mistakes += 1
            s.dirty_time -= evolution.DIRTY_MISTAKE_AFTER
    else:
        s.dirty_time = 0.0

    damage = POOP_DAMAGE * s.poops
    if s.satiety <= 0:
        damage += STARVING_DAMAGE
    if s.happiness <= 0:
        damage += SADNESS_DAMAGE
    if damage:
        s.health = _clamp(s.health - damage * h)
    elif s.satiety >= HEALING_THRESHOLD and s.happiness >= HEALING_THRESHOLD:
        s.health = _clamp(s.health + HEALING * h)

    if s.health <= 0:
        s.alive = False
        s.sleeping = False
    elif s.sleeping and s.energy >= 100:
        s.sleeping = False  # выспался
    elif not s.sleeping and s.energy <= 0:
        s.sleeping = True   # уснул от усталости

    if s.alive:
        evolution.grow(s)


def apply(s: PetState, seconds: float) -> None:
    """Прожить `seconds` секунд игрового времени."""
    while seconds > 0 and s.alive:
        chunk = min(STEP, seconds)
        _step(s, chunk)
        seconds -= chunk


def advance(s: PetState, now: float, speed: float = 1.0) -> None:
    """Догнать состояние до момента `now` (реальное время, умноженное на speed)."""
    elapsed = max(0.0, now - s.updated_at)  # защита от перевода часов назад
    apply(s, elapsed * speed)
    s.updated_at = now
