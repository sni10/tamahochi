class_name Calls
## Когда и почему питомец позовёт игрока — основа для локальных уведомлений (PLAN.md A.4, B.2).

const THRESHOLD := Game.SAD_THRESHOLD
const HORIZON := 72 * 3600.0


static func reasons(s: PetState) -> Array[String]:
	var out: Array[String] = []
	if not s.alive:
		out.append("dead")
	if s.sick:
		out.append("sick")
	if s.poops:
		out.append("poop")
	if s.satiety < THRESHOLD:
		out.append("hungry")
	if s.happiness < THRESHOLD:
		out.append("sad")
	return out


## {"at": момент зова, "reasons": [...]} или {}, если за HORIZON зова не будет.
## Считает на копии: переданное состояние не меняется. Зов, выпавший на тихие часы, ждёт утра.
static func next_call(state: PetState, quiet: Array, now: float) -> Dictionary:
	var s := PetState.from_dict(state.to_dict())
	Decay.advance(s, now, 1.0, quiet)
	var elapsed := 0.0
	while reasons(s).is_empty():
		if elapsed >= HORIZON:
			return {}
		Decay.apply(s, Decay.STEP, quiet)
		elapsed += Decay.STEP
	while Decay.is_night(s.clock, quiet):
		if s.alive:
			Decay.apply(s, Decay.STEP, quiet)
		else:
			s.clock += Decay.STEP  # мёртвого симуляция не двигает — двигаем часы сами
		elapsed += Decay.STEP
	return {"at": now + elapsed, "reasons": reasons(s)}
