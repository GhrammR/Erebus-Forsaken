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
## Editor background z. Must be below the most-negative sprite part z so
## chrome never occludes sprite content (the legs-behind-bg bug). Sprite
## parts live around z -1..+100; -100 keeps the BG safely behind all.
const BG_Z: int = -100

# Class catalog — id, scene path, available variants.
# Variants are {name, anim, equip} — equip drives WeaponProfiles like
# sprite_render does.
const CLASSES: Array = [
	{
		"id": &"pythia",
		"bucket": &"classes",
		"scene": "res://art/procedural/classes/pythia_sprite.tscn",
		"variants": [
			{ "name": "Idle", "anim": &"idle", "equip": { "weapon": &"pythia_staff_starter" }, "show_staff": true },
			{ "name": "Walk", "anim": &"walk", "equip": { "weapon": &"pythia_staff_starter" }, "show_staff": true },
			{ "name": "Attack", "anim": &"attack", "equip": { "weapon": &"pythia_staff_starter" }, "show_staff": true },
			{ "name": "Cast", "anim": &"cast", "equip": { "weapon": &"pythia_staff_starter" }, "show_staff": true },
			{ "name": "Death", "anim": &"die", "equip": { "weapon": &"pythia_staff_starter" }, "show_staff": true },
			{ "name": "Idle Unarmed", "anim": &"idle", "equip": {}, "show_staff": false, "unarmed": true },
			{ "name": "Walk Unarmed", "anim": &"walk", "equip": {}, "show_staff": false, "unarmed": true },
			{ "name": "Strike Unarmed", "anim": &"attack", "equip": {}, "show_staff": false, "unarmed": true },
			{ "name": "Cast Unarmed", "anim": &"cast", "equip": {}, "show_staff": false, "unarmed": true },
			{ "name": "Dying Unarmed", "anim": &"die", "equip": {}, "show_staff": false, "unarmed": true },
		],
	},
	{
		"id": &"myrmidon",
		"bucket": &"classes",
		"scene": "res://art/procedural/classes/myrmidon_sprite.tscn",
		"variants": [
			{ "name": "Idle", "anim": &"idle", "equip": { "weapon": &"myrmidon_spear_starter" }, "show_spear": true },
			{ "name": "Walk", "anim": &"walk", "equip": { "weapon": &"myrmidon_spear_starter" }, "show_spear": true },
			{ "name": "Attack", "anim": &"attack", "equip": { "weapon": &"myrmidon_spear_starter" }, "show_spear": true },
			{ "name": "Cast", "anim": &"cast", "equip": { "weapon": &"myrmidon_spear_starter" }, "show_spear": true },
			{ "name": "Death", "anim": &"die", "equip": { "weapon": &"myrmidon_spear_starter" }, "show_spear": true },
			{ "name": "Idle Unarmed", "anim": &"idle", "equip": {}, "show_spear": false, "unarmed": true },
			{ "name": "Walk Unarmed", "anim": &"walk", "equip": {}, "show_spear": false, "unarmed": true },
			{ "name": "Strike Unarmed", "anim": &"attack", "equip": {}, "show_spear": false, "unarmed": true },
			{ "name": "Cast Unarmed", "anim": &"cast", "equip": {}, "show_spear": false, "unarmed": true },
			{ "name": "Dying Unarmed", "anim": &"die", "equip": {}, "show_spear": false, "unarmed": true },
		],
	},
	{
		"id": &"shade_hunter",
		"bucket": &"classes",
		"scene": "res://art/procedural/classes/shade_hunter_sprite.tscn",
		"variants": [
			{ "name": "Idle", "anim": &"idle", "equip": {}, "show_bow": true },
			{ "name": "Walk", "anim": &"walk", "equip": {}, "show_bow": true },
			{ "name": "Attack", "anim": &"attack", "equip": {}, "show_bow": true },
			{ "name": "Cast", "anim": &"cast", "equip": {}, "show_bow": true },
			{ "name": "Death", "anim": &"die", "equip": {}, "show_bow": true },
			{ "name": "Idle Unarmed", "anim": &"idle", "equip": {}, "show_bow": false, "unarmed": true },
			{ "name": "Walk Unarmed", "anim": &"walk", "equip": {}, "show_bow": false, "unarmed": true },
			{ "name": "Strike Unarmed", "anim": &"attack", "equip": {}, "show_bow": false, "unarmed": true },
			{ "name": "Cast Unarmed", "anim": &"cast", "equip": {}, "show_bow": false, "unarmed": true },
			{ "name": "Dying Unarmed", "anim": &"die", "equip": {}, "show_bow": false, "unarmed": true },
		],
	},
	{
		"id": &"ossuary_priest",
		"bucket": &"classes",
		"scene": "res://art/procedural/classes/ossuary_priest_sprite.tscn",
		"variants": [
			{ "name": "Idle", "anim": &"idle", "equip": { "weapon": &"ossuary_wand_starter" }, "show_wand": true },
			{ "name": "Walk", "anim": &"walk", "equip": { "weapon": &"ossuary_wand_starter" }, "show_wand": true },
			{ "name": "Attack", "anim": &"attack", "equip": { "weapon": &"ossuary_wand_starter" }, "show_wand": true },
			{ "name": "Cast", "anim": &"cast", "equip": { "weapon": &"ossuary_wand_starter" }, "show_wand": true },
			{ "name": "Death", "anim": &"die", "equip": { "weapon": &"ossuary_wand_starter" }, "show_wand": true },
			{ "name": "Idle Unarmed", "anim": &"idle", "equip": {}, "show_wand": false, "unarmed": true },
			{ "name": "Walk Unarmed", "anim": &"walk", "equip": {}, "show_wand": false, "unarmed": true },
			{ "name": "Strike Unarmed", "anim": &"attack", "equip": {}, "show_wand": false, "unarmed": true },
			{ "name": "Cast Unarmed", "anim": &"cast", "equip": {}, "show_wand": false, "unarmed": true },
			{ "name": "Dying Unarmed", "anim": &"die", "equip": {}, "show_wand": false, "unarmed": true },
		],
	},
	{
		"id": &"training_dummy",
		"bucket": &"enemies",
		"scene": "res://art/procedural/enemies/dummy_sprite.tscn",
		"variants": [
			{ "name": "Idle", "anim": &"idle", "equip": {} },
			{ "name": "Walk", "anim": &"walk", "equip": {} },
			{ "name": "Attack", "anim": &"attack", "equip": {} },
			{ "name": "Cast", "anim": &"cast", "equip": {} },
			{ "name": "Death", "anim": &"die", "equip": {} },
		],
	},
	{
		"id": &"bone_servant",
		"bucket": &"enemies",
		"scene": "res://art/procedural/enemies/bone_servant_sprite.tscn",
		"variants": [
			{ "name": "Idle", "anim": &"idle", "equip": {} },
			{ "name": "Walk", "anim": &"walk", "equip": {} },
			{ "name": "Rake", "anim": &"attack", "equip": {} },
			{ "name": "Shiver", "anim": &"cast", "equip": {} },
			{ "name": "Scatter", "anim": &"die", "equip": {} },
		],
	},
	{
		"id": &"shade_wretch",
		"bucket": &"enemies",
		"scene": "res://art/procedural/enemies/shade_wretch_sprite.tscn",
		"variants": [
			{ "name": "Hover", "anim": &"idle", "equip": {} },
			{ "name": "Drift", "anim": &"walk", "equip": {} },
			{ "name": "Lunge", "anim": &"attack", "equip": {} },
			# Shade Wretch is a melee clawed wraith — it does not cast,
			# so there is no cast pose to tune (was the stray "Chill").
			{ "name": "Dissolve", "anim": &"die", "equip": {} },
		],
	},
	{
		"id": &"bog_caller",
		"bucket": &"enemies",
		"scene": "res://art/procedural/enemies/bog_caller_sprite.tscn",
		"variants": [
			{ "name": "Hover", "anim": &"idle", "equip": {} },
			{ "name": "Drift", "anim": &"walk", "equip": {} },
			{ "name": "Spit", "anim": &"attack", "equip": {} },
			{ "name": "Channel", "anim": &"cast", "equip": {} },
			{ "name": "Collapse", "anim": &"die", "equip": {} },
		],
	},
	{
		"id": &"act_boss",
		"bucket": &"enemies",
		"scene": "res://art/procedural/enemies/act_boss_sprite.tscn",
		"variants": [
			{ "name": "Breathe", "anim": &"idle", "equip": {} },
			{ "name": "Stalk", "anim": &"walk", "equip": {} },
			{ "name": "Smite", "anim": &"attack", "equip": {} },
			{ "name": "Taunt", "anim": &"cast", "equip": {} },
			{ "name": "Slump", "anim": &"die", "equip": {} },
		],
	},
	{
		"id": &"revenant",
		"bucket": &"enemies",
		"scene": "res://art/procedural/enemies/revenant_sprite.tscn",
		"variants": [
			{ "name": "Idle", "anim": &"idle", "equip": {} },
			{ "name": "Walk", "anim": &"walk", "equip": {} },
			{ "name": "Attack", "anim": &"attack", "equip": {} },
			{ "name": "Cast", "anim": &"cast", "equip": {} },
			{ "name": "Death", "anim": &"die", "equip": {} },
		],
	},
	{
		"id": &"fiend",
		"bucket": &"enemies",
		"scene": "res://art/procedural/enemies/fiend_sprite.tscn",
		"variants": [
			{ "name": "Idle", "anim": &"idle", "equip": {} },
			{ "name": "Walk", "anim": &"walk", "equip": {} },
			{ "name": "Attack", "anim": &"attack", "equip": {} },
			{ "name": "Cast", "anim": &"cast", "equip": {} },
			{ "name": "Death", "anim": &"die", "equip": {} },
		],
	},
	{
		"id": &"bronze_sentinel",
		"bucket": &"enemies",
		"scene": "res://art/procedural/enemies/sentinel_sprite.tscn",
		"variants": [
			{ "name": "Idle", "anim": &"idle", "equip": {} },
			{ "name": "Walk", "anim": &"walk", "equip": {} },
			{ "name": "Slam", "anim": &"attack", "equip": {} },
			{ "name": "Charge", "anim": &"cast", "equip": {} },
			{ "name": "Topple", "anim": &"die", "equip": {} },
		],
	},
	{
		"id": &"kallias",
		"bucket": &"npcs",
		"scene": "res://art/procedural/npcs/kallias_sprite.tscn",
		"variants": [
			{ "name": "Idle", "anim": &"idle", "equip": {} },
			{ "name": "Walk", "anim": &"walk", "equip": {} },
			{ "name": "Panic", "anim": &"attack", "equip": {} },
			{ "name": "Gesture", "anim": &"cast", "equip": {} },
			{ "name": "Fall", "anim": &"die", "equip": {} },
		],
	},
	{
		"id": &"eurynome",
		"bucket": &"npcs",
		"scene": "res://art/procedural/npcs/eurynome_sprite.tscn",
		"variants": [
			{ "name": "Vigil", "anim": &"idle", "equip": {} },
			{ "name": "Step", "anim": &"walk", "equip": {} },
			{ "name": "Rebuke", "anim": &"attack", "equip": {} },
			{ "name": "Omen", "anim": &"cast", "equip": {} },
			{ "name": "Collapse", "anim": &"die", "equip": {} },
		],
	},
]

const BowStances   = preload("res://scripts/systems/stances/bow_stances.gd")
const StaffStances = preload("res://scripts/systems/stances/staff_stances.gd")
const SpearStances = preload("res://scripts/systems/stances/spear_stances.gd")
const WandStances = preload("res://scripts/systems/stances/wand_stances.gd")
const SpriteMotionStances = preload("res://scripts/systems/stances/sprite_motion_stances.gd")

const SCORE_FILE: String = "res://tmp/stance_scores.json"
const SELECTED_STANCES_FILE: String = "res://tmp/selected_stances.json"
const LAUNCH_FILE: String = "res://tmp/pose_tuner_launch.json"
const CUSTOM_STANCES_FILE: String = "res://tmp/custom_stances.json"

# Per-class stance catalog. Maps class id → catalog tag used in
# _load_current to populate _stance_ids from the right catalog.
const STANCE_CATALOGS: Dictionary = {
	&"shade_hunter":   &"bow",
	&"pythia":         &"staff",
	&"myrmidon":       &"spear",
	&"ossuary_priest": &"wand",
	&"training_dummy": &"motion",
	&"bone_servant":   &"motion",
	&"shade_wretch":   &"motion",
	&"bog_caller":     &"motion",
	&"act_boss":       &"motion",
	&"revenant":       &"motion",
	&"fiend":          &"motion",
	&"bronze_sentinel":&"motion",
	&"kallias":        &"motion",
	&"eurynome":       &"motion",
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
var _drag_last_mouse_prev: Vector2 = Vector2.ZERO
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
var _score_card: RichTextLabel
var _label_score: Label
var _label_completion: Label
var _class_select: OptionButton
var _variant_select: OptionButton
var _stance_select: OptionButton
var _use_stance_button: Button
var _save_stance_button: Button
var _delete_stance_button: Button
var _time_slider: HSlider
var _slider_box: VBoxContainer
var _ui_syncing: bool = false
var _scores: Dictionary = {}
var _selected_stances: Dictionary = {}
var _custom_stances: Dictionary = {}
var _undo_stack: Array = []
var _restoring_undo: bool = false
## PIDs of "Launch in Maw" preview windows spawned this session. Killed
## when the tuner closes gracefully (window X / quit). Ctrl+C can't run
## _exit_tree, so the spawned window ALSO self-closes via the
## launcher_pid watchdog in game.gd — belt and suspenders.
var _spawned_preview_pids: Array[int] = []
# Per-node slider references for the "Dump Pose" extractor.
# Each entry: { "kind": "rot"|"pos", "node_path": String, "controls": [Range...] }
var _slider_entries: Array = []

## Liveness heartbeat for spawned "Launch in Maw" preview windows. The
## game polls this file's timestamp and self-closes when it goes stale,
## which is how Ctrl+C (no clean shutdown) still takes the window down.
const HEARTBEAT_FILE: String = "res://tmp/pose_tuner_heartbeat.txt"

func _exit_tree() -> void:
	_kill_spawned_previews()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_kill_spawned_previews()

## Graceful close (window X / quit): kill any preview windows directly.
## Ctrl+C can't reach this — the heartbeat watchdog covers that case.
func _kill_spawned_previews() -> void:
	for pid in _spawned_preview_pids:
		if OS.is_process_running(pid):
			OS.kill(pid)
	_spawned_preview_pids.clear()

func _write_heartbeat() -> void:
	var f := FileAccess.open(HEARTBEAT_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(str(Time.get_unix_time_from_system()))
		f.close()

func _ready() -> void:
	# Beat ~2 Hz so spawned preview windows can tell we're still alive.
	var hb := Timer.new()
	hb.name = "HeartbeatTimer"
	hb.wait_time = 0.5
	hb.autostart = true
	hb.timeout.connect(_write_heartbeat)
	add_child(hb)
	_write_heartbeat()
	_load_scores_from_disk()
	_load_selected_stances_from_disk()
	_load_custom_stances_from_disk()
	_build_ui()
	_load_current()

func _ellipse_points(center: Vector2, rx: float, ry: float, samples: int = 20) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in samples:
		var t := TAU * float(i) / float(samples)
		pts.append(center + Vector2(rx * cos(t), ry * sin(t)))
	return pts

func _boost_editor_shadows() -> void:
	if _sprite == null:
		return
	for path in _paths_matching(_sprite, ["Shadow"]):
		var shadow := _sprite.get_node_or_null(NodePath(path))
		if shadow is Polygon2D:
			(shadow as Polygon2D).color = Color(0.0, 0.0, 0.02, 0.72)
			(shadow as Polygon2D).z_index = -5

func _paths_matching(root: Node, tokens: Array[String]) -> Array[String]:
	var out: Array[String] = []
	_collect_paths_matching(root, "", tokens, out)
	return out

func _collect_paths_matching(node: Node, prefix: String, tokens: Array[String], out: Array[String]) -> void:
	for child in node.get_children():
		if String(child.name).begins_with("_"):
			continue
		var path := (prefix + "/" + String(child.name)) if prefix != "" else String(child.name)
		for token in tokens:
			if String(child.name).contains(token):
				out.append(path)
				break
		_collect_paths_matching(child, path, tokens, out)

func _push_undo() -> void:
	if _sprite == null or _restoring_undo:
		return
	var snap := _snapshot_pose()
	if snap.is_empty():
		return
	_undo_stack.append(snap)
	if _undo_stack.size() > 60:
		_undo_stack.pop_front()

func _snapshot_pose() -> Dictionary:
	var snap := { "rotations": {}, "positions": {}, "scales": {} }
	for entry_v in _slider_entries:
		var entry: Dictionary = entry_v
		var path := String(entry.get("path", ""))
		if path == "":
			continue
		var n := _sprite.get_node_or_null(NodePath(path)) as Node2D
		if n == null:
			continue
		match String(entry.get("kind", "")):
			"rot": snap["rotations"][path] = n.rotation
			"pos": snap["positions"][path] = [n.position.x, n.position.y]
			"scale": snap["scales"][path] = [n.scale.x, n.scale.y]
	return snap

func _undo_pose() -> void:
	if _undo_stack.is_empty() or _sprite == null:
		return
	_restore_pose_snapshot(_undo_stack.pop_back())

func _restore_pose_snapshot(snap: Dictionary) -> void:
	_restoring_undo = true
	for path in snap.get("rotations", {}).keys():
		var n := _sprite.get_node_or_null(NodePath(String(path))) as Node2D
		if n != null:
			n.rotation = float(snap["rotations"][path])
	for path in snap.get("positions", {}).keys():
		var n := _sprite.get_node_or_null(NodePath(String(path))) as Node2D
		if n != null:
			var v: Array = snap["positions"][path]
			n.position = Vector2(float(v[0]), float(v[1]))
	for path in snap.get("scales", {}).keys():
		var n := _sprite.get_node_or_null(NodePath(String(path))) as Node2D
		if n != null:
			var v: Array = snap["scales"][path]
			n.scale = Vector2(float(v[0]), float(v[1]))
	_restoring_undo = false
	for entry_v in _slider_entries:
		var entry: Dictionary = entry_v
		var n := _sprite.get_node_or_null(NodePath(String(entry.get("path", "")))) as Node2D
		if n != null:
			_sync_sliders_for(n)
	_force_pin_pass()

# =========================================================================
# UI scaffolding
# =========================================================================

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := HSplitContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.split_offset = 500
	add_child(root)
	# Sidebar. The ScrollContainer wraps the entire control stack so
	# class/variant/legend/buttons remain reachable on small windows.
	var side_scroll := ScrollContainer.new()
	side_scroll.custom_minimum_size = Vector2(500, 0)
	side_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(side_scroll)
	var side := VBoxContainer.new()
	side.custom_minimum_size = Vector2(480, 0)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side_scroll.add_child(side)
	var class_row := HBoxContainer.new()
	side.add_child(class_row)
	var class_label := Label.new()
	class_label.text = "Class"
	class_label.custom_minimum_size = Vector2(72, 0)
	class_row.add_child(class_label)
	_class_select = OptionButton.new()
	_class_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_class_select.item_selected.connect(_on_class_selected)
	class_row.add_child(_class_select)
	var variant_row := HBoxContainer.new()
	side.add_child(variant_row)
	var variant_label := Label.new()
	variant_label.text = "Variant"
	variant_label.custom_minimum_size = Vector2(72, 0)
	variant_row.add_child(variant_label)
	_variant_select = OptionButton.new()
	_variant_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_variant_select.item_selected.connect(_on_variant_selected)
	variant_row.add_child(_variant_select)
	var stance_row := HBoxContainer.new()
	side.add_child(stance_row)
	var stance_label := Label.new()
	stance_label.text = "Stance"
	stance_label.custom_minimum_size = Vector2(72, 0)
	stance_row.add_child(stance_label)
	_stance_select = OptionButton.new()
	_stance_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stance_select.item_selected.connect(_on_stance_selected)
	stance_row.add_child(_stance_select)
	var stance_actions := HBoxContainer.new()
	side.add_child(stance_actions)
	_use_stance_button = Button.new()
	_use_stance_button.text = "Use Stance"
	_use_stance_button.pressed.connect(_on_use_stance_pressed)
	stance_actions.add_child(_use_stance_button)
	_save_stance_button = Button.new()
	_save_stance_button.text = "Save Stance"
	_save_stance_button.pressed.connect(_on_save_stance_pressed)
	stance_actions.add_child(_save_stance_button)
	_delete_stance_button = Button.new()
	_delete_stance_button.text = "Delete Stance"
	_delete_stance_button.pressed.connect(_on_delete_stance_pressed)
	stance_actions.add_child(_delete_stance_button)
	_score_card = RichTextLabel.new()
	_score_card.bbcode_enabled = true
	_score_card.fit_content = true
	_score_card.scroll_active = false
	_score_card.custom_minimum_size = Vector2(0, 58)
	_score_card.text = "[color=#ff3333][b]GRADE: UNSCORED[/b][/color]"
	side.add_child(_score_card)
	_label_class = Label.new(); side.add_child(_label_class)
	_label_variant = Label.new(); side.add_child(_label_variant)
	_label_time = Label.new(); side.add_child(_label_time)
	_label_score = Label.new()
	_label_score.text = "Current score: -"
	side.add_child(_label_score)
	_label_completion = Label.new()
	_label_completion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label_completion.text = "Coverage: -"
	side.add_child(_label_completion)
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
	var launch := Button.new(); launch.text = "Launch in Maw"
	launch.pressed.connect(_on_launch_game_pressed); btn_row.add_child(launch)
	# Stage 17.8 — Disable IK so shoulder/elbow rotation sliders can
	# actually move arms. With IK on, the runtime pin pass overwrites
	# any manual rotation every frame.
	var ik_box := CheckBox.new()
	ik_box.text = "Disable IK (manual arm tuning)"
	ik_box.button_pressed = _ik_disabled   # reflect default
	ik_box.toggled.connect(_on_ik_toggled)
	side.add_child(ik_box)
	var hint := Label.new()
	hint.text = "Keys: F1 target · F2 variant · F3 stance · F4 preset · 1-5 score · S save phase · D dump · Space play · R reset"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(hint)
	var legend := Label.new()
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.text = "Legend: colored labels match drag dots. ROT uses degrees around the joint; POS uses local X/Y pixels. Weapon POS is grip/body placement, not an elbow pivot. Hands and claws rotate their parent joint so limbs stay attached."
	side.add_child(legend)
	_slider_box = VBoxContainer.new()
	_slider_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_child(_slider_box)
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
	# Editor chrome MUST sit behind ALL sprite content. Sprites can place
	# parts at negative z_index (e.g. SpriteRuntime2D pins injected leg
	# hips to z=-1 so they read behind the torso) — an opaque background
	# at z=0 silently hid the bone_servant's legs in the editor while they
	# rendered fine in-game (no full-screen overlay there). Keep BG_Z far
	# below any plausible sprite part so the tuner shows what ships.
	# (failure-modes: "editor chrome occluding negative-z sprite parts".)
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.10, 0.14)
	bg.size = VIEW_SIZE
	bg.z_index = BG_Z
	_vp.add_child(bg)
	var floor := Polygon2D.new()
	floor.name = "_EditorShadowGuide"
	floor.position = FEET_POS + Vector2(0, 4)
	floor.polygon = _ellipse_points(Vector2.ZERO, 58.0, 13.0, 28)
	floor.color = Color(0.02, 0.015, 0.025, 0.72)
	floor.z_index = BG_Z + 50   # above the flat BG, still behind the sprite
	_vp.add_child(floor)
	vp_container.add_child(_vp)

# =========================================================================
# Sprite loading
# =========================================================================

func _stance_ids_for(cls: Dictionary, variant: Dictionary) -> Array:
	var catalog: StringName = STANCE_CATALOGS.get(cls["id"], &"")
	var anim_name := StringName(variant.get("anim", &"idle"))
	var ids: Array = []
	if _variant_uses_motion_stances(variant):
		ids = SpriteMotionStances.ids_for_context(
				cls.get("bucket", &"classes"), cls["id"], anim_name)
	elif catalog == &"bow":
		ids = BowStances.ids_for_anim(anim_name)
	elif catalog == &"staff":
		ids = StaffStances.ids_for_anim(anim_name)
	elif catalog == &"spear":
		ids = SpearStances.ids_for_anim(anim_name)
	elif catalog == &"wand":
		ids = WandStances.ids_for_anim(anim_name)
	elif catalog == &"motion":
		ids = SpriteMotionStances.ids_for_context(
				cls.get("bucket", &"classes"), cls["id"], anim_name)
	ids.append_array(_custom_stance_ids_for(String(cls["id"]), String(anim_name)))
	return ids

func _variant_uses_motion_stances(variant: Dictionary) -> bool:
	return bool(variant.get("unarmed", false)) \
			or variant.get("show_bow", true) == false \
			or variant.get("show_staff", true) == false \
			or variant.get("show_spear", true) == false \
			or variant.get("show_wand", true) == false

func _custom_stance_ids_for(class_key: String, anim_name: String) -> Array:
	var out: Array = []
	for owner in _custom_stances.keys():
		var class_block_v: Variant = _custom_stances[owner]
		if typeof(class_block_v) != TYPE_DICTIONARY:
			continue
		var class_block: Dictionary = class_block_v
		for stance_id in class_block.keys():
			var rec_v: Variant = class_block[stance_id]
			if typeof(rec_v) != TYPE_DICTIONARY:
				continue
			var rec: Dictionary = rec_v
			if String(rec.get("anim", "")) != anim_name:
				continue
			if String(owner) == class_key or bool(rec.get("shareable", true)):
				out.append(StringName(String(stance_id)))
	return out

func _custom_stance_record(stance_id: String) -> Dictionary:
	var current_block_v: Variant = _custom_stances.get(_current_class_key(), {})
	if typeof(current_block_v) == TYPE_DICTIONARY and (current_block_v as Dictionary).has(stance_id):
		return (current_block_v as Dictionary)[stance_id]
	for owner in _custom_stances.keys():
		var class_block_v: Variant = _custom_stances[owner]
		if typeof(class_block_v) == TYPE_DICTIONARY and (class_block_v as Dictionary).has(stance_id):
			return (class_block_v as Dictionary)[stance_id]
	return {}

func _custom_stance_owner(stance_id: String) -> String:
	var current_block_v: Variant = _custom_stances.get(_current_class_key(), {})
	if typeof(current_block_v) == TYPE_DICTIONARY and (current_block_v as Dictionary).has(stance_id):
		return _current_class_key()
	for owner in _custom_stances.keys():
		var class_block_v: Variant = _custom_stances[owner]
		if typeof(class_block_v) == TYPE_DICTIONARY and (class_block_v as Dictionary).has(stance_id):
			return String(owner)
	return ""

func _is_custom_stance_id(stance_id: String) -> bool:
	return not _custom_stance_record(stance_id).is_empty()

func _is_local_custom_stance_id(stance_id: String) -> bool:
	return _custom_stance_owner(stance_id) == _current_class_key()

func _custom_import_warning(stance_id: String) -> String:
	if not _is_custom_stance_id(stance_id):
		return ""
	var owner := _custom_stance_owner(stance_id)
	if owner == "" or owner == _current_class_key():
		return ""
	var weapon := _weapon_hint_for_class(owner)
	if weapon == "":
		return "WARNING: importing %s stance from %s; missing target nodes are skipped." % [stance_id, owner]
	return "WARNING: importing %s %s stance from %s; this will attempt to replicate grip/attack transforms, and missing weapon nodes are soft-skipped." % [weapon, stance_id, owner]

func _weapon_hint_for_class(class_key: String) -> String:
	match class_key:
		"shade_hunter": return "bow"
		"pythia": return "staff"
		"myrmidon": return "spear"
		"ossuary_priest": return "wand"
		_: return ""

func _load_current(scrub_time: float = 0.0) -> void:
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
	_undo_stack.clear()
	var cls: Dictionary = CLASSES[_class_idx]
	var variant: Dictionary = cls["variants"][_variant_idx]
	# Populate stance ids for this exact sprite + variant animation.
	# Idle variants receive idle-safe stances, attacks receive attack
	# stances, NPCs never receive enemy rows, and enemies never receive
	# merchant rows.
	_stance_ids = _stance_ids_for(cls, variant)
	if _stance_idx >= _stance_ids.size():
		_stance_idx = 0
	_refresh_picker_options()
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
	var bucket: StringName = cls.get("bucket", &"classes")
	if bucket == &"classes":
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
	if &"sprite_id" in _sprite:
		_sprite.sprite_id = cls["id"]
	if &"stance_bucket" in _sprite:
		_sprite.stance_bucket = bucket
	# Weapon visibility toggles let the same sprite be edited armed or unarmed.
	for prop in ["show_bow", "show_staff", "show_spear", "show_wand"]:
		if variant.has(prop) and StringName(prop) in _sprite:
			_sprite.set(prop, bool(variant[prop]))
	# IK starts OFF on a fresh load (sprite paused -> tuning mode).
	# Pressing Space flips both at once via _apply_auto_ik.
	if &"ik_enabled" in _sprite:
		_sprite.ik_enabled = false
	_ik_disabled = true
	_paused = true
	_sprite.position = FEET_POS
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_vp.add_child(_sprite)
	_boost_editor_shadows()
	# Bind the equipment paper-doll ONLY when the variant equips armor.
	# For weapon-only / unarmed variants the weapon is shown via the
	# show_* flags (baseline's simple one-hand hold) and is fully tunable
	# with the weapon-arm sliders — binding the paper-doll would install
	# WeaponProfiles IK pins that re-pose the weapon every frame and stomp
	# slider edits (issue 1A). Armor variants still use the paper-doll.
	if bucket == &"classes":
		var equip: Dictionary = variant.get("equip", {})
		var has_armor: bool = equip.has("head") or equip.has("chest") \
				or equip.has("legs") or equip.has("offhand")
		if has_armor:
			_paperdoll = EquipmentPaperdoll.new()
			add_child(_paperdoll)
			_paperdoll.bind(_sprite, _inv, cls["id"])
			for slot in ["weapon", "offhand", "head", "chest", "legs"]:
				if equip.has(slot):
					_inv.add_item(equip[slot])
					_inv.equip(equip[slot])
	await get_tree().process_frame
	_anim = _sprite.get_node(^"AnimationPlayer") as AnimationPlayer
	_anim.play(variant["anim"])
	_paused = true
	_anim.pause()
	var length: float = _anim.current_animation_length
	_time_slider.max_value = max(length, 0.01)
	var target_time: float = clampf(scrub_time, 0.0, _time_slider.max_value)
	_time_slider.set_value_no_signal(target_time)
	_scrub_time = target_time
	_anim.seek(target_time, true)
	_update_time_label(target_time)
	_spawn_drag_dots()
	_build_sliders()
	# Final pass: re-assert paused + IK-disabled state on the freshly-
	# loaded sprite. AnimationPlayer.play() above may have re-enabled
	# tracks that would otherwise immediately stomp slider edits;
	# explicitly pausing here + sprite.ik_enabled=false guarantees the
	# first slider drag/spinbox edit takes effect without the user
	# having to toggle the Disable IK checkbox.
	_anim.pause()
	_anim.seek(target_time, true)
	if &"ik_enabled" in _sprite:
		_sprite.ik_enabled = false
	_refresh_score_panel()

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
		dot.color = _color_for_path(_path_for(n))
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
	header.text = "ARMS / HANDS / WEAPONS"
	_slider_box.add_child(header)
	_walk_for_sliders_filtered(_sprite, "", true)
	var sep := Label.new()
	sep.text = "BODY / MARKERS / OTHER PARTS"
	_slider_box.add_child(sep)
	_walk_for_sliders_filtered(_sprite, "", false)

# Two-pass walk. When `arms_only` is true, we add sliders ONLY for arm
# chain nodes (shoulders, elbows under the arms, weapon-arm subtrees +
# their markers). When false, we add sliders for everything ELSE.
func _walk_for_sliders_filtered(node: Node, prefix: String,
		arms_only: bool) -> void:
	for child in node.get_children():
		var path: String = (prefix + "/" + String(child.name)) if prefix != "" else String(child.name)
		var in_arm: bool = _is_arm_weapon_or_hand_path(path)
		var should_add: bool = in_arm if arms_only else not in_arm
		if should_add:
			if child is Marker2D:
				_add_marker_sliders(child, path)
			elif child is Node2D:
				if _wants_rotation_slider(child.name):
					_add_rotation_slider(child, path)
					if _wants_position_slider(child.name):
						_add_arm_position_sliders(child, path)
				if _wants_scale_slider(child, path):
					_add_scale_sliders(child, path)
		_walk_for_sliders_filtered(child, path, arms_only)

func _walk_for_sliders(node: Node, prefix: String) -> void:
	for child in node.get_children():
		var path: String = (prefix + "/" + String(child.name)) if prefix != "" else String(child.name)
		if child is Marker2D:
			_add_marker_sliders(child, path)
		elif child is Node2D:
			if _wants_rotation_slider(child.name):
				_add_rotation_slider(child, path)
				if _wants_position_slider(child.name):
					_add_arm_position_sliders(child, path)
			if _wants_scale_slider(child, path):
				_add_scale_sliders(child, path)
		_walk_for_sliders(child, path)

func _is_arm_weapon_or_hand_path(path: String) -> bool:
	return path.contains("Shoulder") or path.contains("ArmAnchor") \
			or path.contains("BowArm") or path.contains("StaffArm") \
			or path.contains("SpearArm") or path.contains("WandArm") \
			or path.contains("ArmR") or path.contains("ArmL") \
			or path.contains("HandR") or path.contains("HandL") \
			or path.contains("ClawR") or path.contains("ClawL") \
			or path.contains("Finger") or path.ends_with("Staff")

func _wants_rotation_slider(n: StringName) -> bool:
	var s := String(n)
	return s == "Body" or s == "Staff" or s == "ArmAnchor" \
			or s.contains("ArmR") or s.contains("ArmL") \
			or s.contains("HandR") or s.contains("HandL") \
			or s.contains("ClawR") or s.contains("ClawL") \
			or s.contains("Finger") or s.ends_with("Pivot") \
			or s.ends_with("Shoulder") or s.ends_with("StaffArm") \
			or s.ends_with("SpearArm") or s.ends_with("BowArm") \
			or s.ends_with("WandArm")

# Position sliders go on movable body/arm/hand/weapon nodes so the
# editor supports player classes, enemies, NPCs, and bespoke rigs.
func _wants_position_slider(n: StringName) -> bool:
	var s := String(n)
	return s == "Body" or s == "Staff" or s == "ArmAnchor" \
			or s.contains("HandR") or s.contains("HandL") \
			or s.contains("ClawR") or s.contains("ClawL") \
			or s.ends_with("StaffArm") or s.ends_with("SpearArm") \
			or s.ends_with("BowArm") or s.ends_with("WandArm")

func _wants_scale_slider(node: Node, path: String) -> bool:
	if String(node.name).begins_with("_") or node is Marker2D:
		return false
	if node is Polygon2D or node is Line2D:
		return true
	var s := String(node.name)
	return s == "Body" or s == "Face" or s.contains("Arm") \
			or s.contains("Hand") or s.contains("Claw") \
			or s.contains("Leg") or s.contains("Foot") \
			or s.contains("Eye") or _is_weapon_path(path)

func _add_rotation_slider(n: Node2D, path: String) -> void:
	var row := HBoxContainer.new()
	_add_slider_caption(path, "rot")
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
	s.drag_started.connect(_push_undo)
	s.value_changed.connect(func(v):
		n.rotation = deg_to_rad(v)
		box.set_value_no_signal(v))
	box.value_changed.connect(func(v):
		_push_undo()
		n.rotation = deg_to_rad(v)
		s.set_value_no_signal(v))
	_slider_entries.append({ "kind": "rot", "path": path, "controls": [s, box] })

func _add_arm_position_sliders(n: Node2D, path: String) -> void:
	_add_xy_pair("%s.pos" % path, n, Vector2(-50, -70), Vector2(50, 20), 0.5, path)

func _add_xy_pair(_label_text: String, n: Node2D,
		mins: Vector2, maxs: Vector2, step: float, entry_path: String) -> void:
	_add_slider_caption(entry_path, "pos")
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
	sx.drag_started.connect(_push_undo)
	sx.value_changed.connect(func(v):
		n.position.x = v
		bx.set_value_no_signal(v)
		if n is Marker2D:
			_force_pin_pass())
	bx.value_changed.connect(func(v):
		_push_undo()
		n.position.x = v
		sx.set_value_no_signal(v)
		if n is Marker2D:
			_force_pin_pass())
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
	sy.drag_started.connect(_push_undo)
	sy.value_changed.connect(func(v):
		n.position.y = v
		by.set_value_no_signal(v)
		if n is Marker2D:
			_force_pin_pass())
	by.value_changed.connect(func(v):
		_push_undo()
		n.position.y = v
		sy.set_value_no_signal(v)
		if n is Marker2D:
			_force_pin_pass())
	_slider_entries.append({ "kind": "pos", "path": entry_path, "controls": [sx, sy, bx, by] })

func _add_marker_sliders(m: Marker2D, path: String) -> void:
	_add_xy_pair("%s.pos" % path, m, Vector2(-60, -60), Vector2(60, 60), 0.1, path)

func _add_scale_sliders(n: Node2D, path: String) -> void:
	_add_slider_caption(path, "scale")
	var sx := HSlider.new()
	sx.min_value = 0.20; sx.max_value = 3.00; sx.step = 0.02
	sx.value = n.scale.x
	sx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bx := SpinBox.new()
	bx.min_value = 0.20; bx.max_value = 3.00; bx.step = 0.02
	bx.value = n.scale.x
	bx.custom_minimum_size = Vector2(70, 0)
	var rx := HBoxContainer.new()
	rx.add_child(sx); rx.add_child(bx)
	_slider_box.add_child(rx)
	sx.drag_started.connect(_push_undo)
	sx.value_changed.connect(func(v):
		n.scale.x = v
		bx.set_value_no_signal(v))
	bx.value_changed.connect(func(v):
		_push_undo()
		n.scale.x = v
		sx.set_value_no_signal(v))
	var sy := HSlider.new()
	sy.min_value = 0.20; sy.max_value = 3.00; sy.step = 0.02
	sy.value = n.scale.y
	sy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var by := SpinBox.new()
	by.min_value = 0.20; by.max_value = 3.00; by.step = 0.02
	by.value = n.scale.y
	by.custom_minimum_size = Vector2(70, 0)
	var ry := HBoxContainer.new()
	ry.add_child(sy); ry.add_child(by)
	_slider_box.add_child(ry)
	sy.drag_started.connect(_push_undo)
	sy.value_changed.connect(func(v):
		n.scale.y = v
		by.set_value_no_signal(v))
	by.value_changed.connect(func(v):
		_push_undo()
		n.scale.y = v
		sy.set_value_no_signal(v))
	_slider_entries.append({ "kind": "scale", "path": path, "controls": [sx, sy, bx, by] })

func _add_slider_caption(path: String, kind: String) -> void:
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size = Vector2(0, 32)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var color_hex := _color_for_path(path).to_html(false)
	label.text = "[color=#%s][b]%s[/b][/color] (%s)" % [
		color_hex, _slider_title(path, kind), _slider_note(path, kind)]
	_slider_box.add_child(label)

func _slider_title(path: String, kind: String) -> String:
	var leaf := _slider_leaf(path)
	var side := ""
	if path.contains("ArmL") or path.contains("HandL") or path.contains("ClawL") or path.contains("LegL"):
		side = "Left "
	elif path.contains("ArmR") or path.contains("HandR") or path.contains("ClawR") or path.contains("LegR"):
		side = "Right "
	if _is_weapon_path(path):
		if kind == "scale":
			return "Weapon size / shape"
		return "Weapon %s" % ("rotation" if kind == "rot" else "position")
	if leaf.ends_with("ElbowPivot"):
		return "%selbow angle" % side
	if leaf.ends_with("KneePivot"):
		return "%sknee angle" % side
	if leaf.contains("Hand"):
		return "%shand %s" % [side, "angle" if kind == "rot" else "position"]
	if leaf.contains("Claw"):
		return "%sclaw %s" % [side, "angle" if kind == "rot" else "position"]
	if leaf.contains("Finger"):
		return "%sfinger %s" % [side, "angle" if kind == "rot" else "position"]
	if leaf == "Body":
		return "Body %s" % ("tilt" if kind == "rot" else ("size / shape" if kind == "scale" else "position"))
	if kind == "scale":
		return "%s size / shape" % leaf
	return "%s %s" % [leaf, "rotation" if kind == "rot" else "position"]

func _slider_note(path: String, kind: String) -> String:
	if _is_weapon_path(path):
		if kind == "scale":
			return "local X/Y scale for weapon thickness and length"
		return "grip/body-local weapon placement" if kind == "pos" else "weapon angle in degrees"
	if kind == "scale":
		return "local X/Y scale; edits layer size without tearing the rig"
	if kind == "rot":
		return "degrees around this pivot"
	return "local X/Y pixels; child parts remain attached"

func _slider_leaf(path: String) -> String:
	var parts := path.split("/")
	if parts.size() == 0:
		return path
	return String(parts[parts.size() - 1])

func _is_weapon_path(path: String) -> bool:
	return path.contains("BowArm") or path.contains("StaffArm") \
			or path.contains("SpearArm") or path.contains("WandArm") \
			or path.contains("GripMarker") or path.contains("NockMarker") \
			or path.contains("RiserMarker") or path.ends_with("Staff")

func _color_for_path(path: String) -> Color:
	if _is_weapon_path(path):
		return Color(0.95, 0.72, 0.25, 0.95)
	if path.contains("ArmL") or path.contains("HandL") or path.contains("ClawL"):
		return Color(0.35, 0.78, 0.95, 0.95)
	if path.contains("ArmR") or path.contains("HandR") or path.contains("ClawR"):
		return Color(0.95, 0.42, 0.36, 0.95)
	if path.contains("LegL") or path.contains("LegR") or path.contains("Foot"):
		return Color(0.45, 0.86, 0.48, 0.95)
	if path.contains("Head") or path.contains("Eye") or path.contains("Face"):
		return Color(0.82, 0.55, 0.95, 0.95)
	if path == "Body" or path.contains("Torso") or path.contains("Robe") or path.contains("Cloak"):
		return Color(0.55, 0.68, 0.95, 0.95)
	return DRAG_DOT_COLOR

# =========================================================================
# Time scrubbing
# =========================================================================

func _on_time_changed(v: float) -> void:
	_scrub_time = v
	if _anim != null:
		_anim.seek(v, true)
	# Phase guide for attack: 0-20% = BEGIN (start pose), 20-65% =
	# MIDDLE (strike apex), 65-100% = END (recovery). Save at each
	# point with S to capture the per-phase pose.
	_update_time_label(v)

func _on_play_toggle() -> void:
	if _anim == null:
		return
	_paused = not _paused
	if _paused:
		_anim.pause()
	else:
		var length: float = _time_slider.max_value if _time_slider != null else _anim.current_animation_length
		if length > 0.01 and _anim.current_animation_position >= length - 0.001:
			_scrub_time = 0.0
			if _time_slider != null:
				_time_slider.set_value_no_signal(0.0)
			_anim.seek(0.0, true)
			_update_time_label(0.0)
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
		_scrub_time = t
		_time_slider.set_value_no_signal(t)
		_update_time_label(t)

func _update_time_label(t: float) -> void:
	if _label_time == null:
		return
	var length: float = _time_slider.max_value if _time_slider != null else 0.0
	_label_time.text = "Time: %.2fs / %.2fs    Phase: %s    (S saves this phase)" % [
			t, length, String(_current_phase())]
	_refresh_score_panel()

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
		elif entry["kind"] == "scale":
			lines.append("#   %s.scale     = Vector2(%.2f, %.2f)" % [
				entry["path"], entry["controls"][0].value, entry["controls"][1].value])
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
# Picker + score state
# =========================================================================

func _refresh_picker_options() -> void:
	if _class_select == null or _variant_select == null or _stance_select == null:
		return
	_ui_syncing = true
	_class_select.clear()
	for i in range(CLASSES.size()):
		_class_select.add_item(String(CLASSES[i]["id"]))
	_class_select.select(clampi(_class_idx, 0, max(0, CLASSES.size() - 1)))
	_variant_select.clear()
	var variants: Array = CLASSES[_class_idx]["variants"]
	for i in range(variants.size()):
		var variant: Dictionary = variants[i]
		_variant_select.add_item(String(variant["name"]))
	_variant_select.select(clampi(_variant_idx, 0, max(0, variants.size() - 1)))
	_stance_select.clear()
	if _stance_ids.is_empty():
		_stance_select.add_item("default")
		_stance_select.disabled = true
	else:
		_stance_select.disabled = false
		var selected: String = _selected_stance_for_class(String(CLASSES[_class_idx]["id"]))
		for i in range(_stance_ids.size()):
			var stance_id: String = String(_stance_ids[i])
			var coverage: Dictionary = _coverage_for_stance(stance_id)
			var label: String = "%s  [%d/%d]" % [
				stance_id,
				int(coverage.get("completed", 0)),
				int(coverage.get("total", 0)),
			]
			var owner := _custom_stance_owner(stance_id)
			if owner != "" and owner != _current_class_key():
				label += "  IMPORT:%s" % owner
			if stance_id == selected:
				label += "  ACTIVE"
			_stance_select.add_item(label)
		_stance_select.select(clampi(_stance_idx, 0, max(0, _stance_ids.size() - 1)))
	_ui_syncing = false

func _on_class_selected(index: int) -> void:
	if _ui_syncing:
		return
	if index < 0 or index >= CLASSES.size():
		return
	_class_idx = index
	_variant_idx = 0
	_stance_idx = 0
	_load_current()

func _on_variant_selected(index: int) -> void:
	if _ui_syncing:
		return
	var variants: Array = CLASSES[_class_idx]["variants"]
	if index < 0 or index >= variants.size():
		return
	_variant_idx = index
	_stance_idx = 0
	_load_current()

func _on_stance_selected(index: int) -> void:
	if _ui_syncing:
		return
	if index < 0 or index >= _stance_ids.size():
		return
	_stance_idx = index
	_load_current()

func _load_scores_from_disk() -> void:
	_scores = _read_json_dict(SCORE_FILE)

func _load_selected_stances_from_disk() -> void:
	_selected_stances = _read_json_dict(SELECTED_STANCES_FILE)

func _load_custom_stances_from_disk() -> void:
	_custom_stances = _read_json_dict(CUSTOM_STANCES_FILE)

func _read_json_dict(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed

func _write_json_dict(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var w := FileAccess.open(path, FileAccess.WRITE)
	if w != null:
		w.store_string(JSON.stringify(data, "  "))
		w.close()

func _current_class_key() -> String:
	return String(CLASSES[_class_idx]["id"])

func _current_bucket() -> StringName:
	return CLASSES[_class_idx].get("bucket", &"classes")

func _current_stance_key() -> String:
	if _stance_ids.is_empty():
		return "default"
	return String(_stance_ids[_stance_idx])

func _score_key(class_key: String, stance_id: String, variant_name: String, phase: String) -> String:
	return "%s/%s/%s/%s" % [class_key, stance_id, variant_name, phase]

func _score_record_for(class_key: String, stance_id: String,
		variant_name: String, phase: String) -> Dictionary:
	var rec_v: Variant = _scores.get(_score_key(class_key, stance_id, variant_name, phase), {})
	if typeof(rec_v) != TYPE_DICTIONARY:
		return {}
	var rec: Dictionary = rec_v
	if String(rec.get("class", class_key)) != class_key:
		return {}
	return rec

func _required_phases_for_variant(variant: Dictionary) -> Array[String]:
	match String(variant.get("anim", &"idle")):
		"attack", "cast":
			return ["BEGIN", "MIDDLE", "END"]
		_:
			return ["BEGIN"]

func _coverage_for_stance(stance_id: String) -> Dictionary:
	var class_key: String = _current_class_key()
	var variants: Array = CLASSES[_class_idx]["variants"]
	var current_anim: String = String((CLASSES[_class_idx]["variants"][_variant_idx] as Dictionary).get("anim", &"idle"))
	var lines: Array[String] = []
	var missing: Array[String] = []
	var required: Array[String] = []
	var completed: int = 0
	var total: int = 0
	for variant_v in variants:
		var variant: Dictionary = variant_v
		if String(variant.get("anim", &"idle")) != current_anim:
			continue
		var variant_name: String = String(variant["name"])
		var parts: Array[String] = []
		for phase in _required_phases_for_variant(variant):
			total += 1
			var token: String = "%s/%s" % [variant_name, phase]
			required.append(token)
			var rec: Dictionary = _score_record_for(class_key, stance_id, variant_name, phase)
			var phase_short: String = phase.substr(0, 1)
			if rec.is_empty():
				parts.append("%s-" % phase_short)
				missing.append(token)
			else:
				completed += 1
				parts.append("%s%d" % [phase_short, int(rec.get("score", 0))])
		lines.append("%s: %s" % [variant_name, " ".join(parts)])
	return {
		"completed": completed,
		"total": total,
		"lines": lines,
		"missing": missing,
		"required": required,
	}

func _selected_stance_for_class(class_key: String) -> String:
	var bucket := _current_bucket()
	if bucket == &"classes":
		var rec_v: Variant = _selected_stances.get(class_key, {})
		if typeof(rec_v) != TYPE_DICTIONARY:
			return ""
		return String((rec_v as Dictionary).get("stance", ""))
	var bucket_v: Variant = _selected_stances.get(String(bucket), {})
	if typeof(bucket_v) != TYPE_DICTIONARY:
		return ""
	var rec_v: Variant = (bucket_v as Dictionary).get(class_key, {})
	if typeof(rec_v) != TYPE_DICTIONARY:
		return ""
	return String((rec_v as Dictionary).get("stance", ""))

func _refresh_score_panel() -> void:
	if _label_score == null or _label_completion == null:
		return
	var class_key: String = _current_class_key()
	var stance_id: String = _current_stance_key()
	var variant: Dictionary = CLASSES[_class_idx]["variants"][_variant_idx]
	var variant_name: String = String(variant["name"])
	var phase: String = String(_current_phase())
	var rec: Dictionary = _score_record_for(class_key, stance_id, variant_name, phase)
	var current_score: String = "unscored"
	var grade_text: String = "UNSCORED"
	if not rec.is_empty():
		grade_text = "%d / 5" % int(rec.get("score", 0))
		current_score = "%d at %.2fs" % [int(rec.get("score", 0)), float(rec.get("t", 0.0))]
	if _score_card != null:
		_score_card.text = "[color=#ff3333][font_size=28][b]GRADE: %s[/b][/font_size][/color]\n[b]%s[/b]  %s  %s" % [
			grade_text, variant_name, stance_id, phase]
	_label_score.text = "Current: %s / %s / %s / %s    Score: %s" % [
		class_key, stance_id, variant_name, phase, current_score]
	var coverage: Dictionary = _coverage_for_stance(stance_id)
	var selected: String = _selected_stance_for_class(class_key)
	var active_text: String = selected if selected != "" else "none"
	var lines: Array = coverage.get("lines", [])
	var missing: Array = coverage.get("missing", [])
	var text: String = "Selected for game: %s\nCoverage: %d/%d\n%s" % [
		active_text,
		int(coverage.get("completed", 0)),
		int(coverage.get("total", 0)),
		"\n".join(lines),
	]
	if not missing.is_empty():
		text += "\nMissing: %s" % ", ".join(missing.slice(0, 8))
		if missing.size() > 8:
			text += " ..."
	var import_warning := _custom_import_warning(stance_id)
	if import_warning != "":
		text += "\n" + import_warning
	_label_completion.text = text
	if _use_stance_button != null:
		_use_stance_button.disabled = _stance_ids.is_empty()
		_use_stance_button.text = "Use Stance (%d/%d)" % [
			int(coverage.get("completed", 0)),
			int(coverage.get("total", 0)),
		]
	if _save_stance_button != null:
		_save_stance_button.disabled = _stance_ids.is_empty()
	if _delete_stance_button != null:
		_delete_stance_button.disabled = not _is_local_custom_stance_id(stance_id)

func _on_save_stance_pressed() -> void:
	if _stance_ids.is_empty():
		return
	var class_key := _current_class_key()
	var variant: Dictionary = CLASSES[_class_idx]["variants"][_variant_idx]
	var anim_name := String(variant.get("anim", &"idle"))
	var stance_id := _current_stance_key()
	if not _is_local_custom_stance_id(stance_id):
		var source_owner := _custom_stance_owner(stance_id)
		var source_stance := stance_id
		var class_block_v: Variant = _custom_stances.get(class_key, {})
		if typeof(class_block_v) != TYPE_DICTIONARY:
			class_block_v = {}
		var class_block: Dictionary = class_block_v
		var base := "%s_%s_%d" % [class_key, anim_name, int(Time.get_unix_time_from_system())]
		var new_stance_id := "custom_" + base.replace(" ", "_")
		class_block[new_stance_id] = {
			"class": class_key,
			"bucket": String(_current_bucket()),
			"anim": anim_name,
			"source_class": source_owner if source_owner != "" else class_key,
			"source_stance": source_stance,
			"variant": String(variant.get("name", "")),
			"shareable": true,
			"created": Time.get_datetime_string_from_system(),
		}
		_custom_stances[class_key] = class_block
		_write_json_dict(CUSTOM_STANCES_FILE, _custom_stances)
		if source_owner != "":
			_copy_recommended_stance(source_owner, source_stance, class_key, new_stance_id)
		stance_id = new_stance_id
		_stance_ids.append(StringName(stance_id))
		_stance_idx = _stance_ids.size() - 1
		_refresh_picker_options()
	_save_recommended()

func _on_delete_stance_pressed() -> void:
	var stance_id := _current_stance_key()
	if not _is_local_custom_stance_id(stance_id):
		return
	var class_key := _current_class_key()
	var class_block: Dictionary = _custom_stances.get(class_key, {})
	class_block.erase(stance_id)
	_custom_stances[class_key] = class_block
	_write_json_dict(CUSTOM_STANCES_FILE, _custom_stances)
	var selected_v: Variant = _selected_stances.get(class_key, {})
	if typeof(selected_v) == TYPE_DICTIONARY and String((selected_v as Dictionary).get("stance", "")) == stance_id:
		_selected_stances.erase(class_key)
		_write_json_dict(SELECTED_STANCES_FILE, _selected_stances)
	_stance_idx = 0
	_load_current(_scrub_time)

func _copy_recommended_stance(source_class: String, source_stance: String,
		target_class: String, target_stance: String) -> void:
	var recommended := _read_json_dict("res://tmp/recommended_stances.json")
	var src_class_v: Variant = recommended.get(source_class, {})
	if typeof(src_class_v) != TYPE_DICTIONARY:
		return
	var src_block_v: Variant = (src_class_v as Dictionary).get(source_stance, {})
	if typeof(src_block_v) != TYPE_DICTIONARY:
		return
	if not recommended.has(target_class):
		recommended[target_class] = {}
	recommended[target_class][target_stance] = (src_block_v as Dictionary).duplicate(true)
	_write_json_dict("res://tmp/recommended_stances.json", recommended)

func _on_use_stance_pressed() -> void:
	if _stance_ids.is_empty():
		return
	var class_key: String = _current_class_key()
	var stance_id: String = _current_stance_key()
	var coverage: Dictionary = _coverage_for_stance(stance_id)
	var missing: Array = coverage.get("missing", [])
	if not missing.is_empty():
		var msg: String = "blocked: score required animations first: %s" % ", ".join(missing.slice(0, 10))
		if missing.size() > 10:
			msg += " ..."
		print("[pose_tuner] %s" % msg)
		_label_completion.text = msg
		return
	var selected_record := {
		"class": class_key,
		"bucket": String(_current_bucket()),
		"stance": stance_id,
		"completed": int(coverage.get("completed", 0)),
		"total": int(coverage.get("total", 0)),
		"required": coverage.get("required", []),
		"timestamp": Time.get_datetime_string_from_system(),
	}
	var bucket := _current_bucket()
	if bucket == &"classes":
		_selected_stances[class_key] = selected_record
	else:
		var bucket_key := String(bucket)
		# has() gate — see _on_launch_game_pressed: `.get(k,{})` masks a
		# missing key and the direct index below would then crash.
		if not _selected_stances.has(bucket_key) or typeof(_selected_stances[bucket_key]) != TYPE_DICTIONARY:
			_selected_stances[bucket_key] = {}
		(_selected_stances[bucket_key] as Dictionary)[class_key] = selected_record
	_write_json_dict(SELECTED_STANCES_FILE, _selected_stances)
	print("[pose_tuner] selected %s/%s for game" % [class_key, stance_id])
	_refresh_picker_options()
	_refresh_score_panel()

func _on_launch_game_pressed() -> void:
	# REPLACE, don't flood: close any Maw window we previously spawned
	# before opening a new one. Repeated launches used to stack a new game
	# process+window each click until the machine ran out of memory; now
	# there is at most one preview window at a time (close it and launch
	# again to swap sprites).
	_kill_spawned_previews()
	# Launch ANY sprite into The Maw — player class, enemy, or NPC.
	# Non-class sprites spawn next to a default-Myrmidon observer so a
	# wraith can be watched drifting / a boss looming in real engine
	# motion, not just the static pose-tuner viewport.
	var bucket := _current_bucket()
	var sprite_key: String = _current_class_key()
	var stance_id: String = _current_stance_key()
	var record := {
		"class": sprite_key,
		"bucket": String(bucket),
		"stance": stance_id,
		"debug_launch": true,
		"timestamp": Time.get_datetime_string_from_system(),
	}
	if bucket == &"classes":
		_selected_stances[sprite_key] = record
	else:
		var bk := String(bucket)
		# NOTE: `.get(bk, {})` returns the default {} when the key is
		# MISSING, so a typeof check alone passes without creating the
		# key — then the direct `[bk]` read below crashes. Gate on
		# has() so the bucket truly exists before we index it.
		if not _selected_stances.has(bk) or typeof(_selected_stances[bk]) != TYPE_DICTIONARY:
			_selected_stances[bk] = {}
		(_selected_stances[bk] as Dictionary)[sprite_key] = record
	_write_json_dict(SELECTED_STANCES_FILE, _selected_stances)
	# class_id is the observer's class; for a class target it IS the
	# target, otherwise a default Myrmidon stands in.
	var class_id := sprite_key if bucket == &"classes" else "myrmidon"
	# The procedural sprite scene to PLAY AS (non-class sprites swap the
	# player avatar to this; class sprites ride in via assign_class).
	var sprite_scene := String(CLASSES[_class_idx].get("scene", ""))
	_write_json_dict(LAUNCH_FILE, {
		"sprite_id": sprite_key,
		"bucket": String(bucket),
		"class_id": class_id,
		"sprite_scene": sprite_scene,
		"stance_id": stance_id,
		"zone_id": "forsaken_depths",
		"arrival_marker": "DepthsEntry",
		"source": "pose_tuner",
		"input_lock_until_click": true,
		# The spawned window watches this heartbeat file and self-closes
		# when it goes stale — covers Ctrl+C, which can't run _exit_tree.
		"heartbeat_file": HEARTBEAT_FILE,
		"timestamp": Time.get_datetime_string_from_system(),
	})
	_write_heartbeat()  # fresh stamp so the new window starts trusting us
	var exe := OS.get_executable_path()
	var project_dir := ProjectSettings.globalize_path("res://")
	# Pass --debug=sprite (after the `--` user-arg separator) so the
	# spawned game prints the editor-launch + preview-spawn breadcrumbs,
	# making a failed preview diagnosable from its console.
	var pid := OS.create_process(exe, [
		"--path", project_dir, "res://scenes/game.tscn", "--", "--debug=sprite",
	])
	if pid > 0:
		_spawned_preview_pids.append(pid)
	print("[pose_tuner] launch in Maw sprite=%s bucket=%s stance=%s pid=%d" % [sprite_key, bucket, stance_id, pid])

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
#   - weapon / arm / hand / claw nodes — drag updates their position
#     in parent-local space (so children move with them).

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
			if _drag_node != null:
				_push_undo()
			_drag_last_mouse = mb.position
			_drag_last_mouse_prev = mb.position
		else:
			_drag_node = null
	elif event is InputEventMouseMotion and _drag_node != null:
		var mm: InputEventMouseMotion = event
		_drag_last_mouse = mm.position
		var drag_node_name: String = String(_drag_node.name)
		var should_force_pin := _drag_node is Marker2D
		if drag_node_name.ends_with("ElbowPivot") or drag_node_name.ends_with("KneePivot"):
			_rotate_joint_parent_toward_mouse(_drag_node, mm.position)
		elif _is_terminal_drag_part(_drag_node):
			var rot_node: Node2D = _drag_node
			if not drag_node_name.contains("Finger"):
				rot_node = _drag_node.get_parent() as Node2D
			if rot_node != null:
				_rotate_node_toward_mouse(rot_node, mm.position)
		else:
			# Marker / weapon-arm / body node — translate in parent-local space.
			var delta_screen: Vector2 = mm.position - _drag_last_mouse_prev
			var local_delta: Vector2 = delta_screen / SPRITE_SCALE
			_drag_node.position += local_delta
			_sync_sliders_for(_drag_node)
		_drag_last_mouse_prev = mm.position
		if should_force_pin:
			_force_pin_pass()

func _rotate_joint_parent_toward_mouse(joint_node: Node2D, mouse_pos: Vector2) -> void:
	var parent_node: Node2D = joint_node.get_parent() as Node2D
	if parent_node == null:
		return
	var to_cursor: Vector2 = (mouse_pos - parent_node.global_position) / SPRITE_SCALE
	if to_cursor.length() > 0.01:
		parent_node.rotation = atan2(-to_cursor.x, to_cursor.y)
		_sync_sliders_for(parent_node)

func _rotate_node_toward_mouse(rot_node: Node2D, mouse_pos: Vector2) -> void:
	var to_cursor: Vector2 = (mouse_pos - rot_node.global_position) / SPRITE_SCALE
	if to_cursor.length() > 0.01:
		rot_node.rotation = atan2(-to_cursor.x, to_cursor.y)
		_sync_sliders_for(rot_node)

func _is_terminal_drag_part(n: Node2D) -> bool:
	var s := String(n.name)
	return s.contains("Hand") or s.contains("Claw") or s.contains("Finger")

func _force_pin_pass() -> void:
	if _sprite == null:
		return
	var pins = _sprite.get(&"PIN_TABLE") if &"PIN_TABLE" in _sprite else null
	if pins == null:
		return
	var body: Node2D = _sprite.get_node_or_null(^"Body") as Node2D
	if body == null:
		return
	var cur_anim: StringName = _anim.current_animation if _anim != null else &""
	HumanRig.apply_pins(_sprite, body, pins, cur_anim)

# Find the closest draggable (Marker2D or *Arm Node2D) within
# DRAG_HIT_RADIUS of mouse_pos (in container/viewport coords).
func _find_draggable_under(mouse_pos: Vector2) -> Node2D:
	var nearest_marker: Node2D = null
	var marker_d := 8.0
	for n in _enumerate_draggables(_sprite):
		if n is Marker2D:
			var md := mouse_pos.distance_to(n.global_position)
			if md < marker_d:
				marker_d = md
				nearest_marker = n
	if nearest_marker != null:
		return nearest_marker
	var best: Node2D = null
	var best_d: float = DRAG_HIT_RADIUS
	for n in _enumerate_draggables(_sprite):
		var d := _draggable_hit_distance(n, mouse_pos)
		if d < best_d:
			best_d = d
			best = n
	return best

func _draggable_hit_distance(n: Node2D, mouse_pos: Vector2) -> float:
	var best := mouse_pos.distance_to(n.global_position)
	if _is_weapon_path(_path_for(n)) or String(n.name) == "ArmAnchor":
		best = minf(best, _shape_hit_distance(n, mouse_pos))
	return best

func _shape_hit_distance(node: Node, mouse_pos: Vector2) -> float:
	var best := INF
	if node is CanvasItem and not (node as CanvasItem).visible:
		return best
	if node is Polygon2D:
		var poly := (node as Polygon2D).polygon
		for i in range(poly.size()):
			var a := (node as Polygon2D).to_global(poly[i])
			var b := (node as Polygon2D).to_global(poly[(i + 1) % poly.size()])
			best = minf(best, _distance_to_segment(mouse_pos, a, b))
	elif node is Line2D:
		var pts := (node as Line2D).points
		for i in range(max(0, pts.size() - 1)):
			var a := (node as Line2D).to_global(pts[i])
			var b := (node as Line2D).to_global(pts[i + 1])
			best = minf(best, _distance_to_segment(mouse_pos, a, b))
	elif node is Marker2D:
		best = minf(best, mouse_pos.distance_to((node as Marker2D).global_position))
	for child in node.get_children():
		if String(child.name).begins_with("_"):
			continue
		best = minf(best, _shape_hit_distance(child, mouse_pos))
	return best

func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var denom := ab.length_squared()
	if denom <= 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / denom, 0.0, 1.0)
	return p.distance_to(a + ab * t)

# Walk the sprite tree collecting Markers + *Arm Node2Ds + joint
# pivots (ElbowPivot, KneePivot). Drag behavior diverges:
#   - Marker2D / *Arm: drag updates the node's .position directly
#     (parent-local translation).
#   - ElbowPivot / KneePivot: drag updates the PARENT's .rotation so
#     the joint visually lands at the cursor. The pivot itself has a
#     fixed position relative to its parent (e.g. (0, 10)) so direct
#     translation would tear the chain apart.
func _enumerate_draggables(root: Node) -> Array:
	var out: Array = []
	for child in root.get_children():
		if child is Marker2D:
			out.append(child)
		elif child is Node2D:
			var n: String = String(child.name)
			if n.ends_with("ElbowPivot") or n.ends_with("KneePivot"):
				out.append(child)
			elif _wants_position_slider(child.name) or n.contains("ArmR") or n.contains("ArmL") or n.contains("Finger"):
				out.append(child)
		out.append_array(_enumerate_draggables(child))
	return out

# After a drag, find the matching slider entry and sync slider+SpinBox
# values so the sidebar reflects the new position.
func _sync_sliders_for(n: Node2D) -> void:
	var target_path: String = _path_for(n)
	for entry in _slider_entries:
		if entry["path"] != target_path:
			continue
		var controls: Array = entry["controls"]
		if entry["kind"] == "pos":
			if controls.size() >= 1:
				controls[0].set_value_no_signal(n.position.x)
			if controls.size() >= 2:
				controls[1].set_value_no_signal(n.position.y)
			if controls.size() >= 3:
				controls[2].set_value_no_signal(n.position.x)
			if controls.size() >= 4:
				controls[3].set_value_no_signal(n.position.y)
		elif entry["kind"] == "rot":
			var deg := rad_to_deg(n.rotation)
			if controls.size() >= 1:
				controls[0].set_value_no_signal(deg)
			if controls.size() >= 2:
				controls[1].set_value_no_signal(deg)
		elif entry["kind"] == "scale":
			if controls.size() >= 1:
				controls[0].set_value_no_signal(n.scale.x)
			if controls.size() >= 2:
				controls[1].set_value_no_signal(n.scale.y)
			if controls.size() >= 3:
				controls[2].set_value_no_signal(n.scale.x)
			if controls.size() >= 4:
				controls[3].set_value_no_signal(n.scale.y)
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

# F4 — advance the "active" preset under the current
# (class, stance, anim, phase) tuple, then reload the sprite so the
# next preset becomes the rendered pose. Wraps around.
func _cycle_preset() -> void:
	var cls: Dictionary = CLASSES[_class_idx]
	var class_key: String = String(cls["id"])
	var stance_label: String = String(_stance_ids[_stance_idx]) if _stance_ids.size() > 0 else "default"
	var variant: Dictionary = cls["variants"][_variant_idx]
	var anim_name: String = String(variant.get("anim", &"idle"))
	var phase_key: String = String(_current_phase())
	var f := FileAccess.open("res://tmp/recommended_stances.json", FileAccess.READ)
	if f == null:
		print("[pose_tuner] no presets file yet")
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var recommended: Dictionary = parsed
	# Look in primary anim slot; fall back to legacy "global" bucket
	# if nothing's there yet.
	var stance_block: Dictionary = recommended.get(class_key, {}).get(stance_label, {})
	var anim_block: Dictionary = stance_block.get(anim_name, {})
	if typeof(anim_block) != TYPE_DICTIONARY or anim_block.is_empty():
		anim_block = stance_block.get("global", {})
	var slot: Variant = anim_block.get(phase_key, null) if typeof(anim_block) == TYPE_DICTIONARY else null
	# Legacy flat snapshot at stance/phase — migrate on the fly.
	if slot == null:
		var legacy_flat: Variant = stance_block.get(phase_key, null)
		if typeof(legacy_flat) == TYPE_DICTIONARY:
			slot = { "presets": { "legacy": legacy_flat }, "active": "legacy" }
	if typeof(slot) != TYPE_DICTIONARY or not slot.has("presets"):
		print("[pose_tuner] no presets at %s/%s/%s/%s" % [class_key, stance_label, anim_name, phase_key])
		return
	var presets: Dictionary = slot["presets"]
	var keys: Array = presets.keys()
	if keys.is_empty():
		return
	var active: String = String(slot.get("active", ""))
	var idx: int = keys.find(active)
	var next_idx: int = (idx + 1) % keys.size()
	slot["active"] = String(keys[next_idx])
	# Write back.
	var w := FileAccess.open("res://tmp/recommended_stances.json", FileAccess.WRITE)
	if w != null:
		w.store_string(JSON.stringify(recommended, "  "))
		w.close()
	print("[pose_tuner] preset → %s (%d/%d)" % [slot["active"], next_idx + 1, keys.size()])
	if _label_score != null:
		_label_score.text = "Preset: %s (%d/%d)" % [slot["active"], next_idx + 1, keys.size()]
	_load_current()

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
	var key: String = _score_key(String(cls["id"]), String(stance_id), String(variant["name"]), String(phase))
	_load_scores_from_disk()
	var scores: Dictionary = _scores
	scores[key] = {
		"score": score,
		"class": String(cls["id"]),
		"bucket": String(cls.get("bucket", &"classes")),
		"stance": String(stance_id),
		"variant": String(variant["name"]),
		"phase": String(phase),
		"t": _scrub_time,
		"timestamp": Time.get_datetime_string_from_system(),
	}
	_scores = scores
	_write_json_dict(SCORE_FILE, _scores)
	print("[pose_tuner] scored %s = %d" % [key, score])
	_refresh_picker_options()
	_refresh_score_panel()

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
	# Save key uses the variant's anim name (idle/walk/attack), not
	# _anim.current_animation — the latter can be empty if the user
	# saves before play settles. Variant comes from the CLASSES catalog
	# which is always populated.
	var variant: Dictionary = cls["variants"][_variant_idx]
	var anim_name: String = String(variant.get("anim", &"idle"))
	# Snapshot EVERY tunable transform — arms (shoulder + elbow rotations)
	# and the weapon-arm subtree (position + rotation + every marker
	# position). Schema is keyed by tree path so apply-side knows
	# exactly which node each value targets, and so the JSON is self-
	# describing if a future class restructures its tree.
	var snap: Dictionary = {
		"rotations": {},
		"positions": {},
		"scales": {},
		"markers": {},
	}
	for entry_v in _slider_entries:
		var entry: Dictionary = entry_v
		var path: String = String(entry.get("path", ""))
		if path == "":
			continue
		var n := _sprite.get_node_or_null(NodePath(path)) as Node2D
		if n == null:
			continue
		if String(entry.get("kind", "")) == "rot":
			snap["rotations"][path] = n.rotation
		elif String(entry.get("kind", "")) == "pos":
			snap["positions"][path] = [n.position.x, n.position.y]
			if n is Marker2D:
				snap["markers"][path] = [n.position.x, n.position.y]
		elif String(entry.get("kind", "")) == "scale":
			snap["scales"][path] = [n.scale.x, n.scale.y]
	# Both arms — shoulders + elbow pivots.
	for arm_path in ["Body/ArmLShoulder", "Body/ArmRShoulder"]:
		var shoulder: Node2D = _sprite.get_node_or_null(NodePath(arm_path)) as Node2D
		if shoulder != null:
			snap["rotations"][arm_path] = shoulder.rotation
			var elbow_path: String = arm_path + "/ElbowPivot"
			var elbow: Node2D = _sprite.get_node_or_null(NodePath(elbow_path)) as Node2D
			if elbow != null:
				snap["rotations"][elbow_path] = elbow.rotation
	# Weapon arm + markers.
	var weapon_arm: Node2D = _find_weapon_arm(_sprite)
	if weapon_arm != null:
		var w_path: String = _path_for(weapon_arm)
		snap["positions"][w_path] = [weapon_arm.position.x, weapon_arm.position.y]
		snap["rotations"][w_path] = weapon_arm.rotation
		for child in weapon_arm.get_children():
			if child is Marker2D:
				snap["markers"][String(child.name)] = [child.position.x, child.position.y]
		# Back-compat fields so older readers still work.
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
	# Stage 17.8 — each S press writes a new TIMESTAMPED preset under
	# the phase. The "active" key tracks which preset to load. F4
	# cycles by advancing the active pointer.
	var phase_key: String = String(phase)
	if not recommended[class_key][stance_label][anim_name].has(phase_key):
		recommended[class_key][stance_label][anim_name][phase_key] = {
			"presets": {}, "active": "",
		}
	# Tolerate older flat snapshots: migrate to presets bucket.
	var slot: Variant = recommended[class_key][stance_label][anim_name][phase_key]
	if typeof(slot) != TYPE_DICTIONARY or not slot.has("presets"):
		recommended[class_key][stance_label][anim_name][phase_key] = {
			"presets": { "legacy": slot if typeof(slot) == TYPE_DICTIONARY else {} },
			"active": "legacy",
		}
		slot = recommended[class_key][stance_label][anim_name][phase_key]
	var ts: String = Time.get_datetime_string_from_system().replace(":", "-")
	slot["presets"][ts] = snap
	slot["active"] = ts
	DirAccess.make_dir_recursive_absolute("res://tmp")
	var w := FileAccess.open("res://tmp/recommended_stances.json", FileAccess.WRITE)
	if w != null:
		w.store_string(JSON.stringify(recommended, "  "))
		w.close()
	var msg: String = "saved %s/%s/%s/%s" % [class_key, stance_label, anim_name, String(phase)]
	print("[pose_tuner] %s" % msg)
	if _label_score != null:
		_label_score.text = "Recommended " + msg
	# Keep the current edited sprite intact. Reloading here discards the
	# in-progress pose and makes a single-phase save feel destructive.
	_refresh_picker_options()
	_refresh_score_panel()

# Walk the sprite tree looking for the first Node2D whose name ends in
# StaffArm/SpearArm/BowArm — the weapon-arm convention used by all
# class/enemy/NPC sprites.
func _find_weapon_arm(root: Node) -> Node2D:
	for child in root.get_children():
		var s: String = String(child.name)
		if child is Node2D and (s.ends_with("BowArm") or s.ends_with("StaffArm") \
				or s.ends_with("SpearArm") or s.ends_with("WandArm") \
				or s == "Staff" or s == "ArmAnchor"):
			return child
		var nested: Node2D = _find_weapon_arm(child)
		if nested != null:
			return nested
	return null

# Phase classification — three save slots BEGIN/MIDDLE/END, banded
# by scrub-time fraction. Uses _time_slider.max_value as the length
# source so the classification stays correct even after the animation
# has played past its end (current_animation_length goes to 0 then).
func _current_phase() -> StringName:
	if _time_slider == null:
		return &"BEGIN"
	var length: float = _time_slider.max_value
	if length <= 0.01:
		return &"BEGIN"
	var f: float = _scrub_time / length
	if f < 0.20:    return &"BEGIN"
	if f < 0.65:    return &"MIDDLE"
	return &"END"

# =========================================================================
# Hotkeys
# =========================================================================

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.ctrl_pressed and event.keycode == KEY_Z:
		_undo_pose()
		get_viewport().set_input_as_handled()
		return
	match event.keycode:
		KEY_F1:
			_class_idx = (_class_idx + 1) % CLASSES.size()
			_variant_idx = 0
			_stance_idx = 0
			_load_current()
		KEY_F2:
			var n: int = CLASSES[_class_idx]["variants"].size()
			_variant_idx = (_variant_idx + 1) % n
			_load_current()
		KEY_F3:
			if _stance_ids.size() > 0:
				_stance_idx = (_stance_idx + 1) % _stance_ids.size()
				_load_current()
		KEY_F4:
			_cycle_preset()
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
