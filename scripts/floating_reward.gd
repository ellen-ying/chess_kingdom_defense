extends Label


func play(
	amount: int,
	start_position: Vector2,
	target_position: Vector2
) -> void:
	text = "+%d" % amount
	position = start_position
	modulate.a = 1.0

	var mid_position := (
		start_position
		+ Vector2(0, -50)
	)

	var tween := create_tween()

	tween.set_parallel(false)

	tween.tween_property(
		self,
		"position",
		mid_position,
		0.20
	).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)

	tween.tween_property(
		self,
		"position",
		target_position,
		0.55
	).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)

	var fade_tween := create_tween()

	fade_tween.tween_interval(0.45)

	fade_tween.tween_property(
		self,
		"modulate:a",
		0.0,
		0.30
	)

	fade_tween.tween_callback(
		queue_free
	)
