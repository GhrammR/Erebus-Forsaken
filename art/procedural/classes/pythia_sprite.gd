extends Node2D
## Procedural Pythia sprite. AD-11 — implements the canonical
## AnimationPlayer track names. Stage 2/5 exercise idle/walk/attack/cast.

const VIOLET: Color       = Color(0.48, 0.30, 0.65)
const VIOLET_DARK: Color  = Color(0.30, 0.18, 0.42)
const GOLD: Color         = Color(0.85, 0.72, 0.30)
const ORB_GLOW: Color     = Color(0.95, 0.85, 0.50)
const SHADOW: Color       = Color(0.0, 0.0, 0.05, 0.45)

@onready var _shadow: Polygon2D = $Shadow
@onready var _robe: Polygon2D = $Body/Robe
@onready var _torso: Polygon2D = $Body/Torso
@onready var _head: Polygon2D = $Body/Head
@onready var _hood: Polygon2D = $Body/Hood
@onready var _staff_shaft: Polygon2D = $StaffArm/Shaft
@onready var _staff_orb: Polygon2D = $StaffArm/Orb
@onready var _anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_paint()
	_build_animations()
	_anim.play(&"idle")

func _paint() -> void:
	# Shadow at feet
	var sh: PackedVector2Array = []
	var n := 16
	for i in n:
		var t := TAU * i / n
		sh.append(Vector2(13.0 * cos(t), 2.0 + 4.0 * sin(t)))
	_shadow.color = SHADOW
	_shadow.polygon = sh

	# Long robe (wider at the bottom)
	_robe.color = VIOLET_DARK
	_robe.polygon = PackedVector2Array([
		Vector2(-10, 0), Vector2(10, 0), Vector2(8, -28), Vector2(-8, -28),
	])

	# Torso (lighter violet, gold trim at neckline implied)
	_torso.color = VIOLET
	_torso.polygon = PackedVector2Array([
		Vector2(-8, -28), Vector2(8, -28), Vector2(6, -42), Vector2(-6, -42),
	])

	# Head (pale fleshy circle)
	_head.color = Color(0.85, 0.78, 0.60)
	var hd: PackedVector2Array = []
	var nh := 12
	for i in nh:
		var t := TAU * i / nh
		hd.append(Vector2(5.0 * cos(t), -48.0 + 5.0 * sin(t)))
	_head.polygon = hd

	# Hood (violet drape behind/over head)
	_hood.color = VIOLET_DARK
	_hood.polygon = PackedVector2Array([
		Vector2(-8, -42), Vector2(8, -42), Vector2(7, -52), Vector2(0, -58), Vector2(-7, -52),
	])

func _build_animations() -> void:
	# Staff is held to the right (positive x), tilted slightly
	_staff_shaft.color = GOLD
	_staff_shaft.polygon = PackedVector2Array([
		Vector2(-1, 0), Vector2(1, 0), Vector2(1, -38), Vector2(-1, -38),
	])
	_staff_orb.color = ORB_GLOW
	var orb: PackedVector2Array = []
	var no := 10
	for i in no:
		var t := TAU * i / no
		orb.append(Vector2(3.5 * cos(t), -42.0 + 3.5 * sin(t)))
	_staff_orb.polygon = orb

	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle",   _anim_idle())
	lib.add_animation(&"walk",   _anim_walk())
	lib.add_animation(&"attack", _anim_attack())
	lib.add_animation(&"cast",   _anim_cast())
	lib.add_animation(&"hit",    _anim_hit())
	lib.add_animation(&"die",    _anim_die())
	_anim.add_animation_library(&"", lib)

func _anim_idle() -> Animation:
	var a := Animation.new()
	a.length = 1.2
	a.loop_mode = Animation.LOOP_LINEAR
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath("Body:position"))
	a.track_insert_key(ti, 0.0, Vector2.ZERO)
	a.track_insert_key(ti, 0.6, Vector2(0, -1))
	a.track_insert_key(ti, 1.2, Vector2.ZERO)
	return a

func _anim_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.4
	a.loop_mode = Animation.LOOP_LINEAR
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath("Body:position"))
	a.track_insert_key(ti, 0.0, Vector2.ZERO)
	a.track_insert_key(ti, 0.2, Vector2(0, -2))
	a.track_insert_key(ti, 0.4, Vector2.ZERO)
	return a

func _anim_attack() -> Animation:
	# Quick staff jab
	var a := Animation.new()
	a.length = 0.35
	a.loop_mode = Animation.LOOP_NONE
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath("StaffArm:rotation"))
	a.track_insert_key(ti, 0.0, 0.0)
	a.track_insert_key(ti, 0.15, -0.6)
	a.track_insert_key(ti, 0.35, 0.0)
	return a

func _anim_cast() -> Animation:
	# Orb glows bright
	var a := Animation.new()
	a.length = 0.5
	a.loop_mode = Animation.LOOP_NONE
	var to := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(to, NodePath("StaffArm/Orb:modulate"))
	a.track_insert_key(to, 0.0, Color(1, 1, 1, 1))
	a.track_insert_key(to, 0.2, Color(2.0, 1.6, 0.6, 1))
	a.track_insert_key(to, 0.5, Color(1, 1, 1, 1))
	var tm := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tm, NodePath(".:modulate"))
	a.track_insert_key(tm, 0.0, Color(1, 1, 1, 1))
	a.track_insert_key(tm, 0.2, Color(1.2, 1.1, 1.4, 1))
	a.track_insert_key(tm, 0.5, Color(1, 1, 1, 1))
	return a

func _anim_hit() -> Animation:
	var a := Animation.new()
	a.length = 0.15
	a.loop_mode = Animation.LOOP_NONE
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath(".:modulate"))
	a.track_insert_key(ti, 0.0, Color(1, 1, 1, 1))
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
	a.track_insert_key(tr, 0.6, PI / 2.0)
	var tm := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tm, NodePath(".:modulate"))
	a.track_insert_key(tm, 0.0, Color(1, 1, 1, 1))
	a.track_insert_key(tm, 0.6, Color(1, 1, 1, 0.3))
	return a
