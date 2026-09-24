class_name BasePiece
extends Node2D

var type = null

# Returns every theoretical attack tile from origin_cell.
# Occupancy/blocking is intentionally ignored.
func get_attack_tiles_for_cell(
	origin_cell: Vector2i,
	board: Node
) -> Array[Vector2i]:
	return []


func get_ray_tiles(
	origin_cell: Vector2i,
	board: Node,
	directions: Array[Vector2i]
) -> Array[Vector2i]:
	var result: Array[Vector2i] = []

	for direction in directions:
		var cell := origin_cell + direction

		while board.is_valid_cell(cell):
			result.append(cell)
			cell += direction

	return result
