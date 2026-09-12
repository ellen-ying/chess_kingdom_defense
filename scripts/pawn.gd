extends BasePiece

const FIRE_INTERVAL := 0.5

const PAWN_ATTACK_OFFSET: Array[Vector2i] = [
	Vector2i(-1, -1),
	Vector2i(1, -1),
	Vector2i(-1, 1),
	Vector2i(1, 1)
]

var game: Node
var current_cell: Vector2i

var dragging := false
var fire_timer := 0.0


func setup(game_reference: Node, cell: Vector2i) -> void:
	game = game_reference
	current_cell = cell

	global_position = game.board.cell_to_world(current_cell)

	queue_redraw()


func set_cell(cell: Vector2i) -> void:
	current_cell = cell
	global_position = game.board.cell_to_world(current_cell)
	queue_redraw()


func set_dragging(value: bool) -> void:
	dragging = value
	queue_redraw()


func _process(delta: float) -> void:
	if game == null or game.game_over:
		return

	fire_timer += delta

	if fire_timer >= FIRE_INTERVAL:
		fire_timer = 0.0
		attempt_attack()


func attempt_attack() -> void:
	var target = find_closest_enemy()

	if target == null:
		return

	game.spawn_projectile(self, target)


func find_closest_enemy():
	var target_cell: Vector2i

	# We check one square before two squares.
	for distance in [1, 2]:
		for direction in PAWN_ATTACK_OFFSET:
			target_cell = current_cell + direction * distance
			
			if not game.board.is_valid_cell(target_cell):
				continue

			var enemy = game.find_enemy_at_cell(target_cell)

			if enemy != null:
				return enemy

	return null
	
func get_attack_tiles_for_cell(
	origin_cell: Vector2i,
	board: Node
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for distance in [1, 2]:
		for direction in PAWN_ATTACK_OFFSET:
			var cell = origin_cell + direction * distance

			if board.is_valid_cell(cell):
				result.append(cell)

	return result


func _draw() -> void:
	var alpha := 0.65 if dragging else 1.0

	# Shadow.
	draw_circle(
		Vector2(2, 4),
		18.0,
		Color(0, 0, 0, 0.2 * alpha)
	)

	# Pawn head.
	draw_circle(
		Vector2(0, -9),
		8.0,
		Color(0.95, 0.95, 0.95, alpha)
	)

	# Pawn body.
	var body := PackedVector2Array([
		Vector2(-12, -2),
		Vector2(12, -2),
		Vector2(8, 10),
		Vector2(14, 16),
		Vector2(-14, 16),
		Vector2(-8, 10)
	])

	draw_colored_polygon(
		body,
		Color(0.95, 0.95, 0.95, alpha)
	)

	draw_polyline(
		PackedVector2Array([
			Vector2(-12, -2),
			Vector2(12, -2),
			Vector2(8, 10),
			Vector2(14, 16),
			Vector2(-14, 16),
			Vector2(-8, 10),
			Vector2(-12, -2)
		]),
		Color(0.15, 0.15, 0.15, alpha),
		2.0
	)
