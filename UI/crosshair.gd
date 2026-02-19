# game/ui/crosshair.gd
@tool
class_name UICrosshair
extends Control

enum CrosshairMode {
	LINES,    ## Draw crosshair lines
	IMAGE,    ## Use a custom texture
}

@export var mode: CrosshairMode = CrosshairMode.LINES:
	set(value):
		mode = value
		queue_redraw()

@export_group("Image Mode")
@export var crosshair_texture: Texture2D:
	set(value):
		crosshair_texture = value
		queue_redraw()
@export var image_size: Vector2 = Vector2(32, 32):
	set(value):
		image_size = value
		queue_redraw()
@export var image_color: Color = Color.WHITE:
	set(value):
		image_color = value
		queue_redraw()

@export_group("Line Mode")
@export var line_length: float = 10.0:
	set(value):
		line_length = value
		queue_redraw()
@export var line_thickness: float = 2.0:
	set(value):
		line_thickness = value
		queue_redraw()
@export var gap: float = 5.0:
	set(value):
		gap = value
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()
@export var show_dot: bool = true:
	set(value):
		show_dot = value
		queue_redraw()
@export var dot_size: float = 2.0:
	set(value):
		dot_size = value
		queue_redraw()

@export_group("Shadow")
@export var show_shadow: bool = true:
	set(value):
		show_shadow = value
		queue_redraw()
@export var shadow_color: Color = Color(0, 0, 0, 0.5):
	set(value):
		shadow_color = value
		queue_redraw()
@export var shadow_offset: Vector2 = Vector2(1, 1):
	set(value):
		shadow_offset = value
		queue_redraw()

@export_group("Dynamic Spread")
@export var dynamic_spread: bool = false
@export var spread_amount: float = 10.0
@export var spread_sprint_multiplier: float = 2.0
@export var spread_crouch_multiplier: float = 0.5
@export var spread_air_multiplier: float = 1.5
@export var spread_speed: float = 10.0

var _current_spread: float = 0.0
var _target_spread: float = 0.0
var _character_data: CharacterData

func set_character_data(data: CharacterData) -> void:
	_character_data = data

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if dynamic_spread and _character_data:
		_update_spread(delta)
		queue_redraw()

func _update_spread(delta: float) -> void:
	_target_spread = 0.0

	if _character_data.horizontal_speed > 0.5:
		_target_spread = spread_amount

		if _character_data.is_sprinting:
			_target_spread *= spread_sprint_multiplier
		elif _character_data.is_crouching:
			_target_spread *= spread_crouch_multiplier

	if not _character_data.is_on_floor:
		_target_spread *= spread_air_multiplier

	_current_spread = move_toward(_current_spread, _target_spread,
		spread_speed * delta * spread_amount)

func _draw() -> void:
	var center := size / 2.0

	match mode:
		CrosshairMode.IMAGE:
			_draw_image(center)
		CrosshairMode.LINES:
			_draw_lines(center)

func _draw_image(center: Vector2) -> void:
	if not crosshair_texture:
		# Draw placeholder in editor if no texture set
		if Engine.is_editor_hint():
			draw_rect(Rect2(center - image_size / 2.0, image_size),
				Color(1, 0, 1, 0.3), false, 2.0)
			draw_string(ThemeDB.fallback_font, center - Vector2(20, -4),
				"No Tex", HORIZONTAL_ALIGNMENT_CENTER, -1, 12, color)
		return

	var spread_offset := _current_spread
	var draw_size := image_size + Vector2(spread_offset * 2.0, spread_offset * 2.0)
	var draw_pos := center - draw_size / 2.0
	var rect := Rect2(draw_pos, draw_size)

	# Shadow
	if show_shadow and shadow_color.a > 0.0:
		var shadow_rect := Rect2(draw_pos + shadow_offset, draw_size)
		draw_texture_rect(crosshair_texture, shadow_rect, false, shadow_color)

	# Main image
	draw_texture_rect(crosshair_texture, rect, false, image_color)

func _draw_lines(center: Vector2) -> void:
	var current_gap := gap + _current_spread

	# Shadow
	if show_shadow and shadow_color.a > 0.0:
		_draw_crosshair_lines(center + shadow_offset, current_gap, shadow_color)
		if show_dot:
			draw_circle(center + shadow_offset, dot_size, shadow_color)

	# Main crosshair
	_draw_crosshair_lines(center, current_gap, color)
	if show_dot:
		draw_circle(center, dot_size, color)

func _draw_crosshair_lines(center: Vector2, current_gap: float, col: Color) -> void:
	# Top
	draw_line(
		center + Vector2(0, -current_gap),
		center + Vector2(0, -current_gap - line_length),
		col, line_thickness)
	# Bottom
	draw_line(
		center + Vector2(0, current_gap),
		center + Vector2(0, current_gap + line_length),
		col, line_thickness)
	# Left
	draw_line(
		center + Vector2(-current_gap, 0),
		center + Vector2(-current_gap - line_length, 0),
		col, line_thickness)
	# Right
	draw_line(
		center + Vector2(current_gap, 0),
		center + Vector2(current_gap + line_length, 0),
		col, line_thickness)
