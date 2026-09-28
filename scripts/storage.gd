class_name Storage
## Сохранения в user:// (≙ storage.py + settings.py + player.py).

const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
const PROFILE_PATH := "user://player.json"


## Настройки игрока. Тихие часы — это же ночь питомца (см. decay.gd).
class Settings:
	var quiet_start := 22
	var quiet_end := 8

	func quiet() -> Array:
		return [quiet_start, quiet_end]

	func to_dict() -> Dictionary:
		return {"quiet_start": quiet_start, "quiet_end": quiet_end}

	static func from_dict(data: Dictionary) -> Settings:
		var st := Settings.new()
		st.quiet_start = int(data.get("quiet_start", st.quiet_start))
		st.quiet_end = int(data.get("quiet_end", st.quiet_end))
		return st


## Профиль игрока: принадлежит игроку, а не питомцу, и переживает его смерть.
class Profile:
	var syringes := 0
	var umbrellas := 0  # раскрываются сами в начале дождя (Decay)
	var owned_pets: Array[String] = []
	var premium := false

	func to_dict() -> Dictionary:
		return {"syringes": syringes, "umbrellas": umbrellas, "owned_pets": owned_pets, "premium": premium}

	static func from_dict(data: Dictionary) -> Profile:
		var p := Profile.new()
		p.syringes = int(data.get("syringes", 0))
		p.umbrellas = int(data.get("umbrellas", 0))
		p.owned_pets.assign(data.get("owned_pets", []))
		p.premium = bool(data.get("premium", false))
		return p


## null — файла нет или он испорчен.
static func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Не удалось прочитать %s, берём значения по умолчанию." % path)
		return null
	return data


## Пишем во временный файл и подменяем: при сбое посреди записи старый файл останется целым.
static func _write(data: Dictionary, path: String) -> void:
	var tmp := path.get_basename() + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Не удалось записать %s: %s" % [tmp, FileAccess.get_open_error()])
		return
	f.store_string(JSON.stringify(data, "  ", false, true))
	f.close()
	if DirAccess.rename_absolute(tmp, path) != OK:
		DirAccess.remove_absolute(path)  # ponytail: платформа не подменяет файл при rename — удаляем и переименовываем
		DirAccess.rename_absolute(tmp, path)


static func load_pet(path := SAVE_PATH) -> PetState:
	var data: Variant = _read(path)
	return PetState.from_dict(data) if data != null else null


static func save_pet(state: PetState, path := SAVE_PATH) -> void:
	_write(state.to_dict(), path)


static func load_settings(path := SETTINGS_PATH) -> Settings:
	var data: Variant = _read(path)
	return Settings.from_dict(data) if data != null else Settings.new()


static func save_settings(settings: Settings, path := SETTINGS_PATH) -> void:
	_write(settings.to_dict(), path)


static func load_profile(path := PROFILE_PATH) -> Profile:
	var data: Variant = _read(path)
	return Profile.from_dict(data) if data != null else Profile.new()


static func save_profile(profile: Profile, path := PROFILE_PATH) -> void:
	_write(profile.to_dict(), path)
