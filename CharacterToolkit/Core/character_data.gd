class_name CharacterData
extends Resource

# ── Input ──
var input_direction: Vector2 = Vector2.ZERO
var wish_jump: bool = false
var wish_sprint: bool = false
var wish_crouch: bool = false
var mouse_motion: Vector2 = Vector2.ZERO
var look_locked: bool = false

# ── Movement ──
var velocity: Vector3 = Vector3.ZERO
var external_velocity: Vector3 = Vector3.ZERO
var is_on_floor: bool = false
var was_on_floor: bool = false
var move_speed: float = 5.0
var base_speed: float = 5.0
var facing_direction: Vector3 = Vector3.FORWARD

# ── Movement Remapping ──
var use_custom_forward_axis: bool = false
var custom_forward_axis: Vector3 = Vector3.UP

# ── Suspension (reference counted) ──
var _gravity_suspend_count: int = 0
var _input_suspend_count: int = 0

var gravity_suspended: bool:
	get:
		return _gravity_suspend_count > 0

var input_suspended: bool:
	get:
		return _input_suspend_count > 0

var movement_blocked: bool = false

# ── Velocity Modifiers ──
var velocity_modifiers: Array[VelocityModifierEntry] = []

# ── Gravity ──
enum GravityPhase { GROUNDED, RISING, FALLING, HANG_TIME }
var gravity_phase: GravityPhase = GravityPhase.GROUNDED

# ── State ──
var is_crouching: bool = false

# ── Convenience ──
var horizontal_speed: float:
	get:
		return Vector2(velocity.x, velocity.z).length()

var is_moving: bool:
	get:
		return horizontal_speed > 0.1

var is_sprinting: bool:
	get:
		return wish_sprint and is_moving

# ── Signals ──
signal jumped
signal landed
signal state_changed(old_state: StringName, new_state: StringName)

# ── Suspension Management ──
func suspend_gravity() -> void:
	_gravity_suspend_count += 1

func resume_gravity() -> void:
	_gravity_suspend_count = maxi(_gravity_suspend_count - 1, 0)

func suspend_input() -> void:
	_input_suspend_count += 1

func resume_input() -> void:
	_input_suspend_count = maxi(_input_suspend_count - 1, 0)

# ── Velocity Modifier Management ──
func add_velocity_modifier(modifier: VelocityModifierEntry) -> void:
	if modifier.id != &"":
		remove_velocity_modifier(modifier.id)
	velocity_modifiers.append(modifier)
	if modifier.suppress_gravity:
		suspend_gravity()
	if modifier.suppress_input:
		suspend_input()

func remove_velocity_modifier(id: StringName) -> void:
	for i in range(velocity_modifiers.size() - 1, -1, -1):
		if velocity_modifiers[i].id == id:
			_on_modifier_removed(velocity_modifiers[i])
			velocity_modifiers.remove_at(i)
			return

func remove_velocity_modifier_entry(modifier: VelocityModifierEntry) -> void:
	var idx := velocity_modifiers.find(modifier)
	if idx >= 0:
		_on_modifier_removed(modifier)
		velocity_modifiers.remove_at(idx)

func has_velocity_modifier(id: StringName) -> bool:
	for mod in velocity_modifiers:
		if mod.id == id:
			return true
	return false

func clear_velocity_modifiers() -> void:
	for mod in velocity_modifiers:
		_on_modifier_removed(mod)
	velocity_modifiers.clear()

func _on_modifier_removed(modifier: VelocityModifierEntry) -> void:
	if modifier.suppress_gravity:
		resume_gravity()
	if modifier.suppress_input:
		resume_input()
