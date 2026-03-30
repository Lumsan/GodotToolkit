@tool
extends Node3D
class_name FractureCluster

## One fracture event's fragments plus runtime activation settings.

# ============================================================
# IDENTITY
# ============================================================
@export var cluster_id: int = -1

# ============================================================
# ACTIVATION MODE
# ============================================================
enum ActivationMode {
	IMMEDIATE,
	DELAYED,
	ON_SIGNAL,
	ON_TRIGGER,
}

@export_group("Activation")
@export var auto_activate_on_ready: bool = true
@export var activation_mode: ActivationMode = ActivationMode.IMMEDIATE
@export var activation_delay: float = 0.0
@export var trigger_area_path: NodePath = NodePath()

# ============================================================
# REMAINDER
# ============================================================
@export_group("Remainder")
@export var hide_remainder_on_activate: bool = false

# ============================================================
# FORCE
# ============================================================
@export_group("Force")
@export var force_type: int = PhysicsLayer.ForceType.EXPLOSION
@export var force_magnitude: float = 80.0
@export var force_direction: Vector3 = Vector3.FORWARD

# ============================================================
# FRAGMENT INTERACTION
# ============================================================
enum FragmentInteraction {
	SOLID,          ## Player cannot move fragments
	PUSHABLE,       ## Player can push fragments (fragments have mass)
	NO_COLLISION,   ## Player passes through fragments
}

@export_group("Interaction")
@export var fragment_interaction: FragmentInteraction = FragmentInteraction.SOLID
@export var fragment_mass_multiplier: float = 1.0  ## Scale fragment mass (higher = harder to push)
@export var freeze_rotation_after_delay: bool = true
@export var rotation_freeze_delay: float = 1.0

# ============================================================
# FRAGMENT CLEARING
# ============================================================
@export_group("Fragment Clearing")
@export var delayed_collision: bool = false
@export var collision_delay: float = 0.15

# ============================================================
# SETTLING
# ============================================================
@export_group("Settling")
@export var settle_mode: int = PhysicsLayer.SettleMode.PERSIST
@export var fade_time: float = 5.0
@export var post_density: float = 1.0

# ============================================================
# ORIGIN
# ============================================================
@export_group("Origin")
@export var use_cluster_position_as_origin: bool = true
@export var explicit_explosion_origin: Vector3 = Vector3.ZERO

# ============================================================
# SIGNALS
# ============================================================
signal activation_requested
signal activated

# ============================================================
# STATE
# ============================================================
var _activated: bool = false
var _trigger_connected: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if auto_activate_on_ready:
		_handle_activation()


func _handle_activation() -> void:
	match activation_mode:
		ActivationMode.IMMEDIATE:
			activate()

		ActivationMode.DELAYED:
			if activation_delay > 0.0:
				await get_tree().create_timer(activation_delay).timeout
			activate()

		ActivationMode.ON_SIGNAL:
			if not _activated:
				activation_requested.connect(_on_activation_requested, CONNECT_ONE_SHOT)

		ActivationMode.ON_TRIGGER:
			_setup_trigger()


func _setup_trigger() -> void:
	if trigger_area_path == NodePath():
		push_warning("FractureCluster '%s': ON_TRIGGER mode but no trigger_area_path set" % name)
		return

	var trigger := get_node_or_null(trigger_area_path)
	if trigger is Area3D:
		if not _trigger_connected:
			trigger.body_entered.connect(_on_trigger_body_entered)
			_trigger_connected = true
	else:
		push_warning("FractureCluster '%s': trigger_area_path '%s' is not an Area3D" % [
			name, trigger_area_path
		])


func _on_trigger_body_entered(_body: Node3D) -> void:
	activate()


func _on_activation_requested() -> void:
	activate()


func request_activation() -> void:
	if _activated:
		return
	activation_requested.emit()
	if activation_mode != ActivationMode.ON_SIGNAL:
		activate()


func activate() -> void:
	if _activated:
		return
	_activated = true

	var origin: Vector3 = global_position if use_cluster_position_as_origin else explicit_explosion_origin
	var bodies: Array = get_fragment_bodies()

	if hide_remainder_on_activate:
		var parent := get_parent()
		if parent is FracturedMesh:
			var fm: FracturedMesh = parent
			if fm.remainder_node != null and is_instance_valid(fm.remainder_node):
				fm.remainder_node.visible = false

	for body_obj in bodies:
		var body: RigidBody3D = body_obj
		if body == null or not is_instance_valid(body):
			continue

		body.freeze = false
		body.sleeping = false

		# Apply mass multiplier
		body.mass = body.mass * fragment_mass_multiplier

		# Apply interaction mode FIRST
		match fragment_interaction:
			FragmentInteraction.SOLID:
				body.collision_layer = 16  # Layer 5
				body.collision_mask = 1 | 2 | 16

				if freeze_rotation_after_delay:
					_schedule_rotation_freeze(body, rotation_freeze_delay)

			FragmentInteraction.PUSHABLE:
				body.collision_layer = 32  # Layer 6
				body.collision_mask = 1 | 2 | 32

			FragmentInteraction.NO_COLLISION:
				body.collision_layer = 64  # Layer 7
				body.collision_mask = 1 | 64

		# Store mask AFTER interaction mode is applied
		body.set_meta("_original_collision_mask", body.collision_mask)

		# THEN apply delayed collision on top
		if delayed_collision:
			body.collision_mask &= ~1  # Remove environment

		var impulse: Vector3 = PhysicsLayer._compute_impulse(
			body.global_position,
			force_type,
			force_magnitude,
			force_direction,
			origin
		)

		body.apply_central_impulse(impulse)
		body.angular_velocity = Vector3(
			randf_range(-8.0, 8.0),
			randf_range(-8.0, 8.0),
			randf_range(-8.0, 8.0)
		)

	if settle_mode == PhysicsLayer.SettleMode.FADE:
		for body_obj in bodies:
			var body: RigidBody3D = body_obj
			if body == null or not is_instance_valid(body):
				continue
			PhysicsLayer._schedule_fade(body, fade_time)

	PhysicsLayer._schedule_post_density(bodies, post_density)

	if delayed_collision:
		await get_tree().create_timer(collision_delay).timeout

		for body_obj in bodies:
			var body: RigidBody3D = body_obj
			if body == null or not is_instance_valid(body):
				continue
			var original_mask: int = body.get_meta("_original_collision_mask", 1 | 2 | 16)
			body.collision_mask = original_mask

	activated.emit()


func reset_activation() -> void:
	_activated = false

	if activation_mode == ActivationMode.ON_SIGNAL:
		if not activation_requested.is_connected(_on_activation_requested):
			activation_requested.connect(_on_activation_requested, CONNECT_ONE_SHOT)


func get_fragment_bodies() -> Array:
	var bodies: Array = []
	for child in get_children():
		if child is RigidBody3D:
			bodies.append(child)
	return bodies


func apply_runtime_settings(settings: Dictionary) -> void:
	if settings.has("force_type"):
		force_type = settings["force_type"]
	if settings.has("force_magnitude"):
		force_magnitude = settings["force_magnitude"]
	if settings.has("force_direction"):
		force_direction = settings["force_direction"]
	if settings.has("settle_mode"):
		settle_mode = settings["settle_mode"]
	if settings.has("fade_time"):
		fade_time = settings["fade_time"]
	if settings.has("post_density"):
		post_density = settings["post_density"]
	if settings.has("auto_activate_on_ready"):
		auto_activate_on_ready = settings["auto_activate_on_ready"]
	if settings.has("hide_remainder_on_activate"):
		hide_remainder_on_activate = settings["hide_remainder_on_activate"]
	if settings.has("use_cluster_position_as_origin"):
		use_cluster_position_as_origin = settings["use_cluster_position_as_origin"]
	if settings.has("explicit_explosion_origin"):
		explicit_explosion_origin = settings["explicit_explosion_origin"]
	if settings.has("activation_mode"):
		activation_mode = settings["activation_mode"]
	if settings.has("activation_delay"):
		activation_delay = settings["activation_delay"]
	if settings.has("delayed_collision"):
		delayed_collision = settings["delayed_collision"]
	if settings.has("collision_delay"):
		collision_delay = settings["collision_delay"]
	if settings.has("fragment_interaction"):
		fragment_interaction = settings["fragment_interaction"]
	if settings.has("fragment_mass_multiplier"):
		fragment_mass_multiplier = settings["fragment_mass_multiplier"]
	if settings.has("freeze_rotation_after_delay"):
		freeze_rotation_after_delay = settings["freeze_rotation_after_delay"]
	if settings.has("rotation_freeze_delay"):
		rotation_freeze_delay = settings["rotation_freeze_delay"]


func get_runtime_settings() -> Dictionary:
	return {
		"force_type": force_type,
		"force_magnitude": force_magnitude,
		"force_direction": force_direction,
		"settle_mode": settle_mode,
		"fade_time": fade_time,
		"post_density": post_density,
		"auto_activate_on_ready": auto_activate_on_ready,
		"hide_remainder_on_activate": hide_remainder_on_activate,
		"use_cluster_position_as_origin": use_cluster_position_as_origin,
		"explicit_explosion_origin": explicit_explosion_origin,
		"activation_mode": activation_mode,
		"activation_delay": activation_delay,
		"delayed_collision": delayed_collision,
		"collision_delay": collision_delay,
		"fragment_interaction": fragment_interaction,
		"fragment_mass_multiplier": fragment_mass_multiplier,
		"freeze_rotation_after_delay": freeze_rotation_after_delay,
		"rotation_freeze_delay": rotation_freeze_delay,
	}

func _schedule_rotation_freeze(body: RigidBody3D, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if body == null or not is_instance_valid(body):
		return
	body.lock_rotation = true
	body.angular_velocity = Vector3.ZERO
