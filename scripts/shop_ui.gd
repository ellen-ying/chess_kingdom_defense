extends PanelContainer

const SHOP_SLOT_SCENE := preload(
	"res://scenes/shop_slot.tscn"
)

const FLOATING_REWARD_SCENE := preload(
	"res://scenes/floating_reward.tscn"
)

const CATALOG: Dictionary[String, Dictionary] = {
	"Pawn": {
		"type": "Pawn",
		"display_name": "Pawn",
		"cost": 1,
		"scene": preload("res://scenes/pawn.tscn")
	},
	"Knight": {
		"type": "Knight",
		"display_name": "Knight",
		"cost": 3,
		"scene": preload("res://scenes/knight.tscn")
	},
	"Bishop": {
		"type": "Bishop",
		"display_name": "Bishop",
		"cost": 3,
		"scene": preload("res://scenes/bishop.tscn")
	},
	"Rook": {
		"type": "Rook",
		"display_name": "Rook",
		"cost": 5,
		"scene": preload("res://scenes/rook.tscn")
	},
	"Queen": {
		"type": "Queen",
		"display_name": "Queen",
		"cost": 9,
		"scene": preload("res://scenes/queen.tscn")
	}
}

@onready var slots_container: HBoxContainer = $Slots

var placement_controller: Node
var slots: Dictionary = {}


func setup(controller: Node) -> void:
	placement_controller = controller

	_create_slots()



func _create_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()

	slots.clear()

	for definition in CATALOG.values():
		var slot = SHOP_SLOT_SCENE.instantiate()

		slots_container.add_child(slot)

		slot.configure(
			definition["type"],
			definition["display_name"],
			definition["cost"]
		)

		slots[definition["type"]] = slot


func get_definition(piece_type: String) -> Dictionary:
	return CATALOG.get(piece_type, {})


func get_piece_scene(piece_type: String) -> PackedScene:
	var definition := get_definition(piece_type)

	if definition.is_empty():
		return null

	return definition["scene"]


func begin_tray_pointer(piece_type: String) -> void:
	if placement_controller == null:
		return

	var definition := get_definition(piece_type)

	if definition.is_empty():
		return

	if (
		CurrencyManager.current_amount
		< int(definition["cost"])
	):
		return

	placement_controller.begin_piece_selection(
		piece_type,
		definition["scene"]
	)



func show_currency_reward(
	world_position: Vector2,
	amount: int
) -> void:
	var floating_reward = FLOATING_REWARD_SCENE.instantiate()

	var floating_layer: Control = (
		get_parent().get_node("FloatingRewards")
	)

	floating_layer.add_child(floating_reward)

	var target_position = (
		get_parent()
		.get_node("CurrencyLabel")
		.get_global_rect()
		.get_center()
	)

	floating_reward.play(
		amount,
		world_position,
		target_position
	)
