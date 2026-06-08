extends Control
## Stage 17.7 — interactive pose tuner.
##
## Goal: kill the edit-render-squint loop. Load a class sprite live in a
## SubViewport, expose rotation sliders for every pivot + position
## sliders for every Marker2D, and let the dev drag values until the
## pose looks right. The IK runs each frame because the sprite is in
## the tree, so dragging a NockMarker x slider immediately shows the
## draw arm follow it.
##
## Hotkeys:
##   F1       — cycle class (pythia → myrmidon → shade_hunter → ossuary_priest)
##   F2       — cycle variant for the current class
##   F3       — cycle stance (within current class's weapon-stance catalog)
##   D        — dump current pose to console + tmp/pose_dump.txt as
##              keyframe Dictionary ready to paste into sprite_specs.gd
##   1-5      — score CURRENT (stance, anim, time) into tmp/stance_scores.json
##   S        — save current BowArm/NockMarker values as the RECOMMENDED
##              override for (class, stance_id, phase) into
##              tmp/recommended_stances.json. Sprite reads it at _ready
##              and overrides the catalog defaults.
##   SPACE    — toggle play/pause of the animation
##   R        — reset all sliders (reload sprite fresh)
##
## Run: godot res://test/pose_tuner.tscn

const VIEW_SIZE: Vector2i = Vector2i(360, 360)
const SPRITE_SCALE: float = 3.0
const FEET_POS := Vector2(180, 320)

# Class catalog — id, scene path, available variants.
# Variants are {name, anim, equip} — equip drives WeaponProfiles like
# sprite_render does.
const CLASSES: Array = [
	{
		"id": &"pythia",
		"scene": "res://art/procedural/classes/pythia_sprite.tscn",
		"variants": [
			{ "name": "idle_staff",   "anim": &"idle",   "equip": { "weapon": &"pythia_staff_starter" } },
			{ "name": "walk_staff",   "anim": &"walk",   "equip": { "weapon": &"pythia_staff_starter" } },
			{ "name": "attack_staff", "anim": &"attack", "equip": { "weapon": &"pythia_staff_starter" } },
			{ "name": "cast_staff",   "anim": &"cast",   "equip": { "weapon": &"pythia_staff_starter" } },
		],
	},
	{
		"id": &"myrmidon",
		"scene": "res://art/procedural/classes/myrmidon_sprite.tscn",
		"variants": [
			{ "name": "idle_bare",   "anim": &"idle",   "equip": {} },
			{ "name": "attack_spear", "anim": &"attack", "equip": { "weapon": &"myrmidon_spear_starter" } },
		],
	},
	{
		"id": &"shade_hunter",
		"scene": "res://art/procedural/classes/shade_hunter_sprite.tscn",
		"variants": [
			{ "name": "idle",   "anim": &"idle",   "equip": {} },
			{ "name": "attack", "anim": &"attack", "equip": {} },
		],
	},
	{
		"id": &"ossuary_priest",
		"scene": "res://art/procedural/classes/ossuary_priest_sprite.tscn",
		"variants": [
			{ "name": "idle",   "anim": &"idle",   "equip": {} },
			{ "name": "attack", "anim": &"attack", "equip": {} },
		],
	},
]

const BowStances   = preload("res://scripts/systems/stances/bow_stances.gd")
const StaffStances = preload("res://scripts/systems/stances/staff_stances.gd")
const SpearStances = preload("res://scripts/systems/stances/spear_stances.gd")

# Per-class stance catalog. Maps class id → catalog tag used in
# _load_current to populate _stance_ids from the right catalog.
const STANCE_CATALOGS: Dictionary = {
	&"shade_hunter":   &"bow",
	&"pythia":         &"staff",
	&"myrmidon":       &"spear",
}

# State.
var _class_idx: int = 0
var _variant_idx: int = 0
var _stance_ids: Array = []   # candidate stance ids for current class
var _stance_idx: int = 0
# Default ON so loading a sprite lands in manual-tuning mode — the
# user explicitly asked for shoulder/elbow sliders to work without an
# extra click. Untoggle to re-enable runtime IK pinning.
var _ik_disabled: bool = true
var _vp: SubViewport
var _vp_container: SubViewportContainer
var _drag_node: Node2D = null
var _drag_last_mouse: Vector2 = Vector2.ZERO
var _sprite: Node2D
var _anim: AnimationPlayer
var _inv: Inventory
var _paperdoll: EquipmentPaperdoll
var _paused: bool = true
var _scrub_time: float = 0.0

# UI refs (built in _ready)
var _label_class: Label
var _label_variant: Label
var _label_time: Label
var _label_score: Label
var _time_slider: HSlider
var _slider_box: VBoxContainer
# Per-node slider references for the "Dump Pose" extractor.
# Each entry: { "kind": "rot"|"pos", "node_path": String, "controls": [Range...] }
var _slider_entries: Array = []

func _ready() -> void:
	_build_ui()
	_load_current()

# =========================================================================
# UI scaffolding
# =========================================================================

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := HSplitContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.split_offset = 360
	add_child(root)
	# Sidebar
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(360, 0)
	root.add_child(side)
	_label_class = Label.new(); side.add_child(_label_class)
	_label_variant = Label.new(); side.add_child(_label_variant)
	_label_time = Label.new(); side.add_child(_label_time)
	_label_score = Label.new()
	_label_score.text = "Phase: —     Last score: —"
	side.add_child(_label_score)
	_time_slider = HSlider.new()
	_time_slider.min_value = 0.0
	_time_slider.max_value = 1.0
	_time_slider.step = 0.001
	_time_slider.value_changed.connect(_on_time_changed)
	side.add_child(_time_slider)
	var btn_row := HBoxContainer.new()
	side.add_child(btn_row)
	var dump := Button.new(); dump.text = "Dump Pose (D)"
	dump.pressed.connect(_on_dump_pressed); btn_row.add_child(dump)
	var play := Button.new(); play.text = "Play/Pause (Space)"
	play.pressed.connect(_on_play_toggle); btn_row.add_child(play)
	var reset := Button.new(); reset.text = "Reset (R)"
	reset.pressed.connect(_on_reset_pressed); btn_row.add_child(reset)
	# Stage 17.8 — Disable IK so shoulder/elbow rotation sliders can
	# actually move arms. With IK on, the runtime pin pass overwrites
	# any manual rotation every frame.
	var ik_box := CheckBox.new()
	ik_box.text = "Disable IK (manual arm tuning)"
	ik_box.button_pressed = _ik_disabled   # reflect default
	ik_box.toggled.connect(_on_ik_toggled)
	side.add_child(ik_box)
	var hint := Label.new()
	hint.text = "F1 class  ·  F2 variant  ·  F3 stance  ·  1-5 score  ·  Space play/pause  ·  D dump  ·  R reset"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(scroll)
	_slider_box = VBoxContainer.new()
	_slider_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_slider_box)
	# Viewport pane. Stretch OFF + fixed size so mouse position in the
	# container maps 1:1 to viewport pixels — required for drag-handle
	# math to land on the right marker.
	var vp_container := SubViewportContainer.new()
	vp_container.stretch = false
	vp_container.custom_minimum_size = Vector2(VIEW_SIZE)
	vp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vp_container.gui_input.connect(_on_viewport_input)
	vp_container.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(vp_container)
	_vp_container = vp_container
	_vp = SubViewport.new()
	_vp.size = VIEW_SIZE
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.10, 0.14)
	bg.size = VIEW_SIZE
	_vp.add_child(bg)
	vp_container.add_child(_vp)

# =========================================================================
# Sprite loading
# =========================================================================

func _load_current() -> void:
	# Tear down prior sprite.
	if _sprite != null:
		_sprite.queue_free(); _sprite = null
	if _inv != null:
		_inv.queue_free(); _inv = null
	if _paperdoll != null:
		_paperdoll.queue_free(); _paperdoll = null
	for c in _slider_box.get_children():
		c.queue_free()
	_slider_entries.clear()
	var cls: Dictionary = CLASSES[_class_idx]
	var variant: Dictionary = cls["variants"][_variant_idx]
	# Populate stance ids for this class's weapon catalog.
	_stance_ids = []
	var catalog: StringName = STANCE_CATALOGS.get(cls["id"], &"")
	if catalog == &"bow":
		_stance_ids = BowStances.all_ids()
	elif catalog == &"staff":
		_stance_ids = StaffStances.all_ids()
	elif catalog == &"spear":
		_stance_ids = SpearStances.all_ids()
	if _stance_idx >= _stance_ids.size():
		_stance_idx = 0
	var stance_label: String = "—"
	if _stance_ids.size() > 0:
		stance_label = "%s (%d/%d)" % [_stance_ids[_stance_idx], _stance_idx + 1, _stance_ids.size()]
	_label_class.text = "Class: %s   Stance: %s" % [cls["id"], stance_label]
	_label_variant.text = "Variant: %s" % variant["name"]
	# Instantiate
	var scene: PackedScene = load(cls["scene"]) as PackedScene
	if scene == null:
		_label_class.text += " (scene missing)"
		return
	var stats := Stats.new()
	stats.class_id = cls["id"]
	_inv = Inventory.new()
	_inv.class_id = cls["id"]
	_inv.stats = stats
	add_child(_inv)
	_sprite = scene.instantiate() as Node2D
	# Apply selected stance BEFORE add_child so the sprite's _ready
	# picks it up. The sprite exposes stance_id as @export var.
	if _stance_ids.size() > 0 and &"stance_id" in _sprite:
		_sprite.stance_id = _stance_ids[_stance_idx]
	# IK starts OFF on a fresh load (sprite paused → tuning mode).
	# Pressing Space flips both at once via _apply_auto_ik.
	if &"ik_enabled" in _sprite:
		_sprite.ik_enabled = false
	_ik_disabled = true
	_paused = true
	_sprite.position = FEET_POS
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_vp.add_child(_sprite)
	_paperdoll = EquipmentPaperdoll.new()
	add_child(_paperdoll)
	_paperdoll.bind(_sprite, _inv, cls["id"])
	for slot in ["weapon", "offhand", "head", "chest", "legs"]:
		if variant["equip"].has(slot):
			_inv.add_item(variant["equip"][slot])
			_inv.equip(variant["equip"][slot])
	await get_tree().process_frame
	_anim = _sprite.get_node(^"AnimationPlayer") as AnimationPlayer
	_anim.play(variant["anim"])
	_paused = true
	_anim.pause()
	var length: float = _anim.current_animation_length
	_time_slider.max_value = max(length, 0.01)
	_time_slider.value = 0.0
	_scrub_time = 0.0
	_anim.seek(0.0, true)
	_label_time.text = "Time: 0.00s / %.2fs" % length
	_spawn_drag_dots()
	_build_sliders()

# =========================================================================
# Slider construction
# =========================================================================
# Walk the sprite tree and create:
#   - rotation slider for each Node2D whose name ends in "Pivot",
#     "Shoulder", or "StaffArm" / "SpearArm" / "BowArm"
#   - position (x,y) sliders for each Marker2D

## After the sprite is in the tree, drop a small colored disc on each
## draggable (Marker2D + *Arm) so the user can SEE the hit-target.
## Discs are children of the draggable so they track its motion. They
## render in viewport coords; SPRITE_SCALE is applied via parent.
func _spawn_drag_dots() -> void:
	for n in _enumerate_draggables(_sprite):
		if n.has_node(^"_DragDot"):
			continue
		var dot := Polygon2D.new()
		dot.name = "_DragDot"
		dot.color = DRAG_DOT_COLOR
		dot.z_index = 100
		# Dot radius is in PARENT-local units, so divide by sprite scale
		# to render a screen-constant size regardless of zoom. With
		# SPRITE_SCALE=3 a screen radius of DRAG_DOT_RADIUS=3.5 maps to
		# ~1.17 local units — but the dot's parent is BowArm/Marker which
		# is NOT scaled itself; only the sprite root is. So local units
		# need to be tiny.
		var r: float = DRAG_DOT_RADIUS / SPRITE_SCALE
		var pts: PackedVector2Array = []
		for i in 12:
			var t: float = TAU * i / 12
			pts.append(Vector2(r * cos(t), r * sin(t)))
		dot.polygon = pts
		n.add_child(dot)

func _build_sliders() -> void:
	# Pin arm + weapon-arm sliders at the top so the user doesn't have
	# to scroll past legs to reach them.
	var header := Label.new()
	header.text = "── arms + weapon ──"
	_slider_box.add_child(header)
	_walk_for_sliders_filtered(_sprite, "", true)
	var sep := Label.new()
	sep.text = "── everything else ──"
	_slider_box.add_child(sep)
	_walk_for_sliders_filtered(_sprite, "", false)

# Two-pass walk. When `arms_only` is true, we add sliders ONLY for arm
# chain nodes (shoulders, elbows under the arms, weapon-arm subtrees +
# their markers). When false, we add sliders for everything ELSE.
func _walk_for_sliders_filtered(node: Node, prefix: String,
		arms_only: bool) -> void:
	for child in node.get_children():
		var path: String = (prefix + "/" + String(child.name)) if prefix != "" else String(child.name)
		var in_arm: bool = path.contains("Shoulder") or path.contains("BowArm") \
				or path.contains("StaffArm") or path.contains("SpearArm")
		var should_add: bool = in_arm if arms_only else not in_arm
		if should_add:
			if child is Marker2D:
				_add_marker_sliders(child, path)
			elif child is Node2D and _wants_rotation_slider(child.name):
				_add_rotation_slider(child, path)
				if _wants_position_slider(child.name):
					_add_arm_position_sliders(child, path)
		_walk_for_sliders_filtered(child, path, arms_only)

func _walk_for_sliders(node: Node, prefix: String) -> void:
	for child in node.get_children():
		var path: String = (prefix + "/" + String(child.name)) if prefix != "" else String(child.name)
		if child is Marker2D:
			_add_marker_sliders(child, path)
		elif child is Node2D and _wants_rotation_slider(child.name):
			_add_rotation_slider(child, path)
			if _wants_position_slider(child.name):
				_add_arm_position_sliders(child, path)
		_walk_for_sliders(child, path)

func _wants_rotation_slider(n: StringName) -> bool:
	var s := String(n)
	return s.ends_with("Pivot") or s.ends_with("Shoulder") \
			or s.ends_with("StaffArm") or s.ends_with("SpearArm") \
			or s.ends_with("BowArm")

# Position sliders go on the *Arm parent nodes (BowArm/StaffArm/
# SpearArm) so the user can drag the weapon forward/back/up/down
# without editing the .tscn. Marker2Ds already get position sliders.
func _wants_position_slider(n: StringName) -> bool:
	var s := String(n)
	return s.ends_with("StaffArm") or s.ends_with("SpearArm") \
			or s.ends_with("BowArm")

func _add_rotation_slider(n: Node2D, path: String) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = "%s.rot°" % path
	label.custom_minimum_size = Vector2(180, 0)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider_box.add_child(label)
	_slider_box.add_child(row)
	var s := HSlider.new()
	s.min_value = -180.0
	s.max_value = 180.0
	s.step = 0.5
	s.value = rad_to_deg(n.rotation)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(s)
	# Editable numeric input synced with the slider — type exact values.
	var box := SpinBox.new()
	box.min_value = -180.0
	box.max_value = 180.0
	box.step = 0.5
	box.value = rad_to_deg(n.rotation)
	box.custom_minimum_size = Vector2(70, 0)
	row.add_child(box)
	s.value_changed.connect(func(v):
		n.rotation = deg_to_rad(v)
		box.set_value_no_signal(v))
	box.value_changed.connect(func(v):
		n.rotation = deg_to_rad(v)
		s.set_value_no_signal(v))
	_slider_entries.append({ "kind": "rot", "path": path, "controls": [s] })

func _add_arm_position_sliders(n: Node2D, path: String) -> void:
	_add_xy_pair("%s.pos" % path, n, Vector2(-50, -70), Vector2(50, 20), 0.5, path)

func _add_xy_pair(label_text: String, n: Node2D,
		mins: Vector2, maxs: Vector2, step: float, entry_path: String) -> void:
	var label := Label.new()
	label.text = label_text
	_slider_box.add_child(label)
	var sx := HSlider.new()
	sx.min_value = mins.x; sx.max_value = maxs.x; sx.step = step
	sx.value = n.position.x
	sx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bx := SpinBox.new()
	bx.min_value = mins.x; bx.max_value = maxs.x; bx.step = step
	bx.value = n.position.x
	bx.custom_minimum_size = Vector2(70, 0)
	var rx := HBoxContainer.new()
	rx.add_child(sx); rx.add_child(bx)
	_slider_box.add_child(rx)
	sx.value_changed.connect(func(v):
		n.position.x = v
		bx.set_value_no_signal(v))
	bx.value_changed.connect(func(v):
		n.position.x = v
		sx.set_value_no_signal(v))
	var sy := HSlider.new()
	sy.min_value = mins.y; sy.max_value = maxs.y; sy.step = step
	sy.value = n.position.y
	sy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var by := SpinBox.new()
	by.min_value = mins.y; by.max_value = maxs.y; by.step = step
	by.value = n.position.y
	by.custom_minimum_size = Vector2(70, 0)
	var ry := HBoxContainer.new()
	ry.add_child(sy); ry.add_child(by)
	_slider_box.add_child(ry)
	sy.value_changed.connect(func(v):
		n.position.y = v
		by.set_value_no_signal(v))
	by.value_changed.connect(func(v):
		n.position.y = v
		sy.set_value_no_signal(v))
	_slider_entries.append({ "kind": "pos", "path": entry_path, "controls": [sx, sy] })

func _add_marker_sliders(m: Marker2D, path: String) -> void:
	_add_xy_pair("%s.pos" % path, m, Vector2(-60, -60), Vector2(60, 60), 0.1, path)

# =========================================================================
# Time scrubbing
# =========================================================================

func _on_time_changed(v: float) -> void:
	_scrub_time = v
	if _anim != null:
		_anim.seek(v, true)
	_label_time.text = "Time: %.2fs / %.2fs    Phase: %s" % [
			v, _anim.current_animation_length, String(_current_phase())]

func _on_play_toggle() -> void:
	if _anim == null:
		return
	_paused = not _paused
	if _paused:
		_anim.pause()
	else:
		_anim.play()
	# IK follows play state: ON when running (so the hand sticks to the
	# weapon during the swing), OFF when paused (so the sidebar sliders
	# can actually move shoulders/elbows without being overwritten).
	_apply_auto_ik()

func _process(_delta: float) -> void:
	# When playing, sync the time slider to anim time so the scrubber
	# tracks playback. Disable the value_changed reentrancy by setting
	# value directly (Godot won't re-emit for same value).
	if _anim != null and not _paused:
		var t: float = _anim.current_animation_position
		_time_slider.set_value_no_signal(t)
		_label_time.text = "Time: %.2fs / %.2fs" % [t, _anim.current_animation_length]

# =========================================================================
# Pose dump
# =========================================================================

func _on_dump_pressed() -> void:
	var cls: Dictionary = CLASSES[_class_idx]
	var variant: Dictionary = cls["variants"][_variant_idx]
	var lines: Array[String] = []
	lines.append("# Pose dump — %s / %s @ t=%.3fs" % [cls["id"], variant["name"], _scrub_time])
	lines.append("# Paste into test/sprite_specs.gd as a keyframe entry:")
	lines.append("{")
	lines.append("\t\"t\": %.3f," % _scrub_time)
	lines.append("\t\"phase\": &\"REST\",")
	# Pose-spec keyframes use sprite-local hand/elbow positions, not raw
	# rotations. Pull centroids from the live tree the same way the
	# sprite_render verifier does.
	var body: Node2D = _sprite.get_node_or_null(^"Body") as Node2D
	if body != null:
		_dump_centroid(lines, body, ^"ArmRShoulder/ElbowPivot/Hand", "right_hand")
		_dump_centroid(lines, body, ^"ArmLShoulder/ElbowPivot/Hand", "left_hand")
		_dump_centroid(lines, body, ^"ArmRShoulder/ElbowPivot", "right_elbow")
		_dump_centroid(lines, body, ^"ArmLShoulder/ElbowPivot", "left_elbow")
	lines.append("\t\"tolerance_px\": 4.0,")
	lines.append("},")
	# Also dump raw slider values for replay / weapon_profiles tuning.
	lines.append("")
	lines.append("# Raw slider values (rotations in radians, positions in sprite-local px):")
	for entry in _slider_entries:
		if entry["kind"] == "rot":
			var v_deg: float = entry["controls"][0].value
			lines.append("#   %s.rotation = %.4f  # (%.1f°)" % [
				entry["path"], deg_to_rad(v_deg), v_deg])
		else:
			lines.append("#   %s.position  = Vector2(%.2f, %.2f)" % [
				entry["path"], entry["controls"][0].value, entry["controls"][1].value])
	var text := "\n".join(lines)
	print(text)
	# Persist for paste.
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var f := FileAccess.open("res://tmp/pose_dump.txt", FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()
		print("[pose_tuner] wrote res://tmp/pose_dump.txt")

func _dump_centroid(lines: Array[String], body: Node2D,
		rel_path: NodePath, label: String) -> void:
	var node: Node2D = body.get_node_or_null(rel_path) as Node2D
	if node == null:
		return
	var p: Vector2 = Vector2.ZERO
	if node is Polygon2D and (node as Polygon2D).polygon.size() > 0:
		var poly: PackedVector2Array = (node as Polygon2D).polygon
		for v in poly:
			p += v
		p /= float(poly.size())
		p = body.to_local((node as Polygon2D).to_global(p))
	else:
		p = body.to_local(node.global_position)
	lines.append("\t\"%s\": Vector2(%.1f, %.1f)," % [label, p.x, p.y])

func _on_reset_pressed() -> void:
	_load_current()

# =========================================================================
# Click + drag handles
# =========================================================================
# Mouse events on the SubViewportContainer come in as gui_input. The
# container's stretch is off + size = VIEW_SIZE, so mouse position in
# container space == pixel in the SubViewport. Sprite is at FEET_POS
# with scale SPRITE_SCALE, so any draggable's screen pixel can be
# checked against the cursor with simple linear math.
#
# Two kinds of draggable nodes:
#   - Marker2D (NockMarker, RiserMarker, BowTipTop/Bot, LeftGripMarker,
#     etc.) — child of the weapon-arm subtree. Drag updates the
#     marker's position in its parent's local space.
#   - BowArm / StaffArm / SpearArm itself — drag updates its position
#     in Body-local space (so its children move with it).

const DRAG_HIT_RADIUS: float = 18.0
const DRAG_DOT_COLOR := Color(1.0, 0.7, 0.1, 0.9)
const DRAG_DOT_RADIUS: float = 3.5

func _on_viewport_input(event: InputEvent) -> void:
	if _sprite == null:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_drag_node = _find_draggable_under(mb.position)
			_drag_last_mouse = mb.position
		else:
			_drag_node = null
	elif event is InputEventMouseMotion and _drag_node != null:
		var mm: InputEventMouseMotion = event
		var delta_screen: Vector2 = mm.position - _drag_last_mouse
		_drag_last_mouse = mm.position
		# Convert screen delta → parent-local delta. SubViewport is at
		# 1:1 with container, so screen delta divided by sprite scale
		# gives sprite-local delta. We're modifying position in PARENT
		# local space — if BowArm rotation = 0 and Body rotation = 0,
		# parent-local == sprite-local. Rotation handling deferred.
		var local_delta: Vector2 = delta_screen / SPRITE_SCALE
		_drag_node.position += local_delta
		_sync_sliders_for(_drag_node)
		# Force a one-shot IK pass so arms visibly follow the dragged
		# marker even when ik_enabled is false. Otherwise dragging a
		# RiserMarker / NockMarker looks like nothing happens.
		_force_pin_pass()

func _force_pin_pass() -> void:
	if _sprite == null:
		return
	var pins = _sprite.get(&"PIN_TABLE") if &"PIN_TABLE" in _sprite else null
	if pins == null:
		return
	var body: Node2D = _sprite.get_node_or_null(^"Body") as Node2D
	var cur_anim: StringName = _anim.current_animation if _anim != null else &""
	HumanRig.apply_pins(_sprite, body, pins, cur_anim)

# Find the closest draggable (Marker2D or *Arm Node2D) within
# DRAG_HIT_RADIUS of mouse_pos (in container/viewport coords).
func _find_draggable_under(mouse_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d: float = DRAG_HIT_RADIUS
	for n in _enumerate_draggables(_sprite):
		var d: float = mouse_pos.distance_to(n.global_position)
		if d < best_d:
			best_d = d
			best = n
	return best

# Walk the sprite tree collecting Markers + *Arm Node2Ds.
func _enumerate_draggables(root: Node) -> Array:
	var out: Array = []
	for child in root.get_children():
		if child is Marker2D:
			out.append(child)
		elif child is Node2D:
			var n: String = String(child.name)
			if n.ends_with("BowArm") or n.ends_with("StaffArm") or n.ends_with("SpearArm"):
				out.append(child)
		out.append_array(_enumerate_draggables(child))
	return out

# After a drag, find the matching slider entry and sync slider+SpinBox
# values so the sidebar reflects the new position.
func _sync_sliders_for(n: Node2D) -> void:
	var target_path: String = _path_for(n)
	for entry in _slider_entries:
		if entry["kind"] == "pos" and entry["path"] == target_path:
			var controls: Array = entry["controls"]
			# controls[0] is the X HSlider; we don't have the SpinBox
			# refs here so this only updates the slider — SpinBox
			# refresh would require expanding the entry schema. For
			# now slider sync is enough to indicate the value changed.
			if controls.size() >= 1:
				controls[0].set_value_no_signal(n.position.x)
			if controls.size() >= 2:
				controls[1].set_value_no_signal(n.position.y)
			return

func _path_for(n: Node) -> String:
	# Build the same '/'-joined path used when sliders were created.
	var parts: Array[String] = []
	var cur: Node = n
	while cur != null and cur != _sprite:
		parts.append(String(cur.name))
		cur = cur.get_parent()
	parts.reverse()
	return "/".join(parts)

func _on_ik_toggled(pressed: bool) -> void:
	# Manual override. When the user explicitly toggles, we respect
	# their choice and break the auto-pair-with-play behavior until the
	# next play/pause action.
	_ik_disabled = pressed
	if _sprite != null and &"ik_enabled" in _sprite:
		_sprite.ik_enabled = not pressed
	if pressed and _anim != null:
		_anim.pause()
		_paused = true

func _apply_auto_ik() -> void:
	# IK on while playing, off while paused — so the weapon stays in
	# the hand during the swing, but sliders work the moment the user
	# pauses to tune.
	if _sprite == null or not (&"ik_enabled" in _sprite):
		return
	_sprite.ik_enabled = not _paused
	_ik_disabled = _paused

# Stage 17.8 — score the CURRENT (stance, variant_anim, phase) on a
# 1-5 scale. Writes/merges into tmp/stance_scores.json so future agent
# runs can bias toward high-scored entries. Phase is derived from the
# current scrub time: REST at boundaries, STRIKE/CHARGE in the
# middle (variant-anim dependent — uses a coarse t/length banding).
func _score_current(score: int) -> void:
	if _stance_ids.size() == 0:
		print("[pose_tuner] no stance catalog for current class; score ignored")
		return
	var stance_id: StringName = _stance_ids[_stance_idx]
	var cls: Dictionary = CLASSES[_class_idx]
	var variant: Dictionary = cls["variants"][_variant_idx]
	var phase: StringName = _current_phase()
	var key: String = "%s/%s/%s" % [stance_id, variant["name"], phase]
	# Load existing.
	var scores: Dictionary = {}
	var f := FileAccess.open("res://tmp/stance_scores.json", FileAccess.READ)
	if f != null:
		var txt: String = f.get_as_text()
		f.close()
		var parsed: Variant = JSON.parse_string(txt)
		if typeof(parsed) == TYPE_DICTIONARY:
			scores = parsed
	scores[key] = {
		"score": score,
		"class": String(cls["id"]),
		"stance": String(stance_id),
		"variant": String(variant["name"]),
		"phase": String(phase),
		"t": _scrub_time,
		"timestamp": Time.get_datetime_string_from_system(),
	}
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var w := FileAccess.open("res://tmp/stance_scores.json", FileAccess.WRITE)
	if w != null:
		w.store_string(JSON.stringify(scores, "  "))
		w.close()
	print("[pose_tuner] scored %s = %d" % [key, score])
	if _label_score != null:
		_label_score.text = "Phase: %s     Last: %s = %d" % [
				String(phase), key, score]

# Stage 17.8 — write the CURRENT BowArm/StaffArm/SpearArm placement
# + animated Marker2D positions into tmp/recommended_stances.json so
# the sprite consumes the user's tweaks at next _ready. Keyed by
# class/stance/phase so REST captures bow_arm_pos + nock_rest, and
# STRIKE captures nock_drawn. Sprite layer merges with catalog
# defaults: any field present in recommended_stances wins.
func _save_recommended() -> void:
	if _sprite == null:
		return
	var cls: Dictionary = CLASSES[_class_idx]
	var stance_label: String = "default"
	if _stance_ids.size() > 0:
		stance_label = String(_stance_ids[_stance_idx])
	var phase: StringName = _current_phase()
	# Save key includes the ANIMATION NAME (idle/walk/attack) so each
	# variant gets its own slot — idle has a different bow placement
	# than attack-rest, etc. Empty anim falls back to "global".
	var anim_name: String = "global"
	if _anim != null and _anim.current_animation != &"":
		anim_name = String(_anim.current_animation)
	# Discover the weapon-arm node (BowArm/StaffArm/SpearArm) and its
	# tunable marker children. We dump whatever is present so the file
	# is self-describing.
	var snap: Dictionary = {}
	var weapon_arm: Node2D = _find_weapon_arm(_sprite)
	if weapon_arm != null:
		snap["weapon_arm_pos"] = [weapon_arm.position.x, weapon_arm.position.y]
		snap["weapon_arm_rot"] = weapon_arm.rotation
		for child in weapon_arm.get_children():
			if child is Marker2D:
				snap[String(child.name)] = [child.position.x, child.position.y]
	# Load existing file if present, merge our entry, write back.
	var recommended: Dictionary = {}
	var f := FileAccess.open("res://tmp/recommended_stances.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		f.close()
		if typeof(parsed) == TYPE_DICTIONARY:
			recommended = parsed
	var class_key: String = String(cls["id"])
	if not recommended.has(class_key):
		recommended[class_key] = {}
	if not recommended[class_key].has(stance_label):
		recommended[class_key][stance_label] = {}
	if not recommended[class_key][stance_label].has(anim_name):
		recommended[class_key][stance_label][anim_name] = {}
	recommended[class_key][stance_label][anim_name][String(phase)] = snap
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var w := FileAccess.open("res://tmp/recommended_stances.json", FileAccess.WRITE)
	if w != null:
		w.store_string(JSON.stringify(recommended, "  "))
		w.close()
	var msg: String = "saved %s/%s/%s/%s" % [class_key, stance_label, anim_name, String(phase)]
	print("[pose_tuner] %s" % msg)
	if _label_score != null:
		_label_score.text = "Recommended " + msg

# Walk the sprite tree looking for the first Node2D whose name ends in
# StaffArm/SpearArm/BowArm — the weapon-arm convention used by all
# class sprites.
func _find_weapon_arm(root: Node) -> Node2D:
	for child in root.get_children():
		var s: String = String(child.name)
		if child is Node2D and (s.ends_with("BowArm") or s.ends_with("StaffArm") or s.ends_with("SpearArm")):
			return child
		var nested: Node2D = _find_weapon_arm(child)
		if nested != null:
			return nested
	return null

# Coarse phase classification by scrub time. Animation-specific —
# attack splits into REST/CHARGE/STRIKE/RECOVERY; idle/walk are REST.
func _current_phase() -> StringName:
	if _anim == null:
		return &"REST"
	var length: float = _anim.current_animation_length
	if length <= 0.01:
		return &"REST"
	var anim_name: StringName = _anim.current_animation
	if anim_name != &"attack":
		return &"REST"
	var f: float = _scrub_time / length
	if f < 0.10:    return &"REST"
	if f < 0.45:    return &"CHARGE"
	if f < 0.75:    return &"STRIKE"
	if f < 0.95:    return &"RECOVERY"
	return &"REST"

# =========================================================================
# Hotkeys
# =========================================================================

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_F1:
			_class_idx = (_class_idx + 1) % CLASSES.size()
			_variant_idx = 0
			_load_current()
		KEY_F2:
			var n: int = CLASSES[_class_idx]["variants"].size()
			_variant_idx = (_variant_idx + 1) % n
			_load_current()
		KEY_F3:
			if _stance_ids.size() > 0:
				_stance_idx = (_stance_idx + 1) % _stance_ids.size()
				_load_current()
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			_score_current(event.keycode - KEY_0)
		KEY_S:
			_save_recommended()
		KEY_D:
			_on_dump_pressed()
		KEY_SPACE:
			_on_play_toggle()
		KEY_R:
			_on_reset_pressed()
