# components/physics/jump_component.gd
class_name JumpComponent
extends Node

@export var priority: int = 10

@export_group("Jump Tuning")
@export var jump_height: float = 1.2
@export var variable_jump: bool = true
@export_range(0.0, 1.0) var variable_jump_damping: float = 0.4

@export_group("Multi Jump")
@export var allow_multi_jump: bool = false
@export var max_jumps: int = 2
@export var multi_jump_height_decay: float = 1.0

@export_group("Buffering")
@export var jump_buffer_time: float = 0.1

@export_group("Coyote Time")
@export var enable_coyote_time: bool = true
@export var coyote_duration: float = 0.15

var _jumps_remaining: int = 0
var _current_jump_index: int = 0
var _is_jumping: bool = false
var _jump_buffer_timer: float = 0.0
var _coyote_timer: float = 0.0
var _gravity_component: GravityComponent

func _ready() -> void:
	_gravity_component = _find_component(GravityComponent)

func process_physics(data: CharacterData, delta: float) -> void:
	# Coyote time tracking
	if enable_coyote_time:
		if data.was_on_floor and not data.is_on_floor and data.velocity.y <= 0.0:
			_coyote_timer = coyote_duration
		elif data.is_on_floor:
			_coyote_timer = 0.0

		if _coyote_timer > 0.0:
			_coyote_timer -= delta

	# Reset on landing
	if data.is_on_floor:
		_jumps_remaining = max_jumps
		_current_jump_index = 0
		_is_jumping = false

	# Jump buffer
	if data.wish_jump:
		_jump_buffer_timer = jump_buffer_time

	if _jump_buffer_timer > 0.0:
		_jump_buffer_timer -= delta

	# Attempt jump
	var buffered_jump := _jump_buffer_timer > 0.0

	if data.wish_jump or buffered_jump:
		var can_jump := false

		if data.is_on_floor:
			can_jump = true
		elif _has_coyote_time():
			can_jump = true
		elif allow_multi_jump and _jumps_remaining > 0 and _current_jump_index > 0:
			can_jump = true

		if can_jump:
			_perform_jump(data)
			_jump_buffer_timer = 0.0
			_coyote_timer = 0.0

	# Variable jump height
	if variable_jump and _is_jumping:
		if not Input.is_action_pressed("jump") and data.velocity.y > 0.0:
			data.velocity.y *= variable_jump_damping
			_is_jumping = false

func _perform_jump(data: CharacterData) -> void:
	var height := jump_height * pow(multi_jump_height_decay, _current_jump_index)

	var rise_grav := _get_rise_gravity()
	data.velocity.y = sqrt(2.0 * rise_grav * height)

	_jumps_remaining -= 1
	_current_jump_index += 1
	_is_jumping = true
	data.jumped.emit()

func _get_rise_gravity() -> float:
	if _gravity_component:
		return _gravity_component.get_rise_gravity()
	return ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _has_coyote_time() -> bool:
	return enable_coyote_time and _coyote_timer > 0.0

func _find_component(type: Variant) -> Node:
	var character := _find_character_body()
	if not character:
		return null
	return _find_in_children(character, type)

func _find_character_body() -> Node:
	var node := get_parent()
	while node:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null

func _find_in_children(node: Node, type: Variant) -> Node:
	for child in node.get_children():
		if is_instance_of(child, type):
			return child
		var found := _find_in_children(child, type)
		if found:
			return found
	return null
