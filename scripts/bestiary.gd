extends Control

## Embedded-in-popup convention (task Stage 6): when this scene is
## instanced inside the Home Office popup container, `embedded` is
## true and the back button asks the popup to close instead of
## routing scenes. Standalone behavior (embedded=false) is unchanged.

signal close_requested

var embedded := false

const CINZEL_FONT := preload("res://assets/Cinzel-Medium.ttf")
const LORA_FONT := preload("res://assets/Lora-Regular.ttf")

const INK := Color("#3B2A1E")
const MUTED_INK := Color("#6B5442")
const GOLD := Color("#D4A64A")
const NAVY := Color("#1F2D4D")
const NAVY_HOVER := Color("#2A3B61")
const CREAM := Color("#F7EED8")
const CARD_BG := Color("#F0E2C2")
const CARD_HOVER := Color("#F8EBD0")
const CARD_BORDER := Color("#C3A875")
const DISABLED_BG := Color("#D8CCAE")

@onready var entries_grid: GridContainer = %EntriesGrid
@onready var piece_icon: TextureRect = %PieceIcon
@onready var piece_name: Label = %PieceName
@onready var movement_description: Label = %MovementDescription


func _ready() -> void:
	_populate_entries()


func _populate_entries() -> void:
	for child in entries_grid.get_children():
		child.queue_free()

	for entry in BestiaryManager.get_entries():
		if _create_entry_card(entry) != null:
			entries_grid.add_child(_create_entry_card(entry))


func _create_entry_card(entry: EnemyBestiaryEntry) -> Button:
	var unlocked := BestiaryManager.has_encountered(entry.enemy_type)
	if not unlocked:
		return null
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 145)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_FILL
	card.add_theme_stylebox_override("normal", _create_card_style(CARD_BG))
	card.add_theme_stylebox_override("hover", _create_card_style(CARD_HOVER))
	card.add_theme_stylebox_override("pressed", _create_card_style(CARD_HOVER))
	
	# Center the icon and name as a single vertical composition.
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(center)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 0)
	content.custom_minimum_size = Vector2(110, 140)
	content.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(content)
	
	# Real enemy sprite texture.
	if entry.illustration != null:
		var illustration := TextureRect.new()
		illustration.texture = entry.illustration
		illustration.custom_minimum_size = Vector2(72, 76)
		illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		illustration.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(illustration)
	else:
		var silhouette := Label.new()
		silhouette.text = "♟" if unlocked else "?"
		silhouette.add_theme_font_size_override("font_size", 52)
		silhouette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(silhouette)

	var name_label := Label.new()
	name_label.text = entry.display_name if unlocked else "Unknown Piece"
	name_label.add_theme_font_override("font", CINZEL_FONT)
	name_label.add_theme_color_override("font_color", INK)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(name_label)

	#var details_label := Label.new()
	#details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	#details_label.text = entry.movement_description if unlocked else "Encounter this enemy in a defense to reveal its movement."
	#content.add_child(details_label)

	if unlocked and not entry.flavor_text.is_empty():
		var flavor_label := Label.new()
		flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flavor_label.text = entry.flavor_text
		content.add_child(flavor_label)
	
	card.pressed.connect(_on_entry_selected.bind(entry))
	
	return card
	
# ===================================================================
# Card Styling
# ===================================================================

func _create_card_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = color
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
	style.shadow_color = Color(0, 0, 0, 0.12)
	style.shadow_size = 2
	style.shadow_offset = Vector2(0, 1)

	return style
	
func _on_entry_selected(entry: EnemyBestiaryEntry) -> void:
	piece_icon.texture = entry.illustration
	piece_name.text = entry.display_name
	movement_description.text = entry.movement_description
	pass
