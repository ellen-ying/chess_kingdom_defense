class_name WaveManager
extends Node

signal level_completed
signal wave_started

@export_category("Wave Configuration")

@export var waves: Array[WaveConfig] = []

@export_category("Debug")

@export var debug_mode: bool = true
@export_range(1, 100, 1)
var debug_start_wave: int = 1

@export var start_automatically: bool = true

var current_wave_index := -1
var spawning := false
var waiting_for_clear := false
var level_complete := false
var game: Node
var board: Node
var wave_banner: Node

var spawn_timer := 0.0
var wave_timer := 0.0
var total_timer := 0.0
var level_config: LevelConfig

const ENEMY_SCENES: Dictionary = {
	"Pawn": preload("res://scenes/shadow_pawn.tscn"),
	"Knight": preload("res://scenes/shadow_knight.tscn"),
	"Bishop": preload("res://scenes/shadow_bishop.tscn"),
	"Rook": preload("res://scenes/shadow_rook.tscn"),
	"Queen": preload("res://scenes/shadow_queen.tscn"),
	"King": preload("res://scenes/shadow_king.tscn")
}


func configure_level(config: LevelConfig) -> void:
	level_config = config.duplicate_with_waves()
	level_config.setup()
	level_complete = false
	current_wave_index = -1
	waves = level_config.wave_resources
	
	# Automatic populate if no wave list is available
	if waves.is_empty() and not level_config.is_infinite():
		for wave_number in range(1, level_config.wave_count + 1):
			waves.append(_create_generated_wave(wave_number))
			
	for wave in waves:
		wave.configure_wave(
			level_config.get_wave_duration(), 
			level_config.get_spawn_interval())
		level_config.increase_wave_duration()
		level_config.decrease_spawn_interval()


func setup(
	game_reference: Node,
	board_reference: Node,
	wave_benner_reference: Node
	) -> void:
	if waves.is_empty() and (level_config == null or not level_config.is_infinite()):
		push_error("WaveManager has no waves configured.")
		return

	game = game_reference
	board = board_reference
	wave_banner = wave_benner_reference
	game.enemy_changed.connect(notify_enemy_count_changed)
	var starting_wave := debug_start_wave

	if starting_wave < 1:
		starting_wave = 1

	# Only clamp against the wave list when one exists: infinite
	# levels (Final Stand) begin with no pre-built waves and grow
	# on demand, so clamping to waves.size() here would zero the
	# start wave and no wave would ever begin.
	if waves.size() > 0:
		starting_wave = min(starting_wave, waves.size())

	current_wave_index = starting_wave - 2

	if start_automatically:
		start_new_wave()
		
func start_new_wave() -> void:
	if level_complete:
		return

	current_wave_index += 1
	if level_config != null and level_config.is_infinite() and current_wave_index >= waves.size():
		waves.append(_create_generated_wave(current_wave_index + 1))
	
	if (current_wave_index < 0
		or current_wave_index >= waves.size()):
		spawning = false
		waiting_for_clear = false
		level_complete = true
		level_completed.emit()
		return
	
	spawning = true
	waiting_for_clear = false

	spawn_timer = 0.0
	wave_timer = 0.0
	total_timer = 0.0
	
	wave_started.emit()
	show_wave_banner(get_wave_number())
	GameLogger.log_wave_start(get_wave_number())


func get_waves_survived() -> int:
	if level_config == null or not level_config.is_infinite():
		return 0
	return max(0, current_wave_index)

func get_wave_number() -> int:
	if current_wave_index < 0:
		return 0
		
	return current_wave_index + 1

func _create_generated_wave(wave_number: int) -> WaveConfig:
	var wave := WaveConfig.new()
	var spawn_interval = max(
		level_config.minimum_spawn_interval,
		level_config.base_spawn_interval
		- level_config.spawn_interval_reduction_per_wave * (wave_number - 1)
	)
	wave.configure_wave(
		level_config.wave_duration,
		spawn_interval,
		level_config.allowed_enemy_pieces
	)
	return wave
	
func _process(delta: float) -> void:
	if game.game_over:
		return 
		
	total_timer += delta
		
	if not spawning:
		return

	var wave := get_current_wave()

	if wave == null:
		return

	wave_timer += delta
	spawn_timer += delta

	if spawn_timer >= wave.spawn_interval:
		spawn_timer -= wave.spawn_interval
		spawn_random_enemy()

	if wave_timer >= wave.duration:
		spawning = false
		waiting_for_clear = true

		#wave_spawning_finished.emit(current_wave_index + 1)
		
func get_current_wave() -> WaveConfig:
	if current_wave_index >= waves.size():
		return null
		
	return waves[current_wave_index]
	

func spawn_random_enemy() -> void:
	var wave := get_current_wave()

	if wave == null:
		return

	var available = wave.get_available_enemy_types()

	if available.is_empty():
		return

	var type: String = available.pick_random()
	var scene: PackedScene = ENEMY_SCENES[type]
	var enemy: BaseEnemy = scene.instantiate()

	game.enemies.add_child(enemy)

	var spawn_cell := get_spawn_cell(type)

	enemy.setup(game, spawn_cell)
	GameLogger.log_enemy_spawned("Shadow"+type, get_wave_number())
	BestiaryManager.mark_encountered(type)
	
func get_spawn_cell(enemy_type: String) -> Vector2i:

	if enemy_type == "Bishop":
		return board.get_random_edge_cell_same_color(
			game.king.current_cell
		)

	return board.get_random_edge_cell()

func notify_enemy_count_changed() -> void:
	if not waiting_for_clear:
		return

	if game.enemies.get_child_count() > 0:
		return

	waiting_for_clear = false
	GameLogger.log_wave_end(get_wave_number(), total_timer)
	start_new_wave()
	

func show_wave_banner(wave_number: int) -> void:
	wave_banner.text = (
		"WAVE %d"
		% wave_number
	)

	wave_banner.visible = true
	wave_banner.modulate.a = 0.0
	wave_banner.scale = Vector2(0.8, 0.8)

	var tween := create_tween()

	tween.set_parallel(true)

	tween.tween_property(
		wave_banner,
		"modulate:a",
		1.0,
		0.25
	)

	tween.tween_property(
		wave_banner,
		"scale",
		Vector2.ONE,
		0.25
	)

	tween.set_parallel(false)

	tween.tween_interval(1.5)

	tween.tween_property(
		wave_banner,
		"modulate:a",
		0.0,
		0.35
	)

	tween.tween_callback(
		func():
			wave_banner.visible = false
			#start_new_wave()
	)

func _unhandled_input(event: InputEvent) -> void:
	if not debug_mode:
		return

	if not event is InputEventKey:
		return

	if not event.pressed or event.echo:
		return

	match event.keycode:
		KEY_Z:
			debug_previous_wave()

		KEY_X:
			debug_next_wave()

		KEY_C:
			debug_restart_wave()

func debug_previous_wave() -> void:
	if current_wave_index <= 0:
		return

	current_wave_index -= 1
	clear_current_enemies()
	show_debug_wave()


func debug_next_wave() -> void:
	if current_wave_index >= waves.size() - 1:
		return

	current_wave_index += 1
	clear_current_enemies()
	show_debug_wave()


func debug_restart_wave() -> void:
	clear_current_enemies()
	show_debug_wave()
	
func show_debug_wave() -> void:
	spawning = false
	waiting_for_clear = false

	show_wave_banner(current_wave_index + 1)

func clear_current_enemies() -> void:
	for enemy in game.enemies.get_children():
		enemy.queue_free()
