@tool
extends Node3D
class_name FracturedMesh

## The persistent fractured-state owner for one source mesh.
## Stores source geometry, fracture operation history, and owns
## the current remainder node and all FractureCluster children.

# ============================================================
# PERSISTENT STATE (saved with scene)
# ============================================================

## Path to the original mesh node that was fractured
@export var original_mesh_path: NodePath = NodePath()

## Serialized fracture operation history
@export var fracture_operations_data: Array[Dictionary] = []

## Cached source mesh resource
@export var source_mesh_resource: Mesh = null

## Cached source materials
@export var source_materials_data: Array = []

## Source transform (where the original mesh was)
@export var source_transform: Transform3D = Transform3D.IDENTITY

# ============================================================
# RUNTIME STATE (not saved, rebuilt on load)
# ============================================================

## Extracted polygon data from source mesh (rebuilt on _ready if needed)
var source_polys: Array = []

## Reference to original mesh node (resolved from path)
var original_mesh_node: MeshInstance3D = null

## Active fracture operations (loaded from fracture_operations_data)
var fracture_operations: Array = []

## Reference to remainder child node
var remainder_node: MeshInstance3D = null

## References to cluster child nodes
var clusters: Array = []

var _next_op_id: int = 0
var _initialized: bool = false


# ============================================================
# INITIALIZATION
# ============================================================

func _ready() -> void:
	if Engine.is_editor_hint():
		_initialize_from_saved_data()


func _initialize_from_saved_data() -> void:
	if _initialized:
		return
	_initialized = true

	# Resolve original mesh reference
	if original_mesh_path != NodePath():
		var root := get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
		if root != null:
			var node := root.get_node_or_null(original_mesh_path)
			if node is MeshInstance3D:
				original_mesh_node = node

	# Load fracture operations from saved data
	fracture_operations = []
	for op_data in fracture_operations_data:
		fracture_operations.append(op_data.duplicate(true))

	# Find next op ID
	_next_op_id = 0
	for op in fracture_operations:
		var op_id: int = op.get("id", -1)
		if op_id >= _next_op_id:
			_next_op_id = op_id + 1

	# Extract source polys from source mesh if not already done
	if source_polys.is_empty() and source_mesh_resource != null:
		_extract_source_polys_from_resource()

	# Find remainder and clusters in children
	_find_child_references()

	FractureDebug.editor("FracturedMesh '%s' initialized from saved data: ops=%d polys=%d" % [
		name,
		fracture_operations.size(),
		source_polys.size()
	])


func _extract_source_polys_from_resource() -> void:
	if source_mesh_resource == null:
		return

	# Create temporary mesh instance to extract polys
	var temp_mesh := MeshInstance3D.new()
	temp_mesh.mesh = source_mesh_resource
	temp_mesh.global_transform = source_transform

	# Set materials
	for i in range(source_materials_data.size()):
		if i < source_mesh_resource.get_surface_count():
			temp_mesh.set_surface_override_material(i, source_materials_data[i])

	var extracted: Dictionary = FractureLayer.extract_polygons(temp_mesh)
	source_polys = extracted["polys"]

	temp_mesh.queue_free()


func _find_child_references() -> void:
	remainder_node = null
	clusters.clear()

	for child in get_children():
		if child.name == "Remainder" and child is MeshInstance3D:
			remainder_node = child
		elif child is FractureCluster:
			clusters.append(child)


func initialize_from_mesh(mesh_inst: MeshInstance3D) -> void:
	source_mesh_resource = mesh_inst.mesh
	source_transform = mesh_inst.global_transform
	original_mesh_node = mesh_inst

	# Save path to original mesh
	var root := get_tree().edited_scene_root if Engine.is_editor_hint() else get_tree().current_scene
	if root != null:
		original_mesh_path = root.get_path_to(mesh_inst)

	# Save materials
	source_materials_data = []
	if mesh_inst.mesh != null:
		for i in range(mesh_inst.mesh.get_surface_count()):
			var mat: Material = mesh_inst.get_active_material(i)
			source_materials_data.append(mat)

	# Extract polygons
	var extracted: Dictionary = FractureLayer.extract_polygons(mesh_inst)
	source_polys = extracted["polys"]

	_initialized = true

	FractureDebug.editor("FracturedMesh initialized from '%s': polys=%d materials=%d" % [
		mesh_inst.name,
		source_polys.size(),
		source_materials_data.size()
	])


# ============================================================
# FRACTURE OPERATIONS
# ============================================================

func apply_fracture(op_data: Dictionary) -> void:
	op_data["id"] = _next_op_id
	_next_op_id += 1
	fracture_operations.append(op_data)

	# Save to persistent storage
	fracture_operations_data.append(op_data.duplicate(true))

	FractureDebug.editor("FracturedMesh: applied fracture op id=%d, total ops=%d" % [
		op_data["id"],
		fracture_operations.size()
	])

	rebuild_from_history()


func remove_cluster_by_id(cluster_id: int) -> void:
	var new_ops: Array = []
	var new_ops_data: Array[Dictionary] = []
	for op in fracture_operations:
		if op["id"] != cluster_id:
			new_ops.append(op)
			new_ops_data.append(op.duplicate(true))
	fracture_operations = new_ops
	fracture_operations_data = new_ops_data

	FractureDebug.editor("FracturedMesh: removed cluster id=%d, remaining ops=%d" % [
		cluster_id,
		fracture_operations.size()
	])

	rebuild_from_history()


func refracture_cluster(cluster_id: int, new_geometry_settings: Dictionary) -> void:
	for i in range(fracture_operations.size()):
		var op: Dictionary = fracture_operations[i]
		if op["id"] == cluster_id:
			if new_geometry_settings.has("fragment_count"):
				op["fragment_count"] = new_geometry_settings["fragment_count"]
			if new_geometry_settings.has("seeds"):
				op["seeds"] = new_geometry_settings["seeds"]
			if new_geometry_settings.has("cap_material"):
				op["cap_material"] = new_geometry_settings["cap_material"]
			if new_geometry_settings.has("region_shape"):
				op["region_shape"] = new_geometry_settings["region_shape"]
			if new_geometry_settings.has("region_transform"):
				op["region_transform"] = new_geometry_settings["region_transform"]
			if new_geometry_settings.has("region_extents"):
				op["region_extents"] = new_geometry_settings["region_extents"]
			if new_geometry_settings.has("region_radius"):
				op["region_radius"] = new_geometry_settings["region_radius"]

			# Update persistent storage
			fracture_operations_data[i] = op.duplicate(true)
			break

	FractureDebug.editor("FracturedMesh: refracturing cluster id=%d" % cluster_id)

	rebuild_from_history()


func update_cluster_runtime_settings(cluster_id: int, settings: Dictionary) -> void:
	for cluster in clusters:
		if cluster.cluster_id == cluster_id:
			cluster.apply_runtime_settings(settings)
			break

	# Also update the stored operation so settings persist across rebuilds
	for i in range(fracture_operations.size()):
		var op: Dictionary = fracture_operations[i]
		if op["id"] == cluster_id:
			if not op.has("runtime_settings"):
				op["runtime_settings"] = {}
			op["runtime_settings"].merge(settings, true)
			
			# Update persistent storage
			fracture_operations_data[i] = op.duplicate(true)
			break


func clear_all_fractures() -> void:
	fracture_operations.clear()
	fracture_operations_data.clear()
	FractureDebug.editor("FracturedMesh: cleared all fractures")
	rebuild_from_history()


func get_cluster_by_id(cluster_id: int) -> FractureCluster:
	for cluster in clusters:
		if cluster.cluster_id == cluster_id:
			return cluster
	return null


func get_operation_by_id(op_id: int) -> Dictionary:
	for op in fracture_operations:
		if op["id"] == op_id:
			return op
	return {}


func has_fractures() -> bool:
	return not fracture_operations.is_empty()


# ============================================================
# REBUILD FROM HISTORY
# ============================================================

func rebuild_from_history() -> void:
	FractureDebug.editor("FracturedMesh: rebuild_from_history start, ops=%d" % fracture_operations.size())

	# --- Clear existing generated nodes ---
	if remainder_node != null and is_instance_valid(remainder_node):
		remainder_node.queue_free()
		remainder_node = null

	for cluster in clusters:
		if is_instance_valid(cluster):
			cluster.queue_free()
	clusters.clear()

	var scene_owner: Node = null
	if Engine.is_editor_hint():
		scene_owner = EditorInterface.get_edited_scene_root()
	else:
		scene_owner = owner if owner != null else self

	# --- Start from source polys ---
	var current_polys: Array = []
	for p in source_polys:
		current_polys.append(p.duplicate_poly())

	var current_materials: Array = source_materials_data.duplicate()

	# --- If no operations, just build remainder from source ---
	if fracture_operations.is_empty():
		_build_remainder(current_polys, current_materials, null, scene_owner)
		FractureDebug.editor("FracturedMesh: rebuilt with no fracture ops — remainder only")
		return

	# --- Apply each fracture operation in order ---
	for op in fracture_operations:
		var region_planes: Array = _build_region_planes(op)
		var seeds: Array = op.get("seeds", [])
		var cap_material: Material = op.get("cap_material", null)

		if seeds.is_empty():
			FractureDebug.editor("FracturedMesh: op id=%d has no seeds, skipping" % op["id"])
			continue

		# Clip current polys to region
		var clip_result: Dictionary = FractureLayer.clip_to_region(current_polys, region_planes)
		var inside_polys: Array = clip_result["inside"]
		var outside_polys: Array = clip_result["outside"]

		FractureDebug.editor("FracturedMesh: op id=%d clip -> inside=%d outside=%d" % [
			op["id"],
			inside_polys.size(),
			outside_polys.size()
		])

		# Build remainder polys with caps
		var remainder_polys: Array = []
		for p in outside_polys:
			remainder_polys.append(p.duplicate_poly())

		for plane in region_planes:
			var cap: FractureTypes.FracPoly = FractureLayer.generate_convex_caps_for_plane(
				outside_polys,
				plane,
				-plane.normal,
				FractureTypes.CAP_MAT_IDX
			)
			if cap != null:
				remainder_polys.append(cap)

		# Update current polys to be the remainder for next operation
		current_polys = remainder_polys

		# Generate fragments via voronoi
		if inside_polys.is_empty():
			FractureDebug.editor("FracturedMesh: op id=%d has no inside polys, no cluster" % op["id"])
			continue

		var cells: Array = FractureLayer.voronoi_fracture(
			inside_polys,
			seeds,
			FractureTypes.CAP_MAT_IDX,
			region_planes
		)

		# Build cluster
		var cluster := FractureCluster.new()
		cluster.name = "FractureCluster_%d" % op["id"]
		cluster.cluster_id = op["id"]

		# Apply runtime settings if stored
		if op.has("runtime_settings"):
			cluster.apply_runtime_settings(op["runtime_settings"])

		# Set explosion origin from region center
		var region_transform: Transform3D = op.get("region_transform", Transform3D.IDENTITY)
		cluster.use_cluster_position_as_origin = false
		cluster.explicit_explosion_origin = region_transform.origin

		add_child(cluster)
		if scene_owner != null:
			cluster.owner = scene_owner

		# Build fragment bodies inside cluster
		var fragment_meshes: Array = []
		for ci in range(cells.size()):
			var cell: Dictionary = cells[ci]
			var cell_polys: Array = cell["polys"]
			var frag_data: Dictionary = FractureLayer.build_centered_fragment(
				cell_polys,
				current_materials,
				cap_material
			)
			if frag_data.is_empty():
				continue

			var frag_inst: MeshInstance3D = frag_data["mesh_instance"]
			frag_inst.position = frag_data["centroid"]
			frag_inst.name = "Fragment_%d" % ci
			frag_inst.set_meta("fragment_centroid", frag_data["centroid"])
			fragment_meshes.append(frag_inst)

		# Convert to physics bodies
		var bodies: Array = PhysicsLayer.setup_fragments_editor(fragment_meshes, cluster)
		for body in bodies:
			if scene_owner != null:
				body.owner = scene_owner
				PhysicsLayer._set_owner_recursive(body, scene_owner)

		clusters.append(cluster)

		FractureDebug.editor("FracturedMesh: op id=%d produced %d bodies" % [
			op["id"],
			bodies.size()
		])

	# --- Build final remainder ---
	_build_remainder(current_polys, current_materials, null, scene_owner)

	FractureDebug.editor("FracturedMesh: rebuild complete, clusters=%d remainder=%s" % [
		clusters.size(),
		remainder_node != null
	])


func _build_remainder(polys: Array, materials: Array, cap_material: Material, scene_owner: Node) -> void:
	if polys.is_empty():
		FractureDebug.editor("FracturedMesh: no polys for remainder")
		return

	var remainder_mesh_inst: MeshInstance3D = FractureLayer.build_mesh_from_polys(
		polys,
		materials,
		cap_material
	)

	if remainder_mesh_inst == null:
		FractureDebug.editor("FracturedMesh: build_mesh_from_polys returned null for remainder")
		return

	var final_remainder: MeshInstance3D = PhysicsLayer.setup_remainder(remainder_mesh_inst, self)
	if final_remainder == null:
		FractureDebug.editor("FracturedMesh: setup_remainder returned null")
		return

	final_remainder.name = "Remainder"
	add_child(final_remainder)

	if scene_owner != null:
		final_remainder.owner = scene_owner
		PhysicsLayer._set_owner_recursive(final_remainder, scene_owner)

	remainder_node = final_remainder


func _build_region_planes(op: Dictionary) -> Array:
	var region_shape: int = op.get("region_shape", FractureRegion.RegionShape.BOX)
	var region_transform: Transform3D = op.get("region_transform", Transform3D.IDENTITY)
	var region_extents: Vector3 = op.get("region_extents", Vector3.ONE)
	var region_radius: float = op.get("region_radius", 1.0)

	match region_shape:
		FractureRegion.RegionShape.BOX:
			return _build_box_planes(region_transform, region_extents)
		FractureRegion.RegionShape.SPHERE:
			return _build_sphere_planes(region_transform, region_radius)
		FractureRegion.RegionShape.CYLINDER:
			var cyl_radius: float = op.get("cylinder_radius", region_radius)
			var cyl_height: float = op.get("cylinder_height", 2.0)
			return _build_cylinder_planes(region_transform, cyl_radius, cyl_height)

	return []


func _build_box_planes(xf: Transform3D, extents: Vector3) -> Array:
	var planes: Array = []
	var origin: Vector3 = xf.origin
	var axes: Array = [xf.basis.x, xf.basis.y, xf.basis.z]
	var half: Array = [extents.x, extents.y, extents.z]

	for i in range(3):
		var axis_dir: Vector3 = axes[i]
		var axis_len: float = axis_dir.length()
		if axis_len < FractureTypes.EPSILON:
			continue

		var axis_norm: Vector3 = axis_dir / axis_len
		var extent: float = half[i] * axis_len

		var n_pos: Vector3 = -axis_norm
		var d_pos: float = n_pos.dot(origin + axis_norm * extent)
		planes.append(Plane(n_pos, d_pos))

		var n_neg: Vector3 = axis_norm
		var d_neg: float = n_neg.dot(origin - axis_norm * extent)
		planes.append(Plane(n_neg, d_neg))

	return planes


func _build_sphere_planes(xf: Transform3D, radius: float) -> Array:
	var planes: Array = []
	var origin: Vector3 = xf.origin
	var num_planes := 42
	var golden_ratio: float = (1.0 + sqrt(5.0)) * 0.5
	var actual_radius: float = radius * xf.basis.x.length()

	for i in range(num_planes):
		var theta: float = acos(1.0 - 2.0 * (float(i) + 0.5) / float(num_planes))
		var phi: float = TAU * float(i) / golden_ratio

		var dir := Vector3(
			sin(theta) * cos(phi),
			sin(theta) * sin(phi),
			cos(theta)
		).normalized()

		var n: Vector3 = -dir
		var point_on_sphere: Vector3 = origin + dir * actual_radius
		var d: float = n.dot(point_on_sphere)
		planes.append(Plane(n, d))

	return planes


# ============================================================
# UTILITY
# ============================================================

func find_cluster_for_body(body: RigidBody3D) -> FractureCluster:
	var parent := body.get_parent()
	if parent is FractureCluster:
		return parent
	return null

func _build_cylinder_planes(xf: Transform3D, radius: float, height: float) -> Array:
	var planes: Array = []
	var origin: Vector3 = xf.origin

	# Top and bottom cap planes
	var up: Vector3 = xf.basis.y
	var up_len: float = up.length()
	if up_len < FractureTypes.EPSILON:
		return planes
	var up_norm: Vector3 = up / up_len
	var half_height: float = (height * 0.5) * up_len

	# Top plane (pointing down into cylinder)
	var top_point: Vector3 = origin + up_norm * half_height
	var n_top: Vector3 = -up_norm
	planes.append(Plane(n_top, n_top.dot(top_point)))

	# Bottom plane (pointing up into cylinder)
	var bottom_point: Vector3 = origin - up_norm * half_height
	var n_bottom: Vector3 = up_norm
	planes.append(Plane(n_bottom, n_bottom.dot(bottom_point)))

	# Radial planes
	var num_sides := 24
	var actual_radius: float = radius * xf.basis.x.length()

	for i in range(num_sides):
		var angle: float = (TAU * float(i)) / float(num_sides)
		var local_dir := Vector3(cos(angle), 0.0, sin(angle))
		var world_dir: Vector3 = (xf.basis * local_dir)
		world_dir = (world_dir - up_norm * world_dir.dot(up_norm))
		if world_dir.length_squared() < FractureTypes.EPSILON:
			continue
		world_dir = world_dir.normalized()

		var point_on_surface: Vector3 = origin + world_dir * actual_radius
		var normal: Vector3 = -world_dir
		planes.append(Plane(normal, normal.dot(point_on_surface)))

	return planes
