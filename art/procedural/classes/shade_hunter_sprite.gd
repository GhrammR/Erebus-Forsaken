extends Node2D
## Procedural Shade-Hunter sprite. AD-11 — implements the canonical
## AnimationPlayer track names. Stage 2/5 exercise idle/walk/attack.

const CHARCOAL: Color     = Color(0.20, 0.20, 0.24)
const CHARCOAL_DARK: Color = Color(0.10, 0.10, 0.14)
const PALE_TEAL: Color    = Color(0.55, 0.78, 0.80)
const BOW_WOOD: Color     = Color(0.40, 0.30, 0.20)
const SHADOW: Color       = Color(0.0, 0.0, 0.05, 0.45)

@onready var _shadow: Polygon2D = $Shadow
@onready var _legs: Polygon2D = $Body/Legs
@onready var _cloak: Polygon2D = $Body/Cloak
@onready var _torso: Polygon2D = $Body/Torso
@onready var _hood: Polygon2D = $Body/Hood
@onready var _eye_glow: Polygon2D = $Body/EyeGlow
@onready var _bow: Polygon2D = $BowArm/Bow
@onready var _bowstring: Polygon2D = $BowArm/String
@onready var _anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_paint()
	_build_animations()
	_anim.play(&"idle")

func _paint() -> void:
	# Shadow
	var sh: PackedVector2Array = []
	var n := 14
	for i in n:
		var t := TAU * i / n
		sh.append(Vector2(12.0 * cos(t), 2.0 + 3.5 * sin(t)))
	_shadow.color = SHADOW
	_shadow.polygon = sh

	# Legs (charcoal, narrow)
	_legs.color = CHARCOAL_DARK
	_legs.polygon = PackedVector2Array([
		Vector2(-5, 0), Vector2(5, 0), Vector2(4, -14), Vector2(-4, -14),
	])

	# Cloak (drape behind body)
	_cloak.color = CHARCOAL_DARK
	_cloak.polygon = PackedVector2Array([
		Vector2(-10, 0), Vector2(10, 0), Vector2(8, -34), Vector2(-8, -34),
	])

	# Torso (lighter charcoal in front of cloak)
	_torso.color = CHARCOAL
	_torso.polygon = PackedVector2Array([
		Vector2(-7, -14), Vector2(7, -14), Vector2(6, -38), Vector2(-6, -38),
	])

	# Hood (charcoal, triangular over head)
	_hood.color = CHARCOAL_DARK
	_hood.polygon = PackedVector2Array([
		Vector2(-7, -38), Vector2(7, -38), Vector2(5, -52), Vector2(0, -56), Vector2(-5, -52),
	])

	# Eye glow (single pale-teal slit)
	_eye_glow.color = PALE_TEAL
	_eye_glow.polygon = PackedVector2Array([
		Vector2(-3, -46), Vector2(3, -46), Vector2(3, -44), Vector2(-3, -44),
	])

func _build_animations() -> void:
	# Bow — curved arc on the right, string between tips
	_bow.color = BOW_WOOD
	var bow_pts: PackedVector2Array = []
	# Outer arc
	var arc_n := 10
	for i in arc_n + 1:
		var t := float(i) / float(arc_n) * PI
		bow_pts.append(Vector2(-3.0 * sin(t), -18.0 + 18.0 * cos(t)))
	# Inner arc back
	for i in arc_n + 1:
		var t := PI - float(i) / float(arc_n) * PI
		bow_pts.append(Vector2(-1.5 * sin(t), -18.0 + 18.0 * cos(t)))
	_bow.polygon = bow_pts

	_bowstring.color = Color(0.9, 0.9, 0.85)
	_bowstring.polygon = PackedVector2Array([
		Vector2(-0.5, 0), Vector2(0.5, 0),
		Vector2(0.5, -36), Vector2(-0.5, -36),
	])

	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle",   _anim_idle())
	lib.add_animation(&"walk",   _anim_walk())
	lib.add_animation(&"attack", _anim_attack())
	lib.add_animation(&"cast",   _anim_attack())   # cast aliases attack for SH
	lib.add_animation(&"hit",    _anim_hit())
	lib.add_animation(&"die",    _anim_die())
	_anim.add_animation_library(&"", lib)

func _anim_idle() -> Animation:
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_LINEAR
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath("Body:position"))
	a.track_insert_key(ti, 0.0, Vector2.ZERO)
	a.track_insert_key(ti, 0.5, Vector2(0, -1))
	a.track_insert_key(ti, 1.0, Vector2.ZERO)
	return a

func _anim_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.35
	a.loop_mode = Animation.LOOP_LINEAR
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath("Body:position"))
	a.track_insert_key(ti, 0.0, Vector2.ZERO)
	a.track_insert_key(ti, 0.175, Vector2(0, -2))
	a.track_insert_key(ti, 0.35, Vector2.ZERO)
	return a

func _anim_attack() -> Animation:
	# Quick bow draw and release — pull arm back, snap forward
	var a := Animation.new()
	a.length = 0.4
	a.loop_mode = Animation.LOOP_NONE
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath("BowArm:position"))
	a.track_insert_key(ti, 0.0, Vector2(12, -28))
	a.track_insert_key(ti, 0.15, Vector2(8, -28))    # pull back
	a.track_insert_key(ti, 0.20, Vector2(16, -28))   # snap forward
	a.track_insert_key(ti, 0.4, Vector2(12, -28))
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
