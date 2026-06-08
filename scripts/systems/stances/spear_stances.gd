class_name SpearStances extends Object
## Stage 17.8 — catalog of candidate spear stances.
##
## Spear is a ONE-HANDED weapon in Myrmidon's spear+shield posture and
## TWO-HANDED when no shield is equipped. Each stance documents which
## profile it targets. Pin requirements differ: shielded = R hand on
## spear, L hand on buckler; two-handed = both on spear shaft.
##
## ===== Stance row schema =====
##   id, description, profile (&"shield" or &"two_handed")
##   spear_pos, spear_rot          # body-local
##   right_grip                    # spear-local marker for R hand
##   left_grip                     # spear-local marker for L hand (optional)
##   thrust_reach: Vector2         # spear position at thrust apex (body-local)
##   attack_len: float

const STANCES: Dictionary = {
	# Current Myrmidon spear+shield default. R hand grips spear at
	# hip-level; spear horizontal pointing forward.
	# R grip dist from R shoulder = sqrt(0+400)=20 at hip. Marginal —
	# spear position equals R hand position by tree (no marker offset).
	&"hip_spear_shield_legacy": {
		"id": &"hip_spear_shield_legacy",
		"description": "Stage 17.5 stance: R hand at hip, spear horizontal forward, L hand holds buckler. Hoplite plant-and-thrust profile.",
		"profile":      &"shield",
		"spear_pos":    Vector2(9, -24),   # = R hand at hip
		"spear_rot":    0.0,
		"right_grip":   Vector2(0, 0),
		"left_grip":    Vector2.ZERO,       # N/A — L on shield
		"thrust_reach": Vector2(28, -24),   # +19px forward at apex
		"attack_len":   0.85,
	},
	# Two-handed couched: spear held at chest with both hands; thrust
	# from the chest. More phalanx-style.
	# R grip body-local (8, -36): R shoulder→here sqrt(1+64)=8.06. ✓
	# L grip body-local (-2, -36): L shoulder→here sqrt(49+64)=10.6. ✓
	&"chest_couched_two_handed": {
		"id": &"chest_couched_two_handed",
		"description": "Spear couched at chest with both hands. Two-handed thrust from the rib line, no shield. Wider stance, longer reach.",
		"profile":      &"two_handed",
		"spear_pos":    Vector2(8, -36),
		"spear_rot":    0.0,
		"right_grip":   Vector2(0, 0),
		"left_grip":    Vector2(-10, 0),    # forward grip
		"thrust_reach": Vector2(28, -36),
		"attack_len":   0.75,
	},
	# Overhand: spear held above shoulder, point down for stabbing
	# downward (anti-cavalry, javelin-throw setup).
	# R grip body-local (12, -50): R shoulder→here sqrt(9+36)=6.7. ✓
	&"overhand_javelin": {
		"id": &"overhand_javelin",
		"description": "Spear held overhand above shoulder, point angled down-forward. Javelin throw / downward stab. R arm raised; L free for shield or counterbalance.",
		"profile":      &"shield",
		"spear_pos":    Vector2(12, -50),
		"spear_rot":    0.6,                 # ~+34° (point down-forward)
		"right_grip":   Vector2(0, 0),
		"left_grip":    Vector2.ZERO,
		"thrust_reach": Vector2(20, -42),
		"attack_len":   0.7,
	},
}

const DEFAULT_STANCE: StringName = &"hip_spear_shield_legacy"

static func get_stance(id: StringName) -> Dictionary:
	return STANCES.get(id, STANCES[DEFAULT_STANCE])

static func all_ids() -> Array:
	return STANCES.keys()
