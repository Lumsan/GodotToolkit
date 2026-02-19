# game/ui/interaction_prompt.gd
## Simple UI that shows "Press [E] to Interact" when looking at something.
## This goes in your game folder, not the toolkit.
class_name InteractionPrompt
extends Control

@export var interaction_ray_path: NodePath
@export var prompt_label_path: NodePath
@export var action_name: StringName = "interact"

var _ray: InteractionRay
var _label: Label

func _ready() -> void:
	_ray = get_node_or_null(interaction_ray_path)
	_label = get_node_or_null(prompt_label_path)

	if not _ray or not _label:
		push_error("InteractionPrompt: Set interaction_ray_path and prompt_label_path")
		return

	_ray.focused.connect(_on_focused)
	_ray.unfocused.connect(_on_unfocused)
	_ray.interacted.connect(_on_interacted)
	visible = false

func _on_focused(interactable: Interactable) -> void:
	var key := _get_key_name()
	_label.text = "[%s] %s" % [key, interactable.interaction_prompt]
	visible = true

func _on_unfocused(_interactable: Interactable) -> void:
	visible = false

func _on_interacted(_interactable: Interactable) -> void:
	# Optional: flash or animate on interact
	pass

func _get_key_name() -> String:
	var events := InputMap.action_get_events(action_name)
	for event in events:
		if event is InputEventKey:
			return event.as_text().split(" ")[0]
	return "?"
