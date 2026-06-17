extends "res://scripts/systems/sprite_runtime_2d.gd"
## UNDEAD wraith sub-variant, rebuilt on the shared HUMAN rig (Stage 17.8d).
##
## Same anatomy + proportions as the player cast — so a wraith is the same
## SIZE as a character (not the old oversized bespoke rig) and its arms
## HANG DOWN and articulate like a human's, ending in claws (humanoid from
## the waist up, as intended). A cloak + hood drape the torso down to a
## tattered hem; there are NO legs — the wraith DRIFTS, hovering above the
## ground. Both Shade Wretch + Bog Caller share this script; palette +
## the Bog Caller's wand differ by sprite_id.

const SHADOW: Color = Color(0.0, 0.0, 0.05, 0.45)

func _ready() -> void:
	if stance_bucket == &"":
		stance_bucket = &"enemies"
	var body := get_node_or_null(^"Body") as Node2D
	var pal := _palette()
	if body != null:
		HumanRig.apply(body, pal["flesh"], pal["flesh_shadow"])
	var shadow := get_node_or_null(^"Shadow") as Polygon2D
	if shadow != null:
		shadow.polygon = HumanRig.shadow_poly()
		shadow.color = SHADOW
	# Builds the drift anims (no footed gait), seats the hover rest, and
	# mounts the wand for the Bog Caller (shared WeaponRig).
	setup_sprite_runtime()
	if body != null:
		_wraithify(body, pal)

func _palette() -> Dictionary:
	if sprite_id == &"bog_caller":
		return {
			"flesh": Color(0.17, 0.23, 0.17), "flesh_shadow": Color(0.10, 0.15, 0.11),
			"cloak": Color(0.13, 0.21, 0.15), "cloak_dark": Color(0.07, 0.12, 0.09),
			"hood": Color(0.06, 0.10, 0.07), "eye": Color(0.60, 1.0, 0.55),
		}
	return {
		"flesh": Color(0.15, 0.12, 0.18), "flesh_shadow": Color(0.09, 0.08, 0.12),
		"cloak": Color(0.11, 0.09, 0.15), "cloak_dark": Color(0.05, 0.04, 0.08),
		"hood": Color(0.05, 0.04, 0.07), "eye": Color(0.95, 0.55, 0.35),
	}

# Drape the spectral read over the painted HUMAN rig.
func _wraithify(body: Node2D, pal: Dictionary) -> void:
	# Arms ride IN FRONT of the cloak (claws hang down at the sides) — the
	# free arms read instead of being buried by the drape.
	for side in ["L", "R"]:
		for p in ["Arm%sShoulder/UpperArm", "Arm%sShoulder/ShoulderSeam",
				"Arm%sShoulder/ElbowPivot/Forearm", "Arm%sShoulder/ElbowPivot/Hand"]:
			var n := body.get_node_or_null(NodePath(p % side)) as CanvasItem
			if n != null:
				n.z_index = 4
		# Clawed hand pointing down (replaces the rounded human hand).
		_repaint(body, "Arm%sShoulder/ElbowPivot/Hand" % side, PackedVector2Array([
			Vector2(-1.6, 9), Vector2(1.6, 9), Vector2(1.4, 13), Vector2(0.6, 16),
			Vector2(0, 13), Vector2(-0.6, 16), Vector2(-1.4, 13)]), pal["flesh_shadow"])
	# Cloak drape over the torso + where the legs would be, down to a hem.
	_overlay(body, "Cloak", PackedVector2Array([
		Vector2(-10, -44), Vector2(10, -44), Vector2(11, -24), Vector2(12, -4),
		Vector2(7, -1), Vector2(0, -3), Vector2(-7, -1), Vector2(-12, -4), Vector2(-11, -24)]),
		pal["cloak"], 2)
	# Tattered hem (drifts/ripples — also what marks this as a wraith).
	_overlay(body, "TatteredHem", PackedVector2Array([
		Vector2(-12, -4), Vector2(-8, -2), Vector2(-5, -5), Vector2(-2, -1),
		Vector2(1, -5), Vector2(4, -1), Vector2(8, -4), Vector2(12, -4),
		Vector2(11, 1), Vector2(-11, 1)]), pal["cloak_dark"], 2)
	# Hood over the head; dark face void; glowing eyes.
	_overlay(body, "Hood", PackedVector2Array([
		Vector2(-7, -61), Vector2(0, -63), Vector2(7, -61), Vector2(8, -50),
		Vector2(5, -47), Vector2(-5, -47), Vector2(-8, -50)]), pal["hood"], 3)
	_overlay(body, "FaceVoid", PackedVector2Array([
		Vector2(-5, -56), Vector2(5, -56), Vector2(4, -47), Vector2(-4, -47)]),
		Color(0.02, 0.015, 0.03, 0.97), 3)
	for cx in [-2.3, 2.3]:
		_overlay(body, "Eye%s" % ("L" if cx < 0 else "R"),
				_ellipse(Vector2(cx, -53.5), 1.1, 1.3), pal["eye"], 6)

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
	for i in 12:
		var t := TAU * i / 12
		pts.append(Vector2(c.x + rx * cos(t), c.y + ry * sin(t)))
	return pts
