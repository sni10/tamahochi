class_name Notifier
## Единая точка доставки уведомлений: на Android — плагин (синглтон PLUGIN), иначе — строка в лог.

const PLUGIN := "TamahochiNotify"


static func _plugin() -> Object:
	return Engine.get_singleton(PLUGIN) if Engine.has_singleton(PLUGIN) else null


## Запланировать уведомление на момент at (unix-время); прежнее отменяется.
static func schedule(at: float, title: String, body: String) -> void:
	var p := _plugin()
	if p:
		p.schedule(int(at), title, body)
		return
	var t := Decay.local_time(at)
	print("notify at %02d:%02d: %s — %s" % [t.hour, t.minute, title, body])


## Нужно ли явно просить разрешение на уведомления (Android 13+, API 33).
static func needs_permission() -> bool:
	var p := _plugin()
	return p != null and int(p.sdk_int()) >= 33


static func cancel() -> void:
	var p := _plugin()
	if p:
		p.cancel()
		return
	print("notify cancelled")
