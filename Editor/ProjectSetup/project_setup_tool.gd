@tool
extends EditorScript

func _run() -> void:
	var window := preload("res://GodotToolkit/Editor/ProjectSetup/project_setup_window.gd").new()
	EditorInterface.get_base_control().add_child(window)
	window.popup_centered(Vector2i(560, 620))
