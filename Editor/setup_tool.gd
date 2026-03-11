@tool
extends EditorScript

func _run() -> void:
	var window_script := load("res://Toolkit/GodotToolkit/Editor/setup_window.gd")
	var window: Window = window_script.new()
	EditorInterface.get_base_control().add_child(window)
	window.popup_centered(Vector2i(520, 480))
