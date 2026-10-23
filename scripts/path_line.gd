
extends Node2D

@export var line_color: Color = Color("#D4A64A")
@export var line_width: float = 5.0
@export var dash_length: float = 14.0
@export var gap_length: float = 9.0

var path_points: PackedVector2Array = PackedVector2Array()


func set_path(points: PackedVector2Array) -> void:
	path_points = points
	queue_redraw()


func _draw() -> void:
	if path_points.size() < 2:
		return

	var drawing_dash := true
	var phase_progress := 0.0
	var current_point := path_points[0]

	for i in range(1, path_points.size()):
		var next_point := path_points[i]
		var segment_vector := next_point - current_point
		var segment_length := segment_vector.length()

		if segment_length <= 0.001:
			current_point = next_point
			continue

		var direction := segment_vector / segment_length
		var consumed := 0.0

		while consumed < segment_length:
			var phase_length := dash_length if drawing_dash else gap_length
			var available := phase_length - phase_progress
			var step := minf(available, segment_length - consumed)

			var start := current_point + direction * consumed
			var finish := current_point + direction * (consumed + step)

			if drawing_dash:
				draw_line(
					start,
					finish,
					line_color,
					line_width,
					true
				)

			consumed += step
			phase_progress += step

			if phase_progress >= phase_length - 0.001:
				phase_progress = 0.0
				drawing_dash = not drawing_dash

		current_point = next_point
