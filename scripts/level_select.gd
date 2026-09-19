extends Control

@onready var level_buttons: Dictionary[String, Button] = {
	"level_1": %LevelOneButton,
	"level_2": %LevelTwoButton,
	"level_3": %LevelThreeButton,
	"level_4": %LevelFourButton,
	"level_5": %LevelFiveButton,
	"final_stand": %FinalStandButton
}


func _ready() -> void:
	for level_id in LevelProgressManager.LEVEL_ORDER:
		var button := level_buttons[level_id]
		var config := LevelProgressManager.get_level_config(level_id)
		var unlocked := LevelProgressManager.is_level_unlocked(level_id)
		button.disabled = not unlocked
		button.text = _get_button_text(config, unlocked)
		if unlocked:
			button.pressed.connect(_on_level_pressed.bind(level_id))

	level_buttons["level_1"].grab_focus()


func _on_level_pressed(level_id: String) -> void:
	SceneRouter.start_level(level_id)


func _on_back_pressed() -> void:
	SceneRouter.go_home_office()


func _get_button_text(config: LevelConfig, unlocked: bool) -> String:
	if not unlocked:
		return "LOCKED"

	if config.level_id == "final_stand":
		return "%s\nBest: %d waves" % [config.display_name, LevelProgressManager.final_stand_high_score]

	var completed_suffix := "  ✓" if LevelProgressManager.is_level_completed(config.level_id) else ""
	return "%s%s" % [config.display_name, completed_suffix]
