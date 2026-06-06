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
const HAIR: Color           = Color(0.22, 0.15, 0.10)
const EYE_PUPIL: Color      = Color(0.96, 0.92, 0.78)  # bright readable
const EYE_SOCKET: Color     = Color(0.10, 0.07, 0.06)
const BROW_C: Color         = Color(0.18, 0.12, 0.08)
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
@onready var _buckler: Polygon2D = $Body/Buckler
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
	# Override the default face-paint colors with high-contrast
	# values so eyes read at game zoom (Bone Servant approach).
	var face: Node2D = $Body/Face
	# Eye sockets (dark recesses)
	var sl: Polygon2D = face.get_node(^"EyeSocketL")
	sl.color = EYE_SOCKET
	sl.polygon = HumanRig.eye_socket_l_poly()
	var sr: Polygon2D = face.get_node(^"EyeSocketR")
	sr.color = EYE_SOCKET
	sr.polygon = HumanRig.eye_socket_r_poly()
	# Bright pupils
	var pl: Polygon2D = face.get_node(^"EyeL")
	pl.color = EYE_PUPIL
	pl.polygon = HumanRig.eye_pupil_l_poly()
	var pr: Polygon2D = face.get_node(^"EyeR")
	pr.color = EYE_PUPIL
	pr.polygon = HumanRig.eye_pupil_r_poly()
	# Brow bar
	var br: Polygon2D = face.get_node(^"Brow")
	br.color = BROW_C
	br.polygon = HumanRig.brow_poly()
	# Mouth
	var mo: Polygon2D = face.get_node(^"Mouth")
	mo.color = BROW_C
	mo.polygon = HumanRig.mouth_poly()

func _paint_hair() -> void:
	# Small dark cap on the crown so the head doesn't read as a flat
	# oval. Drawn into the existing Head polygon's color layer is
	# tricky; instead we tint the upper portion via the Brow node?
	# Cleanest is to leave hair off — the head outline alone reads
	# fine. Stub kept for future hair work.
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
	# Built-in buckler at the left forearm. Paperdoll will toggle
	# visibility / retint based on offhand equip.
	_buckler.color = BRONZE_DARK
	var cx := -13.5
	var cy := HumanRig.WAIST + 3
	var r := 7.0
	var buc: PackedVector2Array = []
	var n := 12
	for i in n:
		var t := TAU * i / n
		buc.append(Vector2(cx + r * cos(t), cy + r * sin(t)))
	_buckler.polygon = buc

# ---- SpearArm (just the spear; lives under the right hand) --------------
# SpearArm is a child of Body/ArmRShoulder/ElbowPivot at position
# (0, 10) — coincident with the right hand. All polygons local to
# that pivot; +y points down. At rest with all arm pivots at 0,
# SpearArm is at body y=-24 (the wrist).
#
# Reach: shaft butt at +25 (body y=+1, ground line); tip at -36
# (body y=-60, top of head). True hoplite spear length.

func _paint_spear() -> void:
	# Shaft: thin vertical strip reaching from above the head down
	# past the foot to the ground.
	_sa_shaft.color = LEATHER_DARK
	_sa_shaft.polygon = PackedVector2Array([
		Vector2(-1, 25), Vector2(1, 25),
		Vector2(1, -36), Vector2(-1, -36),
	])
	# Bronze grip wrap at the hand position (around y=0 in spear-local).
	_sa_grip.color = BRONZE
	_sa_grip.polygon = PackedVector2Array([
		Vector2(-1.5, -4), Vector2(1.5, -4),
		Vector2(1.5, 4),  Vector2(-1.5, 4),
	])
	# Bronze leaf-shaped spearhead at the top.
	_sa_tip.color = BRONZE
	_sa_tip.polygon = PackedVector2Array([
		Vector2(-2.8, -36), Vector2(2.8, -36),
		Vector2(2.0, -42), Vector2(0, -46), Vector2(-2.0, -42),
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
