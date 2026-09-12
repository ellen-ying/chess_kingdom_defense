extends BasePiece

const FIRE_INTERVAL := 0.5

const BISHOP_ATTACK_DIRECTIONS: Array[Vector2i] = [
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
	var candidates := []

	for direction in BISHOP_ATTACK_DIRECTIONS:
		var cell = current_cell + direction

		while game.board.is_valid_cell(cell):
			var enemies = game.get_enemies_at_cell(cell)

			if not enemies.is_empty():
				# First occupied cell on this ray is the closest target
				# for this direction.
				candidates.append(enemies[0])
				break

			cell += direction

	if candidates.is_empty():
		return null

	# All candidates are along different rays.
	# Pick the one with smallest board distance.
	var best_target = candidates[0]
	var best_distance := current_cell.distance_to(
		best_target.current_cell
	)

	for target in candidates:
		var distance := current_cell.distance_to(
			target.current_cell
		)

		if distance < best_distance:
			best_distance = distance
			best_target = target

	return best_target
	
func get_attack_tiles_for_cell(
	origin_cell: Vector2i,
	board: Node
) -> Array[Vector2i]:
	return get_ray_tiles(
		origin_cell,
		board,
		BISHOP_ATTACK_DIRECTIONS
	)


func _draw() -> void:
	var alpha := 0.65 if dragging else 1.0

	# Shadow
	draw_circle(
		Vector2(2, 4),
		20.0,
		Color(0, 0, 0, 0.2 * alpha)
	)

	# Body
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

	draw_colored_polygon(
		body,
		Color(0.95, 0.95, 0.95, alpha)
	)

	draw_polyline(
		body + PackedVector2Array([body[0]]),
		Color(0.15, 0.15, 0.15, alpha),
		2.0
	)

	# Bishop slit
	draw_line(
		Vector2(-3, -15),
		Vector2(4, -7),
		Color("#333333", alpha),
		2.0
	)
