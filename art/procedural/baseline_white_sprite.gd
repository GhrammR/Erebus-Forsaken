extends Node2D
## Single active procedural baseline sprite.
##
## Intentional reset: every current player, enemy, and NPC sprite path
## points at this one Myrmidon-derived white anatomy rig. Archived
## implementations live under art/procedural/archive/baseline_reset_2026_06_11.

const SpriteOverrides = preload("res://scripts/systems/sprite_overrides.gd")
const SkinLib = preload("res://scripts/systems/skin_library.gd")

const WHITE: Color = Color(1.0, 1.0, 1.0, 1.0)
const SHADOW: Color = Color(0.0, 0.0, 0.05, 0.45)

@export var sprite_id: StringName = &"baseline_white"
@export var stance_bucket: StringName = &""
@export var stance_id: StringName = &"baseline"
@export var ik_enabled: bool = true
@export var show_spear: bool = false
@export var show_staff: bool = false
@export var show_bow: bool = false
@export var show_wand: bool = false

@onready var _shadow: Polygon2D = $Shadow
@onready var _body: Node2D = $Body
@onready var _anim: AnimationPlayer = $AnimationPlayer

var _per_anim_config: Dictionary = {}
var _replaying_for_injection: bool = false

func _ready() -> void:
	_shadow.color = SHADOW
	_shadow.polygon = HumanRig.shadow_poly()
	# Stage 17.6 Phase 2: a data-driven skin (SkinLibrary) paints the rig
	# with the character's palette + accoutrements. No skin entry → the
	# shared white baseline (the reset default).
	if SkinLib.has(sprite_id):
		SkinLib.apply(self, sprite_id)
		# Faces only on skinned characters — the white-baseline placeholders
		# (and the bespoke act_boss) stay faceless until they get a skin.
		_add_face()
	else:
		HumanRig.apply(_body, WHITE, WHITE)
		_paint_polygon_tree(_body, WHITE)
	_hide_compatibility_nodes()
	if SkinLib.has(sprite_id):
		_apply_polish(_body)
	_build_animations()
	_per_anim_config = SpriteOverrides.load_for_class(sprite_id, stance_id)
	_anim.animation_started.connect(_on_anim_started)
	_anim.play(&"idle")

const _PUPIL: Color = Color(0.10, 0.09, 0.09)
const _SOCKET: Color = Color(0.34, 0.27, 0.23)
const _GLINT: Color = Color(0.93, 0.95, 0.87)

## Give every HUMAN sprite a readable face: sockets/eyes/brow/mouth
## (HumanRig face geometry) at z=4 so helms/hoods (z>=5) still occlude
## the face, plus always-visible eye glints (z=6) so the eyes read even
## in a hood's shadow or under a helm brim. Fixes "the sprites have no
## eyes" + a big chunk of the decipherability gap.
func _add_face() -> void:
	var face := _body.get_node_or_null(^"Face") as Node2D
	if face == null:
		face = Node2D.new()
		face.name = "Face"
		_body.add_child(face)
		for n in ["EyeSocketL", "EyeSocketR", "EyeL", "EyeR", "Brow", "Mouth"]:
			var part := Polygon2D.new()
			part.name = n
			face.add_child(part)
	face.z_index = 4
	HumanRig.paint_face(_body, _PUPIL, _SOCKET)
	for cx in [-2.2, 2.2]:
		var gname := "Glint%s" % ("L" if cx < 0.0 else "R")
		var g := _body.get_node_or_null(NodePath(gname)) as Polygon2D
		if g == null:
			g = Polygon2D.new()
			g.name = gname
			_body.add_child(g)
		g.z_index = 6
		g.color = _GLINT
		var pts: PackedVector2Array = []
		for i in 8:
			var t := TAU * i / 8
			pts.append(Vector2(cx + 0.6 * cos(t), HumanRig.HEAD_MID + 0.5 * sin(t)))
		g.polygon = pts

const _OUTLINE_PX: float = 1.1
const _OUTLINE_COLOR: Color = Color(0.07, 0.06, 0.09)
# Detail/glow parts kept crisp (no outline, no shading gradient).
const _POLISH_SKIP: PackedStringArray = [
	"Glint", "Eye", "Socket", "Brow", "Mouth", "Glow", "Orb", "Sigil", "_OL", "Face",
]

## Readability polish for the skinned cast: a uniform dark outline
## behind each body/clothing part (Geometry2D.offset_polygon, added as a
## CHILD so it follows the rig's animation) + a top-light/bottom-shadow
## vertex gradient for form. Makes the flat skins pop and read clearly.
func _apply_polish(body: Node2D) -> void:
	var parts: Array[Polygon2D] = []
	_collect_polys(body, parts)
	for p in parts:
		if _polish_skipped(p.name):
			continue
		_outline_part(p)
		_shade_part(p)

func _collect_polys(node: Node, out: Array[Polygon2D]) -> void:
	for child in node.get_children():
		if child is Polygon2D:
			out.append(child)
		_collect_polys(child, out)

func _polish_skipped(node_name: String) -> bool:
	for tok in _POLISH_SKIP:
		if node_name.contains(tok):
			return true
	return false

func _outline_part(p: Polygon2D) -> void:
	if p.polygon.size() < 3:
		return
	var expanded := Geometry2D.offset_polygon(p.polygon, _OUTLINE_PX)
	if expanded.is_empty():
		return
	var ol := Polygon2D.new()
	ol.name = p.name + "_OL"
	ol.polygon = expanded[0]
	ol.color = _OUTLINE_COLOR
	ol.z_index = -1   # relative → drawn behind its part
	p.add_child(ol)

func _shade_part(p: Polygon2D) -> void:
	var poly := p.polygon
	if poly.size() < 3:
		return
	var ymin := poly[0].y
	var ymax := poly[0].y
	for v in poly:
		ymin = minf(ymin, v.y)
		ymax = maxf(ymax, v.y)
	if ymax - ymin < 0.5:
		return
	var base := p.color
	var vc := PackedColorArray()
	for v in poly:
		var t := inverse_lerp(ymin, ymax, v.y)   # 0 top, 1 bottom
		var f := lerpf(1.12, 0.82, t)
		vc.append(Color(base.r * f, base.g * f, base.b * f, base.a))
	p.vertex_colors = vc

func _paint_polygon_tree(node: Node, color: Color) -> void:
	if node is Polygon2D:
		(node as Polygon2D).color = color
	for child in node.get_children():
		_paint_polygon_tree(child, color)

func _hide_compatibility_nodes() -> void:
	# Paint ALL weapon geometry up front so a weapon is ready whether the
	# editor reveals it via show_* OR the in-game equipment paper-doll
	# toggles its visibility. (Before, geometry was painted only under
	# show_*, so equipped weapons were invisible in the Maw.) z is set in
	# the paint fns so paper-doll-shown weapons also sit above robes.
	_paint_spear()
	_paint_staff()
	_paint_bow()
	_paint_wand()
	for path in [
		^"Body/ArmRShoulder/ElbowPivot/SpearArm",
		^"Body/StaffArm",
		^"Body/BowArm",
		^"WandArm",
		^"Body/ArmLShoulder/ElbowPivot/Buckler",
	]:
		var n := get_node_or_null(path) as CanvasItem
		if n != null:
			n.visible = false
	if show_spear:
		_reveal(^"Body/ArmRShoulder/ElbowPivot/SpearArm")
	if show_staff:
		_reveal(^"Body/StaffArm")
	if show_bow:
		_reveal(^"Body/BowArm")
	if show_wand:
		_reveal(^"WandArm")

func _reveal(path: NodePath) -> void:
	var n := get_node_or_null(path) as Node2D
	if n != null:
		n.visible = true

# Right-hand grip in body-local space (≈ where SpearArm sits). The
# staff/bow/wand arms live under Body / root and were left at the origin
# by the reset — position them at the grip so they read as held. They
# don't reparent under the arm (the Stage-15 paper-doll references their
# scene paths), so they hold steady rather than swinging like the spear.
const _GRIP: Vector2 = Vector2(8, -23)

const _SPEAR_WOOD: Color = Color(0.46, 0.32, 0.17)
const _SPEAR_GRIP: Color = Color(0.28, 0.18, 0.10)
const _SPEAR_STEEL: Color = Color(0.72, 0.74, 0.78)

## Paint the right-hand SpearArm (Shaft/Grip/Tip) — mounted on the right
## arm so it swings with the attack. SpearArm-local: origin at the grip
## hand, shaft runs up (-y), butt hangs down (+y), blade at the top.
func _paint_spear() -> void:
	var arm := get_node_or_null(^"Body/ArmRShoulder/ElbowPivot/SpearArm") as Node2D
	if arm == null:
		return
	arm.z_index = 5   # above robe/body layers (z<=4), under glints (z6)
	_paint_weapon_part(arm, ^"Shaft", PackedVector2Array([
		Vector2(-1.0, 14), Vector2(1.0, 14), Vector2(1.0, -42), Vector2(-1.0, -42)]), _SPEAR_WOOD)
	_paint_weapon_part(arm, ^"Grip", PackedVector2Array([
		Vector2(-1.7, -1), Vector2(1.7, -1), Vector2(1.7, 4), Vector2(-1.7, 4)]), _SPEAR_GRIP)
	_paint_weapon_part(arm, ^"Tip", PackedVector2Array([
		Vector2(0, -50), Vector2(2.6, -42), Vector2(-2.6, -42)]), _SPEAR_STEEL)

func _paint_weapon_part(arm: Node2D, child: NodePath, pts: PackedVector2Array, color: Color) -> void:
	var p := arm.get_node_or_null(child) as Polygon2D
	if p == null:
		return
	p.polygon = pts
	p.color = color

func _ellipse_pts(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in 12:
		var t := TAU * i / 12
		pts.append(Vector2(c.x + rx * cos(t), c.y + ry * sin(t)))
	return pts

## Pythia oracle staff: tall wood shaft + violet orb. (Body/StaffArm)
func _paint_staff() -> void:
	var arm := get_node_or_null(^"Body/StaffArm") as Node2D
	if arm == null:
		return
	arm.position = _GRIP
	arm.z_index = 5
	_paint_weapon_part(arm, ^"Shaft", PackedVector2Array([
		Vector2(-1, 18), Vector2(1, 18), Vector2(1, -36), Vector2(-1, -36)]), Color(0.42, 0.35, 0.28))
	_paint_weapon_part(arm, ^"Grip", PackedVector2Array([
		Vector2(-1.6, -2), Vector2(1.6, -2), Vector2(1.6, 3), Vector2(-1.6, 3)]), Color(0.30, 0.24, 0.18))
	_paint_weapon_part(arm, ^"Orb", _ellipse_pts(Vector2(0, -40), 3.0, 3.2), Color(0.72, 0.50, 0.85))

## Shade-Hunter bow: dark recurve limb + pale string. (Body/BowArm)
func _paint_bow() -> void:
	var arm := get_node_or_null(^"Body/BowArm") as Node2D
	if arm == null:
		return
	arm.position = _GRIP
	arm.z_index = 5
	_paint_weapon_part(arm, ^"Bow", PackedVector2Array([
		Vector2(0, -19), Vector2(4, -10), Vector2(5, 0), Vector2(4, 10), Vector2(0, 19),
		Vector2(-1, 17), Vector2(2.6, 9), Vector2(3.4, 0), Vector2(2.6, -9), Vector2(-1, -17)]),
		Color(0.26, 0.20, 0.14))
	var bs := arm.get_node_or_null(^"Bowstring") as Line2D
	if bs != null:
		bs.points = PackedVector2Array([Vector2(0, -19), Vector2(0, 19)])
		bs.width = 0.6
		bs.default_color = Color(0.80, 0.80, 0.74)

## Ossuary wand: short bone rod + sickly-green glow. (root WandArm)
func _paint_wand() -> void:
	var arm := get_node_or_null(^"WandArm") as Node2D
	if arm == null:
		return
	arm.position = _GRIP
	arm.z_index = 5
	_paint_weapon_part(arm, ^"Shaft", PackedVector2Array([
		Vector2(-0.8, 6), Vector2(0.8, 6), Vector2(0.8, -12), Vector2(-0.8, -12)]), Color(0.80, 0.78, 0.66))
	_paint_weapon_part(arm, ^"Glow", _ellipse_pts(Vector2(0, -14), 2.2, 2.4), Color(0.50, 0.85, 0.45))

func _on_anim_started(anim_name: StringName) -> void:
	if _replaying_for_injection:
		return
	var cfg: Dictionary = _per_anim_config.get(String(anim_name), {})
	if not SpriteOverrides.is_tuned(cfg):
		return
	var lib: AnimationLibrary = _anim.get_animation_library(&"")
	if lib == null or not lib.has_animation(anim_name):
		return
	SpriteOverrides.inject_tuned_transforms(lib.get_animation(anim_name), cfg)
	_replaying_for_injection = true
	_anim.play(anim_name)
	_replaying_for_injection = false

func _build_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle", _anim_idle())
	lib.add_animation(&"walk", _anim_walk())
	lib.add_animation(&"attack", _anim_attack())
	lib.add_animation(&"cast", _anim_cast())
	lib.add_animation(&"hit", _anim_hit())
	lib.add_animation(&"die", _anim_die())
	_anim.add_animation_library(&"", lib)

const _RESET_PATHS: Array = [
	NodePath("Body:rotation"),
	NodePath("Body/LegLHip:rotation"),
	NodePath("Body/LegRHip:rotation"),
	NodePath("Body/LegLHip/KneePivot:rotation"),
	NodePath("Body/LegRHip/KneePivot:rotation"),
	NodePath("Body/ArmLShoulder:rotation"),
	NodePath("Body/ArmLShoulder/ElbowPivot:rotation"),
	NodePath("Body/ArmRShoulder:rotation"),
	NodePath("Body/ArmRShoulder/ElbowPivot:rotation"),
]

func _anim_idle() -> Animation:
	var a := Animation.new()
	a.length = 1.6
	a.loop_mode = Animation.LOOP_LINEAR
	_key_vec2(a, ^"Body:position", [0.0, 0.8, 1.6], [Vector2.ZERO, Vector2(0, -1), Vector2.ZERO])
	for path in _RESET_PATHS:
		_key_float(a, path, [0.0, 1.6], [0.0, 0.0])
	return a

func _anim_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_LINEAR
	_key_vec2(a, ^"Body:position", [0.0, 0.15, 0.3, 0.45, 0.6], [
		Vector2.ZERO, Vector2(0, -1.5), Vector2.ZERO, Vector2(0, -1.5), Vector2.ZERO])
	_key_float(a, ^"Body/LegLHip:rotation", [0.0, 0.15, 0.3, 0.45, 0.6], [0.0, -0.22, 0.0, 0.22, 0.0])
	_key_float(a, ^"Body/LegRHip:rotation", [0.0, 0.15, 0.3, 0.45, 0.6], [0.0, 0.22, 0.0, -0.22, 0.0])
	_key_float(a, ^"Body/LegLHip/KneePivot:rotation", [0.0, 0.45, 0.6], [0.0, 0.32, 0.0])
	_key_float(a, ^"Body/LegRHip/KneePivot:rotation", [0.0, 0.15, 0.6], [0.0, 0.32, 0.0])
	_key_float(a, ^"Body/ArmLShoulder:rotation", [0.0, 0.15, 0.3, 0.45, 0.6], [0.0, 0.25, 0.0, -0.25, 0.0])
	_key_float(a, ^"Body/ArmRShoulder:rotation", [0.0, 0.15, 0.3, 0.45, 0.6], [0.0, -0.25, 0.0, 0.25, 0.0])
	return a

func _anim_attack() -> Animation:
	var a := Animation.new()
	a.length = 0.38
	a.loop_mode = Animation.LOOP_NONE
	_key_float(a, ^"Body:rotation", [0.0, 0.16, 0.38], [0.0, 0.05, 0.0])
	_key_float(a, ^"Body/ArmRShoulder:rotation", [0.0, 0.12, 0.23, 0.38], [0.0, 0.35, -1.15, 0.0])
	_key_float(a, ^"Body/ArmRShoulder/ElbowPivot:rotation", [0.0, 0.23, 0.38], [0.0, -0.25, 0.0])
	_key_float(a, ^"Body/ArmLShoulder:rotation", [0.0, 0.23, 0.38], [0.0, 0.18, 0.0])
	# Weapon swings, authored ungated so they drive BOTH the editor
	# (show_*) and the in-game paper-doll weapon (which shares these arm
	# nodes). Tracks on a hidden weapon arm simply no-op.
	#   Staff: overhead chop (2a-C) — wind back, strike forward-down.
	_key_float(a, ^"Body/StaffArm:rotation", [0.0, 0.12, 0.25, 0.38], [0.0, -0.55, 1.4, 0.5])
	#   Wand: quick downward flick.
	_key_float(a, ^"WandArm:rotation", [0.0, 0.14, 0.38], [0.0, -0.7, 0.0])
	#   Spear: slight forward tilt as the arm thrusts (also keeps the
	#   SpearArm's own track alive so a hidden→shown re-equip snaps right).
	_key_float(a, ^"Body/ArmRShoulder/ElbowPivot/SpearArm:rotation", [0.0, 0.16, 0.38], [0.0, -0.3, 0.0])
	return a

func _anim_cast() -> Animation:
	var a := Animation.new()
	a.length = 0.55
	a.loop_mode = Animation.LOOP_NONE
	_key_float(a, ^"Body/ArmLShoulder:rotation", [0.0, 0.25, 0.55], [0.0, -0.72, 0.0])
	_key_float(a, ^"Body/ArmRShoulder:rotation", [0.0, 0.25, 0.55], [0.0, 0.72, 0.0])
	_key_color(a, ^".:modulate", [0.0, 0.25, 0.55], [Color.WHITE, Color(1.25, 1.25, 1.25, 1), Color.WHITE])
	return a

func _anim_hit() -> Animation:
	var a := Animation.new()
	a.length = 0.15
	a.loop_mode = Animation.LOOP_NONE
	_key_color(a, ^".:modulate", [0.0, 0.05, 0.15], [Color.WHITE, Color(1.5, 0.65, 0.65, 1), Color.WHITE])
	return a

func _anim_die() -> Animation:
	var a := Animation.new()
	a.length = 0.65
	a.loop_mode = Animation.LOOP_NONE
	_key_float(a, ^".:rotation", [0.0, 0.65], [0.0, PI / 2.0])
	_key_color(a, ^".:modulate", [0.0, 0.65], [Color.WHITE, Color(1, 1, 1, 0.25)])
	return a

func _key_float(a: Animation, path: NodePath, times: Array, values: Array) -> void:
	var t := _track(a, path)
	for i in range(times.size()):
		a.track_insert_key(t, float(times[i]), float(values[i]))

func _key_vec2(a: Animation, path: NodePath, times: Array, values: Array) -> void:
	var t := _track(a, path)
	for i in range(times.size()):
		a.track_insert_key(t, float(times[i]), values[i])

func _key_color(a: Animation, path: NodePath, times: Array, values: Array) -> void:
	var t := _track(a, path)
	for i in range(times.size()):
		a.track_insert_key(t, float(times[i]), values[i])

func _track(a: Animation, path: NodePath) -> int:
	var idx := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(idx, path)
	a.track_set_interpolation_type(idx, Animation.INTERPOLATION_CUBIC)
	return idx
