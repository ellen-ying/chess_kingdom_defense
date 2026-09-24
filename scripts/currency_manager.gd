extends Node

signal currency_changed(new_amount: int)
signal currency_earned(amount: int)

const PIECE_VALUES: Dictionary = {
	"Pawn": 1,
	"Knight": 3,
	"Bishop": 3,
	"Rook": 5,
	"Queen": 9
}

var current_amount: int = 5
var currency_spent: int = 0
var _earned_material_remainder := 0.0


func add_currency(amount: int, track_as_earned: bool = true) -> void:
	if amount <= 0:
		return

	var awarded_amount := amount
	if track_as_earned:
		var multiplier := SkillManager.get_effect_value(
			SkillDefinition.EffectType.RUN_MATERIAL_MULTIPLIER
		)
		if multiplier <= 0.0:
			multiplier = 1.0
		var reward_with_remainder := amount * multiplier + _earned_material_remainder
		awarded_amount = floori(reward_with_remainder)
		_earned_material_remainder = reward_with_remainder - awarded_amount

	current_amount += awarded_amount
	currency_changed.emit(current_amount)
	if track_as_earned:
		currency_earned.emit(awarded_amount)


func spend_currency(amount: int) -> bool:
	if amount <= 0:
		return false

	if current_amount < amount:
		return false

	current_amount -= amount
	currency_spent += amount
	currency_changed.emit(current_amount)

	return true


func get_piece_value(piece_type: String) -> int:
	return PIECE_VALUES.get(piece_type, 0)

func get_current_amount() -> int:
	return current_amount

func reset_for_new_run() -> void:
	current_amount = 5
	_earned_material_remainder = 0.0
	currency_changed.emit(current_amount)
