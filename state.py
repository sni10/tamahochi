"""Состояние питомца: только данные, без логики времени и отрисовки."""

import time
from dataclasses import asdict, dataclass, field, fields


@dataclass
class PetState:
    species: str = "blob"     # вид питомца — папка в assets/pets
    stage: str = "birth"      # стадия эволюции, см. evolution.py
    age: float = 0.0          # прожито игровых секунд
    care_mistakes: int = 0    # ошибки ухода — решают, каким вырастет взрослый
    dirty_time: float = 0.0   # сколько секунд подряд лежат неубранные кучки
    # Все показатели в диапазоне 0..100, где 100 — «всё отлично».
    satiety: float = 100.0    # сытость
    happiness: float = 100.0  # счастье
    energy: float = 100.0     # бодрость
    health: float = 100.0     # здоровье
    sick: bool = False        # болен: температура растёт, пока не вылечат
    fever: float = 0.0        # температура болезни: на 100 питомец умирает
    filthy_time: float = 0.0  # сколько секунд подряд лежат все кучки (от этого заболевают)
    pills_day: str = ""       # игровой день (ГГГГ-ММ-ДД), за который считаются таблетки
    pills_used: int = 0       # сколько бесплатных таблеток выпито в этот день
    digestion: float = 0.0    # пищеварение: на 100 появляется кучка
    poops: int = 0            # сколько кучек не убрано
    sleeping: bool = False
    alive: bool = True
    born_at: float = field(default_factory=time.time)
    updated_at: float = field(default_factory=time.time)  # момент последнего пересчёта деградации
    clock: float = field(default_factory=time.time)       # игровые часы (с --speed идут быстрее)

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "PetState":
        # Неизвестные ключи игнорируем, отсутствующие берём по умолчанию —
        # так старые сохранения переживут добавление новых полей.
        known = {f.name for f in fields(cls)}
        data = {k: v for k, v in data.items() if k in known}
        data.setdefault("stage", "adult_normal")  # питомцы до эволюции уже были взрослыми
        if data["stage"] == "egg":
            data["stage"] = "birth"  # стадия переименована
        data.setdefault("clock", data.get("updated_at", time.time()))
        return cls(**data)
