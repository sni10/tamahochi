class_name PetState extends RefCounted
## Состояние питомца: только данные, без логики времени и отрисовки (≙ state.py).

const FIELDS := [
	"species", "stage", "age", "care_mistakes", "dirty_time", "satiety", "happiness", "energy",
	"health", "sick", "fever", "pills_day", "pills_used", "digestion", "poops", "sleeping", "alive",
	"born_at", "updated_at", "clock", "rain_loss", "rain_cover", "pending_call_at",
]

var species := "blob"      # вид питомца — папка в assets/pets
var stage := "birth"       # стадия эволюции, см. evolution.gd
var age := 0.0             # прожито игровых секунд
var care_mistakes := 0     # ошибки ухода — решают, каким вырастет взрослый
var dirty_time := 0.0      # сколько секунд подряд лежат неубранные кучки
# Все показатели в диапазоне 0..100, где 100 — «всё отлично».
var satiety := 100.0
var happiness := 100.0
var energy := 100.0
var health := 100.0
var sick := false          # болен: температура растёт, пока не вылечат
var fever := 0.0           # температура болезни: на 100 питомец умирает
var pills_day := ""        # игровой день (ГГГГ-ММ-ДД), за который считаются таблетки
var pills_used := 0
var digestion := 0.0       # пищеварение: на 100 появляется кучка
var poops := 0
var sleeping := false
var alive := true
var born_at := Time.get_unix_time_from_system()
var updated_at := Time.get_unix_time_from_system()  # момент последнего пересчёта деградации
var clock := Time.get_unix_time_from_system()       # игровые часы (с --speed идут быстрее)
var rain_loss := 0.0     # сколько счастья добавочно отнял текущий дождь (лимит — Decay.RAIN_JOY_MAX)
var rain_cover := ""     # защита на текущий дождь: "" — ещё не решено, "umbrella" — зонтик раскрыт, "none" — без защиты
var pending_call_at := 0.0  # момент запланированного зова-уведомления (0 — нет); см. Calls.punish_ignored


func _init(p_species := "blob") -> void:
	species = p_species


func to_dict() -> Dictionary:
	var d := {}
	for f in FIELDS:
		d[f] = get(f)
	return d


## Неизвестные ключи игнорируем, отсутствующие берём по умолчанию —
## так старые сохранения переживут добавление новых полей.
static func from_dict(data: Dictionary) -> PetState:
	var s := PetState.new()
	data = data.duplicate()
	if not data.has("stage"):
		data["stage"] = "adult_normal"  # питомцы до эволюции уже были взрослыми
	if data["stage"] == "egg":
		data["stage"] = "birth"  # стадия переименована
	if not data.has("clock"):
		data["clock"] = data.get("updated_at", Time.get_unix_time_from_system())
	for f in FIELDS:
		if data.has(f):
			s.set(f, type_convert(data[f], typeof(s.get(f))))  # JSON отдаёт числа как float
	return s
