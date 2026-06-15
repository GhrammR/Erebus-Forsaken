extends "res://scripts/systems/sprite_runtime_2d.gd"
## UNDEAD skeleton sub-variant (Phase 1a). Built on the shared HUMAN
## rig (HumanRig — same articulated anatomy as the Myrmidon/baseline:
## arms with elbows, legs with knees, real proportions) and re-skinned
## as BONE: thin bone-white limb segments, a darkened chest cavity with
## a bone-white ribcage + sternum, a short hip loincloth, and
## sickly-green eye-glow in dark sockets. Six canonical anims come from
## SpriteRuntime2D so summoned minions share player-grade motion.

const BONE: Color       = Color(0.91, 0.89, 0.79)
const BONE_DARK: Color  = Color(0.72, 0.68, 0.55)
const CAVITY: Color     = Color(0.30, 0.27, 0.20)   # chest behind the ribs
const SOCKET: Color     = Color(0.05, 0.05, 0.07)
const EYE_GLOW: Color   = Color(0.45, 0.95, 0.55)
const CLOTH: Color      = Color(0.17, 0.14, 0.19)
const SHADOW: Color     = Color(0.0, 0.0, 0.05, 0.45)

func _ready() -> void:
	sprite_id = &"bone_servant"
	stance_bucket = &"enemies"
	var body := get_node_or_null(^"Body") as Node2D
	if body != null:
		HumanRig.apply(body, BONE, BONE_DARK)
	var shadow := get_node_or_null(^"Shadow") as Polygon2D
	if shadow != null:
		shadow.polygon = HumanRig.shadow_poly()
		shadow.color = SHADOW
	# setup paints the standard-width legs + builds anims; re-skin AFTER
	# so the thin bone limbs aren't overwritten by paint_leg.
	setup_sprite_runtime()
	if body != null:
		_skeletonize(body)

# Layers the skeletal read on top of the painted HUMAN rig.
func _skeletonize(body: Node2D) -> void:
	_thin_limbs(body)
	# Hollow the chest so the ribcage stands out against a dark cavity.
	var torso := body.get_node_or_null(^"Torso") as Polygon2D
	if torso != null:
		torso.color = CAVITY
	# Ribcage: bone-white bars narrowing toward the waist + a sternum.
	var ribs := [
		{ "y": -42.0, "hw": 8.6 },
		{ "y": -38.0, "hw": 8.0 },
		{ "y": -34.0, "hw": 6.9 },
		{ "y": -30.5, "hw": 5.4 },
	]
	for i in ribs.size():
		var r: Dictionary = ribs[i]
		var y: float = r["y"]
		var hw: float = r["hw"]
		_overlay(body, "Rib%d" % (i + 1), PackedVector2Array([
			Vector2(-hw, y), Vector2(hw, y),
			Vector2(hw - 0.9, y + 1.9), Vector2(-hw + 0.9, y + 1.9),
		]), BONE, 1)
	_overlay(body, "Sternum", PackedVector2Array([
		Vector2(-1.3, -43.0), Vector2(1.3, -43.0),
		Vector2(1.3, -30.0), Vector2(-1.3, -30.0),
	]), BONE, 2)
	# Short hip loincloth — a wrap, not a skirt, so the bone thighs show.
	_overlay(body, "Loincloth", PackedVector2Array([
		Vector2(-7, -26), Vector2(7, -26), Vector2(6, -20),
		Vector2(2, -18), Vector2(0, -20), Vector2(-2, -18), Vector2(-6, -20),
	]), CLOTH, 3)
	# Skull read: dark eye sockets with a green glow over the bone head.
	for cx in [-2.3, 2.3]:
		_overlay(body, "Socket%s" % ("L" if cx < 0 else "R"),
				_ellipse(Vector2(cx, -54.0), 1.9, 1.6), SOCKET, 5)
		_overlay(body, "EyeGlow%s" % ("L" if cx < 0 else "R"),
				_ellipse(Vector2(cx, -53.6), 1.05, 0.95), EYE_GLOW, 6)

# Repaint the HUMAN-rig limb polygons as thin bone segments with small
# joint knobs. Pivot-local coords match HumanRig drop lengths.
func _thin_limbs(body: Node2D) -> void:
	for side in ["L", "R"]:
		# Arms — thinner than the fleshed HUMAN arm.
		_repaint(body, "Arm%sShoulder/UpperArm" % side, _bone_seg(1.4, 1.1, HumanRig.ELBOW_DROP), BONE)
		_repaint(body, "Arm%sShoulder/ShoulderSeam" % side, _ellipse(Vector2.ZERO, 1.8, 1.5), BONE_DARK)
		_repaint(body, "Arm%sShoulder/ElbowPivot/Forearm" % side, _bone_seg(1.1, 0.9, HumanRig.WRIST_DROP), BONE)
		_repaint(body, "Arm%sShoulder/ElbowPivot/Hand" % side, _ellipse(Vector2(0, HumanRig.WRIST_DROP + 1.0), 1.5, 1.5), BONE)
		# Legs — thin femur/tibia.
		_repaint(body, "Leg%sHip/Thigh" % side, _bone_seg(1.9, 1.5, HumanRig.KNEE_DROP), BONE)
		_repaint(body, "Leg%sHip/KneePivot/Shin" % side, _bone_seg(1.5, 1.2, HumanRig.ANKLE_DROP), BONE)
		_repaint(body, "Leg%sHip/KneePivot/Foot" % side, PackedVector2Array([
			Vector2(-1.2, HumanRig.ANKLE_DROP), Vector2(2.3, HumanRig.ANKLE_DROP),
			Vector2(2.3, HumanRig.ANKLE_DROP + 1.8), Vector2(-1.2, HumanRig.ANKLE_DROP + 1.8),
		]), BONE_DARK)

# A tapered bone segment from (0,0) down to (0,len), top half-width
# `htop`, bottom half-width `hbot`.
func _bone_seg(htop: float, hbot: float, length: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-htop, 0), Vector2(htop, 0),
		Vector2(hbot, length), Vector2(-hbot, length),
	])

func _repaint(parent: Node2D, path: String, pts: PackedVector2Array, color: Color) -> void:
	var p := parent.get_node_or_null(NodePath(path)) as Polygon2D
	if p == null:
		return
	p.polygon = pts
	p.color = color

func _overlay(parent: Node2D, node_name: String, pts: PackedVector2Array,
		color: Color, z: int) -> void:
	var p := parent.get_node_or_null(NodePath(node_name)) as Polygon2D
	if p == null:
		p = Polygon2D.new()
		p.name = node_name
		parent.add_child(p)
	p.polygon = pts
	p.color = color
	p.z_index = z

func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var n := 12
	for i in n:
		var t := TAU * i / n
		pts.append(Vector2(c.x + rx * cos(t), c.y + ry * sin(t)))
	return pts
