@tool
class_name FractureDebug
extends RefCounted

const DEBUG_FRACTURE := true

const LOG_EDITOR := true
const LOG_REGION := true
const LOG_EXTRACT := true
const LOG_CLIP := true
const LOG_VORONOI := true
const LOG_CAPS := true
const LOG_BUILD := true
const LOG_PHYSICS := true
const LOG_UNDO := true

static func print_log(category: String, message: String) -> void:
	if not DEBUG_FRACTURE:
		return
	print("[FRACTURE:%s] %s" % [category, message])

static func editor(message: String) -> void:
	if DEBUG_FRACTURE and LOG_EDITOR:
		print_log("EDITOR", message)

static func region(message: String) -> void:
	if DEBUG_FRACTURE and LOG_REGION:
		print_log("REGION", message)

static func extract(message: String) -> void:
	if DEBUG_FRACTURE and LOG_EXTRACT:
		print_log("EXTRACT", message)

static func clip(message: String) -> void:
	if DEBUG_FRACTURE and LOG_CLIP:
		print_log("CLIP", message)

static func voronoi(message: String) -> void:
	if DEBUG_FRACTURE and LOG_VORONOI:
		print_log("VORONOI", message)

static func caps(message: String) -> void:
	if DEBUG_FRACTURE and LOG_CAPS:
		print_log("CAPS", message)

static func build(message: String) -> void:
	if DEBUG_FRACTURE and LOG_BUILD:
		print_log("BUILD", message)

static func physics(message: String) -> void:
	if DEBUG_FRACTURE and LOG_PHYSICS:
		print_log("PHYSICS", message)

static func undo(message: String) -> void:
	if DEBUG_FRACTURE and LOG_UNDO:
		print_log("UNDO", message)
