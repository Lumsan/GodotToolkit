class_name VelocityModifierZone
extends Area3D

@export var modifier_id: StringName = &"zone"
@export var modifier_velocity: Vector3 = Vector3.ZERO
@export var modifier_mode: VelocityModifierEntry.Mode = VelocityModifierEntry.Mode.ADDITIVE
@export var modifier_affects: VelocityModifierEntry.Affects = VelocityModifierEntry.Affects.BOTH
@export var suppress_gravity: bool = false
@export var suppress_input: bool = false

@export_group("Time")
@export var time_mode: VelocityModifierEntry.TimeMode = VelocityModifierEntry.TimeMode.CONSTANT
@export var duration: float = 0.0
@export var curve: Curve
@export var loop: bool = false

@export_group("Space")
## If true, velocity is transformed by the zone's rotation
@export var use_local_space: bool = false

var _active_entries: Dictionary = {}  # body_instance_id -> entry_id

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	var data := _get_character_data(body)
	if not data:
		print("no data")
		return

	var entry := VelocityModifierEntry.new()
	var unique_id := StringName(str(modifier_id) + "_" + str(get_instance_id()))
	entry.id = unique_id
	entry.velocity = _get_velocity()
	entry.mode = modifier_mode
	entry.affects = modifier_affects
	entry.suppress_gravity = suppress_gravity
	entry.suppress_input = suppress_input
	entry.time_mode = time_mode
	entry.duration = duration
	entry.loop = loop
	if curve:
		entry.curve = curve

	data.add_velocity_modifier(entry)
	_active_entries[body.get_instance_id()] = unique_id

func _on_body_exited(body: Node3D) -> void:
	var body_id := body.get_instance_id()
	if body_id not in _active_entries:
		return

	var data := _get_character_data(body)
	if data:
		data.remove_velocity_modifier(_active_entries[body_id])
	_active_entries.erase(body_id)

func _get_velocity() -> Vector3:
	if use_local_space:
		return global_basis * modifier_velocity
	return modifier_velocity

func _get_character_data(body: Node3D) -> CharacterData:
	if body is ToolkitCharacterBody:
		return (body as ToolkitCharacterBody).data
	if body.has_method("get_character_data"):
		return body.get_character_data()
	return null
