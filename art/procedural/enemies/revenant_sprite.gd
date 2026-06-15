extends "res://scripts/systems/sprite_runtime_2d.gd"
## UNDEAD revenant sub-variant (Phase 1b). The shared HUMAN rig (full
## fleshed limbs, unlike the thin skeleton) re-skinned as a GAUNT RISEN
## CORPSE: sickly grey-green necrotic flesh, a dirty torn tunic, a rip
## on one side of the chest where rib slivers peek through, a tattered
## hip rag, sunken sickly eye-glow, and one rotted (darker) arm for
## asymmetry. Six canonical anims via SpriteRuntime2D.

const FLESH: Color      = Color(0.55, 0.60, 0.47)   # sickly grey-green
const FLESH_DARK: Color = Color(0.39, 0.44, 0.33)
const ROT: Color        = Color(0.33, 0.40, 0.28)   # rotted limb / blotch
const BONE: Color       = Color(0.82, 0.80, 0.68)   # exposed ribs
const RIP_DARK: Color   = Color(0.10, 0.12, 0.09)   # cavity behind the tear
const RAG: Color        = Color(0.31, 0.30, 0.24)   # dirty tunic
const RAG_DARK: Color   = Color(0.20, 0.19, 0.15)   # hip rag
const SOCKET: Color     = Color(0.06, 0.07, 0.05)
const EYE_GLOW: Color   = Color(0.78, 0.88, 0.42)   # sickly yellow-green
const SHADOW: Color     = Color(0.0, 0.0, 0.05, 0.45)

func _ready() -> void:
	sprite_id = &"revenant"
	stance_bucket = &"enemies"
	var body := get_node_or_null(^"Body") as Node2D
	if body != null:
		HumanRig.apply(body, FLESH, FLESH_DARK)
	var shadow := get_node_or_null(^"Shadow") as Polygon2D
	if shadow != null:
		shadow.polygon = HumanRig.shadow_poly()
		shadow.color = SHADOW
	setup_sprite_runtime()
	if body != null:
		_decay(body)

func _decay(body: Node2D) -> void:
	# One rotted arm (asymmetry): the right arm reads darker/necrotic.
	_recolor(body, "ArmRShoulder/UpperArm", ROT)
	_recolor(body, "ArmRShoulder/ElbowPivot/Forearm", ROT)
	_recolor(body, "ArmRShoulder/ElbowPivot/Hand", ROT.darkened(0.05))
	# Dirty torn tunic over the torso, ragged lower hem.
	_overlay(body, "Tunic", PackedVector2Array([
		Vector2(-9, -43), Vector2(9, -43), Vector2(9, -30), Vector2(7, -26),
		Vector2(3, -29), Vector2(0, -25), Vector2(-3, -29), Vector2(-7, -26),
		Vector2(-9, -30),
	]), RAG, 2)
	# Rip on the left chest — dark cavity with rib slivers peeking through.
	_overlay(body, "Rip", PackedVector2Array([
		Vector2(-7, -42), Vector2(-1, -41), Vector2(-2, -34), Vector2(-7, -35),
	]), RIP_DARK, 3)
	for y in [-41.0, -38.5, -36.0]:
		_overlay(body, "Rib%d" % int(-y), PackedVector2Array([
			Vector2(-6.5, y), Vector2(-1.6, y - 0.3),
			Vector2(-1.6, y + 1.0), Vector2(-6.5, y + 1.3),
		]), BONE, 4)
	# Tattered hip rag.
	_overlay(body, "HipRag", PackedVector2Array([
		Vector2(-8, -27), Vector2(8, -27), Vector2(7, -17), Vector2(3, -13),
		Vector2(0, -16), Vector2(-3, -12), Vector2(-7, -16),
	]), RAG_DARK, 2)
	# Sunken sickly eyes in dark sockets.
	for cx in [-2.3, 2.3]:
		_overlay(body, "Socket%s" % ("L" if cx < 0 else "R"),
				_ellipse(Vector2(cx, -54.0), 1.8, 1.5), SOCKET, 5)
		_overlay(body, "EyeGlow%s" % ("L" if cx < 0 else "R"),
				_ellipse(Vector2(cx, -53.8), 0.9, 0.8), EYE_GLOW, 6)

func _recolor(parent: Node2D, path: String, color: Color) -> void:
	var p := parent.get_node_or_null(NodePath(path)) as Polygon2D
	if p != null:
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
