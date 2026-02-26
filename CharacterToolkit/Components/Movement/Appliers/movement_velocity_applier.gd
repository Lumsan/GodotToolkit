# components/physics/movement_velocity_applier.gd
class_name MovementVelocityApplier
extends Node

@export var priority: int = 15
@export var acceleration: float = 50.0
@export var deceleration: float = 50.0
@export var air_control: float = 0.8

var _character: Node3D

func _ready() -> void:
	_character = _find_character_body()

func _find_character_body() -> Node3D:
	var node := get_parent()
	while node:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null

func process_physics(data: CharacterData, delta: float) -> void:
	if not _character or not _character.is_inside_tree():
		return

	var input := data.input_direction
	if data.input_suspended:
		input = Vector2.ZERO

	var wish_dir := Vector3.ZERO
	if input.length_squared() > 0.001:
		var forward: Vector3
		var right: Vector3

		if data.use_custom_forward_axis:
			forward = data.custom_forward_axis.normalized()
			right = _character.global_basis.x
			right.y = 0.0
			right = right.normalized()
		else:
			forward = -_character.global_basis.z
			right = _character.global_basis.x
			forward.y = 0.0
			right.y = 0.0
			forward = forward.normalized()
			right = right.normalized()

		wish_dir = (forward * -input.y + right * input.x).normalized()
		data.facing_direction = wish_dir

	if data.use_custom_forward_axis:
		_apply_3d_movement(data, wish_dir, delta)
	else:
		_apply_horizontal_movement(data, wish_dir, delta)

func _apply_horizontal_movement(data: CharacterData, wish_dir: Vector3, delta: float) -> void:
	# Target includes external velocity (conveyor)
	var target_velocity := wish_dir * data.move_speed + Vector3(data.external_velocity.x, 0.0, data.external_velocity.z)
	var horizontal_velocity := Vector3(data.velocity.x, 0.0, data.velocity.z)

	var accel := acceleration
	if horizontal_velocity.length() > target_velocity.length():
		accel = deceleration

	if not data.is_on_floor:
		accel *= air_control

	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, accel * delta)

	data.velocity.x = horizontal_velocity.x
	data.velocity.z = horizontal_velocity.z

func _apply_3d_movement(data: CharacterData, wish_dir: Vector3, delta: float) -> void:
	var target_velocity := wish_dir * data.move_speed + data.external_velocity

	var accel := acceleration
	if data.velocity.length() > target_velocity.length():
		accel = deceleration

	if not data.is_on_floor:
		accel *= air_control

	data.velocity = data.velocity.move_toward(target_velocity, accel * delta)
