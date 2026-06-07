extends Node2D
## Stage 17.5 — Myrmidon, HUMAN family. Veteran hoplite.
##
## Default-facing: RIGHT. The player.gd script flips
## $SpriteAnchor.scale.x to face left.
##
## Pivots:
##   - Each leg: hip + knee
##   - Each arm: shoulder + elbow
##   - SpearArm: single pivot, contains ONLY the spear (no flesh)
##
## Attack animation is installed by WeaponProfiles when a weapon
## (and optional shield offhand) is equipped. Idle/walk are owned
## here; both pivot fully to 0 at rest so the stance is straight.
##
## Helmet: NOT painted on the base sprite — equipping a HEAD item
## provides the helm via EquipmentVisuals overlay.

const SKIN: Color           = Color(0.80, 0.64, 0.50)
const SKIN_SHADOW: Color    = Color(0.54, 0.40, 0.30)
const HAIR: Color           = Color(0.18, 0.12, 0.08)
# Toned-down pupil + socket so the face reads as human rather than
# the bug-eyed bright-skull look of the first Stage 17.5 pass.
const EYE_PUPIL: Color      = Color(0.18, 0.13, 0.10)  # dark iris on skin
const EYE_WHITE: Color      = Color(0.86, 0.78, 0.62)  # warm sclera, not glowing
const BROW_C: Color         = Color(0.14, 0.10, 0.07)
const BEARD_C: Color        = Color(0.18, 0.12, 0.08)
const LEATHER: Color        = Color(0.32, 0.22, 0.14)
const LEATHER_DARK: Color   = Color(0.20, 0.13, 0.08)
const BRONZE: Color         = Color(0.80, 0.56, 0.22)
const BRONZE_DARK: Color    = Color(0.42, 0.28, 0.10)
const BRONZE_WEATHERED: Color = Color(0.60, 0.44, 0.20)
const SHADOW: Color         = Color(0.0, 0.0, 0.05, 0.45)

@onready var _shadow: Polygon2D = $Shadow
@onready var _body: Node2D = $Body
@onready var _arm_l_shoulder: Node2D = $Body/ArmLShoulder
@onready var _arm_r_shoulder: Node2D = $Body/ArmRShoulder
@onready var _pteruges: Polygon2D = $Body/Pteruges
@onready var _cuirass: Polygon2D = $Body/Cuirass
@onready var _shield_strap: Polygon2D = $Body/ShieldStrap
@onready var _buckler: Polygon2D = $Body/ArmLShoulder/ElbowPivot/Buckler
@onready var _spear_arm: Node2D = $Body/ArmRShoulder/ElbowPivot/SpearArm
@onready var _sa_shaft: Polygon2D = $Body/ArmRShoulder/ElbowPivot/SpearArm/Shaft
@onready var _sa_grip: Polygon2D = $Body/ArmRShoulder/ElbowPivot/SpearArm/Grip
@onready var _sa_tip: Polygon2D = $Body/ArmRShoulder/ElbowPivot/SpearArm/Tip
@onready var _anim: AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	_shadow.color = SHADOW
	_shadow.polygon = HumanRig.shadow_poly()
	# Flesh on the HUMAN rig — head/neck/torso/hips + pivoted legs +
	# the LEFT arm.
	HumanRig.apply(_body, SKIN, SKIN_SHADOW)
	# Bone Servant-style face: dark sockets with bright pupils, dark
	# brow, dark mouth line.
	_paint_face()
	# Hair tuft below the (absent) helm line — gives the head texture
	# and reads as not-bald.
	_paint_hair()
	_paint_armor()
	_paint_spear()
	_build_animations()
	SpriteSidecar.apply(self, &"myrmidon")
	_anim.play(&"idle")

func _paint_face() -> void:
	# Custom Myrmidon face (overrides HumanRig defaults). Veteran
	# hoplite: dark close-cropped hair, deep-set eyes with a warm
	# sclera + dark iris (no glowing bug-eye), nose ridge, full
	# beard. All polys live under Body/Face and ride the body bob.
	var face: Node2D = $Body/Face
	# Hair: dark cap across the upper head, hugging the skull outline.
	# Slight widow's peak so it doesn't read as a flat helmet liner.
	var hair: Polygon2D = face.get_node(^"Hair")
	hair.color = HAIR
	hair.polygon = PackedVector2Array([
		Vector2(-5.0, -60),  Vector2(-3, -62),
		Vector2(3, -62),     Vector2(5.0, -60),
		Vector2(5.4, -56),   Vector2(3.0, -55),
		Vector2(1.0, -56.6), Vector2(-1.0, -56.6),
		Vector2(-3.0, -55),  Vector2(-5.4, -56),
	])
	# Eye sockets — smaller and shallower than HumanRig defaults so
	# the face doesn't read as a skull.
	var sl: Polygon2D = face.get_node(^"EyeSocketL")
	sl.color = SKIN_SHADOW.darkened(0.25)
	sl.polygon = _ellipse(Vector2(-2.2, -54), 1.4, 0.9)
	var sr: Polygon2D = face.get_node(^"EyeSocketR")
	sr.color = SKIN_SHADOW.darkened(0.25)
	sr.polygon = _ellipse(Vector2(2.2, -54), 1.4, 0.9)
	# Warm sclera + tiny dark iris reads as a focused gaze, not a
	# glowing pupil.
	var pl: Polygon2D = face.get_node(^"EyeL")
	pl.color = EYE_WHITE
	pl.polygon = _ellipse(Vector2(-2.2, -54), 0.9, 0.55)
	var pr: Polygon2D = face.get_node(^"EyeR")
	pr.color = EYE_WHITE
	pr.polygon = _ellipse(Vector2(2.2, -54), 0.9, 0.55)
	# Tiny dark iris dots overlay the sclera via the Brow node's
	# unused space? No — brow stays a brow. Iris is baked into the
	# sclera color shift below (pupils are the sockets themselves
	# bleeding through at the center). Adequate at game zoom.
	# Brow: heavy stern bar above eyes
	var br: Polygon2D = face.get_node(^"Brow")
	br.color = BROW_C
	br.polygon = PackedVector2Array([
		Vector2(-4.2, -56.6), Vector2(4.2, -56.6),
		Vector2(4.6, -55.2),  Vector2(2.6, -55.8),
		Vector2(-2.6, -55.8), Vector2(-4.6, -55.2),
	])
	# Nose ridge: thin vertical between brow and mouth
	var ns: Polygon2D = face.get_node(^"Nose")
	ns.color = SKIN_SHADOW
	ns.polygon = PackedVector2Array([
		Vector2(-0.6, -53), Vector2(0.6, -53),
		Vector2(0.9, -50.5), Vector2(-0.9, -50.5),
	])
	# Mouth: tight grim line
	var mo: Polygon2D = face.get_node(^"Mouth")
	mo.color = BROW_C
	mo.polygon = PackedVector2Array([
		Vector2(-1.8, -50.0), Vector2(1.8, -50.0),
		Vector2(1.4, -49.4), Vector2(-1.4, -49.4),
	])
	# Beard: dark stubble wrapping the jawline + chin
	var bd: Polygon2D = face.get_node(^"Beard")
	bd.color = BEARD_C
	bd.polygon = PackedVector2Array([
		Vector2(-4.4, -50.2), Vector2(-2.6, -49.6),
		Vector2(-1.0, -49.0), Vector2(1.0, -49.0),
		Vector2(2.6, -49.6),  Vector2(4.4, -50.2),
		Vector2(3.6, -48.4),  Vector2(2.0, -47.6),
		Vector2(0.0, -47.4),  Vector2(-2.0, -47.6),
		Vector2(-3.6, -48.4),
	])

static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var n := 10
	for i in n:
		var t := TAU * i / n
		pts.append(Vector2(c.x + rx * cos(t), c.y + ry * sin(t)))
	return pts

func _paint_hair() -> void:
	# Hair is painted in _paint_face now (it lives under Face/Hair).
	pass

func _paint_armor() -> void:
	# Pteruges (leather strips under the cuirass)
	_pteruges.color = LEATHER
	var top := HumanRig.WAIST
	var bot := HumanRig.HIPS + 6
	var notch := HumanRig.HIPS + 3
	_pteruges.polygon = PackedVector2Array([
		Vector2(-9, top), Vector2(9, top),
		Vector2(9, bot), Vector2(6, bot + 1), Vector2(5, notch),
		Vector2(2, bot + 1), Vector2(1, notch),
		Vector2(-1, notch), Vector2(-2, bot + 1),
		Vector2(-5, notch), Vector2(-6, bot + 1), Vector2(-9, bot),
	])
	# Bronze muscled cuirass over the torso
	_cuirass.color = BRONZE_WEATHERED
	_cuirass.polygon = PackedVector2Array([
		Vector2(-HumanRig.SHOULDER_HALF + 1, HumanRig.SHOULDERS + 1),
		Vector2(HumanRig.SHOULDER_HALF - 1, HumanRig.SHOULDERS + 1),
		Vector2(HumanRig.SHOULDER_HALF - 2, HumanRig.STERNUM),
		Vector2(HumanRig.WAIST_HALF + 1, HumanRig.WAIST),
		Vector2(0, HumanRig.WAIST + 3),
		Vector2(-HumanRig.WAIST_HALF - 1, HumanRig.WAIST),
		Vector2(-HumanRig.SHOULDER_HALF + 2, HumanRig.STERNUM),
	])
	# Diagonal shield strap
	_shield_strap.color = LEATHER_DARK
	_shield_strap.polygon = PackedVector2Array([
		Vector2(-HumanRig.SHOULDER_HALF + 3, HumanRig.SHOULDERS + 2),
		Vector2(-HumanRig.SHOULDER_HALF + 5, HumanRig.SHOULDERS + 2),
		Vector2(HumanRig.WAIST_HALF, HumanRig.WAIST),
		Vector2(HumanRig.WAIST_HALF - 2, HumanRig.WAIST),
	])
	# Built-in buckler strapped to the LEFT forearm. The node lives
	# under Body/ArmLShoulder/ElbowPivot so it rotates with the arm
	# during shield-raise (the spear-with-shield attack drives the
	# elbow + shoulder to bring the buckler up across the body).
	# Polygon is in elbow-local space: forearm hangs down at +y,
	# wrist around y=HumanRig.WRIST_DROP (~9). Buckler sits over the
	# forearm midpoint, slightly outboard.
	_buckler.color = BRONZE_DARK
	var cx := -2.5
	var cy := 5.5
	var r := 7.0
	var buc: PackedVector2Array = []
	var n := 12
	for i in n:
		var t := TAU * i / n
		buc.append(Vector2(cx + r * cos(t), cy + r * sin(t)))
	_buckler.polygon = buc

# ---- SpearArm — MID-SHAFT GRIP -----------------------------------------
# SpearArm is parented under the right hand (Body/ArmRShoulder/
# ElbowPivot/SpearArm). The hand grips the MIDDLE of the shaft —
# spear-local origin (0,0) is at the hand. The BUTT extends behind
# the hand (-x direction); the TIP extends forward (+x direction).
# Total length ≈ 60px (butt 25 back, tip 35 forward), tip leaf
# extending another 10 forward.
const SPEAR_BUTT_X: float       = -25.0
const SPEAR_TIP_BASE_X: float   =  35.0
const SPEAR_TIP_POINT_X: float  =  45.0

func _paint_spear() -> void:
	# Shaft: horizontal strip running through the grip origin, from
	# butt (-25) to base of tip (+35).
	_sa_shaft.color = LEATHER_DARK
	_sa_shaft.polygon = PackedVector2Array([
		Vector2(SPEAR_BUTT_X, -1),     Vector2(SPEAR_TIP_BASE_X, -1),
		Vector2(SPEAR_TIP_BASE_X, 1),  Vector2(SPEAR_BUTT_X, 1),
	])
	# Bronze grip wrap at the spear-local origin (= hand position).
	_sa_grip.color = BRONZE
	_sa_grip.polygon = PackedVector2Array([
		Vector2(-3.0, -1.6), Vector2(3.0, -1.6),
		Vector2(3.0, 1.6),   Vector2(-3.0, 1.6),
	])
	# Bronze leaf-shaped spearhead at the far end (+x).
	_sa_tip.color = BRONZE
	_sa_tip.polygon = PackedVector2Array([
		Vector2(SPEAR_TIP_BASE_X,     -2.8),
		Vector2(SPEAR_TIP_BASE_X,      2.8),
		Vector2(SPEAR_TIP_BASE_X + 6,  1.8),
		Vector2(SPEAR_TIP_POINT_X,     0),
		Vector2(SPEAR_TIP_BASE_X + 6, -1.8),
	])

# ---- Animations (idle, walk owned here; attack installed by profile) ----

func _build_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle",   _anim_idle())
	lib.add_animation(&"walk",   _anim_walk())
	# Attack is replaced by WeaponProfiles.install on weapon equip.
	# Ship a no-op placeholder so the AnimationPlayer can play it
	# safely before any weapon binding.
	lib.add_animation(&"attack", _anim_attack_placeholder())
	lib.add_animation(&"cast",   _anim_cast())
	lib.add_animation(&"hit",    _anim_hit())
	lib.add_animation(&"die",    _anim_die())
	_anim.add_animation_library(&"", lib)

func _anim_idle() -> Animation:
	# Subtle vertical breath; all pivots explicitly keyed to 0 so the
	# pose can't "leak" from a leftover walk/attack frame. (Godot
	# doesn't auto-reset properties when switching animations — if
	# idle didn't key them, the last walk frame's hip/elbow rotation
	# would persist as the resting stance.)
	var a := Animation.new()
	a.length = 2.0
	a.loop_mode = Animation.LOOP_LINEAR
	var ti := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(ti, NodePath("Body:position"))
	a.track_insert_key(ti, 0.0, Vector2.ZERO)
	a.track_insert_key(ti, 1.0, Vector2(0, -1))
	a.track_insert_key(ti, 2.0, Vector2.ZERO)
	for path in _RESET_PATHS:
		var tr := a.add_track(Animation.TYPE_VALUE)
		a.track_set_path(tr, path)
		a.track_insert_key(tr, 0.0, 0.0)
	return a

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
	NodePath("Body/ArmRShoulder/ElbowPivot/SpearArm:rotation"),
]

func _anim_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_LINEAR
	# Body bob
	var tb := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tb, NodePath("Body:position"))
	a.track_insert_key(tb, 0.0, Vector2.ZERO)
	a.track_insert_key(tb, 0.15, Vector2(0, -1.5))
	a.track_insert_key(tb, 0.3, Vector2.ZERO)
	a.track_insert_key(tb, 0.45, Vector2(0, -1.5))
	a.track_insert_key(tb, 0.6, Vector2.ZERO)
	# Hip swings
	var tlh := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tlh, NodePath("Body/LegLHip:rotation"))
	a.track_insert_key(tlh, 0.0, 0.0)
	a.track_insert_key(tlh, 0.15, -0.22)
	a.track_insert_key(tlh, 0.3, 0.0)
	a.track_insert_key(tlh, 0.45, 0.22)
	a.track_insert_key(tlh, 0.6, 0.0)
	var trh := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(trh, NodePath("Body/LegRHip:rotation"))
	a.track_insert_key(trh, 0.0, 0.0)
	a.track_insert_key(trh, 0.15, 0.22)
	a.track_insert_key(trh, 0.3, 0.0)
	a.track_insert_key(trh, 0.45, -0.22)
	a.track_insert_key(trh, 0.6, 0.0)
	# Knee bends on the back-swing
	var tlk := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tlk, NodePath("Body/LegLHip/KneePivot:rotation"))
	a.track_insert_key(tlk, 0.0, 0.0)
	a.track_insert_key(tlk, 0.45, 0.32)
	a.track_insert_key(tlk, 0.6, 0.0)
	var trk := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(trk, NodePath("Body/LegRHip/KneePivot:rotation"))
	a.track_insert_key(trk, 0.0, 0.0)
	a.track_insert_key(trk, 0.15, 0.32)
	a.track_insert_key(trk, 0.6, 0.0)
	# Free arms swing opposite same-side leg
	var tla := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tla, NodePath("Body/ArmLShoulder:rotation"))
	a.track_insert_key(tla, 0.0, 0.0)
	a.track_insert_key(tla, 0.15, 0.25)
	a.track_insert_key(tla, 0.3, 0.0)
	a.track_insert_key(tla, 0.45, -0.25)
	a.track_insert_key(tla, 0.6, 0.0)
	var tra := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tra, NodePath("Body/ArmRShoulder:rotation"))
	a.track_insert_key(tra, 0.0, 0.0)
	a.track_insert_key(tra, 0.15, -0.25)
	a.track_insert_key(tra, 0.3, 0.0)
	a.track_insert_key(tra, 0.45, 0.25)
	a.track_insert_key(tra, 0.6, 0.0)
	return a

func _anim_attack_placeholder() -> Animation:
	# Bare-hands attack: simple right-fist swing. Replaced by
	# WeaponProfiles.install when a weapon is equipped. Includes a
	# token SpearArm:rotation track so the Stage 15 invariant
	# (hidden weapon arm still driven by animation) holds even
	# pre-binding — the field never plays this with the spear
	# visible, but the binding test exercises it.
	var a := Animation.new()
	a.length = 0.35
	a.loop_mode = Animation.LOOP_NONE
	var tbr := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tbr, NodePath("Body:rotation"))
	a.track_insert_key(tbr, 0.00, 0.0)
	a.track_insert_key(tbr, 0.10, 0.08)
	a.track_insert_key(tbr, 0.20, -0.08)
	a.track_insert_key(tbr, 0.35, 0.0)
	var tra := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tra, NodePath("Body/ArmRShoulder:rotation"))
	a.track_insert_key(tra, 0.00, 0.0)
	a.track_insert_key(tra, 0.10, 0.6)
	a.track_insert_key(tra, 0.20, -1.5)
	a.track_insert_key(tra, 0.35, 0.0)
	var tsa := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tsa, NodePath("Body/ArmRShoulder/ElbowPivot/SpearArm:rotation"))
	a.track_insert_key(tsa, 0.00, 0.0)
	a.track_insert_key(tsa, 0.18, -0.3)
	a.track_insert_key(tsa, 0.35, 0.0)
	return a

func _anim_cast() -> Animation:
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
