extends Resource
class_name ExceptionGroup
## Defines an exception group for the post-process mask system.
##
## Add nodes to the Godot group matching [member group_name].
## The mask system renders those nodes as a solid color into the
## corresponding RGB channel of the mask texture.

## The Godot group name. Nodes in this group become part of this exception.
@export var group_name: String = ""

## Which channel this group writes to. 0 = Red, 1 = Green, 2 = Blue.
@export_range(0, 2) var mask_channel: int = 0

## If true, the post-process shader skips these pixels entirely
## and outputs the raw scene color instead.
@export var bypass_main_shader: bool = true
