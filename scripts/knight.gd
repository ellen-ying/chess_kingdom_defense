extends BasePiece

const FIRE_INTERVAL := 0.5

const KNIGHT_ATTACK_OFFSETS: Array[Vector2i] = [
	Vector2i(-1, -2),
	Vector2i(1, -2),
	Vector2i(-2, -1),
	Vector2i(2, -1),
	Vector2i(-2, 1),
	Vector2i(2, 1),
	Vector2i(-1, 2),
	Vector2i(1, 2)
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
	var possible_targets: Array = []

	for offset in KNIGHT_ATTACK_OFFSETS:
		var target_cell = current_cell + offset

		if not game.board.is_valid_cell(target_cell):
			continue

		var enemies = game.get_enemies_at_cell(target_cell)

		for enemy in enemies:
			possible_targets.append(enemy)

	if possible_targets.is_empty():
		return null

	# All knight attack cells are sqrt(5) away,
	# so if several enemies exist, simply use the first one.
	return possible_targets[0]
	
func get_attack_tiles_for_cell(
	origin_cell: Vector2i,
	board: Node
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for offset in KNIGHT_ATTACK_OFFSETS:
		var cell = origin_cell + offset

		if board.is_valid_cell(cell):
			result.append(cell)

	return result


func _draw() -> void:
	var alpha := 0.65 if dragging else 1.0

	# Shadow
	draw_circle(
		Vector2(2, 4),
		20.0,
		Color(0, 0, 0, 0.2 * alpha)
	)

	# Simple knight silhouette.
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
		Color(0.95, 0.95, 0.95, alpha)
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
		Color(0.15, 0.15, 0.15, alpha),
		2.0
	)

	# Eye
	draw_circle(
		Vector2(4, -13),
		2.0,
		Color("#AA2222", alpha)
	)
