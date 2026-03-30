@tool
extends EditorPlugin

func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_G:
			if _bring_selected_node_to_camera():
				get_viewport().set_input_as_handled()


func _bring_selected_node_to_camera(distance: float = 17.5) -> bool:
	var selection: EditorSelection = get_editor_interface().get_selection()
	if selection == null:
		return false

	var selected_nodes: Array = selection.get_selected_nodes()
	if selected_nodes.is_empty():
		return false

	var node: Node = selected_nodes[0]
	if not (node is Node3D):
		return false

	var node3d: Node3D = node as Node3D

	var editor_viewport = get_editor_interface().get_editor_viewport_3d()
	if editor_viewport == null:
		push_warning("Editor Utils: No 3D editor viewport available.")
		return false

	var cam: Camera3D = editor_viewport.get_camera_3d()
	if cam == null:
		push_warning("Editor Utils: No active editor camera found.")
		return false

	var cam_transform: Transform3D = cam.global_transform
	var forward: Vector3 = -cam_transform.basis.z.normalized()
	var target_pos: Vector3 = cam_transform.origin + forward * distance

	node3d.global_position = target_pos

	print("Editor Utils: moved '%s' to %s in front of camera." % [
		node3d.name,
		target_pos
	])

	return true
