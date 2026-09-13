extends Node2D

const ENEMY_SCENES: Dictionary = {
	"Pawn": preload("res://scenes/shadow_pawn.tscn"),
	"Knight": preload("res://scenes/shadow_knight.tscn"),
	"Bishop": preload("res://scenes/shadow_bishop.tscn"),
	"Rook": preload("res://scenes/shadow_rook.tscn"),
	"Queen": preload("res://scenes/shadow_queen.tscn"),
	"King": preload("res://scenes/shadow_king.tscn")
}

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


func spawn_enemy(type: String, game: Node) -> BaseEnemy:
	if not ENEMY_SCENES.has(type):
		return null

	var enemy: BaseEnemy = ENEMY_SCENES[type].instantiate()

	game.enemies.add_child(enemy)

	var spawn_cell = game.board.get_random_edge_cell()

	if type == "Bishop":
		spawn_cell = (
			game.board
			.get_random_edge_cell_same_color(
				game.king.current_cell
			)
		)

	enemy.setup(game, spawn_cell)

	return enemy
