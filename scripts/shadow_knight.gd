extends BaseEnemy

# The normal chess knight movement vectors.
const KNIGHT_MOVES := [
	Vector2i(-1, -2),
	Vector2i(1, -2),
	Vector2i(-2, -1),
	Vector2i(2, -1),
	Vector2i(-2, 1),
	Vector2i(2, 1),
	Vector2i(-1, 2),
	Vector2i(1, 2)
]

# We use the squared value of sqrt(5) to avoid unnecessary sqrt operations.
const SPECIAL_DISTANCE_SQUARED := 5


func setup(game_reference: Node, cell: Vector2i) -> void:
	type = "ShadowKnight"
	max_hp = 3
	hp = max_hp
	game = game_reference
	current_cell = cell

	global_position = game.board.cell_to_world(current_cell)

	queue_redraw()


func _process(delta: float) -> void:
	if game == null or game.game_over:
		return
	update_status_effects(delta)

	move_timer += delta
	live_timer += delta

	if move_timer >= get_move_interval(MOVE_INTERVAL):
		move_timer = 0.0
		move_toward_king()
	
	take_piece_at_cell(game)

func move_toward_king() -> void:
	var king_cell: Vector2i = game.king.current_cell

	var difference: Vector2i = king_cell - current_cell

	if difference == Vector2i.ZERO:
		game.enemy_reached_king(self)
		return

	# --------------------------------------------------------
	# SPECIAL KNIGHT RULE
	#
	# If the king is at distance <= sqrt(5), then on this
	# movement tick the knight reaches the king immediately.
	#
	# This includes:
	#   (1,0), (0,1)
	#   (1,1)
	#   (2,0), (0,2)
	#   (2,1), (1,2)
	# --------------------------------------------------------

	var distance_squared := (
		difference.x * difference.x
		+ difference.y * difference.y
	)

	if distance_squared <= SPECIAL_DISTANCE_SQUARED:
		current_cell = king_cell
		global_position = game.board.cell_to_world(current_cell)

		game.enemy_reached_king(self)
		return

	# --------------------------------------------------------
	# NORMAL KNIGHT MOVEMENT
	# --------------------------------------------------------

	var best_destination := current_cell
	var best_distance_squared := INF

	for move in KNIGHT_MOVES:
		var candidate = current_cell + move

		if not game.board.is_valid_cell(candidate):
			continue

		var candidate_difference: Vector2i = king_cell - candidate

		var candidate_distance_squared := (
			candidate_difference.x * candidate_difference.x
			+ candidate_difference.y * candidate_difference.y
		)

		if candidate_distance_squared < best_distance_squared:
			best_distance_squared = candidate_distance_squared
			best_destination = candidate

	# It is theoretically possible that there is no valid move,
	# although on the current 17x9 board this should not occur.
	if best_destination == current_cell:
		return

	current_cell = best_destination
	global_position = game.board.cell_to_world(current_cell)

	queue_redraw()


func take_damage(amount: int, source_piece: String) -> void:
	hp -= amount

	if hp <= 0:
		var reward := CurrencyManager.get_piece_value("Knight")
		CurrencyManager.add_currency(reward)
		game.shop_ui.show_currency_reward(global_position, reward)
		
		game.enemy_destroyed(self, source_piece)
		queue_free()

	queue_redraw()


func _draw() -> void:
	# Shadow
	draw_circle(
		Vector2(2, 4),
		20.0,
		Color(0, 0, 0, 0.25)
	)

	# Knight silhouette
	var knight_shape := PackedVector2Array([
		Vector2(-14, 17),
		Vector2(-12, 7),
		Vector2(-8, 1),
		Vector2(-12, -7),
		Vector2(-9, -19),
		Vector2(-2, -24),
		Vector2(8, -17),
		Vector2(12, -8),
		Vector2(8, -1),
		Vector2(12, 7),
		Vector2(15, 17)
	])

	draw_colored_polygon(
		knight_shape,
		Color("#151515")
	)

	draw_polyline(
		PackedVector2Array([
			Vector2(-14, 17),
			Vector2(-12, 7),
			Vector2(-8, 1),
			Vector2(-12, -7),
			Vector2(-9, -19),
			Vector2(-2, -24),
			Vector2(8, -17),
			Vector2(12, -8),
			Vector2(8, -1),
			Vector2(12, 7),
			Vector2(15, 17),
			Vector2(-14, 17)
		]),
		Color("#666666"),
		2.0
	)

	# Eye
	draw_circle(
		Vector2(4, -13),
		2.0,
		Color("#FF3333")
	)

	# HP bar
	draw_hp()
