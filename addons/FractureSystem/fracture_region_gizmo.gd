@tool
class_name FractureRegionGizmo
extends EditorNode3DGizmoPlugin


func _get_gizmo_name() -> String:
	return "FractureRegion"


func _has_gizmo(node: Node3D) -> bool:
	return node is FractureRegion


func _init() -> void:
	create_material("main", Color(0.2, 0.7, 1.0, 0.95), false, true)
	create_handle_material("handles")


func _redraw(gizmo: EditorNode3DGizmo) -> void:
	gizmo.clear()

	var region: FractureRegion = gizmo.get_node_3d() as FractureRegion
	if region == null:
		return

	var lines := PackedVector3Array()

	match region.shape:
		FractureRegion.RegionShape.BOX:
			_draw_box(lines, region.extents)
		FractureRegion.RegionShape.SPHERE:
			_draw_sphere(lines, region.sphere_radius)
		FractureRegion.RegionShape.CYLINDER:
			_draw_cylinder(lines, region.cylinder_radius, region.cylinder_height)

	gizmo.add_lines(lines, get_material("main", gizmo), false)

	var handles := PackedVector3Array()
	match region.shape:
		FractureRegion.RegionShape.BOX:
			handles.append(Vector3( region.extents.x, 0, 0))
			handles.append(Vector3(-region.extents.x, 0, 0))
			handles.append(Vector3(0,  region.extents.y, 0))
			handles.append(Vector3(0, -region.extents.y, 0))
			handles.append(Vector3(0, 0,  region.extents.z))
			handles.append(Vector3(0, 0, -region.extents.z))

		FractureRegion.RegionShape.SPHERE:
			handles.append(Vector3( region.sphere_radius, 0, 0))
			handles.append(Vector3(-region.sphere_radius, 0, 0))
			handles.append(Vector3(0,  region.sphere_radius, 0))
			handles.append(Vector3(0, -region.sphere_radius, 0))
			handles.append(Vector3(0, 0,  region.sphere_radius))
			handles.append(Vector3(0, 0, -region.sphere_radius))

		FractureRegion.RegionShape.CYLINDER:
			# Radius handles on X and Z axes
			handles.append(Vector3( region.cylinder_radius, 0, 0))
			handles.append(Vector3(-region.cylinder_radius, 0, 0))
			handles.append(Vector3(0, 0,  region.cylinder_radius))
			handles.append(Vector3(0, 0, -region.cylinder_radius))
			# Height handles on Y axis
			var half_h: float = region.cylinder_height * 0.5
			handles.append(Vector3(0,  half_h, 0))
			handles.append(Vector3(0, -half_h, 0))

	gizmo.add_handles(handles, get_material("handles", gizmo), PackedInt32Array())


func _get_handle_name(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> String:
	var region: FractureRegion = gizmo.get_node_3d() as FractureRegion
	if region == null:
		return ""
	match region.shape:
		FractureRegion.RegionShape.BOX:
			return ["+X", "-X", "+Y", "-Y", "+Z", "-Z"][handle_id]
		FractureRegion.RegionShape.SPHERE:
			return ["+X", "-X", "+Y", "-Y", "+Z", "-Z"][handle_id]
		FractureRegion.RegionShape.CYLINDER:
			return ["+R(X)", "-R(X)", "+R(Z)", "-R(Z)", "+H", "-H"][handle_id]
	return ""


func _get_handle_value(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool) -> Variant:
	var region: FractureRegion = gizmo.get_node_3d() as FractureRegion
	if region == null:
		return 0.0

	match region.shape:
		FractureRegion.RegionShape.BOX:
			match handle_id:
				0, 1: return region.extents.x
				2, 3: return region.extents.y
				4, 5: return region.extents.z
		FractureRegion.RegionShape.SPHERE:
			return region.sphere_radius
		FractureRegion.RegionShape.CYLINDER:
			match handle_id:
				0, 1, 2, 3: return region.cylinder_radius
				4, 5: return region.cylinder_height

	return 0.0


func _set_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, camera: Camera3D, screen_pos: Vector2) -> void:
	var region: FractureRegion = gizmo.get_node_3d() as FractureRegion
	if region == null:
		return

	var gt: Transform3D = region.global_transform
	var ray_origin: Vector3 = camera.project_ray_origin(screen_pos)
	var ray_dir: Vector3 = camera.project_ray_normal(screen_pos)

	match region.shape:
		FractureRegion.RegionShape.BOX:
			var axis: Vector3
			var axis_index: int
			match handle_id:
				0, 1:
					axis = gt.basis.x.normalized()
					axis_index = 0
				2, 3:
					axis = gt.basis.y.normalized()
					axis_index = 1
				4, 5:
					axis = gt.basis.z.normalized()
					axis_index = 2

			var value: float = _get_handle_distance(ray_origin, ray_dir, gt.origin, axis)
			value = maxf(value, 0.05)

			var new_ext: Vector3 = region.extents
			match axis_index:
				0: new_ext.x = value
				1: new_ext.y = value
				2: new_ext.z = value
			region.extents = new_ext

		FractureRegion.RegionShape.SPHERE:
			var axis: Vector3
			match handle_id:
				0, 1:
					axis = gt.basis.x.normalized()
				2, 3:
					axis = gt.basis.y.normalized()
				4, 5:
					axis = gt.basis.z.normalized()

			var value: float = _get_handle_distance(ray_origin, ray_dir, gt.origin, axis)
			value = maxf(value, 0.05)
			region.sphere_radius = value

		FractureRegion.RegionShape.CYLINDER:
			match handle_id:
				0, 1:
					# Radius via X axis
					var axis: Vector3 = gt.basis.x.normalized()
					var value: float = _get_handle_distance(ray_origin, ray_dir, gt.origin, axis)
					region.cylinder_radius = maxf(value, 0.05)
				2, 3:
					# Radius via Z axis
					var axis: Vector3 = gt.basis.z.normalized()
					var value: float = _get_handle_distance(ray_origin, ray_dir, gt.origin, axis)
					region.cylinder_radius = maxf(value, 0.05)
				4, 5:
					# Height via Y axis
					var axis: Vector3 = gt.basis.y.normalized()
					var value: float = _get_handle_distance(ray_origin, ray_dir, gt.origin, axis)
					region.cylinder_height = maxf(value * 2.0, 0.05)


func _commit_handle(gizmo: EditorNode3DGizmo, handle_id: int, secondary: bool, restore: Variant, cancel: bool) -> void:
	if cancel:
		var region: FractureRegion = gizmo.get_node_3d() as FractureRegion
		if region == null:
			return
		match region.shape:
			FractureRegion.RegionShape.BOX:
				var e := region.extents
				match handle_id:
					0, 1: e.x = restore
					2, 3: e.y = restore
					4, 5: e.z = restore
				region.extents = e
			FractureRegion.RegionShape.SPHERE:
				region.sphere_radius = restore
			FractureRegion.RegionShape.CYLINDER:
				match handle_id:
					0, 1, 2, 3:
						region.cylinder_radius = restore
					4, 5:
						region.cylinder_height = restore


func _get_handle_distance(ray_origin: Vector3, ray_dir: Vector3, origin: Vector3, axis: Vector3) -> float:
	var w: Vector3 = ray_origin - origin
	var a: float = axis.dot(axis)
	var b: float = axis.dot(ray_dir)
	var c: float = ray_dir.dot(ray_dir)
	var d: float = axis.dot(w)
	var e: float = ray_dir.dot(w)
	var denom: float = a * c - b * b

	if absf(denom) < 0.0001:
		return absf(d)

	var t: float = (b * e - c * d) / denom
	return absf(t)


func _draw_box(lines: PackedVector3Array, extents: Vector3) -> void:
	var e := extents
	var c := [
		Vector3(-e.x, -e.y, -e.z),
		Vector3( e.x, -e.y, -e.z),
		Vector3( e.x,  e.y, -e.z),
		Vector3(-e.x,  e.y, -e.z),
		Vector3(-e.x, -e.y,  e.z),
		Vector3( e.x, -e.y,  e.z),
		Vector3( e.x,  e.y,  e.z),
		Vector3(-e.x,  e.y,  e.z),
	]

	var edges := [
		[0,1],[1,2],[2,3],[3,0],
		[4,5],[5,6],[6,7],[7,4],
		[0,4],[1,5],[2,6],[3,7]
	]

	for e_idx in edges:
		lines.append(c[e_idx[0]])
		lines.append(c[e_idx[1]])


func _draw_sphere(lines: PackedVector3Array, radius: float) -> void:
	var segments := 40
	for axis in range(3):
		for i in range(segments):
			var a0: float = TAU * float(i) / float(segments)
			var a1: float = TAU * float(i + 1) / float(segments)
			var p0: Vector3
			var p1: Vector3
			match axis:
				0:
					p0 = Vector3(cos(a0) * radius, sin(a0) * radius, 0)
					p1 = Vector3(cos(a1) * radius, sin(a1) * radius, 0)
				1:
					p0 = Vector3(cos(a0) * radius, 0, sin(a0) * radius)
					p1 = Vector3(cos(a1) * radius, 0, sin(a1) * radius)
				2:
					p0 = Vector3(0, cos(a0) * radius, sin(a0) * radius)
					p1 = Vector3(0, cos(a1) * radius, sin(a1) * radius)
			lines.append(p0)
			lines.append(p1)


func _draw_cylinder(lines: PackedVector3Array, radius: float, height: float) -> void:
	var segments := 32
	var half_h: float = height * 0.5

	# Top circle
	for i in range(segments):
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		lines.append(Vector3(cos(a0) * radius, half_h, sin(a0) * radius))
		lines.append(Vector3(cos(a1) * radius, half_h, sin(a1) * radius))

	# Bottom circle
	for i in range(segments):
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		lines.append(Vector3(cos(a0) * radius, -half_h, sin(a0) * radius))
		lines.append(Vector3(cos(a1) * radius, -half_h, sin(a1) * radius))

	# Middle circle (at Y=0 for visual reference)
	for i in range(segments):
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		lines.append(Vector3(cos(a0) * radius, 0, sin(a0) * radius))
		lines.append(Vector3(cos(a1) * radius, 0, sin(a1) * radius))

	# Vertical lines connecting top and bottom
	var num_verticals := 8
	for i in range(num_verticals):
		var angle: float = TAU * float(i) / float(num_verticals)
		var x: float = cos(angle) * radius
		var z: float = sin(angle) * radius
		lines.append(Vector3(x, half_h, z))
		lines.append(Vector3(x, -half_h, z))
