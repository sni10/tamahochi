class_name Shop
## Каталог товаров и выдача купленного (≙ shop.py). Оплату проводит Google Play (B.4; пока — Store),
## игре приходит только идентификатор товара — grant() решает, что выдать.

const PILL_PACK_SIZE := 20
const SYRINGE_PACK_SIZE := 5
const UMBRELLA_PACK_SIZE := 5
const PREMIUM_PILLS := 50
const PREMIUM_SYRINGES := 25
const PREMIUM_UMBRELLAS := 25

const AD_PILL := "ad_pill"              # рекламный ролик — 1 таблетка в запас
const AD_REWARD := "ad_reward"          # рекламный ролик — 1 шприц
const AD_UMBRELLA := "ad_umbrella"      # рекламный ролик — 1 зонтик
const PILL_PACK := "pill_pack"          # consumable: наборы можно покупать снова
const SYRINGE_PACK := "syringe_pack"
const UMBRELLA_PACK := "umbrella_pack"
const PREMIUM := "premium"              # non-consumable: все питомцы (и будущие) + 50 таблеток, 25 шприцев, 25 зонтиков
const PET_PREFIX := "pet_"              # non-consumable: pet_cat, pet_bunny, ...


static func pet_product(key: String) -> String:
	return PET_PREFIX + key


static func is_unlocked(profile: Storage.Profile, skin: Sprites.PetSkin) -> bool:
	return skin.free or profile.premium or skin.key in profile.owned_pets


## Выдать купленное. true — что-то изменилось; повторная выдача non-consumable ничего не удваивает.
static func grant(profile: Storage.Profile, product_id: String) -> bool:
	match product_id:
		AD_PILL:
			profile.pills += 1
		AD_REWARD:
			profile.syringes += 1
		AD_UMBRELLA:
			profile.umbrellas += 1
		PILL_PACK:
			profile.pills += PILL_PACK_SIZE
		SYRINGE_PACK:
			profile.syringes += SYRINGE_PACK_SIZE
		UMBRELLA_PACK:
			profile.umbrellas += UMBRELLA_PACK_SIZE
		PREMIUM:
			if profile.premium:
				return false
			profile.premium = true  # открывает всех питомцев — см. is_unlocked
			profile.pills += PREMIUM_PILLS
			profile.syringes += PREMIUM_SYRINGES
			profile.umbrellas += PREMIUM_UMBRELLAS
		_:
			if not product_id.begins_with(PET_PREFIX):
				push_error("неизвестный товар: %s" % product_id)
				return false
			var key := product_id.trim_prefix(PET_PREFIX)
			var skin: Sprites.PetSkin = Sprites.PETS.get(key)
			if skin == null or skin.free or key in profile.owned_pets:
				return false
			profile.owned_pets.append(key)
	return true
