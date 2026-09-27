extends Node

# ============================================================
# AutoplayBot
#
# Autoload singleton. DORMANT by default.
#
# Drives headless auto-play sessions for gameplay-data
# generation: a bot buys and places pieces through the SAME
# code paths a human's UI interaction reaches
# (ShopUI.begin_tray_pointer + PlacementController.place_piece).
# It never mutates gameplay state directly and never acts
# during normal play.
#
# Activation gate (plan Q6): recognized auto-play CLI args AND
# a headless display server are BOTH required, so a stray flag
# can never hijack a real play session.
#
# Launch pattern (args after `--` via OS.get_cmdline_user_args):
#
#   godot --headless --path <project_dir> -- \
#       --strategy=cheapest_first --level=level_1 --runs=50
# ============================================================

const MAIN_SCRIPT_PATH := "res://scripts/main.gd"

const STRATEGIES := [
	"cheapest_first",
	"balanced",
	"rush_strongest",
	"random"
]

const PIECE_TYPES := ["Pawn", "Knight", "Bishop", "Rook", "Queen"]

# rush_strongest always saves for the most expensive piece.
const STRONGEST := "Queen"

# Sentinel meaning "no legal cell", matching PlacementController.
const INVALID_CELL := Vector2i(-999, -999)

# A stuck decision tick logs bot_idle once per idle streak and
# then again every IDLE_RELOG_INTERVAL ticks (~10 s at the
# default 0.5 s cadence), so a stuck run is visible without
# flooding the log.
const IDLE_RELOG_INTERVAL := 20

# ------------------------------------------------------------

# Default time-scale is 16.0 (plan Q7): auto-play runs faster
# than real time by default; decision cadence stays 0.5
# GAME seconds so bot behaviour remains human-paced in
# game-time terms.
const DEFAULTS := {
	"strategy": "balanced",
	"level": "level_1",
	"runs": 1,
	"decision-interval": 0.5,
	"timeout-seconds": 600.0,
	"final-stand-cap": 30,
	"rush-gap": 3,
	"seed": -1,
	"time-scale": 16.0,
}

# Value type of each recognized --key=value argument.
const ARG_SPEC := {
	"strategy": TYPE_STRING,
	"level": TYPE_STRING,
	"runs": TYPE_INT,
	"decision-interval": TYPE_FLOAT,
	"timeout-seconds": TYPE_FLOAT,
	"final-stand-cap": TYPE_INT,
	"rush-gap": TYPE_INT,
	"seed": TYPE_INT,
	"time-scale": TYPE_FLOAT,
}

# ------------------------------------------------------------

var active := false
var config := {}

# The currently bound gameplay scene (main.gd), or null.
var game: Node = null

# Bare script instances used only for the pure geometric query
# get_attack_tiles_for_cell(); never added to the scene tree.
var _prototypes := {}

var _decision_timer := 0.0
var _idle_ticks := 0
var _run_index := 0
var _run_started_msec := 0
var _run_scene_seen := false
var _scene_left_gameplay := false
var _run_forced_end_done := false
var _run_result_printed := false
var _last_heuristic := ""


# ============================================================
# LIFECYCLE
# ============================================================

func _ready() -> void:
	var parsed := _parse_args(OS.get_cmdline_user_args())

	if parsed.is_empty():
		# No auto-play arguments → dormant forever.
		set_process(false)
		return

	if DisplayServer.get_name() != "headless":
		# Arguments present but not running headless → stay
		# dormant (activation gate, plan Q6).
		push_warning(
			"AutoplayBot: auto-play arguments ignored because the display server is not headless."
		)
		set_process(false)
		return

	active = true
	config = parsed

	if int(config["seed"]) >= 0:
		seed(int(config["seed"]))

	Engine.time_scale = float(config["time-scale"])

	_make_prototypes()

	print(
		"AutoplayBot: starting batch — strategy=%s level=%s runs=%d seed=%d time_scale=%s"
		% [
			config["strategy"],
			config["level"],
			int(config["runs"]),
			int(config["seed"]),
			str(config["time-scale"])
		]
	)

	# Let the title scene load first, then take over.
	_start_batch.call_deferred()


func _exit_tree() -> void:
	for prototype in _prototypes.values():
		prototype.free()

	_prototypes.clear()


func _make_prototypes() -> void:
	_prototypes = {
		"Pawn": preload("res://scripts/pawn.gd").new(),
		"Knight": preload("res://scripts/knight.gd").new(),
		"Bishop": preload("res://scripts/bishop.gd").new(),
		"Rook": preload("res://scripts/rook.gd").new(),
		"Queen": preload("res://scripts/queen.gd").new(),
	}


# ============================================================
# PER-FRAME DRIVER
# ============================================================

func _process(delta: float) -> void:
	if not active:
		return

	_update_session_binding()

	if game == null:
		return

	if game.game_over:
		if not _run_result_printed:
			_run_result_printed = true
			print(
				"AutoplayBot: run %d/%d finished — outcome=%s waves_survived=%d"
				% [
					_run_index,
					int(config["runs"]),
					str(game.outcome),
					int(game.waves_survived)
				]
			)
		return

	# Safety checks run every frame, not just on decision ticks.
	_check_final_stand_cap()
	_check_run_timeout()

	if game == null or game.game_over:
		return

	# Human-cadence decision making: not every frame.
	_decision_timer += delta

	if _decision_timer >= float(config["decision-interval"]):
		_decision_timer = 0.0
		_act()


func _update_session_binding() -> void:
	if game != null and not is_instance_valid(game):
		# The bound gameplay scene was freed (run finished).
		game = null
		_run_scene_seen = false
		_scene_left_gameplay = true
		return

	var scene := get_tree().current_scene

	if scene == null:
		return

	var is_gameplay: bool = (
		scene.get_script() != null
		and scene.get_script().resource_path == MAIN_SCRIPT_PATH
	)

	if is_gameplay:
		if game != scene:
			game = scene
			_run_scene_seen = true
			_on_run_scene_bound()
	elif _run_scene_seen:
		# The gameplay scene was replaced — the run ended via
		# main._finish_run → SceneRouter.go_home_office().
		game = null
		_run_scene_seen = false
		_scene_left_gameplay = true


func _on_run_scene_bound() -> void:
	_run_started_msec = Time.get_ticks_msec()
	_decision_timer = 0.0
	_idle_ticks = 0
	_run_forced_end_done = false
	_run_result_printed = false

	# The run result must be captured before the gameplay scene is
	# freed; the scene swap happens between bot frames, so
	# _process alone may never observe game_over.
	game.tree_exiting.connect(_on_run_scene_exiting)

	print(
		"AutoplayBot: run %d/%d started — level=%s"
		% [_run_index, int(config["runs"]), config["level"]]
	)

	# Records the run's configuration (incl. seed, plan Q7) in
	# the same per-run log files the gameplay events go to.
	GameLogger.log_bot_event(
		"bot_run_config",
		{
			"strategy": config["strategy"],
			"level_id": config["level"],
			"run_index": _run_index,
			"seed": int(config["seed"]),
			"time_scale": float(config["time-scale"]),
			"decision_interval_seconds": float(config["decision-interval"]),
			"timeout_seconds": float(config["timeout-seconds"]),
			"final_stand_cap": int(config["final-stand-cap"])
		}
	)


func _on_run_scene_exiting() -> void:
	# Fires while the gameplay scene is still valid (before
	# removal), guaranteeing the run result is readable.
	if not is_instance_valid(game) or not game.game_over:
		return

	if _run_result_printed:
		return

	_run_result_printed = true

	print(
		"AutoplayBot: run %d/%d finished — outcome=%s waves_survived=%d"
		% [
			_run_index,
			int(config["runs"]),
			str(game.outcome),
			int(game.waves_survived)
		]
	)


# ============================================================
# SAFETY: FINAL STAND WAVE CAP + HARD PER-RUN TIMEOUT
# ============================================================

func _check_final_stand_cap() -> void:
	if _run_forced_end_done:
		return

	if config["level"] != "final_stand":
		return

	if game.wave_manager.get_wave_number() < int(config["final-stand-cap"]):
		return

	_run_forced_end_done = true

	GameLogger.log_bot_event(
		"bot_run_capped",
		{
			"wave_number": game.wave_manager.get_wave_number()
		}
	)

	# A capped run is logged as WIN and distinguished from a
	# natural win by the bot_run_capped event (plan Q4).
	game.end_run_with_result("WIN")


func _check_run_timeout() -> void:
	if _run_forced_end_done:
		return

	var elapsed_seconds := (
		Time.get_ticks_msec() - _run_started_msec
	) / 1000.0

	if elapsed_seconds <= float(config["timeout-seconds"]):
		return

	_run_forced_end_done = true

	GameLogger.log_bot_event(
		"run_timeout",
		{
			"seconds": float(config["timeout-seconds"]),
			"wave_number": game.wave_manager.get_wave_number(),
			"material_remaining": CurrencyManager.current_amount
		}
	)

	# TIMEOUT is a label the natural end_run path never produces
	# (plan Q4).
	game.end_run_with_result("TIMEOUT")


# ============================================================
# ONE DECISION TICK
# ============================================================

func _act() -> void:
	var piece_type := _choose_piece_to_buy()

	if piece_type == "":
		_handle_idle()
		return

	var cell := _choose_cell(piece_type)

	if cell == INVALID_CELL:
		_handle_idle()
		return

	# Same entry point a human's shop click reaches; silently
	# no-ops when the piece is unaffordable.
	game.shop_ui.begin_tray_pointer(piece_type)

	if game.placement_controller.active_piece_type != piece_type:
		# Selection never started (affordability gate).
		_handle_idle()
		return

	var count_before := InventoryManager.get_piece_count(piece_type)

	# The actual purchase: re-validates the cell, re-checks
	# affordability, spends, logs, spawns and updates inventory —
	# the same function a human drag-drop reaches.
	game.placement_controller.place_piece(cell)

	if InventoryManager.get_piece_count(piece_type) == count_before:
		# Placement was refused (invalid cell / currency race).
		_handle_idle()
		return

	_idle_ticks = 0

	GameLogger.log_bot_event(
		"bot_placed",
		{
			"strategy": config["strategy"],
			"piece_type": piece_type,
			"tile_col": cell.x,
			"tile_row": cell.y,
			"wave_number": game.wave_manager.get_wave_number(),
			"heuristic": _last_heuristic
		}
	)


func _handle_idle() -> void:
	_idle_ticks += 1

	if _idle_ticks == 1 or _idle_ticks % IDLE_RELOG_INTERVAL == 0:
		GameLogger.log_bot_event(
			"bot_idle",
			{
				"consecutive_idle_ticks": _idle_ticks,
				"material_remaining": CurrencyManager.current_amount,
				"pieces_on_board": game.piece_parent.get_child_count()
			}
		)


# ============================================================
# BUYING STRATEGIES
# ============================================================

func _choose_piece_to_buy() -> String:
	var affordable := _affordable_types()

	if affordable.is_empty():
		return ""

	match config["strategy"]:
		"cheapest_first":
			return _choose_cheapest_first(affordable)
		"balanced":
			return _choose_balanced(affordable)
		"rush_strongest":
			return _choose_rush_strongest()
		"random":
			return affordable.pick_random()

	return ""


func _affordable_types() -> Array[String]:
	var result: Array[String] = []

	for piece_type in PIECE_TYPES:
		if CurrencyManager.current_amount >= CurrencyManager.get_piece_value(piece_type):
			result.append(piece_type)

	return result


func _choose_cheapest_first(affordable: Array[String]) -> String:
	# Iterates in PIECE_TYPES order, so the Knight-before-Bishop
	# tie-break at cost 3 is fixed and runs stay comparable.
	var best := ""
	var best_cost := -1

	for piece_type in affordable:
		var cost := CurrencyManager.get_piece_value(piece_type)

		if best_cost == -1 or cost < best_cost:
			best_cost = cost
			best = piece_type

	return best


func _choose_balanced(affordable: Array[String]) -> String:
	# Lowest owned count; ties broken by lower cost, then by
	# PIECE_TYPES order (the input preserves it).
	var best := ""
	var best_count := -1
	var best_cost := 0

	for piece_type in affordable:
		var count := InventoryManager.get_piece_count(piece_type)
		var cost := CurrencyManager.get_piece_value(piece_type)

		if (
			best_count == -1
			or count < best_count
			or (count == best_count and cost < best_cost)
		):
			best = piece_type
			best_count = count
			best_cost = cost

	return best


func _choose_rush_strongest() -> String:
	# Hold Material for the Queen whenever she is close enough to
	# buy ("close enough" = within --rush-gap Material, default 3
	# ≈ two typical early kills, plan Q5); otherwise keep Material
	# working with the cheapest affordable filler.
	var gap := (
		CurrencyManager.get_piece_value(STRONGEST)
		- CurrencyManager.current_amount
	)

	if gap <= 0:
		return STRONGEST

	if gap <= int(config["rush-gap"]):
		return ""

	var fillers := _affordable_types()

	if fillers.is_empty():
		return ""

	fillers.sort_custom(
		func(a, b):
			return CurrencyManager.get_piece_value(a) < CurrencyManager.get_piece_value(b)
	)

	return fillers[0]


# ============================================================
# PLACEMENT HEURISTIC (line-aware)
# ============================================================

func _choose_cell(piece_type: String) -> Vector2i:
	var prototype: BasePiece = _prototypes.get(piece_type)

	if prototype == null:
		_last_heuristic = "none"
		return INVALID_CELL

	var board = game.board
	var king_cell: Vector2i = game.king.current_cell
	var threat := _compute_threat_map()

	var best_cell := INVALID_CELL
	var best_score := -INF
	var ties: Array[Vector2i] = []

	for x in range(board.COLUMNS):
		for y in range(board.ROWS):
			var cell := Vector2i(x, y)

			if not game.placement_controller.is_valid_placement_cell(cell):
				continue

			var score := 0.0

			if threat.is_empty():
				score = _score_coverage_fallback(
					prototype, cell, board, king_cell
				)
			else:
				score = _score_line_aware(
					prototype, cell, board, king_cell, threat
				)

			if score > best_score:
				best_score = score
				best_cell = cell
				ties.clear()
				ties.append(cell)
			elif is_equal_approx(score, best_score):
				ties.append(cell)

	if ties.is_empty():
		_last_heuristic = "none"
		return INVALID_CELL

	_last_heuristic = "coverage_fallback" if threat.is_empty() else "line_aware"

	# Random tie-break so runs don't always place everything on
	# one square.
	return ties.pick_random()


func _score_line_aware(
	prototype: BasePiece,
	cell: Vector2i,
	board: Node,
	king_cell: Vector2i,
	threat: Dictionary
) -> float:
	var score := 0.0

	# The piece's own attack geometry (diagonals for Bishop,
	# orthogonal rays for Rook, both for Queen) decides how much
	# live threat the candidate covers.
	for attack_tile in prototype.get_attack_tiles_for_cell(cell, board):
		score += float(threat.get(attack_tile, 0.0))

	# Slight preference to stand near the threat itself.
	score += 0.25 * float(threat.get(cell, 0.0))

	# Slight preference to stay near the King.
	score -= 0.05 * float(_chebyshev_distance(cell, king_cell))

	return score


func _score_coverage_fallback(
	prototype: BasePiece,
	cell: Vector2i,
	board: Node,
	king_cell: Vector2i
) -> float:
	# No live threats (between waves): prefer cells whose attack
	# pattern covers the King's immediate ring (Chebyshev 1–2),
	# with the same slight preference for staying near the King.
	var covered_near_king := 0

	for attack_tile in prototype.get_attack_tiles_for_cell(cell, board):
		var distance := _chebyshev_distance(attack_tile, king_cell)

		if distance >= 1 and distance <= 2:
				covered_near_king += 1

	return (
		float(covered_near_king)
		- 0.05 * float(_chebyshev_distance(cell, king_cell))
	)


func _compute_threat_map() -> Dictionary:
	var threat := {}
	var king_cell: Vector2i = game.king.current_cell

	for enemy in game.enemies.get_children():
		if not (enemy is BaseEnemy):
			continue

		var cell: Vector2i = enemy.current_cell

		# An enemy is standing on this cell right now.
		_add_threat(threat, cell, 3.0)

		# Walk the enemy's sign-step corridor toward the King,
		# mirroring the movement rule the enemy code uses.
		# Pawn axis-randomisation and Knight jumps are
		# approximated by straight corridors — acceptable for
		# threat sizing.
		var walker := cell

		while walker != king_cell:
			var step := Vector2i(
				sign(king_cell.x - walker.x),
				sign(king_cell.y - walker.y)
			)

			if step == Vector2i.ZERO:
				break

			walker += step

			if not game.board.is_valid_cell(walker):
				break

			_add_threat(threat, walker, 1.0)

	return threat


func _add_threat(threat: Dictionary, cell: Vector2i, weight: float) -> void:
	threat[cell] = float(threat.get(cell, 0.0)) + weight


func _chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


# ============================================================
# BATCH DRIVER (--runs=N in one process) + CLEAN EXIT
# ============================================================

func _start_batch() -> void:
	# Let the title scene finish loading first.
	await get_tree().process_frame

	for run_number in range(int(config["runs"])):
		_run_index = run_number + 1
		_scene_left_gameplay = false
		_run_scene_seen = false
		game = null

		# Re-entering the gameplay scene is a complete reset:
		# main._ready() resets currency/inventory and
		# GameLogger.start_run() opens a fresh run_id + files.
		SceneRouter.start_level(config["level"])

		var appeared := await _wait_for(
			func(): return game != null,
			30.0
		)

		if not appeared:
			push_warning(
				"AutoplayBot: run %d skipped — gameplay scene never appeared."
				% _run_index
			)
			continue

		# The run ends when main._finish_run() swaps to the Home
		# Office scene; the timeout path force-ends the run well
		# before this deadline expires.
		await _wait_for(
			func(): return _scene_left_gameplay,
			float(config["timeout-seconds"]) + 30.0
		)

	GameLogger.flush()

	print(
		"AutoplayBot: batch complete — %d run(s), strategy=%s, level=%s."
		% [int(config["runs"]), config["strategy"], config["level"]]
	)

	get_tree().quit()


func _wait_for(predicate: Callable, seconds: float) -> bool:
	var deadline_msec := Time.get_ticks_msec() + int(seconds * 1000.0)

	while Time.get_ticks_msec() < deadline_msec:
		if predicate.call():
			return true

		await get_tree().process_frame

	return predicate.call()


# ============================================================
# COMMAND-LINE ARGUMENT PARSING
# ============================================================

func _parse_args(args: PackedStringArray) -> Dictionary:
	var recognized_any := false
	var result := {}

	for token in args:
		if not token.begins_with("--"):
			continue

		var key := token.substr(2)
		var value := ""

		if "=" in key:
			var parts := key.split("=", true, 1)
			key = parts[0]
			value = parts[1]

		if not ARG_SPEC.has(key):
			push_warning("AutoplayBot: ignoring unknown argument --%s" % key)
			continue

		recognized_any = true
		var parsed_value = null

		match ARG_SPEC[key]:
			TYPE_STRING:
				if value == "":
					push_warning(
						"AutoplayBot: --%s needs a value; using default '%s'."
					% [key, str(DEFAULTS[key])]
					)
				else:
					parsed_value = value
			TYPE_INT:
				if value.is_valid_int():
					parsed_value = int(value)
				else:
					push_warning(
							"AutoplayBot: --%s needs an integer; using default %s."
						% [key, str(DEFAULTS[key])]
					)
			TYPE_FLOAT:
				if value.is_valid_float():
					parsed_value = float(value)
				else:
					push_warning(
							"AutoplayBot: --%s needs a number; using default %s."
						% [key, str(DEFAULTS[key])]
					)

		if parsed_value != null:
			result[key] = parsed_value

	if not recognized_any:
		# No auto-play keys at all → dormant.
		return {}

	for default_key in DEFAULTS.keys():
		if not result.has(default_key):
			result[default_key] = DEFAULTS[default_key]

	config = result
	_validate_config()

	return result


func _validate_config() -> void:
	if not (config["strategy"] in STRATEGIES):
		push_warning(
			"AutoplayBot: unknown strategy '%s'; using '%s'."
			% [config["strategy"], DEFAULTS["strategy"]]
		)
		config["strategy"] = DEFAULTS["strategy"]

	if not LevelProgressManager.LEVEL_CONFIGS.has(config["level"]):
		push_warning(
			"AutoplayBot: unknown level '%s'; using '%s'."
			% [config["level"], DEFAULTS["level"]]
		)
		config["level"] = DEFAULTS["level"]

	if int(config["runs"]) < 1:
		push_warning("AutoplayBot: --runs must be >= 1; using %s." % str(DEFAULTS["runs"]))
		config["runs"] = DEFAULTS["runs"]

	if float(config["decision-interval"]) <= 0.0:
		push_warning(
			"AutoplayBot: --decision-interval must be > 0; using %s."
			% str(DEFAULTS["decision-interval"])
		)
		config["decision-interval"] = DEFAULTS["decision-interval"]

	if float(config["timeout-seconds"]) <= 0.0:
		push_warning(
			"AutoplayBot: --timeout-seconds must be > 0; using %s."
			% str(DEFAULTS["timeout-seconds"])
		)
		config["timeout-seconds"] = DEFAULTS["timeout-seconds"]

	if int(config["final-stand-cap"]) < 1:
		push_warning(
			"AutoplayBot: --final-stand-cap must be >= 1; using %s."
			% str(DEFAULTS["final-stand-cap"])
		)
		config["final-stand-cap"] = DEFAULTS["final-stand-cap"]

	if int(config["rush-gap"]) < 0:
		push_warning("AutoplayBot: --rush-gap must be >= 0; using %s." % str(DEFAULTS["rush-gap"]))
		config["rush-gap"] = DEFAULTS["rush-gap"]

	if float(config["time-scale"]) <= 0.0 or float(config["time-scale"]) > 100.0:
		push_warning(
			"AutoplayBot: --time-scale must be within (0, 100]; using %s."
			% str(DEFAULTS["time-scale"])
		)
		config["time-scale"] = DEFAULTS["time-scale"]
