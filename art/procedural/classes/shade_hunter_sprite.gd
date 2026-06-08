extends Node2D
## Stage 17.7 — ShadeHunter, HUMAN family. Hooded bow archer.

const MotionArchetypes = preload("res://scripts/systems/motion_archetypes.gd")
const BowStances       = preload("res://scripts/systems/stances/bow_stances.gd")
const AnatomyValidator = preload("res://scripts/systems/anatomy_validator.gd")

# Stage 17.8 — pick a stance from the catalog. Override at runtime
# (pose_tuner sets this via set_meta(&"stance_id", ...) before _ready
# of a freshly-instanced sprite).
@export var stance_id: StringName = &"forward_high_ready"

# Stage 17.8 — when false, runtime IK pin pass is skipped so the user
# can manually rotate shoulders/elbows via pose_tuner sliders without
# having the IK stomp them every frame. Production sprites leave this
# true; pose_tuner flips it for manual tuning.
@export var ik_enabled: bool = true
##
## Default-facing: RIGHT. Player flips $SpriteAnchor.scale.x to face left.
##
## Pivots:
##   - Each leg: hip + knee
##   - Each arm: shoulder + elbow
##   - BowArm: sibling subtree under Body. Anchored at body-local (8,-36)
##     where the bow's riser (centre grip) sits.
##
## Patterns ported from Pythia + Stage 17.7 infra:
##   1. HumanRig anatomy with cloak draped before arms
##   2. Marker-based dual IK pinning via HumanRig.apply_pins:
##        L hand → BowArm/RiserMarker (constant)
##        R hand → BowArm/NockMarker  (animated during draw)
##   3. Motion archetypes via MotionArchetypes.add_charge_release for
##      the bow draw; idle/walk are body bobs + breath holds.
##   4. Bowstring is a Line2D rebuilt every frame from BowTipTop →
##      NockMarker → BowTipBot so the string follows the nock during
##      the draw without per-frame keyframe authoring.
##   5. z_index = 2 on BowArm so equipment overlays don't eat the bow.

const SKIN: Color           = Color(0.78, 0.62, 0.50)
const SKIN_SHADOW: Color    = Color(0.54, 0.40, 0.30)
const CHARCOAL: Color       = Color(0.20, 0.20, 0.24)
const CHARCOAL_DARK: Color  = Color(0.10, 0.10, 0.14)
const CLOAK_COLOR: Color    = Color(0.16, 0.18, 0.22)
const HOOD_COLOR: Color     = Color(0.10, 0.12, 0.16)
const PALE_TEAL: Color      = Color(0.55, 0.78, 0.80)
const BOW_WOOD: Color       = Color(0.62, 0.46, 0.28)   # lighter so it pops vs cloak
const BOW_WOOD_DARK: Color  = Color(0.30, 0.20, 0.10)
const BOW_HIGHLIGHT: Color  = Color(0.82, 0.66, 0.42)
const SHADOW: Color         = Color(0.0, 0.0, 0.05, 0.45)

# Bow geometry (bow-local space — origin at riser).
const BOW_LIMB_HALF: float = 17.0    # top tip y = -17, bottom tip y = +17
const BOW_DEPTH: float     = 5.5     # how far the limbs curve forward (+x)
const BOW_THICKNESS: float = 1.6     # radial half-thickness of the limb strip
const BOW_GRIP_HALF: float = 5.0     # vertical extent of the grip wrap

# Per-stance values loaded at _ready from BowStances. Defaults match
# forward_high_ready so the catalog is purely additive.
var _nock_rest: Vector2  = Vector2(-12, 0)
var _nock_drawn: Vector2 = Vector2(-19, 0)
var _attack_len: float   = 0.9
var _draw_frac: float    = 0.30
var _release_frac: float = 0.75

# Animation tuning.
const IDLE_LEN: float    = 1.6
const WALK_LEN: float    = 0.45

@onready var _shadow: Polygon2D = $Shadow
@onready var _body: Node2D = $Body
@onready var _cloak: Polygon2D = $Body/Cloak
@onready var _hood: Polygon2D = $Body/Hood
@onready var _bow_arm: Node2D = $Body/BowArm
@onready var _bow: Polygon2D = $Body/BowArm/Bow
@onready var _bowstring: Line2D = $Body/BowArm/Bowstring
@onready var _nock_marker: Marker2D = $Body/BowArm/NockMarker
@onready var _bow_tip_top: Marker2D = $Body/BowArm/BowTipTop
@onready var _bow_tip_bot: Marker2D = $Body/BowArm/BowTipBot
@onready var _anim: AnimationPlayer = $AnimationPlayer

# Stage 17.7 — marker-driven dual IK pin table. Both arms welded to the
# bow every frame: L hand to the riser (static), R hand to the nock
# (animated). Pose authoring becomes "move the markers, arms follow."
const PIN_TABLE: Array = [
	# R arm = bow hand on the riser. Front-facing in screen space, so
	# its forearm + hand stay readable in front of the cloak.
	{
		"shoulder":   ^"Body/ArmRShoulder",
		"target":     ^"Body/BowArm/RiserMarker",
		"elbow_dir":  +1,
		"skip_anims": [],
	},
	# L arm = draw hand on the nock. Pinned ONLY during the attack —
	# real archers don't keep both hands on the bow at rest. At idle/
	# walk the L arm hangs freely, which also lets the bow live further
	# forward (out of L arm's reach for a chest-grip rest pose).
	{
		"shoulder":   ^"Body/ArmLShoulder",
		"target":     ^"Body/BowArm/NockMarker",
		"elbow_dir":  -1,
		"skip_anims": [&"idle", &"walk"],
	},
]

func _ready() -> void:
	# Stage 17.8 — apply the selected stance from the catalog before
	# painting. BowArm position + nock travel come from data.
	var stance: Dictionary = BowStances.get_stance(stance_id)
	_bow_arm.position = stance["bow_arm_pos"]
	_bow_arm.rotation = stance["bow_arm_rot"]
	_nock_rest = stance["nock_rest"]
	_nock_drawn = stance["nock_drawn"]
	_attack_len = stance["attack_len"]
	_draw_frac = stance["draw_frac"]
	_release_frac = stance["release_frac"]
	# Recommended-stance overrides: if the user has tuned this stance
	# in pose_tuner and pressed S, tmp/recommended_stances.json contains
	# their numeric overrides. REST snapshot → bow placement + nock_rest;
	# STRIKE snapshot → nock_drawn. Layered on top of the catalog so
	# absent fields fall through to defaults.
	_apply_recommended_overrides()
	_nock_marker.position = _nock_rest
	_shadow.color = SHADOW
	_shadow.polygon = HumanRig.shadow_poly()
	HumanRig.apply(_body, SKIN, SKIN_SHADOW)
	HumanRig.paint_face(_body, PALE_TEAL, CHARCOAL_DARK)
	_paint_cloak()
	_paint_hood()
	_paint_bow()
	_build_animations()
	_anim.play(&"idle")
	# Pin both arms to the bow every frame (after AnimationPlayer
	# advances the nock track).
	get_tree().process_frame.connect(_apply_pins_and_string)

## Layer user-tuned overrides from tmp/recommended_stances.json on top
## of the catalog defaults. File schema:
##   {
##     "shade_hunter": {
##       "<stance_id>": {
##         "REST":   { "weapon_arm_pos": [x, y], "weapon_arm_rot": r,
##                     "NockMarker":  [x, y], ... },
##         "STRIKE": { "NockMarker":  [x, y], ... },
##       }
##     }
##   }
func _apply_recommended_overrides() -> void:
	var f := FileAccess.open("res://tmp/recommended_stances.json", FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var classes: Dictionary = parsed
	var by_class: Dictionary = classes.get("shade_hunter", {})
	var by_stance: Dictionary = by_class.get(String(stance_id), {})
	if by_stance.is_empty():
		return
	# REST snapshot governs the resting bow placement + nock_rest.
	var rest: Dictionary = by_stance.get("REST", {})
	if rest.has("weapon_arm_pos"):
		var p: Array = rest["weapon_arm_pos"]
		_bow_arm.position = Vector2(float(p[0]), float(p[1]))
	if rest.has("weapon_arm_rot"):
		_bow_arm.rotation = float(rest["weapon_arm_rot"])
	if rest.has("NockMarker"):
		var nm: Array = rest["NockMarker"]
		_nock_rest = Vector2(float(nm[0]), float(nm[1]))
	# STRIKE snapshot governs the drawn nock position (and optionally
	# overrides the bow placement during strike — captured but not
	# applied here because the body lean already handles in-strike
	# offsets).
	var strike: Dictionary = by_stance.get("STRIKE", {})
	if strike.has("NockMarker"):
		var nd: Array = strike["NockMarker"]
		_nock_drawn = Vector2(float(nd[0]), float(nd[1]))
	print("[shade_hunter] applied recommended overrides for stance=%s" % stance_id)

# ---- Runtime IK + bowstring ---------------------------------------------

func _apply_pins_and_string() -> void:
	if ik_enabled:
		HumanRig.apply_pins(self, _body, PIN_TABLE, _anim.current_animation)
	# Rebuild the bowstring as [top tip → nock → bottom tip] in bow-local
	# coords. Line2D inherits the parent's transform so we keep things
	# in bow-local space for simplicity.
	if _bowstring != null and _nock_marker != null:
		_bowstring.points = PackedVector2Array([
			_bow_tip_top.position,
			_nock_marker.position,
			_bow_tip_bot.position,
		])

# ---- Cloak / hood -------------------------------------------------------

func _paint_cloak() -> void:
	# Cloak drapes from shoulders to mid-calf behind the body. Slight
	# A-line silhouette so it reads as fabric, not a slab.
	_cloak.color = CLOAK_COLOR
	_cloak.polygon = PackedVector2Array([
		Vector2(-11.0, HumanRig.SHOULDERS + 1),
		Vector2( 11.0, HumanRig.SHOULDERS + 1),
		Vector2( 13.0, HumanRig.WAIST),
		Vector2( 14.0, HumanRig.HIPS + 6),
		Vector2(  6.0, HumanRig.KNEES + 2),
		Vector2( -6.0, HumanRig.KNEES + 2),
		Vector2(-14.0, HumanRig.HIPS + 6),
		Vector2(-13.0, HumanRig.WAIST),
	])

func _paint_hood() -> void:
	# Hood pulls forward over the brow — leaves the eyes in shadow.
	_hood.color = HOOD_COLOR
	_hood.polygon = PackedVector2Array([
		Vector2(-7.0, HumanRig.NECK_BOTTOM),
		Vector2( 7.0, HumanRig.NECK_BOTTOM),
		Vector2( 8.0, HumanRig.HEAD_TOP + 6),
		Vector2( 5.0, HumanRig.HEAD_TOP - 1),
		Vector2(-5.0, HumanRig.HEAD_TOP - 1),
		Vector2(-8.0, HumanRig.HEAD_TOP + 6),
	])

# ---- Bow + bowstring ----------------------------------------------------

func _paint_bow() -> void:
	# C-curve recurve bow: a vertical arc with the limbs curving forward
	# (+x in bow-local). Use a thin spline traced twice (outer + inner)
	# to give the bow a wood-grain thickness.
	var outer: PackedVector2Array = []
	var inner: PackedVector2Array = []
	var samples := 14
	for i in samples + 1:
		var t: float = float(i) / float(samples)  # 0..1
		var y: float = lerp(-BOW_LIMB_HALF, BOW_LIMB_HALF, t)
		# Bell curve forward bend — max at y=0 (riser), tapers to 0 at tips.
		var bend: float = BOW_DEPTH * (1.0 - pow(abs(y) / BOW_LIMB_HALF, 1.4))
		outer.append(Vector2(bend + BOW_THICKNESS, y))
		inner.append(Vector2(bend - BOW_THICKNESS, y))
	# Close as a strip: outer forward, then inner backward.
	var pts: PackedVector2Array = []
	pts.append_array(outer)
	for i in range(inner.size() - 1, -1, -1):
		pts.append(inner[i])
	_bow.color = BOW_WOOD
	_bow.polygon = pts
	# Bowstring initial points so the first rendered frame isn't empty.
	_bowstring.points = PackedVector2Array([
		_bow_tip_top.position,
		_nock_marker.position,
		_bow_tip_bot.position,
	])

# =========================================================================
# ANIMATIONS — composed from MotionArchetypes helpers.
# =========================================================================

func _build_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle",   _anim_idle())
	lib.add_animation(&"walk",   _anim_walk())
	lib.add_animation(&"attack", _anim_attack())
	lib.add_animation(&"cast",   _anim_attack())   # cast aliases attack
	lib.add_animation(&"hit",    _anim_hit())
	lib.add_animation(&"die",    _anim_die())
	_anim.add_animation_library(&"", lib)

func _anim_idle() -> Animation:
	var a := MotionArchetypes.make_anim(IDLE_LEN, Animation.LOOP_LINEAR)
	MotionArchetypes.add_body_bob(a, ^"Body", 1.0, IDLE_LEN)
	# Nock is held at rest — explicit hold so any prior animation's
	# residual nock translation is overridden the moment idle starts.
	MotionArchetypes.add_hold(a, ^"Body/BowArm/NockMarker:position", _nock_rest)
	return a

func _anim_walk() -> Animation:
	var a := MotionArchetypes.make_anim(WALK_LEN, Animation.LOOP_LINEAR)
	MotionArchetypes.add_body_bob(a, ^"Body", 2.0, WALK_LEN)
	MotionArchetypes.add_hold(a, ^"Body/BowArm/NockMarker:position", _nock_rest)
	# Simple opposing leg swing — front leg forward in first half, back in second.
	MotionArchetypes.add_value_track(a, ^"Body/LegLHip:rotation", [
		[0.0, 0.20], [WALK_LEN * 0.5, -0.20], [WALK_LEN, 0.20],
	])
	MotionArchetypes.add_value_track(a, ^"Body/LegRHip:rotation", [
		[0.0, -0.20], [WALK_LEN * 0.5, 0.20], [WALK_LEN, -0.20],
	])
	return a

func _anim_attack() -> Animation:
	# CHARGE_RELEASE driven by per-stance timing. The L arm's actual
	# hand position is dictated by the pin to NockMarker each frame —
	# the R-shoulder rotation hint here just biases the IK seed.
	var a := MotionArchetypes.make_anim(_attack_len, Animation.LOOP_NONE)
	MotionArchetypes.add_charge_release(a,
		^"Body/BowArm/NockMarker:position",
		^"Body/ArmRShoulder",
		_nock_rest, _nock_drawn,
		0.0, -0.6,
		_attack_len,
		_draw_frac, _release_frac,
	)
	# Subtle body lean back during draw — sells the tension.
	MotionArchetypes.add_value_track(a, ^"Body:position", [
		[0.0,                       Vector2.ZERO],
		[_attack_len * _draw_frac,  Vector2(-1, 0)],
		[_attack_len * _release_frac, Vector2(-1, 0)],
		[_attack_len,               Vector2.ZERO],
	])
	return a

func _anim_hit() -> Animation:
	var a := MotionArchetypes.make_anim(0.15, Animation.LOOP_NONE)
	MotionArchetypes.add_value_track(a, ^".:modulate", [
		[0.0,  Color(1, 1, 1, 1)],
		[0.05, Color(1.6, 0.4, 0.4, 1)],
		[0.15, Color(1, 1, 1, 1)],
	], Animation.INTERPOLATION_LINEAR)
	return a

func _anim_die() -> Animation:
	var a := MotionArchetypes.make_anim(0.6, Animation.LOOP_NONE)
	MotionArchetypes.add_value_track(a, ^".:rotation", [
		[0.0, 0.0], [0.6, PI / 2.0],
	], Animation.INTERPOLATION_LINEAR)
	MotionArchetypes.add_value_track(a, ^".:modulate", [
		[0.0, Color(1, 1, 1, 1)],
		[0.6, Color(1, 1, 1, 0.3)],
	], Animation.INTERPOLATION_LINEAR)
	return a
