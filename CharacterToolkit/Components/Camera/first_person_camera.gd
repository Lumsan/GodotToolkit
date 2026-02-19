# components/camera/first_person_camera.gd
class_name FirstPersonCamera
extends Node3D

@export var priority: int = 0
@export var min_pitch: float = -90.0
@export var max_pitch: float = 60.0
@export var head_bob_enabled: bool = false
@export var head_bob_frequency: float = 2.0
@export var head_bob_amplitude: float = 0.03

@export var camera_path: NodePath = "Camera3D"

var _yaw: float = 0.0
var _pitch: float = 0.0
var _bob_timer: float = 0.0
var _camera: Camera3D
var _character: Node3D

func _ready() -> void:
	_camera = get_node_or_null(camera_path)
	_character = _find_character_body()
	if not _character:
		push_error("FirstPersonCamera: No CharacterBody3D found in ancestors")
		return
	if not is_inside_tree():
		return
	_yaw = _character.rotation.y
	_pitch = rotation.x

func _find_character_body() -> Node3D:
	var node := get_parent()
	while node:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null

func post_process(data: CharacterData, delta: float) -> void:
	if not _character:
		return

	# Accumulate mouse input into yaw and pitch
	_yaw -= data.mouse_motion.x
	_pitch -= data.mouse_motion.y
	_pitch = clampf(_pitch, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

	# Apply as absolute values — no drift, no accumulation bugs
	_character.rotation = Vector3(0.0, _yaw, 0.0)
	rotation.x = _pitch

	if head_bob_enabled and _camera:
		_apply_head_bob(data, delta)

func _apply_head_bob(data: CharacterData, delta: float) -> void:
	var flat_speed := Vector2(data.velocity.x, data.velocity.z).length()

	if data.is_on_floor and flat_speed > 0.5:
		_bob_timer += delta * head_bob_frequency * flat_speed
		_camera.position.y = sin(_bob_timer) * head_bob_amplitude
		_camera.position.x = cos(_bob_timer * 0.5) * head_bob_amplitude * 0.5
	else:
		_bob_timer = 0.0
		_camera.position.y = move_toward(_camera.position.y, 0.0, delta * 2.0)
		_camera.position.x = move_toward(_camera.position.x, 0.0, delta * 2.0)
