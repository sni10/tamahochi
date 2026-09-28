"""Загрузка спрайтов из текстовых файлов папки assets/.

Формат файла:
    ; комментарий
    ключ: значение      — свойства файла (до первого спрайта), например name питомца
    [имя]               — начало спрайта
    ..##..              — строки спрайта: '#' — пиксель включён, '.' — выключен

assets/ui.txt     — иконки меню, значки шкал, стрелки
assets/world.txt  — небо, еда, какашки, эффекты, призрак
assets/font.txt   — пиксельный шрифт (имя спрайта — символ)
assets/pets/<вид>/ — папка питомца: pet.txt (name, order) и по файлу на стадию
                    (baby, child, adult_good, adult_normal, adult_bad)
"""

from pathlib import Path

ASSETS = Path(__file__).with_name("assets")

PET_MAX = 28  # питомец любой стадии не больше 28x28
PET_FRAMES = ("idle1", "idle2", "sad1", "sad2", "happy", "eat1", "eat2", "sleep")
# Если стадия не нарисована — берём первую нарисованную из списка.
STAGE_FALLBACK = {
    "baby": ("baby", "child", "adult_normal"),
    "child": ("child", "adult_normal"),
    "adult_good": ("adult_good", "adult_normal"),
    "adult_normal": ("adult_normal",),
    "adult_bad": ("adult_bad", "adult_normal"),
}


class SpriteError(ValueError):
    pass


class Sprite:
    def __init__(self, *lines: str):
        if not lines or len({len(line) for line in lines}) != 1:
            raise ValueError("строки спрайта должны быть одной длины")
        self.lines = lines
        self.rows = tuple(tuple(c == "#" for c in line) for line in lines)
        self.w, self.h = len(lines[0]), len(lines)

    def cropped(self, width: int) -> "Sprite":
        """Оставить только левые `width` столбцов (для «откусанной» еды)."""
        width = max(1, min(self.w, width))
        return Sprite(*(line[:width] for line in self.lines))


def load_sheet(path: Path) -> tuple[dict[str, str], dict[str, Sprite]]:
    """Прочитать файл спрайтов: вернуть (свойства, {имя: спрайт})."""
    meta: dict[str, str] = {}
    sheet: dict[str, Sprite] = {}
    name, rows, start = None, [], 0

    def finish():
        if name is None:
            return
        try:
            sheet[name] = Sprite(*rows)
        except ValueError as e:
            raise SpriteError(f"{path.name}, спрайт [{name}] (строка {start}): {e}") from None

    for n, raw in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith(";"):
            continue
        if line.startswith("[") and line.endswith("]"):
            finish()
            name, rows, start = line[1:-1], [], n
            if name in sheet:
                raise SpriteError(f"{path.name}:{n}: спрайт [{name}] уже был")
            continue
        if name is None:
            key, sep, value = line.partition(":")
            if not sep:
                raise SpriteError(f"{path.name}:{n}: ожидалось «ключ: значение» или [имя]")
            meta[key.strip()] = value.strip()
            continue
        if set(line) - {"#", "."}:
            raise SpriteError(f"{path.name}:{n}: в спрайте допустимы только '#' и '.'")
        rows.append(line)
    finish()
    return meta, sheet


def _require(sheet: dict[str, Sprite], name: str, file: str) -> Sprite:
    if name not in sheet:
        raise SpriteError(f"{file}: нет спрайта [{name}]")
    return sheet[name]


class Look:
    """Облик питомца на одной стадии: все кадры одного размера."""

    def __init__(self, path: Path):
        _, sheet = load_sheet(path)
        name = f"{path.parent.name}/{path.name}"
        f = {frame: _require(sheet, frame, name) for frame in PET_FRAMES}
        sizes = {(sp.w, sp.h) for sp in f.values()}
        if len(sizes) != 1:
            raise SpriteError(f"{name}: все кадры стадии должны быть одного размера, а тут {sorted(sizes)}")
        self.w, self.h = sizes.pop()
        if self.w > PET_MAX or self.h > PET_MAX:
            raise SpriteError(f"{name}: кадры {self.w}x{self.h} больше {PET_MAX}x{PET_MAX}")
        self.idle = (f["idle1"], f["idle2"])
        self.sad = (f["sad1"], f["sad2"])
        self.happy = f["happy"]
        self.eat = (f["eat1"], f["eat2"])
        self.sleep = f["sleep"]


class PetSkin:
    """Внешность одного вида питомца на всех стадиях."""

    def __init__(self, folder: Path):
        meta_path = folder / "pet.txt"
        meta = load_sheet(meta_path)[0] if meta_path.exists() else {}
        self.key = folder.name
        self.name = meta.get("name", self.key.upper())
        self.order = int(meta.get("order", 99))
        self.birth = meta.get("birth", "basket")
        self.free = meta.get("free", "no").lower() == "yes"  # иначе — покупка или Premium
        if self.birth not in BIRTH:
            raise SpriteError(f"pets/{self.key}/pet.txt: birth должен быть одним из {sorted(BIRTH)}")
        self.looks = {st: Look(folder / f"{st}.txt") for st in STAGE_FALLBACK if (folder / f"{st}.txt").exists()}
        if "adult_normal" not in self.looks:
            raise SpriteError(f"pets/{self.key}: обязателен файл adult_normal.txt")

    def look(self, stage: str) -> Look:
        for st in STAGE_FALLBACK.get(stage, ("adult_normal",)):
            if st in self.looks:
                return self.looks[st]
        return self.looks["adult_normal"]


def _load_pets() -> dict[str, PetSkin]:
    skins = [PetSkin(p) for p in (ASSETS / "pets").iterdir() if p.is_dir()]
    if not skins:
        raise SpriteError("в assets/pets нет ни одного питомца")
    skins.sort(key=lambda s: (s.order, s.key))
    return {s.key: s for s in skins}


_, _ui = load_sheet(ASSETS / "ui.txt")
_, _world = load_sheet(ASSETS / "world.txt")
_, FONT = load_sheet(ASSETS / "font.txt")
# Откуда появляется питомец: (обычный кадр, кадр «вот-вот появится»).
BIRTH = {
    "egg": (_require(_world, "egg", "world.txt"), _require(_world, "egg_crack", "world.txt")),
    "basket": (_require(_world, "basket", "world.txt"), _require(_world, "basket_wake", "world.txt")),
}
PETS = _load_pets()

ICON_FOOD = _require(_ui, "icon_food", "ui.txt")
ICON_PLAY = _require(_ui, "icon_play", "ui.txt")
ICON_SLEEP = _require(_ui, "icon_sleep", "ui.txt")
ICON_CLEAN = _require(_ui, "icon_clean", "ui.txt")
ICON_SETTINGS = _require(_ui, "icon_settings", "ui.txt")
ICON_BAG = _require(_ui, "icon_bag", "ui.txt")
ITEM_PILL = _require(_ui, "item_pill", "ui.txt")
ITEM_SYRINGE = _require(_ui, "item_syringe", "ui.txt")
MINI_FEVER = _require(_ui, "mini_fever", "ui.txt")
SICK = _require(_ui, "sick", "ui.txt")
LOCK = _require(_ui, "lock", "ui.txt")
ICON_SIZE = ICON_FOOD.w
MINI_SATIETY = _require(_ui, "mini_satiety", "ui.txt")
MINI_HAPPINESS = _require(_ui, "mini_happiness", "ui.txt")
MINI_ENERGY = _require(_ui, "mini_energy", "ui.txt")
MINI_HEALTH = _require(_ui, "mini_health", "ui.txt")
ARROW_LEFT = _require(_ui, "arrow_left", "ui.txt")
ARROW_RIGHT = _require(_ui, "arrow_right", "ui.txt")

SUN = (_require(_world, "sun1", "world.txt"), _require(_world, "sun2", "world.txt"))
CLOUD = _require(_world, "cloud", "world.txt")
CLOUD_MASK = _require(_world, "cloud_mask", "world.txt")
FOOD = _require(_world, "food", "world.txt")
POOP = _require(_world, "poop", "world.txt")
STINK = _require(_world, "stink", "world.txt")
WAVE = _require(_world, "wave", "world.txt")
Z_BIG = _require(_world, "z_big", "world.txt")
Z_SMALL = _require(_world, "z_small", "world.txt")
GHOST = _require(_world, "ghost", "world.txt")
