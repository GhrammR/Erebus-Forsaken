class_name EnemyRegistry extends RefCounted
## Static lookup: enemy_id (StringName) -> packed scene. Used by
## SaveSystem to rehydrate enemies recorded in a save snapshot, and
## by the Stage 7 spawn director (Phase 3) to pick a scene by id
## without each caller hard-coding the res:// path.
##
## To add a new enemy type, set its scene's `enemy_id` and add an
## entry below. Phase 2 ships the wilderness roster only; future
## stages append as they introduce new mobs.

const SCENES: Dictionary = {
	&"shade_wretch": "res://scenes/enemies/shade_wretch.tscn",
	&"bog_caller": "res://scenes/enemies/bog_caller.tscn",
	&"act_boss": "res://scenes/enemies/act_boss.tscn",
}

## Stage 8 — elite modifiers loaded once and looked up by id during
## save snapshot rehydration. Keeps SaveSystem/Game ignorant of the
## modifier asset paths (parallel to SCENES above).
const ELITE_PATHS: Dictionary = {
	&"elite_fast":    "res://data/modifiers/elite_fast.tres",
	&"elite_tough":   "res://data/modifiers/elite_tough.tres",
	&"elite_spawner": "res://data/modifiers/elite_spawner.tres",
}

static func scene_for(id: StringName) -> PackedScene:
	var path: String = SCENES.get(id, "")
	if path == "":
		return null
	return load(path) as PackedScene

static func elite_modifier_for(id: StringName) -> EliteModifier:
	var path: String = ELITE_PATHS.get(id, "")
	if path == "":
		return null
	return load(path) as EliteModifier

static func elite_ids() -> Array:
	return ELITE_PATHS.keys()
