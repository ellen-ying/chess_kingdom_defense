extends Node

## Persistent discovery state for enemy types encountered at least once.

const SAVE_SECTION := "bestiary"
const ENCOUNTERED_KEY := "encountered_enemy_types"

const ENEMY_TYPES: Array[String] = ["Pawn", "Bishop", "Knight", "Rook", "Queen"]
const ENTRIES: Array[EnemyBestiaryEntry] = [
	preload("res://resources/bestiary/pawn.tres"),
	preload("res://resources/bestiary/bishop.tres"),
	preload("res://resources/bestiary/knight.tres"),
	preload("res://resources/bestiary/rook.tres"),
	preload("res://resources/bestiary/queen.tres")
]

var _encountered_enemy_types: Array[String] = []


func _ready() -> void:
	var stored_value = SaveData.get_value(SAVE_SECTION, ENCOUNTERED_KEY, [])
	if stored_value is Array:
		for enemy_type in stored_value:
			if enemy_type is String and enemy_type in ENEMY_TYPES:
				_encountered_enemy_types.append(enemy_type)


func mark_encountered(enemy_type: String) -> void:
	if enemy_type not in ENEMY_TYPES or enemy_type in _encountered_enemy_types:
		return

	_encountered_enemy_types.append(enemy_type)
	SaveData.set_value(SAVE_SECTION, ENCOUNTERED_KEY, _encountered_enemy_types)


func has_encountered(enemy_type: String) -> bool:
	return enemy_type in _encountered_enemy_types


func get_entries() -> Array[EnemyBestiaryEntry]:
	return ENTRIES
