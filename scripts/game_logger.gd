extends Node

# ============================================================
# GameLogger
#
# Autoload singleton.
#
# This script ONLY observes the game.
# It should never modify gameplay state.
# ============================================================

# ------------------------------------------------------------
# CONFIGURATION
# ------------------------------------------------------------

const LOGGING_ENABLED = true

# How often buffered data is flushed to disk.
const FLUSH_INTERVAL_SECONDS := 3.0

# To avoid the buffer growing indefinitely if something unusual
# happens, flush when it reaches this many events as well.
const MAX_BUFFERED_EVENTS := 100

# ------------------------------------------------------------
# RUNTIME STATE
# ------------------------------------------------------------

var current_run_id: String = ""

var current_csv_path: String = ""
var current_jsonl_path: String = ""

var csv_file: FileAccess = null
var jsonl_file: FileAccess = null

var csv_buffer: Array[String] = []
var jsonl_buffer: Array[String] = []

var flush_timer: float = 0.0

# Used to give events a common reference point.
# This is elapsed time within the current run.
var run_started_at_msec: int = 0


# ------------------------------------------------------------
# CSV SCHEMA
# ------------------------------------------------------------

# CSV deliberately uses a fixed set of columns.
# Fields that don't apply to an event remain blank.
const CSV_COLUMNS := [
	"timestamp",
	"run_id",
	"event_type",

	"level_id",
	"outcome",

	"wave_number",
	"duration_seconds",
	"waves_survived",

	"enemy_type",
	"killed_by_piece_type",
	"time_alive_seconds",

	"lives_remaining",

	"piece_type",
	"cost",
	"material_remaining",

	"tile_col",
	"tile_row",

	"total_kills_by_this_piece",

	"amount",
	"source",

	"total_material_earned",
	"total_material_spent"
]

# ============================================================
# GODOT LIFECYCLE
# ============================================================

func _ready() -> void:
	# Read the setting ONCE.

	if not LOGGING_ENABLED:
		return

	# Make sure the directory exists.
	DirAccess.make_dir_recursive_absolute("user://logs")


func _process(delta: float) -> void:
	if not LOGGING_ENABLED:
		return

	flush_timer += delta

	if flush_timer >= FLUSH_INTERVAL_SECONDS:
		flush_timer = 0.0
		flush()


func _exit_tree() -> void:
	# Try to preserve anything still in memory when the game
	# closes.
	if LOGGING_ENABLED:
		flush()
		_close_files()
		

# ============================================================
# RUN MANAGEMENT
# ============================================================

func start_run(level_id: String) -> String:
	if not LOGGING_ENABLED:
		return ""

	# If somehow another run is still open, close it first.
	if current_run_id != "":
		flush()
		_close_files()

	current_run_id = _generate_run_id()
	run_started_at_msec = Time.get_ticks_msec()

	var timestamp := Time.get_datetime_string_from_system(
		false,
		true
	)

	# Example: 2026-09-21_143022
	var file_timestamp := timestamp.replace(":", "").replace("-", "")

	current_csv_path = (
		"user://logs/run_%s_%s.csv"
		% [file_timestamp, current_run_id]
	)

	current_jsonl_path = (
		"user://logs/run_%s_%s.jsonl"
		% [file_timestamp, current_run_id]
	)

	csv_file = FileAccess.open(current_csv_path, FileAccess.WRITE)
	jsonl_file = FileAccess.open(current_jsonl_path, FileAccess.WRITE)

	if csv_file == null:
		push_error(
			"GameLogger: Could not open CSV log: "
			+ current_csv_path
		)

	if jsonl_file == null:
		push_error(
			"GameLogger: Could not open JSONL log: "
			+ current_jsonl_path
		)

	# Write CSV header.
	if csv_file != null:
		csv_file.store_line(
			",".join(CSV_COLUMNS)
		)

	_log_event(
		"run_start",
		{
			"level_id": level_id
		}
	)

	return current_run_id


func end_run(
	outcome: String,
	waves_survived: int,
	total_material_earned: int,
	total_material_spent: int
) -> void:

	if not LOGGING_ENABLED:
		return

	_log_event(
		"run_end",
		{
			"outcome": outcome,
			"waves_survived": waves_survived,
			"total_material_earned": total_material_earned,
			"total_material_spent": total_material_spent
		}
	)

	# Run end is a natural point to force everything to disk.
	flush()
	_close_files()

	current_run_id = ""
	current_csv_path = ""
	current_jsonl_path = ""
	
	
# ============================================================
# EVENT API
# ============================================================

func log_wave_start(wave_number: int) -> void:
	_log_event(
		"wave_start",
		{
			"wave_number": wave_number
		}
	)


func log_wave_end(
	wave_number: int,
	duration_seconds: float
) -> void:

	_log_event(
		"wave_end",
		{
			"wave_number": wave_number,
			"duration_seconds": duration_seconds
		}
	)


func log_enemy_spawned(
	enemy_type: String,
	wave_number: int
) -> void:

	_log_event(
		"enemy_spawned",
		{
			"enemy_type": enemy_type,
			"wave_number": wave_number
		}
	)


func log_enemy_killed(
	enemy_type: String,
	killed_by_piece_type: String,
	wave_number: int,
	time_alive_seconds: float
) -> void:

	_log_event(
		"enemy_killed",
		{
			"enemy_type": enemy_type,
			"killed_by_piece_type": killed_by_piece_type,
			"wave_number": wave_number,
			"time_alive_seconds": time_alive_seconds
		}
	)


func log_enemy_reached_king(
	enemy_type: String,
	wave_number: int
) -> void:

	_log_event(
		"enemy_reached_king",
		{
			"enemy_type": enemy_type,
			"wave_number": wave_number
		}
	)


func log_king_life_lost(
	lives_remaining: int,
	wave_number: int
) -> void:

	_log_event(
		"king_life_lost",
		{
			"lives_remaining": lives_remaining,
			"wave_number": wave_number
		}
	)


func log_piece_purchased(
	piece_type: String,
	cost: int,
	material_remaining: int
) -> void:

	_log_event(
		"piece_purchased",
		{
			"piece_type": piece_type,
			"cost": cost,
			"material_remaining": material_remaining
		}
	)


func log_piece_placed(
	piece_type: String,
	tile_col: int,
	tile_row: int,
	wave_number: int
) -> void:

	_log_event(
		"piece_placed",
		{
			"piece_type": piece_type,
			"tile_col": tile_col,
			"tile_row": tile_row,
			"wave_number": wave_number
		}
	)


func log_piece_died(
	piece_type: String,
	time_alive_seconds: float,
	total_kills_by_this_piece: int
) -> void:

	_log_event(
		"piece_died",
		{
			"piece_type": piece_type,
			"time_alive_seconds": time_alive_seconds,
			"total_kills_by_this_piece": total_kills_by_this_piece
		}
	)


func log_material_earned(
	amount: int,
	source: String
) -> void:

	_log_event(
		"material_earned",
		{
			"amount": amount,
			"source": source
		}
	)


## Generic event hook for auxiliary systems (e.g. AutoplayBot). Fields
## appear fully in JSONL; only fields matching known CSV columns are
## also written to CSV.
func log_bot_event(event_type: String, fields: Dictionary = {}) -> void:
	_log_event(event_type, fields)


# ============================================================
# GENERIC EVENT LOGGER
# ============================================================

func _log_event(
	event_type: String,
	fields: Dictionary
) -> void:

	if not LOGGING_ENABLED:
		return

	# No run = no gameplay event.
	# This prevents accidental logging of things happening in
	# menus or between levels.
	if current_run_id == "":
		return

	var timestamp := Time.get_datetime_string_from_system(
		true,
		true
	)

	# --------------------------------------------------------
	# JSONL
	# --------------------------------------------------------

	var json_event := {
		"timestamp": timestamp,
		"run_id": current_run_id,
		"event_type": event_type,
		"data": fields.duplicate(true)
	}

	jsonl_buffer.append(JSON.stringify(json_event))

	# --------------------------------------------------------
	# CSV
	# --------------------------------------------------------

	var csv_values: Array[String] = []

	for column in CSV_COLUMNS:
		match column:
			"timestamp":
				csv_values.append(_csv_escape(timestamp))

			"run_id":
				csv_values.append(_csv_escape(current_run_id))

			"event_type":
				csv_values.append(_csv_escape(event_type))

			_:
				if fields.has(column):
					csv_values.append(
						_csv_escape(str(fields[column]))
					)
				else:
					csv_values.append("")

	csv_buffer.append(
		",".join(csv_values)
	)

	# --------------------------------------------------------
	# Automatic flush threshold
	# --------------------------------------------------------

	if csv_buffer.size() >= MAX_BUFFERED_EVENTS:
		flush()
		
		
	# ============================================================
# FILE FLUSHING
# ============================================================

func flush() -> void:
	if not LOGGING_ENABLED:
		return

	if csv_file != null:
		for line in csv_buffer:
			csv_file.store_line(line)

		csv_file.flush()

	if jsonl_file != null:
		for line in jsonl_buffer:
			jsonl_file.store_line(line)

		jsonl_file.flush()

	csv_buffer.clear()
	jsonl_buffer.clear()
	
# ============================================================
# FILE MANAGEMENT
# ============================================================

func _close_files() -> void:
	if csv_file != null:
		csv_file.close()
		csv_file = null

	if jsonl_file != null:
		jsonl_file.close()
		jsonl_file = null


# ============================================================
# HELPERS
# ============================================================

func _generate_run_id() -> String:
	# Timestamp-based ID is sufficient for your use case.
	#
	# Example:
	# 20260921_165012_384
	#
	# If you want true UUIDs later, this can be replaced.
	var now := Time.get_datetime_dict_from_system()

	var milliseconds := Time.get_ticks_msec() % 1000

	return "%04d%02d%02d_%02d%02d%02d_%03d" % [
		now.year,
		now.month,
		now.day,
		now.hour,
		now.minute,
		now.second,
		milliseconds
	]


func _csv_escape(value: String) -> String:
	# Standard CSV escaping:
	# - quote values containing comma, quote, or newline
	# - double embedded quotes

	if (
		value.contains(",")
		or value.contains("\"")
		or value.contains("\n")
	):
		return "\"" + value.replace("\"", "\"\"") + "\""

	return value
