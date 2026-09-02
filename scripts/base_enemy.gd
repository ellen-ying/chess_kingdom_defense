class_name BaseEnemy
extends Node2D

const MOVE_INTERVAL := 1.0
const MAX_HP := 3

var game: Node
var current_cell: Vector2i
var hp := MAX_HP

var move_timer := 0.0

func setup(game_reference: Node, cell: Vector2i) -> void:
	push_error("BaseEnemy.setup() was not overridden.")


func take_damage(amount: int) -> void:
	push_error("BaseEnemy.take_damage() was not overridden.")
