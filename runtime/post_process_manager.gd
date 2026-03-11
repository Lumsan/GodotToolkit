extends Node
## Runtime manager for the post-process pipeline.
##
## Expected children (created by the Post-Process Pipeline preset):
##   MainScene      (SubViewport)
##   MaskViewport   (SubViewport)
##     └── MaskCamera (Camera3D)
##   PostProcess    (CanvasLayer)
##     ├── MainDisplay   (TextureRect)
##     └── ShaderOverlay (ColorRect)  ← assign your ShaderMaterial here

## Exception groups to process. Configure via the inspector.
@export var exception_groups: Array[ExceptionGroup] = []

@onready var main_viewport: SubViewport = $MainScene
@onready var mask_viewport: SubViewport = $MaskViewport
@onready var mask_camera: Camera3D = $MaskViewport/MaskCamera
@onready var main_display: TextureRect = $PostProcess/MainDisplay
@onready var shader_overlay: ColorRect = $PostProcess/ShaderOverlay

var _main_camera: Camera3D = null
var _mask_entries: Array[Dictionary] = []


func _ready() -> void:
	if Engine.is_editor_hint():
		return

	if not main_viewport or not mask_viewport or not mask_camera:
		push_error("PostProcessManager: required child nodes missing.")
		return

	call_deferred("_deferred_setup")


func _deferred_setup() -> void:
	var window_size = get_viewport().get_visible_rect().size
	main_viewport.size = Vector2i(window_size)
	mask_viewport.size = Vector2i(window_size)
	
	main_display.texture = main_viewport.get_texture()
	
	_find_main_camera()
	_build_mask_duplicates()
	_apply_shader_params()


## Rebuild all mask duplicates. Call after spawning/removing objects at runtime.
func rebuild_masks() -> void:
	for entry in _mask_entries:
		if is_instance_valid(entry["duplicate"]):
			entry["duplicate"].queue_free()
	_mask_entries.clear()
	_build_mask_duplicates()
	_apply_shader_params()


func _find_main_camera() -> void:
	_main_camera = main_viewport.get_camera_3d()


func _build_mask_duplicates() -> void:
	var black_mat := StandardMaterial3D.new()
	black_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black_mat.albedo_color = Color(0, 0, 0, 1)
	
	# First pass: duplicate all geometry as black occluders
	_duplicate_all_geometry(main_viewport, black_mat)
	
	# Second pass: duplicate exception group objects with their mask colors
	for group_res in exception_groups:
		if not group_res is ExceptionGroup or group_res.group_name.is_empty():
			continue

		var color := _channel_color(group_res.mask_channel)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color

		for node in get_tree().get_nodes_in_group(group_res.group_name):
			if node is MeshInstance3D:
				_add_mask_duplicate(node, mat)
			elif node is CSGShape3D:
				_add_csg_mask_duplicate(node, mat)


func _duplicate_all_geometry(node: Node, material: StandardMaterial3D) -> void:
	for child in node.get_children():
		var is_exception := false
		for group_res in exception_groups:
			if group_res is ExceptionGroup and child.is_in_group(group_res.group_name):
				is_exception = true
				break
		
		if not is_exception:
			if child is MeshInstance3D:
				var dup := MeshInstance3D.new()
				dup.name = child.name + "_occluder"
				dup.mesh = child.mesh
				dup.material_override = material
				dup.global_transform = child.global_transform
				mask_viewport.add_child(dup)
				_mask_entries.append({ "original": child, "duplicate": dup })
			elif child is CSGShape3D:
				var meshes: Array = child.get_meshes()
				if meshes.size() > 1:
					var mesh: Mesh = meshes[1]
					if mesh:
						var dup := MeshInstance3D.new()
						dup.name = child.name + "_occluder"
						dup.mesh = mesh
						dup.material_override = material
						dup.global_transform = child.global_transform
						mask_viewport.add_child(dup)
						_mask_entries.append({ "original": child, "duplicate": dup })
		
		_duplicate_all_geometry(child, material)


func _add_mask_duplicate(original: MeshInstance3D, material: StandardMaterial3D) -> void:
	var dup := MeshInstance3D.new()
	dup.name = original.name + "_mask"
	dup.mesh = original.mesh
	dup.material_override = material
	dup.global_transform = original.global_transform
	mask_viewport.add_child(dup)
	_mask_entries.append({ "original": original, "duplicate": dup })


func _add_csg_mask_duplicate(original: CSGShape3D, material: StandardMaterial3D) -> void:
	var meshes: Array = original.get_meshes()
	if meshes.is_empty():
		return
	
	var mesh: Mesh = meshes[1] if meshes.size() > 1 else null
	if not mesh:
		return
	
	var dup := MeshInstance3D.new()
	dup.name = original.name + "_mask"
	dup.mesh = mesh
	dup.material_override = material
	dup.global_transform = original.global_transform
	mask_viewport.add_child(dup)
	_mask_entries.append({ "original": original, "duplicate": dup })


func _apply_shader_params() -> void:
	if not shader_overlay.material is ShaderMaterial:
		return

	var mat: ShaderMaterial = shader_overlay.material
	mat.set_shader_parameter("mask_texture", mask_viewport.get_texture())

	var bypass := [false, false, false]
	for g in exception_groups:
		if g is ExceptionGroup and g.bypass_main_shader:
			if g.mask_channel >= 0 and g.mask_channel <= 2:
				bypass[g.mask_channel] = true

	mat.set_shader_parameter("bypass_r", bypass[0])
	mat.set_shader_parameter("bypass_g", bypass[1])
	mat.set_shader_parameter("bypass_b", bypass[2])


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_sync_sizes()
	_sync_camera()
	_sync_masks()


func _sync_sizes() -> void:
	var s := Vector2i(get_viewport().get_visible_rect().size)
	if s.x <= 0 or s.y <= 0:
		return
	if main_viewport.size != s:
		main_viewport.size = s
	if mask_viewport.size != s:
		mask_viewport.size = s


func _sync_camera() -> void:
	var current := main_viewport.get_camera_3d()
	if current != _main_camera:
		_main_camera = current
	if not _main_camera or not mask_camera:
		return

	mask_camera.global_transform = _main_camera.global_transform
	mask_camera.fov = _main_camera.fov
	mask_camera.near = _main_camera.near
	mask_camera.far = _main_camera.far
	mask_camera.projection = _main_camera.projection
	mask_camera.keep_aspect = _main_camera.keep_aspect
	if _main_camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		mask_camera.size = _main_camera.size


func _sync_masks() -> void:
	var i := _mask_entries.size() - 1
	while i >= 0:
		var orig: Node3D = _mask_entries[i]["original"]
		var dup: MeshInstance3D = _mask_entries[i]["duplicate"]

		if not is_instance_valid(orig) or not is_instance_valid(dup):
			if is_instance_valid(dup):
				dup.queue_free()
			_mask_entries.remove_at(i)
		else:
			dup.global_transform = orig.global_transform
			dup.visible = orig.is_visible_in_tree()
		i -= 1


func _input(event: InputEvent) -> void:
	if main_viewport:
		main_viewport.push_input(event)


static func _channel_color(channel: int) -> Color:
	match channel:
		0: return Color(1, 0, 0)
		1: return Color(0, 1, 0)
		2: return Color(0, 0, 1)
		_: return Color(1, 0, 0)
