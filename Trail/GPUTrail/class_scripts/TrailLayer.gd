# TrailLayer.gd
@tool
class_name TrailLayer extends Resource

const _DEFAULT_TEXTURE = "res://addons/GPUTrail-main/defaults/texture.tres"
const _DEFAULT_CURVE = "res://addons/GPUTrail-main/defaults/curve.tres"

@export var texture : Texture2D
@export var texture_repeat : bool = true
@export var mask : Texture2D
@export var mask_strength : float = 1.0
@export var scroll : Vector2 = Vector2.ZERO
@export var color_ramp : GradientTexture1D
@export var curve : CurveTexture
@export var vertical_texture : bool = false
@export var use_red_as_alpha : bool = false

enum BlendMode { MIX, ADD, MUL, PREMUL_ALPHA, SUB }
@export var blend_mode : BlendMode = BlendMode.MIX

@export var emission_strength : float = 0.0

func _get_addon_path() -> String:
	return get_script().resource_path.get_base_dir().get_base_dir()

func apply_to_material(mat : ShaderMaterial) -> void:
	var base := _get_addon_path()
	mat.set_shader_parameter("tex", texture)
	mat.set_shader_parameter("mask", mask)
	mat.set_shader_parameter("mask_strength", mask_strength)
	mat.set_shader_parameter("color_ramp", color_ramp)
	mat.set_shader_parameter("curve", curve)
	mat.set_shader_parameter("emission_strength", emission_strength)
	mat.set_shader_parameter("texture_repeat", texture_repeat)
