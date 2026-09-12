extends Node

signal inventory_changed(piece_type: String, new_amount: int)

var inventory: Dictionary = {}


func _ready() -> void:
	inventory = {
		"Pawn": 0,
		"Knight": 0,
		"Bishop": 0,
		"Rook": 0,
		"Queen": 0
	}


func add_piece(piece_type: String, amount: int = 1) -> void:
	if amount <= 0:
		return

	inventory[piece_type] = get_piece_count(piece_type) + amount
	inventory_changed.emit(piece_type, inventory[piece_type])


func get_piece_count(piece_type: String) -> int:
	return int(inventory.get(piece_type, 0))


func reset_for_new_run() -> void:
	for piece_type in inventory.keys():
		inventory[piece_type] = 0
		inventory_changed.emit(piece_type, 0)
