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
	# Stage 17.8 — weld every weapon onto its wielding hand BEFORE anything
	# references a weapon path (paint + animation tracks). Guarantees the
	# grip never leaves the hand in any animation (see _mount_weapons).
	_mount_weapons()
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
	_layer_free_arms()
	_build_animations()
	_per_anim_config = SpriteOverrides.load_for_class(sprite_id, stance_id)
	_anim.animation_started.connect(_on_anim_started)
	_anim.play(&"idle")
	# Bow wielder: drive the bowstring + draw-hand pin every frame.
	if _weapon_kind == WeaponRigLib.Kind.BOW:
		get_tree().process_frame.connect(_apply_bow_rig)

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
	# WeaponRig.mount has already painted + welded every weapon under the
	# right hand. Hide them all (+ the buckler); show_* / the in-game
	# paper-doll reveals the one this sprite is wielding.
	for nm in [&"SpearArm", &"StaffArm", &"WandArm", &"BowArm"]:
		var n := _weapon_arm(nm)
		if n != null:
			n.visible = false
	var buck := get_node_or_null(^"Body/ArmLShoulder/ElbowPivot/Buckler") as CanvasItem
	if buck != null:
		buck.visible = false
	if show_spear: _reveal_weapon(&"SpearArm")
	if show_staff: _reveal_weapon(&"StaffArm")
	if show_bow:   _reveal_weapon(&"BowArm")
	if show_wand:  _reveal_weapon(&"WandArm")

func _reveal_weapon(node_name: StringName) -> void:
	var n := _weapon_arm(node_name)
	if n != null:
		n.visible = true

# Free-arm parts sit ABOVE the base clothing (tunic/robe/belt at z2–3, the
# chest emblem at z4) so the arms read in front of the skin instead of
# being buried behind a robe. z4 keeps them under the head/helm (z5) and
# glints (z6); a welded weapon (z5) still draws over the gripping hand.
const _ARM_Z: int = 4
func _layer_free_arms() -> void:
	for side in ["L", "R"]:
		for path in [
			"Body/Arm%sShoulder/UpperArm", "Body/Arm%sShoulder/ShoulderSeam",
			"Body/Arm%sShoulder/ElbowPivot/Forearm", "Body/Arm%sShoulder/ElbowPivot/Hand",
		]:
			var p := get_node_or_null(NodePath(path % side)) as CanvasItem
			if p != null:
				p.z_index = _ARM_Z

# =========================================================================
# WEAPONS (Stage 17.8d) — delegated to the shared WeaponRig.
# =========================================================================
# Every weapon's geometry, grip, and attack/cast pattern lives in
# WeaponRig so ANY sprite (class, NPC, enemy) wields it identically. This
# sprite's PRIMARY weapon (its class weapon) drives the attack/cast
# pattern; all four weapon nodes the scene exposes are mounted+painted so
# the editor show_* preview and the in-game paper-doll can reveal any one.
const WeaponRigLib = preload("res://scripts/systems/weapon_rig.gd")

var _weapon_kind: int = WeaponRigLib.Kind.NONE

func _mount_weapons() -> void:
	_weapon_kind = WeaponRigLib.kind_for(sprite_id)
	for k in [WeaponRigLib.Kind.SPEAR, WeaponRigLib.Kind.STAFF,
			WeaponRigLib.Kind.WAND, WeaponRigLib.Kind.BOW]:
		WeaponRigLib.mount(self, k)

func _weapon_arm(node_name: StringName) -> Node2D:
	return get_node_or_null(NodePath("Body/ArmRShoulder/ElbowPivot/%s" % node_name)) as Node2D

# Per-frame bow string + draw-hand pin (only when a bow is the weapon).
func _apply_bow_rig() -> void:
	WeaponRigLib.process_bow(self, _anim, ik_enabled)

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
	a.loop_mode = Animation.LOOP_NONE
	if _weapon_kind == WeaponRigLib.Kind.NONE:
		# Unarmed reach: step in + jab with the right arm.
		a.length = 0.45
		_key_vec2(a, ^"Body:position", [0.0, 0.16, 0.30, 0.45],
				[Vector2.ZERO, Vector2(1.5, 0), Vector2(5, -1), Vector2.ZERO])
		_key_float(a, ^"Body:rotation", [0.0, 0.30, 0.45], [0.0, 0.06, 0.0])
		_key_float(a, ^"Body/ArmRShoulder:rotation", [0.0, 0.12, 0.30, 0.45], [0.0, 0.18, -0.6, 0.0])
		_key_float(a, ^"Body/ArmLShoulder:rotation", [0.0, 0.30, 0.45], [0.0, 0.20, 0.0])
		return a
	# Armed: the WeaponRig owns the arm + weapon strike for this kind; the
	# Body base here gives the lunge weight (a spear steps in, others lean).
	a.length = 0.6 if _weapon_kind == WeaponRigLib.Kind.BOW else 0.5
	if _weapon_kind == WeaponRigLib.Kind.SPEAR:
		_key_vec2(a, ^"Body:position", [0.0, a.length * 0.3, a.length * 0.66, a.length],
				[Vector2.ZERO, Vector2(2, 0), Vector2(5, -1), Vector2.ZERO])
	else:
		_key_float(a, ^"Body:rotation", [0.0, a.length * 0.55, a.length], [0.0, 0.05, 0.0])
	WeaponRigLib.add_attack(a, self, _weapon_kind, a.length)
	return a

func _anim_cast() -> Animation:
	var a := Animation.new()
	a.length = 0.7
	a.loop_mode = Animation.LOOP_NONE
	_key_vec2(a, ^"Body:position", [0.0, 0.35, 0.7], [Vector2.ZERO, Vector2(0, -2), Vector2.ZERO])
	_key_float(a, ^"Body:rotation", [0.0, 0.35, 0.7], [0.0, -0.04, 0.0])
	_key_color(a, ^".:modulate", [0.0, 0.32, 0.55, 0.7],
			[Color.WHITE, Color(1.25, 1.25, 1.4, 1), Color(1.25, 1.25, 1.4, 1), Color.WHITE])
	if _weapon_kind == WeaponRigLib.Kind.NONE:
		# OVERHEAD INVOCATION (unarmed): both arms raise UP-AND-OUT, never
		# inward across the torso (that buried them behind the body/skin).
		_key_float(a, ^"Body/ArmRShoulder:rotation", [0.0, 0.32, 0.5, 0.7], [0.0, -1.95, -1.95, 0.0])
		_key_float(a, ^"Body/ArmLShoulder:rotation", [0.0, 0.32, 0.5, 0.7], [0.0, 1.95, 1.95, 0.0])
		_key_float(a, ^"Body/ArmRShoulder/ElbowPivot:rotation", [0.0, 0.32, 0.7], [0.0, -0.35, 0.0])
		_key_float(a, ^"Body/ArmLShoulder/ElbowPivot:rotation", [0.0, 0.32, 0.7], [0.0, 0.35, 0.0])
	else:
		WeaponRigLib.add_cast(a, self, _weapon_kind, a.length)
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
