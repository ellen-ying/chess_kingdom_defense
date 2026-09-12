extends Node2D

const PAWN_SCENE := preload("res://scenes/pawn.tscn")
const KNIGHT_SCENE := preload("res://scenes/knight.tscn")
const BISHOP_SCENE := preload("res://scenes/bishop.tscn")
const ROOK_SCENE := preload("res://scenes/rook.tscn")
const QUEEN_SCENE := preload("res://scenes/queen.tscn")

var game: Node
var board: Node
var pieces_parent: Node2D

# The currently selected piece to place
var selected_piece_type = "Pawn"

var dragging_piece: BasePiece = null
var last_drag_cell := Vector2i(-999, -999)


func setup(
	game_reference: Node,
	board_reference: Node,
	parent_reference: Node
) -> void:
	game = game_reference
	board = board_reference
	pieces_parent = parent_reference
	


func _process(_delta: float) -> void:
	if dragging_piece == null:
		return

	var mouse_position = get_global_mouse_position()
	var cell = board.world_to_cell(mouse_position)

	if not board.is_valid_cell(cell):
		return

	if cell == last_drag_cell:
		return

	# Cannot place/move a pawn onto another player piece.
	if is_occupied_by_other_piece(cell, dragging_piece):
		return

	# Do not allow a player piece to occupy the king square.
	if cell == game.king.current_cell:
		return

	dragging_piece.set_cell(cell)
	last_drag_cell = cell


func _input(event: InputEvent) -> void:
	if game == null or game.game_over:
		return
		
	# Keyboard shortcuts for testing.
	#if event is InputEventKey and event.pressed and not event.echo:
		#if event.is_action_pressed("pawn"):
			#selected_piece_type = "Pawn"
			#game.update_hud()
#
		#elif event.is_action_pressed("knight"):
			#selected_piece_type = "Knight"
			#game.update_hud()
			#
		#elif event.is_action_pressed("bishop"):
			#selected_piece_type = "Bishop"
			#game.update_hud()
			#
		#elif event.is_action_pressed("rook"):
			#selected_piece_type = "Rook"
			#game.update_hud()
			#
		#elif event.is_action_pressed("queen"):
			#selected_piece_type = "Queen"
			#game.update_hud()

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return

		if event.pressed:
			start_dragging()
		else:
			stop_dragging()


func start_dragging() -> void:
	var mouse_position := get_global_mouse_position()

	# First check whether we clicked an existing pawn.
	var clicked_piece := get_piece_at_position(mouse_position)

	if clicked_piece != null:
		dragging_piece = clicked_piece
		last_drag_cell = clicked_piece.current_cell

		dragging_piece.set_dragging(true)
		
		get_viewport().set_input_as_handled()


func stop_dragging() -> void:
	if dragging_piece == null:
		return

	dragging_piece.set_dragging(false)

	dragging_piece = null
	last_drag_cell = Vector2i(-999, -999)
	get_viewport().set_input_as_handled()


func place_selected_piece(cell: Vector2i) -> void:
	var piece
	
	match selected_piece_type:
		"Pawn":
			piece = PAWN_SCENE.instantiate()
			
		"Knight":
			piece = KNIGHT_SCENE.instantiate()
			
		"Bishop":
			piece = BISHOP_SCENE.instantiate()
			
		"Rook":
			piece = ROOK_SCENE.instantiate()
			
		"Queen":
			piece = QUEEN_SCENE.instantiate()
			
		_:
			return

	pieces_parent.add_child(piece)

	piece.setup(game, cell)


func get_piece_at_position(position: Vector2) -> Node2D:
	# Reverse order means later-created pawns are selected first
	# if something unexpected overlaps visually.
	for i in range(pieces_parent.get_child_count() - 1, -1, -1):
		var child = pieces_parent.get_child(i)

		if not child is Node2D:
			continue

		var distance = child.global_position.distance_to(position)

		if distance <= 24.0:
			return child

	return null


func is_occupied_by_other_piece(
	cell: Vector2i,
	ignored_pawn: Node2D
) -> bool:
	for child in pieces_parent.get_children():
		if child == ignored_pawn:
			continue

		if not child is Node2D:
			continue

		if child.current_cell == cell:
			return true

	return false
