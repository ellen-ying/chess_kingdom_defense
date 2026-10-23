extends Control

## Pause overlay, opened from the HUD bar's menu button (☰).
##
## This is a PLAYER-INITIATED pause and deliberately does NOT conflict
## with the "waves run continuously, no forced/system-driven pauses"
## design decision: that decision was about never gating shopping or
## spawning behind downtime, not about disabling the player's ability
## to pause on demand.
##
## The root's process_mode is ALWAYS so the overlay's own buttons
## keep working while the rest of the tree is paused. One call —
## get_tree().paused = true — stops WaveManager spawning/timers, enemy
## movement, projectiles and piece firing at once. GameLogger is an
## autoload and keeps flushing; nothing is lost.

var game: Node
@onready var button_sound = $ButtonSound

func setup(game_reference: Node) -> void:
	game = game_reference


func _ready() -> void:
	%ResumeButton.pressed.connect(_on_resume_button_pressed)
	%SettingsButton.pressed.connect(_on_settings_button_pressed)
	%HomeOfficeButton.pressed.connect(_on_home_office_button_pressed)

	visible = false


func open() -> void:
	button_sound.play()
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func _on_resume_button_pressed() -> void:
	button_sound.play()
	close()


func _on_settings_button_pressed() -> void:
	button_sound.play()
	close()
	game.setting_overlay.open()


func _on_home_office_button_pressed() -> void:
	# Unpause FIRST, then end the run cleanly through the existing
	# end_run_with_result path: outcome + waves are recorded, material
	# converts, the Final Stand score is stored, GameLogger.end_run
	# closes the log, and the scene routes home (outcome "ABANDONED").
	button_sound.play()
	close()

	if game != null and is_instance_valid(game):
		game.end_run_with_result("ABANDONED")
