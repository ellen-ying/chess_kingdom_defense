extends Node

## Persistent unlock and Final Stand score state. Level definitions remain
## read-only resources, while player progress is stored in SaveData.

const SAVE_SECTION := "level_progress"
const UNLOCKED_KEY := "unlocked_level_ids"
const COMPLETED_KEY := "completed_level_ids"
const FINAL_STAND_SCORE_KEY := "final_stand_high_score"

const LEVEL_ORDER: Array[String] = [
	"level_1",
	"level_2",
	"level_3",
	"level_4",
	"level_5",
	"final_stand"
]

const LEVEL_CONFIGS: Dictionary[String, LevelConfig] = {
	"level_1": preload("res://resources/levels/level_1.tres"),
	"level_2": preload("res://resources/levels/level_2.tres"),
	"level_3": preload("res://resources/levels/level_3.tres"),
	"level_4": preload("res://resources/levels/level_4.tres"),
	"level_5": preload("res://resources/levels/level_5.tres"),
	"final_stand": preload("res://resources/levels/final_stand.tres")
}

var _unlocked_level_ids: Array[String] = ["level_1"]
var _completed_level_ids: Array[String] = []
var final_stand_high_score := 0


func _ready() -> void:
	_unlocked_level_ids = _load_level_ids(UNLOCKED_KEY, ["level_1"])
	if "level_1" not in _unlocked_level_ids:
		_unlocked_level_ids.append("level_1")
	_completed_level_ids = _load_level_ids(COMPLETED_KEY, [])
	final_stand_high_score = max(0, int(SaveData.get_value(SAVE_SECTION, FINAL_STAND_SCORE_KEY, 0)))


func get_level_config(level_id: String) -> LevelConfig:
	return LEVEL_CONFIGS.get(level_id) as LevelConfig


func is_level_unlocked(level_id: String) -> bool:
	return level_id in _unlocked_level_ids


func is_level_completed(level_id: String) -> bool:
	return level_id in _completed_level_ids


func complete_level(level_id: String) -> void:
	if level_id not in LEVEL_ORDER or level_id == "final_stand":
		return

	if level_id not in _completed_level_ids:
		_completed_level_ids.append(level_id)

	var next_index := LEVEL_ORDER.find(level_id) + 1
	if next_index < LEVEL_ORDER.size():
		var next_level_id := LEVEL_ORDER[next_index]
		if next_level_id not in _unlocked_level_ids:
			_unlocked_level_ids.append(next_level_id)

	_save_progress()


## Best score for Final Stand (infinite): the highest wave STARTED in
## a run, however that run ended. Only ever moves upward.
func record_final_stand_score(waves_reached: int) -> void:
	if waves_reached <= final_stand_high_score:
		return

	final_stand_high_score = waves_reached
	SaveData.set_value(SAVE_SECTION, FINAL_STAND_SCORE_KEY, final_stand_high_score)


func _load_level_ids(key: String, default_value: Array[String]) -> Array[String]:
	var stored_value = SaveData.get_value(SAVE_SECTION, key, default_value)
	var result: Array[String] = []
	if stored_value is Array:
		for level_id in stored_value:
			if level_id is String and level_id in LEVEL_ORDER:
				result.append(level_id)
	return result


func _save_progress() -> void:
	SaveData.set_value(SAVE_SECTION, UNLOCKED_KEY, _unlocked_level_ids)
	SaveData.set_value(SAVE_SECTION, COMPLETED_KEY, _completed_level_ids)
