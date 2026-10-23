extends Control

## Embedded-in-popup convention (task Stage 6): when this scene is
## instanced inside the Home Office popup container, `embedded` is
## true and the back button asks the popup to close instead of
## routing scenes. Standalone behavior (embedded=false) is unchanged.

signal close_requested

var embedded := false

# Assign the actual reading/book icon in the Inspector.
@export var read_icon_texture: Texture2D

const CINZEL_FONT := preload("res://assets/Cinzel-Medium.ttf")
const LORA_FONT := preload("res://assets/Lora-Regular.ttf")

const INK := Color("#3B2A1E")
const MUTED_INK := Color("#6B5442")
const GOLD := Color("#D4A64A")
const NAVY := Color("#1F2D4D")
const NAVY_HOVER := Color("#2A3B61")
const CREAM := Color("#F7EED8")
const CARD_BG := Color(240, 226, 194, 0.2)
const CARD_BORDER := Color("#C3A875")
const DISABLED_BG := Color("#D8CCAE")

@onready var office_material_label: Label = %OfficeMaterialLabel
@onready var skills_container: GridContainer = %SkillsContainer


func _ready() -> void:
	_refresh()


func _refresh() -> void:
	office_material_label.text = "Office Materials  %d" % OfficeMaterialManager.current_amount
	for child in skills_container.get_children():
		child.queue_free()

	for definition in SkillManager.get_definitions():
		skills_container.add_child(_create_skill_card(definition))


func _create_skill_card(definition: SkillDefinition) -> PanelContainer:
	var card := PanelContainer.new()

	# Three-column grid: approximately 260 × 130 px per card.
	# Two-column grid: approximately 370 × 130 px per card.
	card.custom_minimum_size = Vector2(370, 150)

	card.add_theme_stylebox_override(
		"panel",
		_create_card_style()
	)

	# Give the card some internal breathing room.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)

	card.add_child(margin)

	# ---------------------------------------------------------------
	# Left: reading icon
	# ---------------------------------------------------------------

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	margin.add_child(row)

	var icon_holder := Control.new()
	icon_holder.custom_minimum_size = Vector2(46, 0)
	icon_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL

	row.add_child(icon_holder)

	if read_icon_texture != null:
		var icon := TextureRect.new()

		icon.texture = read_icon_texture
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(42, 42)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Center vertically.
		icon.set_anchors_preset(Control.PRESET_CENTER)
		icon.position = Vector2(-21, -21)
		icon.size = Vector2(42, 42)

		icon_holder.add_child(icon)
	else:
		# Temporary fallback until the final icon is assigned.
		var placeholder := Label.new()
		placeholder.text = "✦"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		placeholder.add_theme_font_override("font", CINZEL_FONT)
		placeholder.add_theme_font_size_override("font_size", 28)
		placeholder.add_theme_color_override("font_color", GOLD)
		placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE

		icon_holder.add_child(placeholder)

	# ---------------------------------------------------------------
	# Right: skill information
	# ---------------------------------------------------------------

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 8)

	row.add_child(info)

	# Skill name
	var name_label := Label.new()
	name_label.text = definition.display_name

	name_label.add_theme_font_override("font", CINZEL_FONT)
	name_label.add_theme_font_size_override("font_size", 20)
	name_label.add_theme_color_override("font_color", INK)

	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	info.add_child(name_label)

	# Description
	var description_label := Label.new()
	description_label.text = definition.description

	description_label.add_theme_font_override("font", LORA_FONT)
	description_label.add_theme_font_size_override("font_size", 16)
	description_label.add_theme_color_override("font_color", MUTED_INK)

	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	info.add_child(description_label)

	# ---------------------------------------------------------------
	# Learn button
	# ---------------------------------------------------------------

	var learn_button := Button.new()
	learn_button.custom_minimum_size = Vector2(108, 34)

	_apply_button_style(learn_button)

	if SkillManager.has_skill(definition.skill_id):
		learn_button.text = "MASTERED"
		learn_button.disabled = true
	else:
		learn_button.text = "LEARN  •  %d" % definition.cost
		learn_button.disabled = (
			OfficeMaterialManager.current_amount < definition.cost
		)

		learn_button.pressed.connect(
			_on_buy_pressed.bind(definition.skill_id)
		)

	info.add_child(learn_button)

	return card


# ===================================================================
# Card Styling
# ===================================================================

func _create_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = CARD_BG
	style.border_color = CARD_BORDER

	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1

	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8

	# Subtle depth rather than a heavy modern UI shadow.
	#style.shadow_color = Color(0, 0, 0, 0.12)
	#style.shadow_size = 3
	#style.shadow_offset = Vector2(0, 2)

	return style


# ===================================================================
# Button Styling
# ===================================================================

func _apply_button_style(button: Button) -> void:
	button.add_theme_font_override("font", CINZEL_FONT)
	button.add_theme_font_size_override("font_size", 12)

	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_disabled_color", MUTED_INK)

	# Normal
	var normal := StyleBoxFlat.new()

	normal.bg_color = NAVY
	normal.border_color = GOLD

	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1

	normal.corner_radius_top_left = 7
	normal.corner_radius_top_right = 7
	normal.corner_radius_bottom_left = 7
	normal.corner_radius_bottom_right = 7

	button.add_theme_stylebox_override("normal", normal)

	# Hover
	var hover := normal.duplicate()
	hover.bg_color = NAVY_HOVER

	button.add_theme_stylebox_override("hover", hover)

	# Pressed
	var pressed := normal.duplicate()
	pressed.bg_color = Color("#17243D")

	button.add_theme_stylebox_override("pressed", pressed)

	# Disabled
	var disabled := normal.duplicate()

	disabled.bg_color = DISABLED_BG
	disabled.border_color = Color("#B8A982")

	button.add_theme_stylebox_override("disabled", disabled)


func _on_buy_pressed(skill_id: String) -> void:
	if SkillManager.purchase_skill(skill_id):
		_refresh()


func _on_back_pressed() -> void:
	# Popup convention (task Stage 6): embedded = ask the popup to
	# close; standalone = the original scene route.
	if embedded:
		close_requested.emit()
	else:
		SceneRouter.go_home_office()
