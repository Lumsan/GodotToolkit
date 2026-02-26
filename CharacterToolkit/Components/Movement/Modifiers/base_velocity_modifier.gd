class_name BaseVelocityModifier
extends Node

@export var priority: int = 10

func process_physics(data: CharacterData, _delta: float) -> void:
	data.external_velocity = Vector3.ZERO
	
	for modifier in data.velocity_modifiers:
		if modifier.mode != VelocityModifierEntry.Mode.BASE:
			continue
		
		match modifier.affects:
			VelocityModifierEntry.Affects.HORIZONTAL:
				data.external_velocity.x += modifier.velocity.x
				data.external_velocity.z += modifier.velocity.z
			VelocityModifierEntry.Affects.VERTICAL:
				data.external_velocity.y += modifier.velocity.y
			VelocityModifierEntry.Affects.BOTH:
				data.external_velocity += modifier.velocity
