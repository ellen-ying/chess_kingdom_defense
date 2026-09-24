extends BaseEnemy

const QUEEN_DIRECTIONS := [
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(0, 1),

	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1)
]

var current_direction: Vector2i

func setup(game_reference: Node, cell: Vector2i) -> void:
	type = "ShadowQueen"
	game = game_reference
	current_cell = cell
	global_position = game.board.cell_to_world(cell)

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


func move_toward_king() -> void:
	var king_cell: Vector2i = game.king.current_cell

	if current_cell == king_cell:
		game.enemy_reached_king(self)
		return

	choose_next_direction()

	if current_direction == Vector2i.ZERO:
		return

	var destination := current_cell + current_direction

	if not game.board.is_valid_cell(destination):
		# Safety fallback if the direction somehow became invalid.
		choose_next_direction()
		destination = current_cell + current_direction

	if not game.board.is_valid_cell(destination):
		return

	current_cell = destination
	global_position = game.board.cell_to_world(current_cell)

	if current_cell == king_cell:
		game.enemy_reached_king(self)
		return

	queue_redraw()

func choose_next_direction() -> void:
	var directions := get_toward_king_directions()

	if directions.is_empty():
		current_direction = Vector2i.ZERO
		return

	# Current direction is no longer a valid direction toward
	# the King, so we must change.
	if current_direction not in directions:
		current_direction = directions.pick_random()
		return

	# 70% chance: keep going.
	if randf() < 0.7:
		return

	# 30% chance: switch direction.
	var different_directions := directions.filter(
		func(direction):
			return direction != current_direction
	)

	if not different_directions.is_empty():
		current_direction = different_directions.pick_random()

func get_toward_king_directions() -> Array[Vector2i]:
	var difference = game.king.current_cell - current_cell

	var directions: Array[Vector2i] = []

	for direction in QUEEN_DIRECTIONS:
		var moving_x_toward = (
			direction.x == 0
			or direction.x == sign(difference.x)
		)

		var moving_y_toward = (
			direction.y == 0
			or direction.y == sign(difference.y)
		)

		if not moving_x_toward:
			continue

		if not moving_y_toward:
			continue

		# If the Queen is already aligned on an axis,
		# don't choose a direction purely along that axis
		# in the wrong sense.
		if difference.x == 0 and direction.x != 0:
			continue

		if difference.y == 0 and direction.y != 0:
			continue

		directions.append(direction)

	return directions

func take_damage(amount: int, source_piece: String) -> void:
	hp -= amount

	if hp <= 0:
		var reward := CurrencyManager.get_piece_value("Queen")
		CurrencyManager.add_currency(reward)
		game.shop_ui.show_currency_reward(global_position, reward)
		
		game.enemy_destroyed(self, source_piece) 
		queue_free()

	queue_redraw()


func _draw() -> void:
	draw_circle(
		Vector2(2, 4),
		22.0,
		Color(0, 0, 0, 0.25)
	)

	# Crown
	var crown := PackedVector2Array([
		Vector2(-16, -4),
		Vector2(-13, -20),
		Vector2(-6, -10),
		Vector2(0, -24),
		Vector2(6, -10),
		Vector2(14, -20),
		Vector2(16, -4),
		Vector2(10, 5),
		Vector2(-10, 5)
	])

	draw_colored_polygon(
		crown,
		Color("#202020")
	)

	draw_polyline(
		crown + PackedVector2Array([crown[0]]),
		Color("#202020"),
		2.0
	)

	# Body
	draw_circle(
		Vector2(0, 10),
		8.0,
		Color("#202020")
	)

	draw_rect(
		Rect2(-12, 10, 24, 8),
		Color("#202020")
	)
	
	# HP indicator.
	for i in range(MAX_HP):
		var hp_color := Color("#C62828") if i < hp else Color("#444444")

		draw_rect(
			Rect2(
				-15 + i * 10,
				-29,
				7,
				4
			),
			hp_color
		)
