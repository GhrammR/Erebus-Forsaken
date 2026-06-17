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

const HIDE: Color      = Color(0.34, 0.40, 0.30)   # blighted grey-green hide
const HIDE_DARK: Color = Color(0.24, 0.29, 0.22)   # far-side limbs / shade
const HIDE_BACK: Color = Color(0.27, 0.32, 0.24)   # darker dorsal / tail
const MOTTLE: Color    = Color(0.18, 0.22, 0.16)   # dark mottled patches
const CLAW: Color      = Color(0.13, 0.12, 0.10)   # paws
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
	var shadow := get_node_or_null(^"Shadow") as Polygon2D
	if shadow != null:
		shadow.polygon = _ellipse(Vector2(-3, 1), 22.0, 4.0)
		shadow.color = SHADOW
	# Trunk — a lean dog body, belly tucked up.
	_paint(^"Body/BodyTrunk", PackedVector2Array([
		Vector2(15, -30), Vector2(-20, -28), Vector2(-23, -21),
		Vector2(-12, -19), Vector2(4, -20), Vector2(13, -22), Vector2(16, -27),
	]), HIDE)
	# A mottled patch over the shoulders/back for the blighted read.
	_overlay(get_node(^"Body"), "Mottle", PackedVector2Array([
		Vector2(8, -29), Vector2(-12, -27.5), Vector2(-10, -24), Vector2(6, -25),
	]), MOTTLE, 1)
	# Tail — straight + low, trailing back-and-down. The base starts INSIDE
	# the trunk (+x, overlapping the rump) so it reads as attached, not a
	# floating appendage with a gap (Stage 17.10 tail-disconnect fix).
	_paint(^"Body/Tail/TailSeg", PackedVector2Array([
		Vector2(2, -3), Vector2(2, 3), Vector2(-14, 6), Vector2(-13, 4),
	]), HIDE_BACK)
	# Neck — sloped wedge from the shoulders up to the head base.
	_paint(^"Body/NeckBeast/NeckSeg", PackedVector2Array([
		Vector2(0, 4), Vector2(0, -1), Vector2(11, -6.5), Vector2(9, -3),
	]), HIDE)
	# Head — snouted wedge facing +x.
	_paint(^"Body/NeckBeast/Head/HeadShape", PackedVector2Array([
		Vector2(-4, -3), Vector2(2, -4), Vector2(9, -2), Vector2(11, 0),
		Vector2(9, 2), Vector2(2, 3), Vector2(-3, 3),
	]), HIDE)
	_paint(^"Body/NeckBeast/Head/Ear", PackedVector2Array([
		Vector2(-3, -3), Vector2(-1, -7.5), Vector2(1.5, -2.5),
	]), HIDE_BACK)
	_paint(^"Body/NeckBeast/Head/Maw", PackedVector2Array([
		Vector2(2, 1.6), Vector2(10, 0.8), Vector2(10, 2.4), Vector2(2, 3.2),
	]), MAW)
	_paint(^"Body/NeckBeast/Head/Jaw/JawShape", PackedVector2Array([
		Vector2(0, 0), Vector2(8, -0.4), Vector2(8.5, 1.3), Vector2(0, 2),
	]), HIDE_DARK)
	_paint(^"Body/NeckBeast/Head/Eye", _ellipse(Vector2(3.2, -1.0), 1.0, 0.9), EYE)
	# Four legs — near pair (R) light, far pair (L) shaded for depth.
	_paint_leg(^"Body/LegFrontR", HIDE)
	_paint_leg(^"Body/LegBackR", HIDE)
	_paint_leg(^"Body/LegFrontL", HIDE_DARK)
	_paint_leg(^"Body/LegBackL", HIDE_DARK)

func _paint_leg(pivot_path: NodePath, color: Color) -> void:
	var pivot := get_node_or_null(pivot_path) as Node2D
	if pivot == null:
		return
	_paint(pivot_path.get_concatenated_names() + "/Upper",
			_seg(1.7, 1.3, 12.0), color)
	_paint(pivot_path.get_concatenated_names() + "/KneePivot/Lower",
			_seg(1.3, 1.0, 12.0), color.darkened(0.08))
	_paint(pivot_path.get_concatenated_names() + "/KneePivot/Paw", PackedVector2Array([
		Vector2(-1.2, 12), Vector2(3.2, 12), Vector2(3.2, 13.6), Vector2(-1.2, 13.6),
	]), CLAW)

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
