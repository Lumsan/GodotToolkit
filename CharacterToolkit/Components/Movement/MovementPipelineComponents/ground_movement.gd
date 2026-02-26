# components/movement/ground_mover.gd
## Sets the base movement speed each frame. That's it.
## Modifiers adjust move_speed, VelocityApplicator handles actual movement.
class_name GroundMover
extends Node

@export var priority: int = 20
@export var base_speed: float = 5.0

func process_physics(data: CharacterData, _delta: float) -> void:
	data.base_speed = base_speed
	data.move_speed = base_speed
