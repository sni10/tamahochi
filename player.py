"""Профиль игрока (player.json): то, что принадлежит игроку, а не питомцу, и переживает его смерть.

"""

from dataclasses import asdict, dataclass, fields


@dataclass
class Profile:
    syringes: int = 0  # шприцы: за рекламу или покупку

    def to_dict(self) -> dict:
        return asdict(self)

    @classmethod
    def from_dict(cls, data: dict) -> "Profile":
        known = {f.name for f in fields(cls)}
        return cls(**{k: v for k, v in data.items() if k in known})
