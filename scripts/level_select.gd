extends Control

## Embedded-in-popup convention (task Stage 6): when this scene is
## instanced inside the Home Office popup container, `embedded` is
## true and the back button asks the popup to close instead of
## routing scenes. Standalone behavior (embedded=false) is unchanged.

signal close_requested

const INK := Color("#3B2A1E")
const MUTED_INK := Color("#6B5442")
const GOLD := Color("#D4A64A")
const NAVY := Color("#1F2D4D")
const NAVY_HOVER := Color("#2A3B61")
const CREAM := Color("#F7EED8")
const CARD_BG := Color("#F0E2C2")
const CARD_HOVER := Color("#F8EBD0")
const CARD_BORDER := Color("#C3A875")
const DISABLED_BG := Color("#D8CCAE")

const LEVEL_POSITIONS: Array[Vector2] = [
	Vector2(0.07, 0.59),
	Vector2(0.24, 0.32),
	Vector2(0.41, 0.72),
	Vector2(0.58, 0.25),
	Vector2(0.76, 0.48),
	Vector2(0.93, 0.36)
]
const SAMPLES_PER_SEGMENT: int = 24


var embedded := false
@export var path_width: float = 5.0
@export var node_size: Vector2 = Vector2(64.0, 64.0)

@onready var progression_area: Control = %ProgressionArea
@onready var path_line: Node2D = %PathLine
@onready var level_nodes: Control = %Levels
@onready var start_button: Button = %StartButton
@onready var level_title: Label = %LevelTitle
@onready var wave_number: Label = %WaveNum
@onready var enemy_pieces: Label = %EnemyPiece
@onready var status_info: Label = %CompleteStatus
@onready var level_buttons: Dictionary[String, TextureButton] = {
	"level_1": %LevelOneButton,
	"level_2": %LevelTwoButton,
	"level_3": %LevelThreeButton,
	"level_4": %LevelFourButton,
	"level_5": %LevelFiveButton,
	"final_stand": %FinalStandButton
}


func _ready() -> void:
	# Keep the drawing and buttons in the same coordinate space.
	level_nodes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	path_line.position = Vector2.ZERO
	# Dispalyed info config to default level
	_config_level_details("level_1")
	progression_area.resized.connect(_layout_progression)
	call_deferred("_layout_progression")

func _layout_progression() -> void:
	var area_size := progression_area.size

	if area_size.x <= 0.0 or area_size.y <= 0.0:
		return

	if level_buttons.size() != LEVEL_POSITIONS.size():
		push_warning("Level button count does not match LEVEL_POSITIONS.")
		return

	# Keep the node layer aligned with the drawing area.
	level_nodes.position = Vector2.ZERO
	level_nodes.size = area_size

	var points: PackedVector2Array = PackedVector2Array()

	# Convert normalized waypoints into local pixel coordinates.
	var waypoints: Array[Vector2] = []
	for normalized_position in LEVEL_POSITIONS:
		waypoints.append(
			Vector2(
				normalized_position.x * area_size.x,
				normalized_position.y * area_size.y
			)
		)

	# Draw a smooth Catmull-Rom curve through all six waypoints.
	for segment in range(waypoints.size() - 1):
		var p0: Vector2 = waypoints[maxi(segment - 1, 0)]
		var p1: Vector2 = waypoints[segment]
		var p2: Vector2 = waypoints[segment + 1]
		var p3: Vector2 = waypoints[
			mini(segment + 2, waypoints.size() - 1)
		]

		for sample in range(SAMPLES_PER_SEGMENT):
			var t := float(sample) / float(SAMPLES_PER_SEGMENT)
			points.append(_catmull_rom(p0, p1, p2, p3, t))

	# Include the final endpoint.
	points.append(waypoints[waypoints.size() - 1])
	path_line.set_path(points)

	# Place each button's CENTER on its matching waypoint.
	var i = 0
	for level_id in level_buttons.keys():
		var button := level_buttons[level_id]
		button.custom_minimum_size = node_size
		button.size = node_size
		button.position = waypoints[i] - node_size * 0.5
		
		var unlocked = LevelProgressManager.is_level_unlocked(level_id)
		button.disabled = not unlocked
		if unlocked:
			button.pressed.connect(_config_level_details.bind(level_id))
		
		i += 1


func _catmull_rom(
	p0: Vector2,
	p1: Vector2,
	p2: Vector2,
	p3: Vector2,
	t: float
) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t

	return 0.5 * (
		2.0 * p1
		+ (-p0 + p2) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)
	

func _make_dashed_path(
	source_points: PackedVector2Array,
	dash_length: float = 14.0,
	gap_length: float = 9.0
) -> PackedVector2Array:
	var result := PackedVector2Array()

	if source_points.size() < 2:
		return result

	var distance_in_dash := 0.0
	var drawing_dash := true
	var dash_start := source_points[0]
	var previous := source_points[0]

	# Each pair of points forms a small straight segment.
	for i in range(1, source_points.size()):
		var current := source_points[i]
		var segment_length := previous.distance_to(current)

		if segment_length <= 0.001:
			previous = current
			continue

		var direction := (current - previous).normalized()
		var segment_position := previous
		var remaining := segment_length

		while remaining > 0.001:
			var phase_length := dash_length if drawing_dash else gap_length
			var step := minf(phase_length - distance_in_dash, remaining)
			var next_position := segment_position + direction * step

			if drawing_dash:
				if distance_in_dash == 0.0:
					result.append(segment_position)
				result.append(next_position)

			segment_position = next_position
			remaining -= step
			distance_in_dash += step

			if distance_in_dash >= phase_length - 0.001:
				distance_in_dash = 0.0
				drawing_dash = not drawing_dash

		previous = current

	return result

#func _get_button_text(config: LevelConfig, unlocked: bool) -> String:
	#if not unlocked:
		#return "LOCKED"
#
	#if config.level_id == "final_stand":
		#return "%s\nBest: %d waves" % [config.display_name, LevelProgressManager.final_stand_high_score]
#
	#var completed_suffix := "  ✓" if LevelProgressManager.is_level_completed(config.level_id) else ""
	#return "%s%s" % [config.display_name, completed_suffix]
	


func _on_level_pressed(level_id: String) -> void:
	SceneRouter.start_level(level_id)

func _config_level_details(level_id: String) -> void:
	var config = LevelProgressManager.get_level_config(level_id)
	level_title.text = config.display_name
	wave_number.text = str(config.wave_count) if config.wave_count > 0 else "∞"
	enemy_pieces.text = " · ".join(config.allowed_enemy_pieces)
	status_info.text = "Complete" if LevelProgressManager.is_level_completed(level_id) else "Incomplete"
	start_button.pressed.connect(_on_level_pressed.bind(level_id))
