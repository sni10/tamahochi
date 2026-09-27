"""Игровая логика: меню, действия, анимации и отрисовка кадра на LCD.

Экран в пропорциях смартфона (9:19.5), сверху вниз:
панель шкал → комната с питомцем → меню действий.
При новой игре и после смерти показывается экран выбора питомца.
"""

import random
import time

import decay
import evolution
import sprites
from state import PetState

COLS, ROWS = 72, 156
TICK_MS = 500

# Панель шкал
STATUS_Y, STATUS_STEP = 3, 8
BAR_X, BAR_W = 9, 62
SEPARATOR_TOP = 35

# Комната
PLAY_Y = 37
GROUND = 126                    # «пол», на котором стоят спрайты
PLAY_AREA = (0, PLAY_Y, COLS, GROUND)
POOP_SLOT = 11                  # кучки выстраиваются справа налево
SUN_X, SUN_Y = 47, PLAY_Y + 2
CLOUD_Y = PLAY_Y + 10           # на высоте солнца, чтобы проплывать перед ним

# Меню
SEPARATOR_BOTTOM = 132
ICON_Y, ICON_X, ICON_STEP = 139, 3, 18

# Экран выбора
NAME_Y, DOTS_Y = 9, 25

ICONS = (sprites.ICON_FOOD, sprites.ICON_PLAY, sprites.ICON_SLEEP, sprites.ICON_CLEAN)
FEED, PLAY, SLEEP, CLEAN = range(len(ICONS))

# Длительность анимаций в тиках; пока анимация идёт, кнопки игнорируются.
ANIM_LENGTH = {"eat": 8, "play": 8, "no": 4, "clean": 6, "evolve": 10}
EGG_CRACK_BEFORE = 60  # за сколько игровых секунд до вылупления яйцо трескается

FEED_AMOUNT = 15
FEED_DIGESTION = 25   # еда ускоряет появление кучки
PLAY_JOY, PLAY_COST_ENERGY, PLAY_COST_SATIETY = 20, 10, 5
CLEAN_JOY = 5
FULL_THRESHOLD = 95   # сытый питомец отказывается от еды
TIRED_THRESHOLD = 10  # уставший — от игры
SAD_THRESHOLD = 25    # ниже — грустная мордочка и мигающая шкала


class Game:
    def __init__(self, state: PetState | None, speed: float = 1.0):
        """state=None — новая игра, начинаем с выбора питомца."""
        self.state = state or PetState()
        self.speed = speed
        self.selected: int | None = None
        self.choice = 0  # какой питомец показан на экране выбора
        self.mode = "idle" if state else "select"
        self.mode_ticks = 0
        self.frame = 0
        self.pet_x = (COLS - sprites.PET_MAX) // 2
        self.pet_dir = 1
        self.cleaning_poops = 0  # сколько кучек смывает текущая анимация
        self.evolved_from = ""   # прежняя стадия для анимации эволюции
        if state and not state.alive:
            self.mode = "dead"

    @property
    def skin(self) -> sprites.PetSkin:
        pets = sprites.PETS
        if self.mode == "select":
            return list(pets.values())[self.choice]
        return pets.get(self.state.species) or next(iter(pets.values()))

    @property
    def look(self) -> sprites.Look:
        """Облик на текущей стадии (на экране выбора — взрослый)."""
        stage = "adult_normal" if self.mode == "select" else self.state.stage
        return self.skin.look(stage)

    def _is_egg(self) -> bool:
        return self.mode != "select" and self.state.stage == evolution.EGG

    def _pet_w(self) -> int:
        return sprites.EGG.w if self._is_egg() else self.look.w

    @staticmethod
    def _y_for(h: int) -> int:
        return GROUND - h

    @staticmethod
    def _center_for(w: int) -> int:
        return (COLS - w) // 2

    @property
    def savable(self) -> bool:
        """На экране выбора нет настоящего питомца — сохранять нечего."""
        return self.mode != "select"

    # --- время ---

    def tick(self) -> None:
        self.frame += 1
        if self.mode == "select":
            return
        stage_before = self.state.stage
        decay.advance(self.state, time.time(), self.speed)
        self.pet_x = min(self.pet_x, self._max_pet_x())
        if not self.state.alive:
            if self.mode != "dead":
                self._set_mode("dead")
                self.selected = None
            return
        if self.state.stage != stage_before:
            self.evolved_from = stage_before
            self.pet_x = self._home_x()
            self._set_mode("evolve")
            return
        self.mode_ticks += 1
        if self.mode in ANIM_LENGTH and self.mode_ticks >= ANIM_LENGTH[self.mode]:
            self._set_mode("idle")
        if self.mode == "idle" and not self.state.sleeping and not self._is_egg():
            self._walk()

    def _set_mode(self, mode: str) -> None:
        self.mode = mode
        self.mode_ticks = 0

    def _busy(self) -> bool:
        return self.mode in ANIM_LENGTH

    def _max_pet_x(self) -> int:
        """Правая граница прогулки: кучки занимают место справа."""
        return max(0, COLS - self._pet_w() - POOP_SLOT * self.state.poops - 1)

    def _home_x(self) -> int:
        """Где питомец стоит во время сна и анимаций."""
        return min(self._center_for(self._pet_w()), self._max_pet_x())

    def _walk(self) -> None:
        if random.random() < 0.1:
            self.pet_dir = -self.pet_dir
        if random.random() < 0.6:
            self.pet_x += self.pet_dir
        max_x = self._max_pet_x()
        if not 0 <= self.pet_x <= max_x:
            self.pet_dir = -self.pet_dir
            self.pet_x = max(0, min(max_x, self.pet_x))

    # --- кнопки ---

    def press_a(self) -> None:
        """Выбор следующей иконки (на экране выбора — предыдущий питомец)."""
        if self.mode == "select":
            self.choice = (self.choice - 1) % len(sprites.PETS)
            return
        if self.mode == "dead" or self._busy():
            return
        self.selected = 0 if self.selected is None else (self.selected + 1) % len(ICONS)

    def press_b(self) -> None:
        """Подтверждение выбранного действия."""
        if self.mode == "select":
            self.state = PetState(species=self.skin.key)
            self.pet_x = self._home_x()
            self._set_mode("idle")
            return
        if self.mode == "dead":
            keys = list(sprites.PETS)
            self.choice = keys.index(self.state.species) if self.state.species in keys else 0
            self.selected = None
            self._set_mode("select")
            return
        if self._busy() or self.selected is None or self._is_egg():
            return  # яйцу ничего не нужно
        s = self.state
        if self.selected == SLEEP:
            s.sleeping = not s.sleeping
        elif self.selected == CLEAN:
            if s.poops:
                self.cleaning_poops = s.poops
                s.poops = 0
                s.happiness = min(100.0, s.happiness + CLEAN_JOY)
                self._set_mode("clean")
            elif not s.sleeping:
                self._set_mode("no")
        elif s.sleeping:
            return  # спящего не кормим и не развлекаем
        elif self.selected == FEED:
            if s.satiety >= FULL_THRESHOLD:
                self._set_mode("no")
            else:
                s.satiety = min(100.0, s.satiety + FEED_AMOUNT)
                s.digestion += FEED_DIGESTION
                self._set_mode("eat")
        elif self.selected == PLAY:
            if s.energy < TIRED_THRESHOLD:
                self._set_mode("no")
            else:
                s.happiness = min(100.0, s.happiness + PLAY_JOY)
                s.energy = max(0.0, s.energy - PLAY_COST_ENERGY)
                s.satiety = max(0.0, s.satiety - PLAY_COST_SATIETY)
                self._set_mode("play")

    def press_c(self) -> None:
        """Отмена: снять выбор (на экране выбора — следующий питомец)."""
        if self.mode == "select":
            self.choice = (self.choice + 1) % len(sprites.PETS)
            return
        if self.mode == "dead" or self._busy():
            return
        self.selected = None

    # --- отрисовка ---

    def render(self, lcd) -> None:
        lcd.clear()
        self._dotted(lcd, SEPARATOR_TOP)
        self._draw_room(lcd)
        self._dotted(lcd, SEPARATOR_BOTTOM)
        if self.mode == "select":
            self._draw_select(lcd)
            lcd.flush()
            return
        self._draw_status(lcd)
        getattr(self, f"_draw_{self.mode}")(lcd)
        if self.mode != "clean":
            self._draw_poops(lcd, self.state.poops)
        self._draw_menu(lcd)
        lcd.flush()

    @staticmethod
    def _dotted(lcd, y: int) -> None:
        for x in range(0, COLS, 2):
            lcd.set(x, y)

    def _draw_status(self, lcd) -> None:
        s = self.state
        bars = (
            (sprites.MINI_SATIETY, s.satiety),
            (sprites.MINI_HAPPINESS, s.happiness),
            (sprites.MINI_ENERGY, s.energy),
            (sprites.MINI_HEALTH, s.health),
        )
        inner_w = BAR_W - 2
        for i, (icon, value) in enumerate(bars):
            y = STATUS_Y + i * STATUS_STEP
            if value >= SAD_THRESHOLD or self.frame % 2:  # низкий показатель мигает
                lcd.blit(icon, 1, y)
            # рамка со скруглёнными углами
            lcd.hline(BAR_X + 1, y, inner_w)
            lcd.hline(BAR_X + 1, y + 4, inner_w)
            for row in range(1, 4):
                lcd.set(BAR_X, y + row)
                lcd.set(BAR_X + BAR_W - 1, y + row)
                lcd.hline(BAR_X + 1, y + row, round(value / 100 * inner_w))

    def _draw_room(self, lcd) -> None:
        self._dotted(lcd, GROUND + 1)
        lcd.blit(sprites.SUN[self.frame // 2 % 2], SUN_X, SUN_Y)
        span = COLS + sprites.CLOUD.w
        cloud_x = (self.frame // 2) % span - sprites.CLOUD.w
        lcd.erase(sprites.CLOUD_MASK, cloud_x, CLOUD_Y)
        lcd.blit(sprites.CLOUD, cloud_x, CLOUD_Y)

    def _draw_menu(self, lcd) -> None:
        for i, icon in enumerate(ICONS):
            lcd.blit(icon, ICON_X + i * ICON_STEP, ICON_Y)
        if self.selected is None:
            return
        # уголки-скобки вокруг выбранной иконки
        x0, y0 = ICON_X + self.selected * ICON_STEP - 2, ICON_Y - 2
        x1, y1 = x0 + sprites.ICON_SIZE + 3, y0 + sprites.ICON_SIZE + 3
        for cx, cy, dx, dy in ((x0, y0, 1, 1), (x1, y0, -1, 1), (x0, y1, 1, -1), (x1, y1, -1, -1)):
            for i in range(3):
                lcd.set(cx + dx * i, cy)
                lcd.set(cx, cy + dy * i)

    def _poop_x(self, i: int) -> int:
        return COLS - (i + 1) * POOP_SLOT + 1

    def _draw_poops(self, lcd, count: int, max_x: int = COLS) -> None:
        for i in range(count):
            x = self._poop_x(i)
            if x >= max_x:
                continue
            lcd.blit(sprites.POOP, x, GROUND - sprites.POOP.h)
            lcd.blit(sprites.STINK, x + 3, GROUND - sprites.POOP.h - 7, flip=bool((self.frame + i) % 2))

    def _draw_pet(self, lcd, x: int) -> None:
        s = self.state
        if self._is_egg():
            self._draw_egg(lcd)
            return
        look = self.look
        y = self._y_for(look.h)
        if s.sleeping:
            lcd.blit(look.sleep, x, y)
            if self.frame % 2:
                lcd.blit(sprites.Z_BIG, x + look.w + 2, y - 14)
            else:
                lcd.blit(sprites.Z_SMALL, x + look.w - 2, y - 6)
            return
        sad = s.satiety < SAD_THRESHOLD or s.happiness < SAD_THRESHOLD or s.poops
        frames = look.sad if sad else look.idle
        lcd.blit(frames[self.frame % 2], x, y, flip=self.pet_dir < 0)

    def _draw_egg(self, lcd) -> None:
        cracking = self.state.age >= evolution.EGG_UNTIL - EGG_CRACK_BEFORE
        wobble = (0, 1, 0, -1)[self.frame % 4] if cracking or self.frame % 8 < 4 else 0
        egg = sprites.EGG_CRACK if cracking else sprites.EGG
        lcd.blit(egg, self._home_x() + wobble, self._y_for(egg.h))

    def _draw_idle(self, lcd) -> None:
        x = self._home_x() if self.state.sleeping else self.pet_x
        self._draw_pet(lcd, x)

    def _draw_evolve(self, lcd) -> None:
        # Старый и новый облик мигают по очереди, последние тики — только новый.
        show_old = self.mode_ticks < ANIM_LENGTH["evolve"] - 4 and self.frame % 2
        if not show_old:
            sprite = self.look.happy
        elif self.evolved_from == evolution.EGG:
            sprite = sprites.EGG_CRACK
        else:
            sprite = self.skin.look(self.evolved_from).idle[0]
        lcd.blit(sprite, self._center_for(sprite.w), self._y_for(sprite.h))

    def _draw_eat(self, lcd) -> None:
        poop_left = self._poop_x(self.state.poops - 1) if self.state.poops else COLS
        food_x = min(44, poop_left - sprites.FOOD.w - 1)
        look = self.look
        pet_x = max(0, food_x - look.w - 2)
        lcd.blit(look.eat[self.mode_ticks % 2], pet_x, self._y_for(look.h))
        bites = self.mode_ticks // 2
        if bites < 4:
            food = sprites.FOOD.cropped(sprites.FOOD.w - bites * 3)
            lcd.blit(food, food_x, GROUND - food.h)

    def _draw_play(self, lcd) -> None:
        jump = 8 if self.mode_ticks % 2 else 0
        lcd.blit(self.look.happy, self._home_x(), self._y_for(self.look.h) - jump, clip=PLAY_AREA)

    def _draw_no(self, lcd) -> None:
        shake = 2 if self.mode_ticks % 2 else -2
        lcd.blit(self.look.sad[0], max(0, self._home_x() + shake), self._y_for(self.look.h))

    def _draw_clean(self, lcd) -> None:
        # Волна идёт справа налево и смывает кучки, которые уже прошла.
        wave_x = COLS - (self.mode_ticks + 1) * COLS // ANIM_LENGTH["clean"]
        self._draw_pet(lcd, self.pet_x if not self.state.sleeping else self._home_x())
        self._draw_poops(lcd, self.cleaning_poops, max_x=wave_x)
        wave = sprites.WAVE
        for y in range(GROUND - wave.h, PLAY_Y, -wave.h):
            lcd.blit(wave, wave_x, y, flip=bool(self.frame % 2))

    def _draw_dead(self, lcd) -> None:
        ghost = sprites.GHOST
        y = self._y_for(ghost.h) - 6 + 2 * (self.frame % 2)
        lcd.blit(ghost, self._center_for(ghost.w), y, clip=PLAY_AREA)

    # --- экран выбора питомца ---

    def _draw_select(self, lcd) -> None:
        skin = self.skin
        # Имя (латиницей) крупным шрифтом в верхней панели и точки-страницы под ним.
        self._draw_text(lcd, skin.name, NAME_Y, scale=2)
        count = len(sprites.PETS)
        dots_x = (COLS - (count * 4 - 1)) // 2
        for i in range(count):
            x = dots_x + i * 4
            if i == self.choice:
                for dy in range(3):
                    lcd.hline(x, DOTS_Y + dy, 3)
            else:
                lcd.set(x + 1, DOTS_Y + 1)
        look = self.look
        pet_y = self._y_for(look.h)
        lcd.blit(look.idle[self.frame % 2], self._center_for(look.w), pet_y)
        arrow_y = pet_y + (look.h - sprites.ARROW_LEFT.h) // 2
        lcd.blit(sprites.ARROW_LEFT, 4, arrow_y)
        lcd.blit(sprites.ARROW_RIGHT, COLS - 4 - sprites.ARROW_RIGHT.w, arrow_y)
        # Подсказка на месте меню: A ◀   B   ▶ C
        hint_y = ICON_Y + 3
        self._draw_text(lcd, "A", hint_y, x=ICON_X + 2)
        lcd.blit(sprites.ARROW_LEFT, ICON_X + 8, hint_y)
        self._draw_text(lcd, "B", hint_y)
        lcd.blit(sprites.ARROW_RIGHT, COLS - ICON_X - 12, hint_y)
        self._draw_text(lcd, "C", hint_y, x=COLS - ICON_X - 6)

    @staticmethod
    def _text_width(text: str, scale: int) -> int:
        glyphs = [sprites.FONT.get(ch) for ch in text.upper()]
        return sum((g.w if g else 3) + 1 for g in glyphs) * scale - scale

    def _draw_text(self, lcd, text: str, y: int, x: int | None = None, scale: int = 1) -> None:
        """Текст пиксельным шрифтом; без x — по центру экрана. Неизвестные символы — пробел."""
        if x is None:
            x = (COLS - self._text_width(text, scale)) // 2
        for ch in text.upper():
            glyph = sprites.FONT.get(ch)
            if glyph:
                lcd.blit(glyph, x, y, scale=scale)
            x += ((glyph.w if glyph else 3) + 1) * scale
