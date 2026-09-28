"""Эталон для проверки паритета: прогоняет сценарии через decay.py прототипа.

Запуск из корня репозитория: python godot/tests/make_parity.py
Результат — godot/tests/parity_expected.json, его сравнивает run_tests.gd.
tz_bias — сдвиг местного времени (мин) в момент сценария: Godot подставляет его, чтобы ночь совпала.
"""

import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

import decay  # noqa: E402
from state import PetState  # noqa: E402

NOON = time.mktime((2026, 1, 15, 12, 0, 0, 0, 0, -1))  # фиксированная дата: файл не меняется день ото дня
HOUR = 3600

SCENARIOS = {
    "day_fed_3h": (dict(stage="adult_normal", satiety=80.0), 3 * HOUR, None, 1.0),
    "night_full": (dict(stage="adult_normal", satiety=70.0, happiness=60.0, energy=50.0), 24 * HOUR, (22, 8), 1.0),
    "sick_to_death": (dict(stage="adult_normal", poops=2, digestion=90.0), 40 * HOUR, None, 1.0),
    "child_to_adult": (dict(stage="child", age=24.0 * HOUR, care_mistakes=1), 7 * HOUR, (22, 8), 8.0),
    "starving_death": (dict(stage="adult_normal", satiety=0.0, happiness=0.0, health=16.0), 2 * HOUR, None, 1.0),
    "birth_to_baby": (dict(), 10 * 60, None, 1.0),
}


def main() -> None:
    out = {}
    for name, (fields, seconds, quiet, grow) in SCENARIOS.items():
        s = PetState(born_at=NOON, updated_at=NOON, clock=NOON, **fields)
        start = s.to_dict()
        decay.apply(s, seconds, quiet, grow)
        out[name] = {
            "start": start, "seconds": seconds, "quiet": list(quiet) if quiet else [], "grow": grow,
            "tz_bias": time.localtime(NOON).tm_gmtoff // 60, "expected": s.to_dict(),
        }
    path = Path(__file__).with_name("parity_expected.json")
    path.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"{path}: {len(out)} сценариев")


if __name__ == "__main__":
    main()
