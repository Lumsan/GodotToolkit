# game/ui/notification_popup.gd
class_name NotificationPopup
extends Control

@export var display_duration: float = 2.0
@export var fade_duration: float = 0.3
@export var max_visible: int = 3

@export_group("Appearance")
@export var font_size: int = 18
@export var min_width: float = 200.0
@export var message_spacing: int = 8
@export var background_color: Color = Color(0, 0, 0, 0.6)
@export var background_padding: Vector2 = Vector2(20, 10)
@export var corner_radius: int = 6

var _container: VBoxContainer
var _active_messages: Array[Control] = []
var _active_tweens: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = PRESET_CENTER_TOP
	offset_top = 50

	_container = VBoxContainer.new()
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_container.add_theme_constant_override("separation", message_spacing)
	add_child(_container)

func show_message(text: String, col: Color = Color.WHITE) -> void:
	while _active_messages.size() >= max_visible:
		_remove_message(_active_messages[0])

	# Label
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", col)
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_OFF

	# Panel wrapping the label
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size.x = min_width

	var style := StyleBoxFlat.new()
	style.bg_color = background_color
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	style.content_margin_left = background_padding.x
	style.content_margin_right = background_padding.x
	style.content_margin_top = background_padding.y
	style.content_margin_bottom = background_padding.y
	panel.add_theme_stylebox_override("panel", style)

	# Center the panel in the container
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	panel.add_child(label)
	center.add_child(panel)
	center.modulate.a = 0.0

	_container.add_child(center)
	_active_messages.append(center)

	# Animate
	var tween := create_tween()
	_active_tweens[center] = tween
	tween.tween_property(center, "modulate:a", 1.0, fade_duration)
	tween.tween_interval(display_duration)
	tween.tween_property(center, "modulate:a", 0.0, fade_duration)
	tween.tween_callback(func():
		if is_instance_valid(center):
			_remove_message(center)
	)

func _remove_message(element: Control) -> void:
	if _active_messages.has(element):
		_active_messages.erase(element)
	if _active_tweens.has(element):
		var tween: Tween = _active_tweens[element]
		if tween and tween.is_valid():
			tween.kill()
		_active_tweens.erase(element)
	if is_instance_valid(element):
		element.queue_free()
