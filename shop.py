"""Магазин: каталог товаров и выдача купленного.

Оплату проводит Google Play (на Android — плагин Billing). Игре приходит только
идентификатор товара, и grant() решает, что выдать. В прототипе grant() вызывают
отладочные клавиши (см. app.py).
"""

import sprites
from player import Profile

SYRINGE_PACK_SIZE = 5
PREMIUM_SYRINGES = 10

AD_REWARD = "ad_reward"        # просмотр рекламного ролика — 1 шприц
SYRINGE_PACK = "syringe_pack"  # consumable: можно покупать снова
PREMIUM = "premium"            # non-consumable: все питомцы, включая будущие
PET_PREFIX = "pet_"            # non-consumable: pet_cat, pet_bunny, ...


def pet_product(key: str) -> str:
    return PET_PREFIX + key


def is_unlocked(profile: Profile, skin: sprites.PetSkin) -> bool:
    return skin.free or profile.premium or skin.key in profile.owned_pets


def grant(profile: Profile, product_id: str) -> bool:
    """Выдать купленное. Возвращает True, если что-то изменилось.

    Повторная выдача non-consumable (восстановление покупок) ничего не удваивает.
    """
    if product_id == AD_REWARD:
        profile.syringes += 1
    elif product_id == SYRINGE_PACK:
        profile.syringes += SYRINGE_PACK_SIZE
    elif product_id == PREMIUM:
        if profile.premium:
            return False
        profile.premium = True
        profile.syringes += PREMIUM_SYRINGES
    elif product_id.startswith(PET_PREFIX):
        key = product_id[len(PET_PREFIX):]
        skin = sprites.PETS.get(key)
        if skin is None or skin.free or key in profile.owned_pets:
            return False
        profile.owned_pets.append(key)
    else:
        raise ValueError(f"неизвестный товар: {product_id}")
    return True
