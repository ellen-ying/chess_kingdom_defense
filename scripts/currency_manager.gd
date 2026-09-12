extends Node

signal currency_changed(new_amount: int)

const PIECE_VALUES: Dictionary = {
	"Pawn": 1,
	"Knight": 3,
	"Bishop": 3,
	"Rook": 5,
	"Queen": 9
}

var current_amount: int = 5


func add_currency(amount: int) -> void:
	if amount <= 0:
		return

	current_amount += amount
	currency_changed.emit(current_amount)


func spend_currency(amount: int) -> bool:
	if amount <= 0:
		return false

	if current_amount < amount:
		return false

	current_amount -= amount
	currency_changed.emit(current_amount)

	return true


func get_piece_value(piece_type: String) -> int:
	return PIECE_VALUES.get(piece_type, 0)


func reset_for_new_run() -> void:
	current_amount = 5
	currency_changed.emit(current_amount)
