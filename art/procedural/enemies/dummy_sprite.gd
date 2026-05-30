extends Node2D
## Procedural training-dummy sprite. AD-11 — implements the canonical
## AnimationPlayer track names. Stage 3 exercises idle/hit/die.

const WOOD: Color       = Color(0.45, 0.30, 0.18)
const WOOD_DARK: Color  = Color(0.28, 0.18, 0.10)
const ROPE: Color       = Color(0.65, 0.55, 0.30)
const SHADOW: Color     = Color(0.0, 0.0, 0.05, 0.45)

@onready var _shadow: Polygon2D = $Shadow
@onready var _post: Polygon2D = $Body/Post
@onready var _rope_lo: Polygon2D = $Body/RopeLow
@onready var _rope_hi: Polygon2D = $Body/RopeHigh
@onready var _head: Polygon2D = $Body/Head
@onready var _anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_paint()
	_build_animations()
	_anim.play(&"idle")

func _paint() -> void:
	_shadow.color = SHADOW
	var sh: PackedVector2Array = []
	var n := 16
	for i in n:
		var t := TAU * i / n
		sh.append(Vector2(12.0 * cos(t), 2.0 + 3.5 * sin(t)))
	_shadow.polygon = sh

	# Vertical post, tapered slightly
	_post.color = WOOD
	_post.polygon = PackedVector2Array([
		Vector2(-5, 0), Vector2(5, 0), Vector2(4, -50), Vector2(-4, -50),
	])

	# Rope bands
	_rope_lo.color = ROPE
	_rope_lo.polygon = PackedVector2Array([
		Vector2(-6, -18), Vector2(6, -18), Vector2(6, -14), Vector2(-6, -14),
	])
	_rope_hi.color = ROPE
	_rope_hi.polygon = PackedVector2Array([
		Vector2(-6, -38), Vector2(6, -38), Vector2(6, -34), Vector2(-6, -34),
	])

	# Knob "head" at top
	_head.color = WOOD_DARK
	var head: PackedVector2Array = []
	var nh := 10
	for i in nh:
		var t := TAU * i / nh
		head.append(Vector2(5.0 * cos(t), -52.0 + 5.0 * sin(t)))
	_head.polygon = head

func _build_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle",   _anim_idle())
	lib.add_animation(&"walk",   _anim_idle())     # dummy doesn't walk; alias
	lib.add_animation(&"attack", _anim_empty())
	lib.add_animation(&"cast",   _anim_empty())
	lib.add_animation(&"hit",    _anim_hit())
	lib.add_animation(&"die",    _anim_die())
	_anim.add_animation_library(&"", lib)

func _anim_empty() -> Animation:
	var a := Animation.new()
	a.length = 0.05
	a.loop_mode = Animation.LOOP_NONE
	return a

func _anim_idle() -> Animation:
	var a := Animation.new()
	a.length = 2.0
	a.loop_mode = Animation.LOOP_LINEAR
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath("Body:rotation"))
	a.track_insert_key(ti, 0.0, 0.0)
	a.track_insert_key(ti, 1.0, 0.02)
	a.track_insert_key(ti, 2.0, 0.0)
	return a

func _anim_hit() -> Animation:
	var a := Animation.new()
	a.length = 0.15
	a.loop_mode = Animation.LOOP_NONE
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath(".:modulate"))
	a.track_insert_key(ti, 0.00, Color(1, 1, 1, 1))
	a.track_insert_key(ti, 0.05, Color(1.6, 0.4, 0.4, 1))
	a.track_insert_key(ti, 0.15, Color(1, 1, 1, 1))
	return a

func _anim_die() -> Animation:
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_NONE
	var tr := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tr, NodePath(".:rotation"))
	a.track_insert_key(tr, 0.0, 0.0)
	a.track_insert_key(tr, 0.6, PI / 3.0)
	var tm := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tm, NodePath(".:modulate"))
	a.track_insert_key(tm, 0.0, Color(1, 1, 1, 1))
	a.track_insert_key(tm, 0.6, Color(1, 1, 1, 0.3))
	return a
