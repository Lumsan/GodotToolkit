@tool
class_name FracturePanel
extends VBoxContainer

# ============================================================
# SIGNALS — new fracture mode
# ============================================================
signal start_session_pressed
signal spawn_box_pressed
signal spawn_sphere_pressed
signal spawn_cylinder_pressed
signal fracture_pressed
signal undo_pressed
signal finish_pressed

signal new_cap_material_pressed
signal load_cap_material_pressed
signal edit_cap_material_pressed
signal reset_cap_material_pressed

# ============================================================
# SIGNALS — cluster edit mode
# ============================================================
signal refracture_cluster_pressed
signal delete_cluster_pressed
signal edit_trigger_path_pressed

# ============================================================
# NEW FRACTURE SETTINGS
# ============================================================
var fragment_count: int = 8
var force_type: int = PhysicsLayer.ForceType.EXPLOSION
var force_magnitude: float = 10.0
var force_direction: Vector3 = Vector3.ZERO
var settle_mode: int = PhysicsLayer.SettleMode.PERSIST
var fade_time: float = 5.0
var post_density: float = 1.0

var use_separate_cap_material: bool = false
var cap_material_override: Material = null

# ============================================================
# CLUSTER EDIT STATE
# ============================================================
var _edit_mode: bool = false
var _editing_cluster: FractureCluster = null
var _editing_fractured_mesh: FracturedMesh = null
var _editing_cluster_id: int = -1

# ============================================================
# UI REFERENCES
# ============================================================
var _status_label: Label
var _content: VBoxContainer
var _cap_material_label: Label
var _cap_check: CheckBox

var _new_fracture_section: VBoxContainer
var _cluster_edit_section: VBoxContainer
var _cluster_info_label: Label

var _force_option: OptionButton
var _mag_spin: SpinBox
var _dir_container: VBoxContainer
var _dir_x: SpinBox
var _dir_y: SpinBox
var _dir_z: SpinBox
var _settle_option: OptionButton
var _fade_container: VBoxContainer
var _fade_spin: SpinBox
var _post_spin: SpinBox

var _cluster_frag_spin: SpinBox
var _activation_mode_option: OptionButton
var _activation_delay_container: VBoxContainer
var _activation_delay_spin: SpinBox
var _trigger_container: VBoxContainer
var _delayed_collision_check: CheckBox
var _collision_delay_container: VBoxContainer
var _collision_delay_spin: SpinBox

var _cap_section_content: VBoxContainer
var _cap_section_btn: Button

var _interaction_option: OptionButton
var _mass_multiplier_spin: SpinBox
var _mass_multiplier_container: VBoxContainer

var _freeze_rotation_check: CheckBox
var _rotation_freeze_delay_container: VBoxContainer
var _rotation_freeze_delay_spin: SpinBox


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	custom_minimum_size = Vector2(320, 0)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_FILL
	scroll.add_child(_content)

	var title := Label.new()
	title.text = "Fracture System"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	_content.add_child(title)

	_content.add_child(HSeparator.new())

	# ==========================
	# NEW FRACTURE SECTION
	# ==========================
	_new_fracture_section = VBoxContainer.new()
	_content.add_child(_new_fracture_section)

	# Session
	var session_row := HBoxContainer.new()
	_new_fracture_section.add_child(session_row)

	var start_btn := Button.new()
	start_btn.text = "Start Session"
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.pressed.connect(func(): start_session_pressed.emit())
	session_row.add_child(start_btn)

	var finish_btn := Button.new()
	finish_btn.text = "Finish"
	finish_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	finish_btn.pressed.connect(func(): finish_pressed.emit())
	session_row.add_child(finish_btn)

	_new_fracture_section.add_child(HSeparator.new())

	# Region spawning
	var spawn_label := Label.new()
	spawn_label.text = "Spawn Region"
	_new_fracture_section.add_child(spawn_label)

	var spawn_row := HBoxContainer.new()
	_new_fracture_section.add_child(spawn_row)

	var box_btn := Button.new()
	box_btn.text = "Box (B)"
	box_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_btn.pressed.connect(func(): spawn_box_pressed.emit())
	spawn_row.add_child(box_btn)

	var sphere_btn := Button.new()
	sphere_btn.text = "Sphere (S)"
	sphere_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sphere_btn.pressed.connect(func(): spawn_sphere_pressed.emit())
	spawn_row.add_child(sphere_btn)

	var cylinder_btn := Button.new()
	cylinder_btn.text = "Cylinder (C)"
	cylinder_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cylinder_btn.pressed.connect(func(): spawn_cylinder_pressed.emit())
	spawn_row.add_child(cylinder_btn)

	_new_fracture_section.add_child(HSeparator.new())

	# Fragment count
	var frag_label := Label.new()
	frag_label.text = "Fragment Count"
	_new_fracture_section.add_child(frag_label)

	var frag_spin := SpinBox.new()
	frag_spin.min_value = 2
	frag_spin.max_value = 128
	frag_spin.step = 1
	frag_spin.value = fragment_count
	frag_spin.value_changed.connect(func(v): fragment_count = int(v))
	_new_fracture_section.add_child(frag_spin)

	_new_fracture_section.add_child(HSeparator.new())

	# Cap material (collapsible)
	_cap_section_btn = Button.new()
	_cap_section_btn.text = "▶ Cap Appearance"
	_cap_section_btn.flat = true
	_cap_section_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cap_section_btn.pressed.connect(_toggle_cap_section)
	_new_fracture_section.add_child(_cap_section_btn)

	_cap_section_content = VBoxContainer.new()
	_cap_section_content.visible = false
	_new_fracture_section.add_child(_cap_section_content)

	_cap_check = CheckBox.new()
	_cap_check.text = "Use Separate Cap Material"
	_cap_check.button_pressed = use_separate_cap_material
	_cap_check.toggled.connect(func(v): use_separate_cap_material = v)
	_cap_section_content.add_child(_cap_check)

	var cap_mat_label := Label.new()
	cap_mat_label.text = "Cap Material"
	_cap_section_content.add_child(cap_mat_label)

	_cap_material_label = Label.new()
	_cap_material_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cap_material_label.text = "<none>"
	_cap_section_content.add_child(_cap_material_label)

	var cap_btn_row := HBoxContainer.new()
	_cap_section_content.add_child(cap_btn_row)

	var cap_new := Button.new()
	cap_new.text = "New"
	cap_new.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_new.pressed.connect(func(): new_cap_material_pressed.emit())
	cap_btn_row.add_child(cap_new)

	var cap_load := Button.new()
	cap_load.text = "Load"
	cap_load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_load.pressed.connect(func(): load_cap_material_pressed.emit())
	cap_btn_row.add_child(cap_load)

	var cap_edit := Button.new()
	cap_edit.text = "Edit"
	cap_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_edit.pressed.connect(func(): edit_cap_material_pressed.emit())
	cap_btn_row.add_child(cap_edit)

	var cap_reset := Button.new()
	cap_reset.text = "Reset"
	cap_reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cap_reset.pressed.connect(func(): reset_cap_material_pressed.emit())
	cap_btn_row.add_child(cap_reset)

	_new_fracture_section.add_child(HSeparator.new())

	# Fracture / Undo
	var action_row := HBoxContainer.new()
	_new_fracture_section.add_child(action_row)

	var fracture_btn := Button.new()
	fracture_btn.text = "Fracture"
	fracture_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fracture_btn.pressed.connect(func(): fracture_pressed.emit())
	action_row.add_child(fracture_btn)

	var undo_btn := Button.new()
	undo_btn.text = "Undo Last"
	undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	undo_btn.pressed.connect(func(): undo_pressed.emit())
	action_row.add_child(undo_btn)

	# ==========================
	# CLUSTER EDIT SECTION
	# ==========================
	_cluster_edit_section = VBoxContainer.new()
	_cluster_edit_section.visible = false
	_content.add_child(_cluster_edit_section)

	_cluster_info_label = Label.new()
	_cluster_info_label.text = "Editing Cluster: ---"
	_cluster_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cluster_edit_section.add_child(_cluster_info_label)

	_cluster_edit_section.add_child(HSeparator.new())

	# Geometry
	var geom_label := Label.new()
	geom_label.text = "Geometry (needs refracture)"
	_cluster_edit_section.add_child(geom_label)

	var cfrag_label := Label.new()
	cfrag_label.text = "Fragment Count"
	_cluster_edit_section.add_child(cfrag_label)

	_cluster_frag_spin = SpinBox.new()
	_cluster_frag_spin.min_value = 2
	_cluster_frag_spin.max_value = 128
	_cluster_frag_spin.step = 1
	_cluster_frag_spin.value = 8
	_cluster_edit_section.add_child(_cluster_frag_spin)

	var refracture_btn := Button.new()
	refracture_btn.text = "Refracture This Cluster"
	refracture_btn.pressed.connect(func(): refracture_cluster_pressed.emit())
	_cluster_edit_section.add_child(refracture_btn)

	_cluster_edit_section.add_child(HSeparator.new())

	# Activation
	var act_label := Label.new()
	act_label.text = "Activation"
	_cluster_edit_section.add_child(act_label)

	var act_mode_label := Label.new()
	act_mode_label.text = "Activation Mode"
	_cluster_edit_section.add_child(act_mode_label)

	_activation_mode_option = OptionButton.new()
	_activation_mode_option.add_item("Immediate", FractureCluster.ActivationMode.IMMEDIATE)
	_activation_mode_option.add_item("Delayed", FractureCluster.ActivationMode.DELAYED)
	_activation_mode_option.add_item("On Signal", FractureCluster.ActivationMode.ON_SIGNAL)
	_activation_mode_option.add_item("On Trigger", FractureCluster.ActivationMode.ON_TRIGGER)
	_activation_mode_option.item_selected.connect(_on_activation_mode_changed)
	_cluster_edit_section.add_child(_activation_mode_option)

	_activation_delay_container = VBoxContainer.new()
	_activation_delay_container.visible = false
	_cluster_edit_section.add_child(_activation_delay_container)

	var delay_label := Label.new()
	delay_label.text = "Activation Delay (seconds)"
	_activation_delay_container.add_child(delay_label)

	_activation_delay_spin = SpinBox.new()
	_activation_delay_spin.min_value = 0.0
	_activation_delay_spin.max_value = 60.0
	_activation_delay_spin.step = 0.1
	_activation_delay_spin.value = 0.0
	_activation_delay_spin.value_changed.connect(_on_activation_delay_changed)
	_activation_delay_container.add_child(_activation_delay_spin)

	_trigger_container = VBoxContainer.new()
	_trigger_container.visible = false
	_cluster_edit_section.add_child(_trigger_container)

	var trigger_note := Label.new()
	trigger_note.text = "Set trigger_area_path in the Inspector."
	trigger_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_trigger_container.add_child(trigger_note)

	var trigger_btn := Button.new()
	trigger_btn.text = "Open Cluster in Inspector"
	trigger_btn.pressed.connect(func(): edit_trigger_path_pressed.emit())
	_trigger_container.add_child(trigger_btn)

	_cluster_edit_section.add_child(HSeparator.new())

	# Interaction
	var interact_label := Label.new()
	interact_label.text = "Fragment Interaction"
	_cluster_edit_section.add_child(interact_label)

	var interact_mode_label := Label.new()
	interact_mode_label.text = "Interaction Mode"
	_cluster_edit_section.add_child(interact_mode_label)

	_interaction_option = OptionButton.new()
	_interaction_option.add_item("Solid", FractureCluster.FragmentInteraction.SOLID)
	_interaction_option.add_item("Pushable", FractureCluster.FragmentInteraction.PUSHABLE)
	_interaction_option.add_item("No Collision", FractureCluster.FragmentInteraction.NO_COLLISION)
	_interaction_option.item_selected.connect(_on_interaction_changed)
	_cluster_edit_section.add_child(_interaction_option)

	_mass_multiplier_container = VBoxContainer.new()
	_cluster_edit_section.add_child(_mass_multiplier_container)

	var mass_label := Label.new()
	mass_label.text = "Mass Multiplier"
	_mass_multiplier_container.add_child(mass_label)

	_mass_multiplier_spin = SpinBox.new()
	_mass_multiplier_spin.min_value = 0.01
	_mass_multiplier_spin.max_value = 100.0
	_mass_multiplier_spin.step = 0.1
	_mass_multiplier_spin.value = 1.0
	_mass_multiplier_spin.value_changed.connect(_on_mass_multiplier_changed)
	_mass_multiplier_container.add_child(_mass_multiplier_spin)

	_freeze_rotation_check = CheckBox.new()
	_freeze_rotation_check.text = "Freeze Rotation After Delay"
	_freeze_rotation_check.button_pressed = true
	_freeze_rotation_check.toggled.connect(_on_freeze_rotation_changed)
	_cluster_edit_section.add_child(_freeze_rotation_check)

	_rotation_freeze_delay_container = VBoxContainer.new()
	_rotation_freeze_delay_container.visible = false
	_cluster_edit_section.add_child(_rotation_freeze_delay_container)

	var rot_delay_label := Label.new()
	rot_delay_label.text = "Rotation Freeze Delay (seconds)"
	_rotation_freeze_delay_container.add_child(rot_delay_label)

	_rotation_freeze_delay_spin = SpinBox.new()
	_rotation_freeze_delay_spin.min_value = 0.0
	_rotation_freeze_delay_spin.max_value = 10.0
	_rotation_freeze_delay_spin.step = 0.1
	_rotation_freeze_delay_spin.value = 1.0
	_rotation_freeze_delay_spin.value_changed.connect(_on_rotation_freeze_delay_changed)
	_rotation_freeze_delay_container.add_child(_rotation_freeze_delay_spin)

	_cluster_edit_section.add_child(HSeparator.new())

	# Fragment clearing (collapsible)
	var clear_btn := Button.new()
	clear_btn.text = "▶ Fragment Clearing"
	clear_btn.flat = true
	clear_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_cluster_edit_section.add_child(clear_btn)

	var clear_content := VBoxContainer.new()
	clear_content.visible = false
	_cluster_edit_section.add_child(clear_content)

	clear_btn.pressed.connect(func():
		clear_content.visible = not clear_content.visible
		clear_btn.text = ("▼ " if clear_content.visible else "▶ ") + "Fragment Clearing"
	)

	_delayed_collision_check = CheckBox.new()
	_delayed_collision_check.text = "Delayed Collision"
	_delayed_collision_check.button_pressed = false
	_delayed_collision_check.toggled.connect(_on_delayed_collision_changed)
	clear_content.add_child(_delayed_collision_check)

	var delay_note := Label.new()
	delay_note.text = "Temporarily disables collision with environment so fragments can escape the cavity."
	delay_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clear_content.add_child(delay_note)

	_collision_delay_container = VBoxContainer.new()
	_collision_delay_container.visible = false
	clear_content.add_child(_collision_delay_container)

	var col_delay_label := Label.new()
	col_delay_label.text = "Collision Delay (seconds)"
	_collision_delay_container.add_child(col_delay_label)

	_collision_delay_spin = SpinBox.new()
	_collision_delay_spin.min_value = 0.01
	_collision_delay_spin.max_value = 5.0
	_collision_delay_spin.step = 0.05
	_collision_delay_spin.value = 0.15
	_collision_delay_spin.value_changed.connect(_on_collision_delay_changed)
	_collision_delay_container.add_child(_collision_delay_spin)

	_cluster_edit_section.add_child(HSeparator.new())

	# Delete / Back
	var manage_row := HBoxContainer.new()
	_cluster_edit_section.add_child(manage_row)

	var delete_btn := Button.new()
	delete_btn.text = "Delete Cluster"
	delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_btn.pressed.connect(func(): delete_cluster_pressed.emit())
	manage_row.add_child(delete_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func(): set_mode_new_fracture())
	manage_row.add_child(back_btn)

	# ==========================
	# SHARED RUNTIME SETTINGS
	# ==========================
	_content.add_child(HSeparator.new())

	var runtime_label := Label.new()
	runtime_label.text = "Runtime Settings"
	_content.add_child(runtime_label)

	var force_label := Label.new()
	force_label.text = "Force Type"
	_content.add_child(force_label)

	_force_option = OptionButton.new()
	_force_option.add_item("Explosion", PhysicsLayer.ForceType.EXPLOSION)
	_force_option.add_item("Crumble", PhysicsLayer.ForceType.CRUMBLE)
	_force_option.add_item("Directional", PhysicsLayer.ForceType.DIRECTIONAL)
	_force_option.item_selected.connect(_on_runtime_force_type_changed)
	_content.add_child(_force_option)

	var mag_label := Label.new()
	mag_label.text = "Force Magnitude"
	_content.add_child(mag_label)

	_mag_spin = SpinBox.new()
	_mag_spin.min_value = 0.0
	_mag_spin.max_value = 1000000.0
	_mag_spin.step = 10.0
	_mag_spin.value = force_magnitude
	_mag_spin.value_changed.connect(_on_runtime_magnitude_changed)
	_content.add_child(_mag_spin)

	_dir_container = VBoxContainer.new()
	_content.add_child(_dir_container)

	var dir_label := Label.new()
	dir_label.text = "Directional Force Vector"
	_dir_container.add_child(dir_label)

	var dir_box := HBoxContainer.new()
	_dir_x = SpinBox.new()
	_dir_y = SpinBox.new()
	_dir_z = SpinBox.new()
	for sb in [_dir_x, _dir_y, _dir_z]:
		sb.min_value = -100.0
		sb.max_value = 100.0
		sb.step = 0.1
		sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dir_x.value = 0.0
	_dir_y.value = 0.0
	_dir_z.value = 1.0
	_dir_x.value_changed.connect(func(_v): _on_runtime_direction_changed())
	_dir_y.value_changed.connect(func(_v): _on_runtime_direction_changed())
	_dir_z.value_changed.connect(func(_v): _on_runtime_direction_changed())
	dir_box.add_child(_dir_x)
	dir_box.add_child(_dir_y)
	dir_box.add_child(_dir_z)
	_dir_container.add_child(dir_box)

	_content.add_child(HSeparator.new())

	var settle_label := Label.new()
	settle_label.text = "Settling"
	_content.add_child(settle_label)

	_settle_option = OptionButton.new()
	_settle_option.add_item("Persist", PhysicsLayer.SettleMode.PERSIST)
	_settle_option.add_item("Fade", PhysicsLayer.SettleMode.FADE)
	_settle_option.item_selected.connect(_on_runtime_settle_changed)
	_content.add_child(_settle_option)

	_fade_container = VBoxContainer.new()
	_fade_container.visible = false
	_content.add_child(_fade_container)

	var fade_label := Label.new()
	fade_label.text = "Fade Time (seconds)"
	_fade_container.add_child(fade_label)

	_fade_spin = SpinBox.new()
	_fade_spin.min_value = 0.5
	_fade_spin.max_value = 60.0
	_fade_spin.step = 0.5
	_fade_spin.value = fade_time
	_fade_spin.value_changed.connect(_on_runtime_fade_changed)
	_fade_container.add_child(_fade_spin)

	_content.add_child(HSeparator.new())

	var post_label := Label.new()
	post_label.text = "Post-density keep %"
	_content.add_child(post_label)

	_post_spin = SpinBox.new()
	_post_spin.min_value = 0.0
	_post_spin.max_value = 100.0
	_post_spin.step = 5.0
	_post_spin.value = 100.0
	_post_spin.value_changed.connect(_on_runtime_post_density_changed)
	_content.add_child(_post_spin)

	_content.add_child(HSeparator.new())

	_status_label = Label.new()
	_status_label.text = "Ready. Press Start Session."
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(_status_label)

	_update_conditional_visibility()


# ============================================================
# COLLAPSIBLE TOGGLE
# ============================================================

func _toggle_cap_section() -> void:
	_cap_section_content.visible = not _cap_section_content.visible
	_cap_section_btn.text = ("▼ " if _cap_section_content.visible else "▶ ") + "Cap Appearance"


# ============================================================
# CONDITIONAL VISIBILITY
# ============================================================

func _update_conditional_visibility() -> void:
	if _dir_container != null:
		_dir_container.visible = (force_type == PhysicsLayer.ForceType.DIRECTIONAL)

	if _fade_container != null:
		_fade_container.visible = (settle_mode == PhysicsLayer.SettleMode.FADE)

	if _activation_delay_container != null and _activation_mode_option != null:
		_activation_delay_container.visible = (_activation_mode_option.selected == FractureCluster.ActivationMode.DELAYED)

	if _trigger_container != null and _activation_mode_option != null:
		_trigger_container.visible = (_activation_mode_option.selected == FractureCluster.ActivationMode.ON_TRIGGER)

	if _collision_delay_container != null and _delayed_collision_check != null:
		_collision_delay_container.visible = _delayed_collision_check.button_pressed

	var solid_mode: bool = false
	if _interaction_option != null:
		solid_mode = (_interaction_option.selected == FractureCluster.FragmentInteraction.SOLID)

	if _freeze_rotation_check != null:
		_freeze_rotation_check.visible = solid_mode

	if _rotation_freeze_delay_container != null and _freeze_rotation_check != null:
		_rotation_freeze_delay_container.visible = solid_mode and _freeze_rotation_check.button_pressed

	if _mass_multiplier_container != null:
		_mass_multiplier_container.visible = true


# ============================================================
# MODE SWITCHING
# ============================================================

func set_mode_new_fracture() -> void:
	_edit_mode = false
	_editing_cluster = null
	_editing_fractured_mesh = null
	_editing_cluster_id = -1

	_new_fracture_section.visible = true
	_cluster_edit_section.visible = false

	_update_conditional_visibility()
	set_status("New fracture mode.")


func set_mode_edit_cluster(
	cluster: FractureCluster,
	fractured_mesh: FracturedMesh
) -> void:
	_edit_mode = true
	_editing_cluster = cluster
	_editing_fractured_mesh = fractured_mesh
	_editing_cluster_id = cluster.cluster_id

	_new_fracture_section.visible = false
	_cluster_edit_section.visible = true

	_cluster_info_label.text = "Editing: %s (id=%d)" % [cluster.name, cluster.cluster_id]

	var settings: Dictionary = cluster.get_runtime_settings()
	force_type = settings.get("force_type", 0)
	settle_mode = settings.get("settle_mode", 0)

	_force_option.selected = force_type
	_mag_spin.value = settings.get("force_magnitude", 80.0)
	var dir: Vector3 = settings.get("force_direction", Vector3.ZERO)
	_dir_x.value = dir.x
	_dir_y.value = dir.y
	_dir_z.value = dir.z
	_settle_option.selected = settle_mode
	_fade_spin.value = settings.get("fade_time", 5.0)
	_post_spin.value = settings.get("post_density", 1.0) * 100.0

	var op: Dictionary = fractured_mesh.get_operation_by_id(cluster.cluster_id)
	if not op.is_empty():
		_cluster_frag_spin.value = op.get("fragment_count", 8)

	_activation_mode_option.selected = settings.get("activation_mode", FractureCluster.ActivationMode.IMMEDIATE)
	_activation_delay_spin.value = settings.get("activation_delay", 0.0)
	_delayed_collision_check.button_pressed = settings.get("delayed_collision", false)
	_collision_delay_spin.value = settings.get("collision_delay", 0.15)

	_interaction_option.selected = settings.get("fragment_interaction", FractureCluster.FragmentInteraction.SOLID)
	_mass_multiplier_spin.value = settings.get("fragment_mass_multiplier", 1.0)
	_freeze_rotation_check.button_pressed = settings.get("freeze_rotation_after_delay", true)
	_rotation_freeze_delay_spin.value = settings.get("rotation_freeze_delay", 1.0)

	_update_conditional_visibility()
	set_status("Editing cluster '%s'." % cluster.name)


func is_in_edit_mode() -> bool:
	return _edit_mode


func get_editing_cluster() -> FractureCluster:
	return _editing_cluster


func get_editing_fractured_mesh() -> FracturedMesh:
	return _editing_fractured_mesh


func get_editing_cluster_id() -> int:
	return _editing_cluster_id


func get_cluster_edit_fragment_count() -> int:
	if _cluster_frag_spin != null:
		return int(_cluster_frag_spin.value)
	return 8


# ============================================================
# CLUSTER-SPECIFIC HANDLERS
# ============================================================

func _on_activation_mode_changed(_idx: int) -> void:
	_update_conditional_visibility()
	if _edit_mode:
		_push_runtime_to_cluster()


func _on_activation_delay_changed(_v: float) -> void:
	if _edit_mode:
		_push_runtime_to_cluster()


func _on_delayed_collision_changed(_pressed: bool) -> void:
	_update_conditional_visibility()
	if _edit_mode:
		_push_runtime_to_cluster()


func _on_collision_delay_changed(_v: float) -> void:
	if _edit_mode:
		_push_runtime_to_cluster()


func _on_interaction_changed(_idx: int) -> void:
	_update_conditional_visibility()
	if _edit_mode:
		_push_runtime_to_cluster()


func _on_mass_multiplier_changed(_v: float) -> void:
	if _edit_mode:
		_push_runtime_to_cluster()


func _on_freeze_rotation_changed(_pressed: bool) -> void:
	_update_conditional_visibility()
	if _edit_mode:
		_push_runtime_to_cluster()


func _on_rotation_freeze_delay_changed(_v: float) -> void:
	if _edit_mode:
		_push_runtime_to_cluster()


# ============================================================
# SHARED RUNTIME HANDLERS
# ============================================================

func _on_runtime_force_type_changed(idx: int) -> void:
	force_type = idx
	_update_conditional_visibility()
	if _edit_mode:
		_push_runtime_to_cluster()


func _on_runtime_magnitude_changed(v: float) -> void:
	force_magnitude = v
	if _edit_mode:
		_push_runtime_to_cluster()


func _on_runtime_direction_changed() -> void:
	force_direction = Vector3(_dir_x.value, _dir_y.value, _dir_z.value)
	if _edit_mode:
		_push_runtime_to_cluster()


func _on_runtime_settle_changed(idx: int) -> void:
	settle_mode = idx
	_update_conditional_visibility()
	if _edit_mode:
		_push_runtime_to_cluster()


func _on_runtime_fade_changed(v: float) -> void:
	fade_time = v
	if _edit_mode:
		_push_runtime_to_cluster()


func _on_runtime_post_density_changed(v: float) -> void:
	post_density = v / 100.0
	if _edit_mode:
		_push_runtime_to_cluster()


func _push_runtime_to_cluster() -> void:
	if _editing_fractured_mesh == null or _editing_cluster_id < 0:
		return

	var settings := {
		"force_type": _force_option.selected,
		"force_magnitude": _mag_spin.value,
		"force_direction": Vector3(_dir_x.value, _dir_y.value, _dir_z.value),
		"settle_mode": _settle_option.selected,
		"fade_time": _fade_spin.value,
		"post_density": _post_spin.value / 100.0,
		"activation_mode": _activation_mode_option.selected,
		"activation_delay": _activation_delay_spin.value,
		"delayed_collision": _delayed_collision_check.button_pressed,
		"collision_delay": _collision_delay_spin.value,
		"fragment_interaction": _interaction_option.selected,
		"fragment_mass_multiplier": _mass_multiplier_spin.value,
		"freeze_rotation_after_delay": _freeze_rotation_check.button_pressed,
		"rotation_freeze_delay": _rotation_freeze_delay_spin.value,
	}

	FractureSystem.update_cluster_runtime(_editing_fractured_mesh, _editing_cluster_id, settings)

	if _editing_cluster != null:
		set_status("Settings updated on '%s'." % _editing_cluster.name)


# ============================================================
# CAP MATERIAL
# ============================================================

func set_cap_material(mat: Material) -> void:
	cap_material_override = mat
	if _cap_material_label != null:
		if mat == null:
			_cap_material_label.text = "<none>"
		elif mat.resource_path != "":
			_cap_material_label.text = mat.resource_path
		else:
			_cap_material_label.text = "<unsaved material>"


func set_use_separate_cap_material(enabled: bool) -> void:
	use_separate_cap_material = enabled
	if _cap_check != null:
		_cap_check.button_pressed = enabled


# ============================================================
# STATUS
# ============================================================

func set_status(text: String) -> void:
	if _status_label != null:
		_status_label.text = text
	FractureDebug.editor("Panel status: %s" % text)


# ============================================================
# KEYBOARD INPUT
# ============================================================

func _unhandled_key_input(event: InputEvent) -> void:
	if not _is_panel_focused():
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B:
				spawn_box_pressed.emit()
				get_viewport().set_input_as_handled()
			KEY_S:
				spawn_sphere_pressed.emit()
				get_viewport().set_input_as_handled()
			KEY_C:
				spawn_cylinder_pressed.emit()
				get_viewport().set_input_as_handled()


func _is_panel_focused() -> bool:
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == null:
		return false
	return is_ancestor_of(focused) or focused == self
