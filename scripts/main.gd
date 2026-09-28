extends Control
## Корпус: экран, три кнопки, клавиатура, игровой цикл и автосохранение (≙ app.py + main.py).
## Отладка: godot --path . -- --speed 60 | --grow 3600;
## «покупки» (только debug): 1/G/П — ролик = шприц, 2 — пачка, 3 — Premium, 4 — показанный питомец.

const SHELL := Color("#f2b8c6")
const BEZEL := Color("#4a4458")
const BUTTON := Color("#f5d45c")
const BUTTON_PRESSED := Color("#d9b53a")
const AUTOSAVE_SEC := 60.0

const DEBUG_PURCHASES := {"1": Shop.AD_REWARD, "g": Shop.AD_REWARD, "п": Shop.AD_REWARD,
		"2": Shop.SYRINGE_PACK, "3": Shop.PREMIUM, "4": "pet"}
## Латиница и та же клавиша в русской раскладке, плюс стрелки/Enter/Esc.
const KEYS := {"a": "a", "ф": "a", "b": "b", "и": "b", "c": "c", "с": "c"}
const KEYCODES := {KEY_LEFT: "a", KEY_ENTER: "b", KEY_KP_ENTER: "b", KEY_ESCAPE: "c", KEY_RIGHT: "c"}

var game: Game
var lcd: Lcd


func _ready() -> void:
	if Sprites.error:
		get_tree().quit(1)
		return
	var args := _parse_args()
	var settings := Storage.load_settings()
	var profile := Storage.load_profile()
	var state := Storage.load_pet()  # null — новая игра, начнём с выбора питомца
	var stage_before := state.stage if state else ""
	if state:  # догоняем время, пока программа была закрыта
		Decay.advance(state, Time.get_unix_time_from_system(), 1.0, settings.quiet())
	game = Game.new(state, args.speed, settings, args.grow, profile)
	if state and state.alive and state.stage != stage_before:
		game.start_evolution(stage_before)  # вырос, пока игра была закрыта

	_build_ui()
	_add_timer(Game.TICK_SEC, _on_tick)
	_add_timer(AUTOSAVE_SEC, _save)
	game.render(lcd)


func _parse_args() -> Dictionary:
	var out := {"speed": 1.0, "grow": 1.0}
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		var key := args[i].trim_prefix("--")
		if out.has(key):
			out[key] = args[i + 1].to_float()
	return out


func _build_ui() -> void:
	# Корпус масштабируется от ширины экрана (база — окно ПК 540 px): на телефоне 1440 px кнопки иначе крошечные.
	var k := maxf(1.0, get_viewport_rect().size.x / 540.0)
	var bg := ColorRect.new()
	bg.color = SHELL
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_FULL_RECT, PRESET_MODE_MINSIZE, roundi(16 * k))
	box.add_theme_constant_override("separation", roundi(12 * k))
	add_child(box)
	lcd = Lcd.new()
	lcd.size_flags_vertical = SIZE_EXPAND_FILL
	box.add_child(lcd)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", roundi(40 * k))
	box.add_child(row)
	for key in ["a", "b", "c"]:
		row.add_child(_make_button(key, k))


func _make_button(key: String, k: float) -> Control:
	var col := VBoxContainer.new()
	var b := Button.new()
	b.custom_minimum_size = Vector2.ONE * roundi(72 * k)
	b.focus_mode = FOCUS_NONE
	for st in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = BUTTON_PRESSED if st == "pressed" else BUTTON
		sb.set_corner_radius_all(roundi(36 * k))
		sb.set_border_width_all(roundi(3 * k))
		sb.border_color = BEZEL
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(_press.bind("press_" + key))  # срабатывает при отпускании
	col.add_child(b)
	var label := Label.new()
	label.text = key.to_upper()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", BEZEL)
	label.add_theme_font_size_override("font_size", roundi(22 * k))
	col.add_child(label)
	return col


func _add_timer(sec: float, callback: Callable) -> void:
	var t := Timer.new()
	t.wait_time = sec
	t.autostart = true
	t.timeout.connect(callback)
	add_child(t)


func _unhandled_key_input(event: InputEvent) -> void:
	var e := event as InputEventKey
	if not e.pressed or e.echo:
		return
	var ch := char(e.unicode).to_lower() if e.unicode else ""
	if OS.is_debug_build() and DEBUG_PURCHASES.has(ch):
		var product: String = DEBUG_PURCHASES[ch]
		if product == "pet":  # купить питомца, показанного на экране выбора
			product = Shop.pet_product(game.skin().key)
		if Shop.grant(game.profile, product):
			game.profile_changed = true
		_press("")
		return
	var key: String = KEYS.get(ch, KEYCODES.get(e.keycode, ""))
	if key:
		_press("press_" + key)


func _press(action: String) -> void:
	if action:
		game.call(action)
	if game.settings_changed:
		Storage.save_settings(game.settings)
		game.settings_changed = false
	if game.profile_changed:
		Storage.save_profile(game.profile)
		game.profile_changed = false
	game.render(lcd)


func _on_tick() -> void:
	game.tick()
	game.render(lcd)


func _save() -> void:
	Storage.save_settings(game.settings)
	Storage.save_profile(game.profile)
	if game.savable():
		Storage.save_pet(game.state)


func _notification(what: int) -> void:
	if game and what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		_save()
