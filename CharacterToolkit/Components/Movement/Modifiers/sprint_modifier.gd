# components/movement/sprint_modifier.gd
class_name SprintModifier
extends Node

@export var priority: int = 25
@export var sprint_multiplier: float = 1.4
## If true, sprinting only works while on the ground
@export var ground_only: bool = false

func process_physics(data: CharacterData, _delta: float) -> void:
	if not data.wish_sprint:
		return
	if ground_only and not data.is_on_floor:
		return
	if data.input_direction.length() < 0.1:
		return
	if data.wish_crouch:
		return

	data.move_speed *= sprint_multiplier
