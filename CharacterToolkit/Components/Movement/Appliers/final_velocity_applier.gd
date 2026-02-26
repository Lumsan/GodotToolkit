class_name FinalVelocityApplier
extends Node

@export var priority: int = 30

var _character: CharacterBody3D

func _ready() -> void:
	_character = _find_character_body()

func _find_character_body() -> CharacterBody3D:
	var node := get_parent()
	while node:
		if node is CharacterBody3D:
			return node
		node = node.get_parent()
	return null

func process_physics(data: CharacterData, _delta: float) -> void:
	if not _character or data.movement_blocked:
		return

	_character.velocity = data.velocity
	_character.move_and_slide()
	data.velocity = _character.velocity
	data.is_on_floor = _character.is_on_floor()
