extends Node
class_name SpriteSpecs
## Stage 17.6 — pose specifications + verifier registry.
##
## Each sprite animation declares its INTENT as a list of keyframes,
## each specifying the expected weapon angle / hand positions / elbow
## positions / weapon tip + butt positions in **sprite-local** coords
## (feet at (0,0), +x = forward, -y = up). The sprite_render verifier
## seeks to each keyframe at render time, reads the ACTUAL positions,
## diffs against the spec, and writes PASS/FAIL to the per-variant
## trace.txt next to the strip PNG.
##
## This exists because authoring rotation values by eye, then waiting
## three minutes to render, then squinting at a 240×240 strip is a
## terrible feedback loop. Specs let us declare what we WANT, render
## once, and read deltas as numbers instead of guessing from pixels.
##
## Spec entries are optional. Only the keys present at a keyframe are
## checked — omit fields we don't constrain.
##
## ===== Schema =====
##   per_class: Dictionary[StringName -> per_anim]
##   per_anim: Dictionary[StringName -> spec]
##   spec: Dictionary {
##     "archetype":    StringName     # documentation tag (see ARCHETYPES)
##     "duration":     float          # for cross-check vs the actual Animation
##     "keyframes":    Array[Dictionary]
##   }
##   keyframe: Dictionary {
##     "t":                float    # required — time within the animation
##     "phase":            StringName  # REST / WINDUP / STRIKE / RECOVERY / HOLD / etc.
##     "weapon_angle_deg": float    # global rotation of the weapon arm, in degrees.
##                                  # 0 = horizontal forward (+x), -90 = straight up,
##                                  # +90 = straight down. CW = positive in screen space.
##     "right_hand":       Vector2  # sprite-local (feet at 0,0)
##     "left_hand":        Vector2
##     "right_elbow":      Vector2
##     "left_elbow":       Vector2
##     "weapon_tip":       Vector2  # business-end (spear point / staff orb / etc.)
##     "weapon_butt":      Vector2  # back end of shaft (for visual disambiguation)
##     "tolerance_px":     float    # default 4.0 — distance threshold for PASS
##     "tolerance_deg":    float    # default 6.0 — angle threshold for PASS
##   }

## Motion archetype catalog. A documentation tag so each animation
## declares what KIND of motion it is — and so future sprites can be
## planned by archetype rather than by re-inventing from scratch.
const ARCHETYPES: Dictionary = {
	&"REST_BARE":         "Both arms at sides, no weapon engaged.",
	&"REST_TWO_HANDED":   "Weapon held in two hands at idle — pose holds across walk/idle.",
	&"WALK_BARE":         "Legs swing under body bob, arms swing opposite.",
	&"WALK_TWO_HANDED":   "Legs swing under body bob, arms locked on weapon.",
	&"THRUST_LINEAR":     "Single-arm forward thrust. Weapon TRANSLATES with the hand; weapon rotation stays ~0. Spear pattern.",
	&"ARC_OVERHEAD":      "Two-handed overhead arc. Weapon ROTATES through ~180° from rest → up-and-back → down-to-front. Staff pattern.",
	&"ARC_HORIZONTAL":    "Side-swing through horizontal. Weapon rotates ~120° in body plane. (Not yet used.)",
	&"CHARGE_RELEASE":    "Two-stage: draw back + hold, then release. Bow pattern.",
	&"CONDUIT_LIFT":      "Weapon raised vertical, held, lowered. Caster pattern (Pythia cast).",
	&"FLICK_FORWARD":     "Short snappy single-arm point. Wand pattern.",
	&"FALLBACK_PUNCH":    "Bare-hands jab. Used when no weapon equipped.",
}

# =========================================================================
# Per-class specs
# =========================================================================

const SPECS: Dictionary = {
	&"myrmidon": {
		&"attack_spear": {
			"archetype": &"THRUST_LINEAR",
			"duration": 0.85,
			"keyframes": [
				{ "t": 0.00, "phase": &"REST",
				  "weapon_angle_deg": 0.0,
				  "right_hand": Vector2(9, -24),
				},
				# At strike, the right shoulder rotates -0.50 rad. That
				# rotation propagates through the chain to the SpearArm,
				# so the world weapon angle is -0.50 rad = -28.6° (not
				# 0°). Right hand swings to (~18.6, -26.4); spear tip
				# follows the rotated chain to (~58, -48). The spear
				# THRUSTS forward but on a slightly downward angle —
				# from the body's perspective, that's pointing the
				# spear toward an enemy on the ground (lower than the
				# torso), which is what the "stab a man-sized target"
				# attack should do at hip-height grip.
				{ "t": 0.46, "phase": &"STRIKE",
				  "weapon_angle_deg": -28.6,
				  "right_hand": Vector2(19, -26),
				  "weapon_tip": Vector2(58, -48),
				  "tolerance_px": 5.0,
				  "tolerance_deg": 4.0,
				},
				{ "t": 0.85, "phase": &"REST",
				  "weapon_angle_deg": 0.0,
				  "right_hand": Vector2(9, -24),
				},
			],
		},
	},
	&"pythia": {
		# Bare-hands variants — minimal spec, just confirm REST position.
		&"idle_bare": {
			"archetype": &"REST_BARE",
			"duration": 2.0,
			"keyframes": [
				{ "t": 0.00, "phase": &"REST" },
				{ "t": 2.00, "phase": &"REST" },
			],
		},
		# Two-handed staff idle — the pose that's been fighting us.
		# Targets calibrated so:
		#   - Right hand at hip on the staff grip (9, -24)
		#   - Staff at -60° world (more vertical than -45°, not pure
		#     vertical)
		#   - Orb up near head height
		#   - LeftGrip (cosmetic on staff at staff-local +11) sits on
		#     the upper shaft; left hand should LAND on/near it
		# Post-photo swap: RIGHT arm anchors the staff at hip-forward
		# (lower grip), LEFT arm IK-pinned to LeftGrip cosmetic at the
		# upper grip. Staff at world -135° (diagonal, orb upper-back-
		# left, butt lower-forward-right).
		#   R hand polygon centroid (anchor at hip):  ≈ (9, -24)
		#   StaffArm origin (= R hand position):       ≈ (9, -24)
		#   At staff world angle -135°:
		#     LeftGrip cosmetic (staff-local +11, 0)  ≈ (1.22, -31.78)
		#     Orb        (staff-local +29.5, 0)       ≈ (-11.86, -44.86)
		#     Butt       (staff-local -22, 0)         ≈ (24.55, -8.45)
		#   L arm IK lands hand near LeftGrip ≈ (1, -32).
		&"idle_staff": {
			"archetype": &"REST_TWO_HANDED",
			"duration": 2.0,
			"keyframes": [
				{ "t": 0.00, "phase": &"REST",
				  "weapon_angle_deg": -135.0,
				  "right_hand":  Vector2(9, -24),
				  "left_hand":   Vector2(1, -32),
				  "weapon_tip":  Vector2(-12, -45),
				  "weapon_butt": Vector2(24, -8),
				  "tolerance_px": 4.0,
				},
				{ "t": 2.00, "phase": &"REST",
				  "weapon_angle_deg": -135.0,
				  "right_hand":  Vector2(9, -24),
				  "left_hand":   Vector2(1, -32),
				  "weapon_tip":  Vector2(-12, -45),
				},
			],
		},
		&"walk_staff": {
			"archetype": &"WALK_TWO_HANDED",
			"duration": 0.6,
			"keyframes": [
				{ "t": 0.00, "phase": &"REST",
				  "weapon_angle_deg": -135.0,
				  "right_hand":  Vector2(9, -24),
				  "left_hand":   Vector2(1, -32),
				  "weapon_tip":  Vector2(-12, -45),
				  "tolerance_px": 6.0,
				},
				{ "t": 0.30, "phase": &"REST",
				  "weapon_angle_deg": -135.0,
				  "right_hand":  Vector2(9, -24),
				  "left_hand":   Vector2(1, -32),
				  "weapon_tip":  Vector2(-12, -45),
				  "tolerance_px": 6.0,
				},
			],
		},
		# BOP attack: small overhead lift. Staff goes from rest -135°
		# (orb upper-back-left) to apex -90° (orb directly above head)
		# and back. Conservative range keeps the L hand within IK reach.
		&"attack_staff": {
			"archetype": &"ARC_OVERHEAD",
			"duration": 0.55,
			"keyframes": [
				{ "t": 0.00, "phase": &"REST",
				  "weapon_angle_deg": -135.0,
				  "right_hand":  Vector2(9, -24),
				  "weapon_tip":  Vector2(-12, -45),
				},
				{ "t": 0.25, "phase": &"STRIKE",
				  # World -90° → orb at (9 + 29.5*0, -24 + 29.5*-1) ≈ (9, -54)
				  "weapon_angle_deg": -90.0,
				  "weapon_tip":  Vector2(9, -54),
				  "tolerance_px": 5.0,
				},
				{ "t": 0.55, "phase": &"REST",
				  "weapon_angle_deg": -135.0,
				  "right_hand":  Vector2(9, -24),
				  "weapon_tip":  Vector2(-12, -45),
				},
			],
		},
		&"cast_staff": {
			"archetype": &"CONDUIT_LIFT",
			"duration": 0.85,
			"keyframes": [
				{ "t": 0.00, "phase": &"REST",
				  "weapon_angle_deg": -135.0,
				  "weapon_tip":  Vector2(-12, -45),
				},
				{ "t": 0.30, "phase": &"HOLD",
				  "weapon_angle_deg": -90.0,
				},
				{ "t": 0.85, "phase": &"REST",
				  "weapon_angle_deg": -135.0,
				  "weapon_tip":  Vector2(-12, -45),
				},
			],
		},
	},
}

# =========================================================================
# Helpers — used by sprite_render verifier
# =========================================================================

## Returns the spec for (class_id, variant_name), or {} if none.
static func spec_for(class_id: StringName, variant_name: StringName) -> Dictionary:
	var per_class: Dictionary = SPECS.get(class_id, {})
	return per_class.get(variant_name, {})

static func archetype_description(arch: StringName) -> String:
	return ARCHETYPES.get(arch, "(unknown archetype)")
