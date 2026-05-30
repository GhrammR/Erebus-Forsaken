extends Node2D
## Procedural Myrmidon sprite. AD-11 — implements the canonical
## AnimationPlayer track names: idle, walk, attack, cast, hit, die.
## Stage 2 actively exercises idle + walk. The other four are stubs so
## Stage 3+ does not refactor the sprite scene.
##
## Pivot is at the feet (y = 0). Negative y is up.

# Palette
const BRONZE: Color       = Color(0.72, 0.50, 0.20)
const BRONZE_DARK: Color  = Color(0.40, 0.27, 0.10)
const PLUME_RED: Color    = Color(0.55, 0.10, 0.10)
const SHADOW: Color       = Color(0.0, 0.0, 0.05, 0.45)

@onready var _shadow: Polygon2D = $Shadow
@onready var _legs: Polygon2D = $Body/Legs
@onready var _torso: Polygon2D = $Body/Torso
@onready var _buckler: Polygon2D = $Body/Buckler
@onready var _head: Polygon2D = $Body/Head
@onready var _plume: Polygon2D = $Body/Plume
@onready var _spear_arm: Node2D = $SpearArm
@onready var _spear_shaft: Polygon2D = $SpearArm/Shaft
@onready var _spear_tip: Polygon2D = $SpearArm/Tip
@onready var _anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_paint_shadow()
	_paint_body()
	_paint_spear()
	_build_animations()
	_anim.play(&"idle")

# ------------------------------------------------------------ geometry

func _paint_shadow() -> void:
	_shadow.color = SHADOW
	# Flat ellipse at feet, rx=14, ry=4, centered at (0, 2)
	var pts: PackedVector2Array = []
	var n := 16
	for i in n:
		var t := TAU * i / n
		pts.append(Vector2(14.0 * cos(t), 2.0 + 4.0 * sin(t)))
	_shadow.polygon = pts

func _paint_body() -> void:
	# Legs (darker bronze, y=-12 to y=0)
	_legs.color = BRONZE_DARK
	_legs.polygon = PackedVector2Array([
		Vector2(-6, 0), Vector2(6, 0), Vector2(5, -12), Vector2(-5, -12),
	])

	# Torso (bronze trapezoid, y=-36 to y=-12)
	_torso.color = BRONZE
	_torso.polygon = PackedVector2Array([
		Vector2(-10, -12), Vector2(10, -12), Vector2(8, -36), Vector2(-8, -36),
	])

	# Head / helm (darker bronze, y=-44 to y=-36)
	_head.color = BRONZE_DARK
	_head.polygon = PackedVector2Array([
		Vector2(-7, -36), Vector2(7, -36), Vector2(6, -44), Vector2(-6, -44),
	])

	# Plume (deep red triangle from helm top)
	_plume.color = PLUME_RED
	_plume.polygon = PackedVector2Array([
		Vector2(0, -52), Vector2(-7, -44), Vector2(7, -44),
	])

	# Buckler (round shield on left side, octagon ~radius 6 at (-13, -22))
	_buckler.color = BRONZE_DARK
	var cx := -13.0
	var cy := -22.0
	var r := 6.0
	var buc: PackedVector2Array = []
	var n := 8
	for i in n:
		var t := TAU * i / n
		buc.append(Vector2(cx + r * cos(t), cy + r * sin(t)))
	_buckler.polygon = buc

func _paint_spear() -> void:
	# SpearArm is positioned at (12, -22) in MyrmidonSprite space (set in .tscn).
	# Local rest rotation is -0.4 rad (spear angled up-right).
	# Shaft polygon is in SpearArm local space, pointing up (-y).
	_spear_shaft.color = BRONZE
	_spear_shaft.polygon = PackedVector2Array([
		Vector2(-1, 0), Vector2(1, 0), Vector2(1, -34), Vector2(-1, -34),
	])
	# Spear tip — small triangle on top
	_spear_tip.color = BRONZE
	_spear_tip.polygon = PackedVector2Array([
		Vector2(-3, -34), Vector2(3, -34), Vector2(0, -42),
	])

# ------------------------------------------------------------ animations
# Built in code so the Polygon2D geometry can be authored in code too.
# AD-11: track names match the bitmap-era sprite scenes that will
# replace this one. Calling code never changes during the swap.

const SPEAR_REST: float = -0.4

func _build_animations() -> void:
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
	a.length = 0.4
	a.loop_mode = Animation.LOOP_LINEAR
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath("Body:position"))
	a.track_insert_key(ti, 0.0, Vector2.ZERO)
	a.track_insert_key(ti, 0.1, Vector2(0, -2))
	a.track_insert_key(ti, 0.2, Vector2.ZERO)
	a.track_insert_key(ti, 0.3, Vector2(0, -2))
	a.track_insert_key(ti, 0.4, Vector2.ZERO)
	var ts := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ts, NodePath("SpearArm:rotation"))
	a.track_insert_key(ts, 0.0, SPEAR_REST)
	a.track_insert_key(ts, 0.2, SPEAR_REST - 0.08)
	a.track_insert_key(ts, 0.4, SPEAR_REST)
	return a

func _anim_attack() -> Animation:
	var a := Animation.new()
	a.length = 0.35
	a.loop_mode = Animation.LOOP_NONE
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath("SpearArm:rotation"))
	a.track_insert_key(ti, 0.00, SPEAR_REST)
	a.track_insert_key(ti, 0.10, -1.0)         # wind back
	a.track_insert_key(ti, 0.20, 0.4)          # thrust forward
	a.track_insert_key(ti, 0.35, SPEAR_REST)   # return to rest
	return a

func _anim_cast() -> Animation:
	# Gold flash on the whole sprite. Placeholder for skill VFX.
	var a := Animation.new()
	a.length = 0.4
	a.loop_mode = Animation.LOOP_NONE
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath(".:modulate"))
	a.track_insert_key(ti, 0.00, Color(1, 1, 1, 1))
	a.track_insert_key(ti, 0.15, Color(1.4, 1.2, 0.6, 1))
	a.track_insert_key(ti, 0.40, Color(1, 1, 1, 1))
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
	a.track_insert_key(tr, 0.6, PI / 2.0)
	var tm := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tm, NodePath(".:modulate"))
	a.track_insert_key(tm, 0.0, Color(1, 1, 1, 1))
	a.track_insert_key(tm, 0.6, Color(1, 1, 1, 0.3))
	return a
