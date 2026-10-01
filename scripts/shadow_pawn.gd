extends BaseEnemy

func setup(game_reference: Node, cell: Vector2i) -> void:
	type = "ShadowPawn"
	max_hp = 2
	hp = max_hp
	hp_offset = max_hp * HP_BAR_LENGTH / 2
	game = game_reference
	current_cell = cell
	global_position = game.board.cell_to_world(cell)
	reposition_offset(
		ScreenLayout.scale_vec, ScreenLayout.sprite_offset,
		ScreenLayout.shadow_radius, ScreenLayout.shadow_offset
	)

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

	var difference := king_cell - current_cell

	if difference == Vector2i.ZERO:
		game.enemy_reached_king(self)
		return

	var step := Vector2i(
		sign(difference.x),
		sign(difference.y)
	)
	
	# Force the enemy pawn to choose a direction to avoid diagnol move
	if step.x * step.y != 0:
		var randn = randi_range(0, 1)
		if randn > 0:
			step.x = 0
		else:
			step.y = 0

	var destination := current_cell + step

	# Reaching the king means damage immediately.
	if destination == king_cell:
		game.enemy_reached_king(self)
		return

	current_cell = destination
	global_position = game.board.cell_to_world(current_cell)

	queue_redraw()


func take_damage(amount: int, source_piece: String) -> void:
	hp -= amount

	if hp <= 0:
		var reward := CurrencyManager.get_piece_value("Pawn")
		CurrencyManager.add_currency(reward)
		game.shop_ui.show_currency_reward(global_position, reward)
		
		game.enemy_destroyed(self, source_piece)
		queue_free()

	queue_redraw()


func _draw() -> void:
	# Shadow.
	#draw_circle(
		#Vector2(2, 4),
		#18.0,
		#Color(0, 0, 0, 0.25)
	#)
#
	## Head.
	#draw_circle(
		#Vector2(0, -9),
		#8.0,
		#Color("#202020")
	#)
#
	## Body.
	#var body := PackedVector2Array([
		#Vector2(-12, -2),
		#Vector2(12, -2),
		#Vector2(8, 10),
		#Vector2(14, 16),
		#Vector2(-14, 16),
		#Vector2(-8, 10)
	#])
#
	#draw_colored_polygon(body, Color("#121212"))
#
	#draw_polyline(
		#PackedVector2Array([
			#Vector2(-12, -2),
			#Vector2(12, -2),
			#Vector2(8, 10),
			#Vector2(14, 16),
			#Vector2(-14, 16),
			#Vector2(-8, 10),
			#Vector2(-12, -2)
		#]),
		#Color("#555555"),
		#2.0
	#)

	# HP indicator.
	draw_hp()
