extends "res://scripts/systems/sprite_runtime_2d.gd"
## DEMON species rig (Phase 3) — the lean fiend.
##
## Built on the shared HUMAN rig (HumanRig — articulated arms/elbows,
## legs/knees, real proportions) and re-skinned as an infernal fiend:
## crimson hide with charcoal extremities, back-swept horns, cloven
## hooves, vestigial folded wing nubs, a tapering tail, and ember-orange
## eye-glow in dark sockets. This is the shared DEMON baseline other
## demons derive from (anim_set = human_default; the six canonical anims
## come from SpriteRuntime2D). Demon part set per rules/sprite-animation.md
## §2 / AnatomyFamilies.PARTS[DEMON]: Horns, Hooves, WingAnchors, Tail,
## glowing eye sockets over a HUMAN base.

const HIDE: Color       = Color(0.55, 0.12, 0.12)   # crimson hide
const HIDE_DARK: Color  = Color(0.38, 0.08, 0.09)   # shaded crimson
const CHAR: Color       = Color(0.13, 0.10, 0.12)   # charcoal extremities
const CHAR_HI: Color    = Color(0.20, 0.15, 0.16)   # charcoal highlight
const SOCKET: Color     = Color(0.05, 0.03, 0.03)
const EMBER: Color      = Color(1.0, 0.50, 0.12)    # ember eye-glow
const SHADOW: Color     = Color(0.0, 0.0, 0.05, 0.45)

func _ready() -> void:
	sprite_id = &"fiend"
	stance_bucket = &"enemies"
	var body := get_node_or_null(^"Body") as Node2D
	if body != null:
		HumanRig.apply(body, HIDE, HIDE_DARK)
	var shadow := get_node_or_null(^"Shadow") as Polygon2D
	if shadow != null:
		shadow.polygon = HumanRig.shadow_poly()
		shadow.color = SHADOW
	# setup paints the standard legs + builds the six anims; demonize AFTER
	# so the lean crimson limbs / hooves aren't overwritten by paint_leg.
	setup_sprite_runtime()
	if body != null:
		_demonize(body)

# Layers the infernal read on top of the painted HUMAN rig.
func _demonize(body: Node2D) -> void:
	_lean_limbs(body)
	# Horns: a back-swept pair rising from the temples (charcoal, ember
	# root). Drawn over the head (z=4) but under the eye-glow (z=6).
	_overlay(body, "HornL", _horn(-1.0), CHAR, 4)
	_overlay(body, "HornR", _horn(1.0), CHAR, 4)
	# Vestigial folded wing nubs at the upper back — small, behind the
	# torso (z=-1) so they read as tucked, not spread.
	_overlay(body, "WingAnchorL", _wing(-1.0), HIDE_DARK, -1)
	_overlay(body, "WingAnchorR", _wing(1.0), HIDE_DARK, -1)
	# Tail: tapers from the hips down-and-back with a charcoal barb.
	_overlay(body, "Tail", _tail(), HIDE_DARK, -1)
	_overlay(body, "TailBarb", PackedVector2Array([
		Vector2(-14.5, -6.5), Vector2(-12.5, -8.0), Vector2(-11.0, -4.0),
	]), CHAR, -1)
	# Dark eye sockets with an ember glow over the crimson head.
	for cx in [-2.3, 2.3]:
		_overlay(body, "Socket%s" % ("L" if cx < 0 else "R"),
				_ellipse(Vector2(cx, -54.0), 1.9, 1.6), SOCKET, 5)
		_overlay(body, "EyeGlow%s" % ("L" if cx < 0 else "R"),
				_ellipse(Vector2(cx, -53.7), 1.0, 0.9), EMBER, 6)
	# A heavy charcoal brow ridge to harden the face read.
	_overlay(body, "Brow", PackedVector2Array([
		Vector2(-4.0, -56.4), Vector2(4.0, -56.4),
		Vector2(3.4, -55.4), Vector2(-3.4, -55.4),
	]), CHAR, 5)

# Repaint the HUMAN-rig limbs a touch leaner, with charcoal hands/hooves
# (the fiend's extremities char to black). Pivot-local coords match the
# HumanRig drop lengths so the anim tracks still bind 1:1.
func _lean_limbs(body: Node2D) -> void:
	for side in ["L", "R"]:
		_repaint(body, "Arm%sShoulder/UpperArm" % side, _seg(2.2, 1.7, HumanRig.ELBOW_DROP), HIDE)
		_repaint(body, "Arm%sShoulder/ElbowPivot/Forearm" % side, _seg(1.8, 1.4, HumanRig.WRIST_DROP), HIDE_DARK)
		# Clawed hand — charcoal, slightly pointed.
		_repaint(body, "Arm%sShoulder/ElbowPivot/Hand" % side, PackedVector2Array([
			Vector2(-1.8, HumanRig.WRIST_DROP - 0.5), Vector2(1.8, HumanRig.WRIST_DROP - 0.5),
			Vector2(1.2, HumanRig.WRIST_DROP + 3.2), Vector2(0.0, HumanRig.WRIST_DROP + 4.2),
			Vector2(-1.2, HumanRig.WRIST_DROP + 3.2),
		]), CHAR)
		_repaint(body, "Leg%sHip/Thigh" % side, _seg(2.8, 2.0, HumanRig.KNEE_DROP), HIDE)
		_repaint(body, "Leg%sHip/KneePivot/Shin" % side, _seg(2.0, 1.5, HumanRig.ANKLE_DROP), HIDE_DARK)
		# Cloven hoof — a blunt charcoal block with a central cleft notch.
		_repaint(body, "Leg%sHip/KneePivot/Foot" % side, PackedVector2Array([
			Vector2(-2.0, HumanRig.ANKLE_DROP), Vector2(2.6, HumanRig.ANKLE_DROP),
			Vector2(2.6, HumanRig.ANKLE_DROP + 3.0), Vector2(0.4, HumanRig.ANKLE_DROP + 3.0),
			Vector2(0.4, HumanRig.ANKLE_DROP + 1.4), Vector2(-0.2, HumanRig.ANKLE_DROP + 1.4),
			Vector2(-0.2, HumanRig.ANKLE_DROP + 3.0), Vector2(-2.0, HumanRig.ANKLE_DROP + 3.0),
		]), CHAR)

# A back-swept horn for `side` (-1 left, +1 right): rises from the temple,
# curves up and outward to a charcoal point. Body-local.
func _horn(side: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(side * 3.4, -56.5),    # inner root
		Vector2(side * 5.2, -57.5),    # outer root
		Vector2(side * 7.4, -61.0),    # mid sweep
		Vector2(side * 7.8, -65.5),    # tip
		Vector2(side * 6.2, -64.0),    # inner tip
		Vector2(side * 4.6, -59.5),    # inner curve
	])

# A small tucked wing nub on the upper back for `side`. Body-local.
func _wing(side: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(side * 8.5, -44.0),
		Vector2(side * 13.5, -46.5),
		Vector2(side * 12.0, -40.0),
		Vector2(side * 13.0, -35.5),
		Vector2(side * 9.0, -38.0),
	])

# Tapering tail from the hips curving down-and-back (toward -x). Body-local.
func _tail() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-5.5, -24.0), Vector2(-3.5, -23.0),
		Vector2(-8.5, -16.0), Vector2(-12.5, -9.0),
		Vector2(-14.5, -6.5), Vector2(-13.0, -9.5),
		Vector2(-10.0, -16.0), Vector2(-6.5, -22.0),
	])

# A tapered limb segment from (0,0) to (0,len): top half-width `htop`,
# bottom half-width `hbot`.
func _seg(htop: float, hbot: float, length: float) -> PackedVector2Array:
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
