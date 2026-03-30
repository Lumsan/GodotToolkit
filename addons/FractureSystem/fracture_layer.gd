class_name FractureLayer
extends RefCounted

static func extract_polygons(mesh_inst: MeshInstance3D) -> Dictionary:
	var mesh: Mesh = mesh_inst.mesh
	if mesh == null:
		FractureDebug.extract("MeshInstance '%s' has no mesh" % mesh_inst.name)
		return {"polys": [], "materials": []}

	var xform: Transform3D = mesh_inst.global_transform
	var normal_basis: Basis = xform.basis.inverse().transposed()

	var polys: Array = []
	var mats: Array = []

	FractureDebug.extract("Extracting mesh '%s' with %d surfaces" % [mesh_inst.name, mesh.get_surface_count()])

	for surf_idx in range(mesh.get_surface_count()):
		var mat: Material = mesh_inst.get_active_material(surf_idx)
		mats.append(mat)

		var arrays: Array = mesh.surface_get_arrays(surf_idx)
		if arrays.is_empty():
			continue

		var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if positions.is_empty():
			continue

		var normals := PackedVector3Array()
		if arrays[Mesh.ARRAY_NORMAL] != null:
			normals = arrays[Mesh.ARRAY_NORMAL]

		var uvs := PackedVector2Array()
		if arrays[Mesh.ARRAY_TEX_UV] != null:
			uvs = arrays[Mesh.ARRAY_TEX_UV]

		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]

		var tri_count := 0
		if indices.size() > 0:
			tri_count = indices.size() / 3
		else:
			tri_count = positions.size() / 3

		for tri in range(tri_count):
			var tri_verts: Array = []
			for vi in range(3):
				var idx: int
				if indices.size() > 0:
					idx = indices[tri * 3 + vi]
				else:
					idx = tri * 3 + vi

				var p: Vector3 = xform * positions[idx]
				var n: Vector3 = Vector3.UP
				if normals.size() > idx:
					n = (normal_basis * normals[idx]).normalized()

				var u: Vector2 = Vector2.ZERO
				if uvs.size() > idx:
					u = uvs[idx]

				tri_verts.append(FractureTypes.VtxData.new(p, n, u))

			polys.append(FractureTypes.FracPoly.new(tri_verts, surf_idx, false))

	FractureDebug.extract("Total extracted polygons from '%s': %d" % [mesh_inst.name, polys.size()])
	return {"polys": polys, "materials": mats}


static func split_polygon(poly: FractureTypes.FracPoly, plane: Plane) -> FractureTypes.SplitResult:
	var result := FractureTypes.SplitResult.new()

	var vc: int = poly.verts.size()
	if vc < 3:
		return result

	var dists: Array = []
	var inside_flags: Array = []
	var has_in := false
	var has_out := false

	for vtx_obj in poly.verts:
		var vtx: FractureTypes.VtxData = vtx_obj
		var d: float = plane.normal.dot(vtx.pos) - plane.d
		dists.append(d)

		var inside: bool = d >= -FractureTypes.EPSILON
		inside_flags.append(inside)

		if inside:
			has_in = true
		else:
			has_out = true

	if has_in and not has_out:
		result.inside = poly.duplicate_poly()
		return result

	if has_out and not has_in:
		result.outside = poly.duplicate_poly()
		return result

	var in_verts: Array = []
	var out_verts: Array = []
	var cut_pts: Array = []

	for i in range(vc):
		var cur: FractureTypes.VtxData = poly.verts[i]
		var nxt: FractureTypes.VtxData = poly.verts[(i + 1) % vc]
		var cur_in: bool = inside_flags[i]
		var nxt_in: bool = inside_flags[(i + 1) % vc]
		var d0: float = dists[i]
		var d1: float = dists[(i + 1) % vc]

		if cur_in:
			in_verts.append(cur.duplicate_vtx())
		else:
			out_verts.append(cur.duplicate_vtx())

		if cur_in != nxt_in:
			var t: float = d0 / (d0 - d1)
			t = clampf(t, 0.0, 1.0)
			var inter: FractureTypes.VtxData = cur.lerp_to(nxt, t)
			in_verts.append(inter.duplicate_vtx())
			out_verts.append(inter.duplicate_vtx())
			cut_pts.append(inter.duplicate_vtx())

	if in_verts.size() >= 3:
		result.inside = FractureTypes.FracPoly.new(in_verts, poly.mat_idx, poly.is_cap, poly.cap_normal)
	if out_verts.size() >= 3:
		result.outside = FractureTypes.FracPoly.new(out_verts, poly.mat_idx, poly.is_cap, poly.cap_normal)
	if cut_pts.size() == 2:
		result.cut_edge = [cut_pts[0], cut_pts[1]]

	return result


static func clip_to_region(polys: Array, planes: Array) -> Dictionary:
	FractureDebug.clip("Starting region clip: polys=%d planes=%d" % [polys.size(), planes.size()])

	var current_inside: Array = []
	for p in polys:
		current_inside.append(p.duplicate_poly())

	var all_outside: Array = []

	for pi in range(planes.size()):
		var plane: Plane = planes[pi]
		var next_inside: Array = []
		var cut_points := PackedVector3Array()

		for poly_obj in current_inside:
			var poly: FractureTypes.FracPoly = poly_obj
			var sr: FractureTypes.SplitResult = split_polygon(poly, plane)

			if sr.inside != null:
				next_inside.append(sr.inside)

			if sr.outside != null:
				all_outside.append(sr.outside)

			if sr.cut_edge.size() == 2:
				var a: FractureTypes.VtxData = sr.cut_edge[0]
				var b: FractureTypes.VtxData = sr.cut_edge[1]
				cut_points.append(a.pos)
				cut_points.append(b.pos)

		cut_points = FractureMath.deduplicate_points(cut_points)

		print("clip_to_region plane %d: cut_points=%d debugsearch_clip_cutpts" % [
			pi, cut_points.size()
		])

		# Build inside cap for the fracture region.
		# Region planes point inward into the region, so the inside cap should face inward too.
		if cut_points.size() >= 3:
			var inside_cap: FractureTypes.FracPoly = FractureMath.build_convex_cap(
				cut_points,
				plane.normal,
				FractureTypes.CAP_MAT_IDX
			)

			print("clip_to_region plane %d: inside_cap=%s normal=%s debugsearch_clip_incap" % [
				pi, inside_cap != null, plane.normal
			])

			if inside_cap != null:
				next_inside.append(inside_cap)

		current_inside = next_inside

		FractureDebug.clip("Region plane %d -> kept=%d outside_accum=%d" % [
			pi, current_inside.size(), all_outside.size()
		])

	FractureDebug.clip("Region clip complete: inside=%d outside=%d" % [
		current_inside.size(), all_outside.size()
	])

	return {
		"inside": current_inside,
		"outside": all_outside
	}


static func generate_convex_caps_for_plane(polys: Array, plane: Plane, cap_normal: Vector3, cap_mat_idx: int) -> FractureTypes.FracPoly:
	var coplanar_pts: PackedVector3Array = FractureMath.collect_coplanar_vertices(polys, plane)
	if coplanar_pts.size() < 3:
		return null
	
	var cap: FractureTypes.FracPoly = FractureMath.build_convex_cap(coplanar_pts, cap_normal, cap_mat_idx)
	
	if cap != null:
		var area: float = cap.compute_area()
		if area < 0.01:
			print("WARNING: Cap has very small area=%f, may be degenerate" % area)
			return null  # Skip degenerate caps
	
	return cap

# UNUSED
static func generate_concave_caps_for_plane(polys: Array, plane: Plane, cap_normal: Vector3, cap_mat_idx: int) -> Array:
	var coplanar_pts: PackedVector3Array = FractureMath.collect_coplanar_vertices(polys, plane)
	if coplanar_pts.size() < 3:
		return []
	return FractureMath.build_concave_cap(coplanar_pts, cap_normal, cap_mat_idx)

static func voronoi_fracture(
	inside_polys: Array,
	seeds: Array,
	cap_mat_idx: int = FractureTypes.CAP_MAT_IDX,
	region_planes: Array = []
) -> Array:
	FractureDebug.voronoi("Starting Voronoi fracture: inside_polys=%d seeds=%d region_planes=%d" % [
		inside_polys.size(),
		seeds.size(),
		region_planes.size()
	])

	var fragments: Array = []

	for i in range(seeds.size()):
		var cell_polys: Array = []
		for p in inside_polys:
			cell_polys.append(p.duplicate_poly())

		var total_cap_polys := 0

		# Voronoi bisector cuts
		for j in range(seeds.size()):
			if i == j:
				continue

			var midpoint: Vector3 = (seeds[i] + seeds[j]) * 0.5
			var normal: Vector3 = (seeds[i] - seeds[j]).normalized()
			var d: float = normal.dot(midpoint)
			var bisector := Plane(normal, d)

			var next_polys: Array = []
			var cut_points := PackedVector3Array()

			for poly_obj in cell_polys:
				var poly: FractureTypes.FracPoly = poly_obj
				var sr: FractureTypes.SplitResult = split_polygon(poly, bisector)

				if sr.inside != null:
					next_polys.append(sr.inside)

				if sr.cut_edge.size() == 2:
					var a: FractureTypes.VtxData = sr.cut_edge[0]
					var b: FractureTypes.VtxData = sr.cut_edge[1]
					cut_points.append(a.pos)
					cut_points.append(b.pos)

			cut_points = FractureMath.deduplicate_points(cut_points)

			print("voronoi cell %d bisector %d: cut_points=%d debugsearch_vor_cutpts" % [
				i, j, cut_points.size()
			])

			if cut_points.size() >= 3:
				# The cut face for the cell should face along the bisector normal
				var cap: FractureTypes.FracPoly = FractureMath.build_convex_cap(
					cut_points,
					bisector.normal,
					cap_mat_idx
				)

				print("voronoi cell %d bisector %d: cap=%s normal=%s debugsearch_vor_capgen" % [
					i, j, cap != null, bisector.normal
				])

				if cap != null:
					next_polys.append(cap)
					total_cap_polys += 1

			cell_polys = next_polys
			if cell_polys.is_empty():
				break

		if cell_polys.is_empty():
			print("voronoi cell %d: empty after bisector clipping debugsearch_vor_empty" % i)
			continue

		# Region boundary caps for this fragment:
		# these can still be recovered from final geometry because they come from the region clip
		var geometry_polys: Array = []
		for poly_obj in cell_polys:
			geometry_polys.append(poly_obj.duplicate_poly())

		fragments.append({
			"polys": cell_polys,
			"seed": seeds[i]
		})

		FractureDebug.voronoi("Cell %d summary: final_polys=%d cap_polys=%d" % [
			i,
			cell_polys.size(),
			total_cap_polys
		])

	FractureDebug.voronoi("Voronoi fracture complete: fragments=%d" % fragments.size())
	return fragments


static func build_mesh_from_polys(polys: Array, materials: Array, cap_material: Material = null) -> MeshInstance3D:
	FractureDebug.build("Building mesh from polys: %d polys" % polys.size())

	if polys.is_empty():
		return null

	var groups: Dictionary = {}
	for poly_obj in polys:
		var poly: FractureTypes.FracPoly = poly_obj
		if poly.verts.size() < 3:
			continue
		if poly.compute_area() < FractureTypes.EPSILON:
			continue
		if not groups.has(poly.mat_idx):
			groups[poly.mat_idx] = []
		groups[poly.mat_idx].append(poly)

	if groups.is_empty():
		FractureDebug.build("No valid groups to build")
		return null

	var arr_mesh := ArrayMesh.new()

	for mat_idx in groups.keys():
		var group_polys: Array = groups[mat_idx]
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var tangents := PackedFloat32Array()

		for poly_obj in group_polys:
			var poly: FractureTypes.FracPoly = poly_obj
			if poly.verts.size() < 3:
				continue

			var v0: FractureTypes.VtxData = poly.verts[0]
			for k in range(1, poly.verts.size() - 1):
				var v1: FractureTypes.VtxData = poly.verts[k]
				var v2: FractureTypes.VtxData = poly.verts[k + 1]

				var face_n: Vector3 = (v1.pos - v0.pos).cross(v2.pos - v0.pos)
				if face_n.length_squared() <= 0.000001:
					continue
				face_n = face_n.normalized()

				if poly.is_cap:
					var cap_n: Vector3 = poly.cap_normal.normalized()
					if cap_n.length_squared() < 0.000001:
						cap_n = face_n

					vertices.append(v0.pos)
					vertices.append(v1.pos)
					vertices.append(v2.pos)

					normals.append(-cap_n)
					normals.append(-cap_n)
					normals.append(-cap_n)

					uvs.append(v0.uv)
					uvs.append(v1.uv)
					uvs.append(v2.uv)
				else:
					vertices.append(v0.pos)
					vertices.append(v1.pos)
					vertices.append(v2.pos)

					normals.append(v0.nml)
					normals.append(v1.nml)
					normals.append(v2.nml)

					uvs.append(v0.uv)
					uvs.append(v1.uv)
					uvs.append(v2.uv)

		if vertices.is_empty():
			continue

		# Generate tangents
		if uvs.size() == vertices.size() and normals.size() == vertices.size():
			var tan_accum := PackedVector3Array()
			var bitan_accum := PackedVector3Array()
			tan_accum.resize(vertices.size())
			bitan_accum.resize(vertices.size())
			for i in range(vertices.size()):
				tan_accum[i] = Vector3.ZERO
				bitan_accum[i] = Vector3.ZERO

			var tri_count := vertices.size() / 3
			for ti in range(tri_count):
				var i0 := ti * 3
				var i1 := ti * 3 + 1
				var i2 := ti * 3 + 2

				var p0: Vector3 = vertices[i0]
				var p1: Vector3 = vertices[i1]
				var p2: Vector3 = vertices[i2]

				var w0: Vector2 = uvs[i0]
				var w1: Vector2 = uvs[i1]
				var w2: Vector2 = uvs[i2]

				var e1: Vector3 = p1 - p0
				var e2: Vector3 = p2 - p0
				var d1: Vector2 = w1 - w0
				var d2: Vector2 = w2 - w0

				var denom: float = d1.x * d2.y - d1.y * d2.x
				if absf(denom) < 1e-8:
					continue

				var r: float = 1.0 / denom
				var t: Vector3 = (e1 * d2.y - e2 * d1.y) * r
				var b: Vector3 = (e2 * d1.x - e1 * d2.x) * r

				tan_accum[i0] += t
				tan_accum[i1] += t
				tan_accum[i2] += t
				bitan_accum[i0] += b
				bitan_accum[i1] += b
				bitan_accum[i2] += b

			tangents.resize(vertices.size() * 4)
			for i in range(vertices.size()):
				var n: Vector3 = normals[i].normalized()
				var t: Vector3 = tan_accum[i]
				var b: Vector3 = bitan_accum[i]

				t = (t - n * n.dot(t))
				if t.length_squared() < 1e-10:
					t = n.cross(Vector3.UP) if absf(n.dot(Vector3.UP)) < 0.99 else n.cross(Vector3.RIGHT)
				t = t.normalized()

				var w_sign: float = 1.0
				if (n.cross(t)).dot(b) < 0.0:
					w_sign = -1.0

				tangents[i * 4 + 0] = t.x
				tangents[i * 4 + 1] = t.y
				tangents[i * 4 + 2] = t.z
				tangents[i * 4 + 3] = w_sign

		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		if tangents.size() == vertices.size() * 4:
			arrays[Mesh.ARRAY_TANGENT] = tangents

		var surf_idx: int = arr_mesh.get_surface_count()
		arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

		var mat_to_use: Material = null

		if mat_idx == FractureTypes.CAP_MAT_IDX:
			if cap_material != null:
				mat_to_use = cap_material.duplicate()
			else:
				for src_mat in materials:
					if src_mat != null:
						mat_to_use = src_mat.duplicate()
						break

		elif mat_idx >= 0 and mat_idx < materials.size():
			if materials[mat_idx] != null:
				mat_to_use = materials[mat_idx].duplicate()

		# Shared neutral fallback for both original and cap surfaces
		if mat_to_use == null:
			var fallback := StandardMaterial3D.new()
			fallback.albedo_color = Color(0.9, 0.9, 0.9)
			fallback.roughness = 0.9
			fallback.metallic = 0.0
			fallback.cull_mode = BaseMaterial3D.CULL_BACK
			fallback.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat_to_use = fallback

			arr_mesh.surface_set_material(surf_idx, mat_to_use)

		elif mat_idx >= 0 and mat_idx < materials.size():
			if materials[mat_idx] != null:
				mat_to_use = materials[mat_idx].duplicate()

		if mat_to_use != null:
			arr_mesh.surface_set_material(surf_idx, mat_to_use)

		FractureDebug.build("Surface built: surf_idx=%d mat_idx=%s verts=%d" % [
			surf_idx,
			mat_idx,
			vertices.size()
		])

	if arr_mesh.get_surface_count() == 0:
		FractureDebug.build("ArrayMesh ended with zero surfaces")
		return null

	var inst := MeshInstance3D.new()
	inst.mesh = arr_mesh
	FractureDebug.build("Mesh built successfully with %d surfaces" % arr_mesh.get_surface_count())
	return inst


static func build_centered_fragment(polys: Array, materials: Array, cap_material: Material = null) -> Dictionary:
	if polys.is_empty():
		return {}

	var total_pos := Vector3.ZERO
	var count := 0

	for poly_obj in polys:
		var poly: FractureTypes.FracPoly = poly_obj
		for vtx_obj in poly.verts:
			var vtx: FractureTypes.VtxData = vtx_obj
			total_pos += vtx.pos
			count += 1

	if count == 0:
		return {}

	var centroid: Vector3 = total_pos / float(count)
	FractureDebug.build("Fragment centroid computed: %s from %d vertices" % [centroid, count])

	var offset_polys: Array = []
	for poly_obj in polys:
		var poly: FractureTypes.FracPoly = poly_obj
		var new_poly: FractureTypes.FracPoly = poly.duplicate_poly()
		for vtx_obj in new_poly.verts:
			var vtx: FractureTypes.VtxData = vtx_obj
			vtx.pos -= centroid
		offset_polys.append(new_poly)

	var inst: MeshInstance3D = build_mesh_from_polys(offset_polys, materials, cap_material)
	if inst == null:
		return {}

	return {"mesh_instance": inst, "centroid": centroid}


static func fracture_mesh(
	mesh_inst: MeshInstance3D,
	region_planes: Array,
	seeds: Array,
	cap_material: Material = null
) -> FractureTypes.FractureResult:
	FractureDebug.print_log("FRACTURE", "==== Fracturing mesh '%s' ====" % mesh_inst.name)

	var result := FractureTypes.FractureResult.new()
	result.fragments = []
	result.remainder = null
	result.materials = []

	var extracted: Dictionary = extract_polygons(mesh_inst)
	var polys: Array = extracted["polys"]
	var mats: Array = extracted["materials"]
	result.materials = mats

	if polys.is_empty():
		FractureDebug.print_log("FRACTURE", "No polygons extracted; aborting")
		return result

	var clip_result: Dictionary = clip_to_region(polys, region_planes)
	var inside_polys: Array = clip_result["inside"]
	var outside_polys: Array = clip_result["outside"]

	FractureDebug.print_log("FRACTURE", "Post-region clip -> inside=%d outside=%d" % [
		inside_polys.size(), outside_polys.size()
	])

	# Build remainder mesh with concave caps (can handle L-shapes etc)
	var remainder_polys: Array = []
	remainder_polys.append_array(outside_polys)

	for pi in range(region_planes.size()):
		var plane: Plane = region_planes[pi]
		var cap: FractureTypes.FracPoly = generate_convex_caps_for_plane(
			outside_polys,
			plane,
			-plane.normal,
			FractureTypes.CAP_MAT_IDX
		)

		var cap_count := 0
		if cap != null:
			remainder_polys.append(cap)
			cap_count = 1

		FractureDebug.caps("Remainder plane %d generated %d cap polys debugsearch_remcap_convex" % [pi, cap_count])

	result.remainder = build_mesh_from_polys(remainder_polys, mats, cap_material)

	if result.remainder != null:
		FractureDebug.build("Remainder mesh built")
	else:
		FractureDebug.build("No remainder mesh built")

	if inside_polys.is_empty() or seeds.is_empty():
		FractureDebug.print_log("FRACTURE", "No inside polys or no seeds -> no fragments")
		return result

	# Do NOT add inside_caps to inside_polys before Voronoi.
	# Region boundary caps for each fragment are generated inside voronoi_fracture.
	var cells: Array = voronoi_fracture(inside_polys, seeds, FractureTypes.CAP_MAT_IDX, region_planes)

	for ci in range(cells.size()):
		var cell: Dictionary = cells[ci]
		var cell_polys: Array = cell["polys"]
		var frag_data: Dictionary = build_centered_fragment(cell_polys, mats, cap_material)
		if frag_data.is_empty():
			FractureDebug.build("Cell %d failed to build fragment mesh" % ci)
			continue

		var frag_inst: MeshInstance3D = frag_data["mesh_instance"]
		frag_inst.position = frag_data["centroid"]
		frag_inst.name = "Fragment_%d" % ci
		frag_inst.set_meta("fragment_centroid", frag_data["centroid"])
		result.fragments.append(frag_inst)

		FractureDebug.build("Fragment %d built at %s" % [ci, frag_inst.position])

	FractureDebug.print_log("FRACTURE", "==== Mesh '%s' fracture complete: fragments=%d remainder=%s ====" % [
		mesh_inst.name,
		result.fragments.size(),
		result.remainder != null
	])

	return result

static func extract_plane_cap_polys(
	polys: Array,
	plane: Plane,
	cap_normal: Vector3,
	cap_mat_idx: int
) -> Array:
	var out: Array = []

	var basis := FractureMath.make_plane_basis(cap_normal)
	var u: Vector3 = basis["u"]
	var v: Vector3 = basis["v"]

	for poly_obj in polys:
		var poly: FractureTypes.FracPoly = poly_obj
		if poly == null or poly.verts.size() < 3:
			continue

		if not FractureMath.polygon_lies_on_plane(poly, plane):
			continue

		var centroid := Vector3.ZERO
		for vtx_obj in poly.verts:
			var src_vtx: FractureTypes.VtxData = vtx_obj
			centroid += src_vtx.pos
		centroid /= float(poly.verts.size())

		var new_verts: Array = []
		for vtx_obj in poly.verts:
			var src_vtx: FractureTypes.VtxData = vtx_obj
			var nv: FractureTypes.VtxData = src_vtx.duplicate_vtx()
			nv.nml = cap_normal
			var rel: Vector3 = nv.pos - centroid
			nv.uv = Vector2(rel.dot(u), rel.dot(v))
			new_verts.append(nv)

		# Fix winding to match cap_normal
		var face_n := Vector3.ZERO
		for i in range(1, new_verts.size() - 1):
			var a: Vector3 = new_verts[0].pos
			var b: Vector3 = new_verts[i].pos
			var c: Vector3 = new_verts[i + 1].pos
			var cross: Vector3 = (b - a).cross(c - a)
			if cross.length_squared() > 1e-10:
				face_n = cross.normalized()
				break

		if face_n.length_squared() > 0.0 and face_n.dot(cap_normal) < 0.0:
			new_verts.reverse()

		var cap_poly := FractureTypes.FracPoly.new(new_verts, cap_mat_idx, true, cap_normal, centroid)
		var area: float = cap_poly.compute_area()

		print("extract_plane_cap_polys: plane=%s verts=%d area=%f debugsearch_epcp" % [
			plane.normal,
			new_verts.size(),
			area
		])

		if area > FractureTypes.EPSILON:
			out.append(cap_poly)

	return out
