extends Node

## Shared persistence boundary for all meta-progression systems.
##
## Gameplay state deliberately does not belong here. Feature managers use their
## own ConfigFile section so future save migrations remain localized.

const SAVE_PATH := "user://save.cfg"

var _config := ConfigFile.new()


func _ready() -> void:
	var result := _config.load(SAVE_PATH)
	if result != OK and result != ERR_FILE_NOT_FOUND:
		push_error("Unable to load save data: %s" % error_string(result))


func get_value(section: String, key: String, default_value: Variant = null) -> Variant:
	return _config.get_value(section, key, default_value)


func set_value(section: String, key: String, value: Variant) -> bool:
	_config.set_value(section, key, value)
	var result := _config.save(SAVE_PATH)
	if result != OK:
		push_error("Unable to save game data: %s" % error_string(result))
		return false
	return true
