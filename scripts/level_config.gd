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

## Growth continuation for infinite levels (Final Stand task, Option
## B): past the authored wave table, the spawn-interval slope keeps
## running down to this floor instead of the regular one. -1.0
## (default) = no extension, so finite levels are unaffected. For an
## infinite level without a wave table the extension applies from
## wave 1. Config-exposed on purpose — never hard-coded per level.
@export var extended_minimum_spawn_interval := -1.0

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


# ============================================================
# PURE CURVE FUNCTIONS (Final Stand task, Stage 1)
#
# A wave's parameters as a direct function of its (1-based) wave
# number, independent of any running state. These reproduce exactly
# what the stateful stepping in WaveManager.configure_level()
# produces for finite levels (verified by
# tests/curve_equivalence_check.gd) and are what on-demand wave
# generation for infinite levels uses — starting at any wave
# number yields that wave's true parameters.
#
# Named *_for_wave to avoid colliding with the stateful getters
# above (get_wave_duration/get_spawn_interval return the running
# curve state used by configure_level's stepping loop).
# ============================================================

func duration_for_wave(n: int) -> float:
	return minf(
		base_wave_duration + wave_duration_increment * float(n - 1),
		maximum_wave_duration
	)

func spawn_interval_for_wave(n: int) -> float:
	var floor_value := minimum_spawn_interval

	# Option B growth continuation: past the authored wave table,
	# an infinite level with an extended floor keeps the same slope
	# running down to the extended value. The extension can only
	# lower the floor.
	if (
		extended_minimum_spawn_interval >= 0.0
		and is_infinite()
		and n > wave_resources.size()
	):
		floor_value = minf(floor_value, extended_minimum_spawn_interval)

	return maxf(
		base_spawn_interval - spawn_interval_reduction * float(n - 1),
		floor_value
	)

## The authored roster table entry for waves it covers; beyond it,
## the trend's own continuation (the last entry — the mix is
## already maximal in Level 5's table). Falls back to the allowed
## roster when a level has no authored wave table.
func roster_for_wave(n: int) -> Array[String]:
	var result: Array[String] = []

	if wave_resources.size() > 0:
		var index := clampi(n, 1, wave_resources.size()) - 1
		result.append_array(
			wave_resources[index].get_available_enemy_types()
		)
	else:
		result.append_array(allowed_enemy_pieces)

	return result


func duplicate_with_waves() -> LevelConfig:
	var copy: LevelConfig = self.duplicate(true) as LevelConfig
	copy.wave_resources = []

	for wave in wave_resources:
		if wave != null:
			copy.wave_resources.append(wave.duplicate(true) as WaveConfig)

	return copy 
