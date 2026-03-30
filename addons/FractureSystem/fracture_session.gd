@tool
class_name FractureSession
extends RefCounted

## Session-scoped state for editor workflow.

var active: bool = false
var current_region: FractureRegion = null

# Undo stack: each entry tracks what was created so it can be reversed
# Entry format:
# {
#     "cluster_ids": [{"fractured_mesh": FracturedMesh, "cluster_id": int}],
#     "originals": [MeshInstance3D],
#     "fractured_meshes": [FracturedMesh]
# }
var undo_stack: Array = []


func start() -> void:
	active = true
	current_region = null
	undo_stack.clear()
	FractureDebug.editor("Fracture session started")


func finish() -> void:
	active = false
	if current_region != null and is_instance_valid(current_region):
		if current_region.get_parent() != null:
			current_region.queue_free()
	current_region = null
	undo_stack.clear()
	FractureDebug.editor("Fracture session finished and cleared")


func push_undo(entry: Dictionary) -> void:
	undo_stack.append(entry)
	FractureDebug.undo("Undo entry pushed. Stack size=%d" % undo_stack.size())


func pop_undo() -> Dictionary:
	if undo_stack.is_empty():
		FractureDebug.undo("Undo stack empty")
		return {}
	var entry: Dictionary = undo_stack.pop_back()
	FractureDebug.undo("Undo entry popped. Remaining=%d" % undo_stack.size())
	return entry
