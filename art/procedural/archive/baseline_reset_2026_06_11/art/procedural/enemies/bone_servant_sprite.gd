extends "res://scripts/systems/sprite_runtime_2d.gd"
## Procedural bone-servant minion sprite. AD-11 canonical anim names.
##
## Modular subtree contract (rules/asset-pipeline.md::modular sprites):
## every distinct visual part is its own node under Body / ArmAnchor.
## A future polish pass can swap any single node (Skull → carved
## bitmap, ArmLower → curved bone bitmap, HipCloth → cloth shader,
## etc.) without redrawing the rest. Animation tracks reference
## node paths, not subtree paths, so a swapped node keeps the same
## name and gets the same anim driver for free.
##
## Default-facing: RIGHT. The minion script flips _sprite_anchor.scale.x
## when moving left so the attack arm always reads as striking
## forward.
##
## Stage 5 exercises idle / walk / attack / hit / die. The fan-out of
## subnodes here (HipCloth, Sternum, Jaw, separate eye sockets vs eye
## glows, ArmLower vs Claw) gives the polish pass a per-part target
## list without rewriting silhouettes.

const BONE: Color        = Color(0.93, 0.91, 0.82)
const BONE_DARK: Color   = Color(0.55, 0.52, 0.40)
const BONE_DEEP: Color   = Color(0.38, 0.34, 0.26)
const SOCKET: Color      = Color(0.06, 0.05, 0.08)
const SICKLY_GREEN: Color = Color(0.40, 0.95, 0.55, 1.0)
const CLOTH_DARK: Color  = Color(0.18, 0.15, 0.20, 1.0)
const SHADOW: Color      = Color(0.0, 0.0, 0.05, 0.45)

@onready var _shadow: Polygon2D = $Shadow
@onready var _hip_cloth: Polygon2D = $Body/HipCloth
@onready var _leg_l: Polygon2D = $Body/LegL
@onready var _leg_r: Polygon2D = $Body/LegR
@onready var _pelvis: Polygon2D = $Body/Pelvis
@onready var _spine: Polygon2D = $Body/Spine
@onready var _rib1: Polygon2D = $Body/Rib1
@onready var _rib2: Polygon2D = $Body/Rib2
@onready var _rib3: Polygon2D = $Body/Rib3
@onready var _sternum: Polygon2D = $Body/Sternum
@onready var _arm_rest: Polygon2D = $Body/ArmRest
@onready var _skull: Polygon2D = $Body/Skull
@onready var _jaw: Polygon2D = $Body/Jaw
@onready var _eye_socket_l: Polygon2D = $Body/EyeSocketL
@onready var _eye_socket_r: Polygon2D = $Body/EyeSocketR
@onready var _eye_glow_l: Polygon2D = $Body/EyeGlowL
@onready var _eye_glow_r: Polygon2D = $Body/EyeGlowR
@onready var _arm_upper: Polygon2D = $ArmAnchor/ArmUpper
@onready var _arm_lower: Polygon2D = $ArmAnchor/ArmLower
@onready var _claw: Polygon2D = $ArmAnchor/Claw

func _ready() -> void:
	sprite_id = &"bone_servant"
	stance_bucket = &"enemies"
	_paint()
	setup_sprite_runtime()

func _paint() -> void:
	# Shadow ellipse at feet.
	var sh: PackedVector2Array = []
	var n := 16
	for i in n:
		var t := TAU * i / n
		sh.append(Vector2(13.0 * cos(t), 3.0 + 4.0 * sin(t)))
	_shadow.polygon = sh
	_shadow.color = SHADOW

	# Tattered loincloth behind the bones, dark so it reads as
	# negative space first.
	_hip_cloth.color = CLOTH_DARK
	_hip_cloth.polygon = PackedVector2Array([
		Vector2(-9, -16), Vector2(9, -16),
		Vector2(11, 0), Vector2(6, -2),
		Vector2(2, 2), Vector2(-2, -1),
		Vector2(-6, 2), Vector2(-11, 0),
	])

	# Two distinct bone legs.
	_leg_l.color = BONE
	_leg_l.polygon = _bone_leg(-4)
	_leg_r.color = BONE
	_leg_r.polygon = _bone_leg(4)

	# Wider pelvis bone joining the legs.
	_pelvis.color = BONE_DARK
	_pelvis.polygon = PackedVector2Array([
		Vector2(-8, -18), Vector2(8, -18),
		Vector2(7, -14), Vector2(-7, -14),
	])

	# Vertical spine connecting pelvis to skull.
	_spine.color = BONE_DARK
	_spine.polygon = PackedVector2Array([
		Vector2(-1.5, -36), Vector2(1.5, -36),
		Vector2(1.5, -18), Vector2(-1.5, -18),
	])

	# Three rib pairs — each is a single horizontal sweep with a
	# gap in the middle implied by the dark spine in front.
	_rib1.color = BONE
	_rib1.polygon = _rib_strip(-34, 9)
	_rib2.color = BONE
	_rib2.polygon = _rib_strip(-30, 8)
	_rib3.color = BONE
	_rib3.polygon = _rib_strip(-26, 7)

	# Sternum sits in front of the ribs and the spine.
	_sternum.color = BONE
	_sternum.polygon = PackedVector2Array([
		Vector2(-1, -35), Vector2(1, -35),
		Vector2(1, -25), Vector2(-1, -25),
	])

	# Resting arm hanging at the left side (decorative — the
	# attacking arm is the one on ArmAnchor at the right).
	_arm_rest.color = BONE
	_arm_rest.polygon = PackedVector2Array([
		Vector2(-9, -32), Vector2(-7, -32),
		Vector2(-7, -16), Vector2(-9, -16),
	])

	# Skull — slightly elongated oval suggesting a brow.
	var sk: PackedVector2Array = []
	var ns := 16
	for i in ns:
		var t := TAU * i / ns
		sk.append(Vector2(6.5 * cos(t), -44.0 + 5.5 * sin(t)))
	_skull.color = BONE
	_skull.polygon = sk

	# Lower jaw — a curved underbite.
	_jaw.color = BONE_DARK
	_jaw.polygon = PackedVector2Array([
		Vector2(-4, -39), Vector2(4, -39),
		Vector2(3, -36), Vector2(-3, -36),
	])

	# Eye sockets — deep voids cut into the skull.
	_eye_socket_l.color = SOCKET
	_eye_socket_l.polygon = _eye_socket(-2.5)
	_eye_socket_r.color = SOCKET
	_eye_socket_r.polygon = _eye_socket(2.5)

	# Eye glows inside the sockets — small, bright, additive feel.
	_eye_glow_l.color = SICKLY_GREEN
	_eye_glow_l.polygon = _eye_glow(-2.5)
	_eye_glow_r.color = SICKLY_GREEN
	_eye_glow_r.polygon = _eye_glow(2.5)

	# Attacking arm at the front (right side at default facing).
	# ArmAnchor is at (6, -28); polygons are local to it.
	_arm_upper.color = BONE
	_arm_upper.polygon = PackedVector2Array([
		Vector2(-1, 0), Vector2(2, 0),
		Vector2(2, 9), Vector2(-1, 9),
	])
	_arm_lower.color = BONE
	_arm_lower.polygon = PackedVector2Array([
		Vector2(0, 9), Vector2(3, 9),
		Vector2(4, 19), Vector2(1, 19),
	])
	_claw.color = BONE_DEEP
	_claw.polygon = PackedVector2Array([
		Vector2(0, 18), Vector2(6, 19),
		Vector2(8, 22), Vector2(5, 23),
		Vector2(2, 21),
	])

func _bone_leg(cx: float) -> PackedVector2Array:
	# Tapered femur shape with a slight bulge at the knee.
	return PackedVector2Array([
		Vector2(cx - 2, 0), Vector2(cx + 2, 0),
		Vector2(cx + 2.5, -8), Vector2(cx + 1.5, -12),
		Vector2(cx + 2, -18), Vector2(cx - 2, -18),
		Vector2(cx - 1.5, -12), Vector2(cx - 2.5, -8),
	])

func _rib_strip(y: float, half_w: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half_w, y - 1.0), Vector2(half_w, y - 1.0),
		Vector2(half_w, y + 1.0), Vector2(-half_w, y + 1.0),
	])

func _eye_socket(cx: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var n := 10
	for i in n:
		var t := TAU * i / n
		pts.append(Vector2(cx + 1.8 * cos(t), -44.5 + 1.4 * sin(t)))
	return pts

func _eye_glow(cx: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var n := 8
	for i in n:
		var t := TAU * i / n
		pts.append(Vector2(cx + 0.9 * cos(t), -44.5 + 0.8 * sin(t)))
	return pts

# Animations are installed by SpriteRuntime2D so summoned minions share
# the same stance and pose-tuner override path as enemies/NPCs.
