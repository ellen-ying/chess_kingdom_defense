extends BaseEnemy

const ROOK_DIRECTIONS := [
	Vector2i(-1, 0),
	Vector2i(1, 0),
	Vector2i(0, -1),
	Vector2i(0, 1)
]
var direction_to_king
var move_direction_x
var king_cell: Vector2i


func setup(game_reference: Node, cell: Vector2i) -> void:
	type = "ShadowRook"
	max_hp = 5
	hp = max_hp
	game = game_reference
	current_cell = cell
	global_position = game.board.cell_to_world(current_cell)
	reposition_offset(
		ScreenLayout.scale_vec, ScreenLayout.sprite_offset,
		ScreenLayout.shadow_radius, ScreenLayout.shadow_offset
	)
	
	king_cell = game.king.current_cell
	direction_to_king = king_cell - current_cell
	# Randomly decide the initial direction to move
	if randi_range(0, 1) > 0:
		move_direction_x = true
	else:
		move_direction_x = false

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
		
	take_piece_at_cell()
		
func take_damage(amount: int, source_piece: String) -> void:
	hp -= amount

	if hp <= 0:
		var reward := CurrencyManager.get_piece_value("Rook")
		CurrencyManager.add_currency(reward)
		game.shop_ui.show_currency_reward(global_position, reward)
		
		game.enemy_destroyed(self, source_piece)
		queue_free()

	queue_redraw()


func move_toward_king() -> void:
	if direction_to_king.x == 0 or direction_to_king.y == 0:
		var sgn_x = sign(direction_to_king.x)
		var sgn_y = sign(direction_to_king.y)
		current_cell += sgn_x * Vector2i(1, 0) + sgn_y * Vector2i(0, 1)
	else:
		if move_direction_x:
			var sgn = sign(direction_to_king.x)
			current_cell += sgn * Vector2i(1, 0)
		else:
			var sgn = sign(direction_to_king.y)
			current_cell += sgn * Vector2i(0, 1)

	#var best_cell := current_cell
	#var best_distance := INF
#
	#for direction in ROOK_DIRECTIONS:
		#var candidate = current_cell + direction
#
		#if not game.board.is_valid_cell(candidate):
			#continue
#
		#var difference = king_cell - candidate
		#var distance_squared = (
			#difference.x * difference.x
			#+ difference.y * difference.y
		#)
#
		#if distance_squared < best_distance:
			#best_distance = distance_squared
			#best_cell = candidate
#
	#if best_cell == current_cell:
		#return
#
	#current_cell = best_cell
	global_position = game.board.cell_to_world(current_cell)
	direction_to_king = king_cell - current_cell

	if current_cell == king_cell:
		game.enemy_reached_king(self)

	queue_redraw()
	
func _draw() -> void:
	pass
	#draw_circle(
		#Vector2(2, 4),
		#20.0,
		#Color(0, 0, 0, 0.25)
	#)
#
	#draw_rect(
		#Rect2(-13, -5, 26, 21),
		#Color("#151515")
	#)
#
	#var roof := PackedVector2Array([
		#Vector2(-15, -5),
		#Vector2(-15, -20),
		#Vector2(-8, -20),
		#Vector2(-6, -26),
		#Vector2(0, -20),
		#Vector2(6, -26),
		#Vector2(8, -20),
		#Vector2(15, -20),
		#Vector2(15, -5)
	#])
#
	#draw_colored_polygon(roof, Color("#151515"))
#
	#draw_polyline(
		#roof + PackedVector2Array([roof[0]]),
		#Color("#666666"),
		#2.0
	#)

	draw_hp()
