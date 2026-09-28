class_name Decay
## Деградация состояний со временем (≙ decay.py). Скорости — в единицах за час,
## время обрабатывается шагами по минуте: живой тик и офлайн-догонялка дают одно и то же.
## Ночь питомца = тихие часы игрока. quiet — [с, до] в часах суток; пустой массив — ночи нет.

const HOUR := 3600.0
const STEP := 60.0

const SATIETY_AWAKE := -10.0
const SATIETY_ASLEEP := -4.0
const SATIETY_NIGHT := -1.0
const HAPPINESS_AWAKE := -8.0
const HAPPINESS_ASLEEP := -2.0
const ENERGY_AWAKE := -6.0
const ENERGY_ASLEEP := 25.0

const STARVING_DAMAGE := 12.0
const SADNESS_DAMAGE := 4.0
const HEALING := 5.0
const HEALING_THRESHOLD := 50.0

const DIGESTION_RATE := 20.0
const MAX_POOPS := 3
const POOP_SADNESS := 3.0

const FEVER_RISE := 4.0
const DEADLY_FEVER := 100.0

## Сдвиг местного времени от UTC в минутах.
## ponytail: один сдвиг на весь запуск, на стыке перехода на летнее время ошибка до часа.
static var tz_bias: int = Time.get_time_zone_from_system().bias


## Местное время по игровым часам (≙ time.localtime).
static func local_time(clock: float) -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(floori(clock) + tz_bias * 60)


static func is_night(clock: float, quiet: Array) -> bool:
	if quiet.is_empty() or quiet[0] == quiet[1]:
		return false
	var start: float = quiet[0]
	var end: float = quiet[1]
	var t := local_time(clock)
	var hour: float = t.hour + t.minute / 60.0
	if start < end:
		return start <= hour and hour < end
	return hour >= start or hour < end  # ночь через полночь, например 22–08


static func _clamp(value: float) -> float:
	return clampf(value, 0.0, 100.0)


static func _step(s: PetState, seconds: float, night: bool, grow := 1.0) -> void:
	s.age += seconds * grow
	if s.stage == Evolution.BIRTH:  # в яйце/корзинке ничего не тратится, только растём
		Evolution.grow(s)
		return

	var h := seconds / HOUR
	var hunger: float = Evolution.HUNGER_FACTOR.get(s.stage, 1.0)
	var deep := night and s.sleeping  # ночной сон: игрок спит, питомец тоже
	var satiety_before := s.satiety
	var happiness_before := s.happiness
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
		s.digestion += DIGESTION_RATE * Evolution.DIGESTION_FACTOR.get(s.stage, 1.0) * h
		if s.digestion >= 100:
			s.digestion -= 100
			s.poops = mini(MAX_POOPS, s.poops + 1)
		s.happiness = _clamp(s.happiness - POOP_SADNESS * s.poops * h)

		# Ошибки ухода: довели до нуля сытость или счастье, долго не убирали.
		if satiety_before > 0 and s.satiety <= 0:
			s.care_mistakes += 1
		if happiness_before > 0 and s.happiness <= 0:
			s.care_mistakes += 1
		if s.poops:
			s.dirty_time += seconds
			if s.dirty_time >= Evolution.DIRTY_MISTAKE_AFTER:
				s.care_mistakes += 1
				s.dirty_time -= Evolution.DIRTY_MISTAKE_AFTER
		else:
			s.dirty_time = 0.0

		# Болезнь: набралось максимум кучек.
		if s.poops >= MAX_POOPS and not s.sick:
			s.sick = true
			s.care_mistakes += 1

	if s.sick:  # болезнь не спит: температура растёт и ночью
		s.fever = _clamp(s.fever + FEVER_RISE * h)

	var damage := 0.0
	if s.satiety <= 0:
		damage += STARVING_DAMAGE
	if s.happiness <= 0:
		damage += SADNESS_DAMAGE
	if damage:
		s.health = _clamp(s.health - damage * h)
	elif s.satiety >= HEALING_THRESHOLD and s.happiness >= HEALING_THRESHOLD:
		s.health = _clamp(s.health + HEALING * h)

	if s.health <= 0 or s.fever >= DEADLY_FEVER:
		s.alive = false
		s.sleeping = false
	elif s.sleeping and s.energy >= 100 and not night:
		s.sleeping = false  # выспался (ночью спит до утра)
	elif not s.sleeping and s.energy <= 0:
		s.sleeping = true   # уснул от усталости

	if s.alive:
		Evolution.grow(s)


## Прожить `seconds` секунд игрового времени; игровые часы s.clock идут вместе с ним.
static func apply(s: PetState, seconds: float, quiet: Array = [], grow := 1.0) -> void:
	while seconds > 0 and s.alive:
		var chunk := minf(STEP, seconds)
		var was_night := is_night(s.clock, quiet)
		s.clock += chunk
		var night := is_night(s.clock, quiet)
		if s.stage != Evolution.BIRTH:
			if night and not was_night:
				s.sleeping = true   # наступила ночь — спать
			elif was_night and not night:
				s.sleeping = false  # утро — подъём
		_step(s, chunk, night, grow)
		seconds -= chunk


## Догнать состояние до момента `now` (реальное время × speed).
static func advance(s: PetState, now: float, speed := 1.0, quiet: Array = [], grow := 1.0) -> void:
	var elapsed := maxf(0.0, now - s.updated_at)  # защита от перевода часов назад
	apply(s, elapsed * speed, quiet, grow)
	s.updated_at = now
