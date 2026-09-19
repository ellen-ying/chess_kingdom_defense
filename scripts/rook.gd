extends BasePiece

const FIRE_INTERVAL := 0.5

const ROOK_ATTACK_DIRECTIONS: Array[Vector2i] = [
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(0, 1)
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

	if fire_timer >= SkillManager.get_attack_interval(FIRE_INTERVAL, self, game):
		fire_timer = 0.0
		attempt_attack()


func attempt_attack() -> void:
	var target = find_closest_enemy()

	if target == null:
		return

	game.spawn_projectile(self, target)


func find_closest_enemy():
	var candidates := []

	for direction in ROOK_ATTACK_DIRECTIONS:
		var cell = current_cell + direction

		while game.board.is_valid_cell(cell):
			var enemies = game.get_enemies_at_cell(cell)

			if not enemies.is_empty():
				candidates.append(enemies[0])
				break

			cell += direction

	if candidates.is_empty():
		return null

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
		ROOK_ATTACK_DIRECTIONS
	)


func _draw() -> void:
	var alpha := 0.65 if dragging else 1.0

	draw_circle(
		Vector2(2, 4),
		20.0,
		Color(0, 0, 0, 0.2 * alpha)
	)

	# Main tower
	draw_rect(
		Rect2(-13, -5, 26, 21),
		Color(0.95, 0.95, 0.95, alpha)
	)

	# Roof
	var roof := PackedVector2Array([
		Vector2(-15, -5),
		Vector2(-15, -20),
		Vector2(-8, -20),
		Vector2(-6, -26),
		Vector2(0, -20),
		Vector2(6, -26),
		Vector2(8, -20),
		Vector2(15, -20),
		Vector2(15, -5)
	])

	draw_colored_polygon(
		roof,
		Color(0.95, 0.95, 0.95, alpha)
	)

	draw_polyline(
		roof + PackedVector2Array([roof[0]]),
		Color(0.15, 0.15, 0.15, alpha),
		2.0
	)
