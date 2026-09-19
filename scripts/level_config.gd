class_name LevelConfig
extends Resource

## Editor-authored level data. This resource contains configuration only;
## WaveManager owns the runtime spawning behavior.

@export_category("Identity")
@export var level_id := ""
@export var display_name := ""

@export_category("Enemy Roster")
@export var allowed_enemy_pieces: Array[String] = []

@export_category("Wave Structure")
@export var wave_count := 5
@export var wave_resources: Array[WaveConfig] = []

@export_category("Difficulty Curve")
@export var wave_duration := 30.0
@export var base_spawn_interval := 4.0
@export var spawn_interval_reduction_per_wave := 0.25
@export var minimum_spawn_interval := 0.8


func is_infinite() -> bool:
	return wave_count == -1
