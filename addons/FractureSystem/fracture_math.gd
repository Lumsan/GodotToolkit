class_name FractureMath
extends RefCounted

static func points_equal(a: Vector3, b: Vector3, eps: float = 0.001) -> bool:
	return a.distance_to(b) <= eps

static func make_plane_basis(normal: Vector3) -> Dictionary:
	var u: Vector3
	if absf(normal.dot(Vector3.UP)) < 0.99:
		u = normal.cross(Vector3.UP).normalized()
	else:
		u = normal.cross(Vector3.RIGHT).normalized()
	var v: Vector3 = normal.cross(u).normalized()
	return {"u": u, "v": v}

# Project 3D points onto a plane's 2D basis
static func project_to_2d(points: PackedVector3Array, origin: Vector3, u: Vector3, v: Vector3) -> PackedVector2Array:
	var result := PackedVector2Array()
	for p in points:
		var rel: Vector3 = p - origin
		result.append(Vector2(rel.dot(u), rel.dot(v)))
	return result

# Unproject 2D point back to 3D
static func unproject_to_3d(point_2d: Vector2, origin: Vector3, u: Vector3, v: Vector3) -> Vector3:
	return origin + u * point_2d.x + v * point_2d.y

# Compute convex hull of 2D points using Graham scan
# Returns indices into the input array, in CCW order
static func convex_hull_2d(points: PackedVector2Array) -> PackedInt32Array:
	var n: int = points.size()
	if n < 3:
		var result := PackedInt32Array()
		for i in range(n):
			result.append(i)
		return result

	# Find lowest point (and leftmost if tie)
	var start := 0
	for i in range(1, n):
		if points[i].y < points[start].y or (absf(points[i].y - points[start].y) < 1e-8 and points[i].x < points[start].x):
			start = i

	# Sort by polar angle from start
	var indices: Array = []
	for i in range(n):
		if i != start:
			indices.append(i)

	var start_pt: Vector2 = points[start]
	indices.sort_custom(func(a, b):
		var da: Vector2 = points[a] - start_pt
		var db: Vector2 = points[b] - start_pt
		var cross_val: float = da.x * db.y - da.y * db.x
		if absf(cross_val) > 1e-8:
			return cross_val > 0.0
		return da.length_squared() < db.length_squared()
	)

	var hull := PackedInt32Array()
	hull.append(start)

	for idx in indices:
		while hull.size() > 1:
			var a: Vector2 = points[hull[hull.size() - 2]]
			var b: Vector2 = points[hull[hull.size() - 1]]
			var c: Vector2 = points[idx]
			var cross_val: float = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
			if cross_val > 1e-8:
				break
			hull.resize(hull.size() - 1)
		hull.append(idx)

	return hull

# Ear clipping triangulation for potentially concave 2D polygons
# Returns array of triangle index triples [i0, i1, i2, i0, i1, i2, ...]
static func ear_clip_2d(points: PackedVector2Array) -> PackedInt32Array:
	var n: int = points.size()
	if n < 3:
		return PackedInt32Array()

	if n == 3:
		return PackedInt32Array([0, 1, 2])

	# Ensure CCW winding
	var area := 0.0
	for i in range(n):
		var j: int = (i + 1) % n
		area += points[i].x * points[j].y
		area -= points[j].x * points[i].y
	var ccw: bool = area > 0.0

	# Build index list
	var idx_list: Array = []
	if ccw:
		for i in range(n):
			idx_list.append(i)
	else:
		for i in range(n - 1, -1, -1):
			idx_list.append(i)

	var triangles := PackedInt32Array()
	var safety := 0
	var max_iters: int = n * n

	while idx_list.size() > 2 and safety < max_iters:
		safety += 1
		var found_ear := false

		for i in range(idx_list.size()):
			var prev_i: int = (i - 1 + idx_list.size()) % idx_list.size()
			var next_i: int = (i + 1) % idx_list.size()

			var a: Vector2 = points[idx_list[prev_i]]
			var b: Vector2 = points[idx_list[i]]
			var c: Vector2 = points[idx_list[next_i]]

			# Check if this is a convex vertex (CCW turn)
			var cross_val: float = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
			if cross_val <= 1e-8:
				continue

			# Check no other vertex is inside this triangle
			var has_point_inside := false
			for k in range(idx_list.size()):
				if k == prev_i or k == i or k == next_i:
					continue
				var p: Vector2 = points[idx_list[k]]
				if _point_in_triangle_2d(p, a, b, c):
					has_point_inside = true
					break

			if has_point_inside:
				continue

			# This is an ear - clip it
			triangles.append(idx_list[prev_i])
			triangles.append(idx_list[i])
			triangles.append(idx_list[next_i])
			idx_list.remove_at(i)
			found_ear = true
			break

		if not found_ear:
			# Degenerate polygon, force-clip to avoid infinite loop
			if idx_list.size() >= 3:
				triangles.append(idx_list[0])
				triangles.append(idx_list[1])
				triangles.append(idx_list[2])
				idx_list.remove_at(1)
			else:
				break

	return triangles

static func _point_in_triangle_2d(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1: float = (p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y)
	var d2: float = (p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y)
	var d3: float = (p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y)

	var has_neg: bool = (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos: bool = (d1 > 0) or (d2 > 0) or (d3 > 0)

	return not (has_neg and has_pos)

# Deduplicate coplanar points
static func deduplicate_points(points: PackedVector3Array, eps: float = 0.001) -> PackedVector3Array:
	var result := PackedVector3Array()
	for p in points:
		var found := false
		for existing in result:
			if p.distance_to(existing) <= eps:
				found = true
				break
		if not found:
			result.append(p)
	return result

static func collect_coplanar_vertices(polys: Array, plane: Plane, eps: float = 0.01) -> PackedVector3Array:
	var result := PackedVector3Array()
	var total_checked := 0
	for poly_obj in polys:
		var poly: FractureTypes.FracPoly = poly_obj
		for vtx_obj in poly.verts:
			var vtx: FractureTypes.VtxData = vtx_obj
			total_checked += 1
			var dist: float = absf(plane.normal.dot(vtx.pos) - plane.d)
			if dist <= eps:
				result.append(vtx.pos)
	var deduped: PackedVector3Array = deduplicate_points(result)
	print("collect_coplanar_vertices: checked=%d on_plane=%d deduped=%d plane_n=%s plane_d=%f debugsearch_ccv" % [
		total_checked, result.size(), deduped.size(), plane.normal, plane.d
	])
	return deduped

static func build_convex_cap(
	coplanar_points: PackedVector3Array,
	plane_normal: Vector3,
	cap_mat_idx: int
) -> FractureTypes.FracPoly:
	print("build_convex_cap: points=%d normal=%s debugsearch_bcc_entry" % [coplanar_points.size(), plane_normal])

	if coplanar_points.size() < 3:
		print("build_convex_cap: too few points, returning null debugsearch_bcc_few")
		return null

	var centroid := Vector3.ZERO
	for p in coplanar_points:
		centroid += p
	centroid /= float(coplanar_points.size())

	var basis := make_plane_basis(plane_normal)
	var u: Vector3 = basis["u"]
	var v: Vector3 = basis["v"]

	var pts_2d: PackedVector2Array = project_to_2d(coplanar_points, centroid, u, v)
	var hull_indices: PackedInt32Array = convex_hull_2d(pts_2d)

	print("build_convex_cap: hull_indices=%d from %d 2d points debugsearch_bcc_hull" % [hull_indices.size(), pts_2d.size()])

	if hull_indices.size() < 3:
		print("build_convex_cap: hull too small, returning null debugsearch_bcc_hull_small")
		return null

	var verts: Array = []
	for idx in hull_indices:
		var vtx := FractureTypes.VtxData.new(
			coplanar_points[idx],
			plane_normal,
			pts_2d[idx]
		)
		verts.append(vtx)

	var face_n := Vector3.ZERO
	for fi in range(1, verts.size() - 1):
		var cross: Vector3 = (verts[fi].pos - verts[0].pos).cross(verts[fi + 1].pos - verts[0].pos)
		if cross.length_squared() > 1e-10:
			face_n = cross.normalized()
			break

	var dot_val: float = face_n.dot(plane_normal)
	var did_reverse := false
	if face_n.length_squared() > 0.5 and dot_val < 0.0:
		verts.reverse()
		did_reverse = true

	print("build_convex_cap: face_n=%s desired=%s dot=%f reversed=%s debugsearch_bcc_winding" % [face_n, plane_normal, dot_val, did_reverse])

	var poly := FractureTypes.FracPoly.new(verts, cap_mat_idx, true, plane_normal, centroid)
	var area: float = poly.compute_area()
	print("build_convex_cap: area=%f debugsearch_bcc_area" % area)

	if area < FractureTypes.EPSILON:
		print("build_convex_cap: area too small, returning null debugsearch_bcc_area_small")
		return null
	return poly


static func build_concave_cap(
	coplanar_points: PackedVector3Array,
	plane_normal: Vector3,
	cap_mat_idx: int
) -> Array:
	if coplanar_points.size() < 3:
		return []

	var centroid := Vector3.ZERO
	for p in coplanar_points:
		centroid += p
	centroid /= float(coplanar_points.size())

	var basis := make_plane_basis(plane_normal)
	var u: Vector3 = basis["u"]
	var v: Vector3 = basis["v"]

	var pts_2d: PackedVector2Array = project_to_2d(coplanar_points, centroid, u, v)

	# Get boundary ordering via convex hull first, then use all points
	# For concave shapes we need angular sort for the boundary
	var angle_data: Array = []
	for i in range(pts_2d.size()):
		var angle: float = atan2(pts_2d[i].y, pts_2d[i].x)
		angle_data.append({"idx": i, "angle": angle})
	angle_data.sort_custom(func(a, b): return a["angle"] < b["angle"])

	var sorted_2d := PackedVector2Array()
	var idx_map := PackedInt32Array()
	for d in angle_data:
		sorted_2d.append(pts_2d[d["idx"]])
		idx_map.append(d["idx"])

	var tri_indices: PackedInt32Array = ear_clip_2d(sorted_2d)

	if tri_indices.is_empty():
		return []

	var polys: Array = []
	for ti in range(tri_indices.size() / 3):
		var i0: int = idx_map[tri_indices[ti * 3]]
		var i1: int = idx_map[tri_indices[ti * 3 + 1]]
		var i2: int = idx_map[tri_indices[ti * 3 + 2]]

		var v0 := FractureTypes.VtxData.new(coplanar_points[i0], plane_normal, pts_2d[i0])
		var v1 := FractureTypes.VtxData.new(coplanar_points[i1], plane_normal, pts_2d[i1])
		var v2 := FractureTypes.VtxData.new(coplanar_points[i2], plane_normal, pts_2d[i2])

		# Check winding against desired normal and flip if needed
		var face_n: Vector3 = (v1.pos - v0.pos).cross(v2.pos - v0.pos)
		if face_n.length_squared() > 1e-10:
			face_n = face_n.normalized()
			if face_n.dot(plane_normal) < 0.0:
				var tmp := v1
				v1 = v2
				v2 = tmp

		var tri_poly := FractureTypes.FracPoly.new([v0, v1, v2], cap_mat_idx, true, plane_normal, centroid)
		if tri_poly.compute_area() > FractureTypes.EPSILON:
			polys.append(tri_poly)

	return polys

static func polygon_lies_on_plane(poly: FractureTypes.FracPoly, plane: Plane, eps: float = 0.01) -> bool:
	if poly == null or poly.verts.size() < 3:
		return false

	for vtx_obj in poly.verts:
		var vtx: FractureTypes.VtxData = vtx_obj
		var dist: float = absf(plane.normal.dot(vtx.pos) - plane.d)
		if dist > eps:
			return false

	return true
