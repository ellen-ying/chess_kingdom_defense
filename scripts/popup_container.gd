extends Control

## PopupContainer — visual popup shell for the Home Office.
##
## The popup's visual structure is defined in popup_container.tscn.
## This script is responsible only for:
## - opening / closing
## - responsive positioning and scaling
## - open / close animation
## - loading the appropriate embedded content scene
## - dimmer input
## - close button input
## - Esc / ui_cancel input
##
## The public interface is intentionally preserved:
##     open(zone_id, source_position)
##     close()
##     layout_frame()
##     closed signal
##
## The Home Office can therefore treat this as a reusable popup
## controller without knowing anything about the popup's visual design.


signal closed


# ============================================================
# CONTENT SCENES
# ============================================================

const ZONE_SCENES := {
	"play": preload("res://scenes/level_select.tscn"),
	"skills": preload("res://scenes/skill_shop.tscn"),
	"bestiary": preload("res://scenes/bestiary.tscn"),
	"earn": preload("res://scenes/learning_openings.tscn")
}


# ============================================================
# POPUP LAYOUT
# ============================================================

## Internal design-space size of the popup scene.
##
## All visual elements inside FrameRoot are positioned using this
## coordinate system. FrameRoot itself is scaled to fit the viewport.
const DESIGN_SIZE := Vector2(979.2, 550.8)

## Maximum percentage of the viewport that the popup may occupy.
const FRAME_SCREEN_WIDTH_FRACTION := 0.85
const FRAME_SCREEN_HEIGHT_FRACTION := 0.85


# ============================================================
# ANIMATION
# ============================================================

const DIM_ALPHA := 0.60

const OPEN_SECONDS := 0.22
const CLOSE_SECONDS := 0.15

const FRAME_SCALE_FROM := 0.85


# ============================================================
# SCENE REFERENCES
# ============================================================

@onready var _dimmer: ColorRect = $Dimmer
@onready var _frame_root: Control = $FrameRoot
@onready var _content: Control = $FrameRoot/Content
@onready var _ribbon_title: Label = $FrameRoot/Ribbon/RibbonTitle
@onready var _close_button: TextureButton = $FrameRoot/CloseButton
@onready var button_sound = %ButtonSound


# ============================================================
# RUNTIME STATE
# ============================================================

var _tween: Tween

var _is_open := false
var _closing := false

var _current_zone_id := ""

## Current screen-space scale of FrameRoot.
##
## This is different from FrameRoot.scale during animation. It
## represents the final scale appropriate for the current viewport.
var _frame_scale := 1.0


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	# The scene itself is responsible for the visual hierarchy.
	# We only connect the interactive controls here.

	_dimmer.gui_input.connect(_on_dimmer_gui_input)
	_close_button.pressed.connect(_on_close_button_pressed)

	# Start hidden.
	visible = false

	# Keep visual-only nodes from interfering with embedded content.
	# These are normally already configured in the scene, but setting
	# them here makes the script robust if the scene is edited later.
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_frame_root.mouse_filter = Control.MOUSE_FILTER_PASS

	# Initial layout.
	layout_frame()


# ============================================================
# LAYOUT
# ============================================================

## Sizes and centers FrameRoot for the current viewport.
##
## FrameRoot always remains a 940×600 design-space scene internally.
## Only its position and scale change with the viewport.
##
## Called by the Home Office whenever the viewport changes size.
func layout_frame() -> void:
	if not is_instance_valid(_frame_root):
		return

	if size.x <= 0.0 or size.y <= 0.0:
		return

	var max_width := size.x * FRAME_SCREEN_WIDTH_FRACTION
	var max_height := size.y * FRAME_SCREEN_HEIGHT_FRACTION

	_frame_scale = min(
		max_width / DESIGN_SIZE.x,
		max_height / DESIGN_SIZE.y
	)

	var displayed_size := DESIGN_SIZE * _frame_scale

	_frame_root.position = (size - displayed_size) / 2.0

	# The children inside FrameRoot use design-space coordinates.
	_frame_root.size = DESIGN_SIZE

	# Do not use the animated scale here if the popup is currently
	# opening or closing. During normal layout this is the final scale.
	if not _is_open or _closing:
		_frame_root.scale = Vector2.ONE * _frame_scale


# ============================================================
# OPEN
# ============================================================

func open(zone_id: String, source_position: Vector2) -> void:
	if not ZONE_SCENES.has(zone_id):
		push_warning(
			"PopupContainer: unknown zone_id: %s" % zone_id
		)
		return

	_current_zone_id = zone_id

	_is_open = true
	_closing = false
	visible = true

	layout_frame()

	# --------------------------------------------------------
	# Load popup content
	# --------------------------------------------------------

	_clear_content()
	_load_content(zone_id)
	_update_ribbon_title(zone_id)

	# --------------------------------------------------------
	# Prepare opening animation
	# --------------------------------------------------------

	# Convert the Home Office screen-space tap position into
	# FrameRoot's local design-space coordinates.
	#
	# This is important because FrameRoot is scaled on different
	# screen sizes.
	var local_source_position := (source_position - _frame_root.position) / _frame_scale

	_frame_root.pivot_offset = local_source_position

	_frame_root.scale = (
		Vector2.ONE * _frame_scale * FRAME_SCALE_FROM
	)

	_frame_root.modulate.a = 0.0
	_dimmer.modulate.a = 0.0

	# Cancel an old animation if one somehow remains active.
	if _tween != null and _tween.is_valid():
		_tween.kill()

	# --------------------------------------------------------
	# Animate
	# --------------------------------------------------------

	_tween = create_tween().set_parallel(true)

	_tween.tween_property(
		_dimmer,
		"modulate:a",
		DIM_ALPHA,
		OPEN_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_tween.tween_property(
		_frame_root,
		"modulate:a",
		1.0,
		OPEN_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	_tween.tween_property(
		_frame_root,
		"scale",
		Vector2.ONE * _frame_scale,
		OPEN_SECONDS
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ============================================================
# CONTENT
# ============================================================

func _load_content(zone_id: String) -> void:
	var content_scene: PackedScene = ZONE_SCENES[zone_id]
	var content := content_scene.instantiate()

	# Preserve the existing embedded-content contract.
	#
	# The current popup system expects the four content scenes to
	# expose `embedded` and `close_requested`.
	content.embedded = true

	_content.add_child(content)


func _clear_content() -> void:
	if not is_instance_valid(_content):
		return

	for child in _content.get_children():
		child.queue_free()


# ============================================================
# RIBBON TITLE
# ============================================================

## Updates the title displayed on the visual ribbon.
##
## The ribbon itself lives in the scene. The script only supplies
## the text appropriate to the currently opened zone.
func _update_ribbon_title(zone_id: String) -> void:
	if not is_instance_valid(_ribbon_title):
		return

	match zone_id:
		"play":
			_ribbon_title.text = "Defense"

		"skills":
			_ribbon_title.text = "Royal Skills"

		"bestiary":
			_ribbon_title.text = "Enemy Bestiary"
			_ribbon_title.add_theme_font_size_override("font_size", 40)

		"earn":
			_ribbon_title.text = "Ledger"

		_:
			_ribbon_title.text = ""


# ============================================================
# CLOSE
# ============================================================

func close() -> void:
	if not _is_open or _closing:
		return

	_closing = true
	
	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = create_tween().set_parallel(true)

	_tween.tween_property(
		_dimmer,
		"modulate:a",
		0.0,
		CLOSE_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_tween.tween_property(
		_frame_root,
		"modulate:a",
		0.0,
		CLOSE_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_tween.tween_property(
		_frame_root,
		"scale",
		Vector2.ONE * _frame_scale * FRAME_SCALE_FROM,
		CLOSE_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	_tween.chain().tween_callback(_finish_close)


func _finish_close() -> void:
	_is_open = false
	_closing = false
	visible = false

	_clear_content()

	_current_zone_id = ""

	closed.emit()


# ============================================================
# DIMMER INPUT
# ============================================================

func _on_dimmer_gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		close()


# ============================================================
# ESC / CANCEL INPUT
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close()
		
		
func _on_close_button_pressed():
	button_sound.play()
	close()
