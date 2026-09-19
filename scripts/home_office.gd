extends Control

@export var background_texture: Texture2D

@onready var background: TextureRect = $Background
@onready var office_material_label: Label = %OfficeMaterialLabel
@onready var play_button: Button = %PlayButton


func _ready() -> void:
	background.texture = background_texture
	OfficeMaterialManager.office_material_changed.connect(_on_office_material_changed)
	_on_office_material_changed(OfficeMaterialManager.current_amount)
	play_button.grab_focus()


func _exit_tree() -> void:
	if OfficeMaterialManager.office_material_changed.is_connected(_on_office_material_changed):
		OfficeMaterialManager.office_material_changed.disconnect(_on_office_material_changed)


func _on_office_material_changed(new_amount: int) -> void:
	office_material_label.text = "OFFICE MATERIAL  %d" % new_amount


func _on_play_pressed() -> void:
	SceneRouter.go_level_select()


func _on_skills_pressed() -> void:
	SceneRouter.go_skill_shop()


func _on_bestiary_pressed() -> void:
	SceneRouter.go_bestiary()


func _on_earn_material_pressed() -> void:
	SceneRouter.show_placeholder("Learning Openings")
