extends Control

@onready var office_material_label: Label = %OfficeMaterialLabel
@onready var remaining_uses_label: Label = %RemainingUsesLabel
@onready var claim_button: Button = %ClaimButton
@onready var status_label: Label = %StatusLabel
@onready var back_button: Button = %BackButton


func _ready() -> void:
	_refresh()
	claim_button.grab_focus()


func _refresh() -> void:
	office_material_label.text = "OFFICE MATERIAL  %d" % OfficeMaterialManager.current_amount
	var remaining_uses := DailyRewardManager.get_remaining_uses()
	remaining_uses_label.text = "Openings studied today: %d / %d" % [
		DailyRewardManager.DAILY_USE_LIMIT - remaining_uses,
		DailyRewardManager.DAILY_USE_LIMIT
	]
	claim_button.disabled = not DailyRewardManager.can_claim_reward()
	claim_button.text = "Study an Opening  +%d Material" % DailyRewardManager.REWARD_AMOUNT
	status_label.text = (
		"Each study earns Office Material."
		if remaining_uses > 0
		else "All openings studied for today. Come back tomorrow."
	)


func _on_claim_pressed() -> void:
	if DailyRewardManager.claim_reward():
		_refresh()


func _on_back_pressed() -> void:
	SceneRouter.go_home_office()
