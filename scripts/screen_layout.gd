extends Node

## ScreenLayout — the gameplay scene's single resize-aware node.
##
## Implements the full-bleed layout (tasks/fullbleed-layout-brief.md):
## the fixed 13×9 board is sized FIRST (the largest square integer
## tile that fits the screen minus minimum UI reservations); the HUD
## bar and tray then absorb ALL leftover pixels (exact full-bleed:
## hud_h + 9*tile = H and 13*tile + tray_w = W). On extreme aspect
## ratios the HUD/tray are capped and the surplus is split
## symmetrically as board margins rendered over the Background
## layer — never black bars (task Q5).
##
## apply_layout runs on every viewport resize (window size, aspect,
## orientation) and once from main._ready (after the King exists),
## and repositions live board entities (King, pieces, enemies) to
## their cells' new world positions.

# Minimum reservations subtracted from the tile computation so the
# board can never crowd out the UI entirely.
const HUD_MIN := 48.0
const TRAY_MIN := 136.0

# Caps for extreme aspect ratios: leftover absorbed by the HUD/tray is
# bounded, and the surplus becomes symmetric board margins.
const HUD_MAX := 128.0
const TRAY_MAX := 200.0


func _ready() -> void:
	get_viewport().size_changed.connect(apply_layout)


func apply_layout() -> void:
	var game := get_parent()

	# This node's _ready runs before main._ready, so some @onready
	# references may not exist yet on the very first call.
	if (
		game == null
		or game.board == null
		or game.hud_bar == null
		or game.ui_layer == null
		or game.background == null
	):
		return

	var board = game.board
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size

	# Top-level Controls under a Node2D parent (Main) do not resolve
	# their anchors against the viewport in this Godot build, so the
	# two full-screen layers are sized explicitly here — and on every
	# resize — instead of relying on Full Rect anchors.
	#game.ui_layer.position = Vector2.ZERO
	#game.ui_layer.size = viewport_size
	game.background.position = Vector2.ZERO
	game.background.size = viewport_size

	# 1. Board first: the largest integer square tile that fits the
	#    grid plus the minimum UI reservations.
	var tile := maxi(1, int(min(
		(viewport_size.x - TRAY_MIN) / float(board.COLUMNS),
		(viewport_size.y - HUD_MIN) / float(board.ROWS)
	)))

	# 2/3. HUD and tray absorb ALL leftover pixels: exact full-bleed.
	var hud_height: float = viewport_size.y - board.ROWS * tile
	var tray_width: float = viewport_size.x - board.COLUMNS * tile

	# 4. Caps on extreme aspects; the surplus becomes symmetric
	#    board margins rendered over the Background layer.
	var margin_horizontal := 0.0
	var margin_vertical := 0.0

	if tray_width > TRAY_MAX:
		margin_horizontal = (tray_width - TRAY_MAX) / 2.0
		tray_width = TRAY_MAX

	if hud_height > HUD_MAX:
		margin_vertical = (hud_height - HUD_MAX) / 2.0
		hud_height = HUD_MAX

	# 5. The board's play area: between the HUD and the tray, inset
	#    by the margins.
	var play_area_origin := Vector2(
		margin_horizontal,
		hud_height + margin_vertical
	)
	var play_area_size := Vector2(
		viewport_size.x - tray_width - margin_horizontal * 2.0,
		viewport_size.y - hud_height - margin_vertical * 2.0
	)

	board.apply_layout(play_area_origin, play_area_size)

	game.hud_bar.position = Vector2.ZERO
	game.hud_bar.size = Vector2(viewport_size.x, hud_height)

	game.shop_ui.position = Vector2(
		viewport_size.x - tray_width,
		hud_height
	)
	game.shop_ui.size = Vector2(
		tray_width,
		viewport_size.y - hud_height
	)

	_recenter_over_play_area(game.wave_banner, play_area_origin, play_area_size)
	_recenter_over_play_area(game.game_over_label, play_area_origin, play_area_size)

	_reposition_board_entities(game, board)


func _recenter_over_play_area(
	label: Control,
	play_area_origin: Vector2,
	play_area_size: Vector2
) -> void:
	if label == null:
		return

	label.position = play_area_origin + (play_area_size - label.size) / 2.0


func _reposition_board_entities(game: Node, board: Node) -> void:
	# Board entities derive their world positions from their cells,
	# so a resize re-anchors them onto the recomputed grid. In-flight
	# projectiles keep their world positions (accepted; they may be
	# briefly offset until they resolve).
	if game.king != null and is_instance_valid(game.king):
		game.king.global_position = board.cell_to_world(game.king.current_cell)

	for piece in game.piece_parent.get_children():
		if not (piece is Node2D):
			continue
		if piece.get("current_cell") == null:
			continue
		piece.global_position = board.cell_to_world(piece.current_cell)

	for enemy in game.enemies.get_children():
		if not (enemy is Node2D):
			continue
		if enemy.get("current_cell") == null:
			continue
		enemy.global_position = board.cell_to_world(enemy.current_cell)
