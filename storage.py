"""Загрузка и выгрузка в JSON: сохранение питомца и настройки игрока."""

import json
import os
from pathlib import Path

from player import Profile
from settings import Settings
from state import PetState

# Папка для сохранений: по умолчанию рядом с кодом, в Docker — смонтированный том.
DATA_DIR = Path(os.environ.get("TAMAHOCHI_DATA") or Path(__file__).parent)
DATA_DIR.mkdir(parents=True, exist_ok=True)

SAVE_PATH = DATA_DIR / "save.json"
SETTINGS_PATH = DATA_DIR / "settings.json"
PROFILE_PATH = DATA_DIR / "player.json"


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


def load_profile(path: Path = PROFILE_PATH) -> Profile:
    try:
        data = _read(path)
        return Profile.from_dict(data) if data is not None else Profile()
    except (json.JSONDecodeError, TypeError, ValueError) as e:
        print(f"Не удалось прочитать {path}: {e}. Профиль по умолчанию.")
        return Profile()


def save_profile(profile: Profile, path: Path = PROFILE_PATH) -> None:
    _write(profile.to_dict(), path)
