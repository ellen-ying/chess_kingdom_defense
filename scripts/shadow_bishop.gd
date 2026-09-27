extends BaseEnemy


const BISHOP_DIRECTIONS := [
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1)
]

var direction_to_king
var king_cell: Vector2i
var movement_direction

func setup(game_reference: Node, cell: Vector2i) -> void:
	type = "ShadowBishop"
	max_hp = 3
	hp = max_hp
	game = game_reference
	current_cell = cell
	global_position = game.board.cell_to_world(current_cell)
	
	king_cell = game.king.current_cell
	direction_to_king = king_cell - current_cell
	movement_direction = select_best_direction()

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
	if abs(direction_to_king.x) == abs(direction_to_king.y):
		movement_direction = sign(direction_to_king.x) * Vector2i(1, 0) + \
		sign(direction_to_king.y) * Vector2i(0, 1)
	
	current_cell += movement_direction
	direction_to_king = king_cell - current_cell
	global_position = game.board.cell_to_world(current_cell)

	if current_cell == king_cell:
		game.enemy_reached_king(self)

	queue_redraw()
	
func select_best_direction() -> Vector2i:
	var best_direction := Vector2i.ZERO
	var best_distance := INF
	var best_cell = current_cell

	for direction in BISHOP_DIRECTIONS:
		var candidate = current_cell + direction

		if not game.board.is_valid_cell(candidate):
			continue

		var difference = king_cell - candidate
		var distance_squared = (
			difference.x * difference.x
			+ difference.y * difference.y
		)

		if distance_squared < best_distance:
			best_distance = distance_squared
			best_direction = direction
			best_cell = candidate

	if best_cell == current_cell:
		return Vector2i.ZERO
		
	return best_direction
	
func take_damage(amount: int, source_piece: String) -> void:
	hp -= amount

	if hp <= 0:
		var reward := CurrencyManager.get_piece_value("Bishop")
		CurrencyManager.add_currency(reward)
		game.shop_ui.show_currency_reward(global_position, reward)
		
		game.enemy_destroyed(self, source_piece)
		queue_free()

	queue_redraw()
	
func _draw() -> void:
	draw_circle(
		Vector2(2, 4),
		20.0,
		Color(0, 0, 0, 0.25)
	)

	var body := PackedVector2Array([
		Vector2(-12, 16),
		Vector2(-8, 4),
		Vector2(-5, -5),
		Vector2(-10, -15),
		Vector2(0, -25),
		Vector2(10, -15),
		Vector2(5, -5),
		Vector2(8, 4),
		Vector2(12, 16)
	])

	draw_colored_polygon(body, Color("#151515"))

	draw_polyline(
		body + PackedVector2Array([body[0]]),
		Color("#666666"),
		2.0
	)

	draw_line(
		Vector2(-3, -15),
		Vector2(4, -7),
		Color("#AA3333"),
		2.0
	)

	for i in range(max_hp):
		draw_rect(
			Rect2(-15 + i * 10, 26, 7, 4),
			Color("#C62828") if i < hp else Color("#444444")
		)
