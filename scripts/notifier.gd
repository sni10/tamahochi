class_name Notifier
## Единая точка доставки уведомлений: на Android — плагин (синглтон PLUGIN), иначе — строка в лог.

const PLUGIN := "TamahochiNotify"


static func _plugin() -> Object:
	return Engine.get_singleton(PLUGIN) if Engine.has_singleton(PLUGIN) else null


## Запланировать цепочку уведомлений [{"at" (unix-время), "title", "body"}, ...]; прежняя отменяется.
static func schedule(calls: Array) -> void:
	var p := _plugin()
	if p:
		p.schedule(JSON.stringify(calls.map(func(c): return {"at": int(c.at), "title": c.title, "body": c.body})))
		return
	for c in calls:
		var t := Decay.local_time(c.at)
		print("notify at %02d:%02d: %s — %s" % [t.hour, t.minute, c.title, c.body])


## Нужно ли явно просить разрешение на уведомления (Android 13+, API 33).
static func needs_permission() -> bool:
	var p := _plugin()
	return p != null and int(p.sdk_int()) >= 33


## Открыть системные настройки уведомлений игры (звук, вибрация). false — негде (ПК).
static func open_settings() -> bool:
	var p := _plugin()
	return p != null and bool(p.open_settings())


static func cancel() -> void:
	var p := _plugin()
	if p:
		p.cancel()
		return
	print("notify cancelled")
