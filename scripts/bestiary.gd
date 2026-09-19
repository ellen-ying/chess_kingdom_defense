extends Control

@onready var entries_grid: GridContainer = %EntriesGrid
@onready var back_button: Button = %BackButton


func _ready() -> void:
	_populate_entries()
	back_button.grab_focus()


func _populate_entries() -> void:
	for child in entries_grid.get_children():
		child.queue_free()

	for entry in BestiaryManager.get_entries():
		entries_grid.add_child(_create_entry_card(entry))


func _create_entry_card(entry: EnemyBestiaryEntry) -> PanelContainer:
	var unlocked := BestiaryManager.has_encountered(entry.enemy_type)
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(250, 240)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	card.add_child(content)

	if unlocked and entry.illustration != null:
		var illustration := TextureRect.new()
		illustration.texture = entry.illustration
		illustration.custom_minimum_size = Vector2(0, 80)
		illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content.add_child(illustration)
	else:
		var silhouette := Label.new()
		silhouette.text = "♟" if unlocked else "?"
		silhouette.add_theme_font_size_override("font_size", 52)
		silhouette.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		content.add_child(silhouette)

	var name_label := Label.new()
	name_label.text = entry.display_name if unlocked else "Unknown Piece"
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(name_label)

	var details_label := Label.new()
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.text = entry.movement_description if unlocked else "Encounter this enemy in a defense to reveal its movement."
	content.add_child(details_label)

	if unlocked and not entry.flavor_text.is_empty():
		var flavor_label := Label.new()
		flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flavor_label.text = entry.flavor_text
		content.add_child(flavor_label)

	return card


func _on_back_pressed() -> void:
	SceneRouter.go_home_office()
