class_name Lcd extends Control
## Экран из крупных цветных пикселей: рисование в буфер, показ — по flush().
## Два слоя: фон (bg — небо, земля, декор сцены) и передний план (buf — всё остальное).
## Пиксели спрайта '#' рисуются текущим «пером» pen, буквы — своим цветом палитры.
## Касания экрана переводятся в координаты ЖК-пикселей: короткое — tapped, горизонтальный мазок — swiped.

signal tapped(cell: Vector2i)
signal swiped(dir: int)  ## +1 — палец ушёл влево (следующий), −1 — вправо (предыдущий)

const COLS := 72
const ROWS := 163  # 156 + строка часов питомца сверху (Game.TOP)

const SWIPE_CELLS := 10  # мазок короче — это тап

var buf := PackedByteArray()  # передний план: 0 — пусто (виден фон), иначе индекс цвета палитры
var bg := PackedByteArray()   # фон: индекс цвета для каждого пикселя
var pen := Palette.INK        # цвет для '#' в спрайтах, set_px и hline
var fill := 0                 # заливка внутри контура спрайта (Sprite.inner); 0 — не заливать
var _press_at := Vector2.ZERO


func _init() -> void:
	buf.resize(COLS * ROWS)
	bg.resize(COLS * ROWS)
	resized.connect(queue_redraw)


func clear() -> void:
	buf.fill(0)
	bg.fill(Palette.PAPER)
	pen = Palette.INK
	fill = 0


func set_px(x: int, y: int, on := true) -> void:
	if x >= 0 and x < COLS and y >= 0 and y < ROWS:
		buf[y * COLS + x] = pen if on else 0


func get_px(x: int, y: int) -> bool:
	return buf[y * COLS + x] != 0


## Цвет пикселя на экране: передний план, а где он пуст — фон.
func color_at(x: int, y: int) -> Color:
	var i := y * COLS + x
	return Palette.TABLE[buf[i] if buf[i] else bg[i]]


func hline(x: int, y: int, length: int) -> void:
	for i in length:
		set_px(x + i, y)


## Нарисовать спрайт; выключенные пиксели спрайта прозрачны.
## clip — прямоугольник, за пределы которого рисовать нельзя; zoom — увеличение.
func blit(sprite: Sprites.Sprite, x: int, y: int, flip := false, clip := Rect2i(0, 0, COLS, ROWS), zoom := 1) -> void:
	for sy in sprite.h:
		var row := sprite.rows[sy]
		for sx in sprite.w:
			var i := sprite.w - 1 - sx if flip else sx
			var v := row[i]
			if not v and fill and sprite.inner and sprite.inner[sy][i]:
				v = fill
			if not v:
				continue
			var c := pen if v == Palette.PEN else v
			for dy in zoom:
				for dx in zoom:
					var p := Vector2i(x + sx * zoom + dx, y + sy * zoom + dy)
					if clip.has_point(p) and p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS:
						buf[p.y * COLS + p.x] = c


## Залить прямоугольник фона цветом палитры.
func fill_bg(rect: Rect2i, color: int) -> void:
	rect = rect.intersection(Rect2i(0, 0, COLS, ROWS))
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			bg[y * COLS + x] = color


## Нарисовать спрайт на фоне ('#' — цветом color, буквы — своими цветами).
func blit_bg(sprite: Sprites.Sprite, x: int, y: int, flip := false, color := Palette.INK, clip := Rect2i(0, 0, COLS, ROWS)) -> void:
	clip = clip.intersection(Rect2i(0, 0, COLS, ROWS))
	for sy in sprite.h:
		var row := sprite.rows[sy]
		for sx in sprite.w:
			var v := row[sprite.w - 1 - sx if flip else sx]
			if v and clip.has_point(Vector2i(x + sx, y + sy)):
				bg[(y + sy) * COLS + x + sx] = color if v == Palette.PEN else v


## Погасить прямоугольник (то, что за ним нарисовано раньше, скрыто).
func erase_rect(x: int, y: int, w: int, h: int) -> void:
	for dy in h:
		for dx in w:
			set_px(x + dx, y + dy, false)


## Погасить пиксели под включёнными пикселями спрайта (маска).
func erase(sprite: Sprites.Sprite, x: int, y: int) -> void:
	for sy in sprite.h:
		for sx in sprite.w:
			if sprite.rows[sy][sx]:
				set_px(x + sx, y + sy, false)


func flush() -> void:
	queue_redraw()


## Целый размер пикселя: экран вписан в контрол с полями в 2 пикселя по краям.
func _pixel() -> int:
	return maxi(1, floori(minf(size.x / (COLS + 4), size.y / (ROWS + 4))))


func _origin(pixel: int) -> Vector2:
	return ((size - Vector2(COLS, ROWS) * pixel) / 2).floor()


## ЖК-пиксель под точкой контрола (может быть за пределами сетки).
func cell_at(pos: Vector2) -> Vector2i:
	var pixel := _pixel()
	return Vector2i(((pos - _origin(pixel)) / pixel).floor())


## Тач приходит сюда эмулированной мышью (emulate_mouse_from_touch), мышь на ПК — как есть.
func _gui_input(event: InputEvent) -> void:
	var e := event as InputEventMouseButton
	if not e or e.button_index != MOUSE_BUTTON_LEFT:
		return
	if e.pressed:
		_press_at = e.position
		return
	var d := (e.position - _press_at) / _pixel()
	if absf(d.x) >= SWIPE_CELLS and absf(d.x) > absf(d.y):
		swiped.emit(-1 if d.x > 0 else 1)
	else:
		tapped.emit(cell_at(_press_at))


func _draw() -> void:
	var pixel := _pixel()
	var origin := _origin(pixel)
	draw_rect(Rect2(Vector2.ZERO, size), Palette.TABLE[Palette.PAPER])
	for y in ROWS:
		for x in COLS:
			draw_rect(Rect2(origin + Vector2(x, y) * pixel, Vector2(pixel, pixel)), color_at(x, y))
