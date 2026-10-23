extends Control

var game: Node

@onready var sfx_slider = %SESlider
@onready var music_slider = %MusicSlider

func setup(game_reference: Node) -> void:
	game = game_reference

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	%ReturnButton.pressed.connect(_on_return_button_pressed)
	
	music_slider.value = AudioManager.music_volume
	sfx_slider.value = AudioManager.sfx_volume

	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

	visible = false

func open() -> void:
	visible = true
	get_tree().paused = true

func _on_return_button_pressed() -> void:
	visible = false
	
	if is_instance_valid(game) and game.pause_overlay:
		game.pause_overlay.open()
	else:
		get_tree().paused = false

func _on_music_changed(value: float) -> void:
	$MusicPreview.play()
	AudioManager.set_music_volume(value)
	
func _on_sfx_changed(value:float) -> void:
	$SFXPreview.play()
	AudioManager.set_sfx_volume(value)
