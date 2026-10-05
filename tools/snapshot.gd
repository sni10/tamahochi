extends SceneTree
## Скриншоты экрана в PNG без запуска игры: godot --headless --path . -s res://tools/snapshot.gd
## Кладёт в build/shots/: каждый питомец днём, ночью и в дождь, экран выбора; сцена ice;
## sheet.png — все кадры одной картинкой.

const SCALE := 6
const OUT := "res://build/shots"

var _shots: Array[Image] = []


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var lcd := Lcd.new()
	var noon := _at(12)
	for key in Sprites.PETS:
		var g := _game(key, noon)
		_shot(g, lcd, "%s_day" % key)
		g.state.clock = _at(2)
		g.state.sleeping = true
		_shot(g, lcd, "%s_night" % key)
		g = _game(key, _rain_time())
		_shot(g, lcd, "%s_rain" % key)
	var sel := Game.new(null)
	sel.choice = 0
	_shot(sel, lcd, "select")
	# сцена льдов на чужом питомце — пока нет своих зверей
	var ice := _game("blob", noon)
	Sprites.PETS["blob"].scene = "ice"
	for f in 3:
		ice.frame = f * 7
		_shot(ice, lcd, "ice_%d" % f, false)
	lcd.free()
	_sheet()
	print("shots → ", ProjectSettings.globalize_path(OUT))
	quit()


func _game(key: String, clock: float) -> Game:
	var s := PetState.new()
	s.species = key
	s.stage = "adult_normal"
	s.age = 4 * 86400.0
	s.clock = clock
	s.satiety = 80
	s.happiness = 80
	s.energy = 80
	s.poops = 1
	var g := Game.new(s)
	g.selected = 0
	return g


func _shot(g: Game, lcd: Lcd, name: String, set_frame := true) -> void:
	if set_frame:
		g.frame = 2
	g.render(lcd)
	var img := Image.create(Lcd.COLS * SCALE, Lcd.ROWS * SCALE, false, Image.FORMAT_RGB8)
	for y in Lcd.ROWS:
		for x in Lcd.COLS:
			img.fill_rect(Rect2i(x * SCALE, y * SCALE, SCALE, SCALE), lcd.color_at(x, y))
	img.save_png("%s/%s.png" % [OUT, name])
	_shots.append(img)


## Все кадры в сетку по 6 в ряд, уменьшенные вдвое.
func _sheet() -> void:
	var w := Lcd.COLS * SCALE / 2
	var h := Lcd.ROWS * SCALE / 2
	var cols := 6
	var gap := 8
	var rows := ceili(_shots.size() / float(cols))
	var sheet := Image.create(cols * (w + gap), rows * (h + gap), false, Image.FORMAT_RGB8)
	sheet.fill(Color.WHITE)
	for i in _shots.size():
		var img := _shots[i].duplicate()
		img.resize(w, h, Image.INTERPOLATE_NEAREST)
		sheet.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(i % cols * (w + gap), i / cols * (h + gap)))
	sheet.save_png(OUT + "/sheet.png")


## Местное время сегодня в hour:00.
func _at(hour: int) -> float:
	var now := Time.get_unix_time_from_system()
	var t := Decay.local_time(now)
	return now - (t.hour * 3600 + t.minute * 60 + t.second) + hour * 3600


## Ближайший момент дождя (ищем по часу вперёд).
func _rain_time() -> float:
	var t := _at(12)
	for i in 24 * 60:
		if Weather.is_rain(t):
			return t + 60
		t += 3600
	return t
