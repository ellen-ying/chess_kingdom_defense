extends Control

## Stage-1 tutorial overlay (home-office-interaction brief, Part 1;
## task plan Stage 4).
##
## Dims the whole office EXCEPT the Play zone, which stays fully
## bright inside a soft spotlight ring, with one callout label:
## "Tap the board to begin your first defense."
##
## The overlay is a PASSIVE visual layer: mouse_filter is IGNORE on
## it and everything it contains, so all input passes through to
## Zones, which consults the tutorial state — tapping the Play zone
## proceeds normally (opening Level Select exactly as a non-tutorial
## tap would) and tapping anywhere else skips early; both mark
## Stage 1 done (a skipped tutorial never returns).
##
## setup(play_rect) is re-called by the hub on every viewport resize
## with the freshly mapped zone rect.

const DIM_COLOR := Color(0.02, 0.02, 0.03, 0.55)
const CALLOUT_TEXT := "Tap the board to begin your first defense."
const CALLOUT_FONT_SIZE := 26
const CALLOUT_COLOR := Color(0.95, 0.79, 0.35)
const CALLOUT_OUTLINE_COLOR := Color(0.02, 0.02, 0.03)
const CALLOUT_OUTLINE_SIZE := 6
const CALLOUT_MARGIN := 24.0
const RING_ALPHA := 0.15
const RING_MARGIN := 36.0
const SPOTLIGHT_TINT := Color(1.0, 0.92, 0.7)

var _hole_rect := Rect2()
var _ring: TextureRect
var _callout: Label


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Positions the spotlight ring and callout around the given zone's
## screen rect and queues the dim redraw. callout_text lets the
## Stage-2 sequential spotlight reuse this overlay per step.
func setup(zone_rect: Rect2, callout_text := CALLOUT_TEXT) -> void:
	_hole_rect = zone_rect

	if _ring == null:
		_ring = _make_glow_element()
		add_child(_ring)

	if _callout == null:
		_callout = Label.new()
		_callout.text = callout_text
		_callout.add_theme_font_size_override(
			"font_size", CALLOUT_FONT_SIZE
		)
		_callout.add_theme_color_override("font_color", CALLOUT_COLOR)
		_callout.add_theme_color_override(
			"font_outline_color", CALLOUT_OUTLINE_COLOR
		)
		_callout.add_theme_constant_override(
			"outline_size", CALLOUT_OUTLINE_SIZE
		)
		_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_callout)

	# Soft spotlight edge framing the hole, slightly larger than the
	# zone, so the cutout doesn't read as a debug rectangle.
	var ring_rect := _hole_rect.grow(RING_MARGIN)
	_ring.position = ring_rect.position
	_ring.size = ring_rect.size
	_ring.modulate.a = RING_ALPHA

	# Callout centered above the zone (below it if there is no
	# headroom at the top of the screen).
	var text_size: Vector2 = _callout.get_minimum_size()
	_callout.size = text_size
	_callout.position = Vector2(
		_hole_rect.get_center().x - text_size.x / 2.0,
		_hole_rect.position.y - CALLOUT_MARGIN - text_size.y
	)

	if _callout.position.y < 0.0:
		_callout.position.y = _hole_rect.end.y + CALLOUT_MARGIN

	queue_redraw()


func _draw() -> void:
	if _hole_rect.size == Vector2.ZERO:
		return

	# The dim quad minus the highlighted zone, drawn as four rects
	# around the (clipped) hole so the zone stays fully bright. Every
	# strip is non-negative after the intersection clip.
	var full := Rect2(Vector2.ZERO, size)
	var hole := full.intersection(_hole_rect)

	# Top strip.
	draw_rect(
		Rect2(0, 0, full.size.x, hole.position.y),
		DIM_COLOR
	)

	# Bottom strip.
	draw_rect(
		Rect2(0, hole.end.y, full.size.x, full.size.y - hole.end.y),
		DIM_COLOR
	)

	# Left strip beside the hole.
	draw_rect(
		Rect2(0, hole.position.y, hole.position.x, hole.size.y),
		DIM_COLOR
	)

	# Right strip beside the hole.
	draw_rect(
		Rect2(hole.end.x, hole.position.y,
			full.size.x - hole.end.x, hole.size.y),
		DIM_COLOR
	)


func _make_glow_element() -> TextureRect:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([
		Color(1, 1, 1, 1),
		Color(1, 1, 1, 0)
	])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])

	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128

	var element := TextureRect.new()
	element.texture = texture
	element.stretch_mode = TextureRect.STRETCH_SCALE
	element.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	element.self_modulate = SPOTLIGHT_TINT
	element.modulate = Color(1, 1, 1, 0)
	element.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	element.material = material

	return element
