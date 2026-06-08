class_name StaffStances extends Object
## Stage 17.8 — catalog of candidate staff stances.
##
## Each row is a complete two-handed staff stance: the staff's tree
## position, rotation, marker placements for R+L grip, and any anim
## tuning. Pythia's sprite reads STANCE_ID and applies the row at
## _ready. Cycle in pose_tuner with F3; score with 1-5.
##
## Geometry note: HumanRig arm reach is ~20px. For both hands to grip
## the staff with proper anatomy, BOTH grip markers must sit within
## 20px of their respective shoulders (R at (9,-44), L at (-9,-44)).
## Each candidate below documents its R/L reach calc so the validator
## can confirm.
##
## ===== Stance row schema =====
##   id: StringName
##   description: String
##   # The staff is a sibling under Body — these define its placement:
##   staff_pos: Vector2          # body-local position of staff origin
##   staff_rot: float            # body-local rotation (radians)
##   right_grip: Vector2         # staff-local marker for R hand
##   left_grip:  Vector2         # staff-local marker for L hand
##   attack_apex_rot: float      # staff rotation at strike (radians)
##   attack_len: float
##   # Pin elbow directions:
##   right_elbow_dir: int
##   left_elbow_dir: int

const STANCES: Dictionary = {
	# Legacy stance — matches current Pythia behavior. R hand anchors
	# the staff at hip (reparenting under R hand pivot); L hand
	# OVEREXTENDS to reach LeftGrip. Marked legacy so the user can
	# compare against newer candidates and confirm they're better.
	# Reach: R grip ~0 from R hand (anchor), L grip 22-35px from L
	# shoulder during swing → soft-pinned.
	&"diagonal_back_legacy": {
		"id": &"diagonal_back_legacy",
		"description": "Stage 17.6 stance: R hand at hip, staff diagonal up-back to upper-left. L hand reaches across to upper grip. Anatomically marginal — soft-pin only.",
		"staff_pos":   Vector2(9, -24),    # R hand position
		"staff_rot":   -2.356,             # world -135°
		"right_grip":  Vector2(0, 0),      # at staff origin
		"left_grip":   Vector2(11, 0),
		"attack_apex_rot": -1.571,         # world -90° (vertical)
		"attack_len":   0.55,
		"right_elbow_dir": 1,
		"left_elbow_dir":  -1,
	},
	# Chest grip: staff held horizontally across chest, both hands
	# centered. Anatomically clean — both grips well within reach.
	# R grip at body-local (6, -38) — dist from R shoulder = sqrt(9+36)=6.7. ✓
	# L grip at body-local (-6, -38) — dist from L shoulder = sqrt(9+36)=6.7. ✓
	&"chest_horizontal_guard": {
		"id": &"chest_horizontal_guard",
		"description": "Staff held horizontally across chest at sternum height. Both hands wide on the shaft, classic quarterstaff guard.",
		"staff_pos":   Vector2(0, -38),
		"staff_rot":   0.0,                # horizontal
		"right_grip":  Vector2(6, 0),
		"left_grip":   Vector2(-6, 0),
		"attack_apex_rot": -1.0,           # rotate ~-57° for an overhead strike
		"attack_len":   0.6,
		"right_elbow_dir": 1,
		"left_elbow_dir":  -1,
	},
	# Diagonal high guard: staff at 45° across torso, head end up over
	# left shoulder. R hand low-right, L hand high-left.
	# R grip world: (0,-32) + rotate(7,0,-0.785) = (0,-32)+(4.95,-4.95)=(4.95,-36.95). R shoulder→here = sqrt(16+80)≈9.8. ✓
	# L grip world: (0,-32) + rotate(-7,0,-0.785) = (-4.95,-27.05). L shoulder→here=sqrt(16+286)≈17.4. ✓
	&"diagonal_high_guard": {
		"id": &"diagonal_high_guard",
		"description": "Staff diagonal across the torso, head-end above left shoulder. R hand near right hip, L hand at upper-left shoulder line.",
		"staff_pos":   Vector2(0, -32),
		"staff_rot":   -0.785,             # -45°
		"right_grip":  Vector2(7, 0),
		"left_grip":   Vector2(-7, 0),
		"attack_apex_rot": 0.0,            # rotate to horizontal for a side-swing
		"attack_len":   0.7,
		"right_elbow_dir": 1,
		"left_elbow_dir":  -1,
	},
}

const DEFAULT_STANCE: StringName = &"diagonal_back_legacy"

static func get_stance(id: StringName) -> Dictionary:
	return STANCES.get(id, STANCES[DEFAULT_STANCE])

static func all_ids() -> Array:
	return STANCES.keys()
