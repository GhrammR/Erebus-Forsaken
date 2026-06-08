extends Node2D
## Stage 17.6 — Pythia, HUMAN family. Oracle / staff-caster.
##
## Default-facing: RIGHT. Player flips $SpriteAnchor.scale.x to face left.
##
## Pivots:
##   - Each leg: hip + knee
##   - Each arm: shoulder + elbow
##   - StaffArm: parented under the RIGHT hand. Origin is at the hand;
##     the staff body extends BOTH directions from there (mid-grip).
##
## Patterns ported from Myrmidon (commit cb3c62b):
##   1. Mid-grip weapon polygon: butt at -22, orb at +28 (staff)
##   2. Arm-swing-not-shaft-rotate: ArmRShoulder swings forward;
##      StaffArm:rotation stays at 0 across the attack.
##   3. Built-in offhand z_index=1: N/A — Pythia has no built-in
##      offhand (Stage 15 puts a focus on the LEFT hip via overlay).
##   4. Dual-tracker debug overlay: sprite_render.gd traces hand
##      + tip generically via EquipmentVisuals.weapon_arm_for().
##
## Attack animation is installed by WeaponProfiles on equip.

const SKIN: Color           = Color(0.86, 0.74, 0.62)  # paler than Myrmidon
const SKIN_SHADOW: Color    = Color(0.58, 0.44, 0.36)
const HAIR: Color           = Color(0.16, 0.10, 0.16)
const EYE_PUPIL: Color      = Color(0.88, 0.84, 0.72)  # pale oracle eye
const EYE_SOCKET: Color     = Color(0.40, 0.30, 0.36)
const ROBE_VIOLET: Color    = Color(0.30, 0.18, 0.42)
const ROBE_LIGHT: Color     = Color(0.48, 0.30, 0.65)
const HOOD_DARK: Color      = Color(0.20, 0.12, 0.28)
const STAFF_WOOD: Color     = Color(0.36, 0.22, 0.14)
const STAFF_WOOD_DARK: Color = Color(0.20, 0.12, 0.07)
const GOLD: Color           = Color(0.85, 0.72, 0.30)
const ORB_GLOW: Color       = Color(0.95, 0.86, 0.55)
const SHADOW: Color         = Color(0.0, 0.0, 0.05, 0.45)

@onready var _shadow: Polygon2D = $Shadow
@onready var _body: Node2D = $Body
@onready var _robe: Polygon2D = $Body/Robe
@onready var _mantle: Polygon2D = $Body/Mantle
@onready var _hood: Polygon2D = $Body/Hood
@onready var _staff_arm: Node2D = $Body/ArmRShoulder/ElbowPivot/StaffArm
@onready var _sa_shaft: Polygon2D = $Body/ArmRShoulder/ElbowPivot/StaffArm/Shaft
@onready var _sa_grip: Polygon2D = $Body/ArmRShoulder/ElbowPivot/StaffArm/Grip
@onready var _sa_left_grip: Polygon2D = $Body/ArmRShoulder/ElbowPivot/StaffArm/LeftGrip
@onready var _sa_orb: Polygon2D = $Body/ArmRShoulder/ElbowPivot/StaffArm/Orb
@onready var _anim: AnimationPlayer = $AnimationPlayer

# Stage 17.8 — pose_tuner sets this false for manual arm tuning.
@export var ik_enabled: bool = true

const SpriteOverrides = preload("res://scripts/systems/sprite_overrides.gd")

# Per-anim configs loaded from tmp/recommended_stances.json.
# Stance id for Pythia: hard-coded "diagonal_back_legacy" until staff
# stance selection moves into a real @export var.
var _stance_id: StringName = &"diagonal_back_legacy"
var _per_anim_config: Dictionary = {}
var _tuned_anims: Dictionary = {}

# Stage 17.7 — marker-based IK pin table. HumanRig.apply_pins reads this
# every frame and rotates the L arm so its hand lands on LeftGripMarker.
# `skip_anims` excludes the cast pose (L arm intentionally extends out).
const PIN_TABLE: Array = [
	# soft=true: with R hand anchored at hip and staff diagonal up-back,
	# the LeftGripMarker is geometrically beyond L arm reach (validator
	# flags 35-39px against max 20). The runtime IK degrades to "fully
	# extended toward target" and the rendered pose still reads
	# acceptably, so this is acknowledged as a known-degraded pin. The
	# clean fix is a chest-grip stance (see staff_stances.gd) that the
	# user can score in pose_tuner and adopt as the new default.
	{
		"shoulder":   ^"Body/ArmLShoulder",
		"target":     ^"Body/ArmRShoulder/ElbowPivot/StaffArm/LeftGripMarker",
		"elbow_dir":  -1,
		"skip_anims": [&"cast"],
		"soft":       true,
	},
]

func _ready() -> void:
	_shadow.color = SHADOW
	_shadow.polygon = HumanRig.shadow_poly()
	HumanRig.apply(_body, SKIN, SKIN_SHADOW)
	_paint_face()
	_paint_robe()
	_paint_staff()
	_build_animations()
	SpriteSidecar.apply(self, &"pythia")
	# Stage 17.8 — load per-anim tuning configs and rebuild any
	# animation whose joints the user has explicitly set. The hook
	# fires on every play so newly-installed weapon-profile anims also
	# pick up the user's tuned rotations.
	_per_anim_config = SpriteOverrides.load_for_class(&"pythia", _stance_id)
	for anim_name in _per_anim_config:
		if SpriteOverrides.is_tuned(_per_anim_config[anim_name]):
			_tuned_anims[anim_name] = true
	_anim.animation_started.connect(_on_anim_started)
	_anim.play(&"idle")
	# Stage 17.6 — runtime IK on the LEFT arm so its hand polygon stays
	# pinned to the LeftGrip cosmetic on the staff every frame. R arm
	# is the staff anchor (StaffArm parented under R) and follows the
	# animation tracks directly; L arm is the "off-hand" that grips
	# the upper shaft. Without IK, the L hand would drift out of sync
	# with the staff during motion. Hooked to tree.process_frame so the
	# override runs AFTER AnimationPlayer advances tracks.
	get_tree().process_frame.connect(_apply_pins)

# ---- Runtime IK ---------------------------------------------------------
# Driven by PIN_TABLE + HumanRig.apply_pins (shared marker-based system).
# Pythia pins L arm to LeftGripMarker on the staff every frame so the
# hand stays welded to the upper shaft regardless of staff rotation.

func _apply_pins() -> void:
	if _staff_arm == null or not _staff_arm.visible:
		return
	if not ik_enabled:
		return
	# Skip IK for animations the user has tuned by hand — animation
	# tracks own those joints now.
	if _tuned_anims.has(String(_anim.current_animation)):
		return
	HumanRig.apply_pins(self, _body, PIN_TABLE, _anim.current_animation)

# Rebuild the active anim with tuned-rotation tracks injected. Fires
# every time play() starts a (possibly newly-installed) anim, so the
# WeaponProfiles staff-attack anim picks up the user's rotations.
func _on_anim_started(anim_name: StringName) -> void:
	var cfg: Dictionary = _per_anim_config.get(String(anim_name), {})
	if not SpriteOverrides.is_tuned(cfg):
		return
	var lib: AnimationLibrary = _anim.get_animation_library(&"")
	if lib == null or not lib.has_animation(anim_name):
		return
	var anim: Animation = lib.get_animation(anim_name)
	SpriteOverrides.inject_tuned_rotations(anim, cfg)

func _paint_face() -> void:
	HumanRig.paint_face(_body, EYE_PUPIL, EYE_SOCKET)

# ---- Robe / Mantle / Hood ------------------------------------------------
# Pythia's silhouette reads as "violet draped figure with hood." The
# robe overlays the hips + thighs (down to mid-shin), the mantle drapes
# across the shoulders + upper chest, and the hood frames the head
# from behind/above.

func _paint_robe() -> void:
	# Long robe — wider at the hem. Drawn in body-local space, sits in
	# front of the bare flesh but BEHIND the arms so a reach forward
	# doesn't sink into the fabric.
	_robe.color = ROBE_VIOLET
	_robe.polygon = PackedVector2Array([
		Vector2(-HumanRig.WAIST_HALF - 0.5, HumanRig.WAIST),
		Vector2(HumanRig.WAIST_HALF + 0.5,  HumanRig.WAIST),
		Vector2(HumanRig.HIP_HALF + 1.2,    HumanRig.HIPS),
		Vector2(HumanRig.HIP_HALF + 2.6,    HumanRig.KNEES - 4),
		Vector2(-HumanRig.HIP_HALF - 2.6,   HumanRig.KNEES - 4),
		Vector2(-HumanRig.HIP_HALF - 1.2,   HumanRig.HIPS),
	])
	# Mantle: V-shaped cowl across the upper torso.
	_mantle.color = ROBE_LIGHT
	_mantle.polygon = PackedVector2Array([
		Vector2(-HumanRig.SHOULDER_HALF - 0.5, HumanRig.SHOULDERS + 1),
		Vector2(HumanRig.SHOULDER_HALF + 0.5,  HumanRig.SHOULDERS + 1),
		Vector2(HumanRig.SHOULDER_HALF - 2,    HumanRig.STERNUM + 1),
		Vector2(1.4, HumanRig.STERNUM + 4.5),
		Vector2(0,   HumanRig.STERNUM + 6),
		Vector2(-1.4, HumanRig.STERNUM + 4.5),
		Vector2(-HumanRig.SHOULDER_HALF + 2,   HumanRig.STERNUM + 1),
	])
	# Hood: violet drape arching above the head, dipping behind the
	# temples. Renders AFTER face so the cowl frames the brow line.
	_hood.color = HOOD_DARK
	_hood.polygon = PackedVector2Array([
		Vector2(-HumanRig.HEAD_HALF_W - 1.8, HumanRig.CHIN - 2),
		Vector2(-HumanRig.HEAD_HALF_W - 2.2, HumanRig.HEAD_MID - 2),
		Vector2(-HumanRig.HEAD_HALF_W - 1.6, HumanRig.HEAD_TOP - 1),
		Vector2(0, HumanRig.HEAD_TOP - 3.5),
		Vector2(HumanRig.HEAD_HALF_W + 1.6,  HumanRig.HEAD_TOP - 1),
		Vector2(HumanRig.HEAD_HALF_W + 2.2,  HumanRig.HEAD_MID - 2),
		Vector2(HumanRig.HEAD_HALF_W + 1.8,  HumanRig.CHIN - 2),
		Vector2(HumanRig.HEAD_HALF_W + 0.4,  HumanRig.HEAD_MID - 4),
		Vector2(-HumanRig.HEAD_HALF_W - 0.4, HumanRig.HEAD_MID - 4),
	])

# ---- StaffArm — MID-SHAFT GRIP ------------------------------------------
# Hand-pivot origin sits at the spear-local (0,0). Butt extends -x
# (behind the hand), orb caps the +x end. Same pattern as Myrmidon's
# spear. Total length ≈ 50px so the staff stays readable at game zoom
# without overshooting the SubViewport edge during forward swings.

const STAFF_BUTT_X: float = -22.0
const STAFF_TIP_X: float  = 28.0
const ORB_R: float        = 3.2
# Cosmetic left-hand grip lives partway up the +x extension of the
# shaft (between the right-hand grip at origin and the orb at +28).
# Parented to StaffArm so it rotates with the staff.
const STAFF_LEFT_GRIP_X: float = 11.0

func _paint_staff() -> void:
	# Shaft: dark wood, thin horizontal strip through the grip origin.
	_sa_shaft.color = STAFF_WOOD
	_sa_shaft.polygon = PackedVector2Array([
		Vector2(STAFF_BUTT_X, -1), Vector2(STAFF_TIP_X, -1),
		Vector2(STAFF_TIP_X,  1),  Vector2(STAFF_BUTT_X, 1),
	])
	# Gold grip wrap at the hand position (spear-local origin).
	_sa_grip.color = GOLD
	_sa_grip.polygon = PackedVector2Array([
		Vector2(-3.0, -1.7), Vector2(3.0, -1.7),
		Vector2(3.0,  1.7),  Vector2(-3.0, 1.7),
	])
	# Cosmetic left-hand wrap on the upper shaft. Skin-colored, sized
	# like the actual hand polygon (~2.6 radius) so the silhouette
	# reads as a fist gripping the staff. Rotates with the staff.
	_sa_left_grip.color = SKIN
	var lg: PackedVector2Array = []
	var ln := 10
	for i in ln:
		var t := TAU * i / ln
		lg.append(Vector2(STAFF_LEFT_GRIP_X + 2.6 * cos(t), 2.2 * sin(t)))
	_sa_left_grip.polygon = lg
	# Glowing orb cap at the +x end. Centered slightly forward of the
	# shaft's tip so the orb reads as a separate ornament, not a
	# blunt cap.
	_sa_orb.color = ORB_GLOW
	var pts: PackedVector2Array = []
	var n := 12
	for i in n:
		var t := TAU * i / n
		pts.append(Vector2(STAFF_TIP_X + 1.5 + ORB_R * cos(t),
				ORB_R * sin(t)))
	_sa_orb.polygon = pts

# ---- Animations (idle, walk owned here; attack installed by profile) ----

func _build_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle",   _anim_idle())
	lib.add_animation(&"walk",   _anim_walk())
	lib.add_animation(&"attack", _anim_attack_placeholder())
	lib.add_animation(&"cast",   _anim_cast())
	lib.add_animation(&"hit",    _anim_hit())
	lib.add_animation(&"die",    _anim_die())
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
	NodePath("Body/ArmRShoulder/ElbowPivot/StaffArm:rotation"),
]

func _anim_idle() -> Animation:
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

func _anim_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_LINEAR
	var tb := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tb, NodePath("Body:position"))
	a.track_insert_key(tb, 0.0, Vector2.ZERO)
	a.track_insert_key(tb, 0.15, Vector2(0, -1.5))
	a.track_insert_key(tb, 0.3, Vector2.ZERO)
	a.track_insert_key(tb, 0.45, Vector2(0, -1.5))
	a.track_insert_key(tb, 0.6, Vector2.ZERO)
	var tlh := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tlh, NodePath("Body/LegLHip:rotation"))
	a.track_insert_key(tlh, 0.0, 0.0)
	a.track_insert_key(tlh, 0.15, -0.18)
	a.track_insert_key(tlh, 0.3, 0.0)
	a.track_insert_key(tlh, 0.45, 0.18)
	a.track_insert_key(tlh, 0.6, 0.0)
	var trh := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(trh, NodePath("Body/LegRHip:rotation"))
	a.track_insert_key(trh, 0.0, 0.0)
	a.track_insert_key(trh, 0.15, 0.18)
	a.track_insert_key(trh, 0.3, 0.0)
	a.track_insert_key(trh, 0.45, -0.18)
	a.track_insert_key(trh, 0.6, 0.0)
	# Left arm swings; right arm holds the staff steady at the side
	# (free swing would whip the staff around her head, reading as
	# combat instead of travel).
	var tla := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tla, NodePath("Body/ArmLShoulder:rotation"))
	a.track_insert_key(tla, 0.0, 0.0)
	a.track_insert_key(tla, 0.15, 0.25)
	a.track_insert_key(tla, 0.3, 0.0)
	a.track_insert_key(tla, 0.45, -0.25)
	a.track_insert_key(tla, 0.6, 0.0)
	return a

func _anim_attack_placeholder() -> Animation:
	# Bare-hands fallback (no weapon). Replaced by WeaponProfiles on
	# staff equip. Keeps a token StaffArm:rotation track keyed at 0
	# so the Stage 15 invariant (weapon arm driven by animation) holds.
	var a := Animation.new()
	a.length = 0.35
	a.loop_mode = Animation.LOOP_NONE
	var tra := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tra, NodePath("Body/ArmRShoulder:rotation"))
	a.track_insert_key(tra, 0.00, 0.0)
	a.track_insert_key(tra, 0.10, 0.4)
	a.track_insert_key(tra, 0.20, -0.9)
	a.track_insert_key(tra, 0.35, 0.0)
	var tsa := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tsa, NodePath("Body/ArmRShoulder/ElbowPivot/StaffArm:rotation"))
	a.track_insert_key(tsa, 0.00, 0.0)
	a.track_insert_key(tsa, 0.35, 0.0)
	return a

func _anim_cast() -> Animation:
	# Orb pulse + a brief raise of the staff arm. Shoulder lifts a
	# little (staff orb arcs up); the staff itself does not rotate.
	var a := Animation.new()
	a.length = 0.5
	a.loop_mode = Animation.LOOP_NONE
	var to := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(to, NodePath("Body/ArmRShoulder/ElbowPivot/StaffArm/Orb:modulate"))
	a.track_insert_key(to, 0.0, Color(1, 1, 1, 1))
	a.track_insert_key(to, 0.2, Color(2.0, 1.6, 0.7, 1))
	a.track_insert_key(to, 0.5, Color(1, 1, 1, 1))
	var tra := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tra, NodePath("Body/ArmRShoulder:rotation"))
	a.track_insert_key(tra, 0.00, 0.0)
	a.track_insert_key(tra, 0.20, -0.30)
	a.track_insert_key(tra, 0.50, 0.0)
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
