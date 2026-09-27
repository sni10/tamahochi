"""Настройки игрока (не питомца): хранятся отдельно от сохранения, в settings.json."""

from dataclasses import asdict, dataclass, fields


@dataclass
class Settings:
    # Тихие часы: не беспокоить игрока. Это же — ночь питомца (см. decay.py).
    quiet_start: int = 22
    quiet_end: int = 8

    @property
    def quiet(self) -> tuple[int, int]:
        return self.quiet_start, self.quiet_end

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Settings":
        known = {f.name for f in fields(cls)}
        return cls(**{k: v for k, v in data.items() if k in known})
