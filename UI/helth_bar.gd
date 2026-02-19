@tool
class_name UIHealthBar
extends Control

@export var health_component_path: NodePath

@export_group("Mode")
enum BarMode { DRAWN, TEXTURED }
@export var mode: BarMode = BarMode.DRAWN:
	set(value):
		mode = value
		queue_redraw()

@export_group("Textures")
@export var frame_texture: Texture2D:
	set(value):
		frame_texture = value
		queue_redraw()
@export var fill_texture: Texture2D:
	set(value):
		fill_texture = value
		queue_redraw()
@export var trail_texture: Texture2D:
	set(value):
		trail_texture = value
		queue_redraw()

@export_group("Colors")
@export var fill_color: Color = Color.RED:
	set(value):
		fill_color = value
		queue_redraw()
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.8):
	set(value):
		background_color = value
		queue_redraw()
@export var damage_flash_color: Color = Color.WHITE
@export var heal_flash_color: Color = Color.GREEN
@export var fill_tint: Color = Color.WHITE:
	set(value):
		fill_tint = value
		queue_redraw()
@export var trail_tint: Color = Color(1, 1, 1, 0.6):
	set(value):
		trail_tint = value
		queue_redraw()

@export_group("Trail")
@export var show_damage_trail: bool = true:
	set(value):
		show_damage_trail = value
		queue_redraw()
@export var trail_color: Color = Color(0.8, 0.2, 0.2, 0.6):
	set(value):
		trail_color = value
		queue_redraw()
@export var trail_drain_speed: float = 30.0

@export_group("Animation")
@export var animate_changes: bool = true
@export var animation_speed: float = 200.0
@export var flash_duration: float = 0.15
@export var shake_on_damage: bool = true
@export var shake_intensity: float = 4.0
@export var shake_duration: float = 0.2

@export_group("Editor Preview")
@export_range(0.0, 100.0) var preview_health: float = 100.0:
	set(value):
		preview_health = value
		queue_redraw()
@export_range(0.0, 100.0) var preview_trail: float = 100.0:
	set(value):
		preview_trail = value
		queue_redraw()

var _health: HealthComponent
var _display_value: float = 100.0
var _trail_value: float = 100.0
var _flash_timer: float = 0.0
var _flash_color: Color = Color.WHITE
var _shake_timer: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	_health = get_node_or_null(health_component_path)
	if not _health:
		push_error("UIHealthBar: Set health_component_path")
		return

	_display_value = _health.health_percentage * 100.0
	_trail_value = _display_value

	_health.damaged.connect(_on_damaged)
	_health.healed.connect(_on_healed)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if not _health:
		return

	var target := _health.health_percentage * 100.0

	if animate_changes:
		_display_value = move_toward(_display_value, target, animation_speed * delta)
	else:
		_display_value = target

	if show_damage_trail:
		if _trail_value > _display_value:
			_trail_value = move_toward(_trail_value, _display_value, trail_drain_speed * delta)
		else:
			_trail_value = _display_value

	if _flash_timer > 0.0:
		_flash_timer -= delta

	if _shake_timer > 0.0:
		_shake_timer -= delta
		_shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		if _shake_timer <= 0.0:
			_shake_offset = Vector2.ZERO

	queue_redraw()

func _draw() -> void:
	var fill_val: float
	var trail_val: float

	if Engine.is_editor_hint():
		fill_val = preview_health
		trail_val = preview_trail
	else:
		fill_val = _display_value
		trail_val = _trail_value

	# Apply shake as draw offset instead of moving the node
	if _shake_offset != Vector2.ZERO:
		draw_set_transform(_shake_offset)

	match mode:
		BarMode.DRAWN:
			_draw_simple(fill_val, trail_val)
		BarMode.TEXTURED:
			_draw_textured(fill_val, trail_val)

	# Reset transform
	if _shake_offset != Vector2.ZERO:
		draw_set_transform(Vector2.ZERO)

func _draw_simple(fill_val: float, trail_val: float) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)

	if show_damage_trail:
		var trail_width := (trail_val / 100.0) * size.x
		draw_rect(Rect2(Vector2.ZERO, Vector2(trail_width, size.y)), trail_color)

	var fill_width := (fill_val / 100.0) * size.x
	var current_color := fill_color
	if _flash_timer > 0.0:
		current_color = _flash_color
	draw_rect(Rect2(Vector2.ZERO, Vector2(fill_width, size.y)), current_color)

func _draw_textured(fill_val: float, trail_val: float) -> void:
	var fill_ratio := fill_val / 100.0
	var trail_ratio := trail_val / 100.0

	if show_damage_trail and trail_texture:
		_draw_cropped_texture(trail_texture, trail_ratio, trail_tint)
	elif show_damage_trail and fill_texture:
		_draw_cropped_texture(fill_texture, trail_ratio, trail_tint)

	if fill_texture:
		var current_tint := fill_tint
		if _flash_timer > 0.0:
			current_tint = _flash_color
		_draw_cropped_texture(fill_texture, fill_ratio, current_tint)

	if frame_texture:
		draw_texture_rect(frame_texture, Rect2(Vector2.ZERO, size), false)

func _draw_cropped_texture(texture: Texture2D, ratio: float, tint: Color) -> void:
	if ratio <= 0.0:
		return

	var tex_size := texture.get_size()
	var src_rect := Rect2(0, 0, tex_size.x * ratio, tex_size.y)
	var dst_rect := Rect2(0, 0, size.x * ratio, size.y)
	draw_texture_rect_region(texture, dst_rect, src_rect, tint)

func _on_damaged(_amount: int, _source: Node) -> void:
	_flash_color = damage_flash_color
	_flash_timer = flash_duration
	if shake_on_damage:
		_shake_timer = shake_duration

func _on_healed(_amount: int, _source: Node) -> void:
	_flash_color = heal_flash_color
	_flash_timer = flash_duration
