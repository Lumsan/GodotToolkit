# components/buffs/active_buff.gd
## A single active instance of a buff. Created by BuffManager.
class_name ActiveBuff
extends RefCounted

var effect: BuffEffect
var time_remaining: float
var stacks: int = 1
var tick_timer: float = 0.0

var is_permanent: bool:
	get:
		return effect.duration <= 0.0

var is_expired: bool:
	get:
		if is_permanent:
			return false
		return time_remaining <= 0.0

func _init(buff_effect: BuffEffect) -> void:
	effect = buff_effect
	time_remaining = buff_effect.duration
	tick_timer = buff_effect.tick_interval

func tick(delta: float) -> bool:
	## Returns true if a health tick should happen this frame.
	if not is_permanent:
		time_remaining -= delta

	if not effect.modify_health:
		return false

	tick_timer -= delta
	if tick_timer <= 0.0:
		tick_timer += effect.tick_interval
		return true
	return false

func refresh() -> void:
	time_remaining = effect.duration

func add_stack() -> bool:
	if stacks < effect.max_stacks:
		stacks += 1
		return true
	return false
