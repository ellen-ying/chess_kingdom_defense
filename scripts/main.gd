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
var max_waves: int
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

@onready var background: ColorRect = $Background
@onready var ui_layer: CanvasLayer = $UILayer
@onready var shop_ui = $UILayer/ShopUI

@onready var hud_bar: PanelContainer = $UILayer/HUDBar
@onready var menu_button: Button = $UILayer/HUDBar/HBox/MenuButton
@onready var lives_label: Label = $UILayer/HUDBar/HBox/LivesLabel
@onready var wave_label: Label = $UILayer/HUDBar/HBox/WaveLabel
@onready var currency_label: Label = $UILayer/HUDBar/HBox/CurrencyLabel
@onready var wave_banner: Label = $UILayer/WaveBanner
@onready var pause_overlay: Control = $UILayer/PauseOverlay
@onready var result_overlay: Control = $UILayer/ResultOverlay


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

	# Initialize all nodes
	piece_manager.setup(self, board, piece_parent)
	enemy_manager.setup(self, enemies, board)
	placement_controller.setup(self, board, piece_parent)
	shop_ui.setup(placement_controller)
	wave_manager.configure_level(level_config)
	# Connect the wave signals BEFORE setup(): setup() starts the
	# first wave immediately, so signals emitted during setup (the
	# first wave_started, or a premature level_completed) must
	# already have listeners.
	wave_manager.level_completed.connect(_on_level_completed)
	wave_manager.wave_started.connect(update_hud)
	wave_manager.setup(self, board, wave_banner)
	max_waves = wave_manager.get_total_wave_number()

	CurrencyManager.currency_changed.connect(_on_currency_changed)

	_on_currency_changed(CurrencyManager.current_amount)


	menu_button.pressed.connect(_on_menu_button_pressed)
	pause_overlay.setup(self)
	result_overlay.setup(self)

	update_hud()

	# First real layout pass. Must run after the King and all
	# @onready references exist; ScreenLayout re-applies this on
	# every viewport resize (window size / aspect / orientation).
	ScreenLayout.apply_layout(self)
	
	# Position the king.
	king.setup(self, board.get_center_cell(), board)
	


func update_hud() -> void:
	# Same display formats as the old combined StatusLabel (task Q6).
	lives_label.text = (
		"KING  %d / %d"
		% [lives, max_lives]
	)

	wave_label.text = (
		"WAVE  %d / %d"
		% [wave_manager.get_current_wave_number(), max_waves]
	)


func _on_menu_button_pressed() -> void:
	pause_overlay.open()


func _exit_tree() -> void:
	# Defensive: if the scene changes while the player-initiated
	# pause overlay is open, the next scene must not inherit a
	# paused tree.
	get_tree().paused = false

func find_piece_at_cell(cell: Vector2i):
	var result = null
	
	for piece in piece_parent.get_children():
		if piece.current_cell == cell:
			result = piece

	return result

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
		InventoryManager.remove_piece(piece.type)
		if piece.get_parent():
			piece.get_parent().remove_child(piece)
		piece.queue_free()
		

func enemy_destroyed(enemy: Node, source_piece: String) -> void:
	if is_instance_valid(enemy):
		var type = enemy.type
		GameLogger.log_enemy_killed(
			type, source_piece,
			wave_manager.get_current_wave_number(), enemy.live_timer
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
	GameLogger.log_king_life_lost(lives, wave_manager.get_current_wave_number())

	if is_instance_valid(enemy):
		GameLogger.log_enemy_reached_king(
			enemy.type,	wave_manager.get_current_wave_number()
		)
		if enemy.get_parent():
			enemy.get_parent().remove_child(enemy)
		enemy.queue_free()

	# The loss must be decided BEFORE enemy_changed is emitted:
	# that signal lets the WaveManager end the final wave and
	# complete the level synchronously, which previously won the
	# race against the lives check and logged an all-lives-lost
	# run as WIN (running _finish_run twice).
	if lives <= 0:
		outcome = "LOSE"
		waves_survived = wave_manager.current_wave_index
		end_game()
		result_overlay.open(outcome)
		return

	enemy_changed.emit()
	update_hud()


func end_game() -> void:
	game_over = true

	update_hud()
	_finish_run()


## Ends the run early with an explicit result label. Used by the
## AutoplayBot autoload (wave cap / hard timeout) and by the pause
## menu's "Return to Home Office" (outcome "ABANDONED"); it must
## NEVER be called from normal win/lose gameplay logic.
func end_run_with_result(result: String) -> void:
	if game_over:
		return

	outcome = result
	waves_survived = wave_manager.current_wave_index
	end_game()
	SceneRouter.go_home_office()


func _on_level_completed() -> void:
	if game_over:
		return

	game_over = true
	outcome = "WIN"
	waves_survived = wave_manager.current_wave_index 
	LevelProgressManager.complete_level(level_config.level_id)
	result_overlay.open(outcome)
	_finish_run()


func _finish_run() -> void:
	if level_config != null and level_config.is_infinite():
		LevelProgressManager.record_final_stand_score(
			wave_manager.get_waves_survived()
		)
	RunRewardManager.finish_run()
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
