extends RefCounted
## Base class for scene setup presets.
## Drop new presets into toolkit/presets/ and they appear in the setup window.

## Display name shown in the preset list.
func get_preset_name() -> String:
	return "Unnamed Preset"

## Description shown when the preset is selected.
func get_description() -> String:
	return "No description provided."

## Build and return a complete scene tree (standalone, not in the editor tree).
## Every child node must have .owner set to the returned root.
func build_new_scene() -> Node:
	push_error("build_new_scene() not implemented.")
	return null

## Inject this preset's structure into an already-open scene.
## Returns true on success.
func inject_into_current_scene(_root: Node) -> bool:
	push_error("inject_into_current_scene() not implemented.")
	return false
