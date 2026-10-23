extends Control

## HomeOfficeZones — invisible tap zones over the Home Office art
## (home-office-interaction brief, Part 0; task plan Stages 1–2).
##
## There is NO visible button UI: the four menu sections (Play,
## Skills, Bestiary, Earn Materials) are tap regions over the
## corresponding art elements. Interactivity is communicated by
## press feedback (an additive warm glow over exactly the tapped
## element) and a field of little twinkling stars overlaying the
## coins, the trophies, and the glass display case — never by
## button chrome.
##
## Zone rectangles are defined in IMAGE-PIXEL coordinates of the
## 1376×768 background art (user-confirmed calibration, plan Q2) and
## mapped to screen space through the cover-crop transform, because
## the Background TextureRect uses STRETCH_KEEP_ASPECT_COVERED
## (center-cropped at non-16:9 aspects). The mapping recomputes on
## every viewport resize (the project's established resize-aware
## pattern, cf. gameplay's ScreenLayout).

signal zone_activated(zone_id: String, screen_position: Vector2)

## Emitted when any tap dismisses the tutorial overlay (a called-out
## zone tap that proceeds normally, or a skip-anywhere tap). The
## activated zone id rides the signal ("" for skips and cancelled
## releases) so the hub can advance or skip the sequential Stage-2
## spotlight; the hub owns marking the right stage done.
signal tutorial_advanced(zone_id: String)

# Zone definitions in image pixels. Tunable live in-game via
# show_debug_zones (thin colored outlines + labels).
const ZONE_DEFS := [
	{"id": "play", "label": "Play", "rect": Rect2(460, 410, 415, 175)},
	{"id": "skills", "label": "Skills", "rect": Rect2(15, 55, 285, 365)},
	{"id": "bestiary", "label": "Bestiary", "rect": Rect2(1035, 140, 260, 305)},
	{"id": "earn", "label": "Earn Materials", "rect": Rect2(860, 490, 470, 225)}
]

# Ambient idle cue (user-directed redesign of Stage 2): a field of
# little twinkling stars "constantly shining", overlaid ON the coins,
# the trophies, and the glass display case — not a big glint blob.
# Positions are star CENTERS in image pixels; stars sit inside the
# target areas so the sparkle reads as coming off the art itself.
# Everything is tunable in-game via show_debug_zones (small white
# dots mark star positions).
const COIN_CLUSTER_RECT := Rect2(1150, 615, 175, 95)
const COIN_STAR_POSITIONS := [
	Vector2(1200, 700),
	Vector2(1210, 640),
	Vector2(1255, 655),
	Vector2(1290, 640),
	Vector2(1165, 680),
	Vector2(1230, 690),
	Vector2(1275, 700),
	Vector2(1310, 675)
]
const TROPHY_STAR_POSITIONS := [
	Vector2(75, 215),
	Vector2(120, 205),
	Vector2(145, 215),
	Vector2(190, 225),
	Vector2(100, 245),
	Vector2(165, 240),
	Vector2(220, 230),
]
const DISPLAY_CASE_STAR_POSITIONS := [
	Vector2(1125, 260),
	Vector2(1170, 280),
	Vector2(1195, 245),
	Vector2(1100, 400),
	Vector2(1140, 340),
	Vector2(1200, 380)
]

# Press feedback: soft additive glow, fast-in / slow-out (brief).
const PRESS_GLOW_PEAK := 0.35
const PRESS_GLOW_IN_SECONDS := 0.12
const PRESS_GLOW_OUT_SECONDS := 0.2
const WARM_GOLD := Color(1.0, 0.84, 0.5)

# Star twinkle parameters. Every star shares one period but has its
# own phase and peak, staggered so several stars are always lit
# ("constantly shining") without any two blinking in lockstep.
# Near-white warm light reads on the bright gold art where a gold
# tint would wash out.
const CUE_LIGHT := Color(1.0, 0.96, 0.82)
const STAR_SIZE_IMAGE := 10.0
const STAR_PERIOD := 2.4
const STAR_RISE_FRACTION := 0.22
const STAR_FALL_FRACTION := 0.28
const STAR_PEAK_MIN := 0.55
const STAR_PEAK_MAX := 0.85

# Window flare (title→office crossfade, Stage 3): warm light
# "spilling into view" as the office fades in, peaking at the
# crossfade midpoint (~0.27 s = 0.12 delay + 0.15 ramp), decaying
# over 0.4 s that lingers just past the fade. The window rect is the
# user-confirmed arched window region (arch + glass + sill), in
# image-pixel coordinates (show_debug_zones draws it in cyan).
const WINDOW_FLARE_RECT := Rect2(295, 15, 180, 410)
const WINDOW_FLARE_PEAK := 0.5
const WINDOW_FLARE_DELAY := 0.12
const WINDOW_FLARE_RAMP := 0.15
const WINDOW_FLARE_DECAY := 0.4

@export var show_debug_zones := false

var _background: TextureRect
var _screen_rects := {}
var _pressed_zone_id := ""

var _glow: TextureRect
var _glow_tween: Tween

var _stars: Array[TextureRect] = []
var _star_positions: Array = []
var _star_tweens: Array[Tween] = []

var _window_flare: TextureRect
var _input_locked := false
var _tutorial_active := false


func _ready() -> void:
	_background = get_parent().get_node("Background")

	var glow_texture := _make_glow_texture()

	# Press-feedback glow (hidden until a press lands in a zone).
	_glow = _make_glow_element(glow_texture)
	add_child(_glow)

	# Ambient idle cue (Stage 2): little twinkling stars overlaying
	# the coins, the trophies, and the glass display case. Near-white
	# warm tint — a gold tint washes out on the gold art.
	_star_positions = COIN_STAR_POSITIONS.duplicate()
	_star_positions.append_array(TROPHY_STAR_POSITIONS)
	_star_positions.append_array(DISPLAY_CASE_STAR_POSITIONS)

	for _star_position in _star_positions:
		var star := _make_glow_element(glow_texture, CUE_LIGHT)
		_stars.append(star)
		add_child(star)

	# Window flare (title→office crossfade): hidden until played.
	_window_flare = _make_glow_element(glow_texture, CUE_LIGHT)
	_window_flare.visible = false
	add_child(_window_flare)

	_start_ambient_cues()

	get_viewport().size_changed.connect(_on_viewport_resized)
	_recompute_layout()
	call_deferred("_recompute_layout")


# ============================================================
# COVER-CROP MAPPING (image pixels → screen pixels)
# ============================================================

## The Background TextureRect is STRETCH_KEEP_ASPECT_COVERED: the
## image is center-cropped at non-16:9 aspects. Zones live in image
## pixels, so they must be mapped through the portion of the texture
## actually drawn on screen — not the control's rect.
func _image_to_screen_rect(image_rect: Rect2) -> Rect2:
	var control_size: Vector2 = _background.size
	var texture_size: Vector2 = _background.texture.get_size()

	var cover_scale: float = max(
		control_size.x / texture_size.x,
		control_size.y / texture_size.y
	)

	var drawn_size: Vector2 = texture_size * cover_scale
	var drawn_origin: Vector2 = (control_size - drawn_size) / 2.0

	return Rect2(
		drawn_origin + image_rect.position * cover_scale,
		image_rect.size * cover_scale
	)


func _recompute_layout() -> void:
	_screen_rects.clear()

	for zone in ZONE_DEFS:
		_screen_rects[zone["id"]] = _image_to_screen_rect(zone["rect"])

	if _pressed_zone_id != "" and _screen_rects.has(_pressed_zone_id):
		_place_element(_glow, _screen_rects[_pressed_zone_id])

	# Stars: map each star's image-pixel center to its screen rect.
	for i in _stars.size():
		var center: Vector2 = _star_positions[i]
		var star_rect := Rect2(
			center - Vector2(STAR_SIZE_IMAGE, STAR_SIZE_IMAGE) * 0.5,
			Vector2(STAR_SIZE_IMAGE, STAR_SIZE_IMAGE)
		)
		_place_element(_stars[i], _image_to_screen_rect(star_rect))

	_place_element(
		_window_flare, _image_to_screen_rect(WINDOW_FLARE_RECT)
	)

	queue_redraw()


func _on_viewport_resized() -> void:
	_recompute_layout()


func _place_element(element: TextureRect, screen_rect: Rect2) -> void:
	element.position = screen_rect.position
	element.size = screen_rect.size


# ============================================================
# INPUT (press-down feedback, release action, release-outside cancel)
# ============================================================

## Locks/unlocks zone input. Used by the hub during the title→office
## crossfade so taps can't mid-fire during the transition.
func set_input_locked(locked: bool) -> void:
	_input_locked = locked


## Marks the Stage-1 tutorial as showing: ANY completed tap now
## dismisses it (see _gui_input).
func set_tutorial_active(active: bool) -> void:
	_tutorial_active = active


## Screen-space rect of a zone (its image-pixel rect mapped through
## the cover-crop transform). Used by the hub for the tutorial
## overlay's hole/ring/callout.
func get_zone_screen_rect(zone_id: String) -> Rect2:
	var rect: Rect2 = _screen_rects.get(zone_id, Rect2())
	return rect


## Tells the hub a tap ended the tutorial overlay. zone_id is the
## activated zone ("" for skips and cancelled releases). No-op when
## the tutorial isn't showing, so the input path can call it
## unconditionally.
func _tutorial_advance(zone_id := "") -> void:
	if not _tutorial_active:
		return
	
	if TutorialManager.stage_2_step >= TutorialManager.STAGE_2_SIZE:
		_tutorial_active = false
		
	tutorial_advanced.emit(zone_id)


func _gui_input(event: InputEvent) -> void:
	if _input_locked:
		return

	if not (event is InputEventMouseButton):
		return

	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		var zone_id := _zone_at(event.position)

		if zone_id == "":
			# A press outside every zone while the Stage-1 tutorial is
			# showing = skip-early (the release path below only
			# covers taps that started inside a zone).
			_tutorial_advance()
			return

		# One press tracked at a time; a new press replaces any
		# in-flight one (touch behavior).
		_pressed_zone_id = zone_id
		_show_press_glow(zone_id)
		return

	# Release.
	if _pressed_zone_id == "":
		return

	var released_zone := _zone_at(event.position)
	_hide_press_glow()

	var pressed := _pressed_zone_id
	_pressed_zone_id = ""

	# Tutorial dismissal: any completed tap ends the overlay. The
	# activated zone (empty for skips and cancelled releases) rides
	# the signal so the hub can advance or skip the Stage-2
	# sequence; the hub owns marking the right stage done.
	_tutorial_advance(
		released_zone if released_zone == pressed else ""
	)

	# Release inside the same zone = action; release outside cancels.
	if released_zone == pressed:
		zone_activated.emit(pressed, event.position)


func _zone_at(local_position: Vector2) -> String:
	for zone in ZONE_DEFS:
		if not _screen_rects.has(zone["id"]):
			continue

		var screen_rect: Rect2 = _screen_rects[zone["id"]]

		if screen_rect.has_point(local_position):
			return zone["id"]

	return ""


# ============================================================
# PRESS FEEDBACK
# ============================================================

## Plays the window flare for the title→office crossfade: warm light
## spilling into view, peaking at the crossfade midpoint, decaying
## just past the fade's end.
func play_window_flare() -> void:
	_window_flare.visible = true
	_window_flare.modulate.a = 0.0

	var flare := create_tween()
	flare.tween_interval(WINDOW_FLARE_DELAY)
	flare.tween_property(
		_window_flare, "modulate:a", WINDOW_FLARE_PEAK, WINDOW_FLARE_RAMP
	)
	flare.tween_property(
		_window_flare, "modulate:a", 0.0, WINDOW_FLARE_DECAY
	)
	flare.tween_callback(func(): _window_flare.visible = false)


func _show_press_glow(zone_id: String) -> void:
	if not _screen_rects.has(zone_id):
		return

	_place_element(_glow, _screen_rects[zone_id])
	_glow.visible = true

	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()

	_glow.modulate.a = 0.0
	_glow_tween = create_tween()
	_glow_tween.tween_property(
		_glow, "modulate:a", PRESS_GLOW_PEAK, PRESS_GLOW_IN_SECONDS
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _hide_press_glow() -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()

	_glow_tween = create_tween()
	_glow_tween.tween_property(
		_glow, "modulate:a", 0.0, PRESS_GLOW_OUT_SECONDS
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


# ============================================================
# AMBIENT IDLE CUES (Stage 2)
# ============================================================

func _start_ambient_cues() -> void:
	# Little twinkling stars: shared period, per-star phase and peak.
	# The dark window before each star's rise is spread evenly across
	# the field, so at any moment several stars are lit ("constantly
	# shining") while no two blink in lockstep.
	var rise := STAR_PERIOD * STAR_RISE_FRACTION
	var fall := STAR_PERIOD * STAR_FALL_FRACTION
	var dark_total := STAR_PERIOD - rise - fall
	var star_count := _stars.size()

	for i in star_count:
		var dark := dark_total * float(i) / float(star_count)
		var peak := lerpf(
			STAR_PEAK_MIN,
			STAR_PEAK_MAX,
			float(i % 3) / 2.0
		)

		var twinkle := create_tween().set_loops()
		twinkle.tween_interval(dark)
		twinkle.tween_property(
			_stars[i], "modulate:a", peak, rise
		).from(0.0)
		twinkle.tween_property(
			_stars[i], "modulate:a", 0.0, fall
		)
		_star_tweens.append(twinkle)


## Pauses/resumes the ambient star cues so an open popup owns
## attention (task Stage 6).
func set_cues_paused(paused: bool) -> void:
	for twinkle in _star_tweens:
		if twinkle == null or not twinkle.is_valid():
			continue

		if paused:
			twinkle.pause()
		else:
			twinkle.play()


# ============================================================
# GLOW ELEMENTS (generated gradients — no art assets)
# ============================================================

func _make_glow_texture() -> GradientTexture2D:
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

	return texture


func _make_glow_element(
	glow_texture: GradientTexture2D,
	tint: Color = WARM_GOLD
) -> TextureRect:
	var element := TextureRect.new()
	element.texture = glow_texture
	element.stretch_mode = TextureRect.STRETCH_SCALE
	# The default expand mode keeps the texture's 128px size as the
	# minimum, which would clamp small cue elements (e.g. the sparkle
	# dot) to far larger than their mapped rect.
	element.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	element.self_modulate = tint
	element.modulate = Color(1, 1, 1, 0)
	element.mouse_filter = Control.MOUSE_FILTER_IGNORE

	@warning_ignore("shadowed_variable_base_class")
	var material := CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	element.material = material

	return element


# ============================================================
# DEBUG CALIBRATION DRAW (developer tooling; off in normal state)
# ============================================================

func _draw() -> void:
	if not show_debug_zones:
		return

	var palette := {
		"play": Color(0.2, 1.0, 0.3),
		"skills": Color(0.35, 0.65, 1.0),
		"bestiary": Color(1.0, 0.4, 0.4),
		"earn": Color(1.0, 0.85, 0.2)
	}

	for zone in ZONE_DEFS:
		if not _screen_rects.has(zone["id"]):
			continue

		var screen_rect: Rect2 = _screen_rects[zone["id"]]
		var color: Color = palette[zone["id"]]

		draw_rect(screen_rect, color, false, 2.0)
		draw_string(
			ThemeDB.fallback_font,
			screen_rect.position + Vector2(4, 18),
			zone["label"],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color
		)

	# Ambient star positions (small white dots) + the confirmed coin
	# cluster rect, for calibration.
	for star_position in _star_positions:
		var screen_center := _image_to_screen_rect(
			Rect2(star_position, Vector2.ZERO)
		).position
		draw_circle(screen_center, 3.0, Color(1, 1, 1, 0.8))

	draw_rect(
		_image_to_screen_rect(COIN_CLUSTER_RECT),
		Color(1, 1, 1, 0.4), false, 1.0
	)

	# Window flare region (thin cyan outline, distinct from zones).
	draw_rect(
		_image_to_screen_rect(WINDOW_FLARE_RECT),
		Color(0.4, 0.9, 1.0, 0.8), false, 1.0
	)
