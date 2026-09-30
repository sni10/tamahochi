class_name Weather
## Погода — чистая функция от игровых часов: каждый день 1–2 дождя по 20–60 минут, в любое время суток.
## Для игрока случайно, но одна дата всегда даёт один результат — офлайн-догонялка совпадает с живой игрой.

## Окна начала дождя (минуты суток): ночь–утро и день–ночь; с дождём до 60 минут они не пересекаются
## и заканчиваются до полуночи (дождь не переходит в другие сутки).
const WINDOWS := [[0, 10 * 60 + 59], [12 * 60, 22 * 60 + 59]]
const MIN_MINUTES := 20
const MAX_MINUTES := 60
const INFECT_MIN := 0.2            # шанс заразить без зонтика при 20 минутах…
const INFECT_MAX := 0.8            # …и при 60, линейно между ними (+1,5% за минуту)

## Выключатель только для тестов с точными числами (иначе днём в дождь они бы плавали).
static var enabled := true


## Шанс, что дождь такой длины заразит питомца без зонтика.
static func infect_chance(minutes: int) -> float:
	return INFECT_MIN + (INFECT_MAX - INFECT_MIN) * (minutes - MIN_MINUTES) / float(MAX_MINUTES - MIN_MINUTES)


## Дожди местных суток: [{"start": минута суток, "minutes": 20..60, "infects": bool}, ...] — 1 или 2.
static func rains_of(year: int, month: int, day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = year * 10000 + month * 100 + day
	var windows: Array = WINDOWS if rng.randf() < 0.5 else [WINDOWS[rng.randi_range(0, 1)]]
	var out := []
	for w in windows:
		var minutes := rng.randi_range(MIN_MINUTES, MAX_MINUTES)
		out.append({"start": rng.randi_range(w[0], w[1]), "minutes": minutes,
				"infects": rng.randf() < infect_chance(minutes)})
	return out


## Дождь, который идёт в момент clock, или {}.
static func rain_at(clock: float) -> Dictionary:
	if not enabled:
		return {}
	var t := Decay.local_time(clock)
	var now: int = t.hour * 60 + t.minute
	for r in rains_of(t.year, t.month, t.day):
		if now >= r.start and now < r.start + r.minutes:
			return r
	return {}


static func is_rain(clock: float) -> bool:
	return not rain_at(clock).is_empty()
