# game/ui/fade_screen.gd
## Full screen fade to/from a color. Useful for scene transitions, death, etc.
class_name FadeScreen
extends ColorRect

@export var fade_color: Color = Color.BLACK
@export var default_duration: float = 0.5

var _tween: Tween

func _ready() -> void:
	color = fade_color
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchors_preset = PRESET_FULL_RECT
	# Start transparent
	modulate.a = 0.0
	visible = false

## Fade to black (or fade_color). Await this.
func fade_out(duration: float = -1.0) -> void:
	if duration < 0.0:
		duration = default_duration

	_kill_tween()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, duration)
	await _tween.finished

## Fade from black back to transparent. Await this.
func fade_in(duration: float = -1.0) -> void:
	if duration < 0.0:
		duration = default_duration

	_kill_tween()
	visible = true

	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, duration)
	await _tween.finished

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

## Fade out, call a function, then fade back in.
func transition(callable: Callable, duration: float = -1.0) -> void:
	await fade_out(duration)
	callable.call()
	await fade_in(duration)

func _kill_tween() -> void:
	if _tween:
		_tween.kill()
