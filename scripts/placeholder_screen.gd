extends Control

@onready var title_label: Label = %TitleLabel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	title_label.text = SceneRouter.placeholder_title
	back_button.grab_focus()


func _on_back_pressed() -> void:
	SceneRouter.go_home_office()
