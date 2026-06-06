class_name HumanRig extends Object
## Stage 17.5 — shared HUMAN rig geometry.
## Standard ARPG-readable proportions (~5 heads tall, ~60px total).
## Matches the Bone Servant's visual scale so all sprites coexist
## at the same game zoom. Default-facing RIGHT (positive x).
## Player code flips `_sprite_anchor.scale.x` to face left.
##
## Articulation: shoulder + elbow pivots on the free arm, hip + knee
## pivots on each leg. The weapon arm (per-class) is a single
## shoulder pivot — its elbow bend is faked by polygon shape, like
## Bone Servant's ArmAnchor.
##
## Pivot at the feet (y=0); negative y is up.

# ---- Vertical landmarks --------------------------------------------------
const HEAD_TOP: float    = -60.0
const HEAD_MID: float    = -54.0   # eye-line
const CHIN: float        = -48.0
const NECK_BOTTOM: float = -45.0
const SHOULDERS: float   = -44.0
const STERNUM: float     = -37.0
const WAIST: float       = -28.0
const HIPS: float        = -22.0
const KNEES: float       = -12.0
const ANKLES: float      = -2.0
const FEET_Y: float      = 0.0

# ---- Half-widths ---------------------------------------------------------
const HEAD_HALF_W: float    = 5.5
const SHOULDER_HALF: float  = 10.5
const WAIST_HALF: float     = 7.5
const HIP_HALF: float       = 8.5
const THIGH_HALF: float     = 3.5
const SHIN_HALF: float      = 3.0
const UPPER_ARM_HALF: float = 2.8
const FOREARM_HALF: float   = 2.4
const HAND_R: float         = 2.6
const FOOT_HALF_FRONT: float = 4.0  # toes forward (default-facing right)
const FOOT_HALF_BACK: float  = 2.2  # heel

# ---- Pivot positions (in body-local space) ------------------------------
# Stride is narrow (legs converge slightly under the body) so the
# idle stance reads as feet together, not splayed.
const LEG_L_HIP: Vector2 = Vector2(-3.5, HIPS)
const LEG_R_HIP: Vector2 = Vector2(3.5, HIPS)
const KNEE_DROP: float   = 10.0  # hip pivot to knee pivot, in pivot-local
const ANKLE_DROP: float  = 10.0  # knee pivot to ankle

const ARM_L_SHOULDER: Vector2 = Vector2(-9.0, SHOULDERS)
const ARM_R_SHOULDER: Vector2 = Vector2(9.0, SHOULDERS)  # weapon arm anchor
const ELBOW_DROP: float       = 10.0
const WRIST_DROP: float       = 9.0

# ---- Palette -------------------------------------------------------------
const SKIN_BASE: Color    = Color(0.78, 0.62, 0.50)
const SKIN_SHADOW: Color  = Color(0.54, 0.40, 0.30)
const EYE_DEFAULT: Color  = Color(0.10, 0.08, 0.06)

# =========================================================================
# CORE POLYGONS (body-local — no pivot)
# =========================================================================

static func shadow_poly() -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var n := 18
	for i in n:
		var t := TAU * i / n
		pts.append(Vector2(11.0 * cos(t), 2.0 + 3.5 * sin(t)))
	return pts

static func head_poly() -> PackedVector2Array:
	# Oval skull, slight jaw taper.
	var pts: PackedVector2Array = []
	var n := 16
	var rx := HEAD_HALF_W
	var cy := (HEAD_TOP + CHIN) * 0.5
	var ry := (CHIN - HEAD_TOP) * 0.5
	for i in n:
		var t := TAU * i / n
		var taper := 1.0
		if sin(t) > 0.5:
			taper = 0.80
		pts.append(Vector2(rx * cos(t) * taper, cy + ry * sin(t)))
	return pts

static func neck_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-3, CHIN), Vector2(3, CHIN),
		Vector2(3.4, NECK_BOTTOM), Vector2(-3.4, NECK_BOTTOM),
	])

static func torso_poly() -> PackedVector2Array:
	# V-taper shoulders -> waist, with a slight chest curve.
	return PackedVector2Array([
		Vector2(-SHOULDER_HALF, SHOULDERS),
		Vector2(SHOULDER_HALF, SHOULDERS),
		Vector2(SHOULDER_HALF - 1, STERNUM),
		Vector2(WAIST_HALF, WAIST),
		Vector2(-WAIST_HALF, WAIST),
		Vector2(-SHOULDER_HALF + 1, STERNUM),
	])

static func hips_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-WAIST_HALF, WAIST),
		Vector2(WAIST_HALF, WAIST),
		Vector2(HIP_HALF, HIPS),
		Vector2(-HIP_HALF, HIPS),
	])

# =========================================================================
# LEG PIVOT GEOMETRY (each leg = hip pivot → knee pivot)
# Polygons are in pivot-local space (the pivot Node2D is at the joint).
# =========================================================================

# Thigh: rectangle from hip (0,0) down to knee drop, drawn vertical
# so leg-pivot rotation doesn't produce a lopsided silhouette.
static func leg_thigh_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-THIGH_HALF, 0),
		Vector2(THIGH_HALF, 0),
		Vector2(THIGH_HALF - 0.3, KNEE_DROP),
		Vector2(-THIGH_HALF + 0.3, KNEE_DROP),
	])

# Shin: in knee-local space, top at (0,0), bottom at (0, ANKLE_DROP).
static func leg_shin_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-SHIN_HALF, 0),
		Vector2(SHIN_HALF, 0),
		Vector2(SHIN_HALF - 0.4, ANKLE_DROP),
		Vector2(-SHIN_HALF + 0.4, ANKLE_DROP),
	])

# Foot: in knee-local space, toes pointing in default-facing direction
# (+x = right). Ankle at top, foot extends down + forward.
static func leg_foot_poly() -> PackedVector2Array:
	var ankle_y := ANKLE_DROP
	var sole_y := ANKLE_DROP + 2.0
	return PackedVector2Array([
		Vector2(-FOOT_HALF_BACK, ankle_y),
		Vector2(FOOT_HALF_FRONT, ankle_y),
		Vector2(FOOT_HALF_FRONT, sole_y),
		Vector2(-FOOT_HALF_BACK, sole_y),
	])

## Paint a hip-pivot leg subtree:
##   pivot (Node2D at hip joint)
##     - Thigh (Polygon2D)
##     - KneePivot (Node2D at knee joint)
##         - Shin (Polygon2D)
##         - Foot (Polygon2D)
## Part name convention: pivot/Thigh, pivot/KneePivot/Shin, pivot/KneePivot/Foot
static func paint_leg(hip_pivot: Node2D, color: Color) -> void:
	_paint_child(hip_pivot, &"Thigh", leg_thigh_poly(), color)
	var knee_pivot: Node2D = hip_pivot.get_node_or_null(^"KneePivot") as Node2D
	if knee_pivot == null:
		return
	_paint_child(knee_pivot, &"Shin", leg_shin_poly(), color)
	_paint_child(knee_pivot, &"Foot", leg_foot_poly(), color.darkened(0.1))

# =========================================================================
# ARM PIVOT GEOMETRY (shoulder pivot → elbow pivot)
# Free arm only. Weapon arms are per-class (single shoulder pivot).
# =========================================================================

static func arm_upper_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-UPPER_ARM_HALF, 0),
		Vector2(UPPER_ARM_HALF, 0),
		Vector2(UPPER_ARM_HALF - 0.3, ELBOW_DROP),
		Vector2(-UPPER_ARM_HALF + 0.3, ELBOW_DROP),
	])

static func arm_forearm_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-FOREARM_HALF, 0),
		Vector2(FOREARM_HALF, 0),
		Vector2(FOREARM_HALF - 0.3, WRIST_DROP),
		Vector2(-FOREARM_HALF + 0.3, WRIST_DROP),
	])

static func arm_hand_poly() -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var n := 10
	for i in n:
		var t := TAU * i / n
		pts.append(Vector2(HAND_R * cos(t), WRIST_DROP + 1.0 + HAND_R * 0.95 * sin(t)))
	return pts

## Paint an articulated arm subtree:
##   shoulder_pivot (Node2D at shoulder)
##     - UpperArm (Polygon2D)
##     - ElbowPivot (Node2D at elbow)
##         - Forearm (Polygon2D)
##         - Hand (Polygon2D)
## Upper arm is intentionally a touch darker than the torso color so
## the arm reads as a distinct silhouette at idle (otherwise skin-on-
## skin or skin-against-cuirass blends into a single trunk shape). A
## dynamic "ShoulderSeam" shadow node is created at the shoulder
## pivot for the same reason.
static func paint_arm(shoulder_pivot: Node2D, color: Color) -> void:
	_paint_child(shoulder_pivot, &"UpperArm", arm_upper_poly(), color.darkened(0.12))
	_ensure_child(shoulder_pivot, &"ShoulderSeam",
			_shoulder_seam_poly(), color.darkened(0.45))
	var elbow_pivot: Node2D = shoulder_pivot.get_node_or_null(^"ElbowPivot") as Node2D
	if elbow_pivot == null:
		return
	_paint_child(elbow_pivot, &"Forearm", arm_forearm_poly(), color.darkened(0.08))
	_paint_child(elbow_pivot, &"Hand", arm_hand_poly(), color.darkened(0.05))

# Shoulder-seam shadow: a small dark ellipse at the shoulder pivot's
# origin so the arm visibly meets the torso instead of blending into
# it. Drawn at the pivot, scaled by the upper-arm cross section.
static func _shoulder_seam_poly() -> PackedVector2Array:
	return _ellipse_at(Vector2(0, 0), UPPER_ARM_HALF + 0.6, 1.5)

# =========================================================================
# FACE FEATURES (sized for readability at game zoom)
# =========================================================================

static func eye_socket_l_poly() -> PackedVector2Array:
	return _ellipse_at(Vector2(-2.2, HEAD_MID), 1.6, 1.2)

static func eye_socket_r_poly() -> PackedVector2Array:
	return _ellipse_at(Vector2(2.2, HEAD_MID), 1.6, 1.2)

static func eye_pupil_l_poly() -> PackedVector2Array:
	return _ellipse_at(Vector2(-2.2, HEAD_MID), 0.8, 0.7)

static func eye_pupil_r_poly() -> PackedVector2Array:
	return _ellipse_at(Vector2(2.2, HEAD_MID), 0.8, 0.7)

static func brow_poly() -> PackedVector2Array:
	# Single horizontal bar above the eyes for a grim expression.
	return PackedVector2Array([
		Vector2(-4.0, HEAD_MID - 2.2),
		Vector2(4.0, HEAD_MID - 2.2),
		Vector2(4.0, HEAD_MID - 1.6),
		Vector2(-4.0, HEAD_MID - 1.6),
	])

static func mouth_poly() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-1.6, CHIN - 2.8),
		Vector2(1.6, CHIN - 2.8),
		Vector2(1.6, CHIN - 2.2),
		Vector2(-1.6, CHIN - 2.2),
	])

## Paint face sub-parts on a Face node under Body. Per-sprite scripts
## may pass different pupil colors (oracle whitened, undead glowing).
static func paint_face(body: Node2D, pupil_color: Color = EYE_DEFAULT,
		socket_color: Color = SKIN_SHADOW) -> void:
	var face := body.get_node_or_null(^"Face") as Node2D
	if face == null:
		return
	_paint_child(face, &"EyeSocketL", eye_socket_l_poly(), socket_color.darkened(0.4))
	_paint_child(face, &"EyeSocketR", eye_socket_r_poly(), socket_color.darkened(0.4))
	_paint_child(face, &"EyeL", eye_pupil_l_poly(), pupil_color)
	_paint_child(face, &"EyeR", eye_pupil_r_poly(), pupil_color)
	_paint_child(face, &"Brow", brow_poly(), socket_color.darkened(0.3))
	_paint_child(face, &"Mouth", mouth_poly(), socket_color.darkened(0.3))

# =========================================================================
# APPLY: paints the core body parts on `Body` Node2D + pivoted limbs.
# Caller is responsible for laying out the .tscn with the pivot
# Node2Ds at the canonical positions.
# =========================================================================

static func apply(body: Node2D, skin: Color = SKIN_BASE,
		skin_shadow: Color = SKIN_SHADOW) -> void:
	_paint_child(body, &"Head", head_poly(), skin)
	_paint_child(body, &"Neck", neck_poly(), skin_shadow)
	_paint_child(body, &"Torso", torso_poly(), skin)
	_paint_child(body, &"Hips", hips_poly(), skin_shadow)
	# Pivoted legs
	var lhip := body.get_node_or_null(^"LegLHip") as Node2D
	var rhip := body.get_node_or_null(^"LegRHip") as Node2D
	if lhip != null:
		paint_leg(lhip, skin_shadow)
	if rhip != null:
		paint_leg(rhip, skin_shadow)
	# Both flesh arms. Weapon (per-class SpearArm/StaffArm/etc.)
	# lives outside Body and is painted by the class sprite script.
	var l_arm := body.get_node_or_null(^"ArmLShoulder") as Node2D
	if l_arm != null:
		paint_arm(l_arm, skin)
	var r_arm := body.get_node_or_null(^"ArmRShoulder") as Node2D
	if r_arm != null:
		paint_arm(r_arm, skin)

# =========================================================================
# Internals
# =========================================================================

static func _ellipse_at(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var n := 10
	for i in n:
		var t := TAU * i / n
		pts.append(Vector2(c.x + rx * cos(t), c.y + ry * sin(t)))
	return pts

static func _paint_child(parent: Node2D, child_name: StringName,
		pts: PackedVector2Array, color: Color) -> void:
	var node: Polygon2D = parent.get_node_or_null(NodePath(String(child_name))) as Polygon2D
	if node == null:
		return
	node.polygon = pts
	node.color = color

# Like _paint_child but creates the Polygon2D dynamically if it isn't
# present in the scene tree. Used for parts (shoulder seam) that
# every HUMAN sprite gets without needing each .tscn to declare them.
static func _ensure_child(parent: Node2D, child_name: StringName,
		pts: PackedVector2Array, color: Color) -> void:
	var node: Polygon2D = parent.get_node_or_null(NodePath(String(child_name))) as Polygon2D
	if node == null:
		node = Polygon2D.new()
		node.name = String(child_name)
		parent.add_child(node)
	node.polygon = pts
	node.color = color
