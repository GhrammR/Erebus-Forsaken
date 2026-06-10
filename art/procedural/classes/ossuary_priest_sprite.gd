extends Node2D
## Procedural Ossuary Priest sprite. WandStances drive real WandArm
## geometry; pose_tuner saves BEGIN/MIDDLE/END transform overrides.

const BONE: Color         = Color(0.92, 0.90, 0.80)
const BONE_DARK: Color    = Color(0.65, 0.62, 0.50)
const ROBE_DARK: Color    = Color(0.18, 0.16, 0.20)
const SICKLY_GREEN: Color = Color(0.45, 0.78, 0.45)
const SHADOW: Color       = Color(0.0, 0.0, 0.05, 0.45)

const SpriteOverrides = preload("res://scripts/systems/sprite_overrides.gd")
const StanceSelection = preload("res://scripts/systems/stance_selection.gd")
const WandStances = preload("res://scripts/systems/stances/wand_stances.gd")

@export var stance_id: StringName = WandStances.DEFAULT_STANCE

@onready var _shadow: Polygon2D = $Shadow
@onready var _robe: Polygon2D = $Body/Robe
@onready var _torso: Polygon2D = $Body/Torso
@onready var _shoulder_l: Polygon2D = $Body/ShoulderLeft
@onready var _shoulder_r: Polygon2D = $Body/ShoulderRight
@onready var _head: Polygon2D = $Body/Head
@onready var _hood: Polygon2D = $Body/Hood
@onready var _eye_l: Polygon2D = $Body/EyeL
@onready var _eye_r: Polygon2D = $Body/EyeR
@onready var _wand_arm: Node2D = $WandArm
@onready var _wand_shaft: Polygon2D = $WandArm/Shaft
@onready var _wand_glow: Polygon2D = $WandArm/Glow
@onready var _wand_hand: Polygon2D = $WandArm/GripHand
@onready var _anim: AnimationPlayer = $AnimationPlayer

var _wand_attack_apex_rot: float = -0.45
var _wand_cast_apex_rot: float = -0.80
var _wand_attack_len: float = 0.34
var _wand_cast_len: float = 0.65
var _per_anim_config: Dictionary = {}
var _replaying_for_injection: bool = false

func _ready() -> void:
	_apply_wand_stance()
	_paint()
	_build_animations()
	_load_tuning()
	_anim.animation_started.connect(_on_anim_started)
	_anim.play(&"idle")

func _apply_wand_stance() -> void:
	stance_id = StanceSelection.selected_for_class(
			&"ossuary_priest", stance_id, WandStances.all_ids())
	var stance: Dictionary = WandStances.get_stance(stance_id)
	_wand_arm.position = stance.get("wand_pos", _wand_arm.position)
	_wand_arm.rotation = float(stance.get("wand_rot", _wand_arm.rotation))
	_wand_attack_apex_rot = float(stance.get("attack_apex_rot", _wand_attack_apex_rot))
	_wand_cast_apex_rot = float(stance.get("cast_apex_rot", _wand_cast_apex_rot))
	_wand_attack_len = float(stance.get("attack_len", _wand_attack_len))
	_wand_cast_len = float(stance.get("cast_len", _wand_cast_len))
	set_meta(&"wand_stance", {
		"stance_id": String(stance_id),
		"rest_pos": _wand_arm.position,
		"rest_rot": _wand_arm.rotation,
		"attack_apex_rot": _wand_attack_apex_rot,
		"cast_apex_rot": _wand_cast_apex_rot,
		"attack_len": _wand_attack_len,
		"cast_len": _wand_cast_len,
	})

func _load_tuning() -> void:
	_per_anim_config = SpriteOverrides.load_for_class(&"ossuary_priest", stance_id)

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

func _paint() -> void:
	var sh: PackedVector2Array = []
	var n := 16
	for i in n:
		var t := TAU * i / n
		sh.append(Vector2(14.0 * cos(t), 2.0 + 4.0 * sin(t)))
	_shadow.color = SHADOW
	_shadow.polygon = sh
	_paint_robed_leg(^"Body/LegLHip", -1.0)
	_paint_robed_leg(^"Body/LegRHip", 1.0)

	_robe.color = ROBE_DARK
	_robe.polygon = PackedVector2Array([
		Vector2(-11, 0), Vector2(11, 0), Vector2(8, -30), Vector2(-8, -30),
	])
	_torso.color = ROBE_DARK
	_torso.polygon = PackedVector2Array([
		Vector2(-8, -30), Vector2(8, -30), Vector2(7, -42), Vector2(-7, -42),
	])
	_shoulder_l.color = BONE
	_shoulder_l.polygon = PackedVector2Array([
		Vector2(-12, -32), Vector2(-6, -34), Vector2(-8, -40), Vector2(-13, -38),
	])
	_shoulder_r.color = BONE
	_shoulder_r.polygon = PackedVector2Array([
		Vector2(12, -32), Vector2(6, -34), Vector2(8, -40), Vector2(13, -38),
	])
	_head.color = BONE
	var hd: PackedVector2Array = []
	var nh := 12
	for i in nh:
		var t := TAU * i / nh
		hd.append(Vector2(5.0 * cos(t), -48.0 + 5.0 * sin(t)))
	_head.polygon = hd
	_eye_l.color = SICKLY_GREEN
	_eye_l.polygon = PackedVector2Array([
		Vector2(-1.3, -0.8), Vector2(1.3, -0.8),
		Vector2(1.6, 0.7), Vector2(-1.6, 0.7),
	])
	_eye_r.color = SICKLY_GREEN
	_eye_r.polygon = PackedVector2Array([
		Vector2(-1.3, -0.8), Vector2(1.3, -0.8),
		Vector2(1.6, 0.7), Vector2(-1.6, 0.7),
	])
	_hood.color = ROBE_DARK
	_hood.polygon = PackedVector2Array([
		Vector2(-7, -42), Vector2(7, -42), Vector2(6, -52),
		Vector2(0, -56), Vector2(-6, -52),
	])

	_wand_shaft.color = BONE_DARK
	_wand_shaft.polygon = PackedVector2Array([
		Vector2(-1, 0), Vector2(1, 0), Vector2(1, -22), Vector2(-1, -22),
	])
	_wand_glow.color = SICKLY_GREEN
	var glow: PackedVector2Array = []
	var ng := 10
	for i in ng:
		var t := TAU * i / ng
		glow.append(Vector2(2.5 * cos(t), -25.0 + 2.5 * sin(t)))
	_wand_glow.polygon = glow
	_wand_hand.color = BONE
	_wand_hand.polygon = PackedVector2Array([
		Vector2(-3.0, -2.0), Vector2(3.0, -2.0),
		Vector2(3.0, 2.0), Vector2(-3.0, 2.0),
	])

func _paint_robed_leg(root_path: NodePath, side: float) -> void:
	var hip := get_node_or_null(root_path) as Node2D
	if hip == null:
		return
	var thigh := hip.get_node_or_null(^"Thigh") as Polygon2D
	var knee := hip.get_node_or_null(^"KneePivot") as Node2D
	if thigh != null:
		thigh.color = ROBE_DARK.darkened(0.24)
		thigh.polygon = PackedVector2Array([
			Vector2(-2.5, -1), Vector2(2.5, -1),
			Vector2(2.0, 10), Vector2(-2.0, 10),
		])
	if knee == null:
		return
	var shin := knee.get_node_or_null(^"Shin") as Polygon2D
	var foot := knee.get_node_or_null(^"FootL") as Polygon2D
	if foot == null:
		foot = knee.get_node_or_null(^"FootR") as Polygon2D
	if shin != null:
		shin.color = ROBE_DARK.darkened(0.38)
		shin.polygon = PackedVector2Array([
			Vector2(-2.0, -1), Vector2(2.0, -1),
			Vector2(2.0, 11), Vector2(-2.0, 11),
		])
	if foot != null:
		foot.color = BONE_DARK.darkened(0.35)
		foot.position = Vector2(side, 12)
		if side < 0.0:
			foot.polygon = PackedVector2Array([
				Vector2(1, -2), Vector2(-5, -2),
				Vector2(-6, 1.5), Vector2(1, 2),
			])
		else:
			foot.polygon = PackedVector2Array([
				Vector2(-1, -2), Vector2(5, -2),
				Vector2(6, 1.5), Vector2(-1, 2),
			])

func _build_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle", _anim_idle())
	lib.add_animation(&"walk", _anim_walk())
	lib.add_animation(&"attack", _anim_attack())
	lib.add_animation(&"cast", _anim_cast())
	lib.add_animation(&"hit", _anim_hit())
	lib.add_animation(&"die", _anim_die())
	_anim.add_animation_library(&"", lib)

func _track(a: Animation, path: NodePath) -> int:
	var idx := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(idx, path)
	a.track_set_interpolation_type(idx, Animation.INTERPOLATION_CUBIC)
	return idx

func _key_wand_rest(a: Animation, t: float) -> void:
	var tp := _track(a, NodePath("WandArm:position"))
	a.track_insert_key(tp, t, _wand_arm.position)
	var tr := _track(a, NodePath("WandArm:rotation"))
	a.track_insert_key(tr, t, _wand_arm.rotation)

func _anim_idle() -> Animation:
	var a := Animation.new()
	a.length = 1.4
	a.loop_mode = Animation.LOOP_LINEAR
	var ti := _track(a, NodePath("Body:position"))
	a.track_insert_key(ti, 0.0, Vector2.ZERO)
	a.track_insert_key(ti, 0.7, Vector2(0, -1))
	a.track_insert_key(ti, 1.4, Vector2.ZERO)
	for path in [
		NodePath("Body/LegLHip:rotation"),
		NodePath("Body/LegRHip:rotation"),
		NodePath("Body/LegLHip/KneePivot:rotation"),
		NodePath("Body/LegRHip/KneePivot:rotation"),
	]:
		var tr := _track(a, path)
		a.track_insert_key(tr, 0.0, 0.0)
		a.track_insert_key(tr, 1.4, 0.0)
	var tsh := _track(a, NodePath("Shadow:scale"))
	a.track_insert_key(tsh, 0.0, Vector2.ONE)
	a.track_insert_key(tsh, 0.7, Vector2(0.92, 0.82))
	a.track_insert_key(tsh, 1.4, Vector2.ONE)
	var twp := _track(a, NodePath("WandArm:position"))
	a.track_insert_key(twp, 0.0, _wand_arm.position)
	a.track_insert_key(twp, 1.4, _wand_arm.position)
	var twr := _track(a, NodePath("WandArm:rotation"))
	a.track_insert_key(twr, 0.0, _wand_arm.rotation)
	a.track_insert_key(twr, 1.4, _wand_arm.rotation)
	return a

func _anim_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.46
	a.loop_mode = Animation.LOOP_LINEAR
	var ti := _track(a, NodePath("Body:position"))
	a.track_insert_key(ti, 0.0, Vector2.ZERO)
	a.track_insert_key(ti, 0.23, Vector2(0, -2))
	a.track_insert_key(ti, 0.46, Vector2.ZERO)
	var tr := _track(a, NodePath("Body:rotation"))
	a.track_insert_key(tr, 0.0, 0.0)
	a.track_insert_key(tr, 0.23, 0.035)
	a.track_insert_key(tr, 0.46, 0.0)
	var lhip := _track(a, NodePath("Body/LegLHip:rotation"))
	a.track_insert_key(lhip, 0.0, 0.10)
	a.track_insert_key(lhip, 0.23, -0.12)
	a.track_insert_key(lhip, 0.46, 0.10)
	var rhip := _track(a, NodePath("Body/LegRHip:rotation"))
	a.track_insert_key(rhip, 0.0, -0.12)
	a.track_insert_key(rhip, 0.23, 0.10)
	a.track_insert_key(rhip, 0.46, -0.12)
	var lknee := _track(a, NodePath("Body/LegLHip/KneePivot:rotation"))
	a.track_insert_key(lknee, 0.0, 0.14)
	a.track_insert_key(lknee, 0.23, -0.05)
	a.track_insert_key(lknee, 0.46, 0.14)
	var rknee := _track(a, NodePath("Body/LegRHip/KneePivot:rotation"))
	a.track_insert_key(rknee, 0.0, -0.05)
	a.track_insert_key(rknee, 0.23, 0.14)
	a.track_insert_key(rknee, 0.46, -0.05)
	var tsh := _track(a, NodePath("Shadow:scale"))
	a.track_insert_key(tsh, 0.0, Vector2.ONE)
	a.track_insert_key(tsh, 0.23, Vector2(0.94, 0.82))
	a.track_insert_key(tsh, 0.46, Vector2.ONE)
	var twp := _track(a, NodePath("WandArm:position"))
	a.track_insert_key(twp, 0.0, _wand_arm.position)
	a.track_insert_key(twp, 0.46, _wand_arm.position)
	var twr := _track(a, NodePath("WandArm:rotation"))
	a.track_insert_key(twr, 0.0, _wand_arm.rotation)
	a.track_insert_key(twr, 0.23, _wand_arm.rotation + 0.08)
	a.track_insert_key(twr, 0.46, _wand_arm.rotation)
	return a

func _anim_attack() -> Animation:
	var a := Animation.new()
	a.length = _wand_attack_len
	a.loop_mode = Animation.LOOP_NONE
	var t_hit := a.length * 0.45
	var tr := _track(a, NodePath("WandArm:rotation"))
	a.track_insert_key(tr, 0.0, _wand_arm.rotation)
	a.track_insert_key(tr, t_hit, _wand_attack_apex_rot)
	a.track_insert_key(tr, a.length, _wand_arm.rotation)
	var tp := _track(a, NodePath("WandArm:position"))
	a.track_insert_key(tp, 0.0, _wand_arm.position)
	a.track_insert_key(tp, t_hit, _wand_arm.position + Vector2(2, -1))
	a.track_insert_key(tp, a.length, _wand_arm.position)
	return a

func _anim_cast() -> Animation:
	var a := Animation.new()
	a.length = _wand_cast_len
	a.loop_mode = Animation.LOOP_NONE
	var t_peak := a.length * 0.38
	var tr := _track(a, NodePath("WandArm:rotation"))
	a.track_insert_key(tr, 0.0, _wand_arm.rotation)
	a.track_insert_key(tr, t_peak, _wand_cast_apex_rot)
	a.track_insert_key(tr, a.length, _wand_arm.rotation)
	var tg := _track(a, NodePath("WandArm/Glow:modulate"))
	a.track_insert_key(tg, 0.0, Color(1, 1, 1, 1))
	a.track_insert_key(tg, t_peak, Color(2.0, 2.5, 1.0, 1))
	a.track_insert_key(tg, a.length, Color(1, 1, 1, 1))
	var ts := _track(a, NodePath("WandArm/Glow:scale"))
	a.track_insert_key(ts, 0.0, Vector2.ONE)
	a.track_insert_key(ts, t_peak, Vector2(1.55, 1.55))
	a.track_insert_key(ts, a.length, Vector2.ONE)
	var tm := _track(a, NodePath(".:modulate"))
	a.track_insert_key(tm, 0.0, Color(1, 1, 1, 1))
	a.track_insert_key(tm, t_peak, Color(1.1, 1.3, 1.1, 1))
	a.track_insert_key(tm, a.length, Color(1, 1, 1, 1))
	return a

func _anim_hit() -> Animation:
	var a := Animation.new()
	a.length = 0.15
	a.loop_mode = Animation.LOOP_NONE
	var ti := _track(a, NodePath(".:modulate"))
	a.track_insert_key(ti, 0.0, Color(1, 1, 1, 1))
	a.track_insert_key(ti, 0.05, Color(1.6, 0.4, 0.4, 1))
	a.track_insert_key(ti, 0.15, Color(1, 1, 1, 1))
	return a

func _anim_die() -> Animation:
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_NONE
	var tr := _track(a, NodePath(".:rotation"))
	a.track_insert_key(tr, 0.0, 0.0)
	a.track_insert_key(tr, 0.6, PI / 2.0)
	var tm := _track(a, NodePath(".:modulate"))
	a.track_insert_key(tm, 0.0, Color(1, 1, 1, 1))
	a.track_insert_key(tm, 0.6, Color(1, 1, 1, 0.3))
	return a
