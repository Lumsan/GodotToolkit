# components/interaction/interaction_ray.gd
class_name InteractionRay
extends Node

@export var priority: int = 40

@export_group("Raycast")
@export var interaction_distance: float = 3.0
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

	# Try direct raycast first
	var new_interactable := _raycast()

	# If nothing hit directly, check for aim-assisted interactables
	if not new_interactable:
		new_interactable = _find_aim_assisted()

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

func _find_aim_assisted() -> Interactable:
	if not _character:
		return null

	var space := _character.get_world_3d().direct_space_state
	if not space:
		return null

	var cam_pos := _camera.global_position
	var cam_forward := -_camera.global_basis.z

	# Sphere cast to find all nearby bodies
	var shape := SphereShape3D.new()
	shape.radius = interaction_distance

	var shape_query := PhysicsShapeQueryParameters3D.new()
	shape_query.shape = shape
	shape_query.transform = Transform3D(Basis.IDENTITY, cam_pos)
	shape_query.collision_mask = interaction_mask
	shape_query.exclude = [_character.get_rid()]

	var results := space.intersect_shape(shape_query, 32)

	var best_interactable: Interactable = null
	var best_score: float = -1.0

	for result in results:
		var collider: Node = result.collider
		if not collider:
			continue

		var interactable := _find_interactable(collider)
		if not interactable:
			continue
		if not interactable.can_interact():
			continue
		if not interactable.use_aim_assist:
			continue

		# Direction and distance to object
		var target_pos := interactable.get_world_position()
		var to_target := target_pos - cam_pos
		var distance := to_target.length()

		if distance < 0.01 or distance > interaction_distance:
			continue

		to_target = to_target.normalized()

		# Check if within this interactable's aim assist cone
		var dot := cam_forward.dot(to_target)
		var cone_cos := cos(deg_to_rad(interactable.aim_assist_angle))

		if dot < cone_cos:
			continue

		# Score: balance between looking-at and closeness
		var angle_score := dot
		var distance_score := 1.0 - (distance / interaction_distance)
		var score := angle_score * 0.5 + distance_score * 0.5

		if score > best_score:
			best_score = score
			best_interactable = interactable

	return best_interactable

func _find_interactable(node: Node) -> Interactable:
	if node is Interactable:
		return node
	
	# Search children of the starting node first
	var result := _search_children_for_interactable(node)
	if result:
		return result
	
	# Walk up the tree, searching each ancestor's subtree
	# Limit depth to avoid traversing the entire scene tree
	var current := node.get_parent()
	var max_climb := 8
	var climbed := 0
	
	while current and climbed < max_climb:
		if current is Interactable:
			return current
		
		# Search this ancestor's direct children and their subtrees
		# but skip the branch we already came from
		result = _search_children_for_interactable(current)
		if result:
			return result
		
		# Stop at CharacterBody3D or root to avoid crossing into unrelated trees
		if current is CharacterBody3D:
			break
		
		current = current.get_parent()
		climbed += 1
	
	return null


func _search_children_for_interactable(node: Node, max_depth: int = 6) -> Interactable:
	if max_depth <= 0:
		return null
	
	for child in node.get_children():
		if child is Interactable:
			return child
		var result := _search_children_for_interactable(child, max_depth - 1)
		if result:
			return result
	
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
