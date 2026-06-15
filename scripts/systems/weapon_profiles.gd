extends Node
## Stage 17.5 — weapon-attack profile registry.
##
## A profile knows how a weapon type strikes: it builds the `attack`
## Animation for the sprite's AnimationPlayer based on whether a
## shield is equipped. EquipmentPaperdoll calls `install(...)` on
## every weapon or offhand equip/unequip so the next attack uses
## the right animation.
##
## All HUMAN-family sprites are expected to expose:
##   Body, Body/ArmLShoulder, Body/ArmLShoulder/ElbowPivot,
##   Body/ArmRShoulder, Body/ArmRShoulder/ElbowPivot, SpearArm.
## Profiles author tracks against those paths. Sprites that don't
## have one of these nodes silently skip the corresponding track at
## runtime (Godot logs a one-time warning).

## Default attack length (fall back when no profile is installed).
const DEFAULT_LEN: float = 0.4

## Install the attack animation for `sprite_root` based on the
## currently-equipped weapon + offhand items. Replaces the sprite's
## existing "attack" animation in-place; AnimationPlayer keeps any
## currently-playing track.
## Names of every animation the install pipeline can touch. Snapshot
## taken on first install covers exactly these — anything outside
## (hit, die) is left alone.
const _MANAGED_ANIMS: Array = [&"idle", &"walk", &"attack", &"cast"]

func install(sprite_root: Node2D, weapon_item: ItemData, offhand_item: ItemData) -> void:
	if sprite_root == null:
		return
	var anim: AnimationPlayer = sprite_root.get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if anim == null:
		return
	var lib: AnimationLibrary = anim.get_animation_library(&"")
	if lib == null:
		return
	# Sprites with a built-in weapon (ShadeHunter's welded bow) author
	# their own idle/walk/attack — WeaponProfiles must NOT overwrite
	# those with the unarmed fallback when no weapon item is equipped.
	# Once a bow item exists in Act 1 inventory this guard can drop in
	# favor of a real BOW profile branch.
	if weapon_item == null and _has_builtin_weapon(sprite_root):
		return
	# A sprite with a built-in offhand (Myrmidon's buckler is welded
	# to the left forearm) ALWAYS attacks with shield-guard posture,
	# even with the OFFHAND slot empty. Otherwise the no-shield
	# two-handed thrust runs while the buckler visibly raises on its
	# own, which reads as the shield "swinging" with the strike.
	var has_shield := _is_shield(offhand_item) or _has_builtin_shield(sprite_root)
	var weapon_type := ItemData.WeaponType.NONE
	if weapon_item != null:
		weapon_type = weapon_item.weapon_type
	# Snapshot the bare-hands managed anims on first install so we can
	# restore them when a weapon's profile doesn't override them
	# (e.g. spear replaces only attack — idle/walk/cast restore from
	# snapshot). Pythia's staff replaces all four since the two-handed
	# grip pose has to hold across every state.
	if not sprite_root.has_meta(&"wp_bare_snapshot"):
		var snap: Dictionary = {}
		for n in _MANAGED_ANIMS:
			if lib.has_animation(n):
				snap[n] = lib.get_animation(n)
		sprite_root.set_meta(&"wp_bare_snapshot", snap)
	var snapshot: Dictionary = sprite_root.get_meta(&"wp_bare_snapshot", {})
	var to_install: Dictionary = _build_weapon_anims(sprite_root, weapon_type, has_shield)
	# Restore from snapshot for any managed anim the weapon profile
	# didn't author. Without this, unequipping a staff would leave
	# Pythia frozen in the two-handed grip pose forever.
	for n in _MANAGED_ANIMS:
		if not to_install.has(n) and snapshot.has(n):
			to_install[n] = snapshot[n]
	for n in to_install:
		if lib.has_animation(n):
			lib.remove_animation(n)
		lib.add_animation(n, to_install[n])

## Returns the dictionary of animations this weapon profile authors.
## Only managed anims included; any name omitted is restored from the
## bare-hands snapshot by install().
func _build_weapon_anims(sprite_root: Node2D, weapon_type: int, has_shield: bool) -> Dictionary:
	match weapon_type:
		# SIMPLE ONE-HAND HOLDS (2026-06-15): spear/staff/wand are now
		# held in one hand and animated by the baseline sprite itself
		# (the weapon arm is painted + positioned at the grip, and the
		# baseline idle/walk/attack/cast drive its swing). Returning {}
		# tells install() to restore the baseline anims from the snapshot
		# instead of imposing the old two-handed WeaponProfiles grip — so
		# the in-game weapon matches the editor one-hand hold.
		ItemData.WeaponType.SPEAR, \
		ItemData.WeaponType.STAFF, \
		ItemData.WeaponType.WAND:
			return {}
		ItemData.WeaponType.BOW, \
		ItemData.WeaponType.NONE:
			return { &"attack": _build_unarmed_fallback() }
	return { &"attack": _build_unarmed_fallback() }

## True if the sprite has a class-baked weapon graphic + animations
## that the profile system shouldn't stomp. ShadeHunter's bow is the
## current example — the BowArm subtree is always present and the
## sprite's own attack drives the draw via NockMarker translation.
static func _has_builtin_weapon(sprite_root: Node) -> bool:
	return sprite_root.has_node(^"Body/BowArm")

static func _has_builtin_shield(sprite_root: Node) -> bool:
	# Mirrors EquipmentVisuals.BUILTIN_OFFHAND — kept inline so the
	# profile registry doesn't need to depend on the visuals autoload.
	return sprite_root.has_node(^"Body/ArmLShoulder/ElbowPivot/Buckler")

## Heuristic for now: any item in the OFFHAND slot whose name or
## display includes "shield"/"buckler" counts as a shield. Buckler
## is the Myrmidon starter so this catches it. Future shields will
## get an explicit `offhand_type` field.
static func _is_shield(item: ItemData) -> bool:
	if item == null:
		return false
	if item.slot != EquipmentSlot.Slot.OFFHAND:
		return false
	var n := String(item.id).to_lower()
	if n.contains("shield") or n.contains("buckler"):
		return true
	var d := item.display_name.to_lower()
	return d.contains("shield") or d.contains("buckler")

# =========================================================================
# SPEAR profile (Myrmidon)
# =========================================================================
# With shield: weight shifts back, right arm cocks spear back, left
# arm raises shield forward. Then weight forward, right arm thrusts
# spear forward; shield holds raised. Recovery back to rest.
# Without shield: left hand crosses to grip the shaft (rotates
# inward + downward), both arms thrust forward together.

func _build_spear(sprite_root: Node2D, has_shield: bool) -> Animation:
	# HIP-LEVEL ARM-THRUST (Stage 17.5 follow-up).
	#
	# The spear is gripped at the back of the shaft by the right hand
	# (Body/ArmRShoulder/ElbowPivot/SpearArm, hand-local origin). At
	# rest the arm hangs straight down with the hand at hip level
	# (body y≈-24); the spear extends horizontally forward from that
	# grip, tip at hip height. The strike rotates the right shoulder
	# forward by a small angle — the entire arm + spear translates
	# along an arc that's nearly horizontal at this magnitude. The
	# spear itself does NOT rotate; only the arm does. Hand stays at
	# hip level (small upward drift during the peak ~2px) so the
	# motion does not read as a pelvic thrust.
	var a := Animation.new()
	a.length = _weapon_meta_float(sprite_root, &"spear_stance", "attack_len", 0.85)
	a.loop_mode = Animation.LOOP_NONE
	var t_load: float = a.length * 0.21
	var t_hit: float = a.length * 0.54
	var t_hold: float = a.length * 0.73
	var t_end: float = a.length

	# --- Body holds steady — no lean, no pelvic slide ---
	var tbr := _cubic_track(a, NodePath("Body:rotation"))
	a.track_insert_key(tbr, 0.00, 0.0)
	a.track_insert_key(tbr, t_end, 0.0)

	# --- Right shoulder: cock back → drive forward → recover ---
	# Small magnitudes keep the arc nearly horizontal at the strike
	# magnitude (-0.50 rad), so the hand moves ~+9 in x and only ~+2
	# in y from its rest position.
	var tra := _cubic_track(a, NodePath("Body/ArmRShoulder:rotation"))
	a.track_insert_key(tra, 0.00, 0.0)
	a.track_insert_key(tra, t_load, 0.10)      # tiny back-load
	a.track_insert_key(tra, t_hit, -0.50)     # strike: arm swings forward
	a.track_insert_key(tra, t_hold, -0.25)
	a.track_insert_key(tra, t_end, 0.0)

	# --- Right elbow: stays straight throughout ---
	var tre := _cubic_track(a, NodePath("Body/ArmRShoulder/ElbowPivot:rotation"))
	a.track_insert_key(tre, 0.00, 0.0)
	a.track_insert_key(tre, t_end, 0.0)

	# --- SpearArm: held at 0 (horizontal forward, gripped at back). ---
	# The shaft doesn't rotate around the grip. It just translates
	# with the hand as the arm swings.
	var tsa := _cubic_track(a, NodePath("Body/ArmRShoulder/ElbowPivot/SpearArm:rotation"))
	var spear_rest_rot: float = _weapon_meta_float(sprite_root, &"spear_stance", "rest_rot", 0.0)
	a.track_insert_key(tsa, 0.00, spear_rest_rot)
	a.track_insert_key(tsa, t_end, spear_rest_rot)
	var current_spear_pos := Vector2.ZERO
	var spear_node := sprite_root.get_node_or_null(
			^"Body/ArmRShoulder/ElbowPivot/SpearArm") as Node2D
	if spear_node != null:
		current_spear_pos = spear_node.position
	var spear_rest_pos: Vector2 = _weapon_meta_vec2(sprite_root,
			&"spear_stance", "rest_pos", current_spear_pos)
	var spear_thrust_pos: Vector2 = _weapon_meta_vec2(sprite_root,
			&"spear_stance", "thrust_pos", spear_rest_pos)
	var tsp := _cubic_track(a, NodePath("Body/ArmRShoulder/ElbowPivot/SpearArm:position"))
	a.track_insert_key(tsp, 0.00, spear_rest_pos)
	a.track_insert_key(tsp, t_load, spear_rest_pos)
	a.track_insert_key(tsp, t_hit, spear_thrust_pos)
	a.track_insert_key(tsp, t_hold, spear_thrust_pos.lerp(spear_rest_pos, 0.35))
	a.track_insert_key(tsp, t_end, spear_rest_pos)

	# --- LEFT ARM ---
	var tla := _cubic_track(a, NodePath("Body/ArmLShoulder:rotation"))
	var tle := _cubic_track(a, NodePath("Body/ArmLShoulder/ElbowPivot:rotation"))
	if has_shield:
		# Shield rises EARLY (before the strike), holds across body
		# at chest height through the strike, lowers AFTER. This is
		# the fix for "raises shield as he whacks" — separating the
		# guard-up from the thrust.
		a.track_insert_key(tla, 0.00, 0.0)
		a.track_insert_key(tla, t_load, -0.85)    # shield raised to guard
		a.track_insert_key(tla, t_hit, -0.95)    # slight tighten on strike
		a.track_insert_key(tla, t_hold, -0.85)    # holds at guard
		a.track_insert_key(tla, t_end, 0.0)      # lowers after recovery
		a.track_insert_key(tle, 0.00, 0.0)
		a.track_insert_key(tle, t_load, -1.05)    # elbow folds shield in
		a.track_insert_key(tle, t_hit, -1.15)
		a.track_insert_key(tle, t_hold, -1.05)
		a.track_insert_key(tle, t_end, 0.0)
	else:
		# Two-handed grip — left hand reaches forward to grip shaft.
		# (Unused for Myrmidon now that the buckler counts as built-in
		# shield, but kept for future spear-wielders without shields.)
		a.track_insert_key(tla, 0.00, 0.0)
		a.track_insert_key(tla, 0.34, 0.10)
		a.track_insert_key(tla, t_hit, -0.32)
		a.track_insert_key(tla, t_hold, -0.20)
		a.track_insert_key(tla, t_end, 0.0)
		a.track_insert_key(tle, 0.00, 0.0)
		a.track_insert_key(tle, 0.34, 0.45)
		a.track_insert_key(tle, t_hit, 0.60)
		a.track_insert_key(tle, t_hold, 0.50)
		a.track_insert_key(tle, t_end, 0.0)

	return a

# Adds a TYPE_VALUE track at `path` and switches it to CUBIC
# interpolation so motion eases instead of snapping linearly. Returns
# the new track index.
static func _cubic_track(a: Animation, path: NodePath) -> int:
	var idx := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(idx, path)
	a.track_set_interpolation_type(idx, Animation.INTERPOLATION_CUBIC)
	return idx

# =========================================================================
# STAFF profile (Pythia) — full anim suite
# =========================================================================
# Two-handed staff is held diagonally in front of the body: right hand
# at hip-height on the back of the shaft (StaffArm origin), left hand
# reaches across to grip the upper shaft at chest height. The staff's
# own :rotation drives the pose — not arm-swing.
#
# Anchor angles (used by idle/walk and as start/end frames of attack
# + cast so the pose is continuous across animations):
#
#   STAFF_ANGLE_REST   = -PI / 4 (-0.785) — diagonal up-forward.
#     Orb lands around chest height in front, butt swings down-back.
#   ARM_L_SHOULDER_REST = -1.20 — left arm raised across body.
#   ARM_L_ELBOW_REST    = -0.90 — forearm folds to put the hand on
#     the upper shaft.
#   ARM_R_SHOULDER_REST =  0.00 — right arm hangs straight; the hand
#     pivots in place as the grip.
#
# Patterns vs the Myrmidon spear:
#   - Mid-grip polygon: SHARED. Both hands grip the shaft; right hand
#     at origin, left hand approximately on the +x extension.
#   - Arm-swing-not-shaft-rotate: REVERSED. For staff the staff DOES
#     rotate (large angle); arms drive it but the visible arc comes
#     from the StaffArm rotation track.

# Stage 17.6 — per reference-photo two-handed quarterstaff stance:
#   RIGHT hand is the ANCHOR at the lower grip (R hand at hip-forward,
#     acts as the fulcrum). StaffArm parented under R arm.
#   LEFT hand is the REACH at the upper grip (L hand at chest level,
#     IK-pinned to the LeftGrip cosmetic on the staff).
#   Staff at rest extends diagonally from R hand (lower-forward) up-
#     and-back to orb at upper-back-left — world angle -135°.
#
# Geometry at rest:
#   R shoulder (9, -44); rotation 0 → R hand polygon centroid at (9, -24).
#   StaffArm origin = R hand position; staff at world -135° (= local
#     -2.356 since parent rotation = 0).
#   LeftGrip (staff-local +11) lands at body-local ≈ (1.22, -31.78) —
#     chest height, slightly right of center.
#   Orb (staff-local +29.5) lands at ≈ (-11.86, -44.86) — upper-back-
#     left, above the left shoulder.
#   Butt (staff-local -22) lands at ≈ (24.55, -8.45) — lower-forward,
#     past the right hip.
#   L shoulder (-9, -44) → distance to LeftGrip ≈ 15.93, well within
#     arm reach. IK lands L hand on LeftGrip cleanly.

# Role-named so future swaps stay legible.
const STAFF_ANCHOR_SHOULDER_REST: float = 0.0
const STAFF_ANCHOR_ELBOW_REST: float    = 0.0
# L reach rest values are overridden by runtime IK every frame for
# idle/walk/attack. Authored to match the IK output at idle (L shoulder
# ≈ -0.05, L elbow ≈ -1.30 to put L hand on LeftGrip when staff is at
# rest -135°) so the transition from IK-driven idle into the animation-
# driven cast starts cleanly.
const STAFF_REACH_SHOULDER_REST: float  = -0.05
const STAFF_REACH_ELBOW_REST: float     = -1.30
const STAFF_ANGLE_REST: float           = -2.356  # local; world = -135° (diagonal upper-back)

# Node paths the staff animations drive. Anchor paths are the chain
# that owns StaffArm (R arm); reach paths are the free arm (L arm).
const _PATH_ANCHOR_SHOULDER := ^"Body/ArmRShoulder:rotation"
const _PATH_ANCHOR_ELBOW    := ^"Body/ArmRShoulder/ElbowPivot:rotation"
const _PATH_REACH_SHOULDER  := ^"Body/ArmLShoulder:rotation"
const _PATH_REACH_ELBOW     := ^"Body/ArmLShoulder/ElbowPivot:rotation"
const _PATH_STAFF_ROT       := ^"Body/StaffArm:rotation"
const _PATH_STAFF_ORB_MOD   := ^"Body/StaffArm/Orb:modulate"

# Keys the two-handed rest pose at one timestamp. Drives BOTH arms
# (anchor + reach) plus the staff local rotation so transitions
# between animations stay continuous.
static func _key_staff_rest(a: Animation, tsa: int, t_anchor_s: int,
		t_anchor_e: int, t_reach_s: int, t_reach_e: int, t: float,
		rest_rot: float) -> void:
	a.track_insert_key(tsa,         t, rest_rot)
	a.track_insert_key(t_anchor_s,  t, STAFF_ANCHOR_SHOULDER_REST)
	a.track_insert_key(t_anchor_e,  t, STAFF_ANCHOR_ELBOW_REST)
	a.track_insert_key(t_reach_s,   t, STAFF_REACH_SHOULDER_REST)
	a.track_insert_key(t_reach_e,   t, STAFF_REACH_ELBOW_REST)

# ---- IDLE: two-handed grip held steady, faint breath bob ----
func _build_staff_idle(sprite_root: Node2D) -> Animation:
	var rest_rot: float = _weapon_meta_float(sprite_root, &"staff_stance", "rest_rot", STAFF_ANGLE_REST)
	var a := Animation.new()
	a.length = 2.0
	a.loop_mode = Animation.LOOP_LINEAR
	var tb := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tb, NodePath("Body:position"))
	a.track_insert_key(tb, 0.0, Vector2.ZERO)
	a.track_insert_key(tb, 1.0, Vector2(0, -1))
	a.track_insert_key(tb, 2.0, Vector2.ZERO)
	var tsa := _cubic_track(a, _PATH_STAFF_ROT)
	var t_as := _cubic_track(a, _PATH_ANCHOR_SHOULDER)
	var t_ae := _cubic_track(a, _PATH_ANCHOR_ELBOW)
	var t_rs := _cubic_track(a, _PATH_REACH_SHOULDER)
	var t_re := _cubic_track(a, _PATH_REACH_ELBOW)
	_key_staff_rest(a, tsa, t_as, t_ae, t_rs, t_re, 0.0, rest_rot)
	_key_staff_rest(a, tsa, t_as, t_ae, t_rs, t_re, 2.0, rest_rot)
	return a

# ---- WALK: legs swing under a body bob, staff held two-handed ----
func _build_staff_walk(sprite_root: Node2D) -> Animation:
	var rest_rot: float = _weapon_meta_float(sprite_root, &"staff_stance", "rest_rot", STAFF_ANGLE_REST)
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_LINEAR
	var tb := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tb, NodePath("Body:position"))
	a.track_insert_key(tb, 0.0, Vector2.ZERO)
	a.track_insert_key(tb, 0.15, Vector2(0, -1.5))
	a.track_insert_key(tb, 0.3, Vector2.ZERO)
	a.track_insert_key(tb, 0.45, Vector2(0, -1.5))
	a.track_insert_key(tb, 0.6, Vector2.ZERO)
	var tlh := _cubic_track(a, NodePath("Body/LegLHip:rotation"))
	a.track_insert_key(tlh, 0.0, 0.0)
	a.track_insert_key(tlh, 0.15, -0.18)
	a.track_insert_key(tlh, 0.3, 0.0)
	a.track_insert_key(tlh, 0.45, 0.18)
	a.track_insert_key(tlh, 0.6, 0.0)
	var trh := _cubic_track(a, NodePath("Body/LegRHip:rotation"))
	a.track_insert_key(trh, 0.0, 0.0)
	a.track_insert_key(trh, 0.15, 0.18)
	a.track_insert_key(trh, 0.3, 0.0)
	a.track_insert_key(trh, 0.45, -0.18)
	a.track_insert_key(trh, 0.6, 0.0)
	var tsa := _cubic_track(a, _PATH_STAFF_ROT)
	var t_as := _cubic_track(a, _PATH_ANCHOR_SHOULDER)
	var t_ae := _cubic_track(a, _PATH_ANCHOR_ELBOW)
	var t_rs := _cubic_track(a, _PATH_REACH_SHOULDER)
	var t_re := _cubic_track(a, _PATH_REACH_ELBOW)
	_key_staff_rest(a, tsa, t_as, t_ae, t_rs, t_re, 0.0, rest_rot)
	_key_staff_rest(a, tsa, t_as, t_ae, t_rs, t_re, 0.6, rest_rot)
	return a

# ---- ATTACK: overhead arc → ends at hip-front. No forward thrust. ----
# Windup (0.00 → 0.30): staff rotates up-and-back to overhead-behind
#   the head. Right shoulder rocks back to raise the right hand.
#   Left arm pulls up to follow the rising upper shaft.
# Strike (0.30 → 0.55): staff arcs DOWN through the front, terminating
#   at hip-height-front (rotation ≈ +0.35 — slight down-tilt past
#   horizontal). Both arms drive the swing.
# Recovery (0.55 → 0.95): pose eases back to the two-handed rest.
func _build_staff_attack(sprite_root: Node2D) -> Animation:
	var rest_rot: float = _weapon_meta_float(sprite_root, &"staff_stance", "rest_rot", STAFF_ANGLE_REST)
	var apex_rot: float = _weapon_meta_float(sprite_root, &"staff_stance", "attack_apex_rot", -PI / 2.0)
	var attack_len: float = _weapon_meta_float(sprite_root, &"staff_stance", "attack_len", 0.55)
	# BOP. Simple overhead lift — orb arcs from upper-back-left to
	# straight-overhead and back. No windup, no body lean.
	#   Rest: staff world -135° (orb upper-back, photo-grip pose).
	#   Apex: staff world -90° (vertical, orb directly above the head).
	#     This keeps the LeftGrip cosmetic within L arm reach (~20 px
	#     from L shoulder) so the IK can hold the L hand on the staff
	#     throughout the motion. A larger forward strike would tear
	#     the L hand off the shaft — we accept a small/conservative
	#     bop in exchange for hands-on-staff continuity.
	#   Recovery: back to rest.
	var a := Animation.new()
	a.length = attack_len
	a.loop_mode = Animation.LOOP_NONE
	var t_apex: float = a.length * 0.45
	var t_end: float = a.length

	var tbr := _cubic_track(a, NodePath("Body:rotation"))
	a.track_insert_key(tbr, 0.00, 0.0)
	a.track_insert_key(tbr, t_end, 0.0)

	# Anchor stays at rest — no body drive.
	var t_as := _cubic_track(a, _PATH_ANCHOR_SHOULDER)
	a.track_insert_key(t_as, 0.00, STAFF_ANCHOR_SHOULDER_REST)
	a.track_insert_key(t_as, t_end, STAFF_ANCHOR_SHOULDER_REST)
	var t_ae := _cubic_track(a, _PATH_ANCHOR_ELBOW)
	a.track_insert_key(t_ae, 0.00, STAFF_ANCHOR_ELBOW_REST)
	a.track_insert_key(t_ae, t_end, STAFF_ANCHOR_ELBOW_REST)

	# Staff: world -135° → world -90° → world -135°.
	#   Parent (R anchor) = 0 throughout, so local angle = world angle.
	var tsa := _cubic_track(a, _PATH_STAFF_ROT)
	a.track_insert_key(tsa, 0.00, rest_rot)
	a.track_insert_key(tsa, t_apex, apex_rot)
	a.track_insert_key(tsa, t_end, rest_rot)

	# L arm placeholder tracks; IK overrides every frame.
	var t_rs := _cubic_track(a, _PATH_REACH_SHOULDER)
	a.track_insert_key(t_rs, 0.00, STAFF_REACH_SHOULDER_REST)
	a.track_insert_key(t_rs, t_end, STAFF_REACH_SHOULDER_REST)
	var t_re := _cubic_track(a, _PATH_REACH_ELBOW)
	a.track_insert_key(t_re, 0.00, STAFF_REACH_ELBOW_REST)
	a.track_insert_key(t_re, t_end, STAFF_REACH_ELBOW_REST)
	return a

# ---- CAST: lift staff vertical, orb pulses, no strike ----
# Windup (0.00 → 0.30): staff rotates from rest to vertical (orb high
#   above the head). Right shoulder lifts the arm up.
# Hold  (0.30 → 0.55): pose held, orb glows bright.
# Recovery (0.55 → 0.85): back to two-handed rest.
func _build_staff_cast(sprite_root: Node2D) -> Animation:
	var rest_rot: float = _weapon_meta_float(sprite_root, &"staff_stance", "rest_rot", STAFF_ANGLE_REST)
	var apex_rot: float = _weapon_meta_float(sprite_root, &"staff_stance", "attack_apex_rot", -PI / 2.0)
	var a := Animation.new()
	a.length = 0.85
	a.loop_mode = Animation.LOOP_NONE

	# Anchor (R shoulder) stays at rest — the staff lifts via its own
	# local rotation, not by lifting the anchor arm.
	var t_as := _cubic_track(a, _PATH_ANCHOR_SHOULDER)
	a.track_insert_key(t_as, 0.00, STAFF_ANCHOR_SHOULDER_REST)
	a.track_insert_key(t_as, 0.85, STAFF_ANCHOR_SHOULDER_REST)
	var t_ae := _cubic_track(a, _PATH_ANCHOR_ELBOW)
	a.track_insert_key(t_ae, 0.00, STAFF_ANCHOR_ELBOW_REST)
	a.track_insert_key(t_ae, 0.85, STAFF_ANCHOR_ELBOW_REST)

	# Staff rotates from rest -135° → vertical -90° (orb high above
	# head) and back. Parent (R anchor) stays at 0 so world = local.
	var tsa := _cubic_track(a, _PATH_STAFF_ROT)
	a.track_insert_key(tsa, 0.00, rest_rot)
	a.track_insert_key(tsa, 0.30, apex_rot)
	a.track_insert_key(tsa, 0.55, apex_rot)
	a.track_insert_key(tsa, 0.85, rest_rot)

	# Reach (L) sweeps out as the invocation gesture. Open arm to
	# the left: shoulder rotates +1.40 (upper arm horizontal-left),
	# elbow extends straight (0).
	var t_rs := _cubic_track(a, _PATH_REACH_SHOULDER)
	a.track_insert_key(t_rs, 0.00, STAFF_REACH_SHOULDER_REST)
	a.track_insert_key(t_rs, 0.30, 1.40)
	a.track_insert_key(t_rs, 0.55, 1.40)
	a.track_insert_key(t_rs, 0.85, STAFF_REACH_SHOULDER_REST)
	var t_re := _cubic_track(a, _PATH_REACH_ELBOW)
	a.track_insert_key(t_re, 0.00, STAFF_REACH_ELBOW_REST)
	a.track_insert_key(t_re, 0.30, 0.0)
	a.track_insert_key(t_re, 0.55, 0.0)
	a.track_insert_key(t_re, 0.85, STAFF_REACH_ELBOW_REST)

	# Orb pulse.
	var torb := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(torb, _PATH_STAFF_ORB_MOD)
	a.track_insert_key(torb, 0.00, Color(1, 1, 1, 1))
	a.track_insert_key(torb, 0.30, Color(2.4, 1.8, 0.7, 1))
	a.track_insert_key(torb, 0.55, Color(2.4, 1.8, 0.7, 1))
	a.track_insert_key(torb, 0.85, Color(1, 1, 1, 1))
	return a

static func _weapon_meta_float(sprite_root: Node, meta_key: StringName,
		value_key: String, fallback: float) -> float:
	if sprite_root == null or not sprite_root.has_meta(meta_key):
		return fallback
	var data_v: Variant = sprite_root.get_meta(meta_key)
	if typeof(data_v) != TYPE_DICTIONARY:
		return fallback
	return float((data_v as Dictionary).get(value_key, fallback))

static func _weapon_meta_vec2(sprite_root: Node, meta_key: StringName,
		value_key: String, fallback: Vector2) -> Vector2:
	if sprite_root == null or not sprite_root.has_meta(meta_key):
		return fallback
	var data_v: Variant = sprite_root.get_meta(meta_key)
	if typeof(data_v) != TYPE_DICTIONARY:
		return fallback
	var value: Variant = (data_v as Dictionary).get(value_key, fallback)
	return value if value is Vector2 else fallback

# =========================================================================
# WAND profile (Ossuary Priest)
# =========================================================================

func _build_wand_idle(sprite_root: Node2D) -> Animation:
	var rest_pos: Vector2 = _weapon_meta_vec2(sprite_root, &"wand_stance", "rest_pos", Vector2(10, -28))
	var rest_rot: float = _weapon_meta_float(sprite_root, &"wand_stance", "rest_rot", 0.0)
	var a := Animation.new()
	a.length = 1.4
	a.loop_mode = Animation.LOOP_LINEAR
	var tb := _cubic_track(a, NodePath("Body:position"))
	a.track_insert_key(tb, 0.0, Vector2.ZERO)
	a.track_insert_key(tb, 0.7, Vector2(0, -1))
	a.track_insert_key(tb, 1.4, Vector2.ZERO)
	var twp := _cubic_track(a, NodePath("WandArm:position"))
	a.track_insert_key(twp, 0.0, rest_pos)
	a.track_insert_key(twp, 1.4, rest_pos)
	var twr := _cubic_track(a, NodePath("WandArm:rotation"))
	a.track_insert_key(twr, 0.0, rest_rot)
	a.track_insert_key(twr, 1.4, rest_rot)
	return a

func _build_wand_walk(sprite_root: Node2D) -> Animation:
	var rest_pos: Vector2 = _weapon_meta_vec2(sprite_root, &"wand_stance", "rest_pos", Vector2(10, -28))
	var rest_rot: float = _weapon_meta_float(sprite_root, &"wand_stance", "rest_rot", 0.0)
	var a := Animation.new()
	a.length = 0.46
	a.loop_mode = Animation.LOOP_LINEAR
	var tb := _cubic_track(a, NodePath("Body:position"))
	a.track_insert_key(tb, 0.0, Vector2.ZERO)
	a.track_insert_key(tb, 0.23, Vector2(0, -2))
	a.track_insert_key(tb, 0.46, Vector2.ZERO)
	var br := _cubic_track(a, NodePath("Body:rotation"))
	a.track_insert_key(br, 0.0, 0.0)
	a.track_insert_key(br, 0.23, 0.035)
	a.track_insert_key(br, 0.46, 0.0)
	var twp := _cubic_track(a, NodePath("WandArm:position"))
	a.track_insert_key(twp, 0.0, rest_pos)
	a.track_insert_key(twp, 0.46, rest_pos)
	var twr := _cubic_track(a, NodePath("WandArm:rotation"))
	a.track_insert_key(twr, 0.0, rest_rot)
	a.track_insert_key(twr, 0.23, rest_rot + 0.08)
	a.track_insert_key(twr, 0.46, rest_rot)
	return a

func _build_wand_attack(sprite_root: Node2D) -> Animation:
	var rest_pos: Vector2 = _weapon_meta_vec2(sprite_root, &"wand_stance", "rest_pos", Vector2(10, -28))
	var rest_rot: float = _weapon_meta_float(sprite_root, &"wand_stance", "rest_rot", 0.0)
	var apex_rot: float = _weapon_meta_float(sprite_root, &"wand_stance", "attack_apex_rot", -0.45)
	var a := Animation.new()
	a.length = _weapon_meta_float(sprite_root, &"wand_stance", "attack_len", 0.34)
	a.loop_mode = Animation.LOOP_NONE
	var t_hit := a.length * 0.45
	var twr := _cubic_track(a, NodePath("WandArm:rotation"))
	a.track_insert_key(twr, 0.0, rest_rot)
	a.track_insert_key(twr, t_hit, apex_rot)
	a.track_insert_key(twr, a.length, rest_rot)
	var twp := _cubic_track(a, NodePath("WandArm:position"))
	a.track_insert_key(twp, 0.0, rest_pos)
	a.track_insert_key(twp, t_hit, rest_pos + Vector2(2, -1))
	a.track_insert_key(twp, a.length, rest_pos)
	return a

func _build_wand_cast(sprite_root: Node2D) -> Animation:
	var rest_pos: Vector2 = _weapon_meta_vec2(sprite_root, &"wand_stance", "rest_pos", Vector2(10, -28))
	var rest_rot: float = _weapon_meta_float(sprite_root, &"wand_stance", "rest_rot", 0.0)
	var apex_rot: float = _weapon_meta_float(sprite_root, &"wand_stance", "cast_apex_rot", -0.8)
	var a := Animation.new()
	a.length = _weapon_meta_float(sprite_root, &"wand_stance", "cast_len", 0.65)
	a.loop_mode = Animation.LOOP_NONE
	var t_peak := a.length * 0.38
	var twr := _cubic_track(a, NodePath("WandArm:rotation"))
	a.track_insert_key(twr, 0.0, rest_rot)
	a.track_insert_key(twr, t_peak, apex_rot)
	a.track_insert_key(twr, a.length, rest_rot)
	var twp := _cubic_track(a, NodePath("WandArm:position"))
	a.track_insert_key(twp, 0.0, rest_pos)
	a.track_insert_key(twp, a.length, rest_pos)
	var tg := _cubic_track(a, NodePath("WandArm/Glow:modulate"))
	a.track_insert_key(tg, 0.0, Color(1, 1, 1, 1))
	a.track_insert_key(tg, t_peak, Color(2.0, 2.5, 1.0, 1))
	a.track_insert_key(tg, a.length, Color(1, 1, 1, 1))
	var ts := _cubic_track(a, NodePath("WandArm/Glow:scale"))
	a.track_insert_key(ts, 0.0, Vector2.ONE)
	a.track_insert_key(ts, t_peak, Vector2(1.55, 1.55))
	a.track_insert_key(ts, a.length, Vector2.ONE)
	return a

# =========================================================================
# Unarmed / fallback profile
# =========================================================================
# Used when no weapon equipped OR a weapon type that doesn't yet
# have a profile (other classes' weapons until their sprites are
# rebuilt). Simple right-fist swing.

func _build_unarmed_fallback() -> Animation:
	var a := Animation.new()
	a.length = 0.35
	a.loop_mode = Animation.LOOP_NONE
	# Body slight forward lean
	var tbr := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tbr, NodePath("Body:rotation"))
	a.track_insert_key(tbr, 0.00, 0.0)
	a.track_insert_key(tbr, 0.10, 0.08)
	a.track_insert_key(tbr, 0.20, -0.08)
	a.track_insert_key(tbr, 0.35, 0.0)
	# Right arm jab
	var tra := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tra, NodePath("Body/ArmRShoulder:rotation"))
	a.track_insert_key(tra, 0.00, 0.0)
	a.track_insert_key(tra, 0.10, 0.6)    # wind back
	a.track_insert_key(tra, 0.20, -1.5)   # punch forward
	a.track_insert_key(tra, 0.35, 0.0)
	var tre := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tre, NodePath("Body/ArmRShoulder/ElbowPivot:rotation"))
	a.track_insert_key(tre, 0.00, 0.0)
	a.track_insert_key(tre, 0.10, 0.5)
	a.track_insert_key(tre, 0.20, -0.5)
	a.track_insert_key(tre, 0.35, 0.0)
	return a
