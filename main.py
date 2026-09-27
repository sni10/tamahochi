"""Tamahochi — виртуальный питомец с экраном под ЖК-дисплей.

Управление: A (или ← / Ф) — выбрать иконку, B (Enter / И) — действие, C (Esc / С) — отмена.
На экране выбора питомца A/C листают, B выбирает. Спрайты — текстовые файлы в assets/.
Запуск с ускорением времени для отладки: python main.py --speed 60
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
    args = parser.parse_args()

    state = storage.load()  # None — новая игра, начнём с выбора питомца
    if state:
        decay.advance(state, time.time())  # догоняем время, пока программа была закрыта

    root = tk.Tk()
    App(root, Game(state, speed=args.speed))
    root.mainloop()


if __name__ == "__main__":
    main()
