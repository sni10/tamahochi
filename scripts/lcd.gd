class_name Lcd extends Control
## Монохромный ЖК-дисплей с крупными пикселями: рисование в буфер, показ — по flush().
## Касания экрана переводятся в координаты ЖК-пикселей: короткое — tapped, горизонтальный мазок — swiped.

signal tapped(cell: Vector2i)
signal swiped(dir: int)  ## +1 — палец ушёл влево (следующий), −1 — вправо (предыдущий)

const COLS := 72
const ROWS := 156

const BEZEL := Color("#4a4458")
const BG := Color("#9ead86")         # подложка
const PIXEL_OFF := Color("#94a37d")  # «призрак» выключенного пикселя
const PIXEL_ON := Color("#1f2a1f")
const SHADOW := Color("#7f8e6c")     # тень от включённого пикселя на подложке
const SWIPE_CELLS := 10  # мазок короче — это тап

var buf := PackedByteArray()
var _press_at := Vector2.ZERO


func _init() -> void:
	buf.resize(COLS * ROWS)
	resized.connect(queue_redraw)


func clear() -> void:
	buf.fill(0)


func set_px(x: int, y: int, on := true) -> void:
	if x >= 0 and x < COLS and y >= 0 and y < ROWS:
		buf[y * COLS + x] = 1 if on else 0


func get_px(x: int, y: int) -> bool:
	return buf[y * COLS + x] == 1


func hline(x: int, y: int, length: int) -> void:
	for i in length:
		set_px(x + i, y)


## Нарисовать спрайт; выключенные пиксели спрайта прозрачны.
## clip — прямоугольник, за пределы которого рисовать нельзя; zoom — увеличение.
func blit(sprite: Sprites.Sprite, x: int, y: int, flip := false, clip := Rect2i(0, 0, COLS, ROWS), zoom := 1) -> void:
	for sy in sprite.h:
		var row := sprite.rows[sy]
		for sx in sprite.w:
			if not row[sprite.w - 1 - sx if flip else sx]:
				continue
			for dy in zoom:
				for dx in zoom:
					var p := Vector2i(x + sx * zoom + dx, y + sy * zoom + dy)
					if clip.has_point(p):
						set_px(p.x, p.y)


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


## Целый размер пикселя: экран вписан в контрол вместе с рамкой в 2 пикселя по краям.
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
	var gap := 1 if pixel >= 3 else 0
	var dot := pixel - gap
	var shade := maxi(1, pixel / 5)
	var grid := Vector2(COLS, ROWS) * pixel
	var origin := _origin(pixel)
	draw_rect(Rect2(origin - Vector2.ONE * pixel * 2, grid + Vector2.ONE * pixel * 4), BEZEL)
	draw_rect(Rect2(origin - Vector2.ONE * pixel, grid + Vector2.ONE * pixel * 2), BG)
	for y in ROWS:
		for x in COLS:
			var p := origin + Vector2(x, y) * pixel
			if buf[y * COLS + x]:
				draw_rect(Rect2(p + Vector2(shade, shade), Vector2(dot, dot)), SHADOW)
				draw_rect(Rect2(p, Vector2(dot, dot)), PIXEL_ON)
			else:
				draw_rect(Rect2(p, Vector2(dot, dot)), PIXEL_OFF)
