@tool
extends Window

const PRESETS_PATH := "res://Toolkit/GodotToolkit/presets/"

var _presets: Array = []
var _selected_index: int = -1

var _preset_list: ItemList
var _desc_label: RichTextLabel
var _status_label: Label


func _ready() -> void:
	title = "Scene Setup Tool"
	min_size = Vector2i(520, 480)
	close_requested.connect(queue_free)
	_build_ui()
	_scan_presets()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var title_label := Label.new()
	title_label.text = "Scene Setup Tool"
	title_label.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title_label)

	vbox.add_child(HSeparator.new())

	var list_label := Label.new()
	list_label.text = "Available Presets:"
	vbox.add_child(list_label)

	_preset_list = ItemList.new()
	_preset_list.custom_minimum_size = Vector2(0, 140)
	_preset_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preset_list.item_selected.connect(_on_preset_selected)
	vbox.add_child(_preset_list)

	_desc_label = RichTextLabel.new()
	_desc_label.custom_minimum_size = Vector2(0, 80)
	_desc_label.bbcode_enabled = true
	_desc_label.fit_content = true
	_desc_label.text = "[i]Select a preset to see its description.[/i]"
	vbox.add_child(_desc_label)

	vbox.add_child(HSeparator.new())

	var btn_box := HBoxContainer.new()
	btn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_box.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_box)

	var new_btn := Button.new()
	new_btn.text = "Create New Scene"
	new_btn.pressed.connect(_on_new_scene_pressed)
	btn_box.add_child(new_btn)

	var inject_btn := Button.new()
	inject_btn.text = "Inject into Current Scene"
	inject_btn.pressed.connect(_on_inject_pressed)
	btn_box.add_child(inject_btn)

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color.YELLOW)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_status_label)


func _scan_presets() -> void:
	var dir := DirAccess.open(PRESETS_PATH)
	if not dir:
		_set_status("Could not open: " + PRESETS_PATH)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".gd") and file_name != "base_preset.gd":
			var script = load(PRESETS_PATH + file_name)
			if script:
				var instance = script.new()
				if instance.has_method("get_preset_name") \
						and instance.has_method("build_new_scene"):
					_presets.append(instance)
					_preset_list.add_item(instance.get_preset_name())
		file_name = dir.get_next()
	dir.list_dir_end()

	if _presets.is_empty():
		_set_status("No presets found in " + PRESETS_PATH)


func _on_preset_selected(index: int) -> void:
	_selected_index = index
	if index >= 0 and index < _presets.size():
		_desc_label.text = _presets[index].get_description()
	_status_label.text = ""


func _on_new_scene_pressed() -> void:
	if _selected_index < 0:
		_set_status("Select a preset first.")
		return

	var preset = _presets[_selected_index]
	var root: Node = preset.build_new_scene()
	if not root:
		_set_status("Preset failed to build scene.")
		return

	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.add_filter("*.tscn", "Godot Scene")
	dialog.current_dir = "res://"

	dialog.file_selected.connect(func(path: String) -> void:
		var packed := PackedScene.new()
		var err := packed.pack(root)
		if err != OK:
			_set_status("Failed to pack scene: " + error_string(err))
			root.queue_free()
			dialog.queue_free()
			return

		err = ResourceSaver.save(packed, path)
		if err != OK:
			_set_status("Failed to save: " + error_string(err))
			root.queue_free()
			dialog.queue_free()
			return

		root.queue_free()
		dialog.queue_free()
		EditorInterface.open_scene_from_path(path)
		_set_status("Scene created: " + path)
		_close_after_delay()
	)

	dialog.canceled.connect(func() -> void:
		root.queue_free()
		dialog.queue_free()
	)

	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))


func _on_inject_pressed() -> void:
	if _selected_index < 0:
		_set_status("Select a preset first.")
		return

	var root := EditorInterface.get_edited_scene_root()
	if not root:
		_set_status("No scene is currently open.")
		return

	var had_script := root.get_script() != null
	var preset = _presets[_selected_index]
	var success: bool = preset.inject_into_current_scene(root)

	if success:
		var msg := "Injected successfully. Save the scene."
		if had_script:
			msg += "\nNote: the root node's previous script was replaced."
		_set_status(msg)
		_close_after_delay()
	else:
		_set_status("Injection failed.")


func _set_status(msg: String) -> void:
	_status_label.text = msg


func _close_after_delay() -> void:
	await get_tree().create_timer(2.0).timeout
	queue_free()
