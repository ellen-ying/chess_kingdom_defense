extends Control

## Home Office hub.
##
## The old button-card UI is gone (home-office-interaction brief,
## Part 0): navigation happens through invisible tap zones over the
## art, owned by the Zones child (scripts/home_office_zones.gd).
##
## Stage 3: consumes SceneRouter.arriving_from_title (set once by
## title_screen.advance()) to run the title→office crossfade — the
## title has no art of its own, so a full-screen overlay replicating
## the title's final visual (dark fallback + centered title/prompt
## labels) fades out over 0.55 s while the office art fades in, with
## a warm window flare peaking mid-transition. Repeat hub visits
## (popups, returning from gameplay) never set the flag, so they
## skip the transition entirely.
##
## Stage 4: the Stage-1 tutorial (dim-with-hole spotlight over the
## Play zone + "Tap the board…" callout) shows exactly once on a
## fresh save — after the crossfade if one ran — and is dismissed by
## any tap (Play-zone tap proceeds normally, anything else skips).
## Stage 5: the Stage-2 tutorial (win-gated on Level 1) walks the
## player through Skills → Bestiary → Earn Materials as a sequential
## spotlight; a called-out zone tap opens that zone's popup and the
## sequence resumes at the next step when the popup closes, while any
## other tap skips the rest.
## Stage 6: zone taps open the section's content in a themed popup
## ("opened ledger" frame) layered over the office — the hub (and its
## ambient music) stays alive underneath, so the Stage-2 sequence now
## advances within a single office visit.

const CROSSFADE_SECONDS := 0.55
const TITLE_FALLBACK_COLOR := Color(0.07, 0.09, 0.14)
const TUTORIAL_DISMISS_FADE_SECONDS := 0.18
const TITLE_TEXTURE := preload("res://assets/title.jpg")

const STAGE_1_CALLOUT := "Tap the board to begin \nyour first defense."
const STAGE_2_STEPS := [
	{"zone": "skills", "callout": "Study your skills \non the trophy shelf."},
	{"zone": "bestiary", "callout": "Review your foes \nin the display case."},
	{"zone": "earn", "callout": "Earn extra material \nfrom the ledger."}
]

const TutorialOverlayScript := preload("res://scripts/tutorial_overlay.gd")
const PopupContainer = preload("res://scenes/popup_container.tscn")

@onready var zones: Control = $Zones
@onready var background: TextureRect = $Background
@onready var setting_button: TextureButton = $SettingButton
@onready var setting_overlay: Node = $SettingOverlay

var _crossfade_tween: Tween
var _tutorial_overlay: Control
var _active_tutorial_stage := 0
var _tutorial_zone_id := "play"
var _tutorial_callout := STAGE_1_CALLOUT
var _popup


func _ready() -> void:
	zones.zone_activated.connect(_on_zone_activated)
	zones.tutorial_advanced.connect(_on_tutorial_advanced)
	setting_button.pressed.connect(_on_setting_button_pressed)

	# Keeps the tutorial overlay's hole/ring/callout on the mapped
	# zone rect across resizes (zones recompute first — connected
	# earlier in their own _ready).
	get_viewport().size_changed.connect(_on_viewport_resized)

	if SceneRouter.arriving_from_title:
		_run_title_crossfade()

	# Tutorials: Stage 1 once per fresh save; Stage 2 (win-gated on
	# Level 1) only after Stage 1 is out of the way — they never both
	# show. Either waits for the crossfade if one is running.
	if not TutorialManager.stage_1_done:
		_queue_tutorial(_show_tutorial)
	elif TutorialManager.should_show_stage_2():
		_queue_tutorial(_show_stage_2)


func _queue_tutorial(show: Callable) -> void:
	if _crossfade_tween != null and _crossfade_tween.is_valid():
		_crossfade_tween.finished.connect(show)
	else:
		show.call()


func _on_zone_activated(zone_id: String, screen_position: Vector2) -> void:
	# Stage 6: zone taps open the section's content in a themed
	# popup layered over the office — the hub (and its ambient
	# music) stays alive underneath. The per-zone sound still fires
	# on the tap; the old SceneRouter routes remain available for
	# the standalone content scenes (embedded=false).
	match zone_id:
		"play":
			$BoardSound.play()
		"skills":
			$SkillsSound.play()
		"bestiary":
			$BestiarySound.play()
		_:
			$EarnSound.play()

	_open_popup(zone_id, screen_position)


# ============================================================
# POPUP SYSTEM (Stage 6)
# ============================================================

func _open_popup(zone_id: String, screen_position: Vector2) -> void:
	if _popup == null or not is_instance_valid(_popup):
		_popup = PopupContainer.instantiate()
		_popup.name = "PopupContainer"
		_popup.set_anchors_preset(Control.PRESET_FULL_RECT)
		_popup.closed.connect(_on_popup_closed)
		add_child(_popup)

	# Always on top while open (the tutorial overlay is created
	# later, but only ever after a popup has closed).
	move_child(_popup, -1)

	zones.set_input_locked(true)
	zones.set_cues_paused(true)

	_popup.open(zone_id, screen_position)


func _on_popup_closed() -> void:
	zones.set_input_locked(false)
	zones.set_cues_paused(false)

	# The Stage-2 sequence resumes within the same visit: the popup
	# that just closed was opened by a called-out step tap that
	# already advanced the sequence. (Also covers returning from
	# gameplay mid-sequence: any popup close while Stage 2 is
	# pending re-shows the next spotlight.)
	if TutorialManager.should_show_stage_2():
		_show_stage_2()


func _on_viewport_resized() -> void:
	if _tutorial_overlay != null and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.setup(
			zones.get_zone_screen_rect(_tutorial_zone_id),
			_tutorial_callout
		)

	if _popup != null and is_instance_valid(_popup) and _popup.visible:
		_popup.layout_frame()


# ============================================================
# TITLE → OFFICE CROSSFADE + WINDOW FLARE (Stage 3)
# ============================================================

func _run_title_crossfade() -> void:
	# Consume the flag immediately: the crossfade runs exactly once
	# per arrival from the title, and a mid-fade exit must never
	# re-trigger it on the next visit.
	SceneRouter.arriving_from_title = false

	# Full-screen overlay replicating the title screen's final
	# visual: its dark fallback color plus the centered title and
	# prompt labels (same fonts, colors, sizes as title_screen.tscn).
	var overlay := TextureRect.new()
	overlay.name = "TransitionOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.texture = TITLE_TEXTURE
	overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(overlay)

	# Zone taps stay locked until the fade completes so a tap can't
	# mid-fire a zone action during the transition.
	zones.set_input_locked(true)
	background.modulate.a = 0.0

	# Overlapping dual fade: overlay (title visual) out, office art in.
	# Stored so the Stage-1 tutorial can wait for its completion.
	_crossfade_tween = create_tween().set_parallel(true)
	var fade := _crossfade_tween
	fade.tween_property(overlay, "modulate:a", 0.0, CROSSFADE_SECONDS)
	fade.tween_property(background, "modulate:a", 1.0, CROSSFADE_SECONDS)

	# Window flare: warm light spilling into view, peaking at the
	# crossfade midpoint (~0.27 s), decaying just past the fade.
	zones.play_window_flare()

	fade.finished.connect(func() -> void:
		overlay.queue_free()
		zones.set_input_locked(false)
	)


# ============================================================
# TUTORIALS (Stages 4–5)
# ============================================================

func _show_tutorial() -> void:
	# Stage 1: once per fresh save. The overlay is a passive visual
	# layer: input passes through to Zones, which owns dismissal —
	# any tap (Play = proceed normally, elsewhere = skip) marks
	# Stage 1 done; it never returns.
	_active_tutorial_stage = 1
	zones.set_tutorial_active(true)
	_show_tutorial_overlay_for("play", STAGE_1_CALLOUT)


func _show_stage_2() -> void:
	# Stage 2: first office visit after WINNING Level 1 (losses never
	# trigger it). Sequential spotlight over Skills → Bestiary →
	# Earn Materials, resuming at the saved runtime step if the
	# player navigated away mid-sequence.
	_active_tutorial_stage = 2
	zones.set_tutorial_active(true)

	var step_index := clampi(
		TutorialManager.stage_2_step, 0, STAGE_2_STEPS.size() - 1
	)
	var step: Dictionary = STAGE_2_STEPS[step_index]
	_show_tutorial_overlay_for(step["zone"], step["callout"])


func _show_tutorial_overlay_for(zone_id: String, callout_text: String) -> void:
	_tutorial_zone_id = zone_id
	_tutorial_callout = callout_text

	if _tutorial_overlay != null and is_instance_valid(_tutorial_overlay):
		_tutorial_overlay.queue_free()

	_tutorial_overlay = TutorialOverlayScript.new()
	_tutorial_overlay.name = "TutorialOverlay"
	_tutorial_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_tutorial_overlay)
	_tutorial_overlay.setup(
		zones.get_zone_screen_rect(zone_id), callout_text
	)

	# The user's Stage-2 model: every SHOWN spotlight advances the
	# sequence, completing the stage on the third. Stage 1 must not
	# touch the Stage-2 counter.
	if _active_tutorial_stage == 2:
		TutorialManager.stage_2_advance()


func _on_tutorial_advanced(zone_id: String) -> void:
	var stage := _active_tutorial_stage

	_hide_tutorial_overlay()

	if stage == 1:
		_active_tutorial_stage = 0
		TutorialManager.complete_stage_1()
	elif stage == 2:
		_advance_stage_2(zone_id)


func _advance_stage_2(tapped_zone: String) -> void:
	# A tap on a called-out zone opens that zone's popup normally
	# (the zone_activated switch already fired) and does nothing
	# here — the sequence advances because every SHOWN spotlight
	# counts (TutorialManager.stage_2_advance() on show), and the
	# next spotlight appears when the popup closes. A tap on empty
	# space (or a cancelled release) skips the whole stage — it is
	# marked done and never re-triggers.
	if tapped_zone != "":
		return

	var step_index := clampi(
		TutorialManager.stage_2_step, 0, STAGE_2_STEPS.size() - 1
	)
	var step: Dictionary = STAGE_2_STEPS[step_index]
	_show_tutorial_overlay_for(step["zone"], step["callout"])

	if TutorialManager.stage_2_step > STAGE_2_STEPS.size():
		TutorialManager.stage_2_step = 0
		_active_tutorial_stage = 0
		_hide_tutorial_overlay()
		TutorialManager.complete_stage_2()



func _hide_tutorial_overlay() -> void:
	if _tutorial_overlay == null or not is_instance_valid(_tutorial_overlay):
		return

	var overlay := _tutorial_overlay
	_tutorial_overlay = null

	# Distinct name while fading: if the next spotlight's overlay is
	# created during the 0.18 s fade window, the old node must not
	# collide with the "TutorialOverlay" name (Godot would rename
	# the NEW node to a placeholder instead).
	overlay.name = "TutorialOverlayFading"

	# Quick fade so the dim doesn't pop; if the dismissing tap already
	# navigated away, the scene change frees everything anyway.
	var dismiss := create_tween()
	dismiss.tween_property(
		overlay, "modulate:a", 0.0, TUTORIAL_DISMISS_FADE_SECONDS
	)
	dismiss.tween_callback(overlay.queue_free)

func _on_setting_button_pressed() -> void:
	setting_overlay.open()
