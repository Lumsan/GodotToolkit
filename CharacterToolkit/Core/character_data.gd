# core/character_data.gd
class_name CharacterData
extends Resource

var input_direction: Vector2 = Vector2.ZERO
var wish_jump: bool = false
var wish_sprint: bool = false
var wish_crouch: bool = false
var mouse_motion: Vector2 = Vector2.ZERO
var look_locked: bool = false

var velocity: Vector3 = Vector3.ZERO
var is_on_floor: bool = false
var was_on_floor: bool = false

enum GravityPhase { GROUNDED, RISING, FALLING, HANG_TIME }
var gravity_phase: GravityPhase = GravityPhase.GROUNDED

var move_speed: float = 5.0
var base_speed: float = 5.0
var facing_direction: Vector3 = Vector3.FORWARD

# ── Convenience properties ──
var horizontal_speed: float:
	get:
		return Vector2(velocity.x, velocity.z).length()

var is_moving: bool:
	get:
		return horizontal_speed > 0.1

var is_sprinting: bool:
	get:
		return wish_sprint and is_moving

var is_crouching: bool = false  # Set by CrouchModifier

signal jumped
signal landed
signal state_changed(old_state: StringName, new_state: StringName)
