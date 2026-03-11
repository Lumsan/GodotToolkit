extends "res://Toolkit/GodotToolkit/presets/base_preset.gd"
## Builds a SubViewport-based post-processing pipeline.
##
## Resulting structure:
##   Root (Node)  ← post_process_manager.gd
##   ├── MainScene (SubViewport)         ← scene content lives here
##   ├── MaskViewport (SubViewport)      ← renders exception-group masks
##   │   └── MaskCamera (Camera3D)       ← synced to main camera at runtime
##   └── PostProcess (CanvasLayer)
##       ├── MainDisplay (TextureRect)   ← shows MainScene render
##       └── ShaderOverlay (ColorRect)   ← assign your ShaderMaterial here

const MANAGER_SCRIPT := "res://Toolkit/GodotToolkit/runtime/post_process_manager.gd"


func get_preset_name() -> String:
	return "Post-Process Pipeline"


func get_description() -> String:
	return (
		"SubViewport-based post-processing with exception-group masks.\n\n"
		+ "• MainScene SubViewport renders your scene content\n"
		+ "• MaskViewport encodes exception groups as RGB channels\n"
		+ "• ShaderOverlay applies your post-process shader\n"
		+ "• Assign ExceptionGroup resources on the root to tag groups\n"
		+ "• See toolkit/shaders/example_post_process.gdshader for reference"
	)


func build_new_scene() -> Node:
	var root := Node.new()
	root.name = "GameScene"
	_attach_manager(root)
	_build_structure(root, root)
	return root


func inject_into_current_scene(root: Node) -> bool:
	# Snapshot existing children before we add anything.
	var existing: Array[Node] = []
	for child in root.get_children():
		existing.append(child)

	# Build the pipeline nodes.
	var main_vp := _build_structure(root, root)

	# Move all original children into the MainScene SubViewport.
	for child in existing:
		child.reparent(main_vp)
		# Owners already point to root — reparent preserves them.

	_attach_manager(root)
	return true


# ---- internals ----

func _attach_manager(root: Node) -> void:
	var script = load(MANAGER_SCRIPT)
	if script:
		root.set_script(script)
	else:
		push_warning("PostProcessPreset: manager script not found at " + MANAGER_SCRIPT)


## Builds the SubViewport / CanvasLayer structure under [param parent].
## Returns the MainScene SubViewport so inject can reparent into it.
func _build_structure(parent: Node, owner: Node) -> SubViewport:
	# --- MainScene ---
	var main_vp := SubViewport.new()
	main_vp.name = "MainScene"
	main_vp.handle_input_locally = false
	main_vp.size = Vector2i(1152, 648)
	main_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(main_vp)
	main_vp.owner = owner

	# --- MaskViewport ---
	var mask_vp := SubViewport.new()
	mask_vp.name = "MaskViewport"
	mask_vp.own_world_3d = true  # Back to separate world
	mask_vp.handle_input_locally = false
	mask_vp.size = Vector2i(1152, 648)
	mask_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	mask_vp.transparent_bg = true
	parent.add_child(mask_vp)
	mask_vp.owner = owner

	var mask_cam := Camera3D.new()
	mask_cam.name = "MaskCamera"
	mask_vp.add_child(mask_cam)
	mask_cam.owner = owner

	# --- PostProcess layer ---
	var canvas := CanvasLayer.new()
	canvas.name = "PostProcess"
	canvas.layer = 100
	parent.add_child(canvas)
	canvas.owner = owner

	var tex_rect := TextureRect.new()
	tex_rect.name = "MainDisplay"
	tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(tex_rect)
	tex_rect.owner = owner

	var shader_rect := ColorRect.new()
	shader_rect.name = "ShaderOverlay"
	shader_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader_rect.color = Color(0, 0, 0, 0)
	canvas.add_child(shader_rect)
	shader_rect.owner = owner

	return main_vp
