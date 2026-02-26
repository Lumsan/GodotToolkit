class_name SaveSystemClass extends Node

const SAVE_PATH := "user://save.json"


func save_game() -> Error:
	var save_data := {}
	
	for saveable in get_tree().get_nodes_in_group("saveable"):
		if saveable.has_method("get_save_data"):
			save_data[saveable.save_id] = saveable.get_save_data()
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		return FileAccess.get_open_error()
	
	file.store_string(JSON.stringify(save_data, "\t"))
	return OK


func load_game() -> Error:
	if not FileAccess.file_exists(SAVE_PATH):
		return ERR_FILE_NOT_FOUND
	
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return FileAccess.get_open_error()
	
	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		return error
	
	var save_data: Dictionary = json.data
	
	for saveable in get_tree().get_nodes_in_group("saveable"):
		if saveable.has_method("load_save_data") and save_data.has(saveable.save_id):
			saveable.load_save_data(save_data[saveable.save_id])
	
	return OK


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> Error:
	if has_save():
		return DirAccess.remove_absolute(SAVE_PATH)
	return OK
