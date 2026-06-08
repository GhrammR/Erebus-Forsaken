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
##   D        — dump current pose to console + tmp/pose_dump.txt as
##              keyframe Dictionary ready to paste into sprite_specs.gd
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

# State.
var _class_idx: int = 0
var _variant_idx: int = 0
var _vp: SubViewport
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
	var hint := Label.new()
	hint.text = "F1 next class · F2 next variant"
	side.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(scroll)
	_slider_box = VBoxContainer.new()
	_slider_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_slider_box)
	# Viewport pane
	var vp_container := SubViewportContainer.new()
	vp_container.stretch = true
	vp_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vp_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(vp_container)
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
	_label_class.text = "Class: %s" % cls["id"]
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
	_build_sliders()

# =========================================================================
# Slider construction
# =========================================================================
# Walk the sprite tree and create:
#   - rotation slider for each Node2D whose name ends in "Pivot",
#     "Shoulder", or "StaffArm" / "SpearArm" / "BowArm"
#   - position (x,y) sliders for each Marker2D

func _build_sliders() -> void:
	_walk_for_sliders(_sprite, "")

func _walk_for_sliders(node: Node, prefix: String) -> void:
	for child in node.get_children():
		var path: String = (prefix + "/" + String(child.name)) if prefix != "" else String(child.name)
		if child is Marker2D:
			_add_marker_sliders(child, path)
		elif child is Node2D and _wants_rotation_slider(child.name):
			_add_rotation_slider(child, path)
		_walk_for_sliders(child, path)

func _wants_rotation_slider(n: StringName) -> bool:
	var s := String(n)
	return s.ends_with("Pivot") or s.ends_with("Shoulder") \
			or s.ends_with("StaffArm") or s.ends_with("SpearArm") \
			or s.ends_with("BowArm")

func _add_rotation_slider(n: Node2D, path: String) -> void:
	var label := Label.new()
	label.text = "%s.rot°" % path
	_slider_box.add_child(label)
	var s := HSlider.new()
	s.min_value = -180.0
	s.max_value = 180.0
	s.step = 0.5
	s.value = rad_to_deg(n.rotation)
	s.value_changed.connect(func(v): n.rotation = deg_to_rad(v))
	_slider_box.add_child(s)
	_slider_entries.append({ "kind": "rot", "path": path, "controls": [s] })

func _add_marker_sliders(m: Marker2D, path: String) -> void:
	var label := Label.new()
	label.text = "%s.pos" % path
	_slider_box.add_child(label)
	var sx := HSlider.new()
	sx.min_value = -60.0; sx.max_value = 60.0; sx.step = 0.1
	sx.value = m.position.x
	sx.value_changed.connect(func(v): m.position.x = v)
	_slider_box.add_child(sx)
	var sy := HSlider.new()
	sy.min_value = -60.0; sy.max_value = 60.0; sy.step = 0.1
	sy.value = m.position.y
	sy.value_changed.connect(func(v): m.position.y = v)
	_slider_box.add_child(sy)
	_slider_entries.append({ "kind": "pos", "path": path, "controls": [sx, sy] })

# =========================================================================
# Time scrubbing
# =========================================================================

func _on_time_changed(v: float) -> void:
	_scrub_time = v
	if _anim != null:
		_anim.seek(v, true)
	_label_time.text = "Time: %.2fs / %.2fs" % [v, _anim.current_animation_length]

func _on_play_toggle() -> void:
	if _anim == null:
		return
	_paused = not _paused
	if _paused:
		_anim.pause()
	else:
		_anim.play()

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
		KEY_D:
			_on_dump_pressed()
		KEY_SPACE:
			_on_play_toggle()
		KEY_R:
			_on_reset_pressed()
