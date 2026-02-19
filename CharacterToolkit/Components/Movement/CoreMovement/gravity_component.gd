# components/physics/gravity_component.gd
class_name GravityComponent
extends Node

@export var priority: int = 0
@export_group("Gravity Source")
@export var use_project_gravity: bool = true
@export var custom_gravity: float = 9.8

@export_group("Rise and Fall")
@export var rise_multiplier: float = 0.5
@export var fall_multiplier: float = 1.0
@export var terminal_velocity: float = 50.0

@export_group("Apex Hang Time")
@export var enable_hang_time: bool = false
@export var hang_time_velocity_threshold: float = 2.0
@export var hang_time_gravity_multiplier: float = 0.3

@export_group("Fast Fall")
@export var enable_fast_fall: bool = false
@export var fast_fall_multiplier: float = 1.6

func _get_base_gravity() -> float:
	if use_project_gravity:
		return ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	return custom_gravity

func get_rise_gravity() -> float:
	return _get_base_gravity() * rise_multiplier

func get_fall_gravity() -> float:
	return _get_base_gravity() * fall_multiplier

func process_physics(data: CharacterData, delta: float) -> void:
	if data.is_on_floor:
		data.gravity_phase = CharacterData.GravityPhase.GROUNDED
		if data.velocity.y < 0.0:
			data.velocity.y = 0.0
		return

	var vy := data.velocity.y

	if enable_hang_time and absf(vy) < hang_time_velocity_threshold:
		data.gravity_phase = CharacterData.GravityPhase.HANG_TIME
	elif vy > 0.0:
		data.gravity_phase = CharacterData.GravityPhase.RISING
	else:
		data.gravity_phase = CharacterData.GravityPhase.FALLING

	var gravity := _get_gravity_for_phase(data)

	if enable_fast_fall and data.gravity_phase == CharacterData.GravityPhase.FALLING:
		if data.wish_crouch or data.input_direction.y > 0.5:
			gravity *= fast_fall_multiplier

	data.velocity.y -= gravity * delta
	data.velocity.y = maxf(data.velocity.y, -terminal_velocity)

func _get_gravity_for_phase(data: CharacterData) -> float:
	match data.gravity_phase:
		CharacterData.GravityPhase.RISING:
			return get_rise_gravity()
		CharacterData.GravityPhase.HANG_TIME:
			return get_rise_gravity() * hang_time_gravity_multiplier
		CharacterData.GravityPhase.FALLING:
			return get_fall_gravity()
		_:
			return get_fall_gravity()
