extends Node

## Persistent tutorial completion. One SaveData section, one key per
## stage — deliberately shaped like BestiaryManager/DailyRewardManager
## so migrations stay localized.
##
## Stage 2 shows when Level 1 has been WON (not merely attempted) and
## Stage 2 hasn't been shown yet. "Won" is already tracked exactly:
## LevelProgressManager.is_level_completed() is set only on the WIN
## path, so no new progress-tracking state is needed.

const SAVE_SECTION := "tutorial"
const STAGE_1_KEY := "stage_1_done"
const STAGE_2_KEY := "stage_2_done"
const STAGE_2_SIZE = 3

var stage_1_done := false
var stage_2_done := false

## RUNTIME ONLY (never persisted — no extra save keys): how far the
## sequential Stage-2 spotlight has progressed (0 = Skills,
## 1 = Bestiary, 2 = Earn Materials), so the sequence resumes at the
## next step if the player navigates away mid-way. Resets when Stage 2
## completes or is skipped. Stage 6's popups will let the steps
## advance within a single office visit instead.
var stage_2_step := 0


func _ready() -> void:
	stage_1_done = bool(
		SaveData.get_value(SAVE_SECTION, STAGE_1_KEY, false)
	)
	stage_2_done = bool(
		SaveData.get_value(SAVE_SECTION, STAGE_2_KEY, false)
	)


func complete_stage_1() -> void:
	stage_1_done = true
	SaveData.set_value(SAVE_SECTION, STAGE_1_KEY, true)


func complete_stage_2() -> void:
	stage_2_done = true
	SaveData.set_value(SAVE_SECTION, STAGE_2_KEY, true)
	
func stage_2_advance() -> void:
	stage_2_step += 1
	if stage_2_step >= STAGE_2_SIZE:
		complete_stage_2()


## Stage 2 shows when Level 1 has been WON (not attempted) and Stage 2
## hasn't been shown yet.
func should_show_stage_2() -> bool:
	return (
		not stage_2_done
		and LevelProgressManager.is_level_completed("level_1")
	)


## Debug/testing convenience: resets both stages. No shipped UI calls
## this (the pause-menu "replay tutorial" entry was declined, task Q4).
func reset_for_replay() -> void:
	stage_1_done = false
	stage_2_done = false
	SaveData.set_value(SAVE_SECTION, STAGE_1_KEY, false)
	SaveData.set_value(SAVE_SECTION, STAGE_2_KEY, false)
