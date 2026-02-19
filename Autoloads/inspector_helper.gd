# core/inspector_helper.gd
## Helper for building clean _get_property_list() arrays.
## Usage:
##   var p := InspectorHelper.new()
##   p.prop("speed", TYPE_FLOAT, 5.0)
##   p.prop("name", TYPE_STRING, "Player")
##   return p.build()
class_name InspectorHelper
extends RefCounted

var _properties: Array[Dictionary] = []
var _current_group: String = ""
var _current_subgroup: String = ""

# ── Groups ──

func group(name: String, prefix: String = "") -> InspectorHelper:
	_properties.append({
		"name": name,
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_GROUP,
		"hint_string": prefix
	})
	_current_group = name
	return self

func subgroup(name: String, prefix: String = "") -> InspectorHelper:
	_properties.append({
		"name": name,
		"type": TYPE_NIL,
		"usage": PROPERTY_USAGE_SUBGROUP,
		"hint_string": prefix
	})
	_current_subgroup = name
	return self

# ── Core property adder ──

func prop(name: String, type: int, default_value: Variant = null,
		hint: int = PROPERTY_HINT_NONE, hint_string: String = "",
		usage: int = PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_SCRIPT_VARIABLE
	) -> InspectorHelper:
	_properties.append({
		"name": name,
		"type": type,
		"usage": usage,
		"hint": hint,
		"hint_string": hint_string,
	})
	return self

# ── Typed shortcuts ──

func bool_prop(name: String) -> InspectorHelper:
	return prop(name, TYPE_BOOL)

func float_prop(name: String, min_val: float = 0.0, max_val: float = 100.0,
		step: float = 0.01) -> InspectorHelper:
	return prop(name, TYPE_FLOAT, null,
		PROPERTY_HINT_RANGE, "%s,%s,%s" % [min_val, max_val, step])

func int_prop(name: String, min_val: int = 0, max_val: int = 100) -> InspectorHelper:
	return prop(name, TYPE_INT, null,
		PROPERTY_HINT_RANGE, "%s,%s" % [min_val, max_val])

func string_prop(name: String) -> InspectorHelper:
	return prop(name, TYPE_STRING)

func vector3_prop(name: String) -> InspectorHelper:
	return prop(name, TYPE_VECTOR3)

func vector2_prop(name: String) -> InspectorHelper:
	return prop(name, TYPE_VECTOR2)

func color_prop(name: String) -> InspectorHelper:
	return prop(name, TYPE_COLOR)

func enum_prop(name: String, options: String) -> InspectorHelper:
	return prop(name, TYPE_INT, null, PROPERTY_HINT_ENUM, options)

func node_path_prop(name: String) -> InspectorHelper:
	return prop(name, TYPE_NODE_PATH)

func resource_prop(name: String, resource_type: String = "Resource") -> InspectorHelper:
	return prop(name, TYPE_OBJECT, null,
		PROPERTY_HINT_RESOURCE_TYPE, resource_type)

func flags_prop(name: String, options: String) -> InspectorHelper:
	return prop(name, TYPE_INT, null, PROPERTY_HINT_FLAGS, options)

# ── Build ──

func build() -> Array[Dictionary]:
	return _properties
