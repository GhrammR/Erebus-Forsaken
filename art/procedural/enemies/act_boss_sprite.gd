extends "res://scripts/systems/sprite_runtime_2d.gd"
## BESPOKE BOSS (Phase 6) — Hexacheir, the God-Spurned.
##
## A unique Act-1 boss, so it gets its OWN anatomy (not a species rig +
## skin): a towering six-armed demon idol — broad crimson torso, two
## cloven-hooved legs, a horned head with ember eyes, and THREE symmetric
## pairs of clawed "oath-hands" fanned down the body (upper raised, mid
## reaching, lower low), each palm bearing a glowing broken-oath sigil.
## Oversized (~1.4x the cast). Built on the shared joint-pivot/rotation-
## track system but with a bespoke part set (allowed for unique bosses,
## rules/sprite-animation.md §6). Registered &"act_boss" bespoke DEMON in
## AnatomyFamilies.
##
## The six arms are built procedurally (deterministic node names) so the
## six-arm tree exists before the anims bind. All six canonical anims are
## OVERRIDES (the shared biped builder only drives two arms); `_anim_hit`
## is inherited (a rig-agnostic body-modulate flash).

const HIDE: Color      = Color(0.50, 0.10, 0.10)   # deep crimson hide
const HIDE_DARK: Color = Color(0.34, 0.07, 0.08)   # shaded crimson
const CHAR: Color      = Color(0.12, 0.10, 0.12)   # charcoal horns/hooves/claws
const CHAR_HI: Color   = Color(0.19, 0.15, 0.16)
const SOCKET: Color    = Color(0.05, 0.03, 0.03)
const EMBER: Color     = Color(1.0, 0.50, 0.12)    # ember eyes
const SIGIL: Color     = Color(1.0, 0.62, 0.20)    # broken-oath palm sigil
const SHADOW: Color    = Color(0.0, 0.0, 0.05, 0.5)

const UPPER_LEN: float = 11.0
const LOWER_LEN: float = 10.0

# The six oath-arms. shoulder = pivot pos (Body-local); ud/ld = unit-ish
# upper/lower limb directions for the RIGHT side (left mirrors x). The rest
# pose (the fan) is baked into the geometry; anims rotate the pivots.
const ARMS: Array = [
	{ "name": "ArmUpperR", "shoulder": Vector2(13, -64),  "ud": Vector2(0.82, -0.57), "ld": Vector2(0.55, -0.84) },
	{ "name": "ArmUpperL", "shoulder": Vector2(-13, -64), "ud": Vector2(-0.82, -0.57), "ld": Vector2(-0.55, -0.84) },
	{ "name": "ArmMidR",   "shoulder": Vector2(13, -57),  "ud": Vector2(0.97, -0.10), "ld": Vector2(0.98, 0.18) },
	{ "name": "ArmMidL",   "shoulder": Vector2(-13, -57), "ud": Vector2(-0.97, -0.10), "ld": Vector2(-0.98, 0.18) },
	{ "name": "ArmLowerR", "shoulder": Vector2(12, -50),  "ud": Vector2(0.66, 0.46), "ld": Vector2(0.42, 0.79) },
	{ "name": "ArmLowerL", "shoulder": Vector2(-12, -50), "ud": Vector2(-0.66, 0.46), "ld": Vector2(-0.42, 0.79) },
]

func _ready() -> void:
	sprite_id = &"act_boss"
	stance_bucket = &"enemies"
	_build_rig()
	# Builds the six anims (our overrides) + selects stance + plays idle.
	setup_sprite_runtime()

# Bespoke boss supplies its own oversized hooved legs — never the injected
# standard biped legs.
func _uses_standard_leg_anatomy() -> bool:
	return false

# ---- rig build -----------------------------------------------------------

func _build_rig() -> void:
	var shadow := get_node_or_null(^"Shadow") as Polygon2D
	if shadow != null:
		shadow.polygon = _ellipse(Vector2(0, 1), 18.0, 4.5)
		shadow.color = SHADOW
	var body := get_node(^"Body") as Node2D
	# Far-side (L) arms behind the torso; built first.
	for arm in ARMS:
		if String(arm["name"]).ends_with("L"):
			_build_arm(body, arm, HIDE_DARK, -2)
	# Hooved legs (far L behind, near R in front via the tscn z on the hips).
	_paint_leg(^"Body/LegLHip", HIDE_DARK)
	_paint_leg(^"Body/LegRHip", HIDE)
	# Core body.
	_paint(^"Body/Hips", PackedVector2Array([
		Vector2(-8, -44), Vector2(8, -44), Vector2(10, -38), Vector2(-10, -38),
	]), HIDE_DARK)
	_paint(^"Body/Torso", PackedVector2Array([
		Vector2(-15, -66), Vector2(15, -66), Vector2(14, -58), Vector2(13, -50),
		Vector2(8, -44), Vector2(-8, -44), Vector2(-13, -50), Vector2(-14, -58),
	]), HIDE)
	# A charred sternum scar where a severed oath-sigil once burned.
	_overlay(body, "Sternum", PackedVector2Array([
		Vector2(-1.2, -64), Vector2(1.2, -64), Vector2(2.0, -50), Vector2(0, -47), Vector2(-2.0, -50),
	]), HIDE_DARK, 1)
	_paint(^"Body/Neck", PackedVector2Array([
		Vector2(-5, -66), Vector2(5, -66), Vector2(4.5, -72), Vector2(-4.5, -72),
	]), HIDE_DARK)
	_paint(^"Body/Head", _ellipse(Vector2(0, -79), 6.0, 6.8), HIDE)
	# Heavy charcoal brow.
	_overlay(body, "Brow", PackedVector2Array([
		Vector2(-5, -82), Vector2(5, -82), Vector2(4.4, -80.6), Vector2(-4.4, -80.6),
	]), CHAR, 4)
	# Back-swept horns.
	_overlay(body, "HornL", _horn(-1.0), CHAR, 4)
	_overlay(body, "HornR", _horn(1.0), CHAR, 4)
	# Ember eyes in dark sockets.
	for cx in [-2.6, 2.6]:
		var sfx := "L" if cx < 0 else "R"
		_overlay(body, "Socket%s" % sfx, _ellipse(Vector2(cx, -79.5), 2.0, 1.7), SOCKET, 5)
		_overlay(body, "Eye%s" % sfx, _ellipse(Vector2(cx, -79.2), 1.1, 1.0), EMBER, 6)
	# Near-side (R) arms in front of the torso; built last.
	for arm in ARMS:
		if String(arm["name"]).ends_with("R"):
			_build_arm(body, arm, HIDE, 2)

# Build one oath-arm subtree: ShoulderPivot → UpperArm + ElbowPivot
# (→ Forearm + Claw + Sigil). The fan pose is baked into the geometry
# (elbow placed along `ud`, forearm along `ld`), so anims animate rotation.
func _build_arm(body: Node2D, arm: Dictionary, color: Color, z: int) -> void:
	var nm: String = arm["name"]
	var ud: Vector2 = arm["ud"]
	var ld: Vector2 = arm["ld"]
	var shoulder := body.get_node_or_null(NodePath(nm)) as Node2D
	if shoulder == null:
		shoulder = Node2D.new()
		shoulder.name = nm
		body.add_child(shoulder)
	shoulder.position = arm["shoulder"]
	shoulder.z_index = z
	var elbow_local: Vector2 = ud * UPPER_LEN
	_child_poly(shoulder, "UpperArm", _limb(Vector2.ZERO, elbow_local, 3.0, 2.4), color)
	var elbow := shoulder.get_node_or_null(^"ElbowPivot") as Node2D
	if elbow == null:
		elbow = Node2D.new()
		elbow.name = "ElbowPivot"
		shoulder.add_child(elbow)
	elbow.position = elbow_local
	var wrist_local: Vector2 = ld * LOWER_LEN
	_child_poly(elbow, "Forearm", _limb(Vector2.ZERO, wrist_local, 2.4, 1.8), color.darkened(0.06))
	_child_poly(elbow, "Claw", _claw(wrist_local, ld), CHAR)
	_child_poly(elbow, "Sigil", _ellipse(wrist_local + ld * 2.0, 1.3, 1.3), SIGIL)

func _paint_leg(pivot_path: NodePath, color: Color) -> void:
	var base := pivot_path.get_concatenated_names()
	_paint(base + "/Thigh", _limb(Vector2.ZERO, Vector2(0, 14), 4.0, 3.0), color)
	_paint(base + "/KneePivot/Shin", _limb(Vector2.ZERO, Vector2(0, 14), 3.0, 2.2), color.darkened(0.06))
	# Cloven hoof — a blunt charcoal block with a cleft notch.
	_paint(base + "/KneePivot/Hoof", PackedVector2Array([
		Vector2(-3, 14), Vector2(4, 14), Vector2(4, 17.5), Vector2(0.6, 17.5),
		Vector2(0.6, 15.5), Vector2(-0.2, 15.5), Vector2(-0.2, 17.5), Vector2(-3, 17.5),
	]), CHAR)

# ---- canonical anim overrides (six-arm boss) -----------------------------

func _anim_idle() -> Animation:
	var a := Animation.new()
	a.length = 2.0
	a.loop_mode = Animation.LOOP_LINEAR
	var L := a.length
	_key_vec2(a, ^"Body:position", [0.0, L * 0.5, L], [Vector2.ZERO, Vector2(0, -1.2), Vector2.ZERO])
	# Arms breathe in two alternating banks (even rows dip as odd rows lift)
	# so the idol reads as living, not a static statue.
	for arm in ARMS:
		var nm: String = arm["name"]
		var s := _side(nm)
		var bank := 1.0 if (_row(nm) % 2 == 0) else -1.0
		_key_float(a, NodePath("Body/%s:rotation" % nm),
				[0.0, L * 0.5, L], [0.0, -0.05 * s * bank, 0.0])
	_pulse_glow(a, L, 1.35)
	return a

func _anim_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.7
	a.loop_mode = Animation.LOOP_LINEAR
	var L := a.length
	_key_vec2(a, ^"Body:position", [0.0, L * 0.5, L], [Vector2.ZERO, Vector2(0, -2.2), Vector2.ZERO])
	_key_float(a, ^"Body:rotation", [0.0, L * 0.25, L * 0.5, L * 0.75, L], [0.0, 0.03, 0.0, -0.03, 0.0])
	# Heavy two-leg stride with a knee fold.
	_key_float(a, ^"Body/LegLHip:rotation", [0.0, L * 0.5, L], [0.28, -0.28, 0.28])
	_key_float(a, ^"Body/LegRHip:rotation", [0.0, L * 0.5, L], [-0.28, 0.28, -0.28])
	_key_float(a, ^"Body/LegLHip/KneePivot:rotation", [0.0, L * 0.25, L * 0.5, L * 0.75, L], [0.05, 0.4, 0.05, 0.05, 0.05])
	_key_float(a, ^"Body/LegRHip/KneePivot:rotation", [0.0, L * 0.25, L * 0.5, L * 0.75, L], [0.05, 0.05, 0.05, 0.4, 0.05])
	# Arms sway with the gait — menacing, not limp.
	for arm in ARMS:
		var nm: String = arm["name"]
		var s := _side(nm)
		_key_float(a, NodePath("Body/%s:rotation" % nm), [0.0, L * 0.5, L], [0.08 * s, -0.08 * s, 0.08 * s])
	return a

func _anim_attack() -> Animation:
	# The six-arm cascade — body lunges, arms smash forward in a staggered
	# wave (upper → mid → lower), claws converging on the target.
	var a := Animation.new()
	a.length = 0.7
	a.loop_mode = Animation.LOOP_NONE
	var L := a.length
	_key_vec2(a, ^"Body:position", [0.0, L * 0.35, L * 0.55, L],
			[Vector2.ZERO, Vector2(4, 0), Vector2(7, -1), Vector2.ZERO])
	_key_float(a, ^"Body:rotation", [0.0, L * 0.5, L], [0.0, 0.06, 0.0])
	for arm in ARMS:
		var nm: String = arm["name"]
		var s := _side(nm)
		var row := _row(nm)
		var peak := L * (0.40 + row * 0.08)   # cascade by row
		_key_float(a, NodePath("Body/%s:rotation" % nm),
				[0.0, peak * 0.5, peak, L], [0.0, -0.2 * s, 0.95 * s, 0.0])
		var elbow := "Body/%s/ElbowPivot" % nm
		_key_float(a, NodePath("%s:rotation" % elbow),
				[0.0, peak * 0.5, peak, L], [0.0, 0.3 * s, -0.2 * s, 0.0])
	_flare_glow(a, L)
	return a

func _anim_cast() -> Animation:
	# The taunt/invocation — all six arms raise WIDE + up, the idol rises,
	# eyes + palm-sigils blaze. (Replaces the old generic boss taunt.)
	var a := Animation.new()
	a.length = 1.1
	a.loop_mode = Animation.LOOP_NONE
	var L := a.length
	_key_vec2(a, ^"Body:position", [0.0, L * 0.32, L * 0.8, L],
			[Vector2.ZERO, Vector2(0, -3), Vector2(0, -3), Vector2.ZERO])
	_key_color(a, ^"Body/Head:modulate", [0.0, L * 0.3, L * 0.8, L],
			[Color(1, 1, 1, 1), Color(1.4, 1.0, 1.1, 1), Color(1.4, 1.0, 1.1, 1), Color(1, 1, 1, 1)])
	for arm in ARMS:
		var nm: String = arm["name"]
		var s := _side(nm)
		# Spread the fan WIDER (rotate outward = opposite the strike sign).
		_key_float(a, NodePath("Body/%s:rotation" % nm),
				[0.0, L * 0.3, L * 0.8, L], [0.0, -0.5 * s, -0.5 * s, 0.0])
	_flare_glow(a, L)
	return a

func _anim_die() -> Animation:
	# The idol topples — arms fall limp, the body sinks + tips, light dies.
	var a := Animation.new()
	a.length = 1.0
	a.loop_mode = Animation.LOOP_NONE
	var L := a.length
	_key_vec2(a, ^"Body:position", [0.0, L], [Vector2.ZERO, Vector2(0, 8)])
	_key_float(a, ^"Body:rotation", [0.0, L], [0.0, 0.45])
	for arm in ARMS:
		var nm: String = arm["name"]
		var s := _side(nm)
		_key_float(a, NodePath("Body/%s:rotation" % nm), [0.0, L], [0.0, 0.6 * s])
	_key_color(a, ^"Body:modulate", [0.0, L * 0.4, L],
			[Color(1, 1, 1, 1), Color(0.6, 0.5, 0.5, 0.8), Color(0.3, 0.3, 0.35, 0.0)])
	return a

# Pulse / flare the ember eyes + every palm-sigil (modulate brighten).
func _glow_paths_boss() -> Array:
	var out: Array = ["Body/EyeL", "Body/EyeR"]
	for arm in ARMS:
		out.append("Body/%s/ElbowPivot/Sigil" % arm["name"])
	return out

func _pulse_glow(a: Animation, L: float, amt: float) -> void:
	for p in _glow_paths_boss():
		_key_color(a, NodePath("%s:modulate" % p), [0.0, L * 0.5, L],
				[Color(1, 1, 1, 1), Color(amt, amt * 0.9, amt * 0.7, 1), Color(1, 1, 1, 1)])

func _flare_glow(a: Animation, L: float) -> void:
	for p in _glow_paths_boss():
		_key_color(a, NodePath("%s:modulate" % p), [0.0, L * 0.4, L * 0.8, L],
				[Color(1, 1, 1, 1), Color(2.0, 1.6, 0.9, 1), Color(2.0, 1.6, 0.9, 1), Color(1, 1, 1, 1)])

# ---- geometry helpers ----------------------------------------------------

func _side(arm_name: String) -> float:
	return -1.0 if arm_name.ends_with("L") else 1.0

func _row(arm_name: String) -> int:
	if arm_name.contains("Upper"): return 0
	if arm_name.contains("Mid"): return 1
	return 2

# A tapered limb quad from a to b, half-widths wa (at a) and wb (at b).
func _limb(a: Vector2, b: Vector2, wa: float, wb: float) -> PackedVector2Array:
	var d := b - a
	var l := d.length()
	if l < 0.001:
		return PackedVector2Array([a, a + Vector2(0.1, 0), a + Vector2(0, 0.1)])
	var n := Vector2(-d.y, d.x) / l
	return PackedVector2Array([a + n * wa, b + n * wb, b - n * wb, a - n * wa])

# A 3-point claw at point p extending along unit dir.
func _claw(p: Vector2, dir: Vector2) -> PackedVector2Array:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	return PackedVector2Array([p + n * 1.8, p + d * 4.5, p - n * 1.8])

func _horn(side: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(side * 4.0, -84.0), Vector2(side * 5.8, -85.0),
		Vector2(side * 8.0, -87.6), Vector2(side * 7.0, -85.0),
		Vector2(side * 5.0, -82.8),
	])

func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var n := 14
	for i in n:
		var t := TAU * i / n
		pts.append(Vector2(c.x + rx * cos(t), c.y + ry * sin(t)))
	return pts

func _paint(path: Variant, pts: PackedVector2Array, color: Color) -> void:
	var p := get_node_or_null(NodePath(path)) as Polygon2D
	if p == null:
		return
	p.polygon = pts
	p.color = color

func _child_poly(parent: Node2D, node_name: String, pts: PackedVector2Array, color: Color) -> void:
	var p := parent.get_node_or_null(NodePath(node_name)) as Polygon2D
	if p == null:
		p = Polygon2D.new()
		p.name = node_name
		parent.add_child(p)
	p.polygon = pts
	p.color = color

func _overlay(parent: Node2D, node_name: String, pts: PackedVector2Array, color: Color, z: int) -> void:
	_child_poly(parent, node_name, pts, color)
	(parent.get_node(NodePath(node_name)) as Polygon2D).z_index = z
