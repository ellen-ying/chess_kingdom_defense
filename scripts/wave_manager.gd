class_name WaveManager
extends Node

signal level_completed
signal wave_started

@export_category("Wave Configuration")

@export var waves: Array[WaveConfig] = []

@export_category("Debug")

@export var debug_mode: bool = false
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


## Debug-only test affordance (Final Stand task, Stage 5): a
## `--start-wave=N` command-line user arg (after `--`) overrides the
## exported debug_start_wave for this session. Unlike the export, it
## has NO 100 cap — any wave of an infinite level (e.g. 500) can be
## jumped to for verification, because waves are a pure function of
## their number (Stage 1). Parsed inside setup(), i.e. before the
## first start_new_wave(), so there is no race with main._ready().
## Never surfaced in normal UI; the `=` form matches AutoplayBot's
## argument style.
func _parse_start_wave_arg() -> int:
	for token in OS.get_cmdline_user_args():
		if token.begins_with("--start-wave="):
			var value := token.substr("--start-wave=".length())
			if value.is_valid_int():
				return value.to_int()
			push_warning(
				"WaveManager: --start-wave needs an integer; ignoring."
			)
	return debug_start_wave


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
	var starting_wave := _parse_start_wave_arg()

	if starting_wave < 1:
		starting_wave = 1

	# Clamp to the authored wave list for FINITE levels (as before).
	# Infinite levels (Final Stand) never clamp: waves beyond the
	# authored table are generated on demand with that wave number's
	# true parameters, so --start-wave 500 genuinely starts wave 500.
	if (
		level_config == null or not level_config.is_infinite()
	) and waves.size() > 0:
		starting_wave = min(starting_wave, waves.size())

	current_wave_index = starting_wave - 2

	if start_automatically:
		start_new_wave()
		
func start_new_wave() -> void:
	if level_complete:
		return

	current_wave_index += 1
	if level_config != null and level_config.is_infinite() and current_wave_index >= waves.size():
		# A jump start (debug --start-wave=N with N far beyond the
		# authored table) must not "complete" the level: appending a
		# single wave would still leave current_wave_index >=
		# waves.size(), and the bounds check below would end the run
		# instantly with a phantom result. Fill the gap so the new
		# wave lands at its true index; gap entries are past waves
		# (indices below current_wave_index) and are never started.
		# They share one config instance: nothing ever reads them.
		var generated_wave := _create_generated_wave(current_wave_index + 1)
		while waves.size() <= current_wave_index:
			waves.append(generated_wave)
	
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
	show_wave_banner(get_current_wave_number())
	GameLogger.log_wave_start(get_current_wave_number())


func get_waves_survived() -> int:
	if level_config == null or not level_config.is_infinite():
		return 0
	return max(0, current_wave_index)

func get_current_wave_number() -> int:
	if current_wave_index < 0:
		return 0
		
	return current_wave_index + 1
	
func get_total_wave_number() -> int:
	# Infinite levels have no total. Return the sentinel -1 (not the
	# current list size, which keeps growing) so callers never treat
	# a growing wave list as a denominator.
	if level_config != null and level_config.is_infinite():
		return -1

	if waves == null:
		return 0

	return waves.size()

func _create_generated_wave(wave_number: int) -> WaveConfig:
	# A wave's parameters are a pure function of its (1-based) wave
	# number. This makes on-demand generation independent of any
	# running state: starting an infinite level at ANY wave (a debug
	# start wave, a future resumed run) yields that wave's true
	# parameters, and generated waves are exactly what the pre-built
	# stepping produces (proven by tests/curve_equivalence_check.gd).
	var wave := WaveConfig.new()
	wave.configure_wave(
		level_config.duration_for_wave(wave_number),
		level_config.spawn_interval_for_wave(wave_number),
		level_config.roster_for_wave(wave_number)
	)
	return wave
func _process(delta: float) -> void:
	if game.game_over:
		return 
		
	total_timer += delta
		
	if not spawning:
		# Safety poll: wave completion must not depend solely on the
		# enemy_changed signal. If the last enemy died before the wave
		# duration expired, no signal would ever fire again and the
		# wave (and the whole level) would stall forever.
		_try_end_cleared_wave()
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
	GameLogger.log_enemy_spawned("Shadow"+type, get_current_wave_number())
	BestiaryManager.mark_encountered(type)
	
func get_spawn_cell(enemy_type: String) -> Vector2i:

	if enemy_type == "Bishop":
		return board.get_random_edge_cell_same_color(
			game.king.current_cell
		)

	return board.get_random_edge_cell()

func notify_enemy_count_changed() -> void:
	_try_end_cleared_wave()


func _try_end_cleared_wave() -> void:
	if not waiting_for_clear:
		return

	if game.enemies.get_child_count() > 0:
		return

	waiting_for_clear = false
	GameLogger.log_wave_end(get_current_wave_number(), total_timer)
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
