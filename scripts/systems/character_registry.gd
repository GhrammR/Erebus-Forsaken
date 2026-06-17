class_name CharacterRegistry extends Object
## Stage 17.7 — the CharacterDef registry. Single source of truth that
## maps a `character_id` to the full CharacterDef: which sprite scene to
## instantiate plus the data describing it. Species / sub_variant /
## anim_set come from AnatomyFamilies and the skin from SkinLibrary, so
## this registry AGGREGATES rather than duplicates — one record per
## character, the rest derived.
##
## (Code registry, consistent with AnatomyFamilies / SkinLibrary /
## SpriteMotionStances, rather than per-character .tres — see
## rules/sprite-animation.md §3.)
##
## ClassData.character_id and Enemy.character_id resolve their sprite
## through `scene_for()`; the existing `sprite_scene` export is the
## transitional fallback.

const SkinLibrary = preload("res://scripts/systems/skin_library.gd")

## character_id -> { scene, bucket, weapon, equipment_slots }
## (everything else is derived from AnatomyFamilies + SkinLibrary).
##   weapon: which weapon the rig holds (&"" = none).
##   equipment_slots: receives the Stage-15 paper-doll armor overlays
##     (HUMAN player classes only — NPCs/enemies never do, per §4).
const CHARACTERS: Dictionary = {
	&"myrmidon":       { "scene": "res://art/procedural/classes/myrmidon_sprite.tscn",      "bucket": &"classes", "weapon": &"spear", "equipment_slots": true },
	&"pythia":         { "scene": "res://art/procedural/classes/pythia_sprite.tscn",        "bucket": &"classes", "weapon": &"staff", "equipment_slots": true },
	&"shade_hunter":   { "scene": "res://art/procedural/classes/shade_hunter_sprite.tscn",  "bucket": &"classes", "weapon": &"bow",   "equipment_slots": true },
	&"ossuary_priest": { "scene": "res://art/procedural/classes/ossuary_priest_sprite.tscn","bucket": &"classes", "weapon": &"wand",  "equipment_slots": true },
	&"kallias":        { "scene": "res://art/procedural/npcs/kallias_sprite.tscn",          "bucket": &"npcs",    "weapon": &"",      "equipment_slots": false },
	&"eurynome":       { "scene": "res://art/procedural/npcs/eurynome_sprite.tscn",         "bucket": &"npcs",    "weapon": &"",      "equipment_slots": false },
	&"bone_servant":   { "scene": "res://art/procedural/enemies/bone_servant_sprite.tscn",  "bucket": &"enemies", "weapon": &"",      "equipment_slots": false },
	&"revenant":       { "scene": "res://art/procedural/enemies/revenant_sprite.tscn",      "bucket": &"enemies", "weapon": &"",      "equipment_slots": false },
	&"shade_wretch":   { "scene": "res://art/procedural/enemies/shade_wretch_sprite.tscn",  "bucket": &"enemies", "weapon": &"",      "equipment_slots": false },
	&"bog_caller":     { "scene": "res://art/procedural/enemies/bog_caller_sprite.tscn",    "bucket": &"enemies", "weapon": &"staff", "equipment_slots": false },
	&"act_boss":       { "scene": "res://art/procedural/enemies/act_boss_sprite.tscn",      "bucket": &"enemies", "weapon": &"",      "equipment_slots": false },
	&"fiend":          { "scene": "res://art/procedural/enemies/fiend_sprite.tscn",         "bucket": &"enemies", "weapon": &"",      "equipment_slots": false },
	&"bronze_sentinel":{ "scene": "res://art/procedural/enemies/sentinel_sprite.tscn",      "bucket": &"enemies", "weapon": &"",      "equipment_slots": false },
}

static func has(character_id: StringName) -> bool:
	return CHARACTERS.has(character_id)

static func ids() -> Array:
	return CHARACTERS.keys()

static func bucket(character_id: StringName) -> StringName:
	return (CHARACTERS.get(character_id, {}) as Dictionary).get("bucket", &"")

static func scene_path(character_id: StringName) -> String:
	return (CHARACTERS.get(character_id, {}) as Dictionary).get("scene", "")

static func scene_for(character_id: StringName) -> PackedScene:
	var p := scene_path(character_id)
	return load(p) as PackedScene if p != "" else null

## Instantiate the fully-built character. The scene encodes its
## sprite_id + stance_bucket, so its _ready applies the skin, builds the
## anim_set, and selects the stance — no extra wiring needed here.
static func instantiate(character_id: StringName) -> Node2D:
	var packed := scene_for(character_id)
	return packed.instantiate() as Node2D if packed != null else null

## The aggregated CharacterDef: scene/bucket/weapon/equipment_slots from
## this registry + species/sub_variant/anim_set from AnatomyFamilies +
## has_skin from SkinLibrary. {} for an unknown id.
static func def(character_id: StringName) -> Dictionary:
	var c: Dictionary = CHARACTERS.get(character_id, {})
	if c.is_empty():
		return {}
	return {
		"id": character_id,
		"scene": c["scene"],
		"bucket": c["bucket"],
		"weapon": c.get("weapon", &""),
		"equipment_slots": c.get("equipment_slots", false),
		"species": AnatomyFamilies.family_of(character_id),
		"sub_variant": AnatomyFamilies.sub_variant_name(character_id),
		"anim_set": AnatomyFamilies.anim_set_for(character_id),
		"has_skin": SkinLibrary.has(character_id),
	}
