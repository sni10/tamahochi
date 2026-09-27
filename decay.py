"""Деградация состояний со временем.

Все скорости заданы в единицах за час. Время обрабатывается шагами по минуте,
поэтому и живой тик, и догонялка после долгого офлайна дают одинаковый результат.

Ночь питомца совпадает с тихими часами игрока: в начале ночи питомец засыпает,
в конце просыпается, а пока спит ночью — почти ничего не тратит и не копит ошибок.
"""

import time

import evolution
from state import PetState

HOUR = 3600.0
STEP = 60.0

SATIETY_AWAKE = -10.0
SATIETY_ASLEEP = -4.0
SATIETY_NIGHT = -1.0
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

Quiet = tuple[int, int] | None  # тихие часы (с, до) в часах суток; None — ночи нет


def is_night(clock: float, quiet: Quiet) -> bool:
    if not quiet or quiet[0] == quiet[1]:
        return False
    start, end = quiet
    t = time.localtime(clock)
    hour = t.tm_hour + t.tm_min / 60
    if start < end:
        return start <= hour < end
    return hour >= start or hour < end  # ночь через полночь, например 22–08


def _clamp(value: float) -> float:
    return max(0.0, min(100.0, value))


def _step(s: PetState, seconds: float, night: bool) -> None:
    s.age += seconds
    if s.stage == evolution.EGG:  # в яйце ничего не тратится, только растём
        evolution.grow(s)
        return

    h = seconds / HOUR
    hunger = evolution.HUNGER_FACTOR.get(s.stage, 1.0)
    deep = night and s.sleeping  # ночной сон: игрок спит, питомец тоже
    satiety_before, happiness_before = s.satiety, s.happiness
    if deep:
        s.satiety = _clamp(s.satiety + SATIETY_NIGHT * hunger * h)
        s.energy = _clamp(s.energy + ENERGY_ASLEEP * h)
    elif s.sleeping:
        s.satiety = _clamp(s.satiety + SATIETY_ASLEEP * hunger * h)
        s.happiness = _clamp(s.happiness + HAPPINESS_ASLEEP * h)
        s.energy = _clamp(s.energy + ENERGY_ASLEEP * h)
    else:
        s.satiety = _clamp(s.satiety + SATIETY_AWAKE * hunger * h)
        s.happiness = _clamp(s.happiness + HAPPINESS_AWAKE * h)
        s.energy = _clamp(s.energy + ENERGY_AWAKE * h)

    if not deep:  # ночью пищеварение и кучки «замирают»
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

    damage = 0.0 if deep else POOP_DAMAGE * s.poops
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
    elif s.sleeping and s.energy >= 100 and not night:
        s.sleeping = False  # выспался (ночью спит до утра)
    elif not s.sleeping and s.energy <= 0:
        s.sleeping = True   # уснул от усталости

    if s.alive:
        evolution.grow(s)


def apply(s: PetState, seconds: float, quiet: Quiet = None) -> None:
    """Прожить `seconds` секунд игрового времени; игровые часы s.clock идут вместе с ним."""
    while seconds > 0 and s.alive:
        chunk = min(STEP, seconds)
        was_night = is_night(s.clock, quiet)
        s.clock += chunk
        night = is_night(s.clock, quiet)
        if s.stage != evolution.EGG:
            if night and not was_night:
                s.sleeping = True   # наступила ночь — спать
            elif was_night and not night:
                s.sleeping = False  # утро — подъём
        _step(s, chunk, night)
        seconds -= chunk


def advance(s: PetState, now: float, speed: float = 1.0, quiet: Quiet = None) -> None:
    """Догнать состояние до момента `now` (реальное время, умноженное на speed).

    При speed > 1 игровые часы s.clock убегают вперёд реальных — это режим отладки.
    """
    elapsed = max(0.0, now - s.updated_at)  # защита от перевода часов назад
    apply(s, elapsed * speed, quiet)
    s.updated_at = now
