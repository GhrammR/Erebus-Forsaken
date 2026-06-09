class_name SpriteMotionStances extends Object
## Generic motion stance catalog for enemies and NPCs.
## These rows tune animation timing/amplitude without changing each
## sprite's silhouette-specific polygon data.

const STANCES: Dictionary = {
	&"idle_breathe": {
		"id": &"idle_breathe",
		"description": "Neutral breathing stance with small vertical bob and minimal sway.",
		"idle_len": 1.6,
		"idle_bob": -1.2,
		"idle_sway": 0.015,
		"walk_len": 0.55,
		"walk_bob": -2.0,
		"walk_sway": 0.06,
		"attack_len": 0.42,
		"attack_rot": -0.85,
		"cast_len": 0.65,
		"cast_pulse": 1.5,
	},
	&"wraith_lunge": {
		"id": &"wraith_lunge",
		"description": "Fast spectral lunge with sharper arm/claw arcs and a tighter walk loop.",
		"idle_len": 1.2,
		"idle_bob": -1.8,
		"idle_sway": 0.035,
		"walk_len": 0.40,
		"walk_bob": -2.4,
		"walk_sway": 0.10,
		"attack_len": 0.34,
		"attack_rot": -1.25,
		"cast_len": 0.45,
		"cast_pulse": 1.35,
	},
	&"caster_channel": {
		"id": &"caster_channel",
		"description": "Measured caster motion with pronounced glow pulses and slower attacks.",
		"idle_len": 1.8,
		"idle_bob": -1.0,
		"idle_sway": 0.02,
		"walk_len": 0.62,
		"walk_bob": -1.8,
		"walk_sway": 0.045,
		"attack_len": 0.48,
		"attack_rot": -0.95,
		"cast_len": 0.80,
		"cast_pulse": 1.9,
	},
	&"merchant_idle": {
		"id": &"merchant_idle",
		"description": "Town NPC idle stance with restrained breathing and no combat snap.",
		"idle_len": 2.0,
		"idle_bob": -0.8,
		"idle_sway": 0.012,
		"walk_len": 0.70,
		"walk_bob": -1.2,
		"walk_sway": 0.03,
		"attack_len": 0.50,
		"attack_rot": -0.35,
		"cast_len": 0.75,
		"cast_pulse": 1.25,
	},
	&"boss_command": {
		"id": &"boss_command",
		"description": "Large boss command stance with heavy breathing and broad arm authority.",
		"idle_len": 1.9,
		"idle_bob": -2.4,
		"idle_sway": 0.025,
		"walk_len": 0.65,
		"walk_bob": -2.6,
		"walk_sway": 0.07,
		"attack_len": 0.55,
		"attack_rot": -1.45,
		"cast_len": 0.90,
		"cast_pulse": 2.0,
	},
}

const DEFAULT_STANCE: StringName = &"idle_breathe"

static func get_stance(id: StringName) -> Dictionary:
	return STANCES.get(id, STANCES[DEFAULT_STANCE])

static func all_ids() -> Array:
	return STANCES.keys()
