@tool
extends Area3D
class_name AnimationTrigger

# The AnimationPlayer containing your animations
var _animations
## Add the AnimationPlayer, where your animations are located.
@export var animations: AnimationPlayer:
	set(value):
		notify_property_list_changed()
		_animations = value
	get():
		return _animations

# The selected animation to play (dropdown populated dynamically)
var selected_animation: String = ""

# Optional: trigger only once
@export var trigger_once: bool = true
var triggered: bool = false

func _ready():
	# Connect the body_entered signal to our handler
	if not is_connected("body_entered", _on_body_entered):
		connect("body_entered", _on_body_entered)

# Called when something enters the area
func _on_body_entered(body: Node):
	if triggered and trigger_once:
		return
	if not animations:
		return
	if not selected_animation:
		return
	if not animations.has_animation(selected_animation):
		return
	if not body.is_in_group("Player"):
		print("Body is not in the player group, so animation will not be played.")
		return
	
	if not Engine.is_editor_hint():
		animations.play(selected_animation)
		print("playing animation")
		triggered = true

# Editor-time dropdown logic
func _get_property_list():
	if animations:
		var anims = animations.get_animation_list()
		if anims.size() > 0:
			if selected_animation == "" or not anims.has(selected_animation):
				selected_animation = anims[0]  # default to first animation
			return [{
				"name": "selected_animation",
				"type": TYPE_STRING,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": String(",").join(anims),
				"usage": PROPERTY_USAGE_DEFAULT,
			}]
	return []
