class_name BaseEnemy
extends Node2D

const MOVE_INTERVAL := 1.0
var max_hp := 3

var game: Node
var current_cell: Vector2i
var hp : int
var killed_by = null
var type = null

var move_timer := 0.0
var live_timer := 0.0
var _slow_timer := 0.0
var _slow_multiplier := 1.0

func setup(game_reference: Node, cell: Vector2i) -> void:
	push_error("BaseEnemy.setup() was not overridden.")


func take_damage(amount: int, source_piece: String) -> void:
	push_error("BaseEnemy.take_damage() was not overridden.")
	

func update_status_effects(delta: float) -> void:
	if _slow_timer <= 0.0:
		return
	_slow_timer -= delta
	if _slow_timer <= 0.0:
		_slow_timer = 0.0
		_slow_multiplier = 1.0


func apply_slow(movement_multiplier: float, duration: float) -> void:
	if movement_multiplier <= 0.0 or duration <= 0.0:
		return
	_slow_multiplier = min(_slow_multiplier, movement_multiplier)
	_slow_timer = max(_slow_timer, duration)


func get_move_interval(base_interval: float) -> float:
	return base_interval / _slow_multiplier


func push_away_from_king(distance: int) -> void:
	if game == null or distance <= 0:
		return
	var direction = current_cell - game.king.current_cell
	if direction == Vector2i.ZERO:
		return
	var step := Vector2i(sign(direction.x), sign(direction.y))
	var destination := current_cell
	for _step_number in range(distance):
		var candidate := destination + step
		if not game.board.is_valid_cell(candidate):
			break
		destination = candidate
	current_cell = destination
	global_position = game.board.cell_to_world(current_cell)
	queue_redraw()
