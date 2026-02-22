# components/interaction/interactable.gd
class_name Interactable
extends Node

@export var interaction_prompt: String = "Interact"
@export var enabled: bool = true
@export var one_shot: bool = false

@export_group("Aim Assist")
## If true, player doesn't need to look exactly at this object
@export var use_aim_assist: bool = false
## How many degrees off-center the player can look
@export_range(1.0, 45.0) var aim_assist_angle: float = 10.0

@export_group("Angle Restriction")
## If > 0, player must be within this angle of the object's forward direction
@export_range(0.0, 180.0) var max_interaction_angle: float = 0.0

@export_group("Highlight")
@export var use_highlight: bool = false
@export var highlight_color: Color = Color(1.0, 1.0, 0.5, 1.0)

var is_focused: bool = false
var _has_been_used: bool = false
var _original_materials: Dictionary = {}

signal on_interacted(interactor: Node)
signal on_focused
signal on_unfocused

func can_interact() -> bool:
	if not enabled:
		return false
	if one_shot and _has_been_used:
		return false
	return true

func interact(interactor: Node) -> void:
	if not can_interact():
		return
	_has_been_used = true
	on_interacted.emit(interactor)

func set_focused(value: bool) -> void:
	if is_focused == value:
		return

	is_focused = value
	if value:
		if use_highlight:
			_apply_highlight()
		on_focused.emit()
	else:
		if use_highlight:
			_remove_highlight()
		on_unfocused.emit()

func reset() -> void:
	_has_been_used = false

func get_world_position() -> Vector3:
	var parent := get_parent() as Node3D
	if parent:
		return parent.global_position
	return Vector3.ZERO

func _apply_highlight() -> void:
	var parent := get_parent()
	if not parent:
		return
	for child in parent.get_children():
		if child is MeshInstance3D:
			var mat: Material = child.get_surface_override_material(0)
			if mat:
				_original_materials[child] = mat
				var highlight_mat: Material = mat.duplicate()
				if highlight_mat is StandardMaterial3D:
					var std_mat := highlight_mat as StandardMaterial3D
					std_mat.emission_enabled = true
					std_mat.emission = highlight_color
					std_mat.emission_energy_multiplier = 0.3
				child.set_surface_override_material(0, highlight_mat)

func _remove_highlight() -> void:
	for child: MeshInstance3D in _original_materials:
		if is_instance_valid(child):
			child.set_surface_override_material(0, _original_materials[child])
	_original_materials.clear()
