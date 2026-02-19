# game/ui/debug_overlay.gd
## Toggle with a key to show velocity, FPS, position, state.
class_name DebugOverlay
extends Control

@export var toggle_action: StringName = "debug_toggle"
@export var character_path: NodePath

var _label: RichTextLabel
var _character: ToolkitCharacterBody

func _ready() -> void:
	_character = get_node_or_null(character_path)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.anchors_preset = PRESET_TOP_LEFT
	_label.offset_left = 10
	_label.offset_top = 10
	_label.offset_right = 400
	_label.offset_bottom = 300
	add_child(_label)

	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(toggle_action):
		visible = not visible

func _process(_delta: float) -> void:
	if not visible or not _character:
		return

	var data := _character.data
	var vel := data.velocity
	var h_speed := data.horizontal_speed

	var text := ""
	text += "[b]FPS:[/b] %d\n" % Engine.get_frames_per_second()
	text += "[b]Position:[/b] (%.1f, %.1f, %.1f)\n" % [
		_character.global_position.x,
		_character.global_position.y,
		_character.global_position.z]
	text += "[b]Velocity:[/b] (%.1f, %.1f, %.1f)\n" % [vel.x, vel.y, vel.z]
	text += "[b]H Speed:[/b] %.1f\n" % h_speed
	text += "[b]V Speed:[/b] %.1f\n" % vel.y
	text += "[b]On Floor:[/b] %s\n" % str(data.is_on_floor)
	text += "[b]Phase:[/b] %s\n" % CharacterData.GravityPhase.keys()[data.gravity_phase]
	text += "[b]Move Speed:[/b] %.1f\n" % data.move_speed
	text += "[b]Sprinting:[/b] %s\n" % str(data.is_sprinting)
	text += "[b]Crouching:[/b] %s\n" % str(data.is_crouching)

	_label.text = text
