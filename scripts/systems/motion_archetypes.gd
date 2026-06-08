class_name MotionArchetypes extends Object
## Stage 17.7 — reusable motion-archetype track helpers.
##
## A library of compositional functions that ADD tracks to an existing
## Animation. Each archetype encodes ONE motion pattern (overhead arc,
## linear thrust, charge-release, breath bob, etc.) as a small set of
## keyframes on a single NodePath. Callers compose multiple archetypes
## onto one Animation to get the full pose (e.g. idle = breath bob +
## staff-grip pose + weapon rotation hold).
##
## Built so a sprite/weapon profile is "pick archetype, fill 4 numbers"
## instead of hand-keying every track. Each helper is documented with
## the NodePath shape it expects so the caller knows what nodes must
## exist on the sprite.
##
## All helpers default to CUBIC interpolation for smooth motion. Pass
## a different interp type via the optional `interp` arg if needed.

## Convenience: make a fresh Animation with `length` + loop mode.
static func make_anim(length: float, loop: int = Animation.LOOP_NONE) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = loop
	return a

# =========================================================================
# CORE TRACK HELPERS
# =========================================================================

## Add a TYPE_VALUE track with N keyframes. `keys` is an Array of
## [time, value] pairs. Returns the track index.
static func add_value_track(anim: Animation, path: NodePath, keys: Array,
		interp: int = Animation.INTERPOLATION_CUBIC) -> int:
	var ti: int = anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(ti, path)
	anim.track_set_interpolation_type(ti, interp)
	for kv in keys:
		anim.track_insert_key(ti, float(kv[0]), kv[1])
	return ti

# =========================================================================
# ARCHETYPE: BODY BOB
# =========================================================================
## Vertical sinusoid on Body:position — idle breath or walk bob.
## `amplitude` is in pixels (negative y is up). `period` is the loop
## time. Adds ONE track to `anim`.
##
## Required path: <sprite_root>/Body
static func add_body_bob(anim: Animation, body_path: NodePath,
		amplitude: float, period: float) -> void:
	add_value_track(anim, NodePath(String(body_path) + ":position"), [
		[0.0,           Vector2.ZERO],
		[period * 0.5,  Vector2(0, -amplitude)],
		[period,        Vector2.ZERO],
	])

# =========================================================================
# ARCHETYPE: ARC_OVERHEAD
# =========================================================================
## Two-handed overhead arc (Pythia bop, axe chop). Weapon rotates from
## `rest_rad` → `apex_rad` → `rest_rad` over `duration`. Apex hit at
## `apex_frac` of duration (default 0.45 — slight anticipation).
##
## `weapon_rot_path` is the NodePath:":rotation" of the weapon subtree
## (e.g. Body/ArmRShoulder/ElbowPivot/StaffArm).
static func add_arc_overhead(anim: Animation, weapon_rot_path: NodePath,
		rest_rad: float, apex_rad: float,
		duration: float, apex_frac: float = 0.45) -> void:
	add_value_track(anim, weapon_rot_path, [
		[0.0,                       rest_rad],
		[duration * apex_frac,      apex_rad],
		[duration,                  rest_rad],
	])

# =========================================================================
# ARCHETYPE: THRUST_LINEAR
# =========================================================================
## Single-arm forward thrust (spear, jab). Shoulder rotates from rest
## to reach and back; weapon rotation stays at 0 (translates with hand).
## Returns nothing — adds ONE track on `shoulder_rot_path`.
##
## `reach_frac` of duration is when the shoulder hits peak forward swing.
static func add_thrust_linear(anim: Animation, shoulder_rot_path: NodePath,
		rest_rad: float, reach_rad: float,
		duration: float, reach_frac: float = 0.55) -> void:
	add_value_track(anim, shoulder_rot_path, [
		[0.0,                       rest_rad],
		[duration * reach_frac,     reach_rad],
		[duration,                  rest_rad],
	])

# =========================================================================
# ARCHETYPE: CHARGE_RELEASE
# =========================================================================
## Bow draw + hold + release. Drives a Marker2D (typically the bow's
## NockMarker) along bow-local x — animating its `:position` track
## moves it from rest → drawn-back over `draw_frac` of duration, holds
## at full draw until `release_frac`, then snaps back to rest in the
## remainder.
##
## At the same time the draw arm's shoulder rotates back to follow the
## nock (added as a second track on `draw_shoulder_rot_path`).
##
## Required paths:
##   nock_pos_path        — Marker2D:position on the bow subtree
##   draw_shoulder_path   — Body/ArmRShoulder:rotation (or whichever
##                          arm pulls the string)
##
## Note: the actual hand-to-nock pin is handled by HumanRig.apply_pins
## at runtime; this archetype just animates the nock + a hint shoulder
## rotation so the IK has a sensible starting pose each frame.
static func add_charge_release(anim: Animation,
		nock_pos_path: NodePath, draw_shoulder_path: NodePath,
		nock_rest: Vector2, nock_drawn: Vector2,
		shoulder_rest_rad: float, shoulder_drawn_rad: float,
		duration: float,
		draw_frac: float = 0.30, release_frac: float = 0.75) -> void:
	add_value_track(anim, nock_pos_path, [
		[0.0,                       nock_rest],
		[duration * draw_frac,      nock_drawn],
		[duration * release_frac,   nock_drawn],
		[duration,                  nock_rest],
	])
	add_value_track(anim, NodePath(String(draw_shoulder_path) + ":rotation"), [
		[0.0,                       shoulder_rest_rad],
		[duration * draw_frac,      shoulder_drawn_rad],
		[duration * release_frac,   shoulder_drawn_rad],
		[duration,                  shoulder_rest_rad],
	])

# =========================================================================
# ARCHETYPE: CONDUIT_LIFT
# =========================================================================
## Caster pattern — weapon raised to vertical, held while channeling,
## lowered to rest. Pythia cast. Add an Orb modulate pulse separately
## if the weapon has a glow node.
static func add_conduit_lift(anim: Animation, weapon_rot_path: NodePath,
		rest_rad: float, apex_rad: float,
		duration: float, lift_frac: float = 0.30, hold_frac: float = 0.70) -> void:
	add_value_track(anim, weapon_rot_path, [
		[0.0,                       rest_rad],
		[duration * lift_frac,      apex_rad],
		[duration * hold_frac,      apex_rad],
		[duration,                  rest_rad],
	])

# =========================================================================
# ARCHETYPE: HOLD_POSE
# =========================================================================
## Static hold — single keyframe (or 0+length). Used when a body part
## needs to stay clamped at a specific value across an animation while
## OTHER parts move (e.g. anchor arm rotation during a staff bop).
static func add_hold(anim: Animation, path: NodePath, value: Variant) -> void:
	add_value_track(anim, path, [
		[0.0,           value],
		[anim.length,   value],
	], Animation.INTERPOLATION_LINEAR)
