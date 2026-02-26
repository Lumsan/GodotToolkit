# core/velocity_modifier_entry.gd
class_name VelocityModifierEntry
extends RefCounted

enum Mode {
	ADDITIVE,
	OVERRIDE,
	BASE,
}

enum Affects {
	HORIZONTAL,
	VERTICAL,
	BOTH,
}

enum TimeMode {
	CONSTANT,
	DURATION,
	CURVE,
}

var id: StringName = &""
var mode: Mode = Mode.ADDITIVE
var affects: Affects = Affects.BOTH
var velocity: Vector3 = Vector3.ZERO
var suppress_gravity: bool = false
var suppress_input: bool = false

var time_mode: TimeMode = TimeMode.CONSTANT
var duration: float = 0.0
var curve: Curve = null
var loop: bool = false

var _elapsed: float = 0.0
var _expired: bool = false

func get_current_velocity(delta: float) -> Vector3:
	match time_mode:
		TimeMode.CONSTANT:
			return velocity
		TimeMode.DURATION:
			_elapsed += delta
			if _elapsed >= duration:
				_expired = true
			return velocity
		TimeMode.CURVE:
			_elapsed += delta
			if duration > 0.0:
				var t := _elapsed / duration
				if t >= 1.0:
					if loop:
						_elapsed = fmod(_elapsed, duration)
						t = _elapsed / duration
					else:
						_expired = true
						t = 1.0
				var multiplier := curve.sample(t) if curve else 1.0
				return velocity * multiplier
			return velocity
	return velocity

func is_expired() -> bool:
	return _expired

func reset() -> void:
	_elapsed = 0.0
	_expired = false
