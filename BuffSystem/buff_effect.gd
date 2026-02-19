# components/buffs/buff_effect.gd
class_name BuffEffect
extends Resource

@export var buff_name: String = "Unnamed Buff"
@export var description: String = ""
@export var icon: Texture2D

@export_group("Duration")
@export var duration: float = 5.0
@export var refresh_on_reapply: bool = true

@export_group("Stacking")
@export var stackable: bool = false
@export var max_stacks: int = 5

@export_group("Speed")
@export var modify_speed: bool = false
@export var speed_multiplier: float = 1.0

@export_group("Health Over Time")
@export var modify_health: bool = false
## Positive = heal per tick, negative = damage per tick
@export var health_per_tick: int = 0
@export var tick_interval: float = 1.0

@export_group("Jump")
@export var modify_jump: bool = false
@export var jump_multiplier: float = 1.0

@export_group("Gravity")
@export var modify_gravity: bool = false
@export var gravity_multiplier: float = 1.0

@export_group("Damage Taken")
@export var modify_damage_taken: bool = false
@export var damage_taken_multiplier: float = 1.0

@export_group("")
@export var tags: Array[Enums.BuffTag] = []
