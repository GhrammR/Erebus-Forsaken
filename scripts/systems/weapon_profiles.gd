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
	var has_shield := _is_shield(offhand_item)
	var weapon_type := ItemData.WeaponType.NONE
	if weapon_item != null:
		weapon_type = weapon_item.weapon_type
	var attack := _build_attack(weapon_type, has_shield)
	if lib.has_animation(&"attack"):
		lib.remove_animation(&"attack")
	lib.add_animation(&"attack", attack)

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
	# Thrust, not a swing. The motion is an arm EXTENSION: shoulder
	# rotates slightly forward and elbow straightens. Because
	# SpearArm is parented to the hand (Body/ArmRShoulder/ElbowPivot),
	# the spear travels with the arm — no big circular rotation arc.
	# Spear keeps its hand-relative orientation throughout.
	var a := Animation.new()
	a.length = 0.45
	a.loop_mode = Animation.LOOP_NONE

	# --- Body lean (rotation only — feet stay planted, no hop) ---
	var tbr := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tbr, NodePath("Body:rotation"))
	a.track_insert_key(tbr, 0.00, 0.0)
	a.track_insert_key(tbr, 0.12, 0.10)    # slight lean back during wind-up
	a.track_insert_key(tbr, 0.24, -0.12)   # lean forward into the thrust
	a.track_insert_key(tbr, 0.45, 0.0)

	# --- Right shoulder rotation: cock + thrust ---
	# Shoulder-driven. NO elbow folding (folding the elbow makes the
	# spear sweep through a circular arc, which reads as a swing
	# not a thrust). Arm stays mostly straight; the spear stays
	# roughly aligned with the arm's down-axis throughout.
	var tra := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tra, NodePath("Body/ArmRShoulder:rotation"))
	a.track_insert_key(tra, 0.00, 0.0)
	a.track_insert_key(tra, 0.12, 0.25)    # small back-cock (spear tip back-up)
	a.track_insert_key(tra, 0.24, -1.10)   # forward thrust (spear tip forward)
	a.track_insert_key(tra, 0.45, 0.0)

	# --- Right elbow: stays at 0 (no fold during thrust) ---
	# Keyed explicitly so any prior fold doesn't bleed in from the
	# bare-hands placeholder animation.
	var tre := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tre, NodePath("Body/ArmRShoulder/ElbowPivot:rotation"))
	a.track_insert_key(tre, 0.00, 0.0)
	a.track_insert_key(tre, 0.24, 0.0)
	a.track_insert_key(tre, 0.45, 0.0)

	# --- SpearArm: counter-rotates slightly so the tip "leads" ---
	# Small magnitude — the spear's primary motion comes from the
	# shoulder, this adds a touch of tip-first flair.
	var tsa := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tsa, NodePath("Body/ArmRShoulder/ElbowPivot/SpearArm:rotation"))
	a.track_insert_key(tsa, 0.00, 0.0)
	a.track_insert_key(tsa, 0.24, -0.15)
	a.track_insert_key(tsa, 0.45, 0.0)

	# --- LEFT arm: shield-raise OR two-handed grip ---
	var tla := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tla, NodePath("Body/ArmLShoulder:rotation"))
	var tle := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(tle, NodePath("Body/ArmLShoulder/ElbowPivot:rotation"))
	if has_shield:
		# Shield raise: left shoulder rotates forward and elbow folds
		# in so the shield comes up across the front of the body.
		a.track_insert_key(tla, 0.00, 0.0)
		a.track_insert_key(tla, 0.10, -0.9)   # shoulder up + forward
		a.track_insert_key(tla, 0.30, -0.9)   # hold raised
		a.track_insert_key(tla, 0.45, 0.0)
		a.track_insert_key(tle, 0.00, 0.0)
		a.track_insert_key(tle, 0.10, -1.0)   # elbow folds inward
		a.track_insert_key(tle, 0.30, -1.0)
		a.track_insert_key(tle, 0.45, 0.0)
	else:
		# Two-handed thrust: left arm crosses to grip mid-shaft and
		# drives forward with the spear. Shoulder rotates toward the
		# centerline, elbow extends.
		a.track_insert_key(tla, 0.00, 0.0)
		a.track_insert_key(tla, 0.12, 0.4)    # reach across (wind-back)
		a.track_insert_key(tla, 0.24, -1.3)   # extend forward with thrust
		a.track_insert_key(tla, 0.45, 0.0)
		a.track_insert_key(tle, 0.00, 0.0)
		a.track_insert_key(tle, 0.12, 0.8)    # elbow folds to grip shaft
		a.track_insert_key(tle, 0.24, -0.4)   # elbow extends through
		a.track_insert_key(tle, 0.45, 0.0)

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
