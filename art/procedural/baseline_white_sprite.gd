extends Node2D
## Single active procedural baseline sprite.
##
## Intentional reset: every current player, enemy, and NPC sprite path
## points at this one Myrmidon-derived white anatomy rig. Archived
## implementations live under art/procedural/archive/baseline_reset_2026_06_11.

const SpriteOverrides = preload("res://scripts/systems/sprite_overrides.gd")

const WHITE: Color = Color(1.0, 1.0, 1.0, 1.0)
const SHADOW: Color = Color(0.0, 0.0, 0.05, 0.45)

@export var sprite_id: StringName = &"baseline_white"
@export var stance_bucket: StringName = &""
@export var stance_id: StringName = &"baseline"
@export var ik_enabled: bool = true
@export var show_spear: bool = false
@export var show_staff: bool = false
@export var show_bow: bool = false
@export var show_wand: bool = false

@onready var _shadow: Polygon2D = $Shadow
@onready var _body: Node2D = $Body
@onready var _anim: AnimationPlayer = $AnimationPlayer

var _per_anim_config: Dictionary = {}
var _replaying_for_injection: bool = false

func _ready() -> void:
	_shadow.color = SHADOW
	_shadow.polygon = HumanRig.shadow_poly()
	HumanRig.apply(_body, WHITE, WHITE)
	_paint_polygon_tree(_body, WHITE)
	_hide_compatibility_nodes()
	_build_animations()
	_per_anim_config = SpriteOverrides.load_for_class(sprite_id, stance_id)
	_anim.animation_started.connect(_on_anim_started)
	_anim.play(&"idle")

func _paint_polygon_tree(node: Node, color: Color) -> void:
	if node is Polygon2D:
		(node as Polygon2D).color = color
	for child in node.get_children():
		_paint_polygon_tree(child, color)

func _hide_compatibility_nodes() -> void:
	for path in [
		^"Body/ArmRShoulder/ElbowPivot/SpearArm",
		^"Body/StaffArm",
		^"Body/BowArm",
		^"WandArm",
		^"Body/ArmLShoulder/ElbowPivot/Buckler",
	]:
		var n := get_node_or_null(path) as CanvasItem
		if n != null:
			n.visible = false

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

func _build_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle", _anim_idle())
	lib.add_animation(&"walk", _anim_walk())
	lib.add_animation(&"attack", _anim_attack())
	lib.add_animation(&"cast", _anim_cast())
	lib.add_animation(&"hit", _anim_hit())
	lib.add_animation(&"die", _anim_die())
	_anim.add_animation_library(&"", lib)

const _RESET_PATHS: Array = [
	NodePath("Body:rotation"),
	NodePath("Body/LegLHip:rotation"),
	NodePath("Body/LegRHip:rotation"),
	NodePath("Body/LegLHip/KneePivot:rotation"),
	NodePath("Body/LegRHip/KneePivot:rotation"),
	NodePath("Body/ArmLShoulder:rotation"),
	NodePath("Body/ArmLShoulder/ElbowPivot:rotation"),
	NodePath("Body/ArmRShoulder:rotation"),
	NodePath("Body/ArmRShoulder/ElbowPivot:rotation"),
]

func _anim_idle() -> Animation:
	var a := Animation.new()
	a.length = 1.6
	a.loop_mode = Animation.LOOP_LINEAR
	_key_vec2(a, ^"Body:position", [0.0, 0.8, 1.6], [Vector2.ZERO, Vector2(0, -1), Vector2.ZERO])
	for path in _RESET_PATHS:
		_key_float(a, path, [0.0, 1.6], [0.0, 0.0])
	return a

func _anim_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_LINEAR
	_key_vec2(a, ^"Body:position", [0.0, 0.15, 0.3, 0.45, 0.6], [
		Vector2.ZERO, Vector2(0, -1.5), Vector2.ZERO, Vector2(0, -1.5), Vector2.ZERO])
	_key_float(a, ^"Body/LegLHip:rotation", [0.0, 0.15, 0.3, 0.45, 0.6], [0.0, -0.22, 0.0, 0.22, 0.0])
	_key_float(a, ^"Body/LegRHip:rotation", [0.0, 0.15, 0.3, 0.45, 0.6], [0.0, 0.22, 0.0, -0.22, 0.0])
	_key_float(a, ^"Body/LegLHip/KneePivot:rotation", [0.0, 0.45, 0.6], [0.0, 0.32, 0.0])
	_key_float(a, ^"Body/LegRHip/KneePivot:rotation", [0.0, 0.15, 0.6], [0.0, 0.32, 0.0])
	_key_float(a, ^"Body/ArmLShoulder:rotation", [0.0, 0.15, 0.3, 0.45, 0.6], [0.0, 0.25, 0.0, -0.25, 0.0])
	_key_float(a, ^"Body/ArmRShoulder:rotation", [0.0, 0.15, 0.3, 0.45, 0.6], [0.0, -0.25, 0.0, 0.25, 0.0])
	return a

func _anim_attack() -> Animation:
	var a := Animation.new()
	a.length = 0.38
	a.loop_mode = Animation.LOOP_NONE
	_key_float(a, ^"Body:rotation", [0.0, 0.16, 0.38], [0.0, 0.05, 0.0])
	_key_float(a, ^"Body/ArmRShoulder:rotation", [0.0, 0.12, 0.23, 0.38], [0.0, 0.35, -1.15, 0.0])
	_key_float(a, ^"Body/ArmRShoulder/ElbowPivot:rotation", [0.0, 0.23, 0.38], [0.0, -0.25, 0.0])
	_key_float(a, ^"Body/ArmLShoulder:rotation", [0.0, 0.23, 0.38], [0.0, 0.18, 0.0])
	return a

func _anim_cast() -> Animation:
	var a := Animation.new()
	a.length = 0.55
	a.loop_mode = Animation.LOOP_NONE
	_key_float(a, ^"Body/ArmLShoulder:rotation", [0.0, 0.25, 0.55], [0.0, -0.72, 0.0])
	_key_float(a, ^"Body/ArmRShoulder:rotation", [0.0, 0.25, 0.55], [0.0, 0.72, 0.0])
	_key_color(a, ^".:modulate", [0.0, 0.25, 0.55], [Color.WHITE, Color(1.25, 1.25, 1.25, 1), Color.WHITE])
	return a

func _anim_hit() -> Animation:
	var a := Animation.new()
	a.length = 0.15
	a.loop_mode = Animation.LOOP_NONE
	_key_color(a, ^".:modulate", [0.0, 0.05, 0.15], [Color.WHITE, Color(1.5, 0.65, 0.65, 1), Color.WHITE])
	return a

func _anim_die() -> Animation:
	var a := Animation.new()
	a.length = 0.65
	a.loop_mode = Animation.LOOP_NONE
	_key_float(a, ^".:rotation", [0.0, 0.65], [0.0, PI / 2.0])
	_key_color(a, ^".:modulate", [0.0, 0.65], [Color.WHITE, Color(1, 1, 1, 0.25)])
	return a

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
