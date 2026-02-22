## In-game dev tool panel for tweaking character parameters at runtime.
## Press the toggle key (default: F1) to open/close the panel.
class_name DevToolPanel
extends Node

@export var priority: int = 999
@export var toggle_action: String = "dev_toggle"
@export var toggle_key: Key = KEY_F1

## Whether to also capture physics info for display
@export var show_physics_info: bool = true

var _panel: PanelContainer
var _vbox: VBoxContainer
var _speed_label: Label
var _velocity_label: Label
var _position_label: Label
var _floor_label: Label
var _fps_label: Label

var _visible: bool = false
var _character: ToolkitCharacterBody

# References to tweakable components found at runtime
var _ground_mover: GroundMover
var _sprint_modifier: SprintModifier
var _velocity_applier: VelocityApplier
var _gravity_component: GravityComponent

# Slider references
var _base_speed_slider: HSlider
var _sprint_mult_slider: HSlider
var _accel_slider: HSlider
var _decel_slider: HSlider
var _air_control_slider: HSlider
var _timescale_slider: HSlider

func _ready() -> void:
	_character = _find_character_body()
	_find_sibling_components()
	_build_ui()
	_panel.visible = false

	# Register toggle action if it doesn't exist
	if not InputMap.has_action(toggle_action):
		InputMap.add_action(toggle_action)
		var ev := InputEventKey.new()
		ev.keycode = toggle_key
		InputMap.action_add_event(toggle_action, ev)

func _find_character_body() -> ToolkitCharacterBody:
	var node := get_parent()
	while node:
		if node is ToolkitCharacterBody:
			return node as ToolkitCharacterBody
		node = node.get_parent()
	return null

func _find_sibling_components() -> void:
	if not _character:
		return
	for child in _get_all_descendants(_character):
		if child is GroundMover:
			_ground_mover = child
		elif child is SprintModifier:
			_sprint_modifier = child
		elif child is VelocityApplier:
			_velocity_applier = child
		elif child is GravityComponent:
			_gravity_component = child

func _get_all_descendants(node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in node.get_children():
		result.append(child)
		result.append_array(_get_all_descendants(child))
	return result

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		_toggle_panel()
		get_viewport().set_input_as_handled()

func _toggle_panel() -> void:
	_visible = not _visible
	_panel.visible = _visible

	if _character and _character.data:
		_character.data.look_locked = _visible

	if _visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _build_ui() -> void:
	# CanvasLayer so it renders on top of everything
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(340, 0)
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.offset_left = 10
	_panel.offset_top = 10
	canvas.add_child(_panel)

	# Style the panel
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.92)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.6, 1.0, 0.5)
	_panel.add_theme_stylebox_override("panel", style)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 500)
	_panel.add_child(scroll)

	_vbox = VBoxContainer.new()
	_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_vbox)

	# Title
	var title := _make_label("=== DEV TOOLS (F1) ===", 18, Color(0.5, 0.8, 1.0))
	_vbox.add_child(title)
	_vbox.add_child(_make_separator())

	# --- Info Section ---
	if show_physics_info:
		_vbox.add_child(_make_section_header("Live Info"))
		_fps_label = _make_label("FPS: --")
		_vbox.add_child(_fps_label)
		_velocity_label = _make_label("Velocity: --")
		_vbox.add_child(_velocity_label)
		_speed_label = _make_label("Speed: --")
		_vbox.add_child(_speed_label)
		_position_label = _make_label("Position: --")
		_vbox.add_child(_position_label)
		_floor_label = _make_label("On Floor: --")
		_vbox.add_child(_floor_label)
		_vbox.add_child(_make_separator())

	# --- Movement Section ---
	if _ground_mover:
		_vbox.add_child(_make_section_header("Ground Movement"))
		_base_speed_slider = _add_slider("Base Speed", _ground_mover.base_speed, 0.5, 30.0, 0.1,
			func(val: float) -> void: _ground_mover.base_speed = val
		)
		_vbox.add_child(_make_separator())

	# --- Sprint Section ---
	if _sprint_modifier:
		_vbox.add_child(_make_section_header("Sprint"))
		_sprint_mult_slider = _add_slider("Sprint Multiplier", _sprint_modifier.sprint_multiplier, 1.0, 10.0, 0.05,
			func(val: float) -> void: _sprint_modifier.sprint_multiplier = val
		)
		_vbox.add_child(_make_separator())

	# --- Velocity Applier Section ---
	if _velocity_applier:
		_vbox.add_child(_make_section_header("Velocity"))
		_accel_slider = _add_slider("Acceleration", _velocity_applier.acceleration, 1.0, 200.0, 1.0,
			func(val: float) -> void: _velocity_applier.acceleration = val
		)
		_decel_slider = _add_slider("Deceleration", _velocity_applier.deceleration, 1.0, 200.0, 1.0,
			func(val: float) -> void: _velocity_applier.deceleration = val
		)
		_air_control_slider = _add_slider("Air Control", _velocity_applier.air_control, 0.0, 1.0, 0.01,
			func(val: float) -> void: _velocity_applier.air_control = val
		)
		_vbox.add_child(_make_separator())
	
	# --- Gravity Section ---
	if _gravity_component:
		_vbox.add_child(_make_section_header("Gravity"))
		_add_slider("Base Gravity", _gravity_component.custom_gravity, 0.0, 80.0, 0.5,
			func(val: float) -> void: _gravity_component.custom_gravity = val
		)
		_add_slider("Rise Multiplier", _gravity_component.rise_multiplier, 0.0, 3.0, 0.05,
			func(val: float) -> void: _gravity_component.rise_multiplier = val
		)
		_add_slider("Fall Multiplier", _gravity_component.fall_multiplier, 0.0, 3.0, 0.05,
			func(val: float) -> void: _gravity_component.fall_multiplier = val
		)
		_add_slider("Terminal Velocity", _gravity_component.terminal_velocity, 5.0, 150.0, 1.0,
			func(val: float) -> void: _gravity_component.terminal_velocity = val
		)
		_vbox.add_child(_make_separator())

	# --- Global Section ---
	_vbox.add_child(_make_section_header("Global"))
	_timescale_slider = _add_slider("Time Scale", 1.0, 0.05, 3.0, 0.05,
		func(val: float) -> void: Engine.time_scale = val
	)
	
	# --- Global Section ---
	_vbox.add_child(_make_section_header("Global"))
	_timescale_slider = _add_slider("Time Scale", 1.0, 0.05, 3.0, 0.05,
		func(val: float) -> void: Engine.time_scale = val
	)

	# --- Action Buttons ---
	_vbox.add_child(_make_section_header("Actions"))

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)
	_vbox.add_child(btn_row)

	btn_row.add_child(_make_button("Reset Position", func() -> void:
		if _character:
			_character.global_position = Vector3(0, 2, 0)
			_character.data.velocity = Vector3.ZERO
	))

	btn_row.add_child(_make_button("Reset Velocity", func() -> void:
		if _character:
			_character.data.velocity = Vector3.ZERO
	))

	var btn_row2 := HBoxContainer.new()
	btn_row2.add_theme_constant_override("separation", 8)
	_vbox.add_child(btn_row2)

	btn_row2.add_child(_make_button("Noclip Toggle", func() -> void:
		if _character:
			var col := _character.get_node_or_null("CollisionShape3D") as CollisionShape3D
			if col:
				col.disabled = not col.disabled
	))

	btn_row2.add_child(_make_button("Reset All", func() -> void:
		_reset_all_to_defaults()
	))

# ----- UI Helpers -----

func _make_label(text: String, size: int = 14, color: Color = Color(0.85, 0.85, 0.85)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _make_section_header(text: String) -> Label:
	return _make_label(text, 15, Color(1.0, 0.85, 0.4))

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 6)
	return sep

func _make_button(text: String, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(callback)
	return btn

## Creates a labeled slider row and returns the HSlider.
func _add_slider(label_text: String, initial: float, min_val: float, max_val: float, step: float, on_change: Callable) -> HSlider:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)
	_vbox.add_child(hbox)

	var label := _make_label(label_text, 13)
	label.custom_minimum_size.x = 120
	hbox.add_child(label)

	var slider := HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.step = step
	slider.value = initial
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.custom_minimum_size.x = 120
	hbox.add_child(slider)

	var value_label := _make_label(str(snapped(initial, step)), 13, Color(0.6, 1.0, 0.6))
	value_label.custom_minimum_size.x = 50
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(value_label)

	slider.value_changed.connect(func(val: float) -> void:
		value_label.text = str(snapped(val, step))
		on_change.call(val)
	)

	return slider

# ----- Runtime Updates -----

func post_process(data: CharacterData, _delta: float) -> void:
	if not _visible or not show_physics_info:
		return

	var hvel := Vector3(data.velocity.x, 0, data.velocity.z)
	_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_velocity_label.text = "Velocity: (%.1f, %.1f, %.1f)" % [data.velocity.x, data.velocity.y, data.velocity.z]
	_speed_label.text = "H-Speed: %.2f | Move Speed: %.2f" % [hvel.length(), data.move_speed]
	if _character:
		var p := _character.global_position
		_position_label.text = "Position: (%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]
	_floor_label.text = "On Floor: %s" % str(data.is_on_floor)

# ----- Reset -----

var _defaults: Dictionary = {}

func _find_and_store_defaults() -> void:
	if _ground_mover:
		_defaults["base_speed"] = _ground_mover.base_speed
	if _sprint_modifier:
		_defaults["sprint_multiplier"] = _sprint_modifier.sprint_multiplier
	if _velocity_applier:
		_defaults["acceleration"] = _velocity_applier.acceleration
		_defaults["deceleration"] = _velocity_applier.deceleration
		_defaults["air_control"] = _velocity_applier.air_control
	if _gravity_component:
		_defaults["custom_gravity"] = _gravity_component.custom_gravity
		_defaults["rise_multiplier"] = _gravity_component.rise_multiplier
		_defaults["fall_multiplier"] = _gravity_component.fall_multiplier
		_defaults["terminal_velocity"] = _gravity_component.terminal_velocity

func _reset_all_to_defaults() -> void:
	if _ground_mover and _defaults.has("base_speed"):
		_ground_mover.base_speed = _defaults["base_speed"]
		_base_speed_slider.value = _defaults["base_speed"]
	if _sprint_modifier and _defaults.has("sprint_multiplier"):
		_sprint_modifier.sprint_multiplier = _defaults["sprint_multiplier"]
		_sprint_mult_slider.value = _defaults["sprint_multiplier"]
	if _velocity_applier:
		if _defaults.has("acceleration"):
			_velocity_applier.acceleration = _defaults["acceleration"]
			_accel_slider.value = _defaults["acceleration"]
		if _defaults.has("deceleration"):
			_velocity_applier.deceleration = _defaults["deceleration"]
			_decel_slider.value = _defaults["deceleration"]
		if _defaults.has("air_control"):
			_velocity_applier.air_control = _defaults["air_control"]
			_air_control_slider.value = _defaults["air_control"]
	if _gravity_component:
		if _defaults.has("custom_gravity"):
			_gravity_component.custom_gravity = _defaults["custom_gravity"]
		if _defaults.has("rise_multiplier"):
			_gravity_component.rise_multiplier = _defaults["rise_multiplier"]
		if _defaults.has("fall_multiplier"):
			_gravity_component.fall_multiplier = _defaults["fall_multiplier"]
		if _defaults.has("terminal_velocity"):
			_gravity_component.terminal_velocity = _defaults["terminal_velocity"]
	Engine.time_scale = 1.0
	_timescale_slider.value = 1.0
