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
@export var base_wave_duration := 20.0
@export var wave_duration_increment := 10.0
@export var maximum_wave_duration := 100.0
@export var base_spawn_interval := 8.0
@export var spawn_interval_reduction := 1.0
@export var minimum_spawn_interval := 1.0

var wave_duration
var spawn_interval


func is_infinite() -> bool:
	return wave_count == -1
	
func setup():
	wave_duration = base_wave_duration
	spawn_interval = base_spawn_interval

func get_wave_duration() -> float:
	return wave_duration

func increase_wave_duration() -> void:
	wave_duration += wave_duration_increment
	wave_duration = min(wave_duration, maximum_wave_duration)

func get_spawn_interval() -> float:
	return spawn_interval
	
func decrease_spawn_interval() -> void:
	spawn_interval -= spawn_interval_reduction
	spawn_interval = max(spawn_interval, minimum_spawn_interval)

func duplicate_with_waves() -> LevelConfig:
	var copy: LevelConfig = self.duplicate(true) as LevelConfig
	copy.wave_resources = []

	for wave in wave_resources:
		if wave != null:
			copy.wave_resources.append(wave.duplicate(true) as WaveConfig)

	return copy 
