"""Загрузка и выгрузка в JSON: сохранение питомца и настройки игрока."""

import json
import os
from pathlib import Path

from settings import Settings
from state import PetState

SAVE_PATH = Path(__file__).with_name("save.json")
SETTINGS_PATH = Path(__file__).with_name("settings.json")


def _read(path: Path) -> dict | None:
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return None


def _write(data: dict, path: Path) -> None:
    # Пишем во временный файл и подменяем: если программа упадёт посреди записи,
    # старый файл останется целым.
    tmp = path.with_suffix(".tmp")
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)


def load(path: Path = SAVE_PATH) -> PetState | None:
    """Вернуть сохранённое состояние или None, если сохранения нет или оно испорчено."""
    try:
        data = _read(path)
        return PetState.from_dict(data) if data is not None else None
    except (json.JSONDecodeError, TypeError, ValueError) as e:
        print(f"Не удалось прочитать {path}: {e}. Начинаем с нового питомца.")
        return None


def save(state: PetState, path: Path = SAVE_PATH) -> None:
    _write(state.to_dict(), path)


def load_settings(path: Path = SETTINGS_PATH) -> Settings:
    try:
        data = _read(path)
        return Settings.from_dict(data) if data is not None else Settings()
    except (json.JSONDecodeError, TypeError, ValueError) as e:
        print(f"Не удалось прочитать {path}: {e}. Настройки по умолчанию.")
        return Settings()


def save_settings(settings: Settings, path: Path = SETTINGS_PATH) -> None:
    _write(settings.to_dict(), path)
