class_name FractureTypes
extends RefCounted

# This file holds the small data containers used throughout the fracture pipeline.
# Keeping them here makes the actual fracture code easier to read.

class VtxData:
	var pos: Vector3
	var nml: Vector3
	var uv: Vector2

	func _init(p := Vector3.ZERO, n := Vector3.UP, u := Vector2.ZERO) -> void:
		pos = p
		nml = n
		uv = u

	func duplicate_vtx() -> VtxData:
		return VtxData.new(pos, nml, uv)

	func lerp_to(other: VtxData, t: float) -> VtxData:
		return VtxData.new(
			pos.lerp(other.pos, t),
			nml.lerp(other.nml, t).normalized(),
			uv.lerp(other.uv, t)
		)

class FracPoly:
	# A convex polygon used internally during clipping.
	# It starts as a triangle but can become a quad/pentagon/etc. after clipping.
	var verts: Array
	var mat_idx: int
	var is_cap: bool
	var cap_normal: Vector3
	var cap_centroid : Vector3

	func _init(v: Array = [], m: int = 0, cap: bool = false, cap_n: Vector3 = Vector3.ZERO, cap_c : Vector3 = Vector3.ZERO) -> void:
		verts = v
		mat_idx = m
		is_cap = cap
		cap_normal = cap_n
		cap_centroid = cap_c

	func duplicate_poly() -> FracPoly:
		var out: Array = []
		for vtx_obj in verts:
			var vtx: VtxData = vtx_obj
			out.append(vtx.duplicate_vtx())
		return FracPoly.new(out, mat_idx, is_cap, cap_normal, cap_centroid)

	func compute_area() -> float:
		if verts.size() < 3:
			return 0.0
		var area := 0.0
		var v0: VtxData = verts[0]
		for i in range(1, verts.size() - 1):
			var v1: VtxData = verts[i]
			var v2: VtxData = verts[i + 1]
			area += (v1.pos - v0.pos).cross(v2.pos - v0.pos).length() * 0.5
		return area

class SplitResult:
	var inside: FracPoly = null
	var outside: FracPoly = null
	var cut_edge: Array = []   # [VtxData, VtxData] when a cut occurs

class FractureResult:
	var fragments: Array = []  # MeshInstance3D
	var remainder: MeshInstance3D = null
	var materials: Array = []

const EPSILON := 1e-4
const CAP_MAT_IDX := 9999
