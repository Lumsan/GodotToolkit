# components/state/character_state.gd
## Base class for character states.
class_name CharacterState
extends Node

var state_machine: CharacterStateMachine

func enter(_previous_state: StringName) -> void:
	pass

func exit(_next_state: StringName) -> void:
	pass

## Return a state name to transition, or &"" to stay.
func process_physics(_data: CharacterData, _delta: float) -> StringName:
	return &""
