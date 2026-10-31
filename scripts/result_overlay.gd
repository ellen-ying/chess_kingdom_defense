extends Control

var game: Node
var result_label: Node
var materials_label: Node
var waves_label: Node

func setup(game_reference: Node) -> void:
	game = game_reference
	result_label = %ResultLabel
	materials_label = %MaterialsLabel
	waves_label = %WavesLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%RestartButton.pressed.connect(_on_restart_button_pressed)
	%HomeOfficeButton.pressed.connect(_on_home_office_button_pressed)

	visible = false
	
## Opens the run-end overlay. Finite levels keep the exact previous
## presentation (waves line hidden). Infinite levels (Final Stand)
## pass the waves reached and the (already updated) best wave so the
## overlay can show its waves line — the overlay itself stays dumb:
## values come in from main, nothing is read or recorded here.
func open(outcome: String, waves_reached: int = -1, best_wave: int = -1) -> void:
	visible = true
	result_label.text = "YOU " + outcome
	materials_label.text = (
		"Materials earned: %d points" 
		%[RunRewardManager.calculate_office_material_gained()]
		)

	if waves_reached >= 0 and best_wave >= 0:
		waves_label.visible = true
		waves_label.text = (
			"Waves reached: %d · Best: %d"
			% [waves_reached, best_wave]
		)
	else:
		waves_label.visible = false
	
func close() -> void:
	visible = false

func _on_restart_button_pressed():
	close()
	SceneRouter.start_level("_current")
	
func _on_home_office_button_pressed():
	close()
	SceneRouter.go_home_office()
