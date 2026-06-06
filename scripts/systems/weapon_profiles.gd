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
	var attack := _build_attack(weapon_type, has_shield)
	if lib.has_animation(&"attack"):
		lib.remove_animation(&"attack")
	lib.add_animation(&"attack", attack)

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

func _build_attack(weapon_type: int, has_shield: bool) -> Animation:
	match weapon_type:
		ItemData.WeaponType.SPEAR:
			return _build_spear(has_shield)
		ItemData.WeaponType.STAFF, \
		ItemData.WeaponType.BOW, \
		ItemData.WeaponType.WAND, \
		ItemData.WeaponType.NONE:
			return _build_unarmed_fallback()
	return _build_unarmed_fallback()

# =========================================================================
# SPEAR profile (Myrmidon)
# =========================================================================
# With shield: weight shifts back, right arm cocks spear back, left
# arm raises shield forward. Then weight forward, right arm thrusts
# spear forward; shield holds raised. Recovery back to rest.
# Without shield: left hand crosses to grip the shaft (rotates
# inward + downward), both arms thrust forward together.

func _build_spear(has_shield: bool) -> Animation:
	# Hoplite overhand thrust — fully sequenced, smoothly interpolated.
	#
	# Beats:
	#   0.00–0.18  GUARD UP: shield rises to chest first, body settles
	#              into stance. Spear and right arm stay quiet.
	#   0.18–0.34  WIND UP: shoulder cocks back, spear tip rises behind
	#              the head. Shield holds at guard.
	#   0.34–0.46  STRIKE: spear rotates tip-forward and shoulder drives
	#              through. Shield still at guard. This is the impact
	#              frame (around t=0.42).
	#   0.46–0.62  HOLD:   spear stays extended briefly so the strike
	#              reads at game zoom.
	#   0.62–0.85  RECOVER: spear and shield return to rest together.
	#
	# All rotation tracks use CUBIC interpolation so the motion eases
	# in/out instead of snapping linearly between keys — that's the
	# main fluidity fix.
	var a := Animation.new()
	a.length = 0.85
	a.loop_mode = Animation.LOOP_NONE

	# --- Body lean: subtle back-then-forward, no pelvic slide ---
	var tbr := _cubic_track(a, NodePath("Body:rotation"))
	a.track_insert_key(tbr, 0.00, 0.0)
	a.track_insert_key(tbr, 0.18, 0.04)     # settle into guard
	a.track_insert_key(tbr, 0.34, 0.08)     # tiny back lean as arm winds
	a.track_insert_key(tbr, 0.46, -0.10)    # lean forward through strike
	a.track_insert_key(tbr, 0.62, -0.04)
	a.track_insert_key(tbr, 0.85, 0.0)

	# --- Right shoulder: quiet → cock → drive → recover ---
	# Small amplitudes — the spear tip travel comes from SpearArm
	# rotation, NOT from the shoulder swinging the whole arm in an
	# arc (which would lift the hand and angle the spear up-forward
	# instead of straight forward).
	var tra := _cubic_track(a, NodePath("Body/ArmRShoulder:rotation"))
	a.track_insert_key(tra, 0.00, 0.0)
	a.track_insert_key(tra, 0.18, 0.04)
	a.track_insert_key(tra, 0.34, 0.18)     # gentle wind-back
	a.track_insert_key(tra, 0.46, -0.15)    # gentle drive forward
	a.track_insert_key(tra, 0.62, -0.08)
	a.track_insert_key(tra, 0.85, 0.0)

	# --- Right elbow: straight throughout (thrust, not jab) ---
	var tre := _cubic_track(a, NodePath("Body/ArmRShoulder/ElbowPivot:rotation"))
	a.track_insert_key(tre, 0.00, 0.0)
	a.track_insert_key(tre, 0.85, 0.0)

	# --- SpearArm: the PRIMARY motion. Tip leads forward at strike. ---
	# Rest = 0 (tip up). Wind = -0.30 (tip back-up, behind the shoulder).
	# Strike = +1.50 (tip near-horizontal forward). Hold then return.
	var tsa := _cubic_track(a, NodePath("Body/ArmRShoulder/ElbowPivot/SpearArm:rotation"))
	a.track_insert_key(tsa, 0.00, 0.0)
	a.track_insert_key(tsa, 0.18, -0.10)
	a.track_insert_key(tsa, 0.34, -0.30)    # wound up behind head
	a.track_insert_key(tsa, 0.46, 1.50)     # STRIKE: tip thrusts forward
	a.track_insert_key(tsa, 0.62, 1.20)     # held briefly extended
	a.track_insert_key(tsa, 0.85, 0.0)      # return to vertical

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
