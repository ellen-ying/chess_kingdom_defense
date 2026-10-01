extends Node2D

var offset = Vector2.ZERO
var radius = 20.0

func _draw() -> void:
	draw_circle(
		Vector2(0, 4) + offset,
		radius,
		Color(0, 0, 0, 0.25)
	)
