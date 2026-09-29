class_name Sprites
## Загрузка спрайтов из текстовых файлов res://assets (формат — как в sprites.py прототипа).

const ROOT := "res://assets"
const PET_MAX := 28
const PET_FRAMES := ["idle1", "idle2", "sad1", "sad2", "happy", "eat1", "eat2", "sleep"]
## Если стадия не нарисована — берём первую нарисованную из списка.
const STAGE_FALLBACK := {
	"baby": ["baby", "child", "adult_normal"],
	"child": ["child", "adult_normal"],
	"adult_good": ["adult_good", "adult_normal"],
	"adult_normal": ["adult_normal"],
	"adult_bad": ["adult_bad", "adult_normal"],
}

## Первая ошибка ассетов; пусто — всё загружено.
static var error := ""

static var FONT: Dictionary
static var BIRTH: Dictionary  # egg/basket -> [обычный кадр, кадр «вот-вот появится»]
static var PETS: Dictionary   # ключ вида -> PetSkin, по (order, ключ)

static var ICON_FOOD: Sprite
static var ICON_PLAY: Sprite
static var ICON_SLEEP: Sprite
static var ICON_CLEAN: Sprite
static var ICON_SETTINGS: Sprite
static var ICON_BAG: Sprite
static var ICON_ABOUT: Sprite
static var ICON_TIME: Sprite
static var ITEM_PILL: Sprite
static var ITEM_SYRINGE: Sprite
static var ITEM_UMBRELLA: Sprite
static var MINI_FEVER: Sprite
static var SICK: Sprite
static var LOCK: Sprite
static var ICON_SIZE: int
static var MINI_SATIETY: Sprite
static var MINI_HAPPINESS: Sprite
static var MINI_ENERGY: Sprite
static var MINI_HEALTH: Sprite
static var ARROW_LEFT: Sprite
static var ARROW_RIGHT: Sprite

static var SUN: Array
static var CLOUD: Sprite
static var CLOUD_MASK: Sprite
static var FOOD: Sprite
static var POOP: Sprite
static var STINK: Sprite
static var WAVE: Sprite
static var Z_BIG: Sprite
static var Z_SMALL: Sprite
static var GHOST: Sprite
static var RAIN_CLOUD: Sprite
static var RAIN: Array  # два кадра плитки капель
static var UMBRELLA: Sprite
static var MOON: Sprite


class Sprite:
	var lines: PackedStringArray
	var rows: Array[PackedByteArray] = []
	var w: int
	var h: int

	func _init(p_lines: PackedStringArray) -> void:
		lines = p_lines
		w = lines[0].length()
		h = lines.size()
		for line in lines:
			var row := PackedByteArray()
			row.resize(w)
			for i in w:
				row[i] = 1 if line[i] == "#" else 0
			rows.append(row)

	## Оставить только левые `width` столбцов (для «откусанной» еды).
	func cropped(width: int) -> Sprite:
		width = clampi(width, 1, w)
		var out := PackedStringArray()
		for line in lines:
			out.append(line.substr(0, width))
		return Sprite.new(out)


## Облик питомца на одной стадии: все кадры одного размера.
class Look:
	var w: int
	var h: int
	var idle: Array
	var sad: Array
	var happy: Sprite
	var eat: Array
	var sleep: Sprite


## Внешность одного вида питомца на всех стадиях.
class PetSkin:
	var key: String
	var name: String
	var order: int
	var birth: String
	var free: bool
	var looks := {}

	func look(stage: String) -> Look:
		for st in STAGE_FALLBACK.get(stage, ["adult_normal"]):
			if looks.has(st):
				return looks[st]
		return looks["adult_normal"]


static func _fail(msg: String) -> void:
	if error.is_empty():
		error = msg
		push_error(msg)


## Разобрать текст файла спрайтов: {"meta", "sheet", "error"}.
static func parse_sheet(text: String, fname: String) -> Dictionary:
	var meta := {}
	var sheet := {}
	var name: Variant = null
	var rows := PackedStringArray()
	var start := 0
	var n := 0
	for raw in text.split("\n"):
		n += 1
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with(";"):
			continue
		if line.begins_with("[") and line.ends_with("]"):
			var err := _finish(sheet, name, rows, fname, start)
			if err:
				return {"error": err}
			name = line.substr(1, line.length() - 2)
			rows = PackedStringArray()
			start = n
			if sheet.has(name):
				return {"error": "%s:%d: спрайт [%s] уже был" % [fname, n, name]}
			continue
		if name == null:
			var sep := line.find(":")
			if sep < 0:
				return {"error": "%s:%d: ожидалось «ключ: значение» или [имя]" % [fname, n]}
			meta[line.substr(0, sep).strip_edges()] = line.substr(sep + 1).strip_edges()
			continue
		for ch in line:
			if ch != "#" and ch != ".":
				return {"error": "%s:%d: в спрайте допустимы только '#' и '.'" % [fname, n]}
		rows.append(line)
	var last_err := _finish(sheet, name, rows, fname, start)
	if last_err:
		return {"error": last_err}
	return {"meta": meta, "sheet": sheet, "error": ""}


static func _finish(sheet: Dictionary, name: Variant, rows: PackedStringArray, fname: String, start: int) -> String:
	if name == null:
		return ""
	var widths := {}
	for r in rows:
		widths[r.length()] = true
	if rows.is_empty() or widths.size() != 1:
		return "%s, спрайт [%s] (строка %d): строки спрайта должны быть одной длины" % [fname, name, start]
	sheet[name] = Sprite.new(rows)
	return ""


static func load_sheet(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "нет файла %s" % path}
	return parse_sheet(FileAccess.get_file_as_string(path), path.get_file())


static func _require(sheet: Dictionary, name: String, file: String) -> Sprite:
	if not sheet.has(name):
		_fail("%s: нет спрайта [%s]" % [file, name])
		return null
	return sheet[name]


static func load_look(path: String) -> Look:
	var res := load_sheet(path)
	if res.error:
		_fail(res.error)
		return null
	var name := path.get_base_dir().get_file() + "/" + path.get_file()
	var f := {}
	for frame in PET_FRAMES:
		f[frame] = _require(res.sheet, frame, name)
		if f[frame] == null:
			return null
	var sizes := {}
	for sp in f.values():
		sizes[Vector2i(sp.w, sp.h)] = true
	if sizes.size() != 1:
		_fail("%s: все кадры стадии должны быть одного размера, а тут %s" % [name, sizes.keys()])
		return null
	var look := Look.new()
	look.w = f.idle1.w
	look.h = f.idle1.h
	if look.w > PET_MAX or look.h > PET_MAX:
		_fail("%s: кадры %dx%d больше %dx%d" % [name, look.w, look.h, PET_MAX, PET_MAX])
		return null
	look.idle = [f.idle1, f.idle2]
	look.sad = [f.sad1, f.sad2]
	look.happy = f.happy
	look.eat = [f.eat1, f.eat2]
	look.sleep = f.sleep
	return look


static func load_skin(folder: String) -> PetSkin:
	var skin := PetSkin.new()
	skin.key = folder.get_file()
	var meta := {}
	if FileAccess.file_exists(folder + "/pet.txt"):
		var res := load_sheet(folder + "/pet.txt")
		if res.error:
			_fail(res.error)
			return null
		meta = res.meta
	skin.name = meta.get("name", skin.key.to_upper())
	skin.order = int(meta.get("order", "99"))
	skin.birth = meta.get("birth", "basket")
	skin.free = meta.get("free", "no").to_lower() == "yes"  # иначе — покупка или Premium
	if not BIRTH.has(skin.birth):
		_fail("pets/%s/pet.txt: birth должен быть одним из %s" % [skin.key, BIRTH.keys()])
		return null
	for st in STAGE_FALLBACK:
		var path := "%s/%s.txt" % [folder, st]
		if FileAccess.file_exists(path):
			var look := load_look(path)
			if look == null:
				return null
			skin.looks[st] = look
	if not skin.looks.has("adult_normal"):
		_fail("pets/%s: обязателен файл adult_normal.txt" % skin.key)
		return null
	return skin


static func _load_pets() -> Dictionary:
	var skins: Array[PetSkin] = []
	for dir in DirAccess.get_directories_at(ROOT + "/pets"):
		var skin := load_skin(ROOT + "/pets/" + dir)
		if skin == null:
			return {}
		skins.append(skin)
	if skins.is_empty():
		_fail("в assets/pets нет ни одного питомца")
		return {}
	skins.sort_custom(func(a, b): return a.order < b.order or (a.order == b.order and a.key < b.key))
	var out := {}
	for s in skins:
		out[s.key] = s
	return out


static func _sheet(file: String) -> Dictionary:
	var res := load_sheet(ROOT + "/" + file)
	if res.error:
		_fail(res.error)
		return {}
	return res.sheet


static func _static_init() -> void:
	var ui := _sheet("ui.txt")
	var world := _sheet("world.txt")
	FONT = _sheet("font.txt")
	if error:
		return
	BIRTH = {
		"egg": [_require(world, "egg", "world.txt"), _require(world, "egg_crack", "world.txt")],
		"basket": [_require(world, "basket", "world.txt"), _require(world, "basket_wake", "world.txt")],
	}
	PETS = _load_pets()

	ICON_FOOD = _require(ui, "icon_food", "ui.txt")
	ICON_PLAY = _require(ui, "icon_play", "ui.txt")
	ICON_SLEEP = _require(ui, "icon_sleep", "ui.txt")
	ICON_CLEAN = _require(ui, "icon_clean", "ui.txt")
	ICON_SETTINGS = _require(ui, "icon_settings", "ui.txt")
	ICON_BAG = _require(ui, "icon_bag", "ui.txt")
	ICON_ABOUT = _require(ui, "icon_about", "ui.txt")
	ICON_TIME = _require(ui, "icon_time", "ui.txt")
	ITEM_PILL = _require(ui, "item_pill", "ui.txt")
	ITEM_SYRINGE = _require(ui, "item_syringe", "ui.txt")
	ITEM_UMBRELLA = _require(ui, "item_umbrella", "ui.txt")
	MINI_FEVER = _require(ui, "mini_fever", "ui.txt")
	SICK = _require(ui, "sick", "ui.txt")
	LOCK = _require(ui, "lock", "ui.txt")
	MINI_SATIETY = _require(ui, "mini_satiety", "ui.txt")
	MINI_HAPPINESS = _require(ui, "mini_happiness", "ui.txt")
	MINI_ENERGY = _require(ui, "mini_energy", "ui.txt")
	MINI_HEALTH = _require(ui, "mini_health", "ui.txt")
	ARROW_LEFT = _require(ui, "arrow_left", "ui.txt")
	ARROW_RIGHT = _require(ui, "arrow_right", "ui.txt")
	ICON_SIZE = ICON_FOOD.w if ICON_FOOD else 12

	SUN = [_require(world, "sun1", "world.txt"), _require(world, "sun2", "world.txt")]
	CLOUD = _require(world, "cloud", "world.txt")
	CLOUD_MASK = _require(world, "cloud_mask", "world.txt")
	FOOD = _require(world, "food", "world.txt")
	POOP = _require(world, "poop", "world.txt")
	STINK = _require(world, "stink", "world.txt")
	WAVE = _require(world, "wave", "world.txt")
	Z_BIG = _require(world, "z_big", "world.txt")
	Z_SMALL = _require(world, "z_small", "world.txt")
	GHOST = _require(world, "ghost", "world.txt")
	RAIN_CLOUD = _require(world, "rain_cloud", "world.txt")
	RAIN = [_require(world, "rain1", "world.txt"), _require(world, "rain2", "world.txt")]
	UMBRELLA = _require(world, "umbrella", "world.txt")
	MOON = _require(world, "moon", "world.txt")
