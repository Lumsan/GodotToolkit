@tool
extends Window

# ── Autoload definitions ────────────────────────────────────────────────────
const AUTOLOADS := [
	{
		"name": "AudioManager",
		"path": "res://GodotToolkit/Autoloads/Audio/audio_manager.gd",
		"desc": "Pooled 2D/3D SFX and music with crossfade"
	},
	{
		"name": "SaveSystem",
		"path": "res://GodotToolkit/Autoloads/SaveSystem/save_system.gd",
		"desc": "JSON save/load for nodes in the 'saveable' group"
	},
	{
		"name": "SceneLoader",
		"path": "res://GodotToolkit/Autoloads/Scenes/scene_loader.gd",
		"desc": "Threaded scene transitions with optional loading screen"
	},
	{
		"name": "SettingsManager",
		"path": "res://GodotToolkit/Autoloads/Settings/settings_manager.gd",
		"desc": "Persistent audio/graphics settings via ConfigFile"
	},
	{
		"name": "MouseInput",
		"path": "res://GodotToolkit/Autoloads/WonkyStuff/mouse_input_provider.gd",
		"desc": "Low-latency mouse input (required for SubViewport setups)"
	},
]

# ── Input action definitions ────────────────────────────────────────────────
const INPUT_ACTIONS := [
	{ "action": "move_forward",         "desc": "Move forward",               "key": KEY_W,      "label": "W"      },
	{ "action": "move_backward",        "desc": "Move backward",              "key": KEY_S,      "label": "S"      },
	{ "action": "move_left",            "desc": "Strafe left",                "key": KEY_A,      "label": "A"      },
	{ "action": "move_right",           "desc": "Strafe right",               "key": KEY_D,      "label": "D"      },
	{ "action": "sprint",               "desc": "Hold to sprint",             "key": KEY_SHIFT,  "label": "Shift"  },
	{ "action": "crouch",               "desc": "Hold to crouch / fast-fall", "key": KEY_CTRL,   "label": "Ctrl"   },
	{ "action": "jump",                 "desc": "Jump",                       "key": KEY_SPACE,  "label": "Space"  },
	{ "action": "interact",             "desc": "Interact with objects",      "key": KEY_E,      "label": "E"      },
	{ "action": "toggle_mouse_capture", "desc": "Release / recapture cursor", "key": KEY_ESCAPE, "label": "Escape" },
]

# ── Colours ──────────────────────────────────────────────────────────────────
const C_BG       := Color(0.13, 0.13, 0.13)
const C_HEADER   := Color(0.10, 0.10, 0.10)
const C_ACCENT   := Color(0.25, 0.60, 0.95)
const C_ROW_A    := Color(0.16, 0.16, 0.16)
const C_ROW_B    := Color(0.14, 0.14, 0.14)
const C_TEXT     := Color(0.92, 0.92, 0.92)
const C_MUTED    := Color(0.55, 0.55, 0.55)
const C_KEY_BG   := Color(0.22, 0.22, 0.22)
const C_KEY_TEXT := Color(0.75, 0.90, 1.00)

# ── State ─────────────────────────────────────────────────────────────────────
var _autoload_checks: Array[CheckBox] = []
var _input_checks:    Array[CheckBox] = []
var _apply_btn:       Button


func _ready() -> void:
	title    = "Toolkit — Project Setup"
	min_size = Vector2i(540, 560)
	close_requested.connect(queue_free)
	_build_ui()


func _build_ui() -> void:
	# Root dark panel
	var root_panel := PanelContainer.new()
	root_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var root_style := StyleBoxFlat.new()
	root_style.bg_color = C_BG
	root_panel.add_theme_stylebox_override("panel", root_style)
	add_child(root_panel)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	root_panel.add_child(outer)

	# ── Header ──
	var header_panel := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color             = C_HEADER
	hs.border_color         = C_ACCENT
	hs.border_width_bottom  = 2
	hs.content_margin_left  = 20
	hs.content_margin_right = 20
	hs.content_margin_top   = 14
	hs.content_margin_bottom= 14
	header_panel.add_theme_stylebox_override("panel", hs)
	outer.add_child(header_panel)

	var header_vbox := VBoxContainer.new()
	header_vbox.add_theme_constant_override("separation", 3)
	header_panel.add_child(header_vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Project Setup"
	title_lbl.add_theme_font_size_override("font_size", 17)
	title_lbl.add_theme_color_override("font_color", C_TEXT)
	header_vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Deselect anything you don't need. Everything is on by default."
	sub_lbl.add_theme_font_size_override("font_size", 11)
	sub_lbl.add_theme_color_override("font_color", C_MUTED)
	header_vbox.add_child(sub_lbl)

	# ── Scroll body ──
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)

	_build_section(body, "Autoloads", AUTOLOADS, _autoload_checks,
		func(e: Dictionary) -> String: return e["name"],
		func(e: Dictionary) -> String: return e["desc"],
		func(_e: Dictionary) -> String: return "")

	_build_section(body, "Input Map", INPUT_ACTIONS, _input_checks,
		func(e: Dictionary) -> String: return e["action"],
		func(e: Dictionary) -> String: return e["desc"],
		func(e: Dictionary) -> String: return e["label"])

	# ── Footer ──
	var footer_panel := PanelContainer.new()
	var fs := StyleBoxFlat.new()
	fs.bg_color              = C_HEADER
	fs.border_color          = C_ACCENT
	fs.border_width_top      = 1
	fs.content_margin_left   = 16
	fs.content_margin_right  = 16
	fs.content_margin_top    = 10
	fs.content_margin_bottom = 10
	footer_panel.add_theme_stylebox_override("panel", fs)
	outer.add_child(footer_panel)

	var footer_row := HBoxContainer.new()
	footer_row.alignment = BoxContainer.ALIGNMENT_END
	footer_row.add_theme_constant_override("separation", 8)
	footer_panel.add_child(footer_row)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	_style_btn(cancel_btn, Color(0.24, 0.24, 0.24), C_TEXT)
	cancel_btn.pressed.connect(queue_free)
	footer_row.add_child(cancel_btn)

	_apply_btn = Button.new()
	_apply_btn.text = "Apply"
	_style_btn(_apply_btn, C_ACCENT, Color.WHITE)
	_apply_btn.pressed.connect(_on_apply)
	footer_row.add_child(_apply_btn)


func _build_section(
		parent: VBoxContainer,
		title: String,
		entries: Array,
		checks: Array[CheckBox],
		get_name: Callable,
		get_desc: Callable,
		get_tag:  Callable) -> void:

	# Section label row
	var sec_panel := PanelContainer.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color             = Color(C_ACCENT.r, C_ACCENT.g, C_ACCENT.b, 0.10)
	ss.border_color         = C_ACCENT
	ss.border_width_left    = 3
	ss.content_margin_left  = 14
	ss.content_margin_right = 14
	ss.content_margin_top   = 6
	ss.content_margin_bottom= 6
	sec_panel.add_theme_stylebox_override("panel", ss)
	parent.add_child(sec_panel)

	var sec_lbl := Label.new()
	sec_lbl.text = title.to_upper()
	sec_lbl.add_theme_font_size_override("font_size", 10)
	sec_lbl.add_theme_color_override("font_color", C_ACCENT)
	sec_panel.add_child(sec_lbl)

	# Item rows
	for i in entries.size():
		var e: Dictionary = entries[i]

		var row_panel := PanelContainer.new()
		var rs := StyleBoxFlat.new()
		rs.bg_color              = C_ROW_A if i % 2 == 0 else C_ROW_B
		rs.content_margin_left   = 14
		rs.content_margin_right  = 14
		rs.content_margin_top    = 6
		rs.content_margin_bottom = 6
		row_panel.add_theme_stylebox_override("panel", rs)
		parent.add_child(row_panel)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row_panel.add_child(row)

		var cb := CheckBox.new()
		cb.button_pressed = true
		cb.custom_minimum_size = Vector2(20, 20)
		row.add_child(cb)
		checks.append(cb)

		var name_lbl := Label.new()
		name_lbl.text = get_name.call(e)
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", C_TEXT)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = get_desc.call(e)
		desc_lbl.add_theme_font_size_override("font_size", 11)
		desc_lbl.add_theme_color_override("font_color", C_MUTED)
		desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(desc_lbl)

		var tag: String = get_tag.call(e)
		if tag != "":
			var tag_panel := PanelContainer.new()
			var ts := StyleBoxFlat.new()
			ts.bg_color                  = C_KEY_BG
			ts.corner_radius_top_left    = 3
			ts.corner_radius_top_right   = 3
			ts.corner_radius_bottom_left = 3
			ts.corner_radius_bottom_right= 3
			ts.content_margin_left       = 8
			ts.content_margin_right      = 8
			ts.content_margin_top        = 2
			ts.content_margin_bottom     = 2
			tag_panel.add_theme_stylebox_override("panel", ts)
			row.add_child(tag_panel)

			var tag_lbl := Label.new()
			tag_lbl.text = tag
			tag_lbl.add_theme_font_size_override("font_size", 11)
			tag_lbl.add_theme_color_override("font_color", C_KEY_TEXT)
			tag_panel.add_child(tag_lbl)


func _style_btn(btn: Button, bg: Color, fg: Color) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = bg.lightened(0.08) if state == "hover" \
				else bg.darkened(0.10)  if state == "pressed" \
				else bg.darkened(0.20)  if state == "disabled" \
				else bg
		s.corner_radius_top_left     = 4
		s.corner_radius_top_right    = 4
		s.corner_radius_bottom_left  = 4
		s.corner_radius_bottom_right = 4
		s.content_margin_left        = 16
		s.content_margin_right       = 16
		s.content_margin_top         = 6
		s.content_margin_bottom      = 6
		btn.add_theme_stylebox_override(state, s)
	btn.add_theme_color_override("font_color",         fg)
	btn.add_theme_color_override("font_hover_color",   fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	btn.add_theme_color_override("font_disabled_color",fg.darkened(0.4))


# ── Apply ─────────────────────────────────────────────────────────────────────

func _on_apply() -> void:
	_apply_btn.disabled = true
	var applied: Array[String] = []
	var warnings: Array[String] = []

	for i in _autoload_checks.size():
		if not _autoload_checks[i].button_pressed:
			continue
		var e: Dictionary = AUTOLOADS[i]
		var err := _add_autoload(e["name"], e["path"])
		if err == "":
			applied.append("Autoload  " + e["name"])
		else:
			warnings.append(err)

	for i in _input_checks.size():
		if not _input_checks[i].button_pressed:
			continue
		var e: Dictionary = INPUT_ACTIONS[i]
		_add_input_action(e["action"], e["key"])
		applied.append("Input     " + e["action"] + "  [" + e["label"] + "]")

	ProjectSettings.save()

	print("")
	print("┌─ Toolkit Project Setup ───────────────────────")
	if applied.is_empty() and warnings.is_empty():
		print("│  Nothing applied.")
	for line in applied:
		print("│  ✓  " + line)
	if not warnings.is_empty():
		print("│")
		for line in warnings:
			print("│  ⚠  " + line)
	print("└───────────────────────────────────────────────")
	print("")

	queue_free()


func _add_autoload(autoload_name: String, script_path: String) -> String:
	var key := "autoload/" + autoload_name
	if ProjectSettings.has_setting(key):
		return ""
	if not ResourceLoader.exists(script_path):
		return "File not found, skipped: " + script_path
	ProjectSettings.set_setting(key, "*" + script_path)
	ProjectSettings.add_property_info({ "name": key, "type": TYPE_STRING })
	ProjectSettings.set_initial_value(key, "")
	return ""


func _add_input_action(action: String, key: int) -> void:
	if ProjectSettings.has_setting("input/" + action):
		return
	var event := InputEventKey.new()
	event.physical_keycode = key
	ProjectSettings.set_setting("input/" + action, {
		"deadzone": 0.2,
		"events": [event]
	})
