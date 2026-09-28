class_name Weather
## Погода — чистая функция от игровых часов: дождь примерно в 1 из 4 дней, один, 1–3 ч, днём.
## Для игрока случайно, но одна дата всегда даёт один результат — офлайн-догонялка совпадает с живой игрой.

const RAIN_CHANCE := 0.25     # доля дождливых дней
const INFECT_CHANCE := 0.8    # доля дождей, заражающих питомца без зонтика
const FIRST_HOUR := 6
const LAST_START := 19
const LAST_HOUR := 22         # дождь заканчивается не позже
const MAX_HOURS := 3

## Выключатель только для тестов с точными числами (иначе днём в дождь они бы плавали).
static var enabled := true


## Дождь местных суток: {} или {"start": час, "hours": 1..3, "infects": bool}.
static func rain_of(year: int, month: int, day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = year * 10000 + month * 100 + day
	if rng.randf() >= RAIN_CHANCE:
		return {}
	var start := rng.randi_range(FIRST_HOUR, LAST_START)
	var hours := mini(rng.randi_range(1, MAX_HOURS), LAST_HOUR - start)
	return {"start": start, "hours": hours, "infects": rng.randf() < INFECT_CHANCE}


## Дождь, который идёт в момент clock, или {}.
static func rain_at(clock: float) -> Dictionary:
	if not enabled:
		return {}
	var t := Decay.local_time(clock)
	var r := rain_of(t.year, t.month, t.day)
	if r and t.hour >= r.start and t.hour < r.start + r.hours:
		return r
	return {}


static func is_rain(clock: float) -> bool:
	return not rain_at(clock).is_empty()
