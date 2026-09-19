extends Control

@onready var office_material_label: Label = %OfficeMaterialLabel
@onready var skills_container: VBoxContainer = %SkillsContainer
@onready var back_button: Button = %BackButton


func _ready() -> void:
	_refresh()
	back_button.grab_focus()


func _refresh() -> void:
	office_material_label.text = "OFFICE MATERIAL  %d" % OfficeMaterialManager.current_amount
	for child in skills_container.get_children():
		child.queue_free()

	for definition in SkillManager.get_definitions():
		skills_container.add_child(_create_skill_card(definition))


func _create_skill_card(definition: SkillDefinition) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 116)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)

	var icon := Label.new()
	icon.text = "★"
	icon.add_theme_font_size_override("font_size", 32)
	icon.custom_minimum_size = Vector2(48, 0)
	icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(icon)

	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(copy)

	var name_label := Label.new()
	name_label.text = definition.display_name
	name_label.add_theme_font_size_override("font_size", 22)
	copy.add_child(name_label)

	var description_label := Label.new()
	description_label.text = definition.description
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.add_child(description_label)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(126, 52)
	if SkillManager.has_skill(definition.skill_id):
		buy_button.text = "OWNED"
		buy_button.disabled = true
	else:
		buy_button.text = "BUY  %d" % definition.cost
		buy_button.disabled = OfficeMaterialManager.current_amount < definition.cost
		buy_button.pressed.connect(_on_buy_pressed.bind(definition.skill_id))
	row.add_child(buy_button)

	return card


func _on_buy_pressed(skill_id: String) -> void:
	if SkillManager.purchase_skill(skill_id):
		_refresh()


func _on_back_pressed() -> void:
	SceneRouter.go_home_office()
