## Reads raw input and writes to CharacterData.
## Swap this out for AI input, network input, replay input, etc.
class_name InputProvider
extends Node

@export var priority: int = 0
@export_range(0.0, 1.0, 0.00001) var mouse_sensitivity: float = 0.005
## If the game is inside a SubViewport, you need to add the
## GodotToolkit/Autoloads/WonkyStuff/mouse_input_provider.gd as an autoload and set this property to true
## to avoid latency in mouse motion.
@export var use_external_mouse_input: bool = false

var _mouse_motion: Vector2 = Vector2.ZERO

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if not use_external_mouse_input:
		if event is InputEventMouseMotion:
			_mouse_motion += event.relative

	if event.is_action_pressed("toggle_mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if \
			Input.mouse_mode == Input.MOUSE_MODE_CAPTURED else \
			Input.MOUSE_MODE_CAPTURED

func process_frame(data: CharacterData, _delta: float) -> void:
	if data.look_locked:
		data.mouse_motion = Vector2.ZERO
		_mouse_motion = Vector2.ZERO
	else:
		if use_external_mouse_input:
			_mouse_motion = MouseInput.motion
			MouseInput.motion = Vector2.ZERO
		data.mouse_motion = _mouse_motion * mouse_sensitivity
		_mouse_motion = Vector2.ZERO

func process_input(data: CharacterData, _delta: float) -> void:
	data.input_direction = Input.get_vector(
		"move_left", "move_right",
		"move_forward", "move_backward"
	)
	data.wish_jump = Input.is_action_just_pressed("jump")
	data.wish_sprint = Input.is_action_pressed("sprint")
	data.wish_crouch = Input.is_action_pressed("crouch")
	
