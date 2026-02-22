## Reads raw input and writes to CharacterData.
## Swap this out for AI input, network input, replay input, etc.
class_name InputProvider
extends Node

@export var priority: int = 0
@export var mouse_sensitivity: float = 0.005

var _mouse_motion: Vector2 = Vector2.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_motion += event.relative

	if event.is_action_pressed("toggle_mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if \
			Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else \
			Input.MOUSE_MODE_CAPTURED

func process_input(data: CharacterData, _delta: float) -> void:
	data.input_direction = Input.get_vector(
		"move_left", "move_right",
		"move_forward", "move_backward"
	)

	data.wish_jump = Input.is_action_just_pressed("jump")
	data.wish_sprint = Input.is_action_pressed("sprint")
	data.wish_crouch = Input.is_action_pressed("crouch")

	if data.look_locked:
		data.mouse_motion = Vector2.ZERO
		_mouse_motion = Vector2.ZERO
	else:
		data.mouse_motion = _mouse_motion * mouse_sensitivity
		_mouse_motion = Vector2.ZERO
