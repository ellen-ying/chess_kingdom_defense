extends Node2D

# ============================================================
# TEST CONFIGURATION
# ============================================================

@export_category("Prototype Testing")

@export_enum("Pawn", "Knight", "Bishop", "Rook", "Queen", "King", "None")
var test_enemy_mode := "Pawn"

@export
var auto_spawn_enemies = false


# ============================================================
# GAME STATE
# ============================================================

const BASE_LIVES := 3

var lives := BASE_LIVES
var max_lives := BASE_LIVES
var game_over := false
var outcome = null
var waves_survived = -1
var level_config: LevelConfig

signal enemy_changed

@onready var board = $Board
@onready var king = $King

@onready var enemies = $Enemies
@onready var projectiles = $Projectiles

@onready var piece_manager = $PieceManager
@onready var enemy_manager = $EnemyManager
@onready var wave_manager = $WaveManager
@onready var piece_parent = $Pieces
@onready var placement_controller = $PlacementController

@onready var shop_ui = $UILayer/ShopUI

@onready var status_label: Label = $UILayer/StatusLabel
@onready var currency_label: Label = $UILayer/CurrencyLabel
@onready var game_over_label: Label = $UILayer/GameOverLabel
@onready var wave_banner: Label = $UILayer/WaveBanner


func _ready() -> void:
	GameLogger.start_run(SceneRouter.selected_level_id)
	level_config = LevelProgressManager.get_level_config(SceneRouter.selected_level_id)
	if level_config == null:
		push_error("No level configuration selected: %s" % SceneRouter.selected_level_id)
		SceneRouter.go_home_office()
		return

	CurrencyManager.reset_for_new_run()
	InventoryManager.reset_for_new_run()
	max_lives = BASE_LIVES + int(SkillManager.get_effect_value(SkillDefinition.EffectType.KING_LIVES))
	lives = max_lives
	RunRewardManager.begin_run()

	# Position the king.
	king.setup(board.get_center_cell(), board)

	# Initialize all nodes
	piece_manager.setup(self, board, piece_parent)
	enemy_manager.setup(self, enemies, board)
	placement_controller.setup(self, board, piece_parent)
	shop_ui.setup(placement_controller)
	wave_manager.configure_level(level_config)
	wave_manager.setup(self, board, wave_banner)
	wave_manager.level_completed.connect(_on_level_completed)
	wave_manager.wave_started.connect(update_hud)

	CurrencyManager.currency_changed.connect(_on_currency_changed)

	_on_currency_changed(CurrencyManager.current_amount)

	game_over_label.visible = false

	update_hud()


func update_hud() -> void:
	status_label.text = (
		"KING  %d / %d     WAVE  %d"
		% [lives, max_lives, wave_manager.current_wave_index + 1]
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
		target,
		piece
	)

func piece_destroyed(piece: Node) -> void:
	if is_instance_valid(piece):
		if piece.get_parent():
			piece.get_parent().remove_child(piece)
		piece.queue_free()
		

func enemy_destroyed(enemy: Node, source_piece: String) -> void:
	if is_instance_valid(enemy):
		var type = enemy.type
		GameLogger.log_enemy_killed(
			type, source_piece,
			wave_manager.get_wave_number(), enemy.live_timer
		)
		GameLogger.log_material_earned(
			CurrencyManager.get_piece_value(type.replace("Shadow","")), type
		)
		if enemy.get_parent():
			enemy.get_parent().remove_child(enemy)
		enemy.queue_free()
	
	enemy_changed.emit()


func enemy_reached_king(enemy: Node) -> void:
	if game_over:
		return

	lives -= 1
	GameLogger.log_king_life_lost(lives, wave_manager.get_wave_number())

	if is_instance_valid(enemy):
		GameLogger.log_enemy_reached_king(
			enemy.type,	wave_manager.get_wave_number()
		)
		if enemy.get_parent():
			enemy.get_parent().remove_child(enemy)
		enemy.queue_free()
		
	enemy_changed.emit()
	update_hud()

	if lives <= 0:
		outcome = "LOSE"
		waves_survived = wave_manager.current_wave_index
		end_game()


func end_game() -> void:
	game_over = true

	game_over_label.visible = true

	update_hud()
	_finish_run()


func _on_level_completed() -> void:
	if game_over:
		return

	game_over = true
	outcome = "WIN"
	waves_survived = wave_manager.current_wave_index 
	LevelProgressManager.complete_level(level_config.level_id)
	_finish_run()


func _finish_run() -> void:
	if level_config != null and level_config.is_infinite():
		LevelProgressManager.record_final_stand_score(
			wave_manager.get_waves_survived()
		)
	RunRewardManager.finish_run()
	SceneRouter.go_home_office()
	if ((not outcome) or waves_survived < 0):
		push_error("Invalid end of run satistics.")
	GameLogger.end_run(
		outcome, waves_survived, 
		RunRewardManager.run_material_earned, CurrencyManager.currency_spent
	)
	
func _on_currency_changed(new_amount: int) -> void:
	currency_label.text = (
		"MATERIALS: %d"
		% new_amount
	)
