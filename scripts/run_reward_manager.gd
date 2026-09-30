extends Node

## Converts Material earned during one active run into persistent Office
## Material. It observes earned currency rather than the current balance, so
## spending during a run cannot reduce the conversion reward.

const RUN_TO_OFFICE_RATE := 1.0

var run_material_earned := 0
var _run_active := false
var _run_finished := false


func _ready() -> void:
	CurrencyManager.currency_earned.connect(_on_currency_earned)


func begin_run() -> void:
	run_material_earned = 0
	_run_active = true
	_run_finished = false


func finish_run() -> int:
	if not _run_active or _run_finished:
		return 0

	_run_finished = true
	_run_active = false
	var office_material_gained = calculate_office_material_gained()
	OfficeMaterialManager.add_office_material(office_material_gained)
	return office_material_gained


func _on_currency_earned(amount: int) -> void:
	if _run_active and amount > 0:
		run_material_earned += amount
		
func calculate_office_material_gained() -> int:
	var office_material_gained = max(
		floori((run_material_earned - CurrencyManager.currency_spent)), 0
	)  * RUN_TO_OFFICE_RATE
	return office_material_gained
