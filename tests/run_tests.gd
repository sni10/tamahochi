extends SceneTree
## Проверки Godot-порта. Запуск: godot --headless --path godot -s res://tests/run_tests.gd
## Код выхода 1 — что-то упало. Ассеты: если копия разошлась, скопируйте assets/ в godot/assets/.

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
	check(Sprites.error.is_empty(), "ассеты загружены: " + Sprites.error)
	test_assets_match_root()
	test_sprite_loader()
	test_lcd()
	test_pet_state()
	test_evolution()
	test_decay()
	test_parity()
	test_game()
	test_storage()
	test_shop()
	test_calls()
	test_age()
	print("passed %d, failed %d" % [passed, failed])
	quit(1 if failed else 0)


# --- ассеты ---

func _files(dir: String, prefix := "") -> PackedStringArray:
	var out := PackedStringArray()
	for f in DirAccess.get_files_at(dir):
		out.append(prefix + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_files(dir + "/" + d, prefix + d + "/"))
	return out


func test_assets_match_root() -> void:
	var root := ProjectSettings.globalize_path("res://").path_join("../assets").simplify_path()
	var ours := _files("res://assets")
	var theirs := _files(root)
	ours.sort()
	theirs.sort()
	check(ours == theirs, "список файлов godot/assets совпадает с assets/")
	for f in ours:
		check(FileAccess.get_file_as_bytes("res://assets/" + f) == FileAccess.get_file_as_bytes(root + "/" + f),
				"godot/assets/%s совпадает с assets/%s" % [f, f])


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
	check(is_equal_approx(s.satiety, 90) and is_equal_approx(s.happiness, 92) and is_equal_approx(s.energy, 94), "час днём взрослого")
	s = _adult()
	s.stage = "baby"
	Decay.apply(s, HOUR)
	check(is_equal_approx(s.satiety, 85), "малыш −15 сытости")
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


func test_parity() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/parity_expected.json"))
	var bias := Decay.tz_bias
	for name in data:
		var sc: Dictionary = data[name]
		Decay.tz_bias = int(sc.tz_bias)
		var s := PetState.from_dict(sc.start)
		Decay.apply(s, sc.seconds, sc.quiet, sc.grow)
		var got := s.to_dict()
		for f in sc.expected:
			var want: Variant = sc.expected[f]
			var ok: bool = absf(float(got[f]) - float(want)) < 1e-6 if typeof(want) == TYPE_FLOAT else got[f] == want
			check(ok, "паритет %s.%s: godot %s, python %s" % [name, f, got[f], want])
	Decay.tz_bias = bias


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
	g.press_b()
	check(g.mode == "no" and g.pills_left() == 5, "таблетка здоровому — отказ")
	g.mode = "bag"
	g.state.sick = true
	g.state.fever = 8
	g.state.poops = 1
	g.press_b()
	check(g.mode == "no" and g.state.sick and g.state.fever == 8 and g.pills_left() == 5,
			"кучки не убраны — последняя таблетка не лечит и не тратится")
	g.mode = "bag"
	g.state.fever = 25
	g.press_b()
	check(g.mode == "heal" and g.state.sick and g.state.fever == 15 and g.pills_left() == 4,
			"с кучками таблетка сбивает температуру, но не до конца")
	g.state.poops = 0
	g.state.fever = 8
	g.mode = "bag"
	g.press_b()
	check(g.mode == "heal" and not g.state.sick and g.pills_left() == 3, "после уборки таблетка вылечила")
	g.state.sick = true
	g.state.fever = 10.0000001
	g.mode = "bag"
	g.press_b()
	check(not g.state.sick and g.state.fever == 0.0, "остаток температуры 1e-7 — тоже вылечен")
	g.state.pills_day = "2000-01-01"
	g.state.pills_used = 5
	check(g.pills_left() == 5, "новый день — снова 5 таблеток")
	g.mode = "bag"
	g.bag_item = Game.SYRINGE
	g.press_b()
	check(g.mode == "no", "шприцев нет — отказ")
	g.mode = "bag"
	g.profile.syringes = 2
	g.state.satiety = 10
	g.press_b()
	check(g.state.satiety == 100 and g.profile.syringes == 1 and g.profile_changed, "шприц")
	g.mode = "bag"
	g.state.sick = true
	g.state.poops = 2
	g.press_b()
	check(g.mode == "no" and g.state.sick and g.profile.syringes == 1, "больного с кучками шприц не лечит и не тратится")
	g.state.poops = 0
	g.state.sick = false
	g.mode = "bag"
	g.bag_item = Game.BAG_SETTINGS
	g.press_b()
	g.settings.quiet_start = 23
	g.press_b()
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
	check(Shop.grant(p, Shop.PREMIUM) and p.syringes == 16, "premium")
	check(not Shop.grant(p, Shop.PREMIUM) and p.syringes == 16, "premium второй раз ничего не даёт")
	check(Shop.is_unlocked(p, Sprites.PETS.puppy), "premium открывает всех")


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
	check(Calls.reasons(s) == ["poop", "hungry"], "поводы: сытость 20 + кучка")

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
