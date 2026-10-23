extends Control

@export var margin := 3.0
@export var border_width := 2.0
@export var corner_radius := 5.0
@export var border_color := Color("#f7eed8")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var rect := Rect2(
		margin,
		margin,
		maxf(0.0, size.x - margin * 2.0),
		maxf(0.0, size.y - margin * 2.0)
	)

	var style := StyleBoxFlat.new()

	style.bg_color = Color.TRANSPARENT

	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width

	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius

	draw_style_box(style, rect)
