extends Node2D

const TILE_SIZE: int = 64
const COLUMNS: int = 17
const ROWS: int = 9

const LIGHT_TILE := Color("#F0D9B5")
const DARK_TILE := Color("#B58863")

var board_origin: Vector2
var edge_cells: Array[Vector2i] = []


func _ready() -> void:
	# Set up the origin in the upper left corner
	board_origin = Vector2(
		(1152.0 - COLUMNS * TILE_SIZE) / 2.0,
		(648.0 - ROWS * TILE_SIZE) / 2.0
	)
	
	# Collect the edge cells
	for x in range(COLUMNS):
		edge_cells.append(Vector2i(x, 0))
		edge_cells.append(Vector2i(x, ROWS - 1))

	for y in range(1, ROWS - 1):
		edge_cells.append(Vector2i(0, y))
		edge_cells.append(Vector2i(COLUMNS - 1, y))

	queue_redraw()


func _draw() -> void:
	# Loop to draw the board
	for row in range(ROWS):
		for column in range(COLUMNS):
			var color := LIGHT_TILE if (row + column) % 2 == 0 else DARK_TILE
			var rect := Rect2(
				board_origin +
				Vector2(column * TILE_SIZE, row * TILE_SIZE),
				Vector2(TILE_SIZE, TILE_SIZE)
			)

			draw_rect(rect, color)

	# Subtle outer border
	var board_rect := Rect2(
		board_origin,
		Vector2(COLUMNS * TILE_SIZE, ROWS * TILE_SIZE)
	)

	draw_rect(board_rect, Color("#33251A"), false, 3.0)


func cell_to_world(cell: Vector2i) -> Vector2:
	return board_origin + Vector2(
		cell.x * TILE_SIZE + TILE_SIZE / 2.0,
		cell.y * TILE_SIZE + TILE_SIZE / 2.0
	)


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position := world_position - board_origin

	return Vector2i(
		floor(local_position.x / TILE_SIZE),
		floor(local_position.y / TILE_SIZE)
	)

func is_valid_cell(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < COLUMNS
		and cell.y >= 0
		and cell.y < ROWS
	)


func get_center_cell() -> Vector2i:
	return Vector2i(
		COLUMNS / 2,
		ROWS / 2
	)

func get_random_edge_cell() -> Vector2i:
	return edge_cells.pick_random()

# TODO: Might be optimised
func get_random_edge_cell_same_color(reference_cell: Vector2i) -> Vector2i:
	var reference_color := (
		(reference_cell.x + reference_cell.y) % 2
	)

	var cell := get_random_edge_cell()

	while (cell.x + cell.y) % 2 != reference_color:
		cell = get_random_edge_cell()

	return cell
