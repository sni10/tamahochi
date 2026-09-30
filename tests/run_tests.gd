extends SceneTree
## Проверки Godot-порта. Запуск: godot --headless --path . -s res://tests/run_tests.gd
## Код выхода 1 — что-то упало.

const HOUR := 3600.0
var failed := 0
var passed := 0


func check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		printerr("FAIL: ", what)


func _initialize() -> void:
	Weather.enabled = false  # точные числа в старых тестах; погоду тестируют test_weather/test_rain
	check(Sprites.error.is_empty(), "ассеты загружены: " + Sprites.error)
	test_sprite_loader()
	test_lcd()
	test_pet_state()
	test_evolution()
	test_decay()
	test_game()
	test_storage()
	test_shop()
	test_calls()
	test_age()
	test_weather()
	test_rain()
	test_rain_sky()
	test_umbrella()
	test_umbrella_screens()
	test_notifications()
	test_call_rain_growth()
	test_notify_ask()
	test_settings_calls()
	test_about()
	test_tester_time()
	test_moon()
	test_shop_stubs()
	test_new_game()
	test_no_play_in_rain()
	test_umbrella_shelter()
	test_umbrella_manual()
	print("passed %d, failed %d" % [passed, failed])
	quit(1 if failed else 0)


func test_sprite_loader() -> void:
	var r := Sprites.parse_sheet("; c\nname: X\n[a]\n#.#\n#x#\n", "t.txt")
	check(r.error.contains("t.txt:5"), "чужой символ → файл:строка, получили: " + r.error)
	r = Sprites.parse_sheet("[a]\n##\n###\n", "t.txt")
	check(r.error.contains("одной длины"), "разная длина строк")
	r = Sprites.parse_sheet("[a]\n#\n[a]\n#\n", "t.txt")
	check(r.error.contains("уже был"), "повтор имени")
	r = Sprites.parse_sheet("oops\n", "t.txt")
	check(r.error.contains("t.txt:1"), "строка без двоеточия")
	r = Sprites.parse_sheet("name: CAT\n[a]\n.#\n#.\n", "t.txt")
	check(r.error == "" and r.meta.name == "CAT" and r.sheet.a.w == 2 and r.sheet.a.rows[0][1] == 1, "разбор файла")
	check(Sprites.parse_sheet("[a]\n####\n", "t").sheet.a.cropped(2).w == 2, "cropped")

	var keys := Sprites.PETS.keys()
	check(keys.size() == 5 and keys[0] == "blob", "5 видов, первый BLOB: %s" % [keys])
	var cat: Sprites.PetSkin = Sprites.PETS.cat
	check(cat.name == "CAT" and cat.order == 1 and cat.birth == "basket" and not cat.free, "свойства CAT")
	check(Sprites.PETS.blob.free, "BLOB бесплатный")
	check(cat.look("baby").w == 16 and cat.look("adult_good").w == 28, "стадии CAT")
	for s in [Sprites.ICON_FOOD, Sprites.ICON_PLAY, Sprites.ICON_SLEEP, Sprites.ICON_CLEAN, Sprites.ICON_BAG,
			Sprites.ICON_SETTINGS, Sprites.ITEM_PILL, Sprites.ITEM_SYRINGE, Sprites.MINI_FEVER, Sprites.SICK,
			Sprites.LOCK, Sprites.MINI_SATIETY, Sprites.MINI_HAPPINESS, Sprites.MINI_ENERGY, Sprites.MINI_HEALTH,
			Sprites.ARROW_LEFT, Sprites.ARROW_RIGHT, Sprites.SUN[0], Sprites.SUN[1], Sprites.CLOUD,
			Sprites.CLOUD_MASK, Sprites.FOOD, Sprites.POOP, Sprites.STINK, Sprites.WAVE, Sprites.Z_BIG,
			Sprites.Z_SMALL, Sprites.GHOST, Sprites.BIRTH.egg[1], Sprites.BIRTH.basket[1], Sprites.FONT["+"]]:
		check(s != null, "константа спрайта загружена")
	check(Sprites.ICON_SIZE == 12, "ICON_SIZE")


# --- ЖК ---

func test_lcd() -> void:
	var lcd := Lcd.new()
	var sp: Sprites.Sprite = Sprites.parse_sheet("[s]\n#.\n##\n", "t").sheet.s
	lcd.set_px(1, 0)
	lcd.blit(sp, 0, 0)
	check(lcd.get_px(0, 0) and lcd.get_px(1, 0), "прозрачность: '.' не гасит включённый пиксель")
	lcd.clear()
	lcd.blit(sp, 0, 0, true)
	check(not lcd.get_px(0, 0) and lcd.get_px(1, 0), "отражение")
	lcd.clear()
	lcd.blit(sp, 10, 36, false, Game.PLAY_AREA)
	check(not lcd.get_px(10, 36) and lcd.get_px(10, 37), "отсечение по PLAY_AREA")
	lcd.clear()
	lcd.blit(sp, 0, 0, false, Rect2i(0, 0, 72, 156), 2)
	check(lcd.get_px(1, 1) and not lcd.get_px(2, 0) and lcd.get_px(3, 3), "scale 2")
	lcd.blit(sp, 0, 0)
	lcd.erase(sp, 0, 0)
	check(not lcd.get_px(0, 0) and lcd.get_px(1, 0), "erase гасит только под '#' маски")
	lcd.blit(sp, 0, 155)
	lcd.blit(sp, 71, -1)
	check(lcd.get_px(0, 155) and lcd.get_px(71, 0), "частично за экраном — без ошибок")
	lcd.free()


# --- модель ---

func test_pet_state() -> void:
	var s := PetState.new("cat")
	s.care_mistakes = 3
	var d := JSON.parse_string(JSON.stringify(s.to_dict(), "", false, true)) as Dictionary
	var back := PetState.from_dict(d)
	check(back.to_dict() == s.to_dict() and typeof(back.care_mistakes) == TYPE_INT, "круговая сериализация")
	var old := PetState.from_dict({"satiety": 50, "updated_at": 123.0, "junk": 1})
	check(old.stage == "adult_normal" and old.clock == 123.0 and old.satiety == 50.0, "старый формат")
	check(PetState.from_dict({"stage": "egg"}).stage == "birth", "egg → birth")


func test_evolution() -> void:
	check([2, 3, 6, 7].map(Evolution.adult_for) == ["adult_good", "adult_normal", "adult_normal", "adult_bad"], "adult_for")
	var s := PetState.new()
	s.age = 100 * HOUR
	s.care_mistakes = 1
	Evolution.grow(s)
	check(s.stage == "adult_good", "скачок через несколько стадий")


func _adult() -> PetState:
	var s := PetState.new()
	s.stage = "adult_normal"
	return s


func test_decay() -> void:
	var s := _adult()
	Decay.apply(s, HOUR)
	check(is_equal_approx(s.satiety, 94) and is_equal_approx(s.happiness, 92) and is_equal_approx(s.energy, 90), "час днём взрослого")
	s = _adult()
	s.stage = "baby"
	Decay.apply(s, HOUR)
	check(is_equal_approx(s.satiety, 91), "малыш −9 сытости")
	s = _adult()
	Decay.apply(s, 5 * HOUR + 60)
	check(s.poops == 1, "кучка через 5 часов")
	s = _adult()
	s.poops = 2
	s.digestion = 99.9
	Decay.apply(s, 60)
	check(s.sick and s.care_mistakes == 1, "третья кучка → болен, +1 ошибка")
	s = _adult()
	s.sick = true
	for hour in 12:  # кормим каждый час — убивает только температура
		check(s.alive, "жив на %d ч болезни" % hour)
		s.satiety = 100
		s.happiness = 100
		Decay.apply(s, HOUR)
	Decay.apply(s, 60)  # float: сумма шагов даёт 99.99…
	check(not s.alive and s.fever >= 100, "умер от температуры за ~12 ч")
	s = _adult()
	s.updated_at = 1000.0
	Decay.advance(s, 500.0)
	check(s.satiety == 100.0 and s.updated_at == 500.0, "часы назад — без изменений")
	check(not Decay.is_night(0.0, [8, 8]) and not Decay.is_night(0.0, []), "start == end — ночи нет")


# --- игра ---

func test_game() -> void:
	var s := _adult()
	var g := Game.new(s)
	s.updated_at -= 1  # чтобы тик что-то прожил
	s.stage = "birth"
	s.age = 5 * 60 - 0.5
	g.tick()
	check(g.mode == "evolve" and g.evolved_from == "birth", "эволюция в тике")

	g = Game.new(_adult())
	g.state.satiety = 96
	g.press_a()
	g.press_b()
	check(g.mode == "no" and g.state.satiety == 96, "сытый отказывается")
	g = Game.new(_adult())
	g.state.satiety = 50
	g.press_a()
	g.press_b()
	g.press_a()
	check(g.mode == "eat" and g.state.satiety == 65 and g.selected == 0, "еда, A во время анимации игнорируется")

	g = Game.new(_adult())
	g.state.species = "cat"
	g.state.alive = false
	g = Game.new(g.state)
	g.press_a()
	g.press_c()
	check(g.mode == "dead", "A/C на смерти ничего не делают")
	g.press_b()
	check(g.mode == "select" and Sprites.PETS.keys()[g.choice] == "cat", "после смерти B → выбор того же вида")
	g.press_b()
	check(g.mode == "select", "закрытый CAT не выбирается")
	g.press_a()
	g.press_b()
	check(g.mode == "idle" and g.state.species == "blob" and g.state.stage == "birth", "выбор BLOB")

	g = Game.new(_adult())
	g.selected = Game.BAG
	g.press_b()
	check(g.mode == "bag", "сумка открылась")
	_bag_use(g)
	check(g.mode == "no" and g.pills_left() == 5, "таблетка здоровому — отказ")
	g.mode = "bag"
	g.state.sick = true
	g.state.fever = 8
	g.state.poops = 1
	_bag_use(g)
	check(g.mode == "no" and g.state.sick and g.state.fever == 8 and g.pills_left() == 5,
			"кучки не убраны — последняя таблетка не лечит и не тратится")
	g.mode = "bag"
	g.state.fever = 25
	_bag_use(g)
	check(g.mode == "heal" and g.state.sick and g.state.fever == 15 and g.pills_left() == 4,
			"с кучками таблетка сбивает температуру, но не до конца")
	g.state.poops = 0
	g.state.fever = 8
	g.mode = "bag"
	_bag_use(g)
	check(g.mode == "heal" and not g.state.sick and g.pills_left() == 3, "после уборки таблетка вылечила")
	g.state.sick = true
	g.state.fever = 10.0000001
	g.mode = "bag"
	_bag_use(g)
	check(not g.state.sick and g.state.fever == 0.0, "остаток температуры 1e-7 — тоже вылечен")
	g.state.pills_day = "2000-01-01"
	g.state.pills_used = 5
	check(g.pills_left() == 5, "новый день — снова 5 таблеток")
	g.mode = "bag"
	g.bag_item = Game.SYRINGE
	_bag_use(g)
	check(g.mode == "no", "шприцев нет — отказ")
	g.mode = "bag"
	g.profile.syringes = 2
	g.state.satiety = 10
	_bag_use(g)
	check(g.state.satiety == 100 and g.profile.syringes == 1 and g.profile_changed, "шприц")
	g.mode = "bag"
	g.state.sick = true
	g.state.poops = 2
	_bag_use(g)
	check(g.mode == "no" and g.state.sick and g.profile.syringes == 1, "больного с кучками шприц не лечит и не тратится")
	g.state.poops = 0
	g.state.sick = false
	g.mode = "bag"
	g.bag_item = Game.BAG_SETTINGS
	_bag_use(g)
	g.settings.quiet_start = 23
	_bag_use(g)
	check(g.mode == "settings" and g.settings.quiet_start == 0 and g.settings_changed, "FROM 23 → 00")
	g.press_c()
	check(g.mode == "bag", "C из настроек → сумка")

	check(Game.text_width("BAG", 1) == 14, "ширина BAG: %d" % Game.text_width("BAG", 1))
	# Все экраны рисуются без ошибок.
	var lcd := Lcd.new()
	g = Game.new(null)
	g.render(lcd)
	g = Game.new(_adult())
	g.state.poops = 2
	g.state.sick = true
	for m in ["idle", "eat", "play", "no", "clean", "heal", "bag", "settings", "dead"]:
		g.mode = m
		g.cleaning_poops = 2
		for t in 8:
			g.frame = t
			g.mode_ticks = t
			g.render(lcd)
	g.state.stage = "birth"
	g.mode = "idle"
	g.render(lcd)
	g.state.stage = "baby"
	g.start_evolution("birth")
	g.render(lcd)
	lcd.free()


# --- хранилище ---

func test_storage() -> void:
	var path := "user://test_save.json"
	var s := PetState.new("bunny")
	s.poops = 2
	Storage.save_pet(s, path)
	s.poops = 3
	Storage.save_pet(s, path)  # перезапись существующего
	check(Storage.load_pet(path).poops == 3 and Storage.load_pet(path).species == "bunny", "запись и перезапись")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	check(Storage.load_pet(path) == null, "битый JSON → новая игра")
	check(Storage.load_settings("user://nope.json").quiet() == [22, 8], "настройки по умолчанию")
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"syringes": 3, "owned_pets": ["cat"], "premium": false}')
	f.close()
	var p := Storage.load_profile(path)
	check(p.syringes == 3 and p.owned_pets == ["cat"], "профиль")
	DirAccess.remove_absolute(path)


# --- магазин ---

func test_shop() -> void:
	var p := Storage.Profile.new()
	check(Shop.grant(p, Shop.AD_REWARD) and p.syringes == 1, "ad_reward")
	check(Shop.grant(p, Shop.SYRINGE_PACK) and p.syringes == 6, "syringe_pack")
	check(not Shop.is_unlocked(p, Sprites.PETS.cat), "CAT закрыт")
	check(Shop.grant(p, "pet_cat") and Shop.is_unlocked(p, Sprites.PETS.cat), "pet_cat")
	check(not Shop.grant(p, "pet_cat") and not Shop.grant(p, "pet_blob") and not Shop.grant(p, "pet_nope"), "повторы и бесплатный")
	check(Shop.grant(p, Shop.PREMIUM) and p.syringes == 31 and p.pills == 50 and p.umbrellas == 25, "premium: +50 таблеток, +25 шприцев, +25 зонтиков")
	check(not Shop.grant(p, Shop.PREMIUM) and p.syringes == 31 and p.pills == 50, "premium второй раз ничего не даёт")
	var q := Storage.Profile.new()
	Shop.grant(q, Shop.PREMIUM)
	var all_open := true
	for key in Sprites.PETS:
		all_open = all_open and Shop.is_unlocked(q, Sprites.PETS[key])
	check(all_open, "premium открывает всех питомцев")


# --- следующий зов ---

## Местное время 2026-01-15 + hours (с учётом сдвига пояса, как в Decay.local_time).
func _local(hours: float) -> float:
	return Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 1, "day": 15, "hour": 0, "minute": 0, "second": 0}) \
			- Decay.tz_bias * 60 + hours * HOUR


func _pet_at(clock: float) -> PetState:
	var s := _adult()
	s.clock = clock
	s.updated_at = clock
	return s


func test_calls() -> void:
	var s := _pet_at(_local(12))
	s.satiety = 20
	s.poops = 1
	check(Calls.reasons(s) == ["hungry", "poop"], "поводы: сытость 20 + кучка (главный — голод)")

	var now := _local(12)
	s = _pet_at(now)
	var before := s.to_dict()
	var c := Calls.next_call(s, [], now)
	check(absf(c.at - now - 5 * HOUR) <= 60 and c.reasons == ["poop"], "сытый днём → кучка через 5 ч: %s" % [c])
	check(s.to_dict() == before, "исходное состояние не изменилось")

	s = _pet_at(now)
	s.digestion = 99.9
	c = Calls.next_call(s, [], now)
	check(c.at == now + 60 and c.reasons == ["poop"], "кучка вот-вот → через минуту")

	s = _pet_at(now)
	s.satiety = 10
	c = Calls.next_call(s, [22, 8], now)
	check(c.at == now and c.reasons == ["hungry"], "повод уже есть → сейчас")

	s = _pet_at(now)
	s.alive = false
	c = Calls.next_call(s, [22, 8], now)
	check(c.at == now and c.reasons == ["dead"], "мёртв → сейчас")

	# 23:00, питомца разбудили: пищеварение идёт, кучка к 02:00 — зов ждёт 08:00.
	now = _local(23)
	s = _pet_at(now)
	s.digestion = 40
	c = Calls.next_call(s, [], now)
	check(absf(c.at - _local(26)) <= 60, "без тихих часов кучка в 02:00: %s" % [c])
	c = Calls.next_call(s, [22, 8], now)
	check(absf(c.at - _local(32)) <= 60 and "poop" in c.reasons, "кучка ночью → зов в 08:00: %s" % [c])

	s = _pet_at(now)
	s.poops = 1
	s.sleeping = true
	c = Calls.next_call(s, [22, 8], now)
	check(c.at == _local(32) and "poop" in c.reasons, "кучка в 23:00 → зов в 08:00")


# --- возраст на экране ---

func _corner(lcd: Lcd) -> PackedByteArray:
	var out := PackedByteArray()
	for y in range(Game.PLAY_Y + 1, Game.PLAY_Y + 9):
		for x in 40:
			out.append(lcd.buf[y * Lcd.COLS + x])
	return out


func test_age() -> void:
	var lcd := Lcd.new()
	var clean := Lcd.new()
	var g := Game.new(_adult())
	g.state.age = 3 * 86400 + 5 * HOUR
	g.render(lcd)
	g.draw_text(clean, "AGE 3", Game.PLAY_Y + 2, 2)
	check(_corner(lcd) == _corner(clean), "AGE 3 в углу комнаты")
	g.state.age = 100
	g.state.stage = "baby"
	g.render(lcd)
	clean.clear()
	g.draw_text(clean, "AGE 0", Game.PLAY_Y + 2, 2)
	check(_corner(lcd) == _corner(clean), "AGE 0 в первый день")
	clean.clear()
	g.state.stage = "birth"
	g.render(lcd)
	check(_corner(lcd) == _corner(clean), "в яйце возраста нет")
	g.state.stage = "adult_normal"
	g.mode = "dead"
	g.render(lcd)
	check(_corner(lcd) == _corner(clean), "после смерти возраста нет")
	lcd.free()
	clean.free()


# --- погода ---

func test_weather() -> void:
	Weather.enabled = true
	check(Weather.rains_of(2026, 1, 15) == Weather.rains_of(2026, 1, 15), "одна дата — один результат")
	var ok := true
	var counts := {1: 0, 2: 0}
	var short_n := 0
	var short_inf := 0
	var long_n := 0
	var long_inf := 0
	var day := Time.get_unix_time_from_datetime_string("2026-01-01T00:00:00")
	for i in 1000:
		var d := Time.get_datetime_dict_from_unix_time(day + i * 86400)
		var rs := Weather.rains_of(d.year, d.month, d.day)
		ok = ok and rs.size() in [1, 2]
		counts[rs.size()] = counts.get(rs.size(), 0) + 1
		var prev_end := 0
		for r in rs:
			var in_window: bool = (r.start >= 6 * 60 and r.start < 13 * 60) or (r.start >= 14 * 60 and r.start < 21 * 60)
			ok = ok and r.minutes >= 20 and r.minutes <= 60 and in_window and r.start >= prev_end and r.start + r.minutes <= 22 * 60
			prev_end = r.start + r.minutes
			if r.minutes <= 25:
				short_n += 1
				short_inf += int(r.infects)
			elif r.minutes >= 55:
				long_n += 1
				long_inf += int(r.infects)
	check(ok, "1000 дат: 1–2 дождя, 20–60 мин, в своих окнах, без пересечений, до 22:00")
	check(counts[1] > 300 and counts[2] > 300, "бывает и 1, и 2 дождя: %s" % [counts])
	check(short_n > 50 and long_n > 50, "есть и короткие, и длинные дожди: %d / %d" % [short_n, long_n])
	check(short_inf >= short_n * 0.15 and short_inf <= short_n * 0.35, "короткие заражают 15–35%%: %d из %d" % [short_inf, short_n])
	check(long_inf >= long_n * 0.65 and long_inf <= long_n * 0.9, "длинные заражают 65–90%%: %d из %d" % [long_inf, long_n])
	check(is_equal_approx(Weather.infect_chance(20), 0.2) and is_equal_approx(Weather.infect_chance(60), 0.8), "шанс: 20 мин — 20%%, 60 мин — 80%%")
	var rd := _rain_day(10)
	var start := _at(rd[0], rd[1])
	var minutes: int = Weather.rain_at(start + 60).minutes
	check(Weather.is_rain(start + 60) and not Weather.is_rain(start + minutes * 60 + 60), "is_rain внутри и после дождя")
	check(not Weather.is_rain(_at(rd[0], 3)), "ночью дождя нет")
	Weather.enabled = false
	check(not Weather.is_rain(start + 60), "выключатель")



## Применить расходник в сумке: подменю — строка USE — B.
func _bag_use(g: Game) -> void:
	g.bag_action = Game.ACTION_USE
	g.press_b()

# --- дождь и счастье ---

func _at(d: Dictionary, hours: float) -> float:
	return Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day,
			"hour": 0, "minute": 0, "second": 0}) - Decay.tz_bias * 60 + hours * HOUR


## Первый с 2026-01-01 дождь не короче `minutes` минут (ровно `minutes`, если exact; и, если задано,
## заражающий или нет): [дата, начало в часах от полуночи].
func _rain_day(minutes: int, infects: Variant = null, exact := false) -> Array:
	var day := Time.get_unix_time_from_datetime_string("2026-01-01T00:00:00")
	while true:
		var d := Time.get_datetime_dict_from_unix_time(day)
		for r in Weather.rains_of(d.year, d.month, d.day):
			var fits: bool = r.minutes == minutes if exact else r.minutes >= minutes
			if fits and (infects == null or r.infects == infects):
				return [d, r.start / 60.0]
		day += 86400
	return []


func test_rain() -> void:
	Weather.enabled = true
	var old := PetState.from_dict({"stage": "adult_normal"})
	check(old.rain_loss == 0.0, "сохранение без rain_loss → 0")
	old.rain_loss = 7.5
	check(PetState.from_dict(old.to_dict()).rain_loss == 7.5, "rain_loss сохраняется")

	var rd := _rain_day(30, null, true)  # ровно 30 минут — на этом построена арифметика счастья
	var start := _at(rd[0], rd[1]) - 60  # шаги по минуте: первый шаг заканчивается в первую минуту дождя
	var s := _pet_at(start)
	Decay.apply(s, HOUR)
	check(is_equal_approx(s.happiness, 88), "час, из них 30 мин дождя: −12, получили %s" % s.happiness)
	check(s.rain_loss == 0.0, "после дождя счётчик обнулился")
	s = _pet_at(start)
	s.rain_loss = 14
	Decay.apply(s, 30 * 60)
	check(is_equal_approx(s.rain_loss, 15), "лимит 15 за дождь: добавка упёрлась, получили %s" % s.rain_loss)

	s = _pet_at(start)
	s.sleeping = true
	Decay.apply(s, HOUR, [0, 23])
	check(s.happiness == 100.0, "ночной сон под дождём — счастье не меняется")

	s = _pet_at(start)
	Decay.apply(s, 15 * 60)
	s = PetState.from_dict(s.to_dict())  # «перезапуск» посреди дождя
	var before := s.happiness
	Decay.apply(s, 10 * 60)
	check(is_equal_approx(before - s.happiness, 2 * 8.0 / 6) and s.rain_loss <= 15.0, "после перезапуска дождь продолжается, лимит держится")
	Weather.enabled = false


# --- небо в дождь ---

func _render(g: Game, frame: int) -> PackedByteArray:
	var lcd := Lcd.new()
	g.frame = frame
	g.render(lcd)
	var out := lcd.buf.duplicate()
	lcd.free()
	return out


func test_rain_sky() -> void:
	check(Sprites.RAIN_CLOUD != null and Sprites.RAIN[0].w == Sprites.RAIN[1].w and Sprites.RAIN[0].h == Sprites.RAIN[1].h,
			"спрайты тучи и капель загружены, кадры одного размера")
	Weather.enabled = true
	var rd := _rain_day(10)
	var g := Game.new(_pet_at(_at(rd[0], rd[1] + 5 / 60.0)))
	g.state.age = 3 * 86400
	var sunny := Game.new(_pet_at(_at(rd[0], 3)))  # 03:00 — дождей не бывает
	sunny.settings.quiet_start = 0  # без тихих часов: иначе в 03:00 ночь и луна вместо солнца
	sunny.settings.quiet_end = 0
	var sun_ray := 40 * Lcd.COLS + 58  # верхний луч солнца (sun1, строка 1, столбец 11)
	check(_render(sunny, 0)[sun_ray] == 1 and _render(g, 0)[sun_ray] == 0, "в дождь солнца нет")
	check(_render(g, 0) != _render(g, 1), "капли анимируются по тикам")
	var cloud_x := Lcd.COLS - Sprites.RAIN_CLOUD.w - 1
	var lcd := Lcd.new()
	var clean := Lcd.new()
	g.frame = 0
	g.render(lcd)
	g.draw_text(clean, "AGE 3", Game.PLAY_Y + 2, 2)
	var same := true
	for y in range(Game.PLAY_Y + 1, Game.PLAY_Y + 9):
		for x in cloud_x:
			same = same and lcd.get_px(x, y) == clean.get_px(x, y)
	check(same, "в дождь AGE 3 видна целиком")
	g.state.age = 999 * 86400
	lcd.clear()
	g.render(lcd)
	clean.clear()
	g.draw_text(clean, "AGE 999", Game.PLAY_Y + 2, 2)
	same = true
	for y in range(Game.PLAY_Y + 2, Game.PLAY_Y + 7):  # строки надписи
		for x in 2 + Game.text_width("AGE 999", 1) + 1:
			same = same and lcd.get_px(x, y) == clean.get_px(x, y)
	check(same, "в дождь AGE 999 не задевает тучу")
	var panel_clean := true
	var sunny_buf := _render(sunny, 0)
	for i in (Game.SEPARATOR_TOP + 1) * Lcd.COLS:
		panel_clean = panel_clean and lcd.buf[i] == sunny_buf[i]
	check(panel_clean, "туча и капли не заходят на панель шкал")
	var low_same := true
	for i in range(Game.RAIN_BOTTOM * Lcd.COLS, Game.GROUND * Lcd.COLS):
		low_same = low_same and lcd.buf[i] == sunny_buf[i]
	check(low_same, "капли не долетают до питомца")
	lcd.free()
	clean.free()
	Weather.enabled = false


# --- болезнь от дождя и зонтик ---

func _umbrellas(n: int) -> Storage.Profile:
	var p := Storage.Profile.new()
	p.umbrellas = n
	return p


func test_umbrella() -> void:
	check(Storage.Profile.from_dict({"syringes": 1}).umbrellas == 0, "старый player.json без зонтиков → 0")
	check(Storage.Profile.from_dict(_umbrellas(4).to_dict()).umbrellas == 4, "зонтики сохраняются в профиле")
	check(PetState.from_dict({"stage": "adult_normal"}).rain_cover == "", "старый save.json → rain_cover пуст")
	var st := _adult()
	st.rain_cover = "umbrella"
	check(PetState.from_dict(st.to_dict()).rain_cover == "umbrella", "rain_cover сохраняется")

	Weather.enabled = true
	var wet := _rain_day(20, true)  # заражающий дождь не короче 20 мин (проверки идут внутри дождя)
	var dry := _rain_day(10, false)  # незаражающий
	var start := _at(wet[0], wet[1])

	var s := _pet_at(start - 60)
	var p := _umbrellas(2)
	Decay.apply(s, 10 * 60, [], 1.0, p)
	check(p.umbrellas == 1 and s.rain_cover == "umbrella", "зонтик раскрылся сам: 2 → 1")
	check(not s.sick and is_equal_approx(s.happiness, 100 - 8.0 / 6), "под зонтиком: здоров, счастье обычное (%s)" % s.happiness)
	s = PetState.from_dict(s.to_dict())  # «перезапуск» посреди дождя
	Decay.apply(s, 5 * 60, [], 1.0, p)
	check(p.umbrellas == 1, "перезапуск посреди дождя — второй зонтик не тратится")

	s = _pet_at(start)
	Decay.apply(s, 60, [], 1.0, _umbrellas(0))
	check(s.sick and s.care_mistakes == 1 and s.rain_cover == "none", "заражающий дождь без зонтика → болен, +1 ошибка")
	Decay.apply(s, HOUR)
	check(s.care_mistakes == 1, "за один дождь — одна ошибка")

	s = _pet_at(_at(dry[0], dry[1]))
	Decay.apply(s, HOUR, [], 1.0, _umbrellas(0))
	check(not s.sick, "незаражающий дождь — здоров")

	s = _pet_at(start)
	s.sleeping = true
	p = _umbrellas(1)
	Decay.apply(s, HOUR, [0, 23], 1.0, p)
	check(p.umbrellas == 0 and not s.sick and s.happiness == 100.0, "дождь во сне: зонтик раскрылся сразу, не заразился")
	s = _pet_at(start)
	s.sleeping = true
	Decay.apply(s, HOUR, [0, 23], 1.0, _umbrellas(0))
	check(s.sick and s.care_mistakes == 1, "заражающий дождь во сне без зонтика → болен")

	s = _pet_at(start)
	s.sick = true
	s.fever = 20
	Decay.apply(s, HOUR, [], 1.0, _umbrellas(0))
	check(s.care_mistakes == 0, "уже больной — ошибку за дождь не получает")

	s = _pet_at(start)
	Decay.apply(s, 4 * HOUR, [], 1.0, _umbrellas(1))
	check(s.rain_cover == "", "после дождя защита сбрасывается")

	# Расчёт зова видит болезнь от дождя и не трогает настоящий профиль.
	s = _pet_at(start - HOUR)
	p = _umbrellas(0)
	var c := Calls.next_call(s, [], start - HOUR, p)
	check(absf(c.at - start - 60) <= 60 and "sick" in c.reasons, "next_call: заболеет в начале дождя: %s" % [c])
	p = _umbrellas(1)
	c = Calls.next_call(s, [], start - HOUR, p)
	check(not ("sick" in c.reasons) and p.umbrellas == 1, "next_call с зонтиком: не болеет, настоящий профиль не тронут")

	# Живой тик тратит зонтик и просит сохранить профиль.
	var g := Game.new(_pet_at(start), 1.0, null, 1.0, _umbrellas(3))
	g.tick(start + 120)
	check(g.profile.umbrellas == 2 and g.profile_changed, "тик: зонтик раскрылся, профиль помечен к сохранению")
	Weather.enabled = false


func test_umbrella_screens() -> void:
	check(Sprites.UMBRELLA != null and Sprites.ITEM_UMBRELLA != null and Sprites.ITEM_UMBRELLA.w == 12, "спрайты зонтика загружены")
	Weather.enabled = true
	var rd := _rain_day(20)
	var g := Game.new(_pet_at(_at(rd[0], rd[1] + 5 / 60.0)))
	g.state.rain_cover = "none"
	var bare := _render(g, 0)
	g.state.rain_cover = "umbrella"
	var covered := _render(g, 0)
	var lk := g.look()
	var head_y := Game.GROUND - lk.h
	var differs := false
	for y in range(head_y - Sprites.UMBRELLA.h - 1, head_y):
		for x in Lcd.COLS:
			differs = differs or covered[y * Lcd.COLS + x] != bare[y * Lcd.COLS + x]
	check(differs, "в дождь с раскрытым зонтиком над питомцем появляется зонтик")
	var below_same := true
	for i in range(head_y * Lcd.COLS, Game.GROUND * Lcd.COLS):
		below_same = below_same and covered[i] == bare[i]
	check(below_same, "зонтик не задевает самого питомца")
	g.state.clock = _at(rd[0], 3)  # солнце: зонтик не рисуется, даже если поле не сброшено
	check(_render(g, 0) == _render(Game.new(_pet_at(_at(rd[0], 3))), 0), "без дождя зонтика нет")
	Weather.enabled = false

	g = Game.new(_adult(), 1.0, null, 1.0, _umbrellas(3))
	g.mode = "bag"
	g.bag_item = Game.UMBRELLA
	var lcd := Lcd.new()
	var clean := Lcd.new()
	g.render(lcd)
	g.draw_text(clean, "UMBRELLA", 84)
	g.draw_text(clean, "X 3", 96)
	var shown := true
	for y in range(84, 101):
		for x in Lcd.COLS:
			shown = shown and (not clean.get_px(x, y) or lcd.get_px(x, y))
	check(shown, "сумка: UMBRELLA и X 3")
	_bag_use(g)
	check(g.mode == "no" and g.profile.umbrellas == 3, "USE на зонтике — отказ, запас не меняется")
	lcd.free()
	clean.free()

	var p := Storage.Profile.new()
	check(Shop.grant(p, Shop.AD_UMBRELLA) and p.umbrellas == 1, "ad_umbrella: +1")
	check(Shop.grant(p, Shop.UMBRELLA_PACK) and p.umbrellas == 6, "umbrella_pack: +5 зонтиков")
	check(Shop.grant(p, Shop.SYRINGE_PACK) and p.umbrellas == 6 and p.syringes == 5, "syringe_pack: +5 шприцев, без зонтиков")
	check(Shop.grant(p, Shop.PILL_PACK) and p.pills == 20, "pill_pack: +20 таблеток")
	check(Shop.grant(p, Shop.AD_PILL) and p.pills == 21, "ad_pill: +1 таблетка")
	check(Storage.Profile.from_dict({"syringes": 1}).pills == 0, "старый player.json без таблеток → 0")
	check(Storage.Profile.from_dict(p.to_dict()).pills == 21, "запас таблеток сохраняется")
	var q := Storage.Profile.new()
	check(Store.buy(q, Shop.SYRINGE_PACK, true) and q.syringes == 5, "Store в тестовой сборке: покупка выдаёт")
	check(Store.watch_ad(q, Shop.AD_PILL, true) and q.pills == 1, "Store в тестовой сборке: реклама выдаёт")
	check(not Store.buy(q, Shop.PREMIUM, false) and not q.premium, "Store в продакшене: Premium не выдаётся")
	check(not Store.watch_ad(q, Shop.AD_UMBRELLA, false) and q.umbrellas == 0, "Store в продакшене: реклама не выдаёт")


# --- уведомления (зов игрока) ---

func test_notifications() -> void:
	check(Calls.text(["poop"], "CAT") == "Time to clean up!", "текст: кучка")
	check(Calls.text(["hungry"], "CAT") == "CAT is hungry!", "текст: голод")
	check(Calls.text(["sick", "hungry", "poop"], "CAT") == "CAT is sick! (+2)", "текст: несколько поводов")
	check(Calls.text(["dead"], "CAT") == "CAT has passed away", "текст: смерть")

	var now := _local(12)
	var n := Calls.plan(_pet_at(now), [], now, null, "CAT")
	check(absf(n.at - now - 5 * HOUR) <= 60 and n.title == "CAT" and n.body == "Time to clean up!", "сытый днём → ~5 ч, кучка: %s" % [n])
	var s := _pet_at(now)
	s.satiety = 10
	n = Calls.plan(s, [], now, null, "CAT")
	check(n.at == now + Calls.REMIND_AFTER and n.body == "CAT is hungry!", "повод уже есть → через 15 мин")
	now = _local(23)
	s = _pet_at(now)
	s.digestion = 40  # не спит: кучка к 02:00
	n = Calls.plan(s, [22, 8], now, null, "CAT")
	check(absf(n.at - _local(32)) <= 60 and n.body.begins_with("Time to clean up!"), "повод ночью → 08:00: %s" % [n])
	s = _pet_at(now)
	s.alive = false
	check(Calls.plan(s, [], now, null, "CAT").is_empty(), "мёртвый — не планируем")

	s = _pet_at(_local(12))
	s.pending_call_at = _local(12)
	Calls.punish_ignored(s, [22, 8], _local(13))
	check(s.care_mistakes == 1 and s.pending_call_at == 0.0, "проигнорировал зов → +1 ошибка")
	Calls.punish_ignored(s, [22, 8], _local(13))
	check(s.care_mistakes == 1, "повторный возврат — без второго штрафа")
	s = _pet_at(_local(12))
	s.pending_call_at = _local(12)
	Calls.punish_ignored(s, [22, 8], _local(12) + 10 * 60)
	check(s.care_mistakes == 0, "успел за 15 мин — штрафа нет")
	s = _pet_at(_local(23))
	s.pending_call_at = _local(23)
	Calls.punish_ignored(s, [22, 8], _local(25))
	check(s.care_mistakes == 0, "зов в тихие часы — штрафа нет")
	check(PetState.from_dict({"stage": "adult_normal"}).pending_call_at == 0.0, "старый save.json → зова нет")



func test_call_rain_growth() -> void:
	check(Calls.text(["rain"], "CAT") == "CAT is out in the rain!", "текст: дождь без зонтика")
	check(Calls.text(["rain_umbrella"], "CAT") == "It's raining. CAT is under an umbrella", "текст: под зонтиком")
	check(Calls.text(["born"], "CAT") == "CAT was born!" and Calls.text(["grew"], "CAT") == "CAT has grown!", "тексты: рождение, рост")

	Weather.enabled = true
	var dry := _rain_day(20, false)
	var start := _at(dry[0], dry[1])
	var s := _pet_at(start - HOUR)
	var c := Calls.next_call(s, [], start - HOUR, _umbrellas(0))
	check(absf(c.at - start - 60) <= 60 and c.reasons == ["rain"], "дождь без зонтика → зов: %s" % [c])
	c = Calls.next_call(s, [], start - HOUR, _umbrellas(1))
	check(absf(c.at - start - 60) <= 60 and c.reasons == ["rain_umbrella"], "дождь с зонтиком → зов: %s" % [c])
	var n := Calls.plan(s, [], start - HOUR, _umbrellas(0), "CAT")
	check(n.body == "CAT is out in the rain!" and not n.care, "зов про дождь — не повод ухода")
	s = _pet_at(start + 60)
	c = Calls.next_call(s, [], start + 60, _umbrellas(0))
	check(c.at >= start + 20 * 60, "ушёл посреди дождя — этот дождь не зовёт: %s" % [c])

	# Дождь целиком в тихих часах: к утру кончился — пустого зова нет.
	var h := floori(dry[1])
	s = _pet_at(_at(dry[0], h))
	c = Calls.next_call(s, [h, h + 2], _at(dry[0], h), _umbrellas(0))
	check(c.reasons.size() > 0 and c.at >= _at(dry[0], h + 2) and c.reasons != ["rain"], "дождь ночью кончился → ищем дальше: %s" % [c])
	Weather.enabled = false

	var now := _local(12)
	s = _pet_at(now)
	s.stage = Evolution.BIRTH
	c = Calls.next_call(s, [], now)
	check(absf(c.at - now - Evolution.BIRTH_UNTIL) <= 60 and c.reasons == ["born"], "вылупился → зов: %s" % [c])
	s = _pet_at(now)
	s.stage = Evolution.CHILD
	s.age = Evolution.CHILD_UNTIL - 30
	c = Calls.next_call(s, [], now)
	check(c.at == now + 60 and c.reasons == ["grew"], "вырос → зов: %s" % [c])
	s.satiety = 10
	check(Calls.plan(s, [], now, null, "CAT").care, "голод — повод ухода")


# --- экран разрешения на уведомления ---

func test_notify_ask() -> void:
	check(not Storage.Settings.from_dict({"quiet_start": 22}).notify_asked, "старый settings.json → разрешение ещё не спрашивали")
	check(not Notifier.needs_permission(), "на ПК (без плагина) экран разрешения не нужен")
	var g := Game.new(_adult())
	g.ask_notify()
	check(g.mode == "notify_ask", "экран разрешения открыт")
	g.press_a()
	g.press_c()
	check(g.mode == "notify_ask", "A и C на экране разрешения ничего не делают")
	var lcd := Lcd.new()
	g.render(lcd)
	lcd.free()
	g.press_b()
	check(g.mode == "idle" and g.settings.notify_asked and g.settings_changed and g.notify_permission_wanted,
			"B: запросить разрешение, запомнить, вернуться в комнату")
	g = Game.new(null)
	g.ask_notify()
	check(not g.savable(), "экран разрешения поверх экрана выбора — сохранять нечего")
	g.press_b()
	check(g.mode == "select", "после экрана разрешения — снова экран выбора")


# --- настройки: зов и звук ---

func test_settings_calls() -> void:
	check(Storage.Settings.from_dict({"quiet_start": 22}).calls_enabled, "старый settings.json → зов включён")
	var st := Storage.Settings.new()
	st.calls_enabled = false
	check(not Storage.Settings.from_dict(st.to_dict()).calls_enabled, "CALLS OFF сохраняется")

	var g := Game.new(_adult())
	g.mode = "bag"
	g.bag_item = Game.BAG_SETTINGS
	g.press_b()
	check(g.mode == "settings" and g.settings_field == Game.FIELD_FROM, "настройки открылись на FROM")
	for i in 4:
		g.press_a()
	check(g.settings_field == Game.FIELD_FROM, "A четыре раза — снова FROM")
	g.press_a()
	g.press_a()
	g.settings_changed = false
	g.press_b()
	check(not g.settings.calls_enabled and g.settings_changed, "B на CALLS → OFF, сохранить")
	g.press_a()
	g.press_b()
	check(g.open_notify_settings_wanted and g.settings.calls_enabled == false, "B на SOUND → открыть системные настройки")

	var lcd := Lcd.new()
	var clean := Lcd.new()
	g.settings_note = "NOT HERE"
	g.render(lcd)
	g.draw_text(clean, "NOT HERE", 120)
	g.draw_text(clean, "CALLS OFF", 94, 8)
	var shown := true
	for i in clean.buf.size():
		shown = shown and (not clean.buf[i] or lcd.buf[i])
	check(shown, "на экране CALLS OFF и NOT HERE")
	g.press_a()
	check(g.settings_note == "", "надпись пропадает при следующем нажатии")
	lcd.free()
	clean.free()


# --- About и отзыв ---

func test_about() -> void:
	check(Sprites.ICON_ABOUT != null and Sprites.ICON_ABOUT.w == 12, "иконка About загружена")
	var g := Game.new(_adult())
	g.mode = "bag"
	g.bag_item = Game.BAG_SETTINGS
	g.press_a()
	check(g.bag_item == Game.BAG_ABOUT, "ABOUT — после SETTINGS")
	g.press_b()
	check(g.mode == "about", "B на ABOUT — экран About")
	var lcd := Lcd.new()
	var clean := Lcd.new()
	g.render(lcd)
	for line in [["TAMAHOCHI", 48], ["V 0.0.0", 59], ["MADE BY SNI10", 81], ["WITH LOVE", 92], ["TO PETS", 103], ["B FEEDBACK", Game.ICON_Y]]:
		g.draw_text(clean, line[0], line[1])
	var shown := true
	for i in clean.buf.size():
		shown = shown and (not clean.buf[i] or lcd.buf[i])
	check(shown, "на экране About все строки")
	lcd.free()
	clean.free()
	g.press_a()
	check(g.mode == "about", "A на About ничего не делает")
	g.press_b()
	check(g.feedback_wanted, "B на About — написать отзыв")
	g.press_c()
	check(g.mode == "bag" and g.bag_item == Game.BAG_ABOUT, "C — назад в сумку на ABOUT")
	var mail := Game.feedback_mailto()
	check(mail.begins_with("mailto:d.strelets.a@gmail.com?subject=Tamahochi%20feedback&body=") and mail.contains("0.0.0"),
			"письмо: адрес, тема, версия в теле — %s" % mail)


# --- TIME: ускорение времени для тестов ---

func test_tester_time() -> void:
	check(Storage.Settings.from_dict({"quiet_start": 22}).time_speed == 1.0, "старый settings.json → скорость ×1")
	var g := Game.new(_adult())
	g.mode = "bag"
	g.bag_item = Game.BAG_ABOUT
	g.press_a()
	check(g.bag_item == Game.BAG_NEW, "после ABOUT — NEW GAME")
	g.press_a()
	check(g.bag_item == Game.BAG_PREMIUM, "после NEW GAME — PREMIUM")
	g.press_a()
	check(g.bag_item == Game.PILL, "продакшен: после PREMIUM — снова PILL, TIME нет")
	g.tester = true
	g.bag_item = Game.BAG_PREMIUM
	g.press_a()
	check(g.bag_item == Game.BAG_TIME, "тестовая сборка: после PREMIUM — TIME")
	var seen := []
	for i in 4:
		g.press_b()
		seen.append(g.speed)
	check(seen == [10.0, 60.0, 600.0, 1.0] and g.settings.time_speed == 1.0 and g.settings_changed, "B на TIME: ×10 → ×60 → ×600 → ×1, сохраняется")
	check(g.mode == "bag", "TIME остаётся в сумке")
	var lcd := Lcd.new()
	var clean := Lcd.new()
	g.mode = "idle"
	g.render(lcd)
	var plain := lcd.buf.duplicate()
	g.speed = 60.0
	g.render(lcd)
	g.draw_text(clean, "X60", Game.PLAY_Y + 9, 2)
	var shown := true
	for i in clean.buf.size():
		shown = shown and (not clean.buf[i] or lcd.buf[i])
	check(shown and lcd.buf != plain, "в комнате значок X60 при ускорении")
	lcd.free()
	clean.free()


# --- луна ночью ---

func test_moon() -> void:
	check(Sprites.MOON != null and Sprites.MOON.w == 15, "спрайт луны загружен")
	var sun_ray := 40 * Lcd.COLS + 58  # верхний луч солнца
	var moon_px: int = (Game.SUN_Y + (Sprites.SUN[0].h - Sprites.MOON.h) / 2 + 12) * Lcd.COLS + Game.SUN_X + (Sprites.SUN[0].w - Sprites.MOON.w) / 2 + 7  # низ серпа, у солнца там пусто
	var night := Game.new(_pet_at(_local(2)))
	var day := Game.new(_pet_at(_local(12)))
	var n := _render(night, 0)
	var d := _render(day, 0)
	check(n[sun_ray] == 0 and n[moon_px] == 1, "02:00 при тихих 22–08 — луна, солнца нет")
	check(d[sun_ray] == 1 and d[moon_px] == 0, "12:00 — солнце")


# --- сумка: подменю USE / BUY / GET, ПРЕМИУМ ---

func test_shop_stubs() -> void:
	var g := Game.new(_adult())
	g.tester = true
	g.mode = "bag"
	g.bag_item = Game.SYRINGE
	g.press_b()
	check(g.bag_action == Game.ACTION_USE and g.mode == "bag", "B на расходнике — подменю, строка USE")
	g.press_a()
	check(g.bag_action == Game.ACTION_BUY, "A в подменю — следующая строка")
	g.press_b()
	check(g.profile.syringes == 5 and g.profile_changed and g.mode == "bag", "BUY на SYRINGE → +5 шприцев")
	g.bag_item = Game.PILL
	g.bag_action = Game.ACTION_GET
	g.press_b()
	check(g.profile.pills == 1, "GET на PILL → +1 таблетка в запас")
	g.press_c()
	check(g.bag_action == -1 and g.mode == "bag", "C в подменю — к предметам")
	g.press_c()
	check(g.mode == "idle", "C в сумке — в комнату")

	g.state.sick = true
	g.state.fever = 40
	g.state.pills_day = g._pill_day()
	g.state.pills_used = Game.FREE_PILLS_PER_DAY
	g.profile.pills = 20
	g.mode = "bag"
	g.bag_item = Game.PILL
	_bag_use(g)
	check(g.state.fever == 30 and g.profile.pills == 19, "бесплатные кончились — таблетка из запаса")

	var lcd := Lcd.new()
	var clean := Lcd.new()
	g.mode = "bag"
	g.bag_item = Game.BAG_PREMIUM
	g.render(lcd)
	for line in [["ALL PETS", 95], ["50 PILLS", 103], ["25 SYRINGES", 111], ["25 UMBRELLAS", 119], ["A NEXT  B BUY", Game.ICON_Y]]:
		g.draw_text(clean, line[0], line[1])
	var shown := true
	for i in clean.buf.size():
		shown = shown and (not clean.buf[i] or lcd.buf[i])
	check(shown, "страница PREMIUM: состав и B BUY")
	var before := g.profile.pills
	g.press_b()
	check(g.profile.premium and Shop.is_unlocked(g.profile, Sprites.PETS.cat) and g.profile.pills == before + 50
			and g.profile.syringes == 30 and g.profile.umbrellas == 25, "PREMIUM куплен: все питомцы и 50/25/25")
	g.press_b()
	check(g.profile.pills == before + 50, "PREMIUM повторно ничего не даёт")
	lcd.free()
	clean.free()

	var prod := Game.new(_adult())
	prod.mode = "bag"
	prod.bag_item = Game.UMBRELLA
	prod.bag_action = Game.ACTION_BUY
	prod.press_b()
	check(prod.profile.umbrellas == 0 and prod.mode == "no", "продакшен: BUY — отказ")
	prod.mode = "bag"
	prod.bag_item = Game.BAG_PREMIUM
	prod.press_b()
	check(not prod.profile.premium and prod.mode == "no", "продакшен: PREMIUM — отказ")


# --- новая игра ---

func test_new_game() -> void:
	var s := _adult()
	s.species = "cat"
	var g := Game.new(s)
	g.profile.syringes = 3
	g.mode = "bag"
	g.bag_item = Game.BAG_NEW
	g.press_b()
	check(g.mode == "abandon", "NEW GAME → экран подтверждения")
	var lcd := Lcd.new()
	var clean := Lcd.new()
	g.render(lcd)
	for line in [["NEW GAME", 15], ["YOU WILL LEAVE", 44], ["YOUR PET", 53], ["B CONFIRM", Game.ICON_Y]]:
		g.draw_text(clean, line[0], line[1])
	var shown := true
	for i in clean.buf.size():
		shown = shown and (not clean.buf[i] or lcd.buf[i])
	check(shown and lcd.buf != clean.buf, "экран подтверждения: текст и грустный питомец")
	lcd.free()
	clean.free()
	g.press_a()
	check(g.mode == "abandon", "A на подтверждении ничего не делает")
	g.press_c()
	check(g.mode == "bag" and g.bag_item == Game.BAG_NEW and g.state.species == "cat", "C — назад в сумку, питомец прежний")
	g.press_b()
	g.press_b()
	check(g.mode == "select" and g.new_game_wanted and Sprites.PETS.keys()[g.choice] == "cat" and not g.savable(),
			"B CONFIRM — экран выбора на том же виде, сохранять нечего")
	check(g.profile.syringes == 3, "профиль сохранён")


# --- в дождь не играет ---

func test_no_play_in_rain() -> void:
	Weather.enabled = true
	var rd := _rain_day(10)
	var g := Game.new(_pet_at(_at(rd[0], rd[1] + 3 / 60.0)))
	g.state.happiness = 50
	g.selected = Game.PLAY
	g.press_b()
	check(g.mode == "no" and g.state.happiness == 50 and g.state.energy == 100, "в дождь от игры отказ")
	g = Game.new(_pet_at(_at(rd[0], 3)))
	g.state.happiness = 50
	g.selected = Game.PLAY
	g.press_b()
	check(g.mode == "play" and g.state.happiness == 70, "без дождя играет")
	Weather.enabled = false


# --- зонтик закрывает дождь ---

func test_umbrella_shelter() -> void:
	Weather.enabled = true
	var rd := _rain_day(20)
	var g := Game.new(_pet_at(_at(rd[0], rd[1] + 5 / 60.0)))  # взрослый 28 px: зонтик заходит в зону капель
	g.state.rain_cover = "umbrella"
	var ok := true
	var lk := g.look()
	var u := Sprites.UMBRELLA
	for f in 2:
		var buf := _render(g, f)
		var x := g.pet_x
		var y := Game.GROUND - lk.h
		var ux := x + (lk.w - u.w) / 2
		var uy := y - u.h - 1
		for py in range(uy, y):
			for px in range(maxi(ux, 0), mini(ux + u.w, Lcd.COLS)):
				var row := py - uy
				var umbrella_px: bool = row < u.h and u.rows[row][px - ux] == 1
				ok = ok and (buf[py * Lcd.COLS + px] == 1) == umbrella_px
	check(ok, "под зонтиком и сквозь купол капель нет — только сам зонтик")
	Weather.enabled = false


# --- зонтик вручную посреди дождя ---

func test_umbrella_manual() -> void:
	Weather.enabled = true
	var rd := _rain_day(30)
	var in_rain := _at(rd[0], rd[1] + 5 / 60.0)
	var g := Game.new(_pet_at(in_rain), 1.0, null, 1.0, _umbrellas(0))
	g.state.rain_cover = "none"  # дождь начался без зонтика
	g.profile.umbrellas = 1      # купили посреди дождя
	g.mode = "bag"
	g.bag_item = Game.UMBRELLA
	_bag_use(g)
	check(g.state.rain_cover == "umbrella" and g.profile.umbrellas == 0 and g.profile_changed and g.mode == "idle",
			"в дождь без защиты USE раскрывает зонтик")
	g.mode = "bag"
	g.profile.umbrellas = 1
	_bag_use(g)
	check(g.mode == "no" and g.profile.umbrellas == 1, "уже раскрыт — отказ, зонтик не тратится")
	var dry := Game.new(_pet_at(_at(rd[0], 3)), 1.0, null, 1.0, _umbrellas(1))
	dry.mode = "bag"
	dry.bag_item = Game.UMBRELLA
	_bag_use(dry)
	check(dry.mode == "no" and dry.profile.umbrellas == 1, "вне дождя USE — отказ")
	var none := Game.new(_pet_at(in_rain), 1.0, null, 1.0, _umbrellas(0))
	none.state.rain_cover = "none"
	none.mode = "bag"
	none.bag_item = Game.UMBRELLA
	_bag_use(none)
	check(none.mode == "no" and none.state.rain_cover == "none", "нет зонтиков — отказ")
	var s := _pet_at(in_rain)
	s.rain_cover = "umbrella"
	var before := s.happiness
	Decay.apply(s, 10 * 60, [], 1.0, _umbrellas(0))
	check(is_equal_approx(before - s.happiness, 8.0 / 6), "после ручного раскрытия дождь не отнимает лишнего счастья")
	Weather.enabled = false
