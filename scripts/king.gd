extends Node2D

var current_cell: Vector2i
var game: Node
@onready var king_sprite = $KingSprite
@onready var shadow = $Shadow

func setup(game_reference: Node, cell: Vector2i, board: Node) -> void:
	game = game_reference
	current_cell = cell
	global_position = board.cell_to_world(cell)
	queue_redraw()
	
func reposition_offset(sprite_scale: Vector2, 	sprite_offset: Vector2,
	shadow_radius: float, shadow_offset: Vector2) -> void:
	king_sprite.scale = sprite_scale
	king_sprite.offset = sprite_offset
	shadow.offset = shadow_offset
	shadow.radius = shadow_radius
	shadow.queue_redraw()

func _draw() -> void:
	pass
	# Shadow
	#draw_circle(
		#Vector2(2, 4),
		#20.0,
		#Color(0, 0, 0, 0.25)
	#)

	## Body
	#draw_circle(
		#Vector2(0, 7),
		#13.0,
		#Color("#F5F5F5")
	#)
#
	#draw_rect(
		#Rect2(-12, 6, 24, 12),
		#Color("#F5F5F5")
	#)
#
	## Crown
	#var crown := PackedVector2Array([
		#Vector2(-12, -4),
		#Vector2(-10, -18),
		#Vector2(-4, -11),
		#Vector2(0, -21),
		#Vector2(4, -11),
		#Vector2(10, -18),
		#Vector2(12, -4)
	#])
#
	#draw_colored_polygon(
		#crown,
		#Color("#F5F5F5")
	#)
#
	#draw_polyline(
		#crown + PackedVector2Array([crown[0]]),
		#Color("#666666"),
		#2.0
	#)
#
	## Cross
	#draw_line(
		#Vector2(0, -25),
		#Vector2(0, -14),
		#Color("#AA3333"),
		#2.0
	#)
#
	#draw_line(
		#Vector2(-5, -21),
		#Vector2(5, -21),
		#Color("#AA3333"),
		#2.0
	#)
