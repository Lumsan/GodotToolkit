class_name FractureSystem
extends RefCounted


## Find or create a FracturedMesh for the given source mesh.
## If the mesh is already inside a FracturedMesh (i.e. it's a remainder), return that FracturedMesh.
## If it's a fresh mesh, create a new FracturedMesh.
static func get_or_create_fractured_mesh(
	mesh_inst: MeshInstance3D,
	scene_owner: Node
) -> FracturedMesh:
	# Check if this mesh is already a remainder inside a FracturedMesh
	var parent := mesh_inst.get_parent()
	if parent is FracturedMesh:
		FractureDebug.editor("Found existing FracturedMesh '%s' for mesh '%s'" % [
			parent.name, mesh_inst.name
		])
		return parent

	# Create new FracturedMesh
	var fm := FracturedMesh.new()
	fm.name = mesh_inst.name + "_Fractured"

	# Place as sibling of original mesh
	var mesh_parent: Node = mesh_inst.get_parent()
	if mesh_parent == null:
		FractureDebug.editor("Cannot create FracturedMesh: mesh '%s' has no parent" % mesh_inst.name)
		return null

	fm.global_transform = Transform3D.IDENTITY
	mesh_parent.add_child(fm)
	fm.owner = scene_owner

	# Initialize from source mesh
	fm.initialize_from_mesh(mesh_inst)

	# Hide original mesh
	mesh_inst.visible = false
	mesh_inst.set_meta("fracture_consumed", true)
	PhysicsLayer._set_collision_disabled_recursive(mesh_inst, true)

	FractureDebug.editor("Created new FracturedMesh '%s' from '%s'" % [fm.name, mesh_inst.name])
	return fm


## Build a fracture operation dictionary from a region and panel settings.
static func build_operation_data(
	region: FractureRegion,
	fragment_count: int,
	cap_material: Material,
	runtime_settings: Dictionary
) -> Dictionary:
	var seeds: Array = region.scatter_seeds()

	return {
		"region_shape": region.shape,
		"region_transform": region.global_transform,
		"region_extents": region.extents,
		"region_radius": region.sphere_radius,
		"cylinder_radius": region.cylinder_radius,
		"cylinder_height": region.cylinder_height,
		"fragment_count": fragment_count,
		"seeds": seeds,
		"cap_material": cap_material,
		"runtime_settings": runtime_settings
	}


## Build runtime settings dictionary from panel values.
static func build_runtime_settings(
	force_type: int,
	force_magnitude: float,
	force_direction: Vector3,
	settle_mode: int,
	fade_time: float,
	post_density: float
) -> Dictionary:
	return {
		"force_type": force_type,
		"force_magnitude": force_magnitude,
		"force_direction": force_direction,
		"settle_mode": settle_mode,
		"fade_time": fade_time,
		"post_density": post_density,
	}


## Main editor fracture entry point.
## Fractures all given meshes using the given region.
static func fracture_editor(
	meshes: Array,
	region: FractureRegion,
	fragment_count: int,
	cap_material: Material,
	force_type: int,
	force_magnitude: float,
	force_direction: Vector3,
	settle_mode: int,
	fade_time: float,
	post_density: float
) -> Dictionary:
	FractureDebug.editor("fracture_editor: meshes=%d" % meshes.size())

	var scene_owner: Node = EditorInterface.get_edited_scene_root()

	var runtime_settings: Dictionary = build_runtime_settings(
		force_type,
		force_magnitude,
		force_direction,
		settle_mode,
		fade_time,
		post_density
	)

	var all_fractured_meshes: Array = []
	var all_originals: Array = []
	var all_cluster_ids: Array = []

	for mesh_obj in meshes:
		var mesh_inst: MeshInstance3D = mesh_obj

		# Ensure editable instances
		var node: Node = mesh_inst
		while node != null:
			if node != scene_owner and node.scene_file_path != "":
				if not scene_owner.is_editable_instance(node):
					scene_owner.set_editable_instance(node, true)
					push_warning("Fracture: '%s' was not editable. Set to editable children automatically." % node.name)
			node = node.get_parent()

		var fm: FracturedMesh = get_or_create_fractured_mesh(mesh_inst, scene_owner)
		if fm == null:
			continue

		var op_data: Dictionary = build_operation_data(
			region,
			fragment_count,
			cap_material,
			runtime_settings
		)

		fm.apply_fracture(op_data)

		# Track what was created for undo
		var latest_op: Dictionary = fm.fracture_operations.back()
		all_cluster_ids.append({
			"fractured_mesh": fm,
			"cluster_id": latest_op["id"]
		})

		all_originals.append(mesh_inst)
		if not all_fractured_meshes.has(fm):
			all_fractured_meshes.append(fm)

	return {
		"fractured_meshes": all_fractured_meshes,
		"originals": all_originals,
		"cluster_ids": all_cluster_ids
	}


## Undo a specific cluster from a FracturedMesh.
static func undo_cluster(fm: FracturedMesh, cluster_id: int, original_mesh: MeshInstance3D = null) -> void:
	fm.remove_cluster_by_id(cluster_id)

	# If no more fractures remain, restore the original mesh
	if not fm.has_fractures():
		# Prefer the stored reference, fallback to passed-in original
		var mesh_to_restore: MeshInstance3D = fm.original_mesh_node
		if mesh_to_restore == null or not is_instance_valid(mesh_to_restore):
			mesh_to_restore = original_mesh

		if mesh_to_restore != null and is_instance_valid(mesh_to_restore):
			# Restore immediately
			mesh_to_restore.visible = true
			mesh_to_restore.set_meta("fracture_consumed", false)
			PhysicsLayer._set_collision_disabled_recursive(mesh_to_restore, false)
			
			FractureDebug.editor("Restored original mesh '%s' - visible=%s consumed=%s" % [
				mesh_to_restore.name,
				mesh_to_restore.visible,
				mesh_to_restore.get_meta("fracture_consumed", false)
			])
			
			# Also force property notification in editor
			if Engine.is_editor_hint():
				mesh_to_restore.notify_property_list_changed()

		fm.queue_free()

		FractureDebug.editor("FracturedMesh '%s' has no more fractures, restored original and removed" % fm.name)


## Refracture a specific cluster with new geometry settings.
static func refracture_cluster(
	fm: FracturedMesh,
	cluster_id: int,
	new_geometry_settings: Dictionary
) -> void:
	fm.refracture_cluster(cluster_id, new_geometry_settings)


## Update runtime-only settings on a cluster (no rebuild needed).
static func update_cluster_runtime(
	fm: FracturedMesh,
	cluster_id: int,
	settings: Dictionary
) -> void:
	fm.update_cluster_runtime_settings(cluster_id, settings)


## Runtime fracture (no editor dependency).
static func fracture_runtime(
	meshes: Array,
	region: FractureRegion,
	force_type: int,
	force_magnitude: float,
	force_direction: Vector3,
	settle_mode: int,
	fade_time: float,
	post_density: float,
	cap_material: Material = null
) -> Dictionary:
	FractureDebug.print_log("RUNTIME", "Starting runtime fracture for %d mesh(es)" % meshes.size())

	var all_bodies: Array = []
	var all_remainders: Array = []
	var originals: Array = []

	var planes: Array = region.get_clipping_planes()
	var seeds: Array = region.scatter_seeds()
	var cap_mat: Material = cap_material if cap_material != null else region.cap_material

	for mesh_obj in meshes:
		var mesh_inst: MeshInstance3D = mesh_obj
		var frac_result: FractureTypes.FractureResult = FractureLayer.fracture_mesh(
			mesh_inst, planes, seeds, cap_mat
		)

		var target_parent: Node = mesh_inst.get_parent()
		if target_parent == null:
			continue

		var scene_owner: Node = target_parent.owner if target_parent.owner != null else target_parent

		if frac_result.remainder != null:
			var remainder_mesh: MeshInstance3D = PhysicsLayer.setup_remainder(
				frac_result.remainder,
				target_parent
			)
			if remainder_mesh != null:
				target_parent.add_child(remainder_mesh)
				remainder_mesh.owner = scene_owner
				remainder_mesh.name = mesh_inst.name + "_remainder"
				all_remainders.append(remainder_mesh)

		var bodies: Array = PhysicsLayer.setup_fragments(
			frac_result.fragments,
			target_parent,
			force_type,
			force_magnitude,
			force_direction,
			region.get_center(),
			settle_mode,
			fade_time,
			1.0,
			post_density
		)
		all_bodies.append_array(bodies)

		mesh_inst.visible = false
		mesh_inst.set_meta("fracture_consumed", true)
		PhysicsLayer._set_collision_disabled_recursive(mesh_inst, true)
		originals.append(mesh_inst)

	return {
		"bodies": all_bodies,
		"remainders": all_remainders,
		"originals": originals
	}
