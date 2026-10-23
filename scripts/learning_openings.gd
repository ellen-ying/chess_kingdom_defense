extends Control

## Embedded-in-popup convention (task Stage 6): when this scene is
## instanced inside the Home Office popup container, `embedded` is
## true and the back button asks the popup to close instead of
## routing scenes. Standalone behavior (embedded=false) is unchanged.

signal close_requested

var embedded := false

@onready var office_material_label: Label = %OfficeMaterialLabel
@onready var remaining_uses_label: Label = %RemainingUsesLabel
@onready var claim_button: Button = %ClaimButton
@onready var status_label: Label = %StatusLabel


func _ready() -> void:
	_refresh()
	claim_button.grab_focus()


func _refresh() -> void:
	office_material_label.text = "OFFICE MATERIAL  %d" % OfficeMaterialManager.current_amount
	var remaining_uses := DailyRewardManager.get_remaining_uses()
	remaining_uses_label.text = "Openings studied today: %d of %d" % [
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
