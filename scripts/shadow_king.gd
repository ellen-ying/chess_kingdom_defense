extends BaseEnemy

const KING_DIRECTIONS := [
	Vector2i(-1, -1),
	Vector2i(0, -1),
	Vector2i(1, -1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 1)
]

const LIFETIME := 3.0
var lifetime_timer := 0.0

func setup(game_reference: Node, cell: Vector2i) -> void:
	type = "ShadowKing"
	game = game_reference
	current_cell = cell

	global_position = game.board.cell_to_world(current_cell)

	queue_redraw()
	
func _process(delta: float) -> void:
	if game == null or game.game_over:
		return
	update_status_effects(delta)

	lifetime_timer += delta

	if lifetime_timer + delta >= LIFETIME:
		queue_free()
		return

	move_timer += delta

	if move_timer >= get_move_interval(MOVE_INTERVAL):
		move_timer = 0.0
		move_randomly()
	
func move_randomly() -> void:
	var legal_cells: Array[Vector2i] = []

	for direction in KING_DIRECTIONS:
		var candidate = current_cell + direction

		if game.board.is_valid_cell(candidate):
			legal_cells.append(candidate)

	if legal_cells.is_empty():
		return

	var destination = legal_cells.pick_random()

	current_cell = destination
	global_position = game.board.cell_to_world(current_cell)

	if current_cell == game.king.current_cell:
		game.enemy_reached_king(self)
		return

	queue_redraw()
	
func take_damage(amount: int, source_piece: String) -> void:
	if hp <= 0:
		return

	hp -= amount

	if hp <= 0:
		hp = 0
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

	# Body
	draw_circle(
		Vector2(0, 7),
		13.0,
		Color("#151515")
	)

	draw_rect(
		Rect2(-12, 6, 24, 12),
		Color("#151515")
	)

	# Crown
	var crown := PackedVector2Array([
		Vector2(-12, -4),
		Vector2(-10, -18),
		Vector2(-4, -11),
		Vector2(0, -21),
		Vector2(4, -11),
		Vector2(10, -18),
		Vector2(12, -4)
	])

	draw_colored_polygon(
		crown,
		Color("#151515")
	)

	draw_polyline(
		crown + PackedVector2Array([crown[0]]),
		Color("#666666"),
		2.0
	)

	# Cross
	draw_line(
		Vector2(0, -25),
		Vector2(0, -14),
		Color("#AA3333"),
		2.0
	)

	draw_line(
		Vector2(-5, -21),
		Vector2(5, -21),
		Color("#AA3333"),
		2.0
	)

	# Remaining lifetime indicator
	var remaining = clamp(
		1.0 - lifetime_timer / LIFETIME,
		0.0,
		1.0
	)

	draw_rect(
		Rect2(-18, 24, 36 * remaining, 4),
		Color("#AA3333")
	)
