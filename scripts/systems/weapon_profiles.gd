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
	var to_install: Dictionary = _build_weapon_anims(weapon_type, has_shield)
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
func _build_weapon_anims(weapon_type: int, has_shield: bool) -> Dictionary:
	match weapon_type:
		ItemData.WeaponType.SPEAR:
			return { &"attack": _build_spear(has_shield) }
		ItemData.WeaponType.STAFF:
			# Two-handed grip has to hold across idle/walk/cast too —
			# the bare-hands rest pose has arms at sides, which would
			# leave the staff dangling weirdly.
			return {
				&"idle":   _build_staff_idle(),
				&"walk":   _build_staff_walk(),
				&"attack": _build_staff_attack(),
				&"cast":   _build_staff_cast(),
			}
		ItemData.WeaponType.BOW, \
		ItemData.WeaponType.WAND, \
		ItemData.WeaponType.NONE:
			return { &"attack": _build_unarmed_fallback() }
	return { &"attack": _build_unarmed_fallback() }

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

func _build_spear(has_shield: bool) -> Animation:
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
	a.length = 0.85
	a.loop_mode = Animation.LOOP_NONE

	# --- Body holds steady — no lean, no pelvic slide ---
	var tbr := _cubic_track(a, NodePath("Body:rotation"))
	a.track_insert_key(tbr, 0.00, 0.0)
	a.track_insert_key(tbr, 0.85, 0.0)

	# --- Right shoulder: cock back → drive forward → recover ---
	# Small magnitudes keep the arc nearly horizontal at the strike
	# magnitude (-0.50 rad), so the hand moves ~+9 in x and only ~+2
	# in y from its rest position.
	var tra := _cubic_track(a, NodePath("Body/ArmRShoulder:rotation"))
	a.track_insert_key(tra, 0.00, 0.0)
	a.track_insert_key(tra, 0.18, 0.10)      # tiny back-load
	a.track_insert_key(tra, 0.46, -0.50)     # strike: arm swings forward
	a.track_insert_key(tra, 0.62, -0.25)
	a.track_insert_key(tra, 0.85, 0.0)

	# --- Right elbow: stays straight throughout ---
	var tre := _cubic_track(a, NodePath("Body/ArmRShoulder/ElbowPivot:rotation"))
	a.track_insert_key(tre, 0.00, 0.0)
	a.track_insert_key(tre, 0.85, 0.0)

	# --- SpearArm: held at 0 (horizontal forward, gripped at back). ---
	# The shaft doesn't rotate around the grip. It just translates
	# with the hand as the arm swings.
	var tsa := _cubic_track(a, NodePath("Body/ArmRShoulder/ElbowPivot/SpearArm:rotation"))
	a.track_insert_key(tsa, 0.00, 0.0)
	a.track_insert_key(tsa, 0.85, 0.0)

	# --- LEFT ARM ---
	var tla := _cubic_track(a, NodePath("Body/ArmLShoulder:rotation"))
	var tle := _cubic_track(a, NodePath("Body/ArmLShoulder/ElbowPivot:rotation"))
	if has_shield:
		# Shield rises EARLY (before the strike), holds across body
		# at chest height through the strike, lowers AFTER. This is
		# the fix for "raises shield as he whacks" — separating the
		# guard-up from the thrust.
		a.track_insert_key(tla, 0.00, 0.0)
		a.track_insert_key(tla, 0.18, -0.85)    # shield raised to guard
		a.track_insert_key(tla, 0.46, -0.95)    # slight tighten on strike
		a.track_insert_key(tla, 0.62, -0.85)    # holds at guard
		a.track_insert_key(tla, 0.85, 0.0)      # lowers after recovery
		a.track_insert_key(tle, 0.00, 0.0)
		a.track_insert_key(tle, 0.18, -1.05)    # elbow folds shield in
		a.track_insert_key(tle, 0.46, -1.15)
		a.track_insert_key(tle, 0.62, -1.05)
		a.track_insert_key(tle, 0.85, 0.0)
	else:
		# Two-handed grip — left hand reaches forward to grip shaft.
		# (Unused for Myrmidon now that the buckler counts as built-in
		# shield, but kept for future spear-wielders without shields.)
		a.track_insert_key(tla, 0.00, 0.0)
		a.track_insert_key(tla, 0.34, 0.10)
		a.track_insert_key(tla, 0.46, -0.32)
		a.track_insert_key(tla, 0.62, -0.20)
		a.track_insert_key(tla, 0.85, 0.0)
		a.track_insert_key(tle, 0.00, 0.0)
		a.track_insert_key(tle, 0.34, 0.45)
		a.track_insert_key(tle, 0.46, 0.60)
		a.track_insert_key(tle, 0.62, 0.50)
		a.track_insert_key(tle, 0.85, 0.0)

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

# Staff is gripped at hip (right hand) and chest (left hand). The
# right shoulder rotates slightly inward at rest so the shaft is
# carried near body centerline — that's the only way the left hand
# can geometrically reach a point on the shaft (arm length ~22; if
# the staff stays at the body's right edge, the closest shaft point
# is ~26 away — unreachable). With the shoulder rotated +0.30, the
# shaft passes ~20 away from the left shoulder, within arm reach.
#
# World staff angle at rest is -60° (mostly vertical, slight forward
# tilt). Because the staff inherits the right shoulder's rotation,
# its LOCAL rotation = -60° - shoulder_rest = -1.047 - 0.30 = -1.347
# rad so the rendered global angle still comes out to -60°.
const ARM_R_SHOULDER_REST: float    = 0.30
const STAFF_ANGLE_REST: float       = -1.347         # local; world = -60°
# Left arm reach. Target landing point ≈ LeftGrip cosmetic on the
# upper shaft at body-local ≈ (8.6, -34.4). Vector from left shoulder
# (-9, -44) is (17.6, 9.6), distance ≈ 20 — fully extended arm just
# reaches with a small margin. Shoulder rotation -1.07 points the
# upper arm along that vector; elbow straight (0) leaves the forearm
# in the same direction.
const ARM_L_SHOULDER_REST: float    = -1.07
const ARM_L_ELBOW_REST: float       =  0.0

# Keys the two-handed rest pose at one timestamp. Used by every staff
# animation to lock the start/end frame to the same anchor pose so the
# AnimationPlayer can transition cleanly between states. Right
# shoulder is keyed at ARM_R_SHOULDER_REST (not zero) — see comments
# on that constant for why the staff is carried inward.
static func _key_staff_rest(a: Animation, tsa: int, tls: int, tle: int,
		t_ra: int, t: float) -> void:
	a.track_insert_key(tsa, t, STAFF_ANGLE_REST)
	a.track_insert_key(tls, t, ARM_L_SHOULDER_REST)
	a.track_insert_key(tle, t, ARM_L_ELBOW_REST)
	a.track_insert_key(t_ra, t, ARM_R_SHOULDER_REST)

# ---- IDLE: two-handed grip held steady, faint breath bob ----
func _build_staff_idle() -> Animation:
	var a := Animation.new()
	a.length = 2.0
	a.loop_mode = Animation.LOOP_LINEAR
	# Body breath
	var tb := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tb, NodePath("Body:position"))
	a.track_insert_key(tb, 0.0, Vector2.ZERO)
	a.track_insert_key(tb, 1.0, Vector2(0, -1))
	a.track_insert_key(tb, 2.0, Vector2.ZERO)
	# Locked-pose tracks for the two-handed grip.
	var tsa := _cubic_track(a, NodePath("Body/ArmRShoulder/ElbowPivot/StaffArm:rotation"))
	var tls := _cubic_track(a, NodePath("Body/ArmLShoulder:rotation"))
	var tle := _cubic_track(a, NodePath("Body/ArmLShoulder/ElbowPivot:rotation"))
	var tra := _cubic_track(a, NodePath("Body/ArmRShoulder:rotation"))
	_key_staff_rest(a, tsa, tls, tle, tra, 0.0)
	_key_staff_rest(a, tsa, tls, tle, tra, 2.0)
	return a

# ---- WALK: legs swing under a body bob, staff held two-handed ----
func _build_staff_walk() -> Animation:
	var a := Animation.new()
	a.length = 0.6
	a.loop_mode = Animation.LOOP_LINEAR
	# Body bob
	var tb := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tb, NodePath("Body:position"))
	a.track_insert_key(tb, 0.0, Vector2.ZERO)
	a.track_insert_key(tb, 0.15, Vector2(0, -1.5))
	a.track_insert_key(tb, 0.3, Vector2.ZERO)
	a.track_insert_key(tb, 0.45, Vector2(0, -1.5))
	a.track_insert_key(tb, 0.6, Vector2.ZERO)
	# Hip swings (mirror Pythia bare walk)
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
	# Arms locked on the staff: pose holds across the loop.
	var tsa := _cubic_track(a, NodePath("Body/ArmRShoulder/ElbowPivot/StaffArm:rotation"))
	var tls := _cubic_track(a, NodePath("Body/ArmLShoulder:rotation"))
	var tle := _cubic_track(a, NodePath("Body/ArmLShoulder/ElbowPivot:rotation"))
	var tra := _cubic_track(a, NodePath("Body/ArmRShoulder:rotation"))
	_key_staff_rest(a, tsa, tls, tle, tra, 0.0)
	_key_staff_rest(a, tsa, tls, tle, tra, 0.6)
	return a

# ---- ATTACK: overhead arc → ends at hip-front. No forward thrust. ----
# Windup (0.00 → 0.30): staff rotates up-and-back to overhead-behind
#   the head. Right shoulder rocks back to raise the right hand.
#   Left arm pulls up to follow the rising upper shaft.
# Strike (0.30 → 0.55): staff arcs DOWN through the front, terminating
#   at hip-height-front (rotation ≈ +0.35 — slight down-tilt past
#   horizontal). Both arms drive the swing.
# Recovery (0.55 → 0.95): pose eases back to the two-handed rest.
func _build_staff_attack() -> Animation:
	var a := Animation.new()
	a.length = 0.95
	a.loop_mode = Animation.LOOP_NONE

	# Body holds steady — no hip thrust.
	var tbr := _cubic_track(a, NodePath("Body:rotation"))
	a.track_insert_key(tbr, 0.00, 0.0)
	a.track_insert_key(tbr, 0.95, 0.0)

	# Staff rotation — the defining track. World angle = parent + local.
	# Parent (right shoulder) goes from REST → REST+0.30 windup →
	# REST-0.40 strike → REST recovery. Staff local is computed so the
	# global world angle hits the intended targets:
	#   t=0.00 → world -60° (rest)
	#   t=0.30 → world -137° (overhead + back) — local = -137° in rad
	#            minus (REST+0.30) = -2.39 - 0.60 = -2.99 rad
	#   t=0.55 → world +20° (down-to-hip-front) — local = 0.35 rad
	#            minus (REST-0.40) = 0.35 - (-0.10) = +0.45 rad
	# To keep this readable I author DIRECT world targets and add
	# parent compensation here.
	var tsa := _cubic_track(a, NodePath("Body/ArmRShoulder/ElbowPivot/StaffArm:rotation"))
	a.track_insert_key(tsa, 0.00, STAFF_ANGLE_REST)
	a.track_insert_key(tsa, 0.30, -2.40 - 0.60)       # world -2.40 with parent +0.60
	a.track_insert_key(tsa, 0.55,  0.35 + 0.10)       # world +0.35 with parent -0.10
	a.track_insert_key(tsa, 0.95, STAFF_ANGLE_REST)

	# Right shoulder: cocks back from REST during windup, eases through
	# the strike, returns to REST.
	var tra := _cubic_track(a, NodePath("Body/ArmRShoulder:rotation"))
	a.track_insert_key(tra, 0.00, ARM_R_SHOULDER_REST)
	a.track_insert_key(tra, 0.30, ARM_R_SHOULDER_REST + 0.30)
	a.track_insert_key(tra, 0.55, ARM_R_SHOULDER_REST - 0.40)
	a.track_insert_key(tra, 0.95, ARM_R_SHOULDER_REST)

	# Right elbow: stays straight.
	var tre := _cubic_track(a, NodePath("Body/ArmRShoulder/ElbowPivot:rotation"))
	a.track_insert_key(tre, 0.00, 0.0)
	a.track_insert_key(tre, 0.95, 0.0)

	# Left arm follows the shaft up during windup and down through
	# strike, returning to the two-handed grip rest values.
	var tls := _cubic_track(a, NodePath("Body/ArmLShoulder:rotation"))
	a.track_insert_key(tls, 0.00, ARM_L_SHOULDER_REST)
	a.track_insert_key(tls, 0.30, -2.10)               # arm raised high
	a.track_insert_key(tls, 0.55, -0.20)               # extends down with strike
	a.track_insert_key(tls, 0.95, ARM_L_SHOULDER_REST)
	var tle := _cubic_track(a, NodePath("Body/ArmLShoulder/ElbowPivot:rotation"))
	a.track_insert_key(tle, 0.00, ARM_L_ELBOW_REST)
	a.track_insert_key(tle, 0.30, -1.30)
	a.track_insert_key(tle, 0.55, 0.40)
	a.track_insert_key(tle, 0.95, ARM_L_ELBOW_REST)
	return a

# ---- CAST: lift staff vertical, orb pulses, no strike ----
# Windup (0.00 → 0.30): staff rotates from rest to vertical (orb high
#   above the head). Right shoulder lifts the arm up.
# Hold  (0.30 → 0.55): pose held, orb glows bright.
# Recovery (0.55 → 0.85): back to two-handed rest.
func _build_staff_cast() -> Animation:
	var a := Animation.new()
	a.length = 0.85
	a.loop_mode = Animation.LOOP_NONE

	# Cast: lift staff to vertical world-angle -90°, hold, return to
	# rest. Right shoulder also lifts to raise the orb higher.
	var tsa := _cubic_track(a, NodePath("Body/ArmRShoulder/ElbowPivot/StaffArm:rotation"))
	a.track_insert_key(tsa, 0.00, STAFF_ANGLE_REST)
	# Want world -90° with parent shoulder lifted by -0.30 → local =
	# -PI/2 - (REST-0.30) = -1.57 - 0.0 = -1.57. Authoring as the
	# world target minus parent.
	a.track_insert_key(tsa, 0.30, -PI / 2.0 - (ARM_R_SHOULDER_REST - 0.30))
	a.track_insert_key(tsa, 0.55, -PI / 2.0 - (ARM_R_SHOULDER_REST - 0.30))
	a.track_insert_key(tsa, 0.85, STAFF_ANGLE_REST)

	var tra := _cubic_track(a, NodePath("Body/ArmRShoulder:rotation"))
	a.track_insert_key(tra, 0.00, ARM_R_SHOULDER_REST)
	a.track_insert_key(tra, 0.30, ARM_R_SHOULDER_REST - 0.30)
	a.track_insert_key(tra, 0.55, ARM_R_SHOULDER_REST - 0.30)
	a.track_insert_key(tra, 0.85, ARM_R_SHOULDER_REST)

	var tls := _cubic_track(a, NodePath("Body/ArmLShoulder:rotation"))
	a.track_insert_key(tls, 0.00, ARM_L_SHOULDER_REST)
	a.track_insert_key(tls, 0.30, -0.10)              # left arm sweeps out as invocation
	a.track_insert_key(tls, 0.55, -0.10)
	a.track_insert_key(tls, 0.85, ARM_L_SHOULDER_REST)
	var tle := _cubic_track(a, NodePath("Body/ArmLShoulder/ElbowPivot:rotation"))
	a.track_insert_key(tle, 0.00, ARM_L_ELBOW_REST)
	a.track_insert_key(tle, 0.30, -0.10)
	a.track_insert_key(tle, 0.55, -0.10)
	a.track_insert_key(tle, 0.85, ARM_L_ELBOW_REST)

	# Orb pulse.
	var torb := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(torb, NodePath("Body/ArmRShoulder/ElbowPivot/StaffArm/Orb:modulate"))
	a.track_insert_key(torb, 0.00, Color(1, 1, 1, 1))
	a.track_insert_key(torb, 0.30, Color(2.4, 1.8, 0.7, 1))
	a.track_insert_key(torb, 0.55, Color(2.4, 1.8, 0.7, 1))
	a.track_insert_key(torb, 0.85, Color(1, 1, 1, 1))
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
