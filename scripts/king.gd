extends Node2D

var current_cell: Vector2i


func setup(cell: Vector2i, board: Node) -> void:
	current_cell = cell
	global_position = board.cell_to_world(cell)
	queue_redraw()


#func _draw() -> void:
	## Shadow.
	#draw_circle(Vector2(2, 4), 24.0, Color(0, 0, 0, 0.18))
#
	## King body.
	#draw_circle(Vector2.ZERO, 22.0, Color("#F5F5F5"))
	#draw_circle(Vector2.ZERO, 22.0, Color("#222222"), false, 3.0)
#
	## Crown.
	#var crown := PackedVector2Array([
		#Vector2(-15, -5),
		#Vector2(-10, -17),
		#Vector2(-2, -7),
		#Vector2(5, -18),
		#Vector2(11, -5),
		#Vector2(8, 8),
		#Vector2(-8, 8)
	#])
#
	#draw_colored_polygon(crown, Color("#D4AF37"))
#
	## Cross.
	#draw_line(Vector2(0, -21), Vector2(0, -8), Color("#222222"), 3.0)
	#draw_line(Vector2(-6, -16), Vector2(6, -16), Color("#222222"), 3.0)

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
		Color("#F5F5F5")
	)

	draw_rect(
		Rect2(-12, 6, 24, 12),
		Color("#F5F5F5")
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
		Color("#F5F5F5")
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
