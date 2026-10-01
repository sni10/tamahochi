class_name Calls
## Когда и почему питомец позовёт игрока — основа для локальных уведомлений (PLAN.md A.4, B.2).

const THRESHOLD := Game.SAD_THRESHOLD
const HORIZON := 72 * 3600.0
const REMIND_AFTER := 15 * 60.0  # повод уже есть при уходе — напомнить не сразу, а через 15 мин
const IGNORE_AFTER := 15 * 60.0  # не открыл игру за 15 мин после зова — зов проигнорирован
const TEXTS := {
	"dead": "%s has passed away",
	"sick": "%s is sick!",
	"hungry": "%s is hungry!",
	"poop": "Time to clean up!",
	"sad": "%s is sad",
	"rain": "%s is out in the rain!",
	"rain_umbrella": "It's raining. %s is under an umbrella",
	"born": "%s was born!",
	"grew": "%s has grown!",
}
const ORDER := ["dead", "sick", "hungry", "poop", "sad", "rain", "rain_umbrella", "born", "grew"]
const CARE := ["dead", "sick", "hungry", "poop", "sad"]  # поводы ухода: за них штраф, если зов проигнорирован


## Поводы в порядке важности: первый — главный (по нему текст уведомления).
## start_stage — стадия, о которой уже знают (выросла — повод born/grew).
static func reasons(s: PetState, start_stage := "") -> Array[String]:
	var out: Array[String] = []
	if not s.alive:
		out.append("dead")
	if s.sick:
		out.append("sick")
	if s.satiety < THRESHOLD:
		out.append("hungry")
	if s.poops:
		out.append("poop")
	if s.happiness < THRESHOLD:
		out.append("sad")
	if Weather.is_rain(s.clock):
		out.append("rain_umbrella" if s.rain_cover == "umbrella" else "rain")
	if start_stage and s.stage != start_stage:
		out.append("born" if start_stage == Evolution.BIRTH else "grew")
	return out


## Цепочка зовов на HORIZON вперёд без действий игрока: [{"at", "reasons", "care"}].
## Зов — когда появился повод, о котором ещё не звали; прошедший повод (кончился дождь) снова новый.
## reasons: сначала новые поводы, потом остальные активные (по важности); care — среди новых есть повод ухода.
## Считает на копиях: переданные состояние и профиль (запас зонтиков) не меняются.
## Зов, выпавший на тихие часы, ждёт утра; если к утру нового повода не осталось — ищем дальше.
static func chain(state: PetState, quiet: Array, now: float, profile: Storage.Profile = null) -> Array:
	var s := PetState.from_dict(state.to_dict())
	var p := Storage.Profile.from_dict(profile.to_dict()) if profile else null
	Decay.advance(s, now, 1.0, quiet, 1.0, p)
	var stage := s.stage
	var known := reasons(s).filter(func(r): return r.begins_with("rain"))  # дождь при уходе игрок уже видел
	var out := []
	var elapsed := 0.0
	while elapsed <= HORIZON:
		var cur := reasons(s, stage)
		known = known.filter(func(r): return r in cur)
		var fresh := cur.filter(func(r): return r not in known)
		if fresh and not Decay.is_night(s.clock, quiet):
			out.append({"at": now + elapsed, "reasons": fresh + cur.filter(func(r): return r not in fresh),
					"care": fresh.any(func(r): return r in CARE)})
			if not s.alive:
				break
			known = cur
			stage = s.stage
		if s.alive:
			Decay.apply(s, Decay.STEP, quiet, 1.0, p)
		else:
			s.clock += Decay.STEP  # мёртвого симуляция не двигает — двигаем часы сами
		elapsed += Decay.STEP
	return out


## Первый зов цепочки {"at", "reasons", "care"} или {}, если за HORIZON зова не будет.
static func next_call(state: PetState, quiet: Array, now: float, profile: Storage.Profile = null) -> Dictionary:
	var all := chain(state, quiet, now, profile)
	return all[0] if all else {}


## Текст уведомления по главному поводу; остальные — « (+N)».
static func text(why: Array, name: String) -> String:
	var body: String = TEXTS[why[0]]
	if body.contains("%s"):
		body = body % name
	return body + (" (+%d)" % (why.size() - 1) if why.size() > 1 else "")


## Уведомления на уход из игры: [{"at", "title", "body", "care"}] или [], если питомец мёртв или зова нет.
## Первое — не раньше REMIND_AFTER; зовы, совпавшие по моменту, сливаются (главный — важнейший новый).
static func plan(state: PetState, quiet: Array, now: float, profile: Storage.Profile, name: String) -> Array:
	if not state.alive:
		return []
	var out := []
	var why := []
	for c in chain(state, quiet, now, profile):
		var at := maxf(c.at, now + REMIND_AFTER)
		if out and at <= out[-1].at:
			var merged := why.duplicate()
			for r in c.reasons:
				if r not in merged:
					merged.append(r)
			why = ORDER.filter(func(r): return r in merged)  # ponytail: при слиянии «новые» не различаем — по важности
			out[-1].body = text(why, name)
			out[-1].care = out[-1].care or c.care
			continue
		why = c.reasons
		out.append({"at": at, "title": name, "body": text(why, name), "care": c.care})
	return out


## При возвращении в игру: зов, на который не ответили за IGNORE_AFTER (и не ночью), — ошибка ухода.
## ponytail: штраф начисляется при возвращении, до досчёта времени, а не точно в момент зова + 15 мин —
## если ребёнок вырос за время отсутствия, на облик взрослого штраф уже не повлияет.
static func punish_ignored(state: PetState, quiet: Array, now: float) -> void:
	var at := state.pending_call_at
	state.pending_call_at = 0.0
	if at > 0 and now > at + IGNORE_AFTER and not Decay.is_night(at, quiet):
		state.care_mistakes += 1
