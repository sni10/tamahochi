class_name Palette
## Палитра цветного пиксель-арта. В спрайтах: '.' — прозрачно, '#' — «перо» (цвет выбирает тот,
## кто рисует: питомец — своим цветом, интерфейс — чернилами), буква — цвет из COLORS.

const PEN := 255

## Буква → цвет. Индекс цвета в буфере экрана = позиция буквы + 1 (0 — «пусто»).
const COLORS := {
	"k": Color("#2b2d42"),  # чернила
	"m": Color("#f6efdc"),  # бумага — фон интерфейса
	"w": Color("#fbfbf7"),  # белый
	"e": Color("#a3a7b5"),  # серый
	"d": Color("#5c6070"),  # тёмно-серый
	"r": Color("#e5484d"),  # красный
	"o": Color("#f2884b"),  # оранжевый
	"y": Color("#f7c948"),  # жёлтый
	"l": Color("#9bd35a"),  # салатовый
	"g": Color("#55a630"),  # зелёный
	"f": Color("#2b6a3a"),  # тёмно-зелёный (хвоя, контур листвы)
	"b": Color("#8a5a3b"),  # коричневый
	"s": Color("#f0d9a0"),  # песок
	"c": Color("#bfe6ff"),  # дневное небо
	"u": Color("#3d8bfd"),  # синий
	"n": Color("#23305e"),  # ночное небо
	"p": Color("#f49ac1"),  # розовый
	"v": Color("#9b6dd6"),  # фиолетовый
	# светлые тона — заливка тел питомцев
	"a": Color("#e3d4fa"),  # лавандовый
	"h": Color("#ffd9bd"),  # персиковый
	"i": Color("#e4e6ee"),  # светло-серый
	"j": Color("#fff0a8"),  # светло-жёлтый
	"q": Color("#e8c9a4"),  # бежевый
}

static var TABLE := PackedColorArray()  # индекс → цвет
static var _index := {}

static var INK: int
static var PAPER: int
static var SKY_DAY: int
static var SKY_NIGHT: int
static var SKY_RAIN: int
static var WHITE: int


static func _static_init() -> void:
	TABLE.append(Color.BLACK)  # 0 не рисуется
	for letter in COLORS:
		_index[letter] = TABLE.size()
		TABLE.append(COLORS[letter])
	INK = _index["k"]
	PAPER = _index["m"]
	SKY_DAY = _index["c"]
	SKY_NIGHT = _index["n"]
	SKY_RAIN = _index["e"]
	WHITE = _index["w"]


## Индекс цвета по букве; 0 — такой буквы нет.
static func index(letter: String) -> int:
	return _index.get(letter, 0)
