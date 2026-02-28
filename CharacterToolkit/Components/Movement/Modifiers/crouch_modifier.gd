@icon("res://Toolkit/GodotToolkit/CharacterToolkit/Components/Movement/Modifiers/CrouchModifierIcon3.png")
class_name CrouchModifier
extends Node

@export var priority: int = 26
@export var crouch_speed_multiplier: float = 0.5
@export var crouch_height: float = 1.0
@export var crouch_transition_speed: float = 8.0
@export var collision_shape_path: NodePath
@export var camera_pivot_path: NodePath

var _stand_height: float
var _current_height: float
var _original_shape_y: float
var _original_camera_y: float
var _is_crouching: bool = false

var _character: CharacterBody3D
@onready var _collision: CollisionShape3D = get_node_or_null(collision_shape_path)
@onready var _camera_pivot: Node3D = get_node_or_null(camera_pivot_path)

func _ready() -> void:
	_character = _find_character_body()

	if _collision:
		_collision.shape = _collision.shape.duplicate()
		_stand_height = _collision.shape.height
		_current_height = _stand_height
		_original_shape_y = _collision.position.y

	if _camera_pivot:
		_original_camera_y = _camera_pivot.position.y

func process_physics(data: CharacterData, delta: float) -> void:
	var want_crouch := data.wish_crouch

	if _is_crouching and not want_crouch:
		if _is_ceiling_above():
			want_crouch = true

	_is_crouching = want_crouch
	data.is_crouching = _is_crouching

	# Smooth height transition
	var target_height := crouch_height if _is_crouching else _stand_height
	_current_height = move_toward(_current_height, target_height,
		crouch_transition_speed * delta)

	var height_diff := _stand_height - _current_height

	# Collision shape
	if _collision and _collision.shape is CapsuleShape3D:
		_collision.shape.height = _current_height
		_collision.position.y = _original_shape_y - height_diff / 2.0

	# Camera follows smoothly
	if _camera_pivot:
		_camera_pivot.position.y = _original_camera_y - height_diff

	# Speed modifier
	if _is_crouching:
		data.move_speed *= crouch_speed_multiplier

func _is_ceiling_above() -> bool:
	if not _character or not _character.is_inside_tree():
		return false

	var space := _character.get_world_3d().direct_space_state
	if not space:
		return false

	var from := _character.global_position + Vector3.UP * (_current_height + 0.1)
	var to := _character.global_position + Vector3.UP * (_stand_height + 0.1)

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = _character.collision_mask
	query.exclude = [_character.get_rid()]

	var result := space.intersect_ray(query)
	return not result.is_empty()

func _find_character_body() -> CharacterBody3D:
	var node := get_parent()
	while node:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null
