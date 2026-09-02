extends Node2D

# ============================================================
# TEST CONFIGURATION
# ============================================================

@export_category("Prototype Testing")

@export_enum("Pawn", "Knight", "Bishop", "Rook", "Queen", "King", "None")
var test_enemy_mode := "Pawn"

@export
var auto_spawn_enemies := true

# ============================================================
# GAME STATE
# ============================================================

var lives := 3
var game_over := false

@onready var board = $Board
@onready var king = $King

@onready var pieces = $Pieces
@onready var enemies = $Enemies
@onready var projectiles = $Projectiles

@onready var piece_manager = $PieceManager
@onready var enemy_manager = $EnemyManager

@onready var status_label: Label = $UILayer/StatusLabel
@onready var game_over_label: Label = $UILayer/GameOverLabel


func _ready() -> void:
	# Position the king.
	king.setup(board.get_center_cell(), board)

	# Initialize the piece manager.
	piece_manager.setup(
		self,
		board,
		pieces
	)

	# Initialize enemy spawning.
	enemy_manager.setup(
		self,
		enemies,
		board
	)

	game_over_label.visible = false

	update_hud()


func update_hud() -> void:
	status_label.text = (
        "KING  %d / 3     WAVE  %d     PLACE: %s"
		% [lives, enemy_manager.wave, piece_manager.selected_piece_type]
	)


func find_enemy_at_cell(cell: Vector2i):
	var enemies_here := get_enemies_at_cell(cell)

	if enemies_here.is_empty():
		return null

	return enemies_here[0]


func get_enemies_at_cell(cell: Vector2i) -> Array:
	var result: Array = []

	for enemy in enemies.get_children():
		if enemy.current_cell == cell:
			result.append(enemy)

	return result


func spawn_projectile(piece: Node2D, target: Node) -> void:
	if game_over:
		return

	if target == null or not is_instance_valid(target):
		return

	var projectile = preload(
        "res://scenes/projectile.tscn"
	).instantiate()

	projectiles.add_child(projectile)

	projectile.setup(
		piece.global_position,
		target
	)


func enemy_destroyed(enemy: Node) -> void:
	if is_instance_valid(enemy):
		enemy.queue_free()


func enemy_reached_king(enemy: Node) -> void:
	if game_over:
		return

	lives -= 1

	if is_instance_valid(enemy):
		enemy.queue_free()

	update_hud()

	if lives <= 0:
		end_game()


func end_game() -> void:
	game_over = true

	game_over_label.visible = true

	# Stop spawning new enemies.
	enemy_manager.spawn_timer.stop()

	update_hud()
