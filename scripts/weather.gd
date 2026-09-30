class_name Weather
## Погода — чистая функция от игровых часов: каждый день один дождь 10–30 минут, днём.
## Для игрока случайно, но одна дата всегда даёт один результат — офлайн-догонялка совпадает с живой игрой.

const FIRST_START := 6 * 60        # раньше 06:00 дождь не начинается (минуты суток)
const LAST_END := 22 * 60          # и заканчивается до 22:00
const MIN_MINUTES := 10
const MAX_MINUTES := 30
const INFECT_MIN := 0.2            # шанс заразить без зонтика при 10 минутах…
const INFECT_MAX := 0.8            # …и при 30, линейно между ними (+3% за минуту)

## Выключатель только для тестов с точными числами (иначе днём в дождь они бы плавали).
static var enabled := true


## Шанс, что дождь такой длины заразит питомца без зонтика.
static func infect_chance(minutes: int) -> float:
	return INFECT_MIN + (INFECT_MAX - INFECT_MIN) * (minutes - MIN_MINUTES) / float(MAX_MINUTES - MIN_MINUTES)


## Дождь местных суток: {"start": минута суток, "minutes": 10..30, "infects": bool}.
static func rain_of(year: int, month: int, day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = year * 10000 + month * 100 + day
	var start := rng.randi_range(FIRST_START, LAST_END - MAX_MINUTES)
	var minutes := rng.randi_range(MIN_MINUTES, MAX_MINUTES)
	return {"start": start, "minutes": minutes, "infects": rng.randf() < infect_chance(minutes)}


## Дождь, который идёт в момент clock, или {}.
static func rain_at(clock: float) -> Dictionary:
	if not enabled:
		return {}
	var t := Decay.local_time(clock)
	var r := rain_of(t.year, t.month, t.day)
	var now: int = t.hour * 60 + t.minute
	if now >= r.start and now < r.start + r.minutes:
		return r
	return {}


static func is_rain(clock: float) -> bool:
	return not rain_at(clock).is_empty()
