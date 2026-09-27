"""Имитация монохромного ЖК-дисплея с крупными пикселями.

Рисование идёт в буфер (clear/set/blit), а на экран попадает по flush() —
перекрашиваются только изменившиеся пиксели.
"""

import tkinter as tk

BG = "#9ead86"      # подложка
PIXEL_OFF = "#94a37d"  # «призрак» выключенного пикселя
PIXEL_ON = "#1f2a1f"
SHADOW = "#7f8e6c"  # тень от включённого пикселя на подложке


class LCD(tk.Canvas):
    def __init__(self, master, cols: int, rows: int, pixel: int = 12, gap: int = 1, border: int = 10):
        self.cols, self.rows = cols, rows
        super().__init__(
            master,
            width=cols * pixel + 2 * border,
            height=rows * pixel + 2 * border,
            bg=BG,
            highlightthickness=0,
        )
        self._buf = [[False] * cols for _ in range(rows)]
        self._drawn = [[None] * cols for _ in range(rows)]
        self._rects = []
        self._shadows = []
        size = pixel - gap
        shade = max(1, pixel // 5)  # смещение тени
        for y in range(rows):
            rect_row, shadow_row = [], []
            for x in range(cols):
                x0, y0 = border + x * pixel, border + y * pixel
                shadow_row.append(self.create_rectangle(
                    x0 + shade, y0 + shade, x0 + size + shade, y0 + size + shade,
                    fill=SHADOW, outline="", state="hidden"))
                rect_row.append(self.create_rectangle(
                    x0, y0, x0 + size, y0 + size, fill=PIXEL_OFF, outline=""))
            self._rects.append(rect_row)
            self._shadows.append(shadow_row)

    def clear(self) -> None:
        for row in self._buf:
            row[:] = [False] * self.cols

    def set(self, x: int, y: int, on: bool = True) -> None:
        if 0 <= x < self.cols and 0 <= y < self.rows:
            self._buf[y][x] = on

    def hline(self, x: int, y: int, length: int) -> None:
        for i in range(length):
            self.set(x + i, y)

    def blit(self, sprite, x: int, y: int, flip: bool = False, clip=None, scale: int = 1) -> None:
        """Нарисовать спрайт; выключенные пиксели спрайта прозрачны.

        clip — прямоугольник (x0, y0, x1, y1), за пределы которого рисовать нельзя.
        scale — во сколько раз увеличить (каждый пиксель станет квадратом scale x scale).
        """
        cx0, cy0, cx1, cy1 = clip or (0, 0, self.cols, self.rows)
        for sy, row in enumerate(sprite.rows):
            for sx, on in enumerate(reversed(row) if flip else row):
                if not on:
                    continue
                for dy in range(scale):
                    py = y + sy * scale + dy
                    if not cy0 <= py < cy1:
                        continue
                    for dx in range(scale):
                        px = x + sx * scale + dx
                        if cx0 <= px < cx1:
                            self._buf[py][px] = True

    def erase(self, sprite, x: int, y: int) -> None:
        """Погасить пиксели под включёнными пикселями спрайта (маска)."""
        for sy, row in enumerate(sprite.rows):
            for sx, on in enumerate(row):
                if on:
                    self.set(x + sx, y + sy, False)

    def flush(self) -> None:
        for y in range(self.rows):
            buf, drawn = self._buf[y], self._drawn[y]
            for x in range(self.cols):
                on = buf[x]
                if drawn[x] is not on:
                    self.itemconfigure(self._rects[y][x], fill=PIXEL_ON if on else PIXEL_OFF)
                    self.itemconfigure(self._shadows[y][x], state="normal" if on else "hidden")
                    drawn[x] = on
