class_name BowStances extends Object
## Stage 17.8 — catalog of candidate bow stances.
##
## Each entry describes a complete bow stance: BowArm position on the
## body, nock travel range, IK pin overrides, and any per-stance anim
## tuning. A class sprite picks ONE stance via STANCE_ID and the
## ShadeHunter rig assembles itself from the catalog row.
##
## Why a catalog: the user said "create a string of possibilities I
## can score, so the system learns which patterns work." Each row is a
## scoreable candidate; tmp/stance_scores.json accumulates ratings so
## future agent runs bias toward high-scored entries. Validated by
## AnatomyValidator so every row in the catalog provably reaches.
##
## ===== Stance row schema =====
##   id: StringName              # unique catalog key
##   description: String         # human-readable summary
##   bow_arm_pos: Vector2        # body-local BowArm placement
##   bow_arm_rot: float          # body-local BowArm rotation (radians)
##   nock_rest: Vector2          # bow-local nock at rest
##   nock_drawn: Vector2         # bow-local nock at full draw
##   pin_overrides: Array        # PIN_TABLE entries that override the
##                               # sprite default (e.g. swap R/L roles)
##   draw_frac: float            # CHARGE_RELEASE timing
##   release_frac: float
##   attack_len: float

const STANCES: Dictionary = {
	# Stage 17.7 default — bow held forward at shoulder height, R hand
	# on riser, L hand pulls string. Conservative reach (BowArm 22,-42
	# = R-shoulder-distance ~13).
	# draw_hand: which hand pulls the string. Drives PIN_TABLE setup
	# (other hand goes on the riser) AND which shoulder gets the
	# charge_release rotation hint during attack.
	&"forward_high_ready": {
		"id": &"forward_high_ready",
		"description": "Bow held forward at shoulder height; R grips riser, L on string. Classic side-view archer pose.",
		"bow_arm_pos": Vector2(22, -42),
		"bow_arm_rot": 0.0,
		"nock_rest":  Vector2(-12, 0),
		"nock_drawn": Vector2(-19, 0),
		"draw_frac":    0.30,
		"release_frac": 0.75,
		"attack_len":   0.9,
		"draw_hand":    "left",     # L hand draws; R holds bow
	},
	# Same geometry but right-handed archer (R draws, L holds bow).
	# Useful for left-facing variants of the sprite.
	&"forward_high_ready_RH": {
		"id": &"forward_high_ready_RH",
		"description": "Forward-high-ready, swapped hands. L grips riser, R draws string. Right-handed archer.",
		"bow_arm_pos": Vector2(-22, -42),
		"bow_arm_rot": 0.0,
		"nock_rest":  Vector2(12, 0),
		"nock_drawn": Vector2(19, 0),
		"draw_frac":    0.30,
		"release_frac": 0.75,
		"attack_len":   0.9,
		"draw_hand":    "right",
	},
	# Lower-ready: bow at hip level pointing diagonally up. Bow arm
	# bent more, draw arm has further to travel.
	&"low_ready_diag": {
		"id": &"low_ready_diag",
		"description": "Bow at hip-front pointed diagonally up. R arm at hip, L arm drops to chest at full draw.",
		"bow_arm_pos": Vector2(16, -28),
		"bow_arm_rot": -0.45,   # ~-26° world tilt
		"nock_rest":  Vector2(-10, 0),
		"nock_drawn": Vector2(-17, 0),
		"draw_frac":    0.32,
		"release_frac": 0.75,
		"attack_len":   1.0,
		"draw_hand":    "left",
	},
	# Aimed-high: bow raised above shoulder, R arm extended upward.
	# Tests upper reach envelope.
	&"high_aim": {
		"id": &"high_aim",
		"description": "Bow raised above shoulder line. Aimed high — sniping pose. R arm reaches up-and-forward.",
		"bow_arm_pos": Vector2(20, -52),
		"bow_arm_rot": 0.0,
		"nock_rest":  Vector2(-12, 0),
		"nock_drawn": Vector2(-18, 0),
		"draw_frac":    0.28,
		"release_frac": 0.78,
		"attack_len":   0.85,
		"draw_hand":    "left",
	},
}

## Default stance — the one a class sprite uses if it doesn't override.
const DEFAULT_STANCE: StringName = &"forward_high_ready"

## Look up a stance by id; returns the default if not found.
static func get_stance(id: StringName) -> Dictionary:
	return STANCES.get(id, STANCES[DEFAULT_STANCE])

## All stance ids in declaration order — used by pose_tuner F3 cycle.
static func all_ids() -> Array:
	return STANCES.keys()
