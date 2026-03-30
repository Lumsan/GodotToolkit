class_name PhysicsLayer
extends RefCounted

enum ForceType { EXPLOSION, CRUMBLE, DIRECTIONAL }
enum SettleMode { PERSIST, FADE }

# -------------------------------------------------------------------
# This layer owns everything physics-related.
# The fracture layer gives us fragment MeshInstance3D nodes.
# We convert each one into:
#
#   RigidBody3D
#   ├── MeshInstance3D
#   └── CollisionShape3D
#
# For editor-authored fracture, we create frozen bodies so they are
# visible and saved in the scene, but do not simulate until later.
# -------------------------------------------------------------------

static func setup_fragments(
	fragments: Array,
	parent: Node,
	force_type: int = ForceType.EXPLOSION,
	force_magnitude: float = 20.0,
	force_direction: Vector3 = Vector3.FORWARD,
	explosion_origin: Vector3 = Vector3.ZERO,
	settle_mode: int = SettleMode.PERSIST,
	fade_time: float = 5.0,
	pre_density: float = 1.0,
	post_density: float = 1.0
) -> Array:
	FractureDebug.physics("Runtime setup_fragments() start: fragments=%d parent=%s force_type=%d magnitude=%f" % [
		fragments.size(),
		parent.name,
		force_type,
		force_magnitude
	])

	var kept_fragments: Array = _apply_pre_density(fragments, pre_density, explosion_origin)
	var bodies: Array = []
	var scene_owner: Node = parent.owner if parent.owner != null else parent

	for frag_obj in kept_fragments:
		var frag: MeshInstance3D = frag_obj
		var body: RigidBody3D = _create_body_for_fragment(frag)
		if body == null:
			continue

		body.freeze = false
		body.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		body.sleeping = false

		parent.add_child(body)
		_set_owner_recursive(body, scene_owner)

		var impulse: Vector3 = _compute_impulse(
			body.global_position,
			force_type,
			force_magnitude,
			force_direction,
			explosion_origin
		)

		body.call_deferred("apply_central_impulse", impulse)
		body.angular_velocity = Vector3(
			randf_range(-8.0, 8.0),
			randf_range(-8.0, 8.0),
			randf_range(-8.0, 8.0)
		)

		if settle_mode == SettleMode.FADE:
			_schedule_fade(body, fade_time)

		bodies.append(body)

		FractureDebug.physics("Runtime body '%s' added at %s mass=%f impulse=%s" % [
			body.name,
			body.global_position,
			body.mass,
			impulse
		])

	_schedule_post_density(bodies, post_density)

	FractureDebug.physics("Runtime setup_fragments() complete: bodies=%d" % bodies.size())
	return bodies


static func setup_fragments_editor(
	fragments: Array,
	parent: Node
) -> Array:
	FractureDebug.physics("Editor setup_fragments_editor() start: fragments=%d parent=%s" % [
		fragments.size(),
		parent.name
	])

	var bodies: Array = []
	var scene_owner: Node = parent.owner if parent.owner != null else parent

	for frag_obj in fragments:
		var frag: MeshInstance3D = frag_obj
		if frag == null:
			continue

		var body: RigidBody3D = _create_body_for_fragment(frag)
		if body == null:
			continue

		# Dormant until activated by FractureController at runtime
		body.freeze = true
		body.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		body.sleeping = true

		parent.add_child(body)
		_set_owner_recursive(body, scene_owner)

		bodies.append(body)

		FractureDebug.physics("Editor body '%s' added dormant at %s mass=%f" % [
			body.name,
			body.global_position,
			body.mass
		])

	FractureDebug.physics("Editor setup_fragments_editor() complete: bodies=%d" % bodies.size())
	return bodies


static func _create_body_for_fragment(frag: MeshInstance3D) -> RigidBody3D:
	if frag == null:
		return null

	if frag.mesh == null:
		FractureDebug.physics("Fragment '%s' has no mesh" % frag.name)
		return null

	var all_verts := PackedVector3Array()
	for si in range(frag.mesh.get_surface_count()):
		var arrays: Array = frag.mesh.surface_get_arrays(si)
		if arrays.is_empty():
			continue
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		all_verts.append_array(verts)

	# Deduplicate vertices to avoid hull builder errors
	var clean_verts := PackedVector3Array()
	for v in all_verts:
		var is_duplicate := false
		for existing in clean_verts:
			if v.distance_to(existing) < 0.001:
				is_duplicate = true
				break
		if not is_duplicate:
			clean_verts.append(v)

	var shape: ConvexPolygonShape3D = null
	if clean_verts.size() >= 4:
		# Check if points are not all coplanar
		var is_valid := false
		if clean_verts.size() >= 4:
			var v0: Vector3 = clean_verts[0]
			var v1: Vector3 = clean_verts[1]
			var v2: Vector3 = clean_verts[2]
			var normal: Vector3 = (v1 - v0).cross(v2 - v0)
			if normal.length_squared() > 0.0001:
				for i in range(3, clean_verts.size()):
					var dist: float = absf(normal.normalized().dot(clean_verts[i] - v0))
					if dist > 0.01:
						is_valid = true
						break

		if is_valid:
			shape = ConvexPolygonShape3D.new()
			shape.points = clean_verts
		else:
			FractureDebug.physics("Fragment '%s' has coplanar vertices, using box fallback" % frag.name)
			var aabb: AABB = frag.mesh.get_aabb()
			if aabb.size.length() > 0.01:
				var box := BoxShape3D.new()
				box.size = Vector3(
					maxf(aabb.size.x, 0.02),
					maxf(aabb.size.y, 0.02),
					maxf(aabb.size.z, 0.02)
				)
				shape = null
				var col := CollisionShape3D.new()
				col.name = "CollisionShape3D"
				col.shape = box
				col.position = aabb.get_center()
				# We'll add this below, store it temporarily
				frag.set_meta("_fallback_collision", col)
	else:
		FractureDebug.physics("Fragment '%s' has too few verts for collision (%d)" % [frag.name, clean_verts.size()])

	var original_name := frag.name

	var mesh_copy := MeshInstance3D.new()
	mesh_copy.name = original_name + "_Mesh"
	mesh_copy.mesh = frag.mesh
	mesh_copy.transform = Transform3D.IDENTITY
	mesh_copy.visible = true
	mesh_copy.material_override = frag.material_override

	for si in range(frag.get_surface_override_material_count()):
		var mat: Material = frag.get_surface_override_material(si)
		if mat != null:
			mesh_copy.set_surface_override_material(si, mat)

	var body := RigidBody3D.new()
	body.name = original_name + "_Body"
	body.position = frag.position
	body.add_to_group("fracture_body")

	# Fragments on layer 5 (bit 4 = 16)
	body.collision_layer = 16
	body.collision_mask = 1 | 2 | 16  # Environment + Player + other Fragments

	body.add_child(mesh_copy)

	# Add collision
	if frag.has_meta("_fallback_collision"):
		var fallback_col: CollisionShape3D = frag.get_meta("_fallback_collision")
		body.add_child(fallback_col)
	elif shape != null:
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.shape = shape
		body.add_child(col)

	var mass_val: float = maxf(_estimate_volume(frag.mesh) * 25.0, 0.05)
	if is_nan(mass_val) or mass_val <= 0.0:
		mass_val = 0.1
	body.mass = mass_val

	frag.queue_free()
	return body


static func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)


static func _estimate_volume(mesh: Mesh) -> float:
	var aabb: AABB = mesh.get_aabb()
	return maxf(absf(aabb.size.x * aabb.size.y * aabb.size.z), 0.001)


static func _compute_impulse(
	pos: Vector3,
	force_type: ForceType,
	magnitude: float,
	direction: Vector3,
	origin: Vector3
) -> Vector3:
	match force_type:
		ForceType.EXPLOSION:
			var diff: Vector3 = pos - origin
			if diff.length() < 0.05:
				diff = Vector3(
					randf_range(-1.0, 1.0),
					randf_range(0.2, 1.0),
					randf_range(-1.0, 1.0)
				)

			var dir: Vector3 = diff.normalized()
			dir.y += 0.35
			dir = dir.normalized()

			var dist: float = maxf(diff.length(), 0.25)
			var falloff: float = 1.0 / dist
			falloff = clampf(falloff, 0.8, 2.5)

			return dir * magnitude * falloff

		ForceType.CRUMBLE:
			return Vector3(
				randf_range(-1.0, 1.0),
				randf_range(0.0, 0.25),
				randf_range(-1.0, 1.0)
			).normalized() * magnitude * 0.25

		ForceType.DIRECTIONAL:
			var dir: Vector3 = direction.normalized() if direction.length() > 0.01 else Vector3.FORWARD
			dir += Vector3(
				randf_range(-0.15, 0.15),
				randf_range(-0.05, 0.15),
				randf_range(-0.15, 0.15)
			)
			return dir.normalized() * magnitude

	return Vector3.ZERO


static func _apply_pre_density(fragments: Array, keep_ratio: float, center: Vector3) -> Array:
	if keep_ratio >= 1.0:
		return fragments.duplicate()

	var sorted := fragments.duplicate()
	sorted.sort_custom(func(a, b):
		return a.position.distance_squared_to(center) < b.position.distance_squared_to(center)
	)

	var keep_count := int(ceil(float(sorted.size()) * keep_ratio))
	var out: Array = []

	for i in range(sorted.size()):
		if i < keep_count:
			out.append(sorted[i])
		else:
			FractureDebug.physics("Pre-density removing fragment '%s'" % sorted[i].name)
			sorted[i].queue_free()

	return out


static func _schedule_post_density(bodies: Array, keep_ratio: float) -> void:
	if keep_ratio >= 1.0:
		return

	var shuffled := bodies.duplicate()
	shuffled.shuffle()

	var keep_count := int(ceil(float(shuffled.size()) * keep_ratio))
	for i in range(keep_count, shuffled.size()):
		var body: RigidBody3D = shuffled[i]
		var timer := Timer.new()
		timer.one_shot = true
		timer.wait_time = randf_range(3.0, 8.0)
		body.add_child(timer)
		timer.timeout.connect(body.queue_free)
		timer.start()
		FractureDebug.physics("Post-density scheduled body '%s' for removal in %f sec" % [body.name, timer.wait_time])


static func _schedule_fade(body: RigidBody3D, fade_time: float) -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = fade_time
	body.add_child(timer)
	timer.timeout.connect(body.queue_free)
	timer.start()
	FractureDebug.physics("Fade scheduled for body '%s' in %f sec" % [body.name, fade_time])

static func activate_bodies(
	bodies: Array,
	force_type: int,
	force_magnitude: float,
	force_direction: Vector3,
	explosion_origin: Vector3,
	settle_mode: int,
	fade_time: float,
	post_density: float
) -> void:
	FractureDebug.physics("Activating bodies: count=%d force_type=%d magnitude=%f origin=%s" % [
		bodies.size(),
		force_type,
		force_magnitude,
		explosion_origin
	])

	for body_obj in bodies:
		var body: RigidBody3D = body_obj
		if body == null or not is_instance_valid(body):
			continue

		body.freeze = false
		body.sleeping = false

		var impulse: Vector3 = _compute_impulse(
			body.global_position,
			force_type,
			force_magnitude,
			force_direction,
			explosion_origin
		)

		body.apply_central_impulse(impulse)
		body.angular_velocity = Vector3(
			randf_range(-8.0, 8.0),
			randf_range(-8.0, 8.0),
			randf_range(-8.0, 8.0)
		)

		FractureDebug.physics("Activated body '%s' impulse=%s" % [body.name, impulse])

		if settle_mode == SettleMode.FADE:
			_schedule_fade(body, fade_time)

	_schedule_post_density(bodies, post_density)

static func setup_remainder(remainder: MeshInstance3D, parent: Node) -> MeshInstance3D:
	if remainder == null or remainder.mesh == null:
		return null

	var remainder_root := MeshInstance3D.new()
	remainder_root.name = remainder.name
	remainder_root.mesh = remainder.mesh
	remainder_root.transform = remainder.transform
	remainder_root.material_override = remainder.material_override
	remainder_root.visible = true

	for si in range(remainder.get_surface_override_material_count()):
		var mat: Material = remainder.get_surface_override_material(si)
		if mat != null:
			remainder_root.set_surface_override_material(si, mat)

	var body := StaticBody3D.new()
	body.name = "StaticBody3D"

	# Remainder on layer 1 (environment)
	body.collision_layer = 1
	body.collision_mask = 1 | 2 | 16  # Environment + Player + Fragments

	var all_faces := PackedVector3Array()
	for si in range(remainder.mesh.get_surface_count()):
		var arrays: Array = remainder.mesh.surface_get_arrays(si)
		if arrays.is_empty():
			continue

		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]

		if indices.size() > 0:
			for i in range(indices.size()):
				all_faces.append(verts[indices[i]])
		else:
			all_faces.append_array(verts)

	if all_faces.size() >= 3:
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(all_faces)

		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.shape = shape
		body.add_child(col)
	else:
		FractureDebug.physics("Remainder '%s' has too few faces for collision (%d)" % [
			remainder.name,
			all_faces.size()
		])

	remainder_root.add_child(body)

	remainder.queue_free()
	return remainder_root

static func _set_collision_disabled_recursive(node: Node, disabled: bool) -> void:
	if node == null or not is_instance_valid(node):
		return

	if node is CollisionShape3D:
		var shape_node: CollisionShape3D = node
		shape_node.disabled = disabled

	for child in node.get_children():
		_set_collision_disabled_recursive(child, disabled)
