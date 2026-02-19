# components/interaction/interaction_ray.gd
## Casts a ray from the camera to detect interactable objects.
class_name InteractionRay
extends Node

@export var priority: int = 40

@export_group("Raycast")
@export var interaction_distance: float = 3.0
## Collision mask for the interaction ray
@export_flags_3d_physics var interaction_mask: int = 1

@export_group("Input")
@export var interact_action: StringName = "interact"

@export_group("References")
@export var camera_path: NodePath

var current_interactable: Interactable = null
var _camera: Camera3D
var _character: CharacterBody3D

signal focused(interactable: Interactable)
signal unfocused(interactable: Interactable)
signal interacted(interactable: Interactable)

func _ready() -> void:
	_character = _find_character_body()
	_camera = get_node_or_null(camera_path)
	if not _camera:
		_camera = _find_camera()

func _find_character_body() -> CharacterBody3D:
	var node := get_parent()
	while node:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null

func _find_camera() -> Camera3D:
	if not _character:
		return null
	return _find_in_children(_character, Camera3D) as Camera3D

func _find_in_children(node: Node, type: Variant) -> Node:
	for child in node.get_children():
		if is_instance_of(child, type):
			return child
		var found := _find_in_children(child, type)
		if found:
			return found
	return null

func post_process(data: CharacterData, _delta: float) -> void:
	if not _camera or not _camera.is_inside_tree():
		return

	var new_interactable := _raycast()

	# Check angle restriction
	if new_interactable and new_interactable.max_interaction_angle > 0.0:
		if not _is_within_angle(new_interactable):
			new_interactable = null

	# Focus changed
	if new_interactable != current_interactable:
		if current_interactable:
			current_interactable.set_focused(false)
			unfocused.emit(current_interactable)

		current_interactable = new_interactable

		if current_interactable:
			current_interactable.set_focused(true)
			focused.emit(current_interactable)

	# Interact
	if current_interactable and Input.is_action_just_pressed(interact_action):
		if current_interactable.can_interact():
			current_interactable.interact(_character)
			interacted.emit(current_interactable)

			# If one_shot, clear focus since it can't be used again
			if current_interactable and not current_interactable.can_interact():
				current_interactable.set_focused(false)
				unfocused.emit(current_interactable)
				current_interactable = null

func _raycast() -> Interactable:
	if not _character:
		return null

	var space := _character.get_world_3d().direct_space_state
	if not space:
		return null

	var from := _camera.global_position
	var to := from + -_camera.global_basis.z * interaction_distance

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = interaction_mask
	query.exclude = [_character.get_rid()]

	var result := space.intersect_ray(query)
	if result.is_empty():
		return null

	return _find_interactable(result.collider)

func _find_interactable(node: Node) -> Interactable:
	# Check direct children first
	for child in node.get_children():
		if child is Interactable:
			return child
	# Check the node itself (if it somehow is an interactable)
	if node is Interactable:
		return node
	return null

func _is_within_angle(interactable: Interactable) -> bool:
	var target := interactable.get_parent() as Node3D
	if not target:
		return true

	var to_player := _character.global_position - target.global_position
	to_player.y = 0.0
	to_player = to_player.normalized()

	var target_forward := -target.global_basis.z
	target_forward.y = 0.0
	target_forward = target_forward.normalized()

	var angle := rad_to_deg(to_player.angle_to(target_forward))
	return angle <= interactable.max_interaction_angle
