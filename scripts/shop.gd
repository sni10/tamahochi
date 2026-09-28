class_name Shop
## Каталог товаров и выдача купленного (≙ shop.py). Оплату проводит Google Play,
## игре приходит только идентификатор товара — grant() решает, что выдать.

const SYRINGE_PACK_SIZE := 5
const PREMIUM_SYRINGES := 10

const AD_REWARD := "ad_reward"        # рекламный ролик — 1 шприц
const SYRINGE_PACK := "syringe_pack"  # consumable: можно покупать снова
const PREMIUM := "premium"            # non-consumable: все питомцы, включая будущие
const PET_PREFIX := "pet_"            # non-consumable: pet_cat, pet_bunny, ...


static func pet_product(key: String) -> String:
	return PET_PREFIX + key


static func is_unlocked(profile: Storage.Profile, skin: Sprites.PetSkin) -> bool:
	return skin.free or profile.premium or skin.key in profile.owned_pets


## Выдать купленное. true — что-то изменилось; повторная выдача non-consumable ничего не удваивает.
static func grant(profile: Storage.Profile, product_id: String) -> bool:
	if product_id == AD_REWARD:
		profile.syringes += 1
	elif product_id == SYRINGE_PACK:
		profile.syringes += SYRINGE_PACK_SIZE
	elif product_id == PREMIUM:
		if profile.premium:
			return false
		profile.premium = true
		profile.syringes += PREMIUM_SYRINGES
	elif product_id.begins_with(PET_PREFIX):
		var key := product_id.trim_prefix(PET_PREFIX)
		var skin: Sprites.PetSkin = Sprites.PETS.get(key)
		if skin == null or skin.free or key in profile.owned_pets:
			return false
		profile.owned_pets.append(key)
	else:
		push_error("неизвестный товар: %s" % product_id)
		return false
	return true
