extends Node2D

const COLUMNS: int = 13
const ROWS: int = 9

# Pixel size of one tile. ADAPTIVE: ScreenLayout.apply_layout sets it
# per viewport so the fixed 13×9 grid always fits without cropping.
# The grid itself never changes — only pixels-per-tile adapts. Always
# an integer so grid lines stay crisp and tiles stay perfect squares.
var tile_size: int = 64

const LIGHT_TILE := Color("#F0D9B5")
const DARK_TILE := Color("#B58863")

# Player pieces may only be placed in the central 9-column band
# (PLACEABLE_HALF_WIDTH columns either side of the King's column).
# Enemies spawn on and traverse the whole board.
const PLACEABLE_HALF_WIDTH := 4

var board_origin: Vector2
var edge_cells: Array[Vector2i] = []


func _ready() -> void:
	# Sensible default (centered for the 1152×648 base design) so the
	# board is never uninitialized before the first ScreenLayout pass.
	board_origin = Vector2(
		(1152.0 - COLUMNS * tile_size) / 2.0,
		(648.0 - ROWS * tile_size) / 2.0
	)
	
	# Collect the edge cells (cell-based, independent of tile size)
	for x in range(COLUMNS):
		edge_cells.append(Vector2i(x, 0))
		edge_cells.append(Vector2i(x, ROWS - 1))

	for y in range(1, ROWS - 1):
		edge_cells.append(Vector2i(0, y))
		edge_cells.append(Vector2i(COLUMNS - 1, y))

	queue_redraw()


## Positions/sizes the board for the current viewport. Called by
## ScreenLayout on _ready and on every viewport resize. tile_size
## becomes the largest integer square tile that fits the play area;
## the board is centered within the play area, so any leftover space
## becomes symmetric margins over the Background layer.
func apply_layout(play_area_origin: Vector2, play_area_size: Vector2) -> void:
	tile_size = maxi(1, int(min(
		play_area_size.x / float(COLUMNS),
		play_area_size.y / float(ROWS)
	)))

	board_origin = play_area_origin + (
		(play_area_size - Vector2(COLUMNS * tile_size, ROWS * tile_size)) / 2.0
	)

	queue_redraw()


func _draw() -> void:
	# Loop to draw the board
	for row in range(ROWS):
		for column in range(COLUMNS):
			var color := LIGHT_TILE if (row + column) % 2 == 0 else DARK_TILE
			var rect := Rect2(
				board_origin +
				Vector2(column * tile_size, row * tile_size),
				Vector2(tile_size, tile_size)
			)

			draw_rect(rect, color)

	# Subtle outer border
	var board_rect := Rect2(
		board_origin,
		Vector2(COLUMNS * tile_size, ROWS * tile_size)
	)

	draw_rect(board_rect, Color("#33251A"), false, 3.0)


func cell_to_world(cell: Vector2i) -> Vector2:
	return board_origin + Vector2(
		cell.x * tile_size + tile_size / 2.0,
		cell.y * tile_size + tile_size / 2.0
	)


func world_to_cell(world_position: Vector2) -> Vector2i:
	var local_position := world_position - board_origin

	return Vector2i(
		floor(local_position.x / tile_size),
		floor(local_position.y / tile_size)
	)

func is_valid_cell(cell: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.x < COLUMNS
		and cell.y >= 0
		and cell.y < ROWS
	)

## Player pieces may only be placed in the centered 9-column band
## (PLACEABLE_HALF_WIDTH columns either side of the King's column).
## Rows are unrestricted (the board is 9 rows = the zone height).
## Enemies are NOT affected — they use the whole board.
func is_placeable_cell(cell: Vector2i) -> bool:
	var center_column := get_center_cell().x

	return (
		cell.x >= center_column - PLACEABLE_HALF_WIDTH
		and cell.x <= center_column + PLACEABLE_HALF_WIDTH
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
