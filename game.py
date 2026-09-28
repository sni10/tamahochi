"""Игровая логика: меню, действия, анимации и отрисовка кадра на LCD.

Экран в пропорциях смартфона (9:19.5), сверху вниз:
панель шкал → комната с питомцем → меню действий.
При новой игре и после смерти показывается экран выбора питомца.
"""

import random
import time

import decay
import evolution
import shop
import sprites
from player import Profile
from settings import Settings
from state import PetState

COLS, ROWS = 72, 156
TICK_MS = 500

# Панель шкал
STATUS_Y, STATUS_STEP = 3, 6
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
ICON_Y, ICON_X, ICON_STEP = 139, 2, 14

# Экран выбора
NAME_Y, DOTS_Y = 9, 25

ICONS = (sprites.ICON_FOOD, sprites.ICON_PLAY, sprites.ICON_SLEEP, sprites.ICON_CLEAN, sprites.ICON_BAG)
FEED, PLAY, SLEEP, CLEAN, BAG = range(len(ICONS))

# Содержимое сумки: (иконка, название)
BAG_ITEMS = ((sprites.ITEM_PILL, "PILL"), (sprites.ITEM_SYRINGE, "SYRINGE"), (sprites.ICON_SETTINGS, "SETTINGS"))
PILL, SYRINGE, BAG_SETTINGS = range(len(BAG_ITEMS))
FREE_PILLS_PER_DAY = 5
PILL_FEVER = 10  # сколько температуры снимает таблетка

# Длительность анимаций в тиках; пока анимация идёт, кнопки игнорируются.
ANIM_LENGTH = {"eat": 8, "play": 8, "no": 4, "clean": 6, "evolve": 10, "heal": 6}
WAKE_BEFORE = 60  # за сколько игровых секунд до появления яйцо трескается / корзинка шевелится

FEED_AMOUNT = 15
FEED_DIGESTION = 25   # еда ускоряет появление кучки
PLAY_JOY, PLAY_COST_ENERGY, PLAY_COST_SATIETY = 20, 10, 5
CLEAN_JOY = 5
FULL_THRESHOLD = 95   # сытый питомец отказывается от еды
TIRED_THRESHOLD = 10  # уставший — от игры
SAD_THRESHOLD = 25    # ниже — грустная мордочка и мигающая шкала


class Game:
    def __init__(self, state: PetState | None, speed: float = 1.0, settings: Settings | None = None,
                 grow: float = 1.0, profile: Profile | None = None):
        """state=None — новая игра, начинаем с выбора питомца.

        speed ускоряет всё время, grow — только взросление (для отладки эволюции).
        """
        self.state = state or PetState()
        self.speed = speed
        self.grow = grow
        self.settings = settings or Settings()
        self.settings_field = 0         # 0 — начало тихих часов, 1 — конец
        self.settings_changed = False   # App сохраняет настройки и сбрасывает флаг
        self.profile = profile or Profile()
        self.profile_changed = False    # то же для профиля игрока
        self.bag_item = 0               # какой предмет показан в сумке
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

    def _is_birth(self) -> bool:
        """Питомец ещё в яйце или корзинке."""
        return self.mode != "select" and self.state.stage == evolution.BIRTH

    def _birth_sprite(self, waking: bool) -> sprites.Sprite:
        return sprites.BIRTH[self.skin.birth][1 if waking else 0]

    def _pet_w(self) -> int:
        return self._birth_sprite(False).w if self._is_birth() else self.look.w

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
        decay.advance(self.state, time.time(), self.speed, self.settings.quiet, self.grow)
        self.pet_x = min(self.pet_x, self._max_pet_x())
        if not self.state.alive:
            if self.mode != "dead":
                self._set_mode("dead")
                self.selected = None
            return
        if self.state.stage != stage_before:
            self.start_evolution(stage_before)
            return
        self.mode_ticks += 1
        if self.mode in ANIM_LENGTH and self.mode_ticks >= ANIM_LENGTH[self.mode]:
            self._set_mode("idle")
        if self.mode == "idle" and not self.state.sleeping and not self._is_birth():
            self._walk()

    def start_evolution(self, from_stage: str) -> None:
        """Показать анимацию превращения из стадии from_stage в текущую."""
        self.evolved_from = from_stage
        self.pet_x = self._home_x()
        self._set_mode("evolve")

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
        if self.mode == "settings":
            self.settings_field = 1 - self.settings_field
            return
        if self.mode == "bag":
            self.bag_item = (self.bag_item + 1) % len(BAG_ITEMS)
            return
        if self.mode == "dead" or self._busy():
            return
        self.selected = 0 if self.selected is None else (self.selected + 1) % len(ICONS)

    def press_b(self) -> None:
        """Подтверждение выбранного действия."""
        if self.mode == "select":
            if not shop.is_unlocked(self.profile, self.skin):
                return  # закрыт: сначала купить
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
        if self.mode == "settings":
            st = self.settings
            if self.settings_field == 0:
                st.quiet_start = (st.quiet_start + 1) % 24
            else:
                st.quiet_end = (st.quiet_end + 1) % 24
            self.settings_changed = True
            return
        if self.mode == "bag":
            self._use_bag_item()
            return
        if self._busy() or self.selected is None:
            return
        if self.selected == BAG:
            self._set_mode("bag")
            return
        if self._is_birth():
            return  # в яйце/корзинке ничего не нужно
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
            if s.energy < TIRED_THRESHOLD or s.sick:
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
        if self.mode == "settings":
            self._set_mode("bag")  # настройки открываются из сумки — туда и возвращаемся
            return
        if self.mode == "bag":
            self._set_mode("idle")
            return
        if self.mode == "dead" or self._busy():
            return
        self.selected = None

    # --- сумка ---

    def _pill_day(self) -> str:
        return time.strftime("%Y-%m-%d", time.localtime(self.state.clock))

    def pills_left(self) -> int:
        """Бесплатные таблетки на сегодня (игровой день)."""
        s = self.state
        used = s.pills_used if s.pills_day == self._pill_day() else 0
        return max(0, FREE_PILLS_PER_DAY - used)

    def _use_bag_item(self) -> None:
        s = self.state
        if self.bag_item == BAG_SETTINGS:
            self.settings_field = 0
            self._set_mode("settings")
            return
        if self._is_birth():
            self._set_mode("idle")
            return
        if self.bag_item == PILL:
            if not s.sick or not self.pills_left():
                self._set_mode("no")
                return
            if s.pills_day != self._pill_day():
                s.pills_day, s.pills_used = self._pill_day(), 0
            s.pills_used += 1
            s.fever = max(0.0, s.fever - PILL_FEVER)
            if s.fever <= 0:
                s.sick = False  # вылечили
        elif self.bag_item == SYRINGE:
            if not self.profile.syringes:
                self._set_mode("no")
                return
            # Шприц лечит всё сразу: болезнь, голод, усталость.
            self.profile.syringes -= 1
            self.profile_changed = True
            s.sick, s.fever = False, 0.0
            s.satiety = s.energy = 100.0
        self._set_mode("heal")

    # --- отрисовка ---

    def render(self, lcd) -> None:
        lcd.clear()
        self._dotted(lcd, SEPARATOR_TOP)
        self._dotted(lcd, SEPARATOR_BOTTOM)
        if self.mode in ("settings", "bag"):
            getattr(self, f"_draw_{self.mode}")(lcd)
            lcd.flush()
            return
        self._draw_room(lcd)
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
        # (значок, значение, тревога — значок мигает)
        bars = (
            (sprites.MINI_SATIETY, s.satiety, s.satiety < SAD_THRESHOLD),
            (sprites.MINI_HAPPINESS, s.happiness, s.happiness < SAD_THRESHOLD),
            (sprites.MINI_ENERGY, s.energy, s.energy < SAD_THRESHOLD),
            (sprites.MINI_HEALTH, s.health, s.health < SAD_THRESHOLD),
            (sprites.MINI_FEVER, s.fever, s.sick),
        )
        inner_w = BAR_W - 2
        for i, (icon, value, alarm) in enumerate(bars):
            y = STATUS_Y + i * STATUS_STEP
            if not alarm or self.frame % 2:
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
        if self._is_birth():
            self._draw_birth(lcd)
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
        sad = s.satiety < SAD_THRESHOLD or s.happiness < SAD_THRESHOLD or s.poops or s.sick
        frames = look.sad if sad else look.idle
        lcd.blit(frames[self.frame % 2], x, y, flip=self.pet_dir < 0)
        if s.sick and self.frame % 2:  # череп над головой больного
            lcd.blit(sprites.SICK, x + look.w - 3, y - sprites.SICK.h - 2)

    def _draw_birth(self, lcd) -> None:
        waking = self.state.age >= evolution.BIRTH_UNTIL - WAKE_BEFORE
        wobble = (0, 1, 0, -1)[self.frame % 4] if waking or self.frame % 8 < 4 else 0
        sprite = self._birth_sprite(waking)
        lcd.blit(sprite, self._home_x() + wobble, self._y_for(sprite.h))

    def _draw_idle(self, lcd) -> None:
        x = self._home_x() if self.state.sleeping else self.pet_x
        self._draw_pet(lcd, x)

    def _draw_evolve(self, lcd) -> None:
        # Старый и новый облик мигают по очереди, последние тики — только новый.
        show_old = self.mode_ticks < ANIM_LENGTH["evolve"] - 4 and self.frame % 2
        if not show_old:
            sprite = self.look.happy
        elif self.evolved_from == evolution.BIRTH:
            sprite = self._birth_sprite(True)
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
        unlocked = shop.is_unlocked(self.profile, skin)
        if not unlocked:
            lock = sprites.LOCK
            lcd.blit(lock, self._center_for(lock.w), pet_y - lock.h - 6)
            self._draw_text(lcd, "LOCKED", pet_y - lock.h - 16)
        arrow_y = pet_y + (look.h - sprites.ARROW_LEFT.h) // 2
        lcd.blit(sprites.ARROW_LEFT, 4, arrow_y)
        lcd.blit(sprites.ARROW_RIGHT, COLS - 4 - sprites.ARROW_RIGHT.w, arrow_y)
        # Подсказка на месте меню: A ◀   B   ▶ C
        hint_y = ICON_Y + 3
        self._draw_text(lcd, "A", hint_y, x=ICON_X + 2)
        lcd.blit(sprites.ARROW_LEFT, ICON_X + 8, hint_y)
        if unlocked:
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

    # --- экран настроек ---

    def _draw_settings(self, lcd) -> None:
        st = self.settings
        self._draw_text(lcd, "SETTINGS", 15)
        self._draw_text(lcd, "QUIET HOURS", 45)
        rows = (("FROM", st.quiet_start, 60), ("TO", st.quiet_end, 82))
        for i, (label, hour, y) in enumerate(rows):
            if i == self.settings_field:
                lcd.blit(sprites.ARROW_RIGHT, 2, y + 3)
            self._draw_text(lcd, label, y + 3, x=8)
            self._draw_text(lcd, f"{hour:02d}:00", y, x=30, scale=2)
        now = time.localtime(self.state.clock)
        self._draw_text(lcd, f"NOW {now.tm_hour:02d}:{now.tm_min:02d}", 112)
        self._draw_text(lcd, "A NEXT  B +1", ICON_Y)
        self._draw_text(lcd, "C BACK", ICON_Y + 9)

    def _draw_heal(self, lcd) -> None:
        # Довольный питомец и «плюсики» вокруг.
        look = self.look
        x, y = self._home_x(), self._y_for(look.h)
        lcd.blit(look.happy, x, y)
        plus = sprites.FONT["+"]
        spots = ((-5, 4), (look.w + 2, 8), (-3, 16), (look.w, 0))
        for i, (dx, dy) in enumerate(spots):
            if (i + self.mode_ticks) % 2:
                lcd.blit(plus, x + dx, y + dy)

    # --- экран сумки ---

    def _draw_bag(self, lcd) -> None:
        icon, name = BAG_ITEMS[self.bag_item]
        self._draw_text(lcd, "BAG", 15)
        lcd.blit(icon, (COLS - icon.w * 2) // 2, 50, scale=2)
        lcd.blit(sprites.ARROW_LEFT, 8, 58)
        lcd.blit(sprites.ARROW_RIGHT, COLS - 8 - sprites.ARROW_RIGHT.w, 58)
        self._draw_text(lcd, name, 84)
        if self.bag_item == PILL:
            self._draw_text(lcd, f"FREE {self.pills_left()}/{FREE_PILLS_PER_DAY}", 96)
        elif self.bag_item == SYRINGE:
            self._draw_text(lcd, f"X {self.profile.syringes}", 96)
        action = "OPEN" if self.bag_item == BAG_SETTINGS else "USE"
        self._draw_text(lcd, f"A NEXT  B {action}", ICON_Y)
        self._draw_text(lcd, "C BACK", ICON_Y + 9)
