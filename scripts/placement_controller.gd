extends Node2D

enum PlacementMode {
	NONE,
	PENDING_DRAG,
	DRAGGING,
	ARMED
}

const PREVIEW_ALPHA := 0.45
const RANGE_ALPHA := 0.20

var game: Node
var board: Node
var pieces_parent: Node

var mode := PlacementMode.NONE
var active_piece_type := ""
var active_piece_scene: PackedScene = null

var ghost_piece: BasePiece = null
var hovered_cell := Vector2i(-999, -999)


func setup(
	game_reference: Node,
	board_reference: Node,
	parent_reference: Node
) -> void:
	game = game_reference
	board = board_reference
	pieces_parent = parent_reference


func begin_piece_selection(
	piece_type: String,
	piece_scene: PackedScene
) -> void:
	# Clicking another slot replaces the previous pending piece.
	active_piece_type = piece_type
	active_piece_scene = piece_scene

	mode = PlacementMode.PENDING_DRAG

	_create_ghost()


func _process(_delta: float) -> void:
	if mode == PlacementMode.NONE:
		return

	var mouse_position := get_global_mouse_position()

	hovered_cell = board.world_to_cell(mouse_position)

	if board.is_valid_cell(hovered_cell):
		_update_ghost()
	else:
		if ghost_piece != null:
			ghost_piece.visible = false

	queue_redraw()


func _input(event: InputEvent) -> void:
	if mode == PlacementMode.NONE:
		return

	if event is InputEventMouseMotion:
		if mode == PlacementMode.PENDING_DRAG:
			var mouse_position := get_global_mouse_position()

			if ghost_piece != null:
				var start_position := (
					ghost_piece.global_position
				)

				if mouse_position.distance_to(start_position) >= 8:
					mode = PlacementMode.DRAGGING

		return

	if not event is InputEventMouseButton:
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		return

	# Mouse release.
	if mode == PlacementMode.PENDING_DRAG:
		mode = PlacementMode.NONE
		_cleanup_ghost()
		return

	if mode == PlacementMode.DRAGGING:
		_handle_drag_drop()
		get_viewport().set_input_as_handled()
		return



func _handle_drag_drop() -> void:
	var cell = board.world_to_cell(
		get_global_mouse_position()
	)

	if not is_valid_placement_cell(cell):
		clear_placement()
		return

	place_piece(cell)

func is_valid_placement_cell(cell: Vector2i) -> bool:
	if not board.is_valid_cell(cell):
		return false

	# Cannot place on the King.
	if cell == game.king.current_cell:
		return false

	# Player pieces may only be placed in the central 9-column zone;
	# the outer columns are enemy-traversal-only territory (full-bleed
	# layout brief).
	if not board.is_placeable_cell(cell):
		return false

	# Only player pieces block placement.
	for child in pieces_parent.get_children():
		if not child is BasePiece:
			continue

		var child_cell = child.get("current_cell")

		if child_cell == cell:
			return false

	return true


func place_piece(cell: Vector2i) -> void:
	if not is_valid_placement_cell(cell):
		return

	if active_piece_scene == null:
		return

	var definition_cost := CurrencyManager.get_piece_value(active_piece_type)

	# Materials are checked again here because the player
	# may have spent them while the piece was pending.
	if CurrencyManager.current_amount < definition_cost:
		clear_placement()
		return

	# IMPORTANT:
	# Only now do we deduct Materials.
	if not CurrencyManager.spend_currency(
		definition_cost
	):
		clear_placement()
		return
	
	var piece := active_piece_scene.instantiate() as BasePiece

	if piece == null:
		# This should not normally happen, but don't allow
		# a failed instantiation to consume currency.
		CurrencyManager.add_currency(definition_cost, false)

		clear_placement()
		return

	GameLogger.log_piece_purchased(
		active_piece_type, definition_cost, CurrencyManager.get_current_amount()
	)
	GameLogger.log_piece_placed(
		active_piece_type, cell.x, cell.y,
		game.wave_manager.get_wave_number()
	)
	pieces_parent.add_child(piece)
	piece.setup(game, cell)

	# Inventory is increased only after successful placement.
	InventoryManager.add_piece(active_piece_type)

	clear_placement()


func _create_ghost() -> void:
	_cleanup_ghost()

	if active_piece_scene == null:
		return

	ghost_piece = active_piece_scene.instantiate() as BasePiece

	if ghost_piece == null:
		return

	add_child(ghost_piece)

	ghost_piece.modulate = Color(
		1.0,
		1.0,
		1.0,
		PREVIEW_ALPHA
	)

	ghost_piece.process_mode = (
		Node.PROCESS_MODE_DISABLED
	)

	ghost_piece.visible = true


func _update_ghost() -> void:
	if ghost_piece == null:
		return

	if not board.is_valid_cell(hovered_cell):
		ghost_piece.visible = false
		return

	ghost_piece.visible = true

	ghost_piece.global_position = board.cell_to_world(hovered_cell)


func clear_placement() -> void:
	mode = PlacementMode.NONE
	active_piece_type = ""
	active_piece_scene = null

	hovered_cell = Vector2i(-999, -999)
	_cleanup_ghost()
	queue_redraw()


func _cleanup_ghost() -> void:
	if ghost_piece != null:
		ghost_piece.queue_free()
		ghost_piece = null


func _draw() -> void:
	if mode == PlacementMode.NONE:
		return

	if not board.is_valid_cell(hovered_cell):
		return

	# ----------------------------------------------------
	# Current placement cell: green = valid, red = invalid
	# ----------------------------------------------------

	var valid := is_valid_placement_cell(hovered_cell)

	var tile_rect := Rect2(
		board.cell_to_world(hovered_cell)
		- Vector2(
			board.tile_size / 2.0,
			board.tile_size / 2.0
		),
		Vector2(
			board.tile_size,
			board.tile_size
		)
	)

	if valid:
		draw_rect(
			tile_rect,
			Color(0.2, 1.0, 0.2, 0.25)
		)
	else:
		draw_rect(
			tile_rect,
			Color(1.0, 0.2, 0.2, 0.30)
		)

	# ----------------------------------------------------
	# Attack range overlay
	# ----------------------------------------------------

	if ghost_piece == null:
		return

	var attack_tiles := (
		ghost_piece.get_attack_tiles_for_cell(
			hovered_cell,
			board
		)
	)

	for attack_cell in attack_tiles:
		var attack_rect := Rect2(
			board.cell_to_world(attack_cell)
			- Vector2(
				board.tile_size / 2.0,
				board.tile_size / 2.0
			),
			Vector2(
				board.tile_size,
				board.tile_size
			)
		)

		draw_rect(
			attack_rect,
			Color(1.0, 0.85, 0.2, RANGE_ALPHA)
		)

		draw_rect(
			attack_rect,
			Color(1.0, 0.85, 0.2, 0.35),
			false,
			2.0
		)
