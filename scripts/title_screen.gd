extends Control

@export var background_texture: Texture2D

@onready var background: TextureRect = $Background
@onready var fallback_background: ColorRect = $FallbackBackground

var _advanced := false


func _ready() -> void:
	move_child(fallback_background, 0)
	background.texture = background_texture


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed():
		advance()


func _on_advance_timer_timeout() -> void:
	advance()


func advance() -> void:
	if _advanced:
		return
	_advanced = true
	SceneRouter.go_home_office()
