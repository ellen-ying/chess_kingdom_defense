extends SceneTree

## Stage 1 equivalence check for the Final Stand task
## (tasks/final-stand-tasks.md).
##
## Proves that LevelConfig's pure *_for_wave(n) functions reproduce
## exactly what the stateful stepping in WaveManager.configure_level()
## produces for every wave of every finite level — the safety net
## that guarantees Levels 1–5's behavior is untouched when wave
## generation switches to the pure functions.
##
## Run:
##   godot --headless --path . -s res://tests/curve_equivalence_check.gd
##
## Prints one WAVE-EQUIV line per level plus a summary; exits non-zero
## on any mismatch (duration, spawn interval, or roster).

const LEVEL_IDS := [
	"level_1",
	"level_2",
	"level_3",
	"level_4",
	"level_5"
]


func _initialize() -> void:
	var failures := 0
	var checked := 0

	var wave_manager_script = load("res://scripts/wave_manager.gd")
	var wave_manager = wave_manager_script.new()

	for level_id in LEVEL_IDS:
		var config: LevelConfig = load(
			"res://resources/levels/%s.tres" % level_id
		)

		# The exact production path: duplicate + step every wave.
		wave_manager.configure_level(config)

		var level_failures := 0

		for i in wave_manager.waves.size():
			var n: int = i + 1
			var wave: WaveConfig = wave_manager.waves[i]
			var curve: LevelConfig = wave_manager.level_config

			var duration_ok := is_equal_approx(
				wave.duration, curve.duration_for_wave(n)
			)
			var interval_ok := is_equal_approx(
				wave.spawn_interval, curve.spawn_interval_for_wave(n)
			)
			var roster_actual: Array[String] = (
				wave.get_available_enemy_types()
			)
			var roster_pure: Array[String] = curve.roster_for_wave(n)
			var roster_ok := roster_actual == roster_pure

			checked += 1

			if not (duration_ok and interval_ok and roster_ok):
				level_failures += 1
				print(
					"FAIL %s wave %d: duration %s vs %s | interval %s vs %s | roster %s vs %s"
					% [
						level_id, n,
						str(wave.duration),
						str(curve.duration_for_wave(n)),
						str(wave.spawn_interval),
						str(curve.spawn_interval_for_wave(n)),
						str(roster_actual),
						str(roster_pure)
					]
				)

		failures += level_failures

		print(
			"WAVE-EQUIV %s: %d waves, %s"
			% [
				level_id,
				wave_manager.waves.size(),
				"OK" if level_failures == 0 else "FAIL x%d" % level_failures
			]
		)

	print(
		"WAVE-EQUIV summary: %d waves checked across %d levels, %d failures"
		% [checked, LEVEL_IDS.size(), failures]
	)

	quit(1 if failures > 0 else 0)
