class_name VelocityApplier
extends Node

@export var priority: int = 30
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

	var wish_dir := Vector3.ZERO
	if input.length_squared() > 0.001:
		var forward := -_character.global_basis.z
		var right := _character.global_basis.x
		forward.y = 0.0
		right.y = 0.0
		forward = forward.normalized()
		right = right.normalized()
		wish_dir = (forward * -input.y + right * input.x).normalized()
		data.facing_direction = wish_dir

	var target_velocity := wish_dir * data.move_speed
	var horizontal_velocity := Vector3(data.velocity.x, 0.0, data.velocity.z)

	# Pick accel or decel based on speed comparison
	var accel := acceleration
	if horizontal_velocity.length() > target_velocity.length():
		accel = deceleration

	if not data.is_on_floor:
		accel *= air_control

	horizontal_velocity = horizontal_velocity.move_toward(target_velocity, accel * delta)

	data.velocity.x = horizontal_velocity.x
	data.velocity.z = horizontal_velocity.z
