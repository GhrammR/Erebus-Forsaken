class_name SpriteRuntime2D extends Node2D
## Shared runtime for procedural scene-authored sprites.
## Provides canonical idle/walk/attack/cast/hit/die animations,
## stance selection, and pose-tuner override injection.

const SpriteMotionStances = preload("res://scripts/systems/stances/sprite_motion_stances.gd")
const SpriteOverrides = preload("res://scripts/systems/sprite_overrides.gd")
const StanceSelection = preload("res://scripts/systems/stance_selection.gd")

@export var sprite_id: StringName = &""
@export var stance_bucket: StringName = &""
@export var stance_id: StringName = SpriteMotionStances.DEFAULT_STANCE
@export var auto_build_animations: bool = true
@export var auto_play_idle: bool = true

var _anim: AnimationPlayer = null
var _motion: Dictionary = {}
var _per_anim_config: Dictionary = {}
var _replaying_for_injection: bool = false

func _ready() -> void:
	setup_sprite_runtime()

func setup_sprite_runtime() -> void:
	if sprite_id == &"":
		sprite_id = _infer_sprite_id()
	if stance_bucket != &"":
		stance_id = StanceSelection.selected_for_entity(
				stance_bucket, sprite_id, stance_id, SpriteMotionStances.all_ids())
	else:
		stance_id = StanceSelection.selected_for_key(
				String(sprite_id), stance_id, SpriteMotionStances.all_ids())
	_motion = SpriteMotionStances.get_stance(stance_id)
	_anim = _ensure_animation_player()
	if auto_build_animations:
		_install_runtime_animations()
	_per_anim_config = SpriteOverrides.load_for_class(sprite_id, stance_id)
	if not _anim.animation_started.is_connected(_on_anim_started):
		_anim.animation_started.connect(_on_anim_started)
	if auto_play_idle and _anim.has_animation(&"idle"):
		_anim.play(&"idle")

func _ensure_animation_player() -> AnimationPlayer:
	var existing := get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if existing != null:
		return existing
	var created := AnimationPlayer.new()
	created.name = "AnimationPlayer"
	add_child(created)
	return created

func _install_runtime_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle", _anim_idle())
	lib.add_animation(&"walk", _anim_walk())
	lib.add_animation(&"attack", _anim_attack())
	lib.add_animation(&"cast", _anim_cast())
	lib.add_animation(&"hit", _anim_hit())
	lib.add_animation(&"die", _anim_die())
	if _anim.has_animation_library(&""):
		_anim.remove_animation_library(&"")
	_anim.add_animation_library(&"", lib)

func _on_anim_started(anim_name: StringName) -> void:
	if _replaying_for_injection:
		return
	var cfg: Dictionary = _per_anim_config.get(String(anim_name), {})
	if not SpriteOverrides.is_tuned(cfg):
		return
	var lib: AnimationLibrary = _anim.get_animation_library(&"")
	if lib == null or not lib.has_animation(anim_name):
		return
	SpriteOverrides.inject_tuned_transforms(lib.get_animation(anim_name), cfg)
	_replaying_for_injection = true
	_anim.play(anim_name)
	_replaying_for_injection = false

func _anim_idle() -> Animation:
	var a := Animation.new()
	a.length = float(_motion.get("idle_len", 1.6))
	a.loop_mode = Animation.LOOP_LINEAR
	var body := _body_path()
	_key_vec2(a, NodePath("%s:position" % body), [0.0, a.length * 0.5, a.length],
			[Vector2.ZERO, Vector2(0, float(_motion.get("idle_bob", -1.2))), Vector2.ZERO])
	_key_float(a, NodePath("%s:rotation" % body), [0.0, a.length * 0.5, a.length],
			[0.0, float(_motion.get("idle_sway", 0.015)), 0.0])
	for path in _shadow_paths():
		_key_vec2(a, NodePath("%s:scale" % path), [0.0, a.length * 0.5, a.length],
				[Vector2.ONE, Vector2(0.90, 0.78), Vector2.ONE])
		_key_color(a, NodePath("%s:modulate" % path), [0.0, a.length * 0.5, a.length],
				[Color(1, 1, 1, 1), Color(1, 1, 1, 0.72), Color(1, 1, 1, 1)])
	for path in _glow_paths():
		_key_color(a, NodePath("%s:modulate" % path), [0.0, a.length * 0.5, a.length],
				[Color(1, 1, 1, 1), Color(1.25, 1.35, 1.15, 1), Color(1, 1, 1, 1)])
	return a

func _anim_walk() -> Animation:
	var a := Animation.new()
	a.length = float(_motion.get("walk_len", 0.55))
	a.loop_mode = Animation.LOOP_LINEAR
	var body := _body_path()
	if _is_wraith_sprite():
		var bob := float(_motion.get("walk_bob", -2.8))
		var sway := float(_motion.get("walk_sway", 0.12))
		_key_vec2(a, NodePath("%s:position" % body),
				[0.0, a.length * 0.25, a.length * 0.5, a.length * 0.75, a.length],
				[Vector2.ZERO, Vector2(2, bob), Vector2(0, bob * 0.35), Vector2(-2, bob), Vector2.ZERO])
		_key_float(a, NodePath("%s:rotation" % body),
				[0.0, a.length * 0.25, a.length * 0.5, a.length * 0.75, a.length],
				[0.0, sway, 0.0, -sway, 0.0])
		for path in _paths_matching(["TatteredHem", "CloakInner", "Cloak", "Robe"]):
			_key_vec2(a, NodePath("%s:position" % path),
					[0.0, a.length * 0.5, a.length],
					[Vector2.ZERO, Vector2(0, 1.8), Vector2.ZERO])
			_key_float(a, NodePath("%s:rotation" % path),
					[0.0, a.length * 0.5, a.length],
					[0.0, -sway * 0.45, 0.0])
		for path in _shadow_paths():
			_key_vec2(a, NodePath("%s:scale" % path),
					[0.0, a.length * 0.25, a.length * 0.5, a.length * 0.75, a.length],
					[Vector2(1.05, 0.88), Vector2(0.82, 0.66), Vector2(1.12, 0.92), Vector2(0.82, 0.66), Vector2(1.05, 0.88)])
			_key_color(a, NodePath("%s:modulate" % path),
					[0.0, a.length * 0.25, a.length * 0.5, a.length * 0.75, a.length],
					[Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.58), Color(1, 1, 1, 0.90), Color(1, 1, 1, 0.58), Color(1, 1, 1, 0.95)])
		return a
	_key_vec2(a, NodePath("%s:position" % body), [0.0, a.length * 0.5, a.length],
			[Vector2.ZERO, Vector2(0, float(_motion.get("walk_bob", -2.0))), Vector2.ZERO])
	_key_float(a, NodePath("%s:rotation" % body), [0.0, a.length * 0.25, a.length * 0.5, a.length * 0.75, a.length],
			[0.0, float(_motion.get("walk_sway", 0.06)), 0.0, -float(_motion.get("walk_sway", 0.06)), 0.0])
	for path in _paths_matching(["LegLHip"]):
		_key_float(a, NodePath("%s:rotation" % path), [0.0, a.length * 0.5, a.length],
				[0.10, -0.12, 0.10])
	for path in _paths_matching(["LegRHip"]):
		_key_float(a, NodePath("%s:rotation" % path), [0.0, a.length * 0.5, a.length],
				[-0.12, 0.10, -0.12])
	for path in _paths_matching(["KneePivot"]):
		if String(path).contains("LegL"):
			_key_float(a, NodePath("%s:rotation" % path), [0.0, a.length * 0.5, a.length],
					[0.14, -0.06, 0.14])
		else:
			_key_float(a, NodePath("%s:rotation" % path), [0.0, a.length * 0.5, a.length],
					[-0.06, 0.14, -0.06])
	for path in _shadow_paths():
		_key_vec2(a, NodePath("%s:scale" % path), [0.0, a.length * 0.5, a.length],
				[Vector2.ONE, Vector2(0.94, 0.82), Vector2.ONE])
	return a

func _anim_attack() -> Animation:
	var a := Animation.new()
	a.length = float(_motion.get("attack_len", 0.42))
	a.loop_mode = Animation.LOOP_NONE
	var body := _body_path()
	_key_vec2(a, NodePath("%s:position" % body), [0.0, a.length * 0.42, a.length],
			[Vector2.ZERO, Vector2(2, -1), Vector2.ZERO])
	_key_float(a, NodePath("%s:rotation" % body), [0.0, a.length * 0.42, a.length],
			[0.0, 0.04, 0.0])
	var attack_rot := float(_motion.get("attack_rot", -0.85))
	var attack_paths := _attack_paths()
	if attack_paths.is_empty():
		attack_paths = [body]
	for path in attack_paths:
		var path_s := String(path)
		var sign := -1.0 if path_s.contains("ArmL") or path_s.contains("ClawL") or path_s.contains("HandL") else 1.0
		_key_float(a, NodePath("%s:rotation" % path), [0.0, a.length * 0.28, a.length * 0.55, a.length],
				[0.0, attack_rot * sign, -attack_rot * 0.35 * sign, 0.0])
	return a

func _anim_cast() -> Animation:
	if sprite_id == &"act_boss":
		return _anim_boss_taunt_cast()
	var a := Animation.new()
	a.length = float(_motion.get("cast_len", 0.65))
	a.loop_mode = Animation.LOOP_NONE
	var pulse := float(_motion.get("cast_pulse", 1.5))
	var body := _body_path()
	_key_color(a, NodePath("%s:modulate" % body), [0.0, a.length * 0.35, a.length * 0.72, a.length],
			[Color(1, 1, 1, 1), Color(1.2, 1.25, 1.45, 1), Color(1.2, 1.25, 1.45, 1), Color(1, 1, 1, 1)])
	for path in _glow_paths():
		_key_vec2(a, NodePath("%s:scale" % path), [0.0, a.length * 0.35, a.length],
				[Vector2.ONE, Vector2.ONE * pulse, Vector2.ONE])
		_key_color(a, NodePath("%s:modulate" % path), [0.0, a.length * 0.35, a.length],
				[Color(1, 1, 1, 1), Color(1.8, 2.0, 1.4, 1), Color(1, 1, 1, 1)])
	return a


func _anim_boss_taunt_cast() -> Animation:
	var a := Animation.new()
	a.length = maxf(float(_motion.get("cast_len", 0.90)), 1.05)
	a.loop_mode = Animation.LOOP_NONE
	var body := _body_path()
	_key_color(a, NodePath("%s:modulate" % body), [0.0, a.length * 0.30, a.length * 0.80, a.length],
			[Color(1, 1, 1, 1), Color(1.45, 1.05, 1.85, 1), Color(1.45, 1.05, 1.85, 1), Color(1, 1, 1, 1)])
	_key_vec2(a, NodePath("%s:position" % body), [0.0, a.length * 0.32, a.length],
			[Vector2.ZERO, Vector2(0, -3), Vector2.ZERO])
	for path in _paths_matching(["ArmL", "ArmR"]):
		var path_s := String(path)
		var side := -1.0 if path_s.contains("ArmL") else 1.0
		var lift := -1.08 if path_s.contains("Top") else (-0.78 if path_s.contains("Mid") else -0.48)
		_key_float(a, NodePath("%s:rotation" % path), [0.0, a.length * 0.24, a.length * 0.78, a.length],
				[0.0, lift * side, lift * side, 0.0])
	for path in _paths_matching(["ElbowPivot"]):
		var path_s := String(path)
		var side := -1.0 if path_s.contains("ArmL") else 1.0
		_key_float(a, NodePath("%s:rotation" % path), [0.0, a.length * 0.24, a.length * 0.78, a.length],
				[0.0, 0.42 * side, 0.42 * side, 0.0])
	for path in _paths_matching(["MiddleFinger"]):
		_key_vec2(a, NodePath("%s:scale" % path), [0.0, a.length * 0.24, a.length * 0.78, a.length],
				[Vector2.ONE, Vector2(1.0, 1.38), Vector2(1.0, 1.38), Vector2.ONE])
	return a

func _anim_hit() -> Animation:
	var a := Animation.new()
	a.length = 0.18
	a.loop_mode = Animation.LOOP_NONE
	_key_color(a, NodePath("%s:modulate" % _body_path()), [0.0, 0.05, 0.18],
			[Color(1, 1, 1, 1), Color(2.2, 1.2, 1.4, 1), Color(1, 1, 1, 1)])
	return a

func _anim_die() -> Animation:
	var a := Animation.new()
	a.length = 0.75
	a.loop_mode = Animation.LOOP_NONE
	var body := _body_path()
	_key_float(a, NodePath("%s:rotation" % body), [0.0, a.length], [0.0, 1.45])
	_key_color(a, NodePath("%s:modulate" % body), [0.0, a.length],
			[Color(1, 1, 1, 1), Color(0.4, 0.4, 0.45, 0.0)])
	return a

func _body_path() -> String:
	return "Body" if has_node(^"Body") else "."

func _attack_paths() -> Array[String]:
	var paths: Array[String] = []
	for token in ["ArmR", "ArmL", "HandR", "HandL", "ClawR", "ClawL", "Staff", "WandArm", "ArmAnchor"]:
		for path in _paths_matching([token]):
			if not paths.has(path):
				paths.append(path)
	return paths

func _glow_paths() -> Array[String]:
	var paths: Array[String] = []
	for token in ["Glow", "Orb", "EyeGlow", "EyeL", "EyeR", "StaffOrb"]:
		for path in _paths_matching([token]):
			if not paths.has(path):
				paths.append(path)
	return paths

func _is_wraith_sprite() -> bool:
	return sprite_id == &"shade_wretch" or sprite_id == &"bog_caller" or has_node(^"Body/TatteredHem")

func _shadow_paths() -> Array[String]:
	var paths: Array[String] = []
	for path in _paths_matching(["Shadow"]):
		if not paths.has(path):
			paths.append(path)
	return paths

func _paths_matching(tokens: Array[String]) -> Array[String]:
	var out: Array[String] = []
	_collect_paths(self, "", tokens, out)
	return out

func _collect_paths(node: Node, prefix: String, tokens: Array[String], out: Array[String]) -> void:
	for child in node.get_children():
		if child.name == &"AnimationPlayer" or String(child.name).begins_with("_"):
			continue
		var path := (prefix + "/" + String(child.name)) if prefix != "" else String(child.name)
		if child is Node2D:
			for token in tokens:
				if String(child.name).contains(token):
					out.append(path)
					break
		_collect_paths(child, path, tokens, out)

func _key_float(a: Animation, path: NodePath, times: Array, values: Array) -> void:
	var t := _track(a, path)
	for i in range(times.size()):
		a.track_insert_key(t, float(times[i]), float(values[i]))

func _key_vec2(a: Animation, path: NodePath, times: Array, values: Array) -> void:
	var t := _track(a, path)
	for i in range(times.size()):
		a.track_insert_key(t, float(times[i]), values[i])

func _key_color(a: Animation, path: NodePath, times: Array, values: Array) -> void:
	var t := _track(a, path)
	for i in range(times.size()):
		a.track_insert_key(t, float(times[i]), values[i])

func _track(a: Animation, path: NodePath) -> int:
	var idx := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(idx, path)
	a.track_set_interpolation_type(idx, Animation.INTERPOLATION_CUBIC)
	return idx

func _infer_sprite_id() -> StringName:
	var s := String(name)
	if s.ends_with("Sprite"):
		s = s.substr(0, s.length() - 6)
	var out := ""
	for i in range(s.length()):
		var ch := s.substr(i, 1)
		if i > 0 and ch == ch.to_upper() and ch != ch.to_lower():
			out += "_"
		out += ch.to_lower()
	return StringName(out)
