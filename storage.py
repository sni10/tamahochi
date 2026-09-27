"""Загрузка и выгрузка состояния в JSON."""

import json
import os
from pathlib import Path

from state import PetState

SAVE_PATH = Path(__file__).with_name("save.json")


def load(path: Path = SAVE_PATH) -> PetState | None:
    """Вернуть сохранённое состояние или None, если сохранения нет или оно испорчено."""
    try:
        with open(path, encoding="utf-8") as f:
            return PetState.from_dict(json.load(f))
    except FileNotFoundError:
        return None
    except (json.JSONDecodeError, TypeError, ValueError) as e:
        print(f"Не удалось прочитать {path}: {e}. Начинаем с нового питомца.")
        return None


def save(state: PetState, path: Path = SAVE_PATH) -> None:
    # Пишем во временный файл и подменяем: если программа упадёт посреди записи,
    # старое сохранение останется целым.
    tmp = path.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(state.to_dict(), f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)
