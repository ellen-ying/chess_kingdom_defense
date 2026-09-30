extends Control

var game: Node
var result_label: Node
var materials_label: Node

func setup(game_reference: Node) -> void:
	game = game_reference
	result_label = %ResultLabel
	materials_label = %MaterialsLabel

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%RestartButton.pressed.connect(_on_restart_button_pressed)
	%HomeOfficeButton.pressed.connect(_on_home_office_button_pressed)

	visible = false
	
func open(outcome: String) -> void:
	visible = true
	result_label.text = "YOU " + outcome
	materials_label.text = (
		"Materials earned: %d points" 
		%[RunRewardManager.calculate_office_material_gained()]
		)
		
func close() -> void:
	visible = false

func _on_restart_button_pressed():
	close()
	SceneRouter.start_level("_current")
	
func _on_home_office_button_pressed():
	close()
	SceneRouter.go_home_office()
