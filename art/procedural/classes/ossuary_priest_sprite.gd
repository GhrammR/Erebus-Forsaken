extends Node2D
## Procedural Ossuary Priest sprite. AD-11 — implements the canonical
## AnimationPlayer track names.

const BONE: Color         = Color(0.92, 0.90, 0.80)
const BONE_DARK: Color    = Color(0.65, 0.62, 0.50)
const ROBE_DARK: Color    = Color(0.18, 0.16, 0.20)
const SICKLY_GREEN: Color = Color(0.45, 0.78, 0.45)
const SHADOW: Color       = Color(0.0, 0.0, 0.05, 0.45)

@onready var _shadow: Polygon2D = $Shadow
@onready var _robe: Polygon2D = $Body/Robe
@onready var _torso: Polygon2D = $Body/Torso
@onready var _shoulder_l: Polygon2D = $Body/ShoulderLeft
@onready var _shoulder_r: Polygon2D = $Body/ShoulderRight
@onready var _head: Polygon2D = $Body/Head
@onready var _hood: Polygon2D = $Body/Hood
@onready var _wand_shaft: Polygon2D = $WandArm/Shaft
@onready var _wand_glow: Polygon2D = $WandArm/Glow
@onready var _anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_paint()
	_build_animations()
	_anim.play(&"idle")

func _paint() -> void:
	# Shadow
	var sh: PackedVector2Array = []
	var n := 16
	for i in n:
		var t := TAU * i / n
		sh.append(Vector2(14.0 * cos(t), 2.0 + 4.0 * sin(t)))
	_shadow.color = SHADOW
	_shadow.polygon = sh

	# Long robe (dark)
	_robe.color = ROBE_DARK
	_robe.polygon = PackedVector2Array([
		Vector2(-11, 0), Vector2(11, 0), Vector2(8, -30), Vector2(-8, -30),
	])

	# Torso (dark robe continues)
	_torso.color = ROBE_DARK
	_torso.polygon = PackedVector2Array([
		Vector2(-8, -30), Vector2(8, -30), Vector2(7, -42), Vector2(-7, -42),
	])

	# Bone shoulder pieces (angular bulges)
	_shoulder_l.color = BONE
	_shoulder_l.polygon = PackedVector2Array([
		Vector2(-12, -32), Vector2(-6, -34), Vector2(-8, -40), Vector2(-13, -38),
	])
	_shoulder_r.color = BONE
	_shoulder_r.polygon = PackedVector2Array([
		Vector2(12, -32), Vector2(6, -34), Vector2(8, -40), Vector2(13, -38),
	])

	# Head (skull-ish, bone-pale)
	_head.color = BONE
	var hd: PackedVector2Array = []
	var nh := 12
	for i in nh:
		var t := TAU * i / nh
		hd.append(Vector2(5.0 * cos(t), -48.0 + 5.0 * sin(t)))
	_head.polygon = hd

	# Hood drape (dark, over and behind the head)
	_hood.color = ROBE_DARK
	_hood.polygon = PackedVector2Array([
		Vector2(-7, -42), Vector2(7, -42), Vector2(6, -52), Vector2(0, -56), Vector2(-6, -52),
	])

func _build_animations() -> void:
	# Wand: small bone stick with green glow at tip
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
	a.length = 1.4
	a.loop_mode = Animation.LOOP_LINEAR
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath("Body:position"))
	a.track_insert_key(ti, 0.0, Vector2.ZERO)
	a.track_insert_key(ti, 0.7, Vector2(0, -1))
	a.track_insert_key(ti, 1.4, Vector2.ZERO)
	return a

func _anim_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.42
	a.loop_mode = Animation.LOOP_LINEAR
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath("Body:position"))
	a.track_insert_key(ti, 0.0, Vector2.ZERO)
	a.track_insert_key(ti, 0.21, Vector2(0, -2))
	a.track_insert_key(ti, 0.42, Vector2.ZERO)
	return a

func _anim_attack() -> Animation:
	# Wand poke
	var a := Animation.new()
	a.length = 0.3
	a.loop_mode = Animation.LOOP_NONE
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath("WandArm:rotation"))
	a.track_insert_key(ti, 0.0, 0.0)
	a.track_insert_key(ti, 0.12, -0.4)
	a.track_insert_key(ti, 0.3, 0.0)
	return a

func _anim_cast() -> Animation:
	# Green glow swells as the minion is summoned
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_NONE
	var tg := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tg, NodePath("WandArm/Glow:modulate"))
	a.track_insert_key(tg, 0.0, Color(1, 1, 1, 1))
	a.track_insert_key(tg, 0.25, Color(2.0, 2.5, 1.0, 1))
	a.track_insert_key(tg, 0.6, Color(1, 1, 1, 1))
	var tm := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tm, NodePath(".:modulate"))
	a.track_insert_key(tm, 0.0, Color(1, 1, 1, 1))
	a.track_insert_key(tm, 0.25, Color(1.1, 1.3, 1.1, 1))
	a.track_insert_key(tm, 0.6, Color(1, 1, 1, 1))
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
