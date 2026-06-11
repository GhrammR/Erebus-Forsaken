extends Node2D
## Stage 17.7 — ShadeHunter, HUMAN family. Hooded bow archer.

const MotionArchetypes = preload("res://scripts/systems/motion_archetypes.gd")
const BowStances       = preload("res://scripts/systems/stances/bow_stances.gd")
const AnatomyValidator = preload("res://scripts/systems/anatomy_validator.gd")
const SpriteOverrides  = preload("res://scripts/systems/sprite_overrides.gd")
const StanceSelection  = preload("res://scripts/systems/stance_selection.gd")

# Stage 17.8 — pick a stance from the catalog. Override at runtime
# (pose_tuner sets this via set_meta(&"stance_id", ...) before _ready
# of a freshly-instanced sprite).
@export var stance_id: StringName = &"forward_high_ready"

# Stage 17.8 — when false, runtime IK pin pass is skipped so the user
# can manually rotate shoulders/elbows via pose_tuner sliders without
# having the IK stomp them every frame. Production sprites leave this
# true; pose_tuner flips it for manual tuning.
@export var ik_enabled: bool = true

# Stage 17.8 — toggle for "bow on back / no bow" stances. False hides
# the entire BowArm subtree at _ready and skips L→Nock pinning so the
# off hand hangs free. Used by pose_tuner's `*_bare` variants.
@export var show_bow: bool = true
##
## Default-facing: RIGHT. Player flips $SpriteAnchor.scale.x to face left.
##
## Pivots:
##   - Each leg: hip + knee
##   - Each arm: shoulder + elbow
##   - BowArm: sibling subtree under Body. Anchored at body-local (8,-36)
##     where the bow's riser (centre grip) sits.
##
## Patterns ported from Pythia + Stage 17.7 infra:
##   1. HumanRig anatomy with cloak draped before arms
##   2. Marker-based dual IK pinning via HumanRig.apply_pins:
##        L hand → BowArm/RiserMarker (constant)
##        R hand → BowArm/NockMarker  (animated during draw)
##   3. Motion archetypes via MotionArchetypes.add_charge_release for
##      the bow draw; idle/walk are body bobs + breath holds.
##   4. Bowstring is a Line2D rebuilt every frame from BowTipTop →
##      NockMarker → BowTipBot so the string follows the nock during
##      the draw without per-frame keyframe authoring.
##   5. z_index = 2 on BowArm so equipment overlays don't eat the bow.

const SKIN: Color           = Color(0.78, 0.62, 0.50)
const SKIN_SHADOW: Color    = Color(0.54, 0.40, 0.30)
const CHARCOAL: Color       = Color(0.20, 0.20, 0.24)
const CHARCOAL_DARK: Color  = Color(0.10, 0.10, 0.14)
const CLOAK_COLOR: Color    = Color(0.16, 0.18, 0.22)
const HOOD_COLOR: Color     = Color(0.10, 0.12, 0.16)
const PALE_TEAL: Color      = Color(0.55, 0.78, 0.80)
const BOW_WOOD: Color       = Color(0.62, 0.46, 0.28)   # lighter so it pops vs cloak
const BOW_WOOD_DARK: Color  = Color(0.30, 0.20, 0.10)
const BOW_HIGHLIGHT: Color  = Color(0.82, 0.66, 0.42)
const SHADOW: Color         = Color(0.0, 0.0, 0.05, 0.45)

# Bow geometry (bow-local space — origin at riser).
const BOW_LIMB_HALF: float = 17.0    # top tip y = -17, bottom tip y = +17
const BOW_DEPTH: float     = 5.5     # how far the limbs curve forward (+x)
const BOW_THICKNESS: float = 1.6     # radial half-thickness of the limb strip
const BOW_GRIP_HALF: float = 5.0     # vertical extent of the grip wrap

# Per-stance values loaded at _ready from BowStances. Defaults match
# forward_high_ready so the catalog is purely additive.
var _nock_rest: Vector2  = Vector2(-12, 0)
var _nock_drawn: Vector2 = Vector2(-19, 0)
var _attack_len: float   = 0.9
var _draw_frac: float    = 0.30
var _release_frac: float = 0.75

# Animation tuning.
const IDLE_LEN: float    = 1.6
const WALK_LEN: float    = 0.45

# Stage 17.8 — per-stance attack action descriptor (see bow_stances.gd).
var _attack_action: Dictionary = {}

@onready var _shadow: Polygon2D = $Shadow
@onready var _body: Node2D = $Body
@onready var _cloak: Polygon2D = $Body/Cloak
@onready var _hood: Polygon2D = $Body/Hood
@onready var _bow_arm: Node2D = $Body/BowArm
@onready var _bow: Polygon2D = $Body/BowArm/Bow
@onready var _bowstring: Line2D = $Body/BowArm/Bowstring
@onready var _nock_marker: Marker2D = $Body/BowArm/NockMarker
@onready var _bow_tip_top: Marker2D = $Body/BowArm/BowTipTop
@onready var _bow_tip_bot: Marker2D = $Body/BowArm/BowTipBot
@onready var _anim: AnimationPlayer = $AnimationPlayer

# Stage 17.8 — PIN_TABLE is now BUILT per-stance from BowStances data.
# `draw_hand` in the stance row determines:
#   "left"  → R hand on riser, L hand on nock
#   "right" → L hand on riser, R hand on nock
# Built once in _ready before connecting the pin pass.
var PIN_TABLE: Array = []

# Path to the shoulder of the DRAWING arm — used by _anim_attack to
# bias the IK seed during the draw. Set by _build_pin_table().
var _draw_shoulder_path: NodePath = ^"Body/ArmLShoulder"

func _ready() -> void:
	# Stage 17.8 — apply the selected stance from the catalog before
	# painting. BowArm position + nock travel come from data. Dev editor
	# selections are soft: bad/missing data falls back to stance_id.
	stance_id = StanceSelection.selected_for_class(&"shade_hunter", stance_id, BowStances.all_ids())
	var stance: Dictionary = BowStances.get_stance(stance_id)
	_bow_arm.position = stance["bow_arm_pos"]
	_bow_arm.rotation = stance["bow_arm_rot"]
	_nock_rest = stance["nock_rest"]
	_nock_drawn = stance["nock_drawn"]
	_attack_len = stance["attack_len"]
	_draw_frac = stance["draw_frac"]
	_release_frac = stance["release_frac"]
	# Action descriptor (overrides timing if present).
	_attack_action = stance.get("attack", {})
	if not _attack_action.is_empty():
		_attack_len = float(_attack_action.get("length", _attack_len))
		_draw_frac = float(_attack_action.get("draw_frac", _draw_frac))
		_release_frac = float(_attack_action.get("release_frac", _release_frac))
	# Recommended-stance overrides: if the user has tuned this stance
	# in pose_tuner and pressed S, tmp/recommended_stances.json contains
	# their numeric overrides. BEGIN snapshot -> bow placement + nock_rest;
	# MIDDLE snapshot -> nock_drawn. Layered on top of the catalog so
	# absent fields fall through to defaults.
	_apply_recommended_overrides()
	_nock_marker.position = _nock_rest
	# Build PIN_TABLE based on stance's draw_hand. Must run before the
	# pin pass connects (and before validator scans).
	_build_pin_table(stance.get("draw_hand", "left"))
	_shadow.color = SHADOW
	_shadow.polygon = HumanRig.shadow_poly()
	HumanRig.apply(_body, SKIN, SKIN_SHADOW)
	HumanRig.paint_face(_body, PALE_TEAL, CHARCOAL_DARK)
	_paint_shadowed_face()
	_paint_cloak()
	_paint_hood()
	_paint_bow()
	_build_animations()
	# Stage 17.8 — bare/equipped toggle. When show_bow is false the
	# whole bow subtree is hidden and the dual-pin table is replaced
	# with a no-op so the off hand isn't forced onto a hidden marker.
	if not show_bow:
		_bow_arm.visible = false
	# PROACTIVELY rebuild EVERY tuned animation before first play.
	# AnimationPlayer locks the Animation reference when play() starts;
	# rebuilding inside _on_anim_started after the fact doesn't change
	# what's actually running. Doing it upfront means the first play()
	# already picks up the fresh, tuned-track-injected version.
	for anim_name in _tuned_anims:
		_rebuild_animation(anim_name)
	# Re-run config swap on every animation change so newly-installed
	# variants (none for ShadeHunter today, but mirrors the pattern
	# Pythia/Myrmidon use for WeaponProfiles installs) pick up tuning.
	_anim.animation_started.connect(_on_anim_started)
	_anim.play(&"idle")
	# Pin both arms to the bow every frame (after AnimationPlayer
	# advances the nock track).
	get_tree().process_frame.connect(_apply_pins_and_string)

## Per-variant cache populated from recommended_stances.json. Each
## entry holds the bow placement + nock positions for one animation
## (idle/walk/attack). On animation_started we apply the matching
## entry so each anim renders with its tuned pose.
var _per_anim_config: Dictionary = {}   # anim_name → { bow_pos, bow_rot, nock_rest, nock_drawn, ... }
# Set of anim names where the user saved explicit joint rotations.
# _apply_pins_and_string skips the IK pin pass for these so the
# tuned rotations stick through play instead of being recomputed
# from marker positions every frame.
var _tuned_anims: Dictionary = {}
# Guard to prevent infinite recursion when we re-call play() after
# rebuilding the animation in _on_anim_started.
var _replaying_for_injection: bool = false

## Layer user-tuned overrides from tmp/recommended_stances.json on top
## of the catalog defaults. Two schemas supported:
##   New (per-variant):
##     classes[class][stance][anim_name][phase] = { weapon_arm_pos, ... }
##   Legacy (no anim layer, single REST/STRIKE pair):
##     classes[class][stance][phase] = { ... }
##   Legacy data is treated as applying to all variants.
func _apply_recommended_overrides() -> void:
	var f := FileAccess.open("res://tmp/recommended_stances.json", FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var classes: Dictionary = parsed
	var by_stance: Dictionary = classes.get("shade_hunter", {}).get(String(stance_id), {})
	if by_stance.is_empty():
		return
	# Schema can be mixed: keys at this level are either phase names
	# (REST/STRIKE/... — legacy flat) OR anim names (idle/walk/attack
	# — new per-variant schema). Split them and load both.
	var phase_keys: PackedStringArray = [
		"REST", "STRIKE", "CHARGE", "RECOVERY",
		"BEGIN", "MIDDLE", "END",
	]
	var legacy_phases: Dictionary = {}
	var anim_blocks: Dictionary = {}
	for k in by_stance.keys():
		var ks: String = String(k)
		if phase_keys.has(ks):
			legacy_phases[ks] = by_stance[k]
		else:
			anim_blocks[ks] = by_stance[k]
	if not legacy_phases.is_empty():
		_load_anim_config("global", legacy_phases)
		for legacy_anim in ["idle", "walk", "attack", "cast"]:
			if not anim_blocks.has(legacy_anim):
				_load_anim_config(legacy_anim, legacy_phases)
	for anim_name in anim_blocks:
		_load_anim_config(String(anim_name), anim_blocks[anim_name])
	# Apply the FIRST available config so initial render uses tuned
	# values. Prefer current_animation > attack > idle > walk > global.
	for preferred in ["attack", "idle", "walk", "global"]:
		if _per_anim_config.has(preferred):
			_apply_anim_config(preferred)
			break
	print("[shade_hunter] recommended overrides loaded for stance=%s (anims=%s)" % [
		stance_id, _per_anim_config.keys()])

# Build the per-frame pin table based on which hand draws the string.
# bow_hand grips the riser (constant pin), draw_hand pins to the nock
# only during attack (idle/walk leave that arm free).
func _build_pin_table(draw_hand: String) -> void:
	var bow_shoulder: NodePath
	var draw_shoulder: NodePath
	var bow_elbow_dir: int
	var draw_elbow_dir: int
	if draw_hand == "right":
		bow_shoulder = ^"Body/ArmLShoulder"
		draw_shoulder = ^"Body/ArmRShoulder"
		bow_elbow_dir = -1
		draw_elbow_dir = +1
	else:  # "left" (default)
		bow_shoulder = ^"Body/ArmRShoulder"
		draw_shoulder = ^"Body/ArmLShoulder"
		bow_elbow_dir = +1
		draw_elbow_dir = -1
	PIN_TABLE = [
		{
			"shoulder":   bow_shoulder,
			"target":     ^"Body/BowArm/RiserMarker",
			"elbow_dir":  bow_elbow_dir,
			"skip_anims": [],
		},
		{
			"shoulder":   draw_shoulder,
			"target":     ^"Body/BowArm/NockMarker",
			"elbow_dir":  draw_elbow_dir,
			"skip_anims": [&"idle", &"walk"],
		},
	]
	_draw_shoulder_path = draw_shoulder

# Resolve the active preset's snap for a given phase. If the phase
# value is the new {presets: {...}, active: ...} bucket, dereference
# to the active preset. Otherwise treat the value as a flat snap (old
# schema written before Stage 17.8 presets).
static func _resolve_phase(phase_value: Variant) -> Dictionary:
	if typeof(phase_value) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = phase_value
	if d.has("presets"):
		var active: String = String(d.get("active", ""))
		var presets: Dictionary = d.get("presets", {})
		if presets.has(active):
			return presets[active]
		# Fall back to last preset by key order.
		if presets.size() > 0:
			return presets.values()[presets.size() - 1]
		return {}
	return d

func _load_anim_config(anim_name: String, phases: Dictionary) -> void:
	var cfg: Dictionary = _per_anim_config.get(anim_name, {})
	# BEGIN supersedes REST; MIDDLE supersedes STRIKE; END is new.
	# Falls back through both aliases so legacy saves still load.
	var rest: Dictionary = _resolve_phase(
		phases.get("BEGIN", phases.get("REST", {})))
	var strike: Dictionary = _resolve_phase(
		phases.get("MIDDLE", phases.get("STRIKE", {})))
	var ending: Dictionary = _resolve_phase(
		phases.get("END", phases.get("REST", rest)))
	# Rotations / positions / markers — full per-phase capture.
	if rest.has("rotations"):    cfg["rest_rotations"] = rest["rotations"]
	if rest.has("positions"):    cfg["rest_positions"] = rest["positions"]
	if rest.has("scales"):       cfg["rest_scales"] = rest["scales"]
	if rest.has("markers"):      cfg["rest_markers"] = rest["markers"]
	if strike.has("rotations"):  cfg["strike_rotations"] = strike["rotations"]
	if strike.has("positions"):  cfg["strike_positions"] = strike["positions"]
	if strike.has("scales"):     cfg["strike_scales"] = strike["scales"]
	if strike.has("markers"):    cfg["strike_markers"] = strike["markers"]
	if ending.has("rotations"):  cfg["end_rotations"] = ending["rotations"]
	if ending.has("scales"):     cfg["end_scales"] = ending["scales"]
	# Legacy / flat fields — still honored for backward compat.
	if rest.has("weapon_arm_pos"):
		var p: Array = rest["weapon_arm_pos"]
		cfg["bow_pos"] = Vector2(float(p[0]), float(p[1]))
	if rest.has("weapon_arm_rot"):
		cfg["bow_rot"] = float(rest["weapon_arm_rot"])
	if rest.has("NockMarker"):
		var nm: Array = rest["NockMarker"]
		cfg["nock_rest"] = Vector2(float(nm[0]), float(nm[1]))
	if strike.has("NockMarker"):
		var nd: Array = strike["NockMarker"]
		cfg["nock_drawn"] = Vector2(float(nd[0]), float(nd[1]))
	# Tag as tuned if ANY phase has rotation data.
	if rest.has("rotations") or strike.has("rotations") or ending.has("rotations") \
			or rest.has("scales") or strike.has("scales") or ending.has("scales"):
		_tuned_anims[anim_name] = true
	_per_anim_config[anim_name] = cfg

# Animation-start hook — switch to the variant's tuned bow placement
# and rebuild the animation so its nock track uses the variant-
# specific rest position. Critical: AnimationPlayer locks the
# Animation reference at play() time, so editing the library entry
# after animation_started has fired has no effect on the running
# animation. We MUST re-call play() with the fresh reference.
# `_replaying_for_injection` breaks the would-be recursion.
func _on_anim_started(anim_name: StringName) -> void:
	if _replaying_for_injection:
		return
	var key: String = String(anim_name)
	if not _per_anim_config.has(key):
		return
	_apply_anim_config(key)
	_rebuild_animation(anim_name)
	# Restart so the player picks up the freshly-rebuilt anim with the
	# injected rotation tracks. Without this, the OLD pre-tuned anim
	# keeps playing for the rest of the cycle.
	_replaying_for_injection = true
	_anim.play(anim_name)
	_replaying_for_injection = false

# Replace a single named animation in the library with a fresh build
# that uses the current _nock_rest / _nock_drawn / timing values.
func _rebuild_animation(anim_name: StringName) -> void:
	var lib: AnimationLibrary = _anim.get_animation_library(&"")
	if lib == null:
		return
	var fresh: Animation = null
	match anim_name:
		&"idle":   fresh = _anim_idle()
		&"walk":   fresh = _anim_walk()
		&"attack": fresh = _anim_attack()
		&"cast":   fresh = _anim_attack()
	if fresh == null:
		return
	_inject_tuned_rotations(fresh, anim_name)
	if lib.has_animation(anim_name):
		lib.remove_animation(anim_name)
	lib.add_animation(anim_name, fresh)

# Delegate to the shared helper. Critical: SpriteOverrides.inject
# REMOVES any existing track on the same property path BEFORE adding
# the tuned-rotation track. Without that, the catalog
# charge_release's shoulder-rotation track collides with our tuned
# track on the same path and the player picks one nondeterministically.
func _inject_tuned_rotations(anim: Animation, anim_name: StringName) -> void:
	var cfg: Dictionary = _per_anim_config.get(String(anim_name), {})
	# Only strike-key the attack anim — idle/walk just hold rest.
	var df: float = _draw_frac if anim_name == &"attack" else 0.5
	var rf: float = _release_frac if anim_name == &"attack" else 0.5
	SpriteOverrides.inject_tuned_rotations(anim, cfg, df, rf)

func _apply_anim_config(anim_name: String) -> void:
	var cfg: Dictionary = _per_anim_config.get(anim_name, {})
	if cfg.is_empty():
		return
	if cfg.has("bow_pos"):
		_bow_arm.position = cfg["bow_pos"]
	if cfg.has("bow_rot"):
		_bow_arm.rotation = cfg["bow_rot"]
	if cfg.has("nock_rest"):
		_nock_rest = cfg["nock_rest"]
		_nock_marker.position = _nock_rest
	if cfg.has("nock_drawn"):
		_nock_drawn = cfg["nock_drawn"]
	# Apply tuned shoulder/elbow rotations + any non-weapon-arm
	# positions. Path keys are sprite-root-relative.
	if cfg.has("rest_rotations"):
		for path in cfg["rest_rotations"]:
			var n: Node2D = get_node_or_null(NodePath(String(path))) as Node2D
			if n != null:
				n.rotation = float(cfg["rest_rotations"][path])
	if cfg.has("rest_positions"):
		for path in cfg["rest_positions"]:
			var n: Node2D = get_node_or_null(NodePath(String(path))) as Node2D
			if n != null:
				var v: Array = cfg["rest_positions"][path]
				n.position = Vector2(float(v[0]), float(v[1]))
	if cfg.has("rest_scales"):
		for path in cfg["rest_scales"]:
			var n: Node2D = get_node_or_null(NodePath(String(path))) as Node2D
			if n != null:
				var v: Array = cfg["rest_scales"][path]
				n.scale = Vector2(float(v[0]), float(v[1]))
	if cfg.has("rest_markers"):
		for marker_name in cfg["rest_markers"]:
			var m: Node2D = _bow_arm.get_node_or_null(NodePath(String(marker_name))) as Node2D
			if m != null:
				var v2: Array = cfg["rest_markers"][marker_name]
				m.position = Vector2(float(v2[0]), float(v2[1]))

# ---- Runtime IK + bowstring ---------------------------------------------

func _apply_pins_and_string() -> void:
	# IK runs ONLY when:
	#   - sprite has a weapon visible (show_bow)
	#   - IK isn't manually disabled (ik_enabled)
	#   - an anim is currently playing (current_animation != "")
	#   - that anim isn't in _tuned_anims
	# The previous version forgot the "anim is playing" check, so once
	# a non-loop attack ended, current_animation cleared to "" and IK
	# resumed dragging joints toward their marker pin targets — that's
	# why the elbow drifted back at the tail of the animation.
	if not show_bow or not ik_enabled:
		pass
	else:
		var cur: String = String(_anim.current_animation)
		if cur != "" and not _tuned_anims.has(cur):
			HumanRig.apply_pins(self, _body, PIN_TABLE, _anim.current_animation)
	# Rebuild the bowstring as [top tip → nock → bottom tip] in bow-local
	# coords. Line2D inherits the parent's transform so we keep things
	# in bow-local space for simplicity.
	if _bowstring != null and _nock_marker != null:
		_bowstring.points = PackedVector2Array([
			_bow_tip_top.position,
			_nock_marker.position,
			_bow_tip_bot.position,
		])

# ---- Cloak / hood -------------------------------------------------------

func _paint_shadowed_face() -> void:
	var face := _body.get_node_or_null(^"Face") as Node2D
	if face == null:
		return
	face.z_index = 3
	_hood.z_index = 2
	var shadow := face.get_node_or_null(^"FaceShadow") as Polygon2D
	if shadow == null:
		shadow = Polygon2D.new()
		shadow.name = "FaceShadow"
		face.add_child(shadow)
		face.move_child(shadow, 0)
	shadow.color = Color(0.015, 0.018, 0.026, 0.96)
	shadow.polygon = PackedVector2Array([
		Vector2(-5.6, HumanRig.HEAD_TOP + 3.0),
		Vector2(5.6, HumanRig.HEAD_TOP + 3.0),
		Vector2(4.4, HumanRig.NECK_BOTTOM - 1.0),
		Vector2(-4.4, HumanRig.NECK_BOTTOM - 1.0),
	])
	var socket_l := face.get_node_or_null(^"EyeSocketL") as Polygon2D
	var socket_r := face.get_node_or_null(^"EyeSocketR") as Polygon2D
	var eye_l := face.get_node_or_null(^"EyeL") as Polygon2D
	var eye_r := face.get_node_or_null(^"EyeR") as Polygon2D
	if socket_l != null:
		socket_l.color = Color(0.0, 0.0, 0.0, 0.92)
		socket_l.polygon = _small_ellipse(Vector2(-2.4, HumanRig.HEAD_MID), 1.7, 1.0)
	if socket_r != null:
		socket_r.color = Color(0.0, 0.0, 0.0, 0.92)
		socket_r.polygon = _small_ellipse(Vector2(2.4, HumanRig.HEAD_MID), 1.7, 1.0)
	if eye_l != null:
		eye_l.color = Color(0.42, 0.92, 0.95, 1.0)
		eye_l.polygon = _small_ellipse(Vector2(-2.4, HumanRig.HEAD_MID), 0.7, 0.45)
	if eye_r != null:
		eye_r.color = Color(0.42, 0.92, 0.95, 1.0)
		eye_r.polygon = _small_ellipse(Vector2(2.4, HumanRig.HEAD_MID), 0.7, 0.45)
	var brow := face.get_node_or_null(^"Brow") as Polygon2D
	if brow != null:
		brow.color = Color(0.0, 0.0, 0.0, 0.9)
		brow.polygon = PackedVector2Array([
			Vector2(-5.0, HumanRig.HEAD_MID - 2.4), Vector2(5.0, HumanRig.HEAD_MID - 2.4),
			Vector2(4.4, HumanRig.HEAD_MID - 1.3), Vector2(-4.4, HumanRig.HEAD_MID - 1.3),
		])

func _small_ellipse(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	for i in 10:
		var t := TAU * i / 10
		pts.append(Vector2(c.x + rx * cos(t), c.y + ry * sin(t)))
	return pts

func _paint_cloak() -> void:
	# Cloak drapes from shoulders to mid-calf behind the body. Slight
	# A-line silhouette so it reads as fabric, not a slab.
	_cloak.color = CLOAK_COLOR
	_cloak.polygon = PackedVector2Array([
		Vector2(-11.0, HumanRig.SHOULDERS + 1),
		Vector2( 11.0, HumanRig.SHOULDERS + 1),
		Vector2( 13.0, HumanRig.WAIST),
		Vector2( 14.0, HumanRig.HIPS + 6),
		Vector2(  6.0, HumanRig.KNEES + 2),
		Vector2( -6.0, HumanRig.KNEES + 2),
		Vector2(-14.0, HumanRig.HIPS + 6),
		Vector2(-13.0, HumanRig.WAIST),
	])

func _paint_hood() -> void:
	# Hood pulls forward over the brow — leaves the eyes in shadow.
	_hood.color = HOOD_COLOR
	_hood.polygon = PackedVector2Array([
		Vector2(-7.0, HumanRig.NECK_BOTTOM),
		Vector2( 7.0, HumanRig.NECK_BOTTOM),
		Vector2( 8.0, HumanRig.HEAD_TOP + 6),
		Vector2( 5.0, HumanRig.HEAD_TOP - 1),
		Vector2(-5.0, HumanRig.HEAD_TOP - 1),
		Vector2(-8.0, HumanRig.HEAD_TOP + 6),
	])

# ---- Bow + bowstring ----------------------------------------------------

func _paint_bow() -> void:
	# C-curve recurve bow: a vertical arc with the limbs curving forward
	# (+x in bow-local). Use a thin spline traced twice (outer + inner)
	# to give the bow a wood-grain thickness.
	var outer: PackedVector2Array = []
	var inner: PackedVector2Array = []
	var samples := 14
	for i in samples + 1:
		var t: float = float(i) / float(samples)  # 0..1
		var y: float = lerp(-BOW_LIMB_HALF, BOW_LIMB_HALF, t)
		# Bell curve forward bend — max at y=0 (riser), tapers to 0 at tips.
		var bend: float = BOW_DEPTH * (1.0 - pow(abs(y) / BOW_LIMB_HALF, 1.4))
		outer.append(Vector2(bend + BOW_THICKNESS, y))
		inner.append(Vector2(bend - BOW_THICKNESS, y))
	# Close as a strip: outer forward, then inner backward.
	var pts: PackedVector2Array = []
	pts.append_array(outer)
	for i in range(inner.size() - 1, -1, -1):
		pts.append(inner[i])
	_bow.color = BOW_WOOD
	_bow.polygon = pts
	# Bowstring initial points so the first rendered frame isn't empty.
	_bowstring.points = PackedVector2Array([
		_bow_tip_top.position,
		_nock_marker.position,
		_bow_tip_bot.position,
	])

# =========================================================================
# ANIMATIONS — composed from MotionArchetypes helpers.
# =========================================================================

func _build_animations() -> void:
	var lib := AnimationLibrary.new()
	lib.add_animation(&"idle",   _anim_idle())
	lib.add_animation(&"walk",   _anim_walk())
	lib.add_animation(&"attack", _anim_attack())
	lib.add_animation(&"cast",   _anim_attack())   # cast aliases attack
	lib.add_animation(&"hit",    _anim_hit())
	lib.add_animation(&"die",    _anim_die())
	_anim.add_animation_library(&"", lib)

func _anim_idle() -> Animation:
	var a := MotionArchetypes.make_anim(IDLE_LEN, Animation.LOOP_LINEAR)
	MotionArchetypes.add_body_bob(a, ^"Body", 1.0, IDLE_LEN)
	# Nock is held at rest — explicit hold so any prior animation's
	# residual nock translation is overridden the moment idle starts.
	MotionArchetypes.add_hold(a, ^"Body/BowArm/NockMarker:position", _nock_rest)
	return a

func _anim_walk() -> Animation:
	var a := MotionArchetypes.make_anim(WALK_LEN, Animation.LOOP_LINEAR)
	MotionArchetypes.add_body_bob(a, ^"Body", 2.0, WALK_LEN)
	MotionArchetypes.add_hold(a, ^"Body/BowArm/NockMarker:position", _nock_rest)
	# Simple opposing leg swing — front leg forward in first half, back in second.
	MotionArchetypes.add_value_track(a, ^"Body/LegLHip:rotation", [
		[0.0, 0.20], [WALK_LEN * 0.5, -0.20], [WALK_LEN, 0.20],
	])
	MotionArchetypes.add_value_track(a, ^"Body/LegRHip:rotation", [
		[0.0, -0.20], [WALK_LEN * 0.5, 0.20], [WALK_LEN, -0.20],
	])
	return a

func _anim_attack() -> Animation:
	# Dispatch on stance.attack.motion. Currently only charge_release
	# is wired for bow; future archetypes (snap_release, burst_volley,
	# overhand_loose) plug in here without changing the sprite.
	var motion: String = String(_attack_action.get("motion", "charge_release"))
	var a := MotionArchetypes.make_anim(_attack_len, Animation.LOOP_NONE)
	# Shoulder-seed hint defaults to [0.0, -0.6] if the stance doesn't
	# specify. Hint biases the IK starting pose during the draw.
	var seed: Array = _attack_action.get("shoulder_seed", [0.0, -0.6])
	var seed_rest: float = float(seed[0]) if seed.size() > 0 else 0.0
	var seed_drawn: float = float(seed[1]) if seed.size() > 1 else -0.6
	match motion:
		"charge_release", _:
			MotionArchetypes.add_charge_release(a,
				^"Body/BowArm/NockMarker:position",
				_draw_shoulder_path,
				_nock_rest, _nock_drawn,
				seed_rest, seed_drawn,
				_attack_len,
				_draw_frac, _release_frac,
			)
	# Subtle body lean back during draw — sells the tension.
	MotionArchetypes.add_value_track(a, ^"Body:position", [
		[0.0,                       Vector2.ZERO],
		[_attack_len * _draw_frac,  Vector2(-1, 0)],
		[_attack_len * _release_frac, Vector2(-1, 0)],
		[_attack_len,               Vector2.ZERO],
	])
	return a

func _anim_hit() -> Animation:
	var a := MotionArchetypes.make_anim(0.15, Animation.LOOP_NONE)
	MotionArchetypes.add_value_track(a, ^".:modulate", [
		[0.0,  Color(1, 1, 1, 1)],
		[0.05, Color(1.6, 0.4, 0.4, 1)],
		[0.15, Color(1, 1, 1, 1)],
	], Animation.INTERPOLATION_LINEAR)
	return a

func _anim_die() -> Animation:
	var a := MotionArchetypes.make_anim(0.6, Animation.LOOP_NONE)
	MotionArchetypes.add_value_track(a, ^".:rotation", [
		[0.0, 0.0], [0.6, PI / 2.0],
	], Animation.INTERPOLATION_LINEAR)
	MotionArchetypes.add_value_track(a, ^".:modulate", [
		[0.0, Color(1, 1, 1, 1)],
		[0.6, Color(1, 1, 1, 0.3)],
	], Animation.INTERPOLATION_LINEAR)
	return a
