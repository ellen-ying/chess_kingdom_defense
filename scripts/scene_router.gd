extends Node

## Owns high-level scene navigation and the selected level identity. Gameplay
## remains independent from menu scene paths.

const HOME_OFFICE_SCENE := "res://scenes/home_office.tscn"
const LEVEL_SELECT_SCENE := "res://scenes/level_select.tscn"
const BESTIARY_SCENE := "res://scenes/bestiary.tscn"
const SKILL_SHOP_SCENE := "res://scenes/skill_shop.tscn"
const LEARNING_OPENINGS_SCENE := "res://scenes/learning_openings.tscn"
const GAMEPLAY_SCENE := "res://scenes/main.tscn"
const PLACEHOLDER_SCENE := "res://scenes/placeholder_screen.tscn"

var selected_level_id := "level_1"
var placeholder_title := ""


func go_home_office() -> void:
	get_tree().change_scene_to_file(HOME_OFFICE_SCENE)


func go_level_select() -> void:
	get_tree().change_scene_to_file(LEVEL_SELECT_SCENE)


func go_bestiary() -> void:
	get_tree().change_scene_to_file(BESTIARY_SCENE)


func go_skill_shop() -> void:
	get_tree().change_scene_to_file(SKILL_SHOP_SCENE)


func go_learning_openings() -> void:
	get_tree().change_scene_to_file(LEARNING_OPENINGS_SCENE)


func start_level(level_id: String) -> void:
	selected_level_id = level_id
	get_tree().change_scene_to_file(GAMEPLAY_SCENE)


func show_placeholder(title: String) -> void:
	placeholder_title = title
	get_tree().change_scene_to_file(PLACEHOLDER_SCENE)
