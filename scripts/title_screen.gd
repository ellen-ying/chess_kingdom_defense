extends Control

@onready var background: TextureRect = $Background

var _advanced := false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed():
		advance()


func _on_advance_timer_timeout() -> void:
	advance()


func advance() -> void:
	if _advanced:
		return
	_advanced = true
	# The Home Office consumes this flag to run the title→office
	# crossfade + window flare (Stage 3); the crossfade itself is
	# executed by the office, not here.
	SceneRouter.arriving_from_title = true
	SceneRouter.go_home_office()
