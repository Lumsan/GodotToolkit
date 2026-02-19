# components/physics/coyote_time.gd
## Allows jumping for a brief window after walking off a ledge.

class_name CoyoteTime
extends Node

@export var priority: int = 5
@export var coyote_duration: float = 0.15

var _timer: float = 0.0

func is_active() -> bool:
	return _timer > 0.0

func process_physics(data: CharacterData, delta: float) -> void:
	if data.was_on_floor and not data.is_on_floor and data.velocity.y <= 0.0:
		# Just walked off a ledge
		_timer = coyote_duration
	elif data.is_on_floor:
		_timer = 0.0

	if _timer > 0.0:
		_timer -= delta
