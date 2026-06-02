extends Node2D
## Procedural bone-servant minion sprite. AD-11 canonical anim names.
## Stage 5 exercises idle / walk / attack / hit / die.

const BONE: Color       = Color(0.92, 0.90, 0.80)
const BONE_DARK: Color  = Color(0.55, 0.52, 0.40)
const SICKLY_GREEN: Color = Color(0.45, 0.65, 0.40, 0.7)
const SHADOW: Color     = Color(0.0, 0.0, 0.05, 0.4)

@onready var _shadow: Polygon2D = $Shadow
@onready var _legs: Polygon2D = $Body/Legs
@onready var _ribs: Polygon2D = $Body/Ribs
@onready var _skull: Polygon2D = $Body/Skull
@onready var _eye_glow: Polygon2D = $Body/EyeGlow
@onready var _arm: Polygon2D = $ArmAnchor/Arm
@onready var _anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_paint()
	_build_animations()
	_anim.play(&"idle")

func _paint() -> void:
	# Shadow ellipse at feet
	var sh: PackedVector2Array = []
	var n := 14
	for i in n:
		var t := TAU * i / n
		sh.append(Vector2(11.0 * cos(t), 2.0 + 3.0 * sin(t)))
	_shadow.polygon = sh
	_shadow.color = SHADOW

	# Legs (two bone pillars)
	_legs.color = BONE
	_legs.polygon = PackedVector2Array([
		Vector2(-4, 0), Vector2(-1, 0), Vector2(-1, -16), Vector2(-3, -16),
		Vector2(-3, -16), Vector2(-1, -16), Vector2(-1, 0), Vector2(-4, 0),
		# right leg starts here as the next sub-polygon won't render in
		# one Polygon2D — keep simple: just two narrow rects.
	])
	# Simpler: a single trapezoid suggesting both legs.
	_legs.polygon = PackedVector2Array([
		Vector2(-5, 0), Vector2(5, 0), Vector2(4, -18), Vector2(-4, -18),
	])

	# Ribcage (bone-dark to suggest hollow space)
	_ribs.color = BONE_DARK
	_ribs.polygon = PackedVector2Array([
		Vector2(-7, -18), Vector2(7, -18), Vector2(6, -36), Vector2(-6, -36),
	])

	# Skull
	_skull.color = BONE
	var sk: PackedVector2Array = []
	var ns := 12
	for i in ns:
		var t := TAU * i / ns
		sk.append(Vector2(6.0 * cos(t), -42.0 + 6.0 * sin(t)))
	_skull.polygon = sk

	# Eye glow (sickly green)
	_eye_glow.color = SICKLY_GREEN
	_eye_glow.polygon = PackedVector2Array([
		Vector2(-3, -42), Vector2(-1, -42), Vector2(-1, -40), Vector2(-3, -40),
	])

	# Arm — bone segment that swings on attack
	_arm.color = BONE
	_arm.polygon = PackedVector2Array([
		Vector2(0, -2), Vector2(2, -2), Vector2(2, 18), Vector2(0, 18),
	])

func _build_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle",   _anim_idle())
	lib.add_animation(&"walk",   _anim_walk())
	lib.add_animation(&"attack", _anim_attack())
	lib.add_animation(&"cast",   _anim_empty())
	lib.add_animation(&"hit",    _anim_hit())
	lib.add_animation(&"die",    _anim_die())
	_anim.add_animation_library(&"", lib)

func _anim_empty() -> Animation:
	var a := Animation.new()
	a.length = 0.05
	return a

func _anim_idle() -> Animation:
	var a := Animation.new()
	a.length = 1.6
	a.loop_mode = Animation.LOOP_LINEAR
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath("Body:position"))
	a.track_insert_key(ti, 0.0, Vector2.ZERO)
	a.track_insert_key(ti, 0.8, Vector2(0, -1))
	a.track_insert_key(ti, 1.6, Vector2.ZERO)
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
	var a := Animation.new()
	a.length = 0.4
	a.loop_mode = Animation.LOOP_NONE
	var ta := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ta, NodePath("ArmAnchor:rotation"))
	a.track_insert_key(ta, 0.0, 0.0)
	a.track_insert_key(ta, 0.15, -1.2)
	a.track_insert_key(ta, 0.4, 0.0)
	return a

func _anim_hit() -> Animation:
	var a := Animation.new()
	a.length = 0.15
	a.loop_mode = Animation.LOOP_NONE
	var tm := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tm, NodePath(".:modulate"))
	a.track_insert_key(tm, 0.00, Color(1, 1, 1, 1))
	a.track_insert_key(tm, 0.05, Color(1.6, 0.4, 0.4, 1))
	a.track_insert_key(tm, 0.15, Color(1, 1, 1, 1))
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
	a.track_insert_key(tm, 0.6, Color(1, 1, 1, 0.0))
	return a
