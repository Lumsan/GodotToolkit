# components/camera/third_person_camera.gd
## Orbit camera with collision avoidance.
class_name ThirdPersonCamera
extends Node3D

@export var priority: int = 0
@export var distance: float = 5.0
@export var min_distance: float = 1.0
@export var min_pitch: float = -40.0
@export var max_pitch: float = 70.0
@export var collision_margin: float = 0.2

@export var camera_path: NodePath = "Camera3D"
@export var character_path: NodePath = "../.."

@onready var _camera: Camera3D = get_node(camera_path)
@onready var _character: CharacterBody3D = get_node(character_path)

var _yaw: float = 0.0
var _pitch: float = 0.0

func post_process(data: CharacterData, delta: float) -> void:
	# Orbit input
	_yaw -= data.mouse_motion.x
	_pitch = clampf(_pitch - data.mouse_motion.y,
		deg_to_rad(min_pitch), deg_to_rad(max_pitch))

	# Calculate ideal position
	var offset := Vector3.ZERO
	offset.z = distance
	var orbit_rotation := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	var ideal_pos := _character.global_position + Vector3.UP * 1.5 + orbit_rotation * offset

	# Collision check
	var space := _character.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		_character.global_position + Vector3.UP * 1.5,
		ideal_pos,
		_character.collision_mask,
		[_character.get_rid()]
	)
	var result := space.intersect_ray(query)

	if result:
		_camera.global_position = result.position + result.normal * collision_margin
	else:
		_camera.global_position = ideal_pos

	_camera.look_at(_character.global_position + Vector3.UP * 1.5)

	# Rotate character to face camera direction when moving
	if data.input_direction.length() > 0.1:
		var cam_forward := -_camera.global_basis.z
		cam_forward.y = 0.0
		cam_forward = cam_forward.normalized()
		var target_angle := atan2(cam_forward.x, cam_forward.z)
		_character.rotation.y = lerp_angle(
			_character.rotation.y, target_angle, 10.0 * delta)
