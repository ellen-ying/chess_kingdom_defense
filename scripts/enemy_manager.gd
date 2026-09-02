extends Node2D

const SHADOW_PAWN_SCENE := preload("res://scenes/shadow_pawn.tscn")
const SHADOW_KNIGHT_SCENE := preload("res://scenes/shadow_knight.tscn")
const SHADOW_BISHOP_SCENE := preload("res://scenes/shadow_bishop.tscn")
const SHADOW_ROOK_SCENE := preload("res://scenes/shadow_rook.tscn")
const SHADOW_QUEEN_SCENE := preload("res://scenes/shadow_queen.tscn")
const SHADOW_KING_SCENE := preload("res://scenes/shadow_king.tscn")

@onready var spawn_timer: Timer = $SpawnTimer

var game: Node
var enemies_parent: Node2D
var board: Node

var spawned_count := 0
var wave := 1

var pawn_spawn_count := 0
var knight_spawn_count := 0
var bishop_spawn_count := 0
var rook_spawn_count := 0
var queen_spawn_count := 0
var king_spawn_count := 0


func setup(
	game_reference: Node,
	enemy_parent: Node2D,
	board_reference: Node
) -> void:
	game = game_reference
	enemies_parent = enemy_parent
	board = board_reference

	if game.auto_spawn_enemies:
		spawn_timer.start()


func _on_spawn_timer_timeout() -> void:
	if game == null or game.game_over:
		return

	spawn_enemy()


func spawn_enemy() -> void:
	var enemy_type = choose_enemy_type()
	
	if enemy_type == "None":
		return
		
	var spawn_cell : Vector2i
	spawn_cell = board.get_random_edge_cell()
	
	var enemy: BaseEnemy
	
	match enemy_type:
		"Pawn":
			enemy = SHADOW_PAWN_SCENE.instantiate()
			pawn_spawn_count += 1
		"Knight":
			enemy = SHADOW_KNIGHT_SCENE.instantiate()
			knight_spawn_count += 1
		"Bishop":
			enemy = SHADOW_BISHOP_SCENE.instantiate()
			bishop_spawn_count += 1
			spawn_cell = board.get_random_edge_cell_same_color(game.king.current_cell)
		"Rook":
			enemy = SHADOW_ROOK_SCENE.instantiate()
			rook_spawn_count += 1
		"Queen":
			enemy = SHADOW_QUEEN_SCENE.instantiate()
			queen_spawn_count += 1
		"King":
			enemy = SHADOW_KING_SCENE.instantiate()
			king_spawn_count += 1
		_:
			return

	enemies_parent.add_child(enemy)
	enemy.setup(game, spawn_cell)

	spawned_count += 1

	# Ten enemies per wave.
	wave = int((spawned_count - 1) / 10) + 1

	game.update_hud()
	
func choose_enemy_type() -> String:
	match game.test_enemy_mode:
		"Pawn":
			return "Pawn"
		"Knight":
			return "Knight"
		"Bishop":
			return "Bishop"
		"Rook":
			return "Rook"
		"Queen":
			return "Queen"
		"King":
			return "King"
		"None":
			return "None"

	return "None"
