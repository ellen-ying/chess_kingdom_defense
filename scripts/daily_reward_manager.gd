extends Node

## Daily Office Material reward boundary. A future rewarded-ad callback can
## call claim_reward() after an ad completes without changing any UI logic.

const SAVE_SECTION := "daily_rewards"
const LAST_RESET_DATE_KEY := "last_reset_date"
const USES_TODAY_KEY := "uses_today"

const DAILY_USE_LIMIT := 5
const REWARD_AMOUNT := 1

var _last_reset_date := ""
var _uses_today := 0


func _ready() -> void:
	_last_reset_date = str(SaveData.get_value(SAVE_SECTION, LAST_RESET_DATE_KEY, ""))
	_uses_today = max(0, int(SaveData.get_value(SAVE_SECTION, USES_TODAY_KEY, 0)))
	_reset_if_new_day()


func get_remaining_uses() -> int:
	_reset_if_new_day()
	return max(0, DAILY_USE_LIMIT - _uses_today)


func can_claim_reward() -> bool:
	return get_remaining_uses() > 0


func claim_reward() -> bool:
	if not can_claim_reward():
		return false

	_uses_today += 1
	_save_state()
	OfficeMaterialManager.add_office_material(REWARD_AMOUNT)
	return true


func _reset_if_new_day() -> void:
	var today := Time.get_date_string_from_system()
	if _last_reset_date == today:
		return

	_last_reset_date = today
	_uses_today = 0
	_save_state()


func _save_state() -> void:
	SaveData.set_value(SAVE_SECTION, LAST_RESET_DATE_KEY, _last_reset_date)
	SaveData.set_value(SAVE_SECTION, USES_TODAY_KEY, _uses_today)
