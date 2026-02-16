# Based on GPUTrail by celyk
# https://github.com/celyk/GPUTrail
# MIT License

@tool
@icon("bounce.svg")
class_name GPUTrail3D extends GPUParticles3D

@export var length : int = 100 : set = _set_length
@export var length_seconds : float : set = _set_length

@export_category("Emission Shape")

enum EmissionShape { LINE, PATH }
@export var emission_shape : EmissionShape = EmissionShape.LINE : set = _set_emission_shape
@export var emission_path : Path3D : set = _set_emission_path
@export_range(2, 128) var path_segments : int = 16 : set = _set_path_segments
@export_range(2, 256) var path_resolution : int = 64 : set = _set_path_resolution

## Width of the ribbon trail perpendicular to the path curve
@export var ribbon_width : float = 0.05 : set = _set_ribbon_width

@export_category("Color / Texture")

@export var texture : Texture : set = _set_texture
@export var mask : Texture : set = _set_mask
@export var mask_strength : float = 1.0 : set = _set_mask_strength
@export var scroll : Vector2 : set = _set_scroll
@export var color_ramp : GradientTexture1D : set = _set_color_ramp
@export var curve : CurveTexture : set = _set_curve
@export var vertical_texture := false : set = _set_vertical_texture
@export var use_red_as_alpha := false : set = _set_use_red_as_alpha

@export_category("Mesh tweaks")

@export var billboard := false : set = _set_billboard
@export var dewiggle := true : set = _set_dewiggle
@export var clip_overlaps := true : set = _set_clip_overlaps
@export var snap_to_transform := false : set = _set_snap_to_transform

const _DEFAULT_TEXTURE = "defaults/texture.tres"
const _DEFAULT_CURVE = "defaults/curve.tres"

var _trail_material : ShaderMaterial
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

		process_material = ShaderMaterial.new()
		process_material.shader = preload("shaders/trail.gdshader")

		_trail_material = ShaderMaterial.new()
		_trail_material.shader = preload("shaders/trail_draw_pass.gdshader")
		_trail_material.resource_local_to_scene = true

		color_ramp = preload(_DEFAULT_TEXTURE).duplicate(true)
		curve = preload(_DEFAULT_CURVE).duplicate(true)
	else:
		if draw_pass_1:
			if draw_pass_1 is PrimitiveMesh:
				_trail_material = draw_pass_1.material
			elif draw_pass_1 is ArrayMesh and draw_pass_1.get_surface_count() > 0:
				_trail_material = draw_pass_1.surface_get_material(0)

		if not _trail_material:
			_trail_material = ShaderMaterial.new()
			_trail_material.resource_local_to_scene = true

		if process_material is ShaderMaterial:
			process_material.shader = preload("shaders/trail.gdshader")
		_trail_material.shader = preload("shaders/trail_draw_pass.gdshader")

	_update_draw_mesh()
	_apply_all_settings()

func _apply_all_settings():
	amount = length
	lifetime = length
	_trail_material.set_shader_parameter("trail_length", float(length))

	var use_path := emission_shape == EmissionShape.PATH
	process_material.set_shader_parameter("use_path_emission", use_path)
	_trail_material.set_shader_parameter("use_path_emission", use_path)
	_trail_material.set_shader_parameter("ribbon_width", ribbon_width)

	if use_path:
		_bake_path_texture()
		_path_needs_update = false
		if emission_path and emission_path.is_inside_tree() and is_inside_tree():
			_last_path_relative_xform = global_transform.affine_inverse() * emission_path.global_transform

	_flags = 0
	vertical_texture = vertical_texture
	use_red_as_alpha = use_red_as_alpha
	billboard = billboard
	dewiggle = dewiggle
	clip_overlaps = clip_overlaps
	snap_to_transform = snap_to_transform

	restart()

func _update_draw_mesh():
	if emission_shape == EmissionShape.PATH and path_segments >= 2:
		var mesh := _create_ribbon_mesh(path_segments)
		mesh.surface_set_material(0, _trail_material)
		draw_pass_1 = mesh
	else:
		var quad := QuadMesh.new()
		quad.material = _trail_material
		draw_pass_1 = quad

func _create_ribbon_mesh(subdivisions: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()

	# Simple grid: 2 columns (time) x (subdivisions+1) rows (path)
	# Column 0 = new time (UV.x = 0), Column 1 = old time (UV.x = 1)
	var rows := subdivisions + 1
	for i in range(rows):
		var v := float(i) / float(subdivisions)  # path parameter 0..1
		# New time vertex
		verts.append(Vector3(-0.5, v - 0.5, 0.0))
		uvs.append(Vector2(0.0, v))
		# Old time vertex
		verts.append(Vector3(0.5, v - 0.5, 0.0))
		uvs.append(Vector2(1.0, v))

	# Create quads between adjacent path rows, spanning time
	for i in range(subdivisions):
		var b := i * 2      # base row start index
		var n := (i + 1) * 2  # next row start index
		# Quad: new_base, old_base, new_next, old_next
		# Triangle 1
		indices.append(b + 0); indices.append(n + 0); indices.append(b + 1)
		# Triangle 2
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
	if not _defaults_have_been_set:
		return
	_trail_material.set_shader_parameter("ribbon_width", ribbon_width)

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
		_trail_material.set_shader_parameter("trail_length", float(length))
		restart()

func _set_emission_shape(value):
	emission_shape = value
	if not _defaults_have_been_set:
		return
	var use_path := emission_shape == EmissionShape.PATH
	process_material.set_shader_parameter("use_path_emission", use_path)
	_trail_material.set_shader_parameter("use_path_emission", use_path)
	_update_draw_mesh()
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
	if not _defaults_have_been_set:
		return
	_update_draw_mesh()
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
	if not emission_path or not emission_path.curve:
		_path_texture = null
		if _defaults_have_been_set:
			_trail_material.set_shader_parameter("path_texture", null)
			_trail_material.set_shader_parameter("path_point_count", 0)
		return

	var curve3d : Curve3D = emission_path.curve
	var baked_length := curve3d.get_baked_length()
	if baked_length <= 0.0:
		return

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
		_trail_material.set_shader_parameter("path_texture", _path_texture)

	_trail_material.set_shader_parameter("path_point_count", res)

func _set_texture(value):
	texture = value
	_uv_offset = Vector2.ZERO
	if not _defaults_have_been_set: return
	_trail_material.set_shader_parameter("tex", texture if texture else preload(_DEFAULT_TEXTURE))

func _set_mask(value):
	mask = value
	if not _defaults_have_been_set: return
	_trail_material.set_shader_parameter("mask", mask)

func _set_mask_strength(value):
	mask_strength = clamp(value, 0.0, 1.0)
	if not _defaults_have_been_set: return
	_trail_material.set_shader_parameter("mask_strength", mask_strength)

func _set_scroll(value):
	scroll = value

func _set_color_ramp(value):
	color_ramp = value
	if not _defaults_have_been_set: return
	_trail_material.set_shader_parameter("color_ramp", color_ramp)

func _set_curve(value):
	curve = value
	if not _defaults_have_been_set: return
	_trail_material.set_shader_parameter("curve", curve if curve else preload(_DEFAULT_CURVE))

func _set_vertical_texture(value):
	vertical_texture = value
	if not _defaults_have_been_set: return
	_flags = _set_flag(_flags, 0, value)
	_trail_material.set_shader_parameter("flags", _flags)

func _set_use_red_as_alpha(value):
	use_red_as_alpha = value
	if not _defaults_have_been_set: return
	_flags = _set_flag(_flags, 1, value)
	_trail_material.set_shader_parameter("flags", _flags)

func _set_billboard(value):
	billboard = value
	if not _defaults_have_been_set: return
	_flags = _set_flag(_flags, 2, value)
	_trail_material.set_shader_parameter("flags", _flags)
	if value:
		_update_billboard_transform(global_transform.basis[0])
	restart()

func _set_dewiggle(value):
	dewiggle = value
	if not _defaults_have_been_set: return
	_flags = _set_flag(_flags, 3, value)
	_trail_material.set_shader_parameter("flags", _flags)

func _set_snap_to_transform(value):
	snap_to_transform = value
	if not _defaults_have_been_set: return
	_flags = _set_flag(_flags, 4, value)
	_trail_material.set_shader_parameter("flags", _flags)

func _set_clip_overlaps(value):
	clip_overlaps = value
	if not _defaults_have_been_set: return
	_flags = _set_flag(_flags, 5, value)
	_trail_material.set_shader_parameter("flags", _flags)

@onready var _old_pos : Vector3 = global_position
@onready var _billboard_transform : Transform3D = global_transform
var _uv_offset : Vector2

func _process(delta):
	if snap_to_transform:
		_trail_material.set_shader_parameter("emmission_transform", global_transform)

	_uv_offset += scroll * delta
	_uv_offset = _uv_offset.posmod(1.0)
	_trail_material.set_shader_parameter("uv_offset", _uv_offset)

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

		if do_rebake:
			_bake_path_texture()
		if do_restart:
			restart()

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

var _flags := 0
func _set_flag(i, idx : int, value : bool):
	return (i & ~(1 << idx)) | (int(value) << idx)
