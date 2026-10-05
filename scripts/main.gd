extends Control
## Экран во весь телефон: касания, «назад» Android, клавиатура, игровой цикл и автосохранение (≙ app.py + main.py).
## Отладка: godot --path . -- --speed 60 | --grow 3600;
## «покупки» (только debug): 1/G/П — ролик = шприц, 2 — пачка, 3 — Premium, 4 — показанный питомец, 5 — ролик = зонтик, 6 — ролик = таблетка.

const AUTOSAVE_SEC := 60.0
const TAP_VIBRATE_MS := 25  # короткий отклик на касание экрана

const DEBUG_PURCHASES := {"1": Shop.AD_REWARD, "g": Shop.AD_REWARD, "п": Shop.AD_REWARD,
		"2": Shop.SYRINGE_PACK, "3": Shop.PREMIUM, "4": "pet", "5": Shop.AD_UMBRELLA, "6": Shop.AD_PILL}
## Клавиатура на ПК: A — дальше, B — выполнить, C — назад. Латиница и та же клавиша в русской раскладке, плюс стрелки/Enter/Esc.
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
	if state:  # догоняем время, пока программа была закрыта (зонтики раскрываются и офлайн)
		Notifier.cancel()
		Calls.punish_ignored(state, settings.quiet(), Time.get_unix_time_from_system())  # до досчёта времени
		var umbrellas_before := profile.umbrellas
		Decay.advance(state, Time.get_unix_time_from_system(), 1.0, settings.quiet(), 1.0, profile)
		if profile.umbrellas != umbrellas_before:
			Storage.save_profile(profile)
	game = Game.new(state, args.speed, settings, args.grow, profile)
	game.tester = OS.is_debug_build() or OS.has_feature("tester")  # метку tester снимаем для продакшена
	if game.tester and args.speed == 1.0:
		game.speed = settings.time_speed  # TIME из сумки; действует, пока игра открыта
	if state and state.alive and state.stage != stage_before:
		game.start_evolution(stage_before)  # вырос, пока игра была закрыта
	if not settings.notify_asked:  # экран разрешения — один раз и только там, где он нужен
		if Notifier.needs_permission():
			game.ask_notify()
		else:
			settings.notify_asked = true
			Storage.save_settings(settings)

	get_tree().quit_on_go_back = false  # «назад» обрабатываем сами: это C, выход — только из пустой комнаты
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
	var bg := ColorRect.new()
	bg.color = Palette.TABLE[Palette.PAPER]
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)
	lcd = Lcd.new()
	lcd.set_anchors_preset(PRESET_FULL_RECT)
	lcd.tapped.connect(func(cell: Vector2i): Input.vibrate_handheld(TAP_VIBRATE_MS); game.tap(cell.x, cell.y); _press(""))
	lcd.swiped.connect(func(dir: int): game.swipe(dir); _press(""))
	add_child(lcd)


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
	if game.new_game_wanted:  # бросили питомца: без сохранения и без зова он не вернётся
		game.new_game_wanted = false
		Notifier.cancel()
		DirAccess.remove_absolute(Storage.SAVE_PATH)
	if game.feedback_wanted:
		game.feedback_wanted = false
		OS.shell_open(Game.feedback_mailto())  # почтовое приложение с готовым письмом
	if game.open_notify_settings_wanted:
		game.open_notify_settings_wanted = false
		if not Notifier.open_settings():
			game.settings_note = "NOT HERE"
	if game.notify_permission_wanted:
		OS.request_permission("android.permission.POST_NOTIFICATIONS")
		game.notify_permission_wanted = false
	if game.settings_changed:
		Storage.save_settings(game.settings)
		game.settings_changed = false
	if game.profile_changed:
		Storage.save_profile(game.profile)
		game.profile_changed = false
	game.render(lcd)


func _on_tick() -> void:
	game.tick()
	_press("")  # сохранить профиль, если в тике раскрылся зонтик, и перерисовать


func _save() -> void:
	Storage.save_settings(game.settings)
	Storage.save_profile(game.profile)
	if game.savable():
		Storage.save_pet(game.state)


func _notification(what: int) -> void:
	if not game:
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:  # «назад» Android = C; из пустой комнаты — выход
		if game.mode == "idle" and game.selected < 0:
			_leave()
			get_tree().quit()
		else:
			_press("press_c")
	elif what in [NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST]:
		_leave()
	elif what in [NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_come_back()


## Игрок уходит: запланировать зов (если есть живой питомец) и сохранить.
func _leave() -> void:
	if game.savable() and not game.settings.calls_enabled:  # CALLS OFF: не звать — и не штрафовать
		print("[calls] CALLS OFF")
		game.state.pending_call_at = 0.0
		Notifier.cancel()
	elif game.savable():
		var calls := Calls.plan(game.state, game.settings.quiet(), Time.get_unix_time_from_system(), game.profile, game.skin().name)
		var care := calls.filter(func(c): return c.care)  # дождь и рост не штрафуются
		game.state.pending_call_at = care[0].at if care else 0.0
		if calls:
			Notifier.schedule(calls)
		else:
			Notifier.cancel()
	_save()


## Игрок вернулся: отменить зов, оштрафовать за проигнорированный — до досчёта времени,
## затем досчитать время в фоне 1:1 (TIME ускоряет только открытую игру, зов планировался 1:1).
func _come_back() -> void:
	Notifier.cancel()
	if game.savable():
		var now := Time.get_unix_time_from_system()
		Calls.punish_ignored(game.state, game.settings.quiet(), now)
		game.tick(now, true)
		_press("")  # сохранить профиль (зонтик) и перерисовать
		Storage.save_pet(game.state)
