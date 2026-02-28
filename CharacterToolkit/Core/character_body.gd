@icon("res://Toolkit/GodotToolkit/CharacterToolkit/Core/ToolkitCharacterBodyIcon.png")
class_name ToolkitCharacterBody
extends CharacterBody3D

@export var data: CharacterData = CharacterData.new()

@export var blocking_animation_player: NodePath

var _input_processors: Array[Node] = []
var _physics_processors: Array[Node] = []
var _post_processors: Array[Node] = []
var _blocking_anim: AnimationPlayer

func get_character_data() -> CharacterData:
	return data

func _ready() -> void:
	if blocking_animation_player:
		_blocking_anim = get_node_or_null(blocking_animation_player)
	_gather_components()

func _gather_components() -> void:
	_input_processors.clear()
	_physics_processors.clear()
	_post_processors.clear()

	for child in _get_all_descendants(self):
		if child.has_method("process_input"):
			_input_processors.append(child)
		if child.has_method("process_physics"):
			_physics_processors.append(child)
		if child.has_method("post_process"):
			_post_processors.append(child)

	var sorter := func(a: Node, b: Node) -> bool:
		var a_pri: int = a.get("priority") if a.get("priority") != null else 0
		var b_pri: int = b.get("priority") if b.get("priority") != null else 0
		return a_pri < b_pri

	_input_processors.sort_custom(sorter)
	_physics_processors.sort_custom(sorter)
	_post_processors.sort_custom(sorter)

func _get_all_descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_descendants(child))
	return result

func _is_blocked() -> bool:
	return _blocking_anim and _blocking_anim.is_playing()

func _physics_process(delta: float) -> void:
	data.was_on_floor = data.is_on_floor
	data.movement_blocked = _is_blocked()

	# Phase 1: Input (always runs so buffering works)
	for processor in _input_processors:
		processor.process_input(data, delta)

	# Phase 2: Physics (includes FinalVelocityApplier which handles move_and_slide)
	for processor in _physics_processors:
		processor.process_physics(data, delta)

	# Phase 3: Post-process
	for processor in _post_processors:
		processor.post_process(data, delta)

	# Phase 4: Clear per-frame input
	data.mouse_motion = Vector2.ZERO

	# Detect landing
	if data.is_on_floor and not data.was_on_floor:
		data.landed.emit()
