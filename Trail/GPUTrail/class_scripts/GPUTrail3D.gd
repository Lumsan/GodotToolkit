# Based on GPUTrail by celyk
# https://github.com/celyk/GPUTrail
# MIT License

@tool
@icon("../bounce.svg")
class_name GPUTrail3D extends GPUParticles3D

@export var length : int = 100 : set = _set_length
@export var length_seconds : float : set = _set_length
@export var active : bool = true : set = _set_active

func _set_active(value):
	active = value
	var mat = process_material as ShaderMaterial
	if mat == null or not is_inside_tree():
		return
	if not value:
		mat.set_shader_parameter("active", false)
		mat.set_shader_parameter("frozen_transform", global_transform)
	else:
		mat.set_shader_parameter("active", true)
		restart()

@export_category("Emission Shape")

enum EmissionShape { LINE, PATH }
@export var emission_shape : EmissionShape = EmissionShape.LINE : set = _set_emission_shape
@export var emission_path : Path3D : set = _set_emission_path
@export_range(2, 128) var path_segments : int = 16 : set = _set_path_segments
@export_range(2, 256) var path_resolution : int = 64 : set = _set_path_resolution
@export var ribbon_width : float = 0.05 : set = _set_ribbon_width

@export_category("Trail Layers")
@export var trail_layers : Array[TrailLayer] = [] : set = _set_trail_layers

func _set_trail_layers(value):
	trail_layers = value
	if not _defaults_have_been_set:
		return
	_rebuild_layers()

func _rebuild_layers():
	draw_passes = 4
	var count := mini(trail_layers.size(), 4)

	for i in range(count):
		var mat := ShaderMaterial.new()
		var base := _get_addon_path()
		var shader_path : String
		match trail_layers[i].blend_mode:
			TrailLayer.BlendMode.ADD:
				shader_path = base + "/shaders/trail_draw_pass_add.gdshader"
			TrailLayer.BlendMode.SUB:
				shader_path = base + "/shaders/trail_draw_pass_sub.gdshader"
			TrailLayer.BlendMode.MUL:
				shader_path = base + "/shaders/trail_draw_pass_mul.gdshader"
			TrailLayer.BlendMode.PREMUL_ALPHA:
				shader_path = base + "/shaders/trail_draw_pass_premul_alpha.gdshader"
			_:
				shader_path = base + "/shaders/trail_draw_pass_mix.gdshader"
		mat.shader = load(shader_path)
		mat.resource_local_to_scene = true

		_apply_mesh_tweaks_to_material(mat)

		if trail_layers[i] != null:
			trail_layers[i].apply_to_material(mat)

		mat.set_shader_parameter("trail_length", float(length))
		mat.set_shader_parameter("ribbon_width", ribbon_width)
		mat.set_shader_parameter("use_path_emission", emission_shape == EmissionShape.PATH)

		var mesh : Mesh
		if emission_shape == EmissionShape.PATH and path_segments >= 2:
			mesh = _create_ribbon_mesh(path_segments)
			(mesh as ArrayMesh).surface_set_material(0, mat)
		else:
			var quad := QuadMesh.new()
			quad.material = mat
			mesh = quad

		match i:
			0: draw_pass_1 = mesh
			1: draw_pass_2 = mesh
			2: draw_pass_3 = mesh
			3: draw_pass_4 = mesh

	for i in range(count, 4):
		match i:
			0: draw_pass_1 = null
			1: draw_pass_2 = null
			2: draw_pass_3 = null
			3: draw_pass_4 = null

	_layer_materials.clear()
	for i in range(count):
		var m : ShaderMaterial
		match i:
			0: m = _get_draw_pass_material(draw_pass_1)
			1: m = _get_draw_pass_material(draw_pass_2)
			2: m = _get_draw_pass_material(draw_pass_3)
			3: m = _get_draw_pass_material(draw_pass_4)
		if m:
			_layer_materials.append(m)
	
	_update_all_layer_flags()
	if emission_shape == EmissionShape.PATH and _path_texture != null:
		for mat in _layer_materials:
			mat.set_shader_parameter("path_texture", _path_texture)
			mat.set_shader_parameter("path_point_count", path_resolution)
	if emission_shape == EmissionShape.PATH:
		_bake_path_texture()
	
	print("_layer_materials count: %d" % _layer_materials.size())
	for i in range(_layer_materials.size()):
		var mat = _layer_materials[i]
		print("  layer %d - color_ramp: %s" % [i, mat.get_shader_parameter("color_ramp")])
		print("  layer %d - tex: %s" % [i, mat.get_shader_parameter("tex")])
		print("  layer %d - flags: %s" % [i, mat.get_shader_parameter("flags")])
		print("  layer %d material id: %s" % [i, _layer_materials[i].get_instance_id()])

func _get_draw_pass_material(mesh) -> ShaderMaterial:
	if mesh == null:
		return null
	if mesh is PrimitiveMesh:
		return mesh.material as ShaderMaterial
	if mesh is ArrayMesh and mesh.get_surface_count() > 0:
		return mesh.surface_get_material(0) as ShaderMaterial
	return null

func _apply_mesh_tweaks_to_material(mat : ShaderMaterial) -> void:
	var f := 0
	if billboard: f |= 4
	if dewiggle: f |= 8
	if snap_to_transform: f |= 16
	if clip_overlaps: f |= 32
	mat.set_shader_parameter("flags", f)

@export_category("Mesh Tweaks")
@export var billboard := false : set = _set_billboard
@export var dewiggle := true : set = _set_dewiggle
@export var clip_overlaps := true : set = _set_clip_overlaps
@export var snap_to_transform := false : set = _set_snap_to_transform

func _set_billboard(value):
	billboard = value
	if not _defaults_have_been_set: return
	_update_all_layer_flags()
	if value and is_inside_tree():
		_update_billboard_transform(global_transform.basis[0])
	restart()

func _set_dewiggle(value):
	dewiggle = value
	if not _defaults_have_been_set: return
	_update_all_layer_flags()

func _set_clip_overlaps(value):
	clip_overlaps = value
	if not _defaults_have_been_set: return
	_update_all_layer_flags()

func _set_snap_to_transform(value):
	snap_to_transform = value
	if not _defaults_have_been_set: return
	_update_all_layer_flags()

func _update_all_layer_flags():
	for i in range(_layer_materials.size()):
		var mat := _layer_materials[i]
		if mat == null: continue
		var f := 0
		if billboard: f |= 4
		if dewiggle: f |= 8
		if snap_to_transform: f |= 16
		if clip_overlaps: f |= 32
		if i < trail_layers.size() and trail_layers[i] != null:
			if trail_layers[i].use_red_as_alpha: f |= 2
			if trail_layers[i].vertical_texture: f |= 1
		mat.set_shader_parameter("flags", f)

var _layer_materials : Array[ShaderMaterial] = []
var _path_texture : ImageTexture
var _path_needs_update := true
var _defaults_have_been_set := false
var _last_path_relative_xform := Transform3D.IDENTITY

func _get_property_list():
	return [{"name": "_defaults_have_been_set", "type": TYPE_BOOL, "usage": PROPERTY_USAGE_NO_EDITOR}]

func _ready():
	if not _defaults_have_been_set:
		_defaults_have_been_set = true
		explosiveness = 1
		fixed_fps = int(DisplayServer.screen_get_refresh_rate(DisplayServer.MAIN_WINDOW_ID))
		if fixed_fps <= 0:
			push_warning("Could not find screen refresh rate. Using fixed_fps = 60")
			fixed_fps = 60

		var pm := ShaderMaterial.new()
		pm.shader = load(_get_addon_path() + "/shaders/trail.gdshader")
		pm.resource_local_to_scene = true
		process_material = pm

		if trail_layers.is_empty():
			push_error("GPUTrail3D needs at least 1 TrailLayer to function!")
	else:
		var pm := ShaderMaterial.new()
		pm.shader = load(_get_addon_path() + "/shaders/trail.gdshader")
		pm.resource_local_to_scene = true
		process_material = pm

	_rebuild_layers()
	_apply_all_settings()

func _apply_all_settings():
	amount = length
	lifetime = length

	var use_path := emission_shape == EmissionShape.PATH
	process_material.set_shader_parameter("use_path_emission", use_path)

	for mat in _layer_materials:
		mat.set_shader_parameter("trail_length", float(length))
		mat.set_shader_parameter("use_path_emission", use_path)
		mat.set_shader_parameter("ribbon_width", ribbon_width)

	if use_path:
		_bake_path_texture()
		_path_needs_update = false
		if emission_path and emission_path.is_inside_tree() and is_inside_tree():
			_last_path_relative_xform = global_transform.affine_inverse() * emission_path.global_transform

	_update_all_layer_flags()
	restart()

func _create_ribbon_mesh(subdivisions: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	var rows := subdivisions + 1
	for i in range(rows):
		var v := float(i) / float(subdivisions)
		verts.append(Vector3(-0.5, v - 0.5, 0.0))
		uvs.append(Vector2(0.0, v))
		verts.append(Vector3(0.5, v - 0.5, 0.0))
		uvs.append(Vector2(1.0, v))

	for i in range(subdivisions):
		var b := i * 2
		var n := (i + 1) * 2
		indices.append(b + 0); indices.append(n + 0); indices.append(b + 1)
		indices.append(b + 1); indices.append(n + 0); indices.append(n + 1)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _set_ribbon_width(value):
	ribbon_width = max(value, 0.001)
	if not _defaults_have_been_set: return
	for mat in _layer_materials:
		mat.set_shader_parameter("ribbon_width", ribbon_width)

func _set_length(value):
	if value is int:
		length = max(value, 1)
		length_seconds = float(length) / max(fixed_fps, 1)
	elif value is float:
		length = max(int(value * max(fixed_fps, 1)), 1)
		length_seconds = float(length) / max(fixed_fps, 1)
	if _defaults_have_been_set:
		amount = length
		lifetime = length
		for mat in _layer_materials:
			mat.set_shader_parameter("trail_length", float(length))
		restart()

func _set_emission_shape(value):
	emission_shape = value
	if not _defaults_have_been_set: return
	var use_path := emission_shape == EmissionShape.PATH
	process_material.set_shader_parameter("use_path_emission", use_path)
	for mat in _layer_materials:
		mat.set_shader_parameter("use_path_emission", use_path)
	_rebuild_layers()
	if use_path:
		_bake_path_texture()
	_path_needs_update = true
	notify_property_list_changed()
	restart()
	update_gizmos()

func _set_emission_path(value):
	if emission_path and emission_path.curve:
		if emission_path.curve.changed.is_connected(_on_path_curve_changed):
			emission_path.curve.changed.disconnect(_on_path_curve_changed)
	emission_path = value
	if emission_path and emission_path.curve:
		if not emission_path.curve.changed.is_connected(_on_path_curve_changed):
			emission_path.curve.changed.connect(_on_path_curve_changed)
	_path_needs_update = true
	if _defaults_have_been_set and emission_shape == EmissionShape.PATH:
		_bake_path_texture()
		restart()

func _set_path_segments(value):
	path_segments = max(value, 2)
	if not _defaults_have_been_set: return
	_rebuild_layers()
	restart()

func _set_path_resolution(value):
	path_resolution = max(value, 2)
	_path_needs_update = true
	if _defaults_have_been_set and emission_shape == EmissionShape.PATH:
		_bake_path_texture()
		restart()

func _on_path_curve_changed():
	_path_needs_update = true

func _validate_property(property: Dictionary):
	if property.name in ["emission_path", "path_segments", "path_resolution", "ribbon_width"]:
		if emission_shape != EmissionShape.PATH:
			property.usage = PROPERTY_USAGE_NO_EDITOR

func _bake_path_texture():
	if not is_inside_tree(): return
	if not emission_path or not emission_path.curve:
		_path_texture = null
		if _defaults_have_been_set:
			for mat in _layer_materials:
				mat.set_shader_parameter("path_texture", null)
				mat.set_shader_parameter("path_point_count", 0)
		return

	var curve3d : Curve3D = emission_path.curve
	var baked_length := curve3d.get_baked_length()
	if baked_length <= 0.0: return

	var res := path_resolution
	var img := Image.create(res, 1, false, Image.FORMAT_RGBAF)

	for i in range(res):
		var t := float(i) / float(res - 1)
		var point := curve3d.sample_baked(t * baked_length)
		var world_point := emission_path.global_transform * point
		point = global_transform.affine_inverse() * world_point
		img.set_pixel(i, 0, Color(point.x, point.y, point.z, 1.0))

	if _path_texture and _path_texture.get_width() == res:
		_path_texture.update(img)
	else:
		_path_texture = ImageTexture.create_from_image(img)
		for mat in _layer_materials:
			mat.set_shader_parameter("path_texture", _path_texture)

	for mat in _layer_materials:
		mat.set_shader_parameter("path_point_count", res)

@onready var _old_pos : Vector3 = global_position
@onready var _billboard_transform : Transform3D = global_transform
var _uv_offsets : Array = []

func _process(delta):
	if snap_to_transform:
		for mat in _layer_materials:
			mat.set_shader_parameter("emmission_transform", global_transform)

	for i in range(mini(trail_layers.size(), _layer_materials.size())):
		if trail_layers[i] == null: continue
		if _uv_offsets.size() <= i:
			_uv_offsets.resize(i + 1)
			_uv_offsets[i] = Vector2.ZERO
		_uv_offsets[i] = (_uv_offsets[i] + trail_layers[i].scroll * delta).posmod(1.0)
		_layer_materials[i].set_shader_parameter("uv_offset", _uv_offsets[i])

	if emission_shape == EmissionShape.PATH:
		var do_rebake := false
		var do_restart := false

		if _path_needs_update:
			do_rebake = true
			do_restart = true
			_path_needs_update = false
		elif emission_path and emission_path.is_inside_tree():
			var rel := global_transform.affine_inverse() * emission_path.global_transform
			if not rel.is_equal_approx(_last_path_relative_xform):
				_last_path_relative_xform = rel
				do_rebake = true

		if do_rebake: _bake_path_texture()
		if do_restart: restart()

	await RenderingServer.frame_pre_draw

	if billboard:
		var delta_position := global_position - _old_pos
		if delta_position:
			var tangent := global_transform.basis[1].length() * delta_position.normalized()
			_update_billboard_transform(tangent)
		RenderingServer.instance_set_transform(get_instance(), _billboard_transform)

	_old_pos = global_position

func _update_billboard_transform(tangent : Vector3):
	_billboard_transform = global_transform
	var p : Vector3 = _billboard_transform.basis[1]
	var x : Vector3 = tangent
	var angle_val : float = p.angle_to(x)
	var rotation_axis : Vector3 = p.cross(x).normalized()
	if rotation_axis != Vector3():
		_billboard_transform.basis = _billboard_transform.basis.rotated(rotation_axis, angle_val)
	_billboard_transform.basis = _billboard_transform.basis.scaled(Vector3(0.5, 0.5, 0.5))
	_billboard_transform.origin += _billboard_transform.basis[1]

func _get_addon_path() -> String:
	return get_script().resource_path.get_base_dir().get_base_dir()
