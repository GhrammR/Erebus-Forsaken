class_name WeaponRig extends Object
## Reusable per-weapon hold + attack contract (Stage 17.8d).
##
## One source of truth for HOW each weapon is held and HOW it strikes, so
## ANY sprite that exposes the shared HUMAN hand rig
## (Body/Arm{R,L}Shoulder/ElbowPivot) can wield it — player classes, NPCs,
## or enemies — with zero per-sprite authoring. A future armed enemy (e.g.
## the Bog Caller sharing the character wand) just calls mount() + the
## add_*() animators.
##
## Grip model (see rules/sprite-animation.md §5b): the primary grip WELDS
## the weapon under the right hand's ElbowPivot at GRIP (structural — the
## weapon can never detach). Two-handers (bow) weld the riser and pin only
## the second hand to a nock marker during the draw.

enum Kind { NONE, SPEAR, STAFF, WAND, BOW }

const GRIP: Vector2 = Vector2(0, 10)   # hand centroid, elbow-local
const R_HAND: NodePath = ^"Body/ArmRShoulder/ElbowPivot"

## Default weapon per sprite id — picks the mount + attack/cast pattern.
## Classes + any armed enemy (Bog Caller shares the wand).
const SPRITE_WEAPON: Dictionary = {
	&"myrmidon": Kind.SPEAR,
	&"pythia": Kind.STAFF,
	&"shade_hunter": Kind.BOW,
	&"ossuary_priest": Kind.WAND,
	&"bog_caller": Kind.WAND,
}

const NODE_NAME: Dictionary = {
	Kind.SPEAR: &"SpearArm", Kind.STAFF: &"StaffArm",
	Kind.WAND: &"WandArm", Kind.BOW: &"BowArm",
}

static func kind_for(sprite_id: StringName) -> Kind:
	return SPRITE_WEAPON.get(sprite_id, Kind.NONE)

static func kind_from_name(s: StringName) -> Kind:
	match s:
		&"spear": return Kind.SPEAR
		&"staff": return Kind.STAFF
		&"wand": return Kind.WAND
		&"bow": return Kind.BOW
	return Kind.NONE

# =========================================================================
# MOUNT + GEOMETRY
# =========================================================================

# Weld the weapon under the right hand (creating the arm node + parts if
# the scene doesn't already declare them) and paint its geometry. Returns
# the weapon arm node, or null for NONE / a rig without the hand.
static func mount(root: Node2D, kind: Kind) -> Node2D:
	if kind == Kind.NONE:
		return null
	var hand := root.get_node_or_null(R_HAND) as Node2D
	if hand == null:
		return null
	var arm_name := String(NODE_NAME[kind])
	var arm := root.find_child(arm_name, true, false) as Node2D
	if arm == null:
		arm = Node2D.new()
		arm.name = arm_name
		hand.add_child(arm)
	elif arm.get_parent() != hand:
		arm.get_parent().remove_child(arm)
		hand.add_child(arm)
	arm.position = GRIP
	arm.rotation = 0.0
	arm.z_index = 5   # above body/clothing + free arms (z4), below glints
	_paint(arm, kind)
	return arm

static func _part(arm: Node2D, child: StringName, type: String) -> Node2D:
	var n := arm.get_node_or_null(NodePath(String(child)))
	if n == null:
		n = (Line2D.new() if type == "line" else Polygon2D.new())
		n.name = String(child)
		arm.add_child(n)
	return n

static func _poly(arm: Node2D, child: StringName, pts: PackedVector2Array, color: Color) -> void:
	var p := _part(arm, child, "poly") as Polygon2D
	p.polygon = pts
	p.color = color

static func _ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in 12:
		var t := TAU * i / 12
		pts.append(Vector2(c.x + rx * cos(t), c.y + ry * sin(t)))
	return pts

# Bow draw geometry (bow-local, origin = riser at the hand): the wood
# bulges forward (+x); the string sits BEHIND the riser (nock at -x) so
# the hand grips the BOW, not the string; the left hand draws the nock
# further back.
const BOW_TIP_TOP: Vector2 = Vector2(0, -19)
const BOW_TIP_BOT: Vector2 = Vector2(0, 19)
const BOW_NOCK_REST: Vector2 = Vector2(-6, 0)
const BOW_NOCK_DRAWN: Vector2 = Vector2(-16, 0)

static func _paint(arm: Node2D, kind: Kind) -> void:
	match kind:
		Kind.SPEAR:
			_poly(arm, &"Shaft", PackedVector2Array([
				Vector2(-1, 14), Vector2(1, 14), Vector2(1, -42), Vector2(-1, -42)]),
				Color(0.46, 0.32, 0.17))
			_poly(arm, &"Grip", PackedVector2Array([
				Vector2(-1.7, -1), Vector2(1.7, -1), Vector2(1.7, 4), Vector2(-1.7, 4)]),
				Color(0.28, 0.18, 0.10))
			_poly(arm, &"Tip", PackedVector2Array([
				Vector2(0, -50), Vector2(2.6, -42), Vector2(-2.6, -42)]),
				Color(0.72, 0.74, 0.78))
		Kind.STAFF:
			_poly(arm, &"Shaft", PackedVector2Array([
				Vector2(-1, 18), Vector2(1, 18), Vector2(1, -36), Vector2(-1, -36)]),
				Color(0.42, 0.35, 0.28))
			_poly(arm, &"Grip", PackedVector2Array([
				Vector2(-1.6, -2), Vector2(1.6, -2), Vector2(1.6, 3), Vector2(-1.6, 3)]),
				Color(0.30, 0.24, 0.18))
			_poly(arm, &"Orb", _ellipse(Vector2(0, -40), 3.0, 3.2), Color(0.72, 0.50, 0.85))
		Kind.WAND:
			# A touch longer so the rod clearly EXTENDS from the fist (was
			# short enough to read as buried in the forearm).
			_poly(arm, &"Shaft", PackedVector2Array([
				Vector2(-0.9, 4), Vector2(0.9, 4), Vector2(0.9, -19), Vector2(-0.9, -19)]),
				Color(0.80, 0.78, 0.66))
			_poly(arm, &"Glow", _ellipse(Vector2(0, -21), 2.4, 2.6), Color(0.50, 0.85, 0.45))
		Kind.BOW:
			# Recurve wood: handle near origin, deep forward belly (+x),
			# tips at top/bottom (more curve than the old flat limb).
			_poly(arm, &"Bow", PackedVector2Array([
				Vector2(0, -19), Vector2(4, -13), Vector2(6, -5), Vector2(6, 5),
				Vector2(4, 13), Vector2(0, 19),
				Vector2(1.6, 16), Vector2(4.6, 8), Vector2(2.4, 0), Vector2(4.6, -8), Vector2(1.6, -16)]),
				Color(0.36, 0.24, 0.12))
			var bs := _part(arm, &"Bowstring", "line") as Line2D
			bs.points = PackedVector2Array([BOW_TIP_TOP, BOW_NOCK_REST, BOW_TIP_BOT])
			bs.width = 0.6
			bs.default_color = Color(0.82, 0.80, 0.72)
			_marker(arm, &"RiserMarker", Vector2(2, 0))
			_marker(arm, &"NockMarker", BOW_NOCK_REST)
			_marker(arm, &"BowTipTop", BOW_TIP_TOP)
			_marker(arm, &"BowTipBot", BOW_TIP_BOT)

static func _marker(arm: Node2D, child: StringName, pos: Vector2) -> void:
	var n := arm.get_node_or_null(NodePath(String(child))) as Node2D
	if n == null:
		var m := Marker2D.new()
		m.name = String(child)
		arm.add_child(m)
		n = m
	n.position = pos

# =========================================================================
# ATTACK / CAST PATTERNS (added to an Animation the sprite already seeded
# with its Body bob/rest, so hover-aware sprites stay correct).
# =========================================================================

static func add_attack(a: Animation, root: Node2D, kind: Kind, length: float) -> void:
	match kind:
		Kind.SPEAR:   _spear_attack(a, length)
		Kind.STAFF:   _chop_attack(a, kind, length)
		Kind.WAND:    _chop_attack(a, kind, length)
		Kind.BOW:     _bow_attack(a, length)

static func add_cast(a: Animation, root: Node2D, kind: Kind, length: float) -> void:
	if kind == Kind.BOW:
		_bow_cast(a, length)
	else:
		_raise_vertical_cast(a, kind, length)

# SPEAR — couched forward thrust (lunge). Tip leads.
static func _spear_attack(a: Animation, L: float) -> void:
	_key(a, ^"Body/ArmRShoulder:rotation", [0.0, L * 0.27, L * 0.66, L], [0.0, 0.18, -0.42, 0.0])
	_key(a, ^"Body/ArmLShoulder:rotation", [0.0, L * 0.66, L], [0.0, 0.20, 0.0])
	_key(a, NodePath("%s/SpearArm:rotation" % R_HAND), [0.0, L * 0.27, L * 0.66, L], [0.0, -0.25, 1.5, 0.0])

# STAFF / WAND — OVERHEAD CHOP driven by the WEAPON's own rotation about
# the hand (NOT the arm). The implement stays a held, ~vertical staff/wand
# that winds back overhead then arcs DOWN-forward (tip/orb leads). The arm
# only lifts for power + holds the weapon extended OUT from the fist, so it
# never reads as an "extended arm" (staff) or a rod buried in the forearm
# (wand) — the pivot is the hand, the weapon swings.
static func _chop_attack(a: Animation, kind: Kind, L: float) -> void:
	var wrot := NodePath("%s/%s:rotation" % [R_HAND, NODE_NAME[kind]])
	_key(a, wrot, [0.0, L * 0.28, L * 0.58, L], [0.0, -0.7, 2.5, 0.0])
	_key(a, ^"Body/ArmRShoulder:rotation", [0.0, L * 0.28, L * 0.58, L], [0.0, -0.5, -0.2, 0.0])
	_key(a, ^"Body/ArmRShoulder/ElbowPivot:rotation", [0.0, L * 0.28, L * 0.58, L], [0.0, -0.2, 0.2, 0.0])
	_key(a, ^"Body:rotation", [0.0, L * 0.55, L], [0.0, 0.10, 0.0])
	_key(a, ^"Body/ArmLShoulder:rotation", [0.0, L * 0.58, L], [0.0, 0.22, 0.0])

# BOW — present + draw + loose. The welded bow is counter-rotated to stay
# vertical while the bow arm raises; the nock pulls back (left hand
# follows via the runtime pin) then snaps forward.
static func _bow_attack(a: Animation, L: float) -> void:
	_key(a, ^"Body/ArmRShoulder:rotation", [0.0, L * 0.33, L * 0.83, L], [0.0, -0.7, -0.7, 0.0])
	_key(a, NodePath("%s/BowArm:rotation" % R_HAND), [0.0, L * 0.33, L * 0.83, L], [0.0, 0.7, 0.7, 0.0])
	_key_vec2(a, NodePath("%s/BowArm/NockMarker:position" % R_HAND),
			[0.0, L * 0.75, L * 0.83, L], [BOW_NOCK_REST, BOW_NOCK_DRAWN, BOW_NOCK_DRAWN, BOW_NOCK_REST])

# Melee CAST — raise the weapon high + VERTICAL (counter the arm rotation
# so it doesn't tip at the ground); free arm sweeps out; glow pulses.
static func _raise_vertical_cast(a: Animation, kind: Kind, L: float) -> void:
	_key(a, ^"Body/ArmRShoulder:rotation", [0.0, L * 0.45, L * 0.72, L], [0.0, -1.95, -1.95, 0.0])
	_key(a, ^"Body/ArmRShoulder/ElbowPivot:rotation", [0.0, L * 0.45, L], [0.0, -0.35, 0.0])
	_key(a, NodePath("%s/%s:rotation" % [R_HAND, NODE_NAME[kind]]), [0.0, L * 0.45, L * 0.72, L], [0.0, 2.3, 2.3, 0.0])
	_key(a, ^"Body/ArmLShoulder:rotation", [0.0, L * 0.45, L * 0.72, L], [0.0, 1.95, 1.95, 0.0])
	_key(a, ^"Body/ArmLShoulder/ElbowPivot:rotation", [0.0, L * 0.45, L], [0.0, 0.35, 0.0])
	var orb := NodePath("%s/%s/Orb:modulate" % [R_HAND, NODE_NAME[kind]]) if kind == Kind.STAFF \
			else NodePath("%s/%s/Glow:modulate" % [R_HAND, NODE_NAME[kind]])
	if kind == Kind.STAFF or kind == Kind.WAND:
		_key_color(a, orb, [0.0, L * 0.5, L], [Color(1, 1, 1, 1), Color(2.2, 1.9, 1.0, 1), Color(1, 1, 1, 1)])

# BOW CAST — raise the bow high (kept vertical); free arm gestures.
static func _bow_cast(a: Animation, L: float) -> void:
	_key(a, ^"Body/ArmRShoulder:rotation", [0.0, L * 0.45, L * 0.72, L], [0.0, -1.6, -1.6, 0.0])
	_key(a, NodePath("%s/BowArm:rotation" % R_HAND), [0.0, L * 0.45, L * 0.72, L], [0.0, 1.6, 1.6, 0.0])
	_key(a, ^"Body/ArmLShoulder:rotation", [0.0, L * 0.45, L * 0.72, L], [0.0, 1.95, 1.95, 0.0])
	_key(a, ^"Body/ArmLShoulder/ElbowPivot:rotation", [0.0, L * 0.45, L], [0.0, 0.35, 0.0])

# =========================================================================
# BOW RUNTIME — second hand draws the nock; bowstring tracks it.
# =========================================================================
const _BOW_NOCK_PIN: Dictionary = {
	"shoulder": ^"Body/ArmLShoulder",
	"target": ^"Body/ArmRShoulder/ElbowPivot/BowArm/NockMarker",
	"elbow_dir": 1, "skip_anims": [],
}

static func process_bow(root: Node2D, anim: AnimationPlayer, ik_enabled: bool) -> void:
	var arm := root.get_node_or_null(NodePath("%s/BowArm" % R_HAND)) as Node2D
	if arm == null or not arm.is_visible_in_tree() or anim == null:
		return
	var body := root.get_node_or_null(^"Body") as Node2D
	if ik_enabled and body != null and anim.current_animation == &"attack":
		HumanRig.apply_pins(root, body, [_BOW_NOCK_PIN], anim.current_animation)
	var bs := arm.get_node_or_null(^"Bowstring") as Line2D
	var nm := arm.get_node_or_null(^"NockMarker") as Node2D
	var tt := arm.get_node_or_null(^"BowTipTop") as Node2D
	var tb := arm.get_node_or_null(^"BowTipBot") as Node2D
	if bs != null and nm != null and tt != null and tb != null:
		bs.points = PackedVector2Array([tt.position, nm.position, tb.position])

# =========================================================================
static func _key(a: Animation, path: NodePath, times: Array, values: Array) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, path)
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for i in range(times.size()):
		a.track_insert_key(t, float(times[i]), float(values[i]))

static func _key_vec2(a: Animation, path: NodePath, times: Array, values: Array) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, path)
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for i in range(times.size()):
		a.track_insert_key(t, float(times[i]), values[i])

static func _key_color(a: Animation, path: NodePath, times: Array, values: Array) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, path)
	for i in range(times.size()):
		a.track_insert_key(t, float(times[i]), values[i])
