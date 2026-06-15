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

## Stage 17.6 (rules/sprite-animation.md) locked the roster to FIVE
## species. HUMANOID + FLYING below are LEGACY/DEPRECATED enum entries
## only — no sprite may register to them; they survive so the older
## stage17_5 verifier keeps resolving and are slated for removal once
## nothing references them. Locomotion (winged / floating / quadruped)
## is a sub-variant, not a species. New entries added at the END so
## existing integer mappings are never shuffled.
enum Family {
	HUMAN,     ## Species. 4 player classes + town NPCs. No visible ribcage.
	HUMANOID,  ## LEGACY — collapses into HUMAN + skin. Do not register.
	UNDEAD,    ## Species. Skeleton / revenant / wraith sub-variants.
	BEAST,     ## Species. Quadruped base; winged sub-variant.
	DEMON,     ## Species. Infernal HUMAN-base + horns/hooves.
	FLYING,    ## LEGACY — now the `winged` sub-variant. Do not register.
	CONSTRUCT, ## Species. HUMAN-base + segmented joints, metallic skin.
}

## The five live species (excludes the two legacy entries above).
const SPECIES: Array = [
	Family.HUMAN, Family.UNDEAD, Family.BEAST, Family.DEMON, Family.CONSTRUCT,
]

const LEGACY_FAMILIES: Array = [Family.HUMANOID, Family.FLYING]

## REVENANT added Stage 17.6 (decayed HUMAN rig). SKELETON + WRAITH
## unchanged so the legacy verifier's int comparisons still hold.
enum UndeadSubtype { SKELETON, WRAITH, REVENANT }

## Canonical six animations every character must build. These are the
## names the live codebase plays (player.gd / enemy.gd / act_boss.gd /
## bone_servant_minion.gd / sprite_runtime_2d.gd) and AD-11. NEVER
## rename — that orphans every caller and every AnimationPlayer track.
const CANONICAL_ANIMS: Array = [&"idle", &"walk", &"attack", &"cast", &"hit", &"die"]

## Named animation profiles. A character's `anim_set` selects how the
## six canonical anims are built for its body type / temperament.
## Declaration only — the build still flows through baseline_white_sprite
## / SpriteRuntime2D / SpriteMotionStances. The `stance` is the default
## SpriteMotionStances posture the profile leans on.
const ANIM_SETS: Dictionary = {
	&"human_default":   { "stance": &"idle_breathe",      "legs": true,  "rigid": false, "note": "baseline biped" },
	&"wraith_float":    { "stance": &"enemy_idle_haunt",  "legs": false, "rigid": false, "note": "no leg motion; hem + cloak drift; vertical bob" },
	&"quadruped":       { "stance": &"enemy_walk_stalk",  "legs": true,  "rigid": false, "note": "four-leg gait, head-lead" },
	&"construct_rigid": { "stance": &"enemy_idle_watch",  "legs": true,  "rigid": true,  "note": "stiff interpolation, mechanical attack arc" },
}

## Default anim_set per species (sub-variants may override per entry).
const SPECIES_DEFAULT_ANIM_SET: Dictionary = {
	Family.HUMAN:     &"human_default",
	Family.UNDEAD:    &"human_default",   # skeleton/revenant; wraith overrides
	Family.BEAST:     &"quadruped",
	Family.DEMON:     &"human_default",
	Family.CONSTRUCT: &"construct_rigid",
}

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
		# LEGACY enum entry — retained for the stage17_5 verifier only.
		# The winged silhouette is now the `winged` sub-variant of
		# BEAST/DEMON. Do not register sprites here.
		&"Head", &"Neck", &"Torso",
		&"WingUpperL", &"WingLowerL",
		&"WingUpperR", &"WingLowerR",
		&"ClawL", &"ClawR", &"Tail",
	],
	# CONSTRUCT (Stage 17.6): HUMAN biped skeleton with segmented joints
	# and a faceplate instead of a face. Same part *names* as HUMAN where
	# the joint maps 1:1 so the HUMAN anim_set tracks bind unchanged; the
	# `construct_rigid` anim_set is what reads as mechanical, not the rig.
	Family.CONSTRUCT: [
		&"Head", &"Neck", &"Torso", &"Hips",
		&"UpperArmL", &"ForearmL", &"HandL",
		&"UpperArmR", &"ForearmR", &"HandR",
		&"ThighL", &"ShinL", &"FootL",
		&"ThighR", &"ShinR", &"FootR",
		&"Faceplate", &"CoreGlow",
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
	&"shade_wretch":   { "family": Family.UNDEAD, "subtype": UndeadSubtype.WRAITH, "anim_set": &"wraith_float" },
	&"bog_caller":     { "family": Family.UNDEAD, "subtype": UndeadSubtype.WRAITH, "anim_set": &"wraith_float" },
	# UNDEAD — revenant subtype (Phase 1b): HUMAN rig + decayed flesh.
	&"revenant":       { "family": Family.UNDEAD, "subtype": UndeadSubtype.REVENANT },
	# DEMON — first Act-boss demon, bespoke six-arm rig.
	&"act_boss": {
		"family": Family.DEMON,
		"bespoke": true,
		"display_name": "Hexacheir, the God-Spurned",
		"identity_note": "Six oath-hands, one contempt for every pact the living still believe will protect them.",
	},
	# Per-unique-boss bespoke entries retained for non-final rare/unique routing.
	&"hekate_marked":  {
		"bespoke": true,
		"display_name": "Hekate-Marked Forsaken",
	},
}

## Roster summary under the `sprite` debug flag (run with
## `--debug=sprite`). Lets the dev confirm the species/anim_set spine
## loaded as expected without opening a scene. Full visual previewer
## (cycle every CharacterDef + its six anims) lands with Stage 17.7.
func _ready() -> void:
	if DebugLog == null or not DebugLog.is_enabled(&"sprite"):
		return
	var lines: Array[String] = []
	lines.append("species roster (5): %s" % ", ".join(
			species_list().map(func(f): return family_name(f))))
	for id in ENTRIES.keys():
		var fam := family_of(id)
		var sub := sub_variant_name(id)
		var suffix := "" if sub == "" else "/%s" % sub
		lines.append("  %s -> %s%s  anim_set=%s%s" % [
				id, family_name(fam), suffix, anim_set_for(id),
				"  [bespoke]" if is_bespoke(id) else ""])
	DebugLog.write(&"sprite", "AnatomyFamilies:\n" + "\n".join(lines))

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
		Family.HUMAN:     return "HUMAN"
		Family.HUMANOID:  return "HUMANOID"
		Family.UNDEAD:    return "UNDEAD"
		Family.BEAST:     return "BEAST"
		Family.DEMON:     return "DEMON"
		Family.FLYING:    return "FLYING"
		Family.CONSTRUCT: return "CONSTRUCT"
	return "UNKNOWN"

# =========================================================================
# Stage 17.6 — species + anim_set accessors (rules/sprite-animation.md)
# =========================================================================

## The five live species (excludes the two legacy enum entries).
func species_list() -> Array:
	return SPECIES.duplicate()

## True if `fam` is one of the five locked species (not HUMANOID/FLYING).
func is_species(fam: int) -> bool:
	return fam in SPECIES

## True if `fam` is a deprecated/legacy family that no sprite may use.
func is_legacy_family(fam: int) -> bool:
	return fam in LEGACY_FAMILIES

## Human-readable sub-variant for a registered sprite, e.g. "skeleton",
## "wraith", "revenant". "" when the species has no sub-variant axis or
## the sprite is bespoke/unregistered.
func sub_variant_name(sprite_id: StringName) -> String:
	var e := entry_for(sprite_id)
	if e.is_empty() or e.get("bespoke", false):
		return ""
	if e.has("sub_variant"):
		return String(e["sub_variant"])
	if int(e.get("family", -1)) == Family.UNDEAD:
		match int(e.get("subtype", -1)):
			UndeadSubtype.SKELETON: return "skeleton"
			UndeadSubtype.WRAITH:   return "wraith"
			UndeadSubtype.REVENANT: return "revenant"
	return ""

## The anim_set name a registered sprite builds against. Resolution
## order: explicit entry `anim_set` → species default → human_default.
## Bespoke bosses fall back to human_default unless they declare one.
func anim_set_for(sprite_id: StringName) -> StringName:
	var e := entry_for(sprite_id)
	if e.has("anim_set"):
		return e["anim_set"]
	var fam: int = int(e.get("family", -1))
	return SPECIES_DEFAULT_ANIM_SET.get(fam, &"human_default")

## True if the given anim_set name is a declared profile.
func has_anim_set(set_id: StringName) -> bool:
	return ANIM_SETS.has(set_id)
