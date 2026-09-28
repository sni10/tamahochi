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
}


## Поводы в порядке важности: первый — главный (по нему текст уведомления).
static func reasons(s: PetState) -> Array[String]:
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
	return out


## {"at": момент зова, "reasons": [...]} или {}, если за HORIZON зова не будет.
## Считает на копиях: переданные состояние и профиль (запас зонтиков) не меняются.
## Зов, выпавший на тихие часы, ждёт утра.
static func next_call(state: PetState, quiet: Array, now: float, profile: Storage.Profile = null) -> Dictionary:
	var s := PetState.from_dict(state.to_dict())
	var p := Storage.Profile.from_dict(profile.to_dict()) if profile else null
	Decay.advance(s, now, 1.0, quiet, 1.0, p)
	var elapsed := 0.0
	while reasons(s).is_empty():
		if elapsed >= HORIZON:
			return {}
		Decay.apply(s, Decay.STEP, quiet, 1.0, p)
		elapsed += Decay.STEP
	while Decay.is_night(s.clock, quiet):
		if s.alive:
			Decay.apply(s, Decay.STEP, quiet, 1.0, p)
		else:
			s.clock += Decay.STEP  # мёртвого симуляция не двигает — двигаем часы сами
		elapsed += Decay.STEP
	return {"at": now + elapsed, "reasons": reasons(s)}


## Текст уведомления по главному поводу; остальные — « (+N)».
static func text(why: Array, name: String) -> String:
	var body: String = TEXTS[why[0]]
	if body.contains("%s"):
		body = body % name
	return body + (" (+%d)" % (why.size() - 1) if why.size() > 1 else "")


## Уведомление на уход из игры: {"at", "title", "body"} или {}, если питомец мёртв или зова нет.
static func plan(state: PetState, quiet: Array, now: float, profile: Storage.Profile, name: String) -> Dictionary:
	if not state.alive:
		return {}
	var call := next_call(state, quiet, now, profile)
	if call.is_empty():
		return {}
	return {"at": maxf(call.at, now + REMIND_AFTER), "title": name, "body": text(call.reasons, name)}


## При возвращении в игру: зов, на который не ответили за IGNORE_AFTER (и не ночью), — ошибка ухода.
## ponytail: штраф начисляется при возвращении, до досчёта времени, а не точно в момент зова + 15 мин —
## если ребёнок вырос за время отсутствия, на облик взрослого штраф уже не повлияет.
static func punish_ignored(state: PetState, quiet: Array, now: float) -> void:
	var at := state.pending_call_at
	state.pending_call_at = 0.0
	if at > 0 and now > at + IGNORE_AFTER and not Decay.is_night(at, quiet):
		state.care_mistakes += 1
