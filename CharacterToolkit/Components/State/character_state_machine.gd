# components/state/character_state_machine.gd
class_name CharacterStateMachine
extends Node

@export var initial_state: NodePath

var current_state: CharacterState
var states: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is CharacterState:
			states[child.name] = child
			child.state_machine = self

	if initial_state:
		current_state = get_node(initial_state)
	elif states.size() > 0:
		current_state = states.values()[0]

	if current_state:
		current_state.enter(&"")

func process_input(data: CharacterData, delta: float) -> void:
	if current_state and current_state.has_method("process_input"):
		current_state.process_input(data, delta)

func process_physics(data: CharacterData, delta: float) -> void:
	if current_state:
		var next := current_state.process_physics(data, delta)
		if next != &"":
			transition_to(next, data)

func transition_to(state_name: StringName, data: CharacterData) -> void:
	if not states.has(state_name):
		push_warning("State '%s' not found" % state_name)
		return

	var old_state := current_state
	current_state.exit(state_name)
	current_state = states[state_name]
	current_state.enter(old_state.name if old_state else &"")
	data.state_changed.emit(
		old_state.name if old_state else &"",
		state_name
	)
