class_name Store
## Единая точка оплаты и рекламы за награду. Пока заглушка (B.4 заменит её на Google Play Billing и
## AdMob): в тестовой сборке — сразу «успешно» и выдача через Shop.grant, в продакшене — «недоступно».

## Тестовая сборка: отладочная или с меткой экспорта tester (её снимаем для продакшена, B.6).
static func is_test_build() -> bool:
	return OS.is_debug_build() or OS.has_feature("tester")


## Купить товар. true — оплата прошла и товар выдан.
static func buy(profile: Storage.Profile, product_id: String, test_build := is_test_build()) -> bool:
	# ponytail: заглушка оплаты — B.4 подключит Play Billing на это место
	return test_build and Shop.grant(profile, product_id)


## Посмотреть рекламу за награду. true — ролик досмотрен и награда выдана.
static func watch_ad(profile: Storage.Profile, product_id: String, test_build := is_test_build()) -> bool:
	# ponytail: заглушка рекламы — B.4 подключит AdMob Rewarded на это место
	return test_build and Shop.grant(profile, product_id)
