extends Node2D

const SPEED := 300.0
const HIT_DISTANCE := 8.0

var target: Node
var damage := 1
var source_piece: BasePiece

var shoot_direction : Vector2


func setup(
	start_position: Vector2,
	target_reference: Node,
	source_piece_reference: BasePiece
) -> void:
	global_position = start_position
	target = target_reference
	source_piece = source_piece_reference
	
	if target == null or not is_instance_valid(target):
		queue_free()
		return

	if target.get_parent() == null:
		queue_free()
		return
		
	shoot_direction = (target.global_position - global_position).normalized()
	queue_redraw()


func _process(delta: float) -> void:
	
	if target == null or not is_instance_valid(target):
		queue_free()
		return

	if target.get_parent() == null:
		queue_free()
		return
	
	var current_direction = target.global_position - global_position
	var distance = current_direction.length()

	if distance <= HIT_DISTANCE:
		target.take_damage(damage)
		if target is BaseEnemy:
			SkillManager.apply_projectile_effects(source_piece, target)
		queue_free()
		return

	if distance > 0:
		global_position += shoot_direction * SPEED * delta
		# Note that the projectile can track an enemy if this is updated using the current direction


	queue_redraw()



func _draw() -> void:
	draw_circle(
		Vector2.ZERO,
		5.0,
		Color("#FFD54F")
	)

	draw_circle(
		Vector2.ZERO,
		2.0,
		Color("#FFFFFF")
	)
