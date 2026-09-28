class_name Weather
## Погода — чистая функция от игровых часов: дождь 1–2 раза в местные сутки по 1–3 ч.
## Для игрока случайно, но одна дата всегда даёт одно расписание — офлайн-догонялка совпадает с живой игрой.

const WINDOWS := [6, 14]  # с какого часа начинаются окна дождей: 06–14 и 14–22, не пересекаются
const MAX_OFFSET := 5     # начало дождя — не позже чем через 5 ч после начала окна
const MAX_HOURS := 3

## Выключатель только для тестов с точными числами (иначе днём в дождь они бы плавали).
static var enabled := true


## [[час начала, длительность в часах], ...] для местных суток.
static func rains(year: int, month: int, day: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = year * 10000 + month * 100 + day
	var windows: Array = WINDOWS if rng.randi_range(1, 2) == 2 else [WINDOWS[rng.randi_range(0, 1)]]
	var out := []
	for w in windows:
		out.append([w + rng.randi_range(0, MAX_OFFSET), rng.randi_range(1, MAX_HOURS)])
	return out


static func is_rain(clock: float) -> bool:
	if not enabled:
		return false
	var t := Decay.local_time(clock)
	for r in rains(t.year, t.month, t.day):
		if t.hour >= r[0] and t.hour < r[0] + r[1]:
			return true
	return false
