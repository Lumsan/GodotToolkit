# components/physics/static_velocity_modifier.gd
class_name StaticVelocityModifier
extends Node

@export var priority: int = 25

func process_physics(data: CharacterData, delta: float) -> void:
	var expired: Array[VelocityModifierEntry] = []

	for modifier in data.velocity_modifiers:
		if modifier.mode == VelocityModifierEntry.Mode.BASE:
			if modifier.is_expired():
				expired.append(modifier)
			continue
			
		var vel := modifier.get_current_velocity(delta)

		match modifier.mode:
			VelocityModifierEntry.Mode.ADDITIVE:
				_apply_additive(data, vel, modifier.affects)
			VelocityModifierEntry.Mode.OVERRIDE:
				_apply_override(data, vel, modifier.affects)

		if modifier.is_expired():
			expired.append(modifier)

	for mod in expired:
		data.remove_velocity_modifier_entry(mod)

func _apply_additive(data: CharacterData, vel: Vector3, affects: VelocityModifierEntry.Affects) -> void:
	match affects:
		VelocityModifierEntry.Affects.HORIZONTAL:
			data.velocity.x += vel.x
			data.velocity.z += vel.z
		VelocityModifierEntry.Affects.VERTICAL:
			data.velocity.y += vel.y
		VelocityModifierEntry.Affects.BOTH:
			data.velocity += vel

func _apply_override(data: CharacterData, vel: Vector3, affects: VelocityModifierEntry.Affects) -> void:
	match affects:
		VelocityModifierEntry.Affects.HORIZONTAL:
			data.velocity.x = vel.x
			data.velocity.z = vel.z
		VelocityModifierEntry.Affects.VERTICAL:
			data.velocity.y = vel.y
		VelocityModifierEntry.Affects.BOTH:
			data.velocity = vel
