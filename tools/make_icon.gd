extends SceneTree
## Иконка приложения из спрайта питомца: godot --headless --path . -s res://tools/make_icon.gd
## assets/icon/: icon_512.png (Google Play), icon_192.png (лаунчер), adaptive_fg/bg_432.png (адаптивная иконка Android).
## Фон — небо и трава луга, на переднем плане — довольный BLOB. Пиксель спрайта — целое число точек.

const PET := "blob"
const OUT := "res://assets/icon"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# адаптивная: питомец внутри безопасной зоны (центр 66% = 288 из 432): 28 × 9 = 252
	_layer(432, 9, true, false).save_png(OUT + "/adaptive_bg_432.png")
	_layer(432, 9, false, true).save_png(OUT + "/adaptive_fg_432.png")
	# обычные: питомец почти во всю иконку
	_layer(512, 16, true, true).save_png(OUT + "/icon_512.png")
	_layer(192, 6, true, true).save_png(OUT + "/icon_192.png")
	print("icons → ", ProjectSettings.globalize_path(OUT))
	quit()


func _layer(size: int, px: int, with_bg: bool, with_pet: bool) -> Image:
	var skin: Sprites.PetSkin = Sprites.PETS[PET]
	var sprite: Sprites.Sprite = skin.look("adult_normal").happy
	var left := (size - sprite.w * px) / 2
	var top := (size - sprite.h * px) / 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if with_bg:
		var ground := top + sprite.h * px - px  # трава с нижнего ряда спрайта — ноги стоят на ней
		img.fill(Palette.TABLE[Palette.SKY_DAY])
		img.fill_rect(Rect2i(0, ground, size, size - ground), Palette.TABLE[Palette.index("l")])
		img.fill_rect(Rect2i(0, ground, size, px), Palette.TABLE[Palette.index("g")])
	if with_pet:
		for y in sprite.h:
			for x in sprite.w:
				var v: int = sprite.rows[y][x]
				var c := (skin.color if v == Palette.PEN else v) if v else (skin.fill if sprite.inner[y][x] else 0)
				if c:
					img.fill_rect(Rect2i(left + x * px, top + y * px, px, px), Palette.TABLE[c])
	return img
