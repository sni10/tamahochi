"""Tamahochi — виртуальный питомец с экраном под ЖК-дисплей.

Управление: A (или ← / Ф) — выбрать иконку, B (Enter / И) — действие, C (Esc / С) — отмена.
На экране выбора питомца A/C листают, B выбирает. Спрайты — текстовые файлы в assets/.
Отладка: python main.py --speed 60  — всё время в 60 раз быстрее;
         python main.py --grow 3600 — только взросление (час за секунду), потребности как обычно;
         «покупки»: 1 (или G) — ролик = шприц, 2 — пачка шприцев, 3 — Premium,
         4 — питомец, показанный на экране выбора.
"""

import argparse
import time
import tkinter as tk

import decay
import storage
from app import App
from game import Game


def main() -> None:
    parser = argparse.ArgumentParser(description="Tamahochi")
    parser.add_argument("--speed", type=float, default=1.0,
                        help="во сколько раз ускорить время (например, 60 — минута за секунду)")
    parser.add_argument("--grow", type=float, default=1.0,
                        help="во сколько раз ускорить только взросление (3600 — час за секунду)")
    args = parser.parse_args()

    settings = storage.load_settings()
    profile = storage.load_profile()
    state = storage.load()  # None — новая игра, начнём с выбора питомца
    stage_before = state.stage if state else None
    if state:
        decay.advance(state, time.time(), quiet=settings.quiet)  # догоняем время, пока программа была закрыта

    game = Game(state, speed=args.speed, settings=settings, grow=args.grow, profile=profile)
    if state and state.alive and state.stage != stage_before:
        game.start_evolution(stage_before)  # вырос, пока игра была закрыта

    root = tk.Tk()
    App(root, game)
    root.mainloop()


if __name__ == "__main__":
    main()
