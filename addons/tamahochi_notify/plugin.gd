@tool
extends EditorPlugin
## Подключает AAR плагина уведомлений (собирается в android_plugin/: gradlew assembleRelease assembleDebug)
## к экспорту Android.

var _export: AndroidExport


func _enter_tree() -> void:
	_export = AndroidExport.new()
	add_export_plugin(_export)


func _exit_tree() -> void:
	remove_export_plugin(_export)
	_export = null


class AndroidExport extends EditorExportPlugin:
	func _get_name() -> String:
		return "TamahochiNotify"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		# Путь — относительно res://addons/.
		return PackedStringArray(["tamahochi_notify/bin/tamahochi-notify-%s.aar" % ("debug" if debug else "release")])

	func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray(["androidx.core:core:1.13.1"])  # та же версия — в android_plugin/build.gradle
