@tool
class_name FractureRegion
extends Node3D

enum RegionShape { BOX, SPHERE, CYLINDER }

@export var shape: RegionShape = RegionShape.BOX:
	set(v):
		shape = v
		_rebuild_preview()

@export var extents: Vector3 = Vector3.ONE:
	set(v):
		extents = Vector3(maxf(v.x, 0.05), maxf(v.y, 0.05), maxf(v.z, 0.05))
		_rebuild_preview()

@export var sphere_radius: float = 1.0:
	set(v):
		sphere_radius = maxf(v, 0.05)
		_rebuild_preview()

@export var cylinder_radius: float = 1.0:
	set(v):
		cylinder_radius = maxf(v, 0.05)
		_rebuild_preview()

@export var cylinder_height: float = 2.0:
	set(v):
		cylinder_height = maxf(v, 0.05)
		_rebuild_preview()

@export var fragment_count: int = 8:
	set(v):
		fragment_count = maxi(v, 2)

@export var cap_material: Material = null

var _preview_mesh: MeshInstance3D = null

const SAMPLE_MIN_SPACING := 0.2


func _ready() -> void:
	_rebuild_preview()


func _rebuild_preview() -> void:
	if _preview_mesh != null and is_instance_valid(_preview_mesh):
		_preview_mesh.queue_free()
		_preview_mesh = null

	if not Engine.is_editor_hint():
		return

	_preview_mesh = MeshInstance3D.new()
	_preview_mesh.name = "_FracturePreview"
	add_child(_preview_mesh)

	var preview_mat := StandardMaterial3D.new()
	preview_mat.albedo_color = Color(0.2, 0.6, 1.0, 0.12)
	preview_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	preview_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	preview_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	preview_mat.no_depth_test = true

	match shape:
		RegionShape.BOX:
			var box := BoxMesh.new()
			box.size = extents * 2.0
			_preview_mesh.mesh = box
		RegionShape.SPHERE:
			var sphere := SphereMesh.new()
			sphere.radius = sphere_radius
			sphere.height = sphere_radius * 2.0
			_preview_mesh.mesh = sphere
		RegionShape.CYLINDER:
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = cylinder_radius
			cylinder.bottom_radius = cylinder_radius
			cylinder.height = cylinder_height
			_preview_mesh.mesh = cylinder

	_preview_mesh.material_override = preview_mat
	FractureDebug.region("Preview rebuilt: shape=%s extents=%s radius=%s cyl_r=%s cyl_h=%s" % [
		shape, extents, sphere_radius, cylinder_radius, cylinder_height
	])


func get_clipping_planes() -> Array:
	var xf: Transform3D = global_transform
	var origin: Vector3 = xf.origin

	match shape:
		RegionShape.BOX:
			return _get_box_planes(xf, origin)
		RegionShape.SPHERE:
			return _get_sphere_planes(xf, origin)
		RegionShape.CYLINDER:
			return _get_cylinder_planes(xf, origin)
	return []


func _get_box_planes(xf: Transform3D, origin: Vector3) -> Array:
	var planes: Array = []
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

	FractureDebug.region("Box planes generated: %d planes" % planes.size())
	return planes


func _get_sphere_planes(xf: Transform3D, origin: Vector3) -> Array:
	var planes: Array = []
	var num_planes := 42
	var golden_ratio: float = (1.0 + sqrt(5.0)) * 0.5
	var actual_radius: float = sphere_radius * xf.basis.x.length()

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

	FractureDebug.region("Sphere planes generated: %d planes" % planes.size())
	return planes


func _get_cylinder_planes(xf: Transform3D, origin: Vector3) -> Array:
	var planes: Array = []

	# Top and bottom cap planes
	var up: Vector3 = xf.basis.y
	var up_len: float = up.length()
	if up_len < FractureTypes.EPSILON:
		return planes
	var up_norm: Vector3 = up / up_len
	var half_height: float = (cylinder_height * 0.5) * up_len

	# Top plane (pointing down into cylinder)
	var top_point: Vector3 = origin + up_norm * half_height
	var n_top: Vector3 = -up_norm
	planes.append(Plane(n_top, n_top.dot(top_point)))

	# Bottom plane (pointing up into cylinder)
	var bottom_point: Vector3 = origin - up_norm * half_height
	var n_bottom: Vector3 = up_norm
	planes.append(Plane(n_bottom, n_bottom.dot(bottom_point)))

	# Radial planes approximating the cylinder wall
	var num_sides := 24
	var actual_radius: float = cylinder_radius * xf.basis.x.length()

	for i in range(num_sides):
		var angle: float = (TAU * float(i)) / float(num_sides)

		# Local radial direction in XZ plane
		var local_dir := Vector3(cos(angle), 0.0, sin(angle))

		# Transform to world space using basis (excludes Y component for radial)
		var world_dir: Vector3 = (xf.basis * local_dir)
		# Project out the Y component so radial planes are perpendicular to the axis
		world_dir = (world_dir - up_norm * world_dir.dot(up_norm))
		if world_dir.length_squared() < FractureTypes.EPSILON:
			continue
		world_dir = world_dir.normalized()

		# Point on cylinder surface
		var point_on_surface: Vector3 = origin + world_dir * actual_radius

		# Plane points inward
		var normal: Vector3 = -world_dir
		planes.append(Plane(normal, normal.dot(point_on_surface)))

	FractureDebug.region("Cylinder planes generated: %d planes" % planes.size())
	return planes


func scatter_seeds() -> Array:
	var seeds: Array = []
	var xf: Transform3D = global_transform

	match shape:
		RegionShape.BOX:
			for i in range(fragment_count):
				var local := Vector3(
					randf_range(-extents.x, extents.x),
					randf_range(-extents.y, extents.y),
					randf_range(-extents.z, extents.z)
				)
				var world_pt: Vector3 = xf * local
				seeds.append(world_pt)
				FractureDebug.voronoi("Seed[%d] box local=%s world=%s" % [i, local, world_pt])

		RegionShape.SPHERE:
			var actual_radius: float = sphere_radius * xf.basis.x.length()
			for i in range(fragment_count):
				while true:
					var local := Vector3(
						randf_range(-1.0, 1.0),
						randf_range(-1.0, 1.0),
						randf_range(-1.0, 1.0)
					)
					if local.length_squared() <= 1.0:
						var world_pt: Vector3 = xf.origin + local * actual_radius
						seeds.append(world_pt)
						FractureDebug.voronoi("Seed[%d] sphere local=%s world=%s" % [i, local, world_pt])
						break

		RegionShape.CYLINDER:
			var actual_radius: float = cylinder_radius * xf.basis.x.length()
			var half_height: float = cylinder_height * 0.5
			for i in range(fragment_count):
				# Uniform distribution inside cylinder
				var r: float = sqrt(randf()) * actual_radius
				var theta: float = randf() * TAU
				var h: float = randf_range(-half_height, half_height)

				var local := Vector3(
					r * cos(theta),
					h,
					r * sin(theta)
				)

				var world_pt: Vector3 = xf * local
				seeds.append(world_pt)
				FractureDebug.voronoi("Seed[%d] cylinder local=%s world=%s" % [i, local, world_pt])

	FractureDebug.voronoi("Total seeds scattered: %d" % seeds.size())
	return seeds


func get_center() -> Vector3:
	return global_transform.origin


func find_overlapping_meshes(root: Node = null) -> Array:
	if root == null:
		if Engine.is_editor_hint():
			root = EditorInterface.get_edited_scene_root()
			FractureDebug.region("Found root as %s in editor time" % root)
		else:
			root = get_tree().current_scene
	if root == null:
		FractureDebug.region("No scene root found while searching for overlapping meshes")
		return []

	var region_aabb: AABB = _get_world_aabb()
	var results: Array = []

	var all_meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	FractureDebug.region("Searching overlaps in %d MeshInstance3D nodes" % all_meshes.size())
	FractureDebug.region("Region AABB (grown): %s" % region_aabb)

	for node in all_meshes:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi == null:
			continue
		if mi.get_parent() == self:
			continue
		if mi.mesh == null:
			continue
		if not mi.visible:
			FractureDebug.region("Skipping mesh '%s' because it is hidden" % mi.name)
			continue
		if mi.is_in_group("fracture_exclude"):
			FractureDebug.region("Skipping mesh '%s' because it is in group 'fracture_exclude'" % mi.name)
			continue

		if mi.has_meta("exclude_from_fracture") and mi.get_meta("exclude_from_fracture"):
			FractureDebug.region("Skipping mesh '%s' because exclude_from_fracture meta is true" % mi.name)
			continue

		if mi.has_meta("fracture_consumed") and mi.get_meta("fracture_consumed"):
			FractureDebug.region("Skipping mesh '%s' because fracture_consumed meta is true" % mi.name)
			continue

		var mesh_aabb: AABB = _get_mesh_world_aabb(mi)
		var overlaps: bool = region_aabb.intersects(mesh_aabb) and _mesh_overlaps_region(mi)

		if overlaps:
			results.append(mi)
			FractureDebug.region("Mesh '%s' overlaps and will be fractured" % mi.name)

	FractureDebug.region("Overlapping meshes found: %d" % results.size())
	return results


func _get_world_aabb() -> AABB:
	var xf: Transform3D = global_transform
	match shape:
		RegionShape.BOX:
			var local_aabb := AABB(-extents, extents * 2.0)
			return _transform_aabb(xf, local_aabb)
		RegionShape.SPHERE:
			var r := sphere_radius
			var local_aabb := AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
			return _transform_aabb(xf, local_aabb)
		RegionShape.CYLINDER:
			var r := cylinder_radius
			var h := cylinder_height * 0.5
			var local_aabb := AABB(Vector3(-r, -h, -r), Vector3(r * 2.0, cylinder_height, r * 2.0))
			return _transform_aabb(xf, local_aabb)
	return AABB()


func _get_mesh_world_aabb(mi: MeshInstance3D) -> AABB:
	return _transform_aabb(mi.global_transform, mi.mesh.get_aabb())


func _transform_aabb(xf: Transform3D, aabb: AABB) -> AABB:
	var corners: Array = []
	for xi in [0, 1]:
		for yi in [0, 1]:
			for zi in [0, 1]:
				var corner := Vector3(
					aabb.position.x + aabb.size.x * float(xi),
					aabb.position.y + aabb.size.y * float(yi),
					aabb.position.z + aabb.size.z * float(zi)
				)
				corners.append(xf * corner)

	var min_pt: Vector3 = corners[0]
	var max_pt: Vector3 = corners[0]
	for c in corners:
		min_pt = Vector3(minf(min_pt.x, c.x), minf(min_pt.y, c.y), minf(min_pt.z, c.z))
		max_pt = Vector3(maxf(max_pt.x, c.x), maxf(max_pt.y, c.y), maxf(max_pt.z, c.z))

	return AABB(min_pt, max_pt - min_pt)


func contains_point(point: Vector3) -> bool:
	match shape:
		RegionShape.BOX:
			var planes: Array = get_clipping_planes()
			for plane in planes:
				if plane.normal.dot(point) - plane.d < 0.0:
					return false
			return true
		RegionShape.SPHERE:
			var actual_radius: float = sphere_radius * global_transform.basis.x.length()
			return point.distance_to(global_transform.origin) <= actual_radius
		RegionShape.CYLINDER:
			var local_point: Vector3 = global_transform.affine_inverse() * point
			var xz_dist: float = sqrt(local_point.x * local_point.x + local_point.z * local_point.z)
			var half_height: float = cylinder_height * 0.5
			return xz_dist <= cylinder_radius and absf(local_point.y) <= half_height
	return false


func _mesh_overlaps_region(mi: MeshInstance3D) -> bool:
	var cached_planes: Array = get_clipping_planes() if shape == RegionShape.BOX else []

	for si in range(mi.mesh.get_surface_count()):
		var arrays: Array = mi.mesh.surface_get_arrays(si)
		if arrays.is_empty():
			continue
		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if positions.is_empty():
			continue
		var indices: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]

		var tri_count := indices.size() / 3 if indices.size() > 0 else positions.size() / 3
		var step := maxi(1, tri_count / 500)

		for tri in range(0, tri_count, step):
			var idx0 := indices[tri * 3] if indices.size() > 0 else tri * 3
			var idx1 := indices[tri * 3 + 1] if indices.size() > 0 else tri * 3 + 1
			var idx2 := indices[tri * 3 + 2] if indices.size() > 0 else tri * 3 + 2

			var a: Vector3 = mi.global_transform * positions[idx0]
			var b: Vector3 = mi.global_transform * positions[idx1]
			var c: Vector3 = mi.global_transform * positions[idx2]

			var longest_edge := maxf(a.distance_to(b), maxf(b.distance_to(c), a.distance_to(c)))
			var steps := clamp(int(ceil(longest_edge / SAMPLE_MIN_SPACING)), 1, 20)

			for i in range(steps + 1):
				for j in range(steps + 1 - i):
					var k: int = steps - i - j
					var u := float(i) / float(steps)
					var v := float(j) / float(steps)
					var w := float(k) / float(steps)
					var point: Vector3 = a * u + b * v + c * w
					if contains_point_cached(point, cached_planes):
						return true

	return false


func contains_point_cached(point: Vector3, cached_planes: Array) -> bool:
	match shape:
		RegionShape.BOX:
			for plane in cached_planes:
				if plane.normal.dot(point) - plane.d < 0.0:
					return false
			return true
		RegionShape.SPHERE:
			var actual_radius: float = sphere_radius * global_transform.basis.x.length()
			return point.distance_to(global_transform.origin) <= actual_radius
		RegionShape.CYLINDER:
			var local_point: Vector3 = global_transform.affine_inverse() * point
			var xz_dist: float = sqrt(local_point.x * local_point.x + local_point.z * local_point.z)
			var half_height: float = cylinder_height * 0.5
			return xz_dist <= cylinder_radius and absf(local_point.y) <= half_height
	return false
