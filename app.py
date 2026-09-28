"""Окно-корпус: экран, три кнопки, клавиатура, игровой цикл и автосохранение."""

import tkinter as tk

import shop
import storage
from game import COLS, ROWS, TICK_MS, Game
from lcd import LCD

SHELL = "#f2b8c6"
BEZEL = "#4a4458"
BUTTON = "#f5d45c"
BUTTON_PRESSED = "#d9b53a"
AUTOSAVE_MS = 60_000
# Сколько экранной высоты занимает всё, кроме LCD: рамка окна, панель задач, кнопки, отступы.
CHROME_HEIGHT = 270
MAX_PIXEL = 9

# Латиница и та же клавиша в русской раскладке, плюс стрелка/Enter/Esc.
# Отладка: «покупки» без магазина — идут через тот же shop.grant(), что и на Android.
DEBUG_PURCHASES = {"1": shop.AD_REWARD, "g": shop.AD_REWARD, "п": shop.AD_REWARD,
                   "2": shop.SYRINGE_PACK, "3": shop.PREMIUM, "4": "pet"}

KEYS = {
    "a": "a", "ф": "a", "Left": "a",
    "b": "b", "и": "b", "Return": "b",
    "c": "c", "с": "c", "Escape": "c", "Right": "c",
}


class App:
    def __init__(self, root: tk.Tk, game: Game):
        self.root = root
        self.game = game
        root.title("Tamahochi")
        root.configure(bg=SHELL)
        root.resizable(False, False)

        # Пиксель подбирается так, чтобы высокий экран-«смартфон» влез в монитор.
        pixel = max(3, min(MAX_PIXEL, (root.winfo_screenheight() - CHROME_HEIGHT) // ROWS))
        bezel = tk.Frame(root, bg=BEZEL, padx=10, pady=14)
        bezel.pack(padx=32, pady=(20, 14))
        self.lcd = LCD(bezel, COLS, ROWS, pixel=pixel)
        self.lcd.pack()

        buttons = tk.Frame(root, bg=SHELL)
        buttons.pack(pady=(0, 16))
        for name, action in (("A", game.press_a), ("B", game.press_b), ("C", game.press_c)):
            self._make_button(buttons, name, action)

        root.bind("<Key>", self._on_key)
        root.protocol("WM_DELETE_WINDOW", self._on_close)

        self.game.render(self.lcd)
        root.after(TICK_MS, self._loop)
        root.after(AUTOSAVE_MS, self._autosave)

    def _make_button(self, parent, name: str, action) -> None:
        size = 44
        frame = tk.Frame(parent, bg=SHELL)
        frame.pack(side="left", padx=18)
        canvas = tk.Canvas(frame, width=size, height=size, bg=SHELL, highlightthickness=0, cursor="hand2")
        canvas.pack()
        oval = canvas.create_oval(3, 3, size - 3, size - 3, fill=BUTTON, outline=BEZEL, width=2)
        tk.Label(frame, text=name, bg=SHELL, fg=BEZEL, font=("Segoe UI", 11, "bold")).pack()

        def on_press(_):
            canvas.itemconfigure(oval, fill=BUTTON_PRESSED)

        def on_release(_):
            canvas.itemconfigure(oval, fill=BUTTON)
            self._press(action)

        canvas.bind("<ButtonPress-1>", on_press)
        canvas.bind("<ButtonRelease-1>", on_release)

    def _on_key(self, event) -> None:
        product = DEBUG_PURCHASES.get(event.char.lower())
        if product:
            if product == "pet":  # купить питомца, показанного на экране выбора
                product = shop.pet_product(self.game.skin.key)
            if shop.grant(self.game.profile, product):
                self.game.profile_changed = True
            self._press(lambda: None)
            return
        key = KEYS.get(event.char.lower()) or KEYS.get(event.keysym)
        if key:
            self._press(getattr(self.game, f"press_{key}"))

    def _press(self, action) -> None:
        action()
        if self.game.settings_changed:
            storage.save_settings(self.game.settings)
            self.game.settings_changed = False
        if self.game.profile_changed:
            storage.save_profile(self.game.profile)
            self.game.profile_changed = False
        self.game.render(self.lcd)

    def _loop(self) -> None:
        self.game.tick()
        self.game.render(self.lcd)
        self.root.after(TICK_MS, self._loop)

    def _save(self) -> None:
        storage.save_settings(self.game.settings)
        storage.save_profile(self.game.profile)
        if self.game.savable:
            storage.save(self.game.state)

    def _autosave(self) -> None:
        self._save()
        self.root.after(AUTOSAVE_MS, self._autosave)

    def _on_close(self) -> None:
        self._save()
        self.root.destroy()
