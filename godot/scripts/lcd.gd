class_name Lcd extends Control
## Монохромный ЖК-дисплей с крупными пикселями: рисование в буфер, показ — по flush().

const COLS := 72
const ROWS := 156

const BEZEL := Color("#4a4458")
const BG := Color("#9ead86")         # подложка
const PIXEL_OFF := Color("#94a37d")  # «призрак» выключенного пикселя
const PIXEL_ON := Color("#1f2a1f")
const SHADOW := Color("#7f8e6c")     # тень от включённого пикселя на подложке

var buf := PackedByteArray()


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


## Погасить пиксели под включёнными пикселями спрайта (маска).
func erase(sprite: Sprites.Sprite, x: int, y: int) -> void:
	for sy in sprite.h:
		for sx in sprite.w:
			if sprite.rows[sy][sx]:
				set_px(x + sx, y + sy, false)


func flush() -> void:
	queue_redraw()


func _draw() -> void:
	# Целый размер пикселя: экран вписан в контрол вместе с рамкой в 2 пикселя по краям.
	var pixel := maxi(1, floori(minf(size.x / (COLS + 4), size.y / (ROWS + 4))))
	var gap := 1 if pixel >= 3 else 0
	var dot := pixel - gap
	var shade := maxi(1, pixel / 5)
	var grid := Vector2(COLS, ROWS) * pixel
	var origin := ((size - grid) / 2).floor()
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
