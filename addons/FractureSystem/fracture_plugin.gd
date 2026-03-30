@tool
extends EditorPlugin

var _panel: FracturePanel = null
var _session: FractureSession = null
var _gizmo_plugin: FractureRegionGizmo = null
var _cap_material_save_dialog: EditorFileDialog = null
var _cap_material_load_dialog: EditorFileDialog = null


func _enter_tree() -> void:
	FractureDebug.editor("Entering fracture plugin")

	_session = FractureSession.new()

	_panel = FracturePanel.new()
	_panel.name = "Fracture"

	# New fracture signals
	_panel.start_session_pressed.connect(_on_start_session)
	_panel.spawn_box_pressed.connect(_on_spawn_box)
	_panel.spawn_sphere_pressed.connect(_on_spawn_sphere)
	_panel.spawn_cylinder_pressed.connect(_on_spawn_cylinder)
	_panel.fracture_pressed.connect(_on_fracture)
	_panel.undo_pressed.connect(_on_undo)
	_panel.finish_pressed.connect(_on_finish)

	# Cap material signals
	_panel.new_cap_material_pressed.connect(_on_new_cap_material)
	_panel.edit_cap_material_pressed.connect(_on_edit_cap_material)
	_panel.reset_cap_material_pressed.connect(_on_reset_cap_material)
	_panel.load_cap_material_pressed.connect(_on_load_cap_material)

	# Cluster edit signals
	_panel.refracture_cluster_pressed.connect(_on_refracture_cluster)
	_panel.delete_cluster_pressed.connect(_on_delete_cluster)
	_panel.edit_trigger_path_pressed.connect(_on_edit_trigger_path)

	# File dialogs
	_cap_material_save_dialog = EditorFileDialog.new()
	_cap_material_save_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_cap_material_save_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_cap_material_save_dialog.title = "Save New Cap Material"
	_cap_material_save_dialog.add_filter("*.tres ; Godot Material Resource")
	_cap_material_save_dialog.add_filter("*.res ; Godot Resource")
	_cap_material_save_dialog.file_selected.connect(_on_cap_material_save_selected)
	get_editor_interface().get_base_control().add_child(_cap_material_save_dialog)

	_cap_material_load_dialog = EditorFileDialog.new()
	_cap_material_load_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILE
	_cap_material_load_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_cap_material_load_dialog.title = "Load Cap Material"
	_cap_material_load_dialog.add_filter("*.tres ; Godot Material Resource")
	_cap_material_load_dialog.add_filter("*.res ; Godot Resource")
	_cap_material_load_dialog.file_selected.connect(_on_cap_material_load_selected)
	get_editor_interface().get_base_control().add_child(_cap_material_load_dialog)

	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _panel)
	_panel.set_status("Ready. Press Start Fracture Session.")

	_gizmo_plugin = FractureRegionGizmo.new()
	add_node_3d_gizmo_plugin(_gizmo_plugin)

	add_custom_type(
		"FractureRegion",
		"Node3D",
		preload("res://addons/FractureSystem/fracture_region.gd"),
		null
	)

	# Connect to selection changes for cluster detection
	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)
	
	_setup_collision_layer_names()


func _exit_tree() -> void:
	FractureDebug.editor("Exiting fracture plugin")

	get_editor_interface().get_selection().selection_changed.disconnect(_on_selection_changed)

	if _gizmo_plugin != null:
		remove_node_3d_gizmo_plugin(_gizmo_plugin)
		_gizmo_plugin = null

	remove_custom_type("FractureRegion")

	if _cap_material_save_dialog != null:
		_cap_material_save_dialog.queue_free()
		_cap_material_save_dialog = null

	if _cap_material_load_dialog != null:
		_cap_material_load_dialog.queue_free()
		_cap_material_load_dialog = null

	if _panel != null:
		remove_control_from_docks(_panel)
		_panel.queue_free()
		_panel = null

	_session = null


# ============================================================
# SELECTION DETECTION
# ============================================================

func _on_selection_changed() -> void:
	var selected: Array = get_editor_interface().get_selection().get_selected_nodes()
	if selected.size() != 1:
		return

	var sel_node: Node = selected[0]

	# Try to find the FractureCluster ancestor for any selected node
	var cluster: FractureCluster = _find_ancestor_cluster(sel_node)
	if cluster != null:
		var fm: FracturedMesh = _find_parent_fractured_mesh(cluster)
		if fm != null:
			_panel.set_mode_edit_cluster(cluster, fm)
			return

	# Nothing relevant selected — if in edit mode, switch back
	if _panel.is_in_edit_mode():
		_panel.set_mode_new_fracture()


func _find_ancestor_cluster(node: Node) -> FractureCluster:
	var current := node
	while current != null:
		if current is FractureCluster:
			return current
		current = current.get_parent()
	return null


func _find_parent_fractured_mesh(node: Node) -> FracturedMesh:
	var parent := node.get_parent()
	while parent != null:
		if parent is FracturedMesh:
			return parent
		parent = parent.get_parent()
	return null


# ============================================================
# SHORTCUTS
# ============================================================

func _shortcut_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.shift_pressed and event.keycode == KEY_F:
			if _panel != null:
				_panel.grab_focus()
				_panel.set_status("Fracture panel focused.")
				FractureDebug.editor("Shift+F pressed -> panel focused")
				get_viewport().set_input_as_handled()


# ============================================================
# SESSION MANAGEMENT
# ============================================================

func _on_start_session() -> void:
	_session.start()
	_panel.set_status("Session started. Spawn a region with B/S/C while panel is focused.")


func _on_spawn_box() -> void:
	_spawn_region(FractureRegion.RegionShape.BOX)


func _on_spawn_sphere() -> void:
	_spawn_region(FractureRegion.RegionShape.SPHERE)


func _on_spawn_cylinder() -> void:
	_spawn_region(FractureRegion.RegionShape.CYLINDER)


func _spawn_region(shape_type: int) -> void:
	if not _session.active:
		_panel.set_status("Start a session first.")
		return

	var scene_root: Node = get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		_panel.set_status("No edited scene root.")
		return

	if _session.current_region != null and is_instance_valid(_session.current_region):
		_session.current_region.queue_free()
		_session.current_region = null

	var region := FractureRegion.new()
	region.name = "FractureRegion"
	region.shape = shape_type
	region.fragment_count = _panel.fragment_count

	scene_root.add_child(region)
	region.owner = scene_root

	region.global_position = Vector3.ZERO

	_session.current_region = region

	get_editor_interface().get_selection().clear()
	get_editor_interface().get_selection().add_node(region)

	var shape_name: String
	match shape_type:
		FractureRegion.RegionShape.BOX:
			shape_name = "Box"
		FractureRegion.RegionShape.SPHERE:
			shape_name = "Sphere"
		FractureRegion.RegionShape.CYLINDER:
			shape_name = "Cylinder"
		_:
			shape_name = "Unknown"

	_panel.set_status("Spawned %s region. Move/resize it, then press Fracture." % shape_name)


# ============================================================
# NEW FRACTURE
# ============================================================

func _on_fracture() -> void:
	if not _session.active:
		_panel.set_status("Start a session first.")
		return

	if _session.current_region == null or not is_instance_valid(_session.current_region):
		_panel.set_status("No active region. Spawn one first.")
		return

	_session.current_region.fragment_count = _panel.fragment_count

	var meshes: Array = _session.current_region.find_overlapping_meshes()
	if meshes.is_empty():
		_panel.set_status("No meshes found in region.")
		return

	_panel.set_status("Fracturing %d mesh(es)..." % meshes.size())

	var cap_material: Material = null
	if _panel.use_separate_cap_material:
		cap_material = _panel.cap_material_override

	var result: Dictionary = FractureSystem.fracture_editor(
		meshes,
		_session.current_region,
		_panel.fragment_count,
		cap_material,
		_panel.force_type,
		_panel.force_magnitude,
		_panel.force_direction,
		_panel.settle_mode,
		_panel.fade_time,
		_panel.post_density
	)

	# Push undo entry
	_session.push_undo(result)

	# Remove region after fracture
	if _session.current_region != null and is_instance_valid(_session.current_region):
		_session.current_region.queue_free()
		_session.current_region = null

	var cluster_count: int = result.get("cluster_ids", []).size()
	_panel.set_status("Fracture complete. %d cluster(s) created." % cluster_count)


# ============================================================
# UNDO
# ============================================================

func _on_undo() -> void:
	if not _session.active:
		_panel.set_status("No active session.")
		return

	var entry: Dictionary = _session.pop_undo()
	if entry.is_empty():
		_panel.set_status("Nothing to undo.")
		return

	var cluster_ids: Array = entry.get("cluster_ids", [])
	for ci in cluster_ids:
		var fm: FracturedMesh = ci.get("fractured_mesh")
		var cluster_id: int = ci.get("cluster_id", -1)

		if fm == null or not is_instance_valid(fm):
			continue

		FractureSystem.undo_cluster(fm, cluster_id, null)

	_panel.set_status("Undo completed.")


# ============================================================
# CLUSTER EDITING
# ============================================================

func _on_refracture_cluster() -> void:
	if not _panel.is_in_edit_mode():
		_panel.set_status("Not in cluster edit mode.")
		return

	var fm: FracturedMesh = _panel.get_editing_fractured_mesh()
	var cluster_id: int = _panel.get_editing_cluster_id()

	if fm == null or not is_instance_valid(fm):
		_panel.set_status("FracturedMesh no longer valid.")
		_panel.set_mode_new_fracture()
		return

	var op: Dictionary = fm.get_operation_by_id(cluster_id)
	if op.is_empty():
		_panel.set_status("Cannot find fracture operation for this cluster.")
		return

	var new_frag_count: int = _panel.get_cluster_edit_fragment_count()
	var new_seeds: Array = _regenerate_seeds(op, new_frag_count)

	var new_settings := {
		"fragment_count": new_frag_count,
		"seeds": new_seeds,
	}

	if _panel.use_separate_cap_material:
		new_settings["cap_material"] = _panel.cap_material_override

	FractureSystem.refracture_cluster(fm, cluster_id, new_settings)

	# Re-select the updated cluster
	var updated_cluster: FractureCluster = fm.get_cluster_by_id(cluster_id)
	if updated_cluster != null:
		_panel.set_mode_edit_cluster(updated_cluster, fm)
		get_editor_interface().get_selection().clear()
		get_editor_interface().get_selection().add_node(updated_cluster)

	_panel.set_status("Refractured cluster id=%d with %d fragments." % [cluster_id, new_frag_count])


func _on_delete_cluster() -> void:
	if not _panel.is_in_edit_mode():
		_panel.set_status("Not in cluster edit mode.")
		return

	var fm: FracturedMesh = _panel.get_editing_fractured_mesh()
	var cluster_id: int = _panel.get_editing_cluster_id()

	if fm == null or not is_instance_valid(fm):
		_panel.set_status("FracturedMesh no longer valid.")
		_panel.set_mode_new_fracture()
		return

	FractureSystem.undo_cluster(fm, cluster_id, null)

	_panel.set_mode_new_fracture()
	_panel.set_status("Deleted cluster id=%d." % cluster_id)


func _regenerate_seeds(op: Dictionary, fragment_count: int) -> Array:
	var region_shape: int = op.get("region_shape", FractureRegion.RegionShape.BOX)
	var region_transform: Transform3D = op.get("region_transform", Transform3D.IDENTITY)
	var region_extents: Vector3 = op.get("region_extents", Vector3.ONE)
	var region_radius: float = op.get("region_radius", 1.0)
	var cyl_radius: float = op.get("region_radius", 1.0)
	var cyl_height: float = op.get("cylinder_height", 2.0)

	var seeds: Array = []

	match region_shape:
		FractureRegion.RegionShape.BOX:
			for i in range(fragment_count):
				var local := Vector3(
					randf_range(-region_extents.x, region_extents.x),
					randf_range(-region_extents.y, region_extents.y),
					randf_range(-region_extents.z, region_extents.z)
				)
				seeds.append(region_transform * local)

		FractureRegion.RegionShape.SPHERE:
			var actual_radius: float = region_radius * region_transform.basis.x.length()
			for i in range(fragment_count):
				while true:
					var local := Vector3(
						randf_range(-1.0, 1.0),
						randf_range(-1.0, 1.0),
						randf_range(-1.0, 1.0)
					)
					if local.length_squared() <= 1.0:
						seeds.append(region_transform.origin + local * actual_radius)
						break

		FractureRegion.RegionShape.CYLINDER:
			var actual_radius: float = cyl_radius * region_transform.basis.x.length()
			var half_height: float = cyl_height * 0.5
			for i in range(fragment_count):
				var r: float = sqrt(randf()) * actual_radius
				var theta: float = randf() * TAU
				var h: float = randf_range(-half_height, half_height)
				var local := Vector3(
					r * cos(theta),
					h,
					r * sin(theta)
				)
				seeds.append(region_transform * local)

	return seeds


# ============================================================
# FINISH
# ============================================================

func _on_finish() -> void:
	if _session != null:
		_session.finish()
	_panel.set_mode_new_fracture()
	_panel.set_status("Session finished.")


# ============================================================
# CAP MATERIAL
# ============================================================

func _on_new_cap_material() -> void:
	if _cap_material_save_dialog == null:
		return
	_cap_material_save_dialog.current_dir = "res://"
	_cap_material_save_dialog.current_file = "fracture_cap_material.tres"
	_cap_material_save_dialog.popup_centered_ratio(0.5)
	_panel.set_status("Choose where to save the new cap material.")


func _on_cap_material_save_selected(path: String) -> void:
	var mat := StandardMaterial3D.new()
	mat.resource_name = path.get_file().get_basename()
	mat.albedo_color = Color(0.9, 0.9, 0.9)
	mat.roughness = 0.9
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_BACK
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	var err := ResourceSaver.save(mat, path)
	if err != OK:
		_panel.set_status("Failed to save cap material: %s" % path)
		return

	var saved_res: Resource = load(path)
	if saved_res is Material:
		_panel.set_cap_material(saved_res)
		_panel.set_use_separate_cap_material(true)
		_panel.set_status("Created cap material: %s" % path)
	else:
		_panel.set_status("Saved material, but failed to reload it.")


func _on_edit_cap_material() -> void:
	if _panel == null:
		return
	var mat: Material = _panel.cap_material_override
	if mat == null:
		_panel.set_status("No cap material selected.")
		return
	_edit_resource_and_focus_inspector(mat)
	_panel.set_status("Editing cap material in Inspector.")


func _on_reset_cap_material() -> void:
	if _panel == null:
		return
	_panel.set_cap_material(null)
	_panel.set_use_separate_cap_material(false)
	_panel.set_status("Cap material reset.")


func _on_load_cap_material() -> void:
	if _cap_material_load_dialog == null:
		return
	_cap_material_load_dialog.current_dir = "res://"
	_cap_material_load_dialog.popup_centered_ratio(0.5)
	_panel.set_status("Choose a cap material to load.")


func _on_cap_material_load_selected(path: String) -> void:
	var res: Resource = load(path)
	if res is Material:
		_panel.set_cap_material(res)
		_panel.set_use_separate_cap_material(true)
		_panel.set_status("Loaded cap material: %s" % path)
	else:
		_panel.set_status("Selected resource is not a Material.")


func _edit_resource_and_focus_inspector(res: Resource) -> void:
	if res == null:
		return
	var editor := get_editor_interface()
	editor.edit_resource(res)
	var base: Control = editor.get_base_control()
	if base == null:
		return
	_focus_inspector_in_tree(base)


func _focus_inspector_in_tree(root: Node) -> bool:
	if root == null:
		return false
	if root is TabContainer:
		var tc: TabContainer = root
		for i in range(tc.get_tab_count()):
			if tc.get_tab_title(i).to_lower() == "inspector":
				tc.current_tab = i
				return true
	for child in root.get_children():
		if _focus_inspector_in_tree(child):
			return true
	return false

func _on_edit_trigger_path() -> void:
	if not _panel.is_in_edit_mode():
		return

	var cluster: FractureCluster = _panel.get_editing_cluster()
	if cluster == null or not is_instance_valid(cluster):
		_panel.set_status("No valid cluster selected.")
		return

	get_editor_interface().edit_node(cluster)
	get_editor_interface().inspect_object(cluster)
	_panel.set_status("Set trigger_area_path in the Inspector panel.")

func _setup_collision_layer_names() -> void:
	var layer_names := {
		"layer_names/3d_physics/layer_1": "Environment",
		"layer_names/3d_physics/layer_5": "Fragments (Solid)",
		"layer_names/3d_physics/layer_6": "Fragments (Pushable)",
		"layer_names/3d_physics/layer_7": "Fragments (No Interact)",
	}

	for key in layer_names:
		var current: String = ProjectSettings.get_setting(key, "")
		if current != "" and current != layer_names[key]:
			push_warning("Fracture System: Collision layer '%s' is named '%s', expected '%s'." % [
				key.get_file(),
				current,
				layer_names[key]
			])
		elif current == "":
			ProjectSettings.set_setting(key, layer_names[key])

	ProjectSettings.save()
