class_name WaveConfig
extends Resource

@export_category("Wave")

@export var duration: float = 30.0
@export var spawn_interval: float = 2.0


@export_category("Available Enemies")

@export var shadow_pawn: bool = true
@export var shadow_knight: bool = false
@export var shadow_bishop: bool = false
@export var shadow_rook: bool = false
@export var shadow_queen: bool = false
@export var shadow_king: bool = false


func configure_wave(
	wave_duration: float,
	universal_spawn_interval: float,
	enabled_enemy_types = null
) -> void:
	duration = wave_duration
	spawn_interval = universal_spawn_interval
	
	if enabled_enemy_types != null:
		shadow_pawn = "Pawn" in enabled_enemy_types
		shadow_knight = "Knight" in enabled_enemy_types
		shadow_bishop = "Bishop" in enabled_enemy_types
		shadow_rook = "Rook" in enabled_enemy_types
		shadow_queen = "Queen" in enabled_enemy_types
		shadow_king = "King" in enabled_enemy_types


func get_available_enemy_types() -> Array[String]:
	var result: Array[String] = []

	if shadow_pawn:
		result.append("Pawn")

	if shadow_knight:
		result.append("Knight")

	if shadow_bishop:
		result.append("Bishop")

	if shadow_rook:
		result.append("Rook")

	if shadow_queen:
		result.append("Queen")

	if shadow_king:
		result.append("King")

	return result
