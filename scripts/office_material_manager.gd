extends Node

## Persistent Material used exclusively by the Home Office skill system.

signal office_material_changed(new_amount: int)

const SAVE_SECTION := "office_material"
const SAVE_KEY_AMOUNT := "current_amount"

var current_amount: int = 0


func _ready() -> void:
	current_amount = max(0, int(SaveData.get_value(SAVE_SECTION, SAVE_KEY_AMOUNT, 0)))


func add_office_material(amount: int) -> void:
	if amount <= 0:
		return

	current_amount += amount
	_save_and_notify()


func spend_office_material(amount: int) -> bool:
	if amount <= 0 or amount > current_amount:
		return false

	current_amount -= amount
	_save_and_notify()
	return true


func _save_and_notify() -> void:
	SaveData.set_value(SAVE_SECTION, SAVE_KEY_AMOUNT, current_amount)
	office_material_changed.emit(current_amount)
