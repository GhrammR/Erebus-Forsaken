extends "res://scripts/systems/sprite_runtime_2d.gd"
## BEAST species rig (Phase 5) — the Blighted Hound.
##
## The largest deviation from the HUMAN baseline: a QUADRUPED. Built NOT
## on the biped silhouette but on the same joint-pivot system (hip/knee
## pivots, marker-free rotation tracks) re-laid as a four-legged frame —
## a lean low-slung canine facing right (+x): forward-thrust snouted head
## on a sloped neck, thin digitigrade legs (two near, two far, depth-
## layered), a straight low tail. Re-skinned blighted (grey-green hide,
## dark mottling, sickly amber eyes) — a corrupted predator of the
## Blighted Reach. This is the shared BEAST baseline other quadrupeds
## derive from (anim_set = quadruped; a winged sub-variant would add
## paired wings — out of scope here).
##
## The six canonical anims (idle/walk/attack/cast/hit/die) are built by
## the OVERRIDES below, NOT SpriteRuntime2D's biped builders — a
## quadruped has no Arm*Shoulder / Leg*Hip tracks. `_anim_hit` is the one
## exception: the inherited body-modulate flash works on any rig.
## BEAST part set per rules/sprite-animation.md §2 / AnatomyFamilies.PARTS
## [BEAST]: Head, NeckBeast, BodyTrunk, Tail, LegFront{L,R}, LegBack{L,R}.

const HIDE: Color      = Color(0.36, 0.42, 0.32)   # blighted grey-green hide
const BELLY: Color     = Color(0.46, 0.50, 0.41)   # pale starved underside
const HIDE_DARK: Color = Color(0.25, 0.30, 0.23)   # far-side limbs / shade
const HIDE_BACK: Color = Color(0.27, 0.32, 0.24)   # darker dorsal / tail
const DORSAL: Color    = Color(0.20, 0.24, 0.18)   # dark dorsal band
const MUSCLE: Color    = Color(0.29, 0.34, 0.26)   # shoulder/haunch shading
const MOTTLE: Color    = Color(0.17, 0.21, 0.15)   # rib shadow / mottle
const RUFF: Color      = Color(0.30, 0.35, 0.27)   # neck ruff / fur tufts
const CLAW: Color      = Color(0.13, 0.12, 0.10)   # paws
const NOSE: Color      = Color(0.07, 0.06, 0.06)   # nose leather
const EYE: Color       = Color(0.95, 0.75, 0.25)   # sickly amber
const MAW: Color       = Color(0.22, 0.10, 0.12)   # dark mouth interior
const SHADOW: Color    = Color(0.0, 0.0, 0.05, 0.45)

# Diagonal trot pairs: front-near + back-far swing together, the other
# diagonal opposite. A 2-beat gait reads as a quick canine trot.
const PHASE_A := ["LegFrontR", "LegBackL"]
const PHASE_B := ["LegFrontL", "LegBackR"]

func _ready() -> void:
	sprite_id = &"blighted_hound"
	stance_bucket = &"enemies"
	_paint_rig()
	# Builds the six anims (our overrides) + selects stance + plays idle.
	setup_sprite_runtime()

# A quadruped supplies its own legs in the scene — never the injected
# HUMAN biped leg chain.
func _uses_standard_leg_anatomy() -> bool:
	return false

# ---- rig paint -----------------------------------------------------------

func _paint_rig() -> void:
	# Reposition the joints for a gaunt-wolf frame + a staggered (dynamic)
	# stance: near legs forward, far legs back; hind hocks set low + back.
	_set_pos("Body/NeckBeast", Vector2(13, -31))
	_set_pos("Body/NeckBeast/Head", Vector2(10, -7))
	_set_pos("Body/Tail", Vector2(-20, -29))
	_set_pos("Body/LegFrontR", Vector2(13, -25))
	_set_pos("Body/LegFrontL", Vector2(9.5, -24))
	_set_pos("Body/LegBackR", Vector2(-15, -26))
	_set_pos("Body/LegBackL", Vector2(-19, -25))
	for s in ["LegFrontR", "LegFrontL"]:
		_set_pos("Body/%s/KneePivot" % s, Vector2(0.5, 12))
	for s in ["LegBackR", "LegBackL"]:
		_set_pos("Body/%s/KneePivot" % s, Vector2(-1.5, 13))

	var shadow := get_node_or_null(^"Shadow") as Polygon2D
	if shadow != null:
		shadow.polygon = _ellipse(Vector2(-3, 1), 23.0, 4.0)
		shadow.color = SHADOW

	# --- far (L) legs first, behind the trunk -----------------------------
	_paint_hind_leg(^"Body/LegBackL", HIDE_DARK)
	_paint_front_leg(^"Body/LegFrontL", HIDE_DARK)

	# --- trunk: gaunt wolf — deep chest, starved tuck, arched topline -----
	_paint(^"Body/BodyTrunk", PackedVector2Array([
		Vector2(12, -32),    # withers (high)
		Vector2(-3, -30),    # back dip
		Vector2(-20, -31),   # croup (rises)
		Vector2(-23, -27),   # rump
		Vector2(-15, -24),   # flank
		Vector2(-2, -25),    # starved belly tuck (pulled up)
		Vector2(8, -20),     # deep chest bottom
		Vector2(14, -24),    # brisket front
		Vector2(15, -30),    # shoulder front
	]), HIDE)
	var body := get_node(^"Body") as Node2D
	# Pale starved underside (chest → tuck).
	_overlay(body, "Belly", PackedVector2Array([
		Vector2(13, -23), Vector2(8, -20.5), Vector2(-2, -24.5), Vector2(-14, -23.5),
		Vector2(-13, -22), Vector2(-2, -22.5), Vector2(7, -19), Vector2(12, -22),
	]), BELLY, 1)
	# Dark dorsal band along the arched back.
	_overlay(body, "Dorsal", PackedVector2Array([
		Vector2(12, -32), Vector2(-3, -30), Vector2(-20, -31), Vector2(-20, -29.5),
		Vector2(-3, -28.5), Vector2(11, -30.5),
	]), DORSAL, 1)
	# Shoulder + haunch muscle shading.
	_overlay(body, "ShoulderShade", _ellipse(Vector2(11, -27), 3.6, 4.2), MUSCLE, 1)
	_overlay(body, "HaunchFar", _ellipse(Vector2(-17, -27), 4.8, 4.6), HIDE_DARK, -2)
	_overlay(body, "HaunchNear", _ellipse(Vector2(-15, -27), 5.0, 4.8), MUSCLE, 1)
	# Visible rib shadows on the gaunt chest.
	for i in 3:
		var rx := 1.0 + i * 3.2
		_overlay(body, "Rib%d" % i, PackedVector2Array([
			Vector2(rx, -25.5), Vector2(rx + 0.9, -25.6),
			Vector2(rx + 1.6, -21.5), Vector2(rx + 0.7, -21.4),
		]), MOTTLE, 2)
	# Neck ruff — a fur fringe hugging the neck/shoulder front, throat to
	# withers (raised-hackle read), kept tight to the body so it does not
	# float as a spike.
	_overlay(body, "Ruff", PackedVector2Array([
		Vector2(11, -31), Vector2(15, -30), Vector2(16.5, -27),
		Vector2(15, -27.5), Vector2(15.5, -24), Vector2(13.5, -25.5),
		Vector2(13.5, -22.5), Vector2(12, -24.5), Vector2(11, -27),
	]), RUFF, 2)

	# --- tail: bushier, base inside the rump (stays attached) -------------
	_paint(^"Body/Tail/TailSeg", PackedVector2Array([
		Vector2(2, -3.5), Vector2(2, 3.5), Vector2(-9, 7),
		Vector2(-15, 10), Vector2(-17, 7), Vector2(-13, 4),
	]), HIDE_BACK)

	# --- neck + head ------------------------------------------------------
	_paint(^"Body/NeckBeast/NeckSeg", PackedVector2Array([
		Vector2(-1, 5), Vector2(-1, -3), Vector2(8, -7), Vector2(11, -6), Vector2(9, -2),
	]), HIDE)
	# Head — a proper wolf skull: brow, muzzle, lower jaw line.
	_paint(^"Body/NeckBeast/Head/HeadShape", PackedVector2Array([
		Vector2(-5, -1), Vector2(-4, -4),   # back of skull
		Vector2(1, -5),                      # brow
		Vector2(7, -4), Vector2(11, -2.5),   # muzzle top
		Vector2(12.5, -1),                   # nose tip
		Vector2(11, 0.5), Vector2(7, 1),     # under muzzle
		Vector2(2, 2.5), Vector2(-3, 3),     # jaw line / throat
	]), HIDE)
	_paint(^"Body/NeckBeast/Head/Ear", PackedVector2Array([
		Vector2(-3.5, -3.5), Vector2(-1.5, -9), Vector2(1.5, -3.5),
	]), HIDE_BACK)
	_overlay(get_node(^"Body/NeckBeast/Head"), "Brow", PackedVector2Array([
		Vector2(0, -4.8), Vector2(4, -4.2), Vector2(4, -3.4), Vector2(0, -3.8),
	]), DORSAL, 1)
	_paint(^"Body/NeckBeast/Head/Maw", PackedVector2Array([
		Vector2(3, 0.4), Vector2(11, -0.6), Vector2(11.5, 0.6), Vector2(3, 1.6),
	]), MAW)
	_paint(^"Body/NeckBeast/Head/Jaw/JawShape", PackedVector2Array([
		Vector2(0, 0), Vector2(9, -0.5), Vector2(10, 1.0), Vector2(0, 2),
	]), HIDE_DARK)
	_overlay(get_node(^"Body/NeckBeast/Head"), "Nose",
			_ellipse(Vector2(12, -1.2), 1.1, 1.0), NOSE, 2)
	_paint(^"Body/NeckBeast/Head/Eye", _ellipse(Vector2(2.5, -2.2), 1.0, 0.8), EYE)

	# --- near (R) legs last, in front of the trunk ------------------------
	_paint_hind_leg(^"Body/LegBackR", HIDE)
	_paint_front_leg(^"Body/LegFrontR", HIDE)

# Front leg — humerus/radius + a short pastern, paw set forward.
func _paint_front_leg(pivot_path: NodePath, color: Color) -> void:
	var base := pivot_path.get_concatenated_names()
	_paint(base + "/Upper", PackedVector2Array([
		Vector2(-1.9, 0), Vector2(2.0, 0), Vector2(1.3, 12), Vector2(-0.9, 12),
	]), color)
	_paint(base + "/KneePivot/Lower", _seg(1.1, 0.9, 11.0), color.darkened(0.06))
	_paint(base + "/KneePivot/Paw", PackedVector2Array([
		Vector2(-1.3, 11), Vector2(3.4, 11), Vector2(3.6, 13.2), Vector2(-1.3, 13.2),
	]), CLAW)

# Hind leg — heavy thigh tapering to a low/back hock, metatarsus angling
# forward to the paw (the digitigrade Z-bend).
func _paint_hind_leg(pivot_path: NodePath, color: Color) -> void:
	var base := pivot_path.get_concatenated_names()
	_paint(base + "/Upper", PackedVector2Array([
		Vector2(-2.6, 0), Vector2(2.6, 0), Vector2(3.0, 6),
		Vector2(1.0, 13), Vector2(-2.2, 13), Vector2(-2.8, 6),
	]), color)
	# Metatarsus angles down-and-forward (bottom shifted +x) to the paw.
	_paint(base + "/KneePivot/Lower", PackedVector2Array([
		Vector2(-1.1, 0), Vector2(1.1, 0), Vector2(2.4, 11), Vector2(0.6, 11),
	]), color.darkened(0.06))
	_paint(base + "/KneePivot/Paw", PackedVector2Array([
		Vector2(0.2, 11), Vector2(4.4, 11), Vector2(4.6, 13.2), Vector2(0.2, 13.2),
	]), CLAW)

func _set_pos(path: String, pos: Vector2) -> void:
	var n := get_node_or_null(NodePath(path)) as Node2D
	if n != null:
		n.position = pos

# ---- canonical anim overrides (quadruped) --------------------------------

func _anim_idle() -> Animation:
	var a := Animation.new()
	a.length = 1.8
	a.loop_mode = Animation.LOOP_LINEAR
	var L := a.length
	_key_vec2(a, ^"Body:position", [0.0, L * 0.5, L], [Vector2.ZERO, Vector2(0, -0.7), Vector2.ZERO])
	_key_float(a, ^"Body/NeckBeast:rotation", [0.0, L * 0.5, L], [0.0, 0.03, 0.0])
	_key_float(a, ^"Body/Tail:rotation", [0.0, L * 0.5, L], [0.08, -0.08, 0.08])
	return a

func _anim_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.5
	a.loop_mode = Animation.LOOP_LINEAR
	var L := a.length
	# Two body bobs per stride = the trot beat.
	_key_vec2(a, ^"Body:position", [0.0, L * 0.25, L * 0.5, L * 0.75, L],
			[Vector2.ZERO, Vector2(0, -1.2), Vector2.ZERO, Vector2(0, -1.2), Vector2.ZERO])
	_key_float(a, ^"Body:rotation", [0.0, L * 0.5, L], [0.0, 0.02, 0.0])
	for leg in PHASE_A:
		_key_float(a, NodePath("Body/%s:rotation" % leg), [0.0, L * 0.5, L], [0.35, -0.35, 0.35])
		_key_float(a, NodePath("Body/%s/KneePivot:rotation" % leg),
				[0.0, L * 0.25, L * 0.5, L * 0.75, L], [0.05, 0.35, 0.05, 0.05, 0.05])
	for leg in PHASE_B:
		_key_float(a, NodePath("Body/%s:rotation" % leg), [0.0, L * 0.5, L], [-0.35, 0.35, -0.35])
		_key_float(a, NodePath("Body/%s/KneePivot:rotation" % leg),
				[0.0, L * 0.25, L * 0.5, L * 0.75, L], [0.05, 0.05, 0.05, 0.35, 0.05])
	_key_float(a, ^"Body/NeckBeast:rotation", [0.0, L * 0.5, L], [0.0, 0.04, 0.0])
	_key_float(a, ^"Body/Tail:rotation", [0.0, L * 0.5, L], [0.06, -0.06, 0.06])
	return a

func _anim_attack() -> Animation:
	# Lunge-bite: the body drives forward, the neck thrusts the head down
	# and the jaw snaps open then shut.
	var a := Animation.new()
	a.length = 0.45
	a.loop_mode = Animation.LOOP_NONE
	var L := a.length
	_key_vec2(a, ^"Body:position", [0.0, L * 0.3, L * 0.5, L],
			[Vector2.ZERO, Vector2(3, 0), Vector2(5, -1), Vector2.ZERO])
	_key_float(a, ^"Body:rotation", [0.0, L * 0.5, L], [0.0, 0.05, 0.0])
	_key_float(a, ^"Body/NeckBeast:rotation", [0.0, L * 0.18, L * 0.5, L], [0.0, -0.18, 0.45, 0.0])
	_key_float(a, ^"Body/NeckBeast/Head:rotation", [0.0, L * 0.18, L * 0.5, L], [0.0, -0.1, 0.35, 0.0])
	_key_float(a, ^"Body/NeckBeast/Head/Jaw:rotation", [0.0, L * 0.4, L * 0.6, L], [0.0, 0.7, 0.7, 0.0])
	for leg in ["LegFrontR", "LegFrontL"]:
		_key_float(a, NodePath("Body/%s:rotation" % leg), [0.0, L * 0.5, L], [0.0, -0.3, 0.0])
	_key_color(a, ^"Body/NeckBeast/Head/Eye:modulate", [0.0, L * 0.5, L],
			[Color(1, 1, 1, 1), Color(1.6, 1.3, 0.6, 1), Color(1, 1, 1, 1)])
	return a

func _anim_cast() -> Animation:
	# Beasts don't cast — this is a threat SNARL/HOWL: head rears up + back,
	# jaw open, eyes flare. Built so the canonical 'cast' name exists.
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_NONE
	var L := a.length
	_key_float(a, ^"Body/NeckBeast:rotation", [0.0, L * 0.25, L * 0.75, L], [0.0, -0.5, -0.5, 0.0])
	_key_float(a, ^"Body/NeckBeast/Head:rotation", [0.0, L * 0.25, L * 0.75, L], [0.0, -0.25, -0.25, 0.0])
	_key_float(a, ^"Body/NeckBeast/Head/Jaw:rotation", [0.0, L * 0.25, L * 0.75, L], [0.0, 0.6, 0.6, 0.0])
	_key_vec2(a, ^"Body:position", [0.0, L * 0.3, L], [Vector2.ZERO, Vector2(-2, 1), Vector2.ZERO])
	_key_color(a, ^"Body/NeckBeast/Head/Eye:modulate", [0.0, L * 0.3, L * 0.7, L],
			[Color(1, 1, 1, 1), Color(1.9, 1.4, 0.6, 1), Color(1.9, 1.4, 0.6, 1), Color(1, 1, 1, 1)])
	return a

func _anim_die() -> Animation:
	# Collapse: legs buckle outward, the body sinks + tips, hide fades.
	var a := Animation.new()
	a.length = 0.75
	a.loop_mode = Animation.LOOP_NONE
	var L := a.length
	_key_vec2(a, ^"Body:position", [0.0, L], [Vector2.ZERO, Vector2(0, 7)])
	_key_float(a, ^"Body:rotation", [0.0, L], [0.0, 0.4])
	_key_float(a, ^"Body/NeckBeast:rotation", [0.0, L], [0.0, 0.3])
	_key_float(a, ^"Body/LegFrontR:rotation", [0.0, L], [0.0, 0.5])
	_key_float(a, ^"Body/LegFrontL:rotation", [0.0, L], [0.0, 0.6])
	_key_float(a, ^"Body/LegBackR:rotation", [0.0, L], [0.0, -0.5])
	_key_float(a, ^"Body/LegBackL:rotation", [0.0, L], [0.0, -0.6])
	_key_color(a, ^"Body:modulate", [0.0, L * 0.4, L],
			[Color(1, 1, 1, 1), Color(0.6, 0.6, 0.6, 0.8), Color(0.4, 0.4, 0.45, 0.0)])
	return a

# ---- geometry helpers ----------------------------------------------------

func _seg(htop: float, hbot: float, length: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-htop, 0), Vector2(htop, 0),
		Vector2(hbot, length), Vector2(-hbot, length),
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
