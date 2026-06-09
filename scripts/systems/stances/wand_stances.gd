class_name WandStances extends Object
## Stance catalog for Ossuary Priest one-handed wand geometry.
## Rows drive WandArm placement, rest rotation, and attack/cast apexes.

const STANCES: Dictionary = {
	&"low_wand_guard": {
		"id": &"low_wand_guard",
		"description": "Wand held low-right beside the robe, ready for a quick bone-needle poke.",
		"wand_pos": Vector2(10, -28),
		"wand_rot": 0.0,
		"attack_apex_rot": -0.45,
		"cast_apex_rot": -0.80,
		"attack_len": 0.34,
		"cast_len": 0.65,
	},
	&"raised_wand_channel": {
		"id": &"raised_wand_channel",
		"description": "Wand raised near the skull for summoning and curse channels.",
		"wand_pos": Vector2(9, -38),
		"wand_rot": -0.45,
		"attack_apex_rot": -1.05,
		"cast_apex_rot": -1.35,
		"attack_len": 0.42,
		"cast_len": 0.75,
	},
	&"cross_body_ward": {
		"id": &"cross_body_ward",
		"description": "Wand crosses the torso as a defensive ward before snapping outward.",
		"wand_pos": Vector2(5, -34),
		"wand_rot": 0.55,
		"attack_apex_rot": -0.75,
		"cast_apex_rot": -1.10,
		"attack_len": 0.40,
		"cast_len": 0.70,
	},
}

const DEFAULT_STANCE: StringName = &"low_wand_guard"

static func get_stance(id: StringName) -> Dictionary:
	return STANCES.get(id, STANCES[DEFAULT_STANCE])

static func all_ids() -> Array:
	return STANCES.keys()
