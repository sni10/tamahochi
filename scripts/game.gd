class_name Game extends RefCounted
## Игровая логика: меню, действия, анимации и отрисовка кадра на LCD (≙ game.py).
## Экран сверху вниз: панель шкал → комната с питомцем → меню действий.

const COLS := Lcd.COLS
const ROWS := Lcd.ROWS
const TICK_SEC := 0.5

# Панель шкал
const STATUS_Y := 3
const STATUS_STEP := 6
const BAR_X := 9
const BAR_W := 62
const SEPARATOR_TOP := 35

# Комната
const PLAY_Y := 37
const GROUND := 126                 # «пол», на котором стоят спрайты
const PLAY_AREA := Rect2i(0, PLAY_Y, COLS, GROUND - PLAY_Y)
const POOP_SLOT := 11               # кучки выстраиваются справа налево
const SUN_X := 47
const SUN_Y := PLAY_Y + 2
const CLOUD_Y := PLAY_Y + 10        # на высоте солнца, чтобы проплывать перед ним
const RAIN_CLOUD_Y := PLAY_Y + 3  # ниже — широкая часть тучи ушла бы на надпись AGE 999
const RAIN_BOTTOM := GROUND - Sprites.PET_MAX - 2  # капли не долетают до питомца

# Меню
const SEPARATOR_BOTTOM := 132
const ICON_Y := 139
const ICON_X := 2
const ICON_STEP := 14

# Экран выбора
const NAME_Y := 9
const DOTS_Y := 25

enum { FEED, PLAY, SLEEP, CLEAN, BAG }
const ICON_COUNT := 5
enum { FIELD_FROM, FIELD_TO, FIELD_CALLS, FIELD_SOUND }
const SETTINGS_FIELDS := 4
enum { PILL, SYRINGE, UMBRELLA, BAG_SETTINGS, BAG_ABOUT, BAG_NEW, BAG_PREMIUM, BAG_TIME }
const BAG_NAMES := ["PILL", "SYRINGE", "UMBRELLA", "SETTINGS", "ABOUT", "NEW GAME", "PREMIUM", "TIME"]  # TIME — только tester
## Подменю расходника (B на PILL/SYRINGE/UMBRELLA): применить, купить набор, получить за рекламу.
enum { ACTION_USE, ACTION_BUY, ACTION_GET }
const ACTION_NAMES := ["USE", "BUY", "GET"]
const BUY_PRODUCTS := {PILL: Shop.PILL_PACK, SYRINGE: Shop.SYRINGE_PACK, UMBRELLA: Shop.UMBRELLA_PACK}
const AD_PRODUCTS := {PILL: Shop.AD_PILL, SYRINGE: Shop.AD_REWARD, UMBRELLA: Shop.AD_UMBRELLA}
const PACK_SIZES := {PILL: Shop.PILL_PACK_SIZE, SYRINGE: Shop.SYRINGE_PACK_SIZE, UMBRELLA: Shop.UMBRELLA_PACK_SIZE}
const TIME_SPEEDS := [1.0, 10.0, 60.0, 600.0]
const FEEDBACK_EMAIL := "d.strelets.a@gmail.com"
const FREE_PILLS_PER_DAY := 5
const PILL_FEVER := 10.0

## Длительность анимаций в тиках; пока анимация идёт, кнопки игнорируются.
const ANIM_LENGTH := {"eat": 8, "play": 8, "no": 4, "clean": 6, "evolve": 10, "heal": 6}
const WAKE_BEFORE := 60.0  # за сколько игровых секунд до появления яйцо трескается / корзинка шевелится

const FEED_AMOUNT := 15.0
const FEED_DIGESTION := 25.0
const PLAY_JOY := 20.0
const PLAY_COST_ENERGY := 10.0
const PLAY_COST_SATIETY := 5.0
const CLEAN_JOY := 5.0
const FULL_THRESHOLD := 95.0
const TIRED_THRESHOLD := 10.0
const SAD_THRESHOLD := 25.0

var state: PetState
var speed: float
var grow: float
var settings: Storage.Settings
var settings_field := 0          # поле экрана настроек: FIELD_FROM … FIELD_SOUND
var settings_note := ""          # короткая надпись на экране настроек (NOT HERE), до следующего нажатия
var open_notify_settings_wanted := false  # main.gd открывает системные настройки уведомлений
var tester := false  # тестовая сборка: в сумке есть TIME (main.gd)
var new_game_wanted := false  # main.gd удаляет сохранение прежнего питомца и отменяет зов
var feedback_wanted := false  # main.gd открывает письмо разработчику (feedback_mailto)
var settings_changed := false    # main.gd сохраняет настройки и сбрасывает флаг
var profile: Storage.Profile
var profile_changed := false
var notify_permission_wanted := false  # main.gd запрашивает системное разрешение и сбрасывает флаг
var after_ask := ""                     # куда вернуться с экрана разрешения
var bag_item := 0
var bag_action := -1             # строка подменю расходника; -1 — подменю закрыто
var selected := -1               # -1 — ничего не выбрано
var choice := 0                  # какой питомец показан на экране выбора
var mode := "idle"
var mode_ticks := 0
var frame := 0
var pet_x := (COLS - Sprites.PET_MAX) / 2
var pet_dir := 1
var cleaning_poops := 0
var evolved_from := ""


## p_state == null — новая игра, начинаем с выбора питомца.
## speed ускоряет всё время, grow — только взросление (отладка эволюции).
func _init(p_state: PetState, p_speed := 1.0, p_settings: Storage.Settings = null,
		p_grow := 1.0, p_profile: Storage.Profile = null) -> void:
	state = p_state if p_state else PetState.new()
	speed = p_speed
	grow = p_grow
	settings = p_settings if p_settings else Storage.Settings.new()
	profile = p_profile if p_profile else Storage.Profile.new()
	mode = "idle" if p_state else "select"
	if p_state and not p_state.alive:
		mode = "dead"


func skin() -> Sprites.PetSkin:
	var pets := Sprites.PETS
	if mode == "select":
		return pets.values()[choice]
	return pets.get(state.species, pets.values()[0])


## Облик на текущей стадии (на экране выбора — взрослый).
func look() -> Sprites.Look:
	return skin().look("adult_normal" if mode == "select" else state.stage)


func _icons() -> Array:
	return [Sprites.ICON_FOOD, Sprites.ICON_PLAY, Sprites.ICON_SLEEP, Sprites.ICON_CLEAN, Sprites.ICON_BAG]


func _bag_icons() -> Array:
	return [Sprites.ITEM_PILL, Sprites.ITEM_SYRINGE, Sprites.ITEM_UMBRELLA, Sprites.ICON_SETTINGS, Sprites.ICON_ABOUT, Sprites.ICON_NEW, Sprites.ICON_PREMIUM, Sprites.ICON_TIME]


func _is_birth() -> bool:
	return mode != "select" and state.stage == Evolution.BIRTH


func _birth_sprite(waking: bool) -> Sprites.Sprite:
	return Sprites.BIRTH[skin().birth][1 if waking else 0]


func _pet_w() -> int:
	return _birth_sprite(false).w if _is_birth() else look().w


static func _y_for(h: int) -> int:
	return GROUND - h


static func _center_for(w: int) -> int:
	return (COLS - w) / 2


## На экране выбора нет настоящего питомца — сохранять нечего.
func savable() -> bool:
	return (after_ask if mode == "notify_ask" else mode) != "select"


## Один раз показать экран «разрешите уведомления»; B вернёт туда, где были.
func ask_notify() -> void:
	after_ask = mode
	_set_mode("notify_ask")


# --- время ---

## real_time — досчёт времени, пока игра была свёрнута: 1:1, без ускорения TIME.
func tick(now := Time.get_unix_time_from_system(), real_time := false) -> void:
	frame += 1
	if mode == "select" or mode == "notify_ask":
		return  # время догонит первый тик после экрана разрешения
	var stage_before := state.stage
	var umbrellas_before := profile.umbrellas
	Decay.advance(state, now, 1.0 if real_time else speed, settings.quiet(), grow, profile)
	if profile.umbrellas != umbrellas_before:
		profile_changed = true  # зонтик раскрылся сам — main.gd сохранит профиль
	pet_x = mini(pet_x, _max_pet_x())
	if not state.alive:
		if mode != "dead":
			_set_mode("dead")
			selected = -1
		return
	if state.stage != stage_before:
		start_evolution(stage_before)
		return
	mode_ticks += 1
	if ANIM_LENGTH.has(mode) and mode_ticks >= ANIM_LENGTH[mode]:
		_set_mode("idle")
	if mode == "idle" and not state.sleeping and not _is_birth():
		_walk()


## Показать анимацию превращения из стадии from_stage в текущую.
func start_evolution(from_stage: String) -> void:
	evolved_from = from_stage
	pet_x = _home_x()
	_set_mode("evolve")


func _set_mode(m: String) -> void:
	mode = m
	mode_ticks = 0


func _busy() -> bool:
	return ANIM_LENGTH.has(mode)


## Правая граница прогулки: кучки занимают место справа.
func _max_pet_x() -> int:
	return maxi(0, COLS - _pet_w() - POOP_SLOT * state.poops - 1)


## Где питомец стоит во время сна и анимаций.
func _home_x() -> int:
	return mini(_center_for(_pet_w()), _max_pet_x())


func _walk() -> void:
	if randf() < 0.1:
		pet_dir = -pet_dir
	if randf() < 0.6:
		pet_x += pet_dir
	var max_x := _max_pet_x()
	if pet_x < 0 or pet_x > max_x:
		pet_dir = -pet_dir
		pet_x = clampi(pet_x, 0, max_x)


# --- кнопки ---

## Выбор следующей иконки (на экране выбора — предыдущий питомец).
func press_a() -> void:
	if mode in ["notify_ask", "about", "abandon"]:
		return
	if mode == "select":
		choice = posmod(choice - 1, Sprites.PETS.size())
		return
	if mode == "settings":
		settings_field = (settings_field + 1) % SETTINGS_FIELDS
		settings_note = ""
		return
	if mode == "bag":
		if bag_action >= 0:
			bag_action = (bag_action + 1) % ACTION_NAMES.size()
		else:
			bag_item = (bag_item + 1) % (BAG_NAMES.size() if tester else BAG_TIME)
		return
	if mode == "dead" or _busy():
		return
	selected = 0 if selected < 0 else (selected + 1) % ICON_COUNT


## Подтверждение выбранного действия.
func press_b() -> void:
	if mode == "abandon":  # новая игра: как после смерти — на выбор, но прежнего питомца удаляем
		new_game_wanted = true
		choice = maxi(0, Sprites.PETS.keys().find(state.species))
		selected = -1
		_set_mode("select")
		return
	if mode == "about":
		feedback_wanted = true
		return
	if mode == "notify_ask":
		settings.notify_asked = true
		settings_changed = true
		notify_permission_wanted = true
		_set_mode(after_ask)
		return
	if mode == "select":
		if not Shop.is_unlocked(profile, skin()):
			return  # закрыт: сначала купить
		state = PetState.new(skin().key)
		pet_x = _home_x()
		_set_mode("idle")
		return
	if mode == "dead":
		choice = maxi(0, Sprites.PETS.keys().find(state.species))
		selected = -1
		_set_mode("select")
		return
	if mode == "settings":
		settings_note = ""
		if settings_field == FIELD_FROM:
			settings.quiet_start = (settings.quiet_start + 1) % 24
		elif settings_field == FIELD_TO:
			settings.quiet_end = (settings.quiet_end + 1) % 24
		elif settings_field == FIELD_CALLS:
			settings.calls_enabled = not settings.calls_enabled
		else:
			open_notify_settings_wanted = true  # main.gd откроет системные настройки уведомлений
			return
		settings_changed = true
		return
	if mode == "bag":
		_use_bag_item()
		return
	if _busy() or selected < 0:
		return
	if selected == BAG:
		bag_action = -1
		_set_mode("bag")
		return
	if _is_birth():
		return  # в яйце/корзинке ничего не нужно
	var s := state
	if selected == SLEEP:
		s.sleeping = not s.sleeping
	elif selected == CLEAN:
		if s.poops:
			cleaning_poops = s.poops
			s.poops = 0
			s.happiness = minf(100.0, s.happiness + CLEAN_JOY)
			_set_mode("clean")
		elif not s.sleeping:
			_set_mode("no")
	elif s.sleeping:
		return  # спящего не кормим и не развлекаем
	elif selected == FEED:
		if s.satiety >= FULL_THRESHOLD:
			_set_mode("no")
		else:
			s.satiety = minf(100.0, s.satiety + FEED_AMOUNT)
			s.digestion += FEED_DIGESTION
			_set_mode("eat")
	elif selected == PLAY:
		if s.energy < TIRED_THRESHOLD or s.sick or Weather.is_rain(s.clock):  # в дождь не играет
			_set_mode("no")
		else:
			s.happiness = minf(100.0, s.happiness + PLAY_JOY)
			s.energy = maxf(0.0, s.energy - PLAY_COST_ENERGY)
			s.satiety = maxf(0.0, s.satiety - PLAY_COST_SATIETY)
			_set_mode("play")


## Отмена: снять выбор (на экране выбора — следующий питомец).
func press_c() -> void:
	if mode == "about" or mode == "abandon":
		_set_mode("bag")
		return
	if mode == "notify_ask":
		return
	if mode == "select":
		choice = (choice + 1) % Sprites.PETS.size()
		return
	if mode == "settings":
		_set_mode("bag")  # настройки открываются из сумки — туда и возвращаемся
		return
	if mode == "bag":
		if bag_action >= 0:
			bag_action = -1  # из подменю — обратно к предметам
		else:
			_set_mode("idle")
		return
	if mode == "dead" or _busy():
		return
	selected = -1


# --- сумка ---

func _pill_day() -> String:
	var t := Decay.local_time(state.clock)
	return "%04d-%02d-%02d" % [t.year, t.month, t.day]


## Бесплатные таблетки на сегодня (игровой день).
func pills_left() -> int:
	var used := state.pills_used if state.pills_day == _pill_day() else 0
	return maxi(0, FREE_PILLS_PER_DAY - used)


func _use_bag_item() -> void:
	var s := state
	if bag_item == BAG_SETTINGS:
		settings_field = FIELD_FROM
		settings_note = ""
		_set_mode("settings")
		return
	if bag_item == BAG_ABOUT:
		_set_mode("about")
		return
	if bag_item == BAG_NEW:
		_set_mode("abandon")  # экран подтверждения: бросить питомца
		return
	if bag_item == BAG_TIME:  # следующая скорость по кругу; нестандартная (--speed) → ×1
		speed = TIME_SPEEDS[(TIME_SPEEDS.find(speed) + 1) % TIME_SPEEDS.size()]
		settings.time_speed = speed
		settings_changed = true
		return
	if bag_item == BAG_PREMIUM:
		if not profile.premium:
			if Store.buy(profile, Shop.PREMIUM, tester):
				profile_changed = true
			else:
				_set_mode("no")
		return
	if bag_action < 0:
		bag_action = ACTION_USE  # расходник: B открывает подменю USE / BUY / GET
		return
	if bag_action != ACTION_USE:
		var ok := Store.buy(profile, BUY_PRODUCTS[bag_item], tester) if bag_action == ACTION_BUY 				else Store.watch_ad(profile, AD_PRODUCTS[bag_item], tester)
		if ok:
			profile_changed = true
		else:
			bag_action = -1
			_set_mode("no")  # продакшен без B.4: оплата и реклама недоступны
		return
	bag_action = -1
	if bag_item == UMBRELLA:
		# Сам зонтик раскрывается в начале дождя; вручную — только если дождь идёт, а зонтик не раскрыт
		# (дождь начался, когда зонтиков не было).
		if Weather.is_rain(state.clock) and state.rain_cover != "umbrella" and profile.umbrellas > 0:
			profile.umbrellas -= 1
			profile_changed = true
			state.rain_cover = "umbrella"
			_set_mode("idle")  # в комнату — видно раскрытый зонтик
		else:
			_set_mode("no")
		return
	if _is_birth():
		_set_mode("idle")
		return
	# Полностью вылечить можно только после уборки: пока лежат кучки, болезнь не уходит.
	var cures := bag_item == SYRINGE or s.fever - PILL_FEVER < 1
	if s.sick and s.poops and cures:
		_set_mode("no")
		return
	if bag_item == PILL:
		if not s.sick or not (pills_left() or profile.pills):
			_set_mode("no")
			return
		if pills_left():  # сначала 5 бесплатных в день, потом купленные
			if s.pills_day != _pill_day():
				s.pills_day = _pill_day()
				s.pills_used = 0
			s.pills_used += 1
		else:
			profile.pills -= 1
			profile_changed = true
		s.fever = maxf(0.0, s.fever - PILL_FEVER)
		if s.fever < 1:  # не сравниваем с нулём: температура копится дробями, остаток 1e-7 не болезнь
			s.sick = false  # вылечили
			s.fever = 0.0
	elif bag_item == SYRINGE:
		if not profile.syringes:
			_set_mode("no")
			return
		# Шприц лечит всё сразу: болезнь, голод, усталость.
		profile.syringes -= 1
		profile_changed = true
		s.sick = false
		s.fever = 0.0
		s.satiety = 100.0
		s.energy = 100.0
	_set_mode("heal")


# --- отрисовка ---

func render(lcd: Lcd) -> void:
	lcd.clear()
	_dotted(lcd, SEPARATOR_TOP)
	_dotted(lcd, SEPARATOR_BOTTOM)
	if mode in ["settings", "bag", "notify_ask", "about", "abandon"]:
		call("_draw_" + mode, lcd)
		lcd.flush()
		return
	_draw_room(lcd)
	if mode == "select":
		_draw_select(lcd)
		lcd.flush()
		return
	_draw_status(lcd)
	if mode != "dead" and not _is_birth():
		draw_text(lcd, "AGE %d" % floori(state.age / 86400), PLAY_Y + 2, 2)
	if speed != 1.0:  # тестовое ускорение времени — чтобы не забыть, что оно включено
		draw_text(lcd, "X%d" % speed, PLAY_Y + 9, 2)
	call("_draw_" + mode, lcd)
	if mode != "clean":
		_draw_poops(lcd, state.poops)
	_draw_menu(lcd)
	lcd.flush()


static func _dotted(lcd: Lcd, y: int) -> void:
	for x in range(0, COLS, 2):
		lcd.set_px(x, y)


func _draw_status(lcd: Lcd) -> void:
	var s := state
	# [значок, значение, тревога — значок мигает]
	var bars := [
		[Sprites.MINI_SATIETY, s.satiety, s.satiety < SAD_THRESHOLD],
		[Sprites.MINI_HAPPINESS, s.happiness, s.happiness < SAD_THRESHOLD],
		[Sprites.MINI_ENERGY, s.energy, s.energy < SAD_THRESHOLD],
		[Sprites.MINI_HEALTH, s.health, s.health < SAD_THRESHOLD],
		[Sprites.MINI_FEVER, s.fever, s.sick],
	]
	var inner_w := BAR_W - 2
	for i in bars.size():
		var y := STATUS_Y + i * STATUS_STEP
		if not bars[i][2] or frame % 2:
			lcd.blit(bars[i][0], 1, y)
		# рамка со скруглёнными углами
		lcd.hline(BAR_X + 1, y, inner_w)
		lcd.hline(BAR_X + 1, y + 4, inner_w)
		for row in range(1, 4):
			lcd.set_px(BAR_X, y + row)
			lcd.set_px(BAR_X + BAR_W - 1, y + row)
			lcd.hline(BAR_X + 1, y + row, roundi(bars[i][1] / 100.0 * inner_w))


func _draw_room(lcd: Lcd) -> void:
	_dotted(lcd, GROUND + 1)
	if Weather.is_rain(state.clock):
		_draw_rain(lcd)
		return
	if Decay.is_night(state.clock, settings.quiet()):  # игровая ночь = тихие часы: питомец спит до утра
		var sun: Sprites.Sprite = Sprites.SUN[0]
		lcd.blit(Sprites.MOON, SUN_X + (sun.w - Sprites.MOON.w) / 2, SUN_Y + (sun.h - Sprites.MOON.h) / 2)
	else:
		lcd.blit(Sprites.SUN[frame / 2 % 2], SUN_X, SUN_Y)
	var span := COLS + Sprites.CLOUD.w
	var cloud_x := (frame / 2) % span - Sprites.CLOUD.w
	lcd.erase(Sprites.CLOUD_MASK, cloud_x, CLOUD_Y)
	lcd.blit(Sprites.CLOUD, cloud_x, CLOUD_Y)


## Туча у правого края (левее — надпись возраста), капли — под тучей и выше питомца,
## чтобы не сливаться с ним (пиксели на ЖК складываются).
func _draw_rain(lcd: Lcd) -> void:
	var cloud := Sprites.RAIN_CLOUD
	var cloud_x := COLS - cloud.w - 1
	lcd.blit(cloud, cloud_x, RAIN_CLOUD_Y)
	var drop: Sprites.Sprite = Sprites.RAIN[frame % 2]
	var rain_area := Rect2i(cloud_x, 0, cloud.w, RAIN_BOTTOM)
	for y in range(RAIN_CLOUD_Y + cloud.h, RAIN_BOTTOM, drop.h):
		for x in range(cloud_x + 2, cloud_x + cloud.w, drop.w):
			lcd.blit(drop, x, y, false, rain_area)


func _draw_menu(lcd: Lcd) -> void:
	var icons := _icons()
	for i in icons.size():
		lcd.blit(icons[i], ICON_X + i * ICON_STEP, ICON_Y)
	if selected < 0:
		return
	# уголки-скобки вокруг выбранной иконки
	var x0 := ICON_X + selected * ICON_STEP - 2
	var y0 := ICON_Y - 2
	var x1 := x0 + Sprites.ICON_SIZE + 3
	var y1 := y0 + Sprites.ICON_SIZE + 3
	for c in [[x0, y0, 1, 1], [x1, y0, -1, 1], [x0, y1, 1, -1], [x1, y1, -1, -1]]:
		for i in 3:
			lcd.set_px(c[0] + c[2] * i, c[1])
			lcd.set_px(c[0], c[1] + c[3] * i)


func _poop_x(i: int) -> int:
	return COLS - (i + 1) * POOP_SLOT + 1


func _draw_poops(lcd: Lcd, count: int, max_x := COLS) -> void:
	for i in count:
		var x := _poop_x(i)
		if x >= max_x:
			continue
		lcd.blit(Sprites.POOP, x, GROUND - Sprites.POOP.h)
		lcd.blit(Sprites.STINK, x + 3, GROUND - Sprites.POOP.h - 7, (frame + i) % 2 == 1)


func _draw_pet(lcd: Lcd, x: int) -> void:
	var s := state
	if _is_birth():
		_draw_birth(lcd)
		return
	var lk := look()
	var y := _y_for(lk.h)
	_draw_umbrella(lcd, x, y, lk.w)
	if s.sleeping:
		lcd.blit(lk.sleep, x, y)
		if frame % 2:
			lcd.blit(Sprites.Z_BIG, x + lk.w + 2, y - 14)
		else:
			lcd.blit(Sprites.Z_SMALL, x + lk.w - 2, y - 6)
		return
	var sad := s.satiety < SAD_THRESHOLD or s.happiness < SAD_THRESHOLD or s.poops > 0 or s.sick
	var frames: Array = lk.sad if sad else lk.idle
	lcd.blit(frames[frame % 2], x, y, pet_dir < 0)
	if s.sick and frame % 2:  # череп над головой больного
		lcd.blit(Sprites.SICK, x + lk.w - 3, y - Sprites.SICK.h - 2)


## Зонтик над питомцем, пока он раскрыт на текущий дождь.
func _draw_umbrella(lcd: Lcd, x: int, y: int, w: int) -> void:
	if state.rain_cover == "umbrella" and Weather.is_rain(state.clock):
		var u := Sprites.UMBRELLA
		var ux := x + (w - u.w) / 2
		var uy := y - u.h - 1
		lcd.erase_rect(ux, uy, u.w, y - uy)  # зонтик закрывает капли — под ним сухо
		lcd.blit(u, ux, uy, false, PLAY_AREA)


func _draw_birth(lcd: Lcd) -> void:
	var waking := state.age >= Evolution.BIRTH_UNTIL - WAKE_BEFORE
	var wobble: int = [0, 1, 0, -1][frame % 4] if waking or frame % 8 < 4 else 0
	var sprite := _birth_sprite(waking)
	lcd.blit(sprite, _home_x() + wobble, _y_for(sprite.h))


func _draw_idle(lcd: Lcd) -> void:
	_draw_pet(lcd, _home_x() if state.sleeping else pet_x)


func _draw_evolve(lcd: Lcd) -> void:
	# Старый и новый облик мигают по очереди, последние тики — только новый.
	var show_old := mode_ticks < ANIM_LENGTH["evolve"] - 4 and frame % 2 == 1
	var sprite: Sprites.Sprite
	if not show_old:
		sprite = look().happy
	elif evolved_from == Evolution.BIRTH:
		sprite = _birth_sprite(true)
	else:
		sprite = skin().look(evolved_from).idle[0]
	lcd.blit(sprite, _center_for(sprite.w), _y_for(sprite.h))


func _draw_eat(lcd: Lcd) -> void:
	var poop_left := _poop_x(state.poops - 1) if state.poops else COLS
	var food_x := mini(44, poop_left - Sprites.FOOD.w - 1)
	var lk := look()
	var x := maxi(0, food_x - lk.w - 2)
	lcd.blit(lk.eat[mode_ticks % 2], x, _y_for(lk.h))
	_draw_umbrella(lcd, x, _y_for(lk.h), lk.w)
	var bites := mode_ticks / 2
	if bites < 4:
		var food := Sprites.FOOD.cropped(Sprites.FOOD.w - bites * 3)
		lcd.blit(food, food_x, GROUND - food.h)


func _draw_play(lcd: Lcd) -> void:
	var jump := 8 if mode_ticks % 2 else 0
	lcd.blit(look().happy, _home_x(), _y_for(look().h) - jump, false, PLAY_AREA)
	_draw_umbrella(lcd, _home_x(), _y_for(look().h) - jump, look().w)


func _draw_no(lcd: Lcd) -> void:
	var shake := 2 if mode_ticks % 2 else -2
	lcd.blit(look().sad[0], maxi(0, _home_x() + shake), _y_for(look().h))
	_draw_umbrella(lcd, maxi(0, _home_x() + shake), _y_for(look().h), look().w)


func _draw_clean(lcd: Lcd) -> void:
	# Волна идёт справа налево и смывает кучки, которые уже прошла.
	var wave_x := COLS - (mode_ticks + 1) * COLS / ANIM_LENGTH["clean"]
	_draw_pet(lcd, _home_x() if state.sleeping else pet_x)
	_draw_poops(lcd, cleaning_poops, wave_x)
	var wave := Sprites.WAVE
	for y in range(GROUND - wave.h, PLAY_Y, -wave.h):
		lcd.blit(wave, wave_x, y, frame % 2 == 1)


func _draw_dead(lcd: Lcd) -> void:
	var ghost := Sprites.GHOST
	var y := _y_for(ghost.h) - 6 + 2 * (frame % 2)
	lcd.blit(ghost, _center_for(ghost.w), y, false, PLAY_AREA)


func _draw_heal(lcd: Lcd) -> void:
	# Довольный питомец и «плюсики» вокруг.
	var lk := look()
	var x := _home_x()
	var y := _y_for(lk.h)
	lcd.blit(lk.happy, x, y)
	_draw_umbrella(lcd, x, y, lk.w)
	var plus: Sprites.Sprite = Sprites.FONT["+"]
	var spots := [[-5, 4], [lk.w + 2, 8], [-3, 16], [lk.w, 0]]
	for i in spots.size():
		if (i + mode_ticks) % 2:
			lcd.blit(plus, x + spots[i][0], y + spots[i][1])


# --- экран выбора питомца ---

func _draw_select(lcd: Lcd) -> void:
	var sk := skin()
	# Имя (латиницей) крупным шрифтом в верхней панели и точки-страницы под ним.
	draw_text(lcd, sk.name, NAME_Y, -1, 2)
	var count := Sprites.PETS.size()
	var dots_x := (COLS - (count * 4 - 1)) / 2
	for i in count:
		var x := dots_x + i * 4
		if i == choice:
			for dy in 3:
				lcd.hline(x, DOTS_Y + dy, 3)
		else:
			lcd.set_px(x + 1, DOTS_Y + 1)
	var lk := look()
	var pet_y := _y_for(lk.h)
	lcd.blit(lk.idle[frame % 2], _center_for(lk.w), pet_y)
	var unlocked := Shop.is_unlocked(profile, sk)
	if not unlocked:
		var lock := Sprites.LOCK
		lcd.blit(lock, _center_for(lock.w), pet_y - lock.h - 6)
		draw_text(lcd, "LOCKED", pet_y - lock.h - 16)
	var arrow_y := pet_y + (lk.h - Sprites.ARROW_LEFT.h) / 2
	lcd.blit(Sprites.ARROW_LEFT, 4, arrow_y)
	lcd.blit(Sprites.ARROW_RIGHT, COLS - 4 - Sprites.ARROW_RIGHT.w, arrow_y)
	# Подсказка на месте меню: A ◀   B   ▶ C
	var hint_y := ICON_Y + 3
	draw_text(lcd, "A", hint_y, ICON_X + 2)
	lcd.blit(Sprites.ARROW_LEFT, ICON_X + 8, hint_y)
	if unlocked:
		draw_text(lcd, "B", hint_y)
	lcd.blit(Sprites.ARROW_RIGHT, COLS - ICON_X - 12, hint_y)
	draw_text(lcd, "C", hint_y, COLS - ICON_X - 6)


static func text_width(text: String, scale: int) -> int:
	var total := 0
	for ch in text.to_upper():
		var g: Sprites.Sprite = Sprites.FONT.get(ch)
		total += (g.w if g else 3) + 1
	return total * scale - scale


## Текст пиксельным шрифтом; x < 0 — по центру экрана. Неизвестные символы — пробел.
func draw_text(lcd: Lcd, text: String, y: int, x := -1, scale := 1) -> void:
	if x < 0:
		x = (COLS - text_width(text, scale)) / 2
	for ch in text.to_upper():
		var g: Sprites.Sprite = Sprites.FONT.get(ch)
		if g:
			lcd.blit(g, x, y, false, Rect2i(0, 0, COLS, ROWS), scale)
		x += ((g.w if g else 3) + 1) * scale


# --- экран настроек ---

func _draw_settings(lcd: Lcd) -> void:
	var st := settings
	draw_text(lcd, "SETTINGS", 15)
	draw_text(lcd, "QUIET HOURS", 42)
	var rows := [["FROM", st.quiet_start, 54], ["TO", st.quiet_end, 72]]
	for i in rows.size():
		var y: int = rows[i][2]
		if i == settings_field:
			lcd.blit(Sprites.ARROW_RIGHT, 2, y + 3)
		draw_text(lcd, rows[i][0], y + 3, 8)
		draw_text(lcd, "%02d:00" % rows[i][1], y, 30, 2)
	var lines := [[FIELD_CALLS, "CALLS ON" if st.calls_enabled else "CALLS OFF", 94], [FIELD_SOUND, "SOUND", 104]]
	for line in lines:
		if line[0] == settings_field:
			lcd.blit(Sprites.ARROW_RIGHT, 2, line[2])
		draw_text(lcd, line[1], line[2], 8)
	var now := Decay.local_time(state.clock)
	draw_text(lcd, settings_note if settings_note else "NOW %02d:%02d" % [now.hour, now.minute], 120)
	var action: String = ["+1", "+1", "SET", "OPEN"][settings_field]
	draw_text(lcd, "A NEXT  B " + action, ICON_Y)
	draw_text(lcd, "C BACK", ICON_Y + 9)


# --- экран разрешения на уведомления ---

func _draw_notify_ask(lcd: Lcd) -> void:
	draw_text(lcd, "HELLO", 12, -1, 2)
	var lines := ["I WILL CALL YOU", "WHEN I NEED YOU", "", "PLEASE ALLOW", "NOTIFICATIONS"]
	for i in lines.size():
		draw_text(lcd, lines[i], 50 + i * 10)
	draw_text(lcd, "B OK", ICON_Y + 3)


# --- экран About ---

## Версия сборки: CI проставляет её в application/config/version, локально — 0.0.0.
static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


## Письмо разработчику: адрес, тема и сведения о сборке и устройстве — текст игрок допишет сам.
static func feedback_mailto() -> String:
	var body := "

---
Version: %s
Device: %s
OS: %s %s" % [version(), OS.get_model_name(), OS.get_name(), OS.get_version()]
	return "mailto:%s?subject=%s&body=%s" % [FEEDBACK_EMAIL, "Tamahochi feedback".uri_encode(), body.uri_encode()]


func _draw_about(lcd: Lcd) -> void:
	draw_text(lcd, "ABOUT", 15)
	var lines := ["TAMAHOCHI", "V " + version(), "", "MADE BY SNI10", "WITH LOVE", "TO PETS"]
	for i in lines.size():
		draw_text(lcd, lines[i], 48 + i * 11)
	draw_text(lcd, "B FEEDBACK", ICON_Y)
	draw_text(lcd, "C BACK", ICON_Y + 9)


# --- экран «новая игра» ---

func _draw_abandon(lcd: Lcd) -> void:
	draw_text(lcd, "NEW GAME", 15)
	draw_text(lcd, "YOU WILL LEAVE", 44)
	draw_text(lcd, "YOUR PET", 53)
	var sad: Sprites.Sprite = look().sad[frame % 2]
	lcd.blit(sad, _center_for(sad.w), 112 - sad.h)
	draw_text(lcd, "B CONFIRM", ICON_Y)
	draw_text(lcd, "C BACK", ICON_Y + 9)


# --- экран сумки ---

func _draw_bag(lcd: Lcd) -> void:
	var icon: Sprites.Sprite = _bag_icons()[bag_item]
	draw_text(lcd, "BAG", 15)
	lcd.blit(icon, (COLS - icon.w * 2) / 2, 50, false, Rect2i(0, 0, COLS, ROWS), 2)
	lcd.blit(Sprites.ARROW_LEFT, 8, 58)
	lcd.blit(Sprites.ARROW_RIGHT, COLS - 8 - Sprites.ARROW_RIGHT.w, 58)
	draw_text(lcd, BAG_NAMES[bag_item], 84)
	if bag_item == BAG_PREMIUM:
		var lines := ["ALL PETS", "%d PILLS" % Shop.PREMIUM_PILLS, "%d SYRINGES" % Shop.PREMIUM_SYRINGES, "%d UMBRELLAS" % Shop.PREMIUM_UMBRELLAS]
		for i in lines.size():
			draw_text(lcd, lines[i], 95 + i * 8)
		draw_text(lcd, "OWNED" if profile.premium else "A NEXT  B BUY", ICON_Y)
		draw_text(lcd, "C BACK", ICON_Y + 9)
		return
	if bag_item == PILL:
		draw_text(lcd, "FREE %d/%d  X%d" % [pills_left(), FREE_PILLS_PER_DAY, profile.pills], 96)
	elif bag_item == SYRINGE:
		draw_text(lcd, "X %d" % profile.syringes, 96)
	elif bag_item == UMBRELLA:
		draw_text(lcd, "X %d" % profile.umbrellas, 96)
	elif bag_item == BAG_TIME:
		draw_text(lcd, "SPEED X%d" % speed, 96)
	if bag_item in BUY_PRODUCTS:
		if bag_action >= 0:  # подменю: USE / BUY Xn / GET X1 (реклама)
			var labels := ["USE", "BUY X%d" % PACK_SIZES[bag_item], "GET X1 AD"]
			for i in labels.size():
				if i == bag_action:
					lcd.blit(Sprites.ARROW_RIGHT, 14, 107 + i * 8)
				draw_text(lcd, labels[i], 107 + i * 8, 20)
			draw_text(lcd, "A NEXT  B OK", ICON_Y)
		else:
			draw_text(lcd, "A NEXT  B MENU", ICON_Y)
		draw_text(lcd, "C BACK", ICON_Y + 9)
		return
	var action := "OPEN" if bag_item in [BAG_SETTINGS, BAG_ABOUT, BAG_NEW] else "SET"
	draw_text(lcd, "A NEXT  B %s" % action, ICON_Y)
	draw_text(lcd, "C BACK", ICON_Y + 9)
