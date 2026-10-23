extends PanelContainer

const DRAG_THRESHOLD := 8.0

var piece_type: String = ""
var display_name: String = ""
var cost: int = 0

var pointer_down := false
var pointer_position := Vector2.ZERO

@onready var icon_label: TextureRect = %IconTexture
@onready var num_label: Label = %NumLabel
@onready var info_label: Label = %InfoLabel


func configure(
	type: String,
	display_name_value: String,
	cost_value: int
) -> void:
	piece_type = type
	display_name = display_name_value
	cost = cost_value
	
	var texture_file = "res://assets/" + piece_type.to_lower() + ".png"
	icon_label.texture = load(texture_file)

	_update_display(InventoryManager.get_piece_count(piece_type))


func _ready() -> void:
	InventoryManager.inventory_changed.connect(_on_inventory_changed)
	CurrencyManager.currency_changed.connect(_on_currency_changed)


func _update_display(inventory_count: int) -> void:
	var enough_materials := (CurrencyManager.current_amount >= cost)

	info_label.text = ("%s · %d M" % [display_name, cost])
	num_label.text = "x%d" % [inventory_count]

	if enough_materials:
		modulate = Color.WHITE
	else:
		modulate = Color(0.45, 0.45, 0.45)


func _on_inventory_changed(
	changed_type: String,
	new_amount: int
) -> void:
	if changed_type == piece_type:
		_update_display(new_amount)


func _on_currency_changed(
	_new_amount: int
) -> void:
	_update_display(InventoryManager.get_piece_count(piece_type))


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	# Clicking should only work if the player can afford
	# the piece at this moment.
	if CurrencyManager.current_amount < cost:
		accept_event()
		return

	if event.pressed:
		pointer_down = true
		pointer_position = event.position

		get_parent().get_parent().get_parent().get_parent().begin_tray_pointer(piece_type)

		accept_event()
		return

	if not pointer_down:
		return

	pointer_down = false

	accept_event()


#func get_icon_text(type: String) -> String:
	#match type:
		#"Pawn":
			#return "♙"
		#"Knight":
			#return "♘"
		#"Bishop":
			#return "♗"
		#"Rook":
			#return "♖"
		#"Queen":
			#return "♕"
#
	#return "?"
