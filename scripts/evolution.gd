class_name Evolution
## Стадии роста и выбор взрослого облика по качеству ухода (≙ evolution.py).
## BIRTH ──► BABY ──► CHILD ──► ADULT_GOOD / ADULT_NORMAL / ADULT_BAD

const MINUTE := 60.0
const HOUR := 3600.0

const BIRTH := "birth"  # в яйце или корзинке
const BABY := "baby"
const CHILD := "child"
const ADULT_GOOD := "adult_good"
const ADULT_NORMAL := "adult_normal"
const ADULT_BAD := "adult_bad"

const BIRTH_UNTIL := 5 * MINUTE
const BABY_UNTIL := 24 * HOUR
const CHILD_UNTIL := 72 * HOUR

const GOOD_MAX_MISTAKES := 2
const NORMAL_MAX_MISTAKES := 6

# Малыши быстрее голодают и чаще какают.
const HUNGER_FACTOR := {BABY: 1.5, CHILD: 1.2}
const DIGESTION_FACTOR := {BABY: 1.5, CHILD: 1.2}

const DIRTY_MISTAKE_AFTER := 3 * HOUR  # столько кучка может лежать, прежде чем это станет ошибкой


static func adult_for(mistakes: int) -> String:
	if mistakes <= GOOD_MAX_MISTAKES:
		return ADULT_GOOD
	if mistakes <= NORMAL_MAX_MISTAKES:
		return ADULT_NORMAL
	return ADULT_BAD


## Перевести питомца на ту стадию, до которой он дорос (можно через несколько сразу).
static func grow(s: PetState) -> void:
	if s.stage == BIRTH and s.age >= BIRTH_UNTIL:
		s.stage = BABY
	if s.stage == BABY and s.age >= BABY_UNTIL:
		s.stage = CHILD
	if s.stage == CHILD and s.age >= CHILD_UNTIL:
		s.stage = adult_for(s.care_mistakes)
