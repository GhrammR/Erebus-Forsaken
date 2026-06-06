extends Node
## Stage 17.5 — Anatomy family registry. Single source of truth for
## which sprite belongs to which anatomy family, and what part-name
## set that family is allowed to declare under `Body/`.
##
## Per-unique-boss bespoke entries register by sprite_id directly,
## not under a family — they may declare any part set.
##
## The registry does NOT instantiate sprites. It validates them.
## `EquipmentVisuals` overlays bind to the HUMAN part set only;
## other families never receive equipment overlays.

enum Family {
	HUMAN,     ## 4 player classes + town NPCs. No visible ribcage.
	HUMANOID,  ## Non-human mortals (satyrs, harpies). Stage 20 fills.
	UNDEAD,    ## Skeletons + wraiths. Two subtypes.
	BEAST,     ## Quadrupeds. Stage 20 fills.
	DEMON,     ## Infernal HUMAN-base + horns/hooves. Stage 20 fills.
	FLYING,    ## Winged. Reduced/no legs. Stage 20 fills.
}

enum UndeadSubtype { SKELETON, WRAITH }

## Per-family canonical part list (declared under `Body/`). A sprite
## may omit individual parts (a one-armed enemy, an eyeless skull)
## but may NOT introduce parts outside its family's list. Verifier
## asserts both directions: the sprite has none-of-the-forbidden,
## and the family's required-core subset is present.
const PARTS: Dictionary = {
	Family.HUMAN: [
		&"Head", &"Neck", &"Torso", &"Hips",
		&"UpperArmL", &"ForearmL", &"HandL",
		&"UpperArmR", &"ForearmR", &"HandR",
		&"ThighL", &"ShinL", &"FootL",
		&"ThighR", &"ShinR", &"FootR",
	],
	Family.HUMANOID: [
		# HUMAN base + reserved monstrous slots. Stage 20 fills.
		&"Head", &"Neck", &"Torso", &"Hips",
		&"UpperArmL", &"ForearmL", &"HandL",
		&"UpperArmR", &"ForearmR", &"HandR",
		&"ThighL", &"ShinL", &"FootL",
		&"ThighR", &"ShinR", &"FootR",
		&"HornL", &"HornR", &"Tail",
	],
	# UNDEAD has two subtypes — kept in separate constants below
	# because their part sets do not overlap.
	Family.BEAST: [
		&"Head", &"NeckBeast", &"BodyTrunk", &"Tail",
		&"LegFrontL", &"LegFrontR", &"LegBackL", &"LegBackR",
	],
	Family.DEMON: [
		&"Head", &"Neck", &"Torso", &"Hips",
		&"UpperArmL", &"ForearmL", &"HandL",
		&"UpperArmR", &"ForearmR", &"HandR",
		&"ThighL", &"ShinL", &"HoofL",
		&"ThighR", &"ShinR", &"HoofR",
		&"HornL", &"HornR", &"WingAnchorL", &"WingAnchorR",
	],
	Family.FLYING: [
		&"Head", &"Neck", &"Torso",
		&"WingUpperL", &"WingLowerL",
		&"WingUpperR", &"WingLowerR",
		&"ClawL", &"ClawR", &"Tail",
	],
}

const UNDEAD_SKELETON_PARTS: Array = [
	&"Skull", &"Jaw", &"Spine", &"Pelvis",
	&"Rib1", &"Rib2", &"Rib3", &"Sternum", &"HipCloth",
	&"LegL", &"LegR",
	&"ArmUpper", &"ArmLower", &"Claw",  # current Bone Servant rig
]

const UNDEAD_WRAITH_PARTS: Array = [
	&"Hood", &"Cloak", &"CloakInner", &"TatteredHem",
	&"FaceVoid", &"EyeL", &"EyeR",
	&"ShoulderL", &"ShoulderR",
	&"UpperArmL", &"UpperArmR",
	&"ForearmL", &"ForearmR",
	&"ClawL", &"ClawR",
]

## Sprite ID -> registry entry. Each entry declares the sprite's
## family + (for UNDEAD) subtype, and optionally a bespoke part
## list when the sprite is a per-unique-boss anatomy.
## `bespoke_parts` (when present) overrides the family part list
## for that sprite. Used only by unique bosses.
const ENTRIES: Dictionary = {
	# HUMAN — players
	&"myrmidon":       { "family": Family.HUMAN },
	&"pythia":         { "family": Family.HUMAN },
	&"shade_hunter":   { "family": Family.HUMAN },
	&"ossuary_priest": { "family": Family.HUMAN },
	# HUMAN — town NPCs
	&"kallias":        { "family": Family.HUMAN },
	&"eurynome":       { "family": Family.HUMAN },
	# UNDEAD — skeleton subtype (anchor, unchanged)
	&"bone_servant":   { "family": Family.UNDEAD, "subtype": UndeadSubtype.SKELETON },
	# UNDEAD — wraith subtype (new anatomy this stage)
	&"shade_wretch":   { "family": Family.UNDEAD, "subtype": UndeadSubtype.WRAITH },
	&"bog_caller":     { "family": Family.UNDEAD, "subtype": UndeadSubtype.WRAITH },
	# Per-unique-boss bespoke entries
	&"hekate_marked":  {
		"bespoke": true,
		"display_name": "Hekate-Marked Forsaken",
	},
}

func entry_for(sprite_id: StringName) -> Dictionary:
	return ENTRIES.get(sprite_id, {})

func is_registered(sprite_id: StringName) -> bool:
	return ENTRIES.has(sprite_id)

func is_bespoke(sprite_id: StringName) -> bool:
	var e := entry_for(sprite_id)
	return bool(e.get("bespoke", false))

func family_of(sprite_id: StringName) -> int:
	var e := entry_for(sprite_id)
	return int(e.get("family", -1))

func subtype_of(sprite_id: StringName) -> int:
	var e := entry_for(sprite_id)
	return int(e.get("subtype", -1))

## Returns the allowed part-name list for a registered sprite.
## Empty for bespoke entries (any parts allowed). Empty for
## unregistered sprite ids.
func allowed_parts(sprite_id: StringName) -> Array:
	var e := entry_for(sprite_id)
	if e.is_empty() or e.get("bespoke", false):
		return []
	var fam: int = e.get("family", -1)
	if fam == Family.UNDEAD:
		var sub: int = e.get("subtype", -1)
		if sub == UndeadSubtype.SKELETON:
			return UNDEAD_SKELETON_PARTS
		if sub == UndeadSubtype.WRAITH:
			return UNDEAD_WRAITH_PARTS
		return []
	return PARTS.get(fam, [])

## True if `part_name` is allowed under `Body/` for this sprite.
## Bespoke entries pass any name.
func is_part_allowed(sprite_id: StringName, part_name: StringName) -> bool:
	if is_bespoke(sprite_id):
		return true
	return part_name in allowed_parts(sprite_id)

func family_name(fam: int) -> String:
	match fam:
		Family.HUMAN:    return "HUMAN"
		Family.HUMANOID: return "HUMANOID"
		Family.UNDEAD:   return "UNDEAD"
		Family.BEAST:    return "BEAST"
		Family.DEMON:    return "DEMON"
		Family.FLYING:   return "FLYING"
	return "UNKNOWN"
