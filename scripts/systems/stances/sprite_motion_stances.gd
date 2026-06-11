class_name SpriteMotionStances extends Object
## Generic motion stance catalog for enemies and NPCs.
## Rows tune animation timing/amplitude without changing each sprite's
## silhouette-specific polygon data. Editor-facing rows are namespaced
## by sprite role so enemy, NPC, and future player motion rows do not
## bleed into one another.

const STANCES: Dictionary = {
	&"idle_breathe": {
		"id": &"idle_breathe",
		"description": "Neutral breathing stance with small vertical bob and minimal sway.",
		"idle_len": 1.6, "idle_bob": -1.2, "idle_sway": 0.015,
		"walk_len": 0.55, "walk_bob": -2.0, "walk_sway": 0.06,
		"attack_len": 0.42, "attack_rot": -0.85,
		"cast_len": 0.65, "cast_pulse": 1.5,
	},
	&"wraith_lunge": {
		"id": &"wraith_lunge",
		"description": "Fast spectral lunge with sharper arm/claw arcs and a tighter hover loop.",
		"idle_len": 1.2, "idle_bob": -1.8, "idle_sway": 0.035,
		"walk_len": 0.40, "walk_bob": -2.4, "walk_sway": 0.10,
		"attack_len": 0.34, "attack_rot": -1.25,
		"cast_len": 0.45, "cast_pulse": 1.35,
	},
	&"caster_channel": {
		"id": &"caster_channel",
		"description": "Measured caster motion with pronounced glow pulses and slower attacks.",
		"idle_len": 1.8, "idle_bob": -1.0, "idle_sway": 0.02,
		"walk_len": 0.62, "walk_bob": -1.8, "walk_sway": 0.045,
		"attack_len": 0.48, "attack_rot": -0.95,
		"cast_len": 0.80, "cast_pulse": 1.9,
	},
	&"merchant_idle": {
		"id": &"merchant_idle",
		"description": "Town NPC idle stance with restrained breathing and no combat snap.",
		"idle_len": 2.0, "idle_bob": -0.8, "idle_sway": 0.012,
		"walk_len": 0.70, "walk_bob": -1.2, "walk_sway": 0.03,
		"attack_len": 0.50, "attack_rot": -0.35,
		"cast_len": 0.75, "cast_pulse": 1.25,
	},
	&"boss_command": {
		"id": &"boss_command",
		"description": "Large boss command stance with heavy breathing and broad arm authority.",
		"idle_len": 1.9, "idle_bob": -2.4, "idle_sway": 0.025,
		"walk_len": 0.65, "walk_bob": -2.6, "walk_sway": 0.07,
		"attack_len": 0.55, "attack_rot": -1.45,
		"cast_len": 0.90, "cast_pulse": 2.0,
	},
	&"enemy_idle_watch": {
		"id": &"enemy_idle_watch", "description": "Enemy idle: predatory watch with shallow breathing.",
		"idle_len": 1.45, "idle_bob": -1.1, "idle_sway": 0.018,
		"walk_len": 0.55, "walk_bob": -2.0, "walk_sway": 0.060,
		"attack_len": 0.42, "attack_rot": -0.85, "cast_len": 0.65, "cast_pulse": 1.5,
	},
	&"enemy_idle_crouch": {
		"id": &"enemy_idle_crouch", "description": "Enemy idle: compressed stance with coiled shoulders.",
		"idle_len": 1.65, "idle_bob": -0.8, "idle_sway": 0.030,
		"walk_len": 0.58, "walk_bob": -1.7, "walk_sway": 0.075,
		"attack_len": 0.40, "attack_rot": -1.05, "cast_len": 0.62, "cast_pulse": 1.45,
	},
	&"enemy_idle_haunt": {
		"id": &"enemy_idle_haunt", "description": "Enemy idle: floating haunt motion for ethereal silhouettes.",
		"idle_len": 1.25, "idle_bob": -2.0, "idle_sway": 0.040,
		"walk_len": 0.48, "walk_bob": -2.8, "walk_sway": 0.120,
		"attack_len": 0.36, "attack_rot": -1.15, "cast_len": 0.58, "cast_pulse": 1.65,
	},
	&"enemy_walk_lurch": {
		"id": &"enemy_walk_lurch", "description": "Enemy walk: uneven lurch with visible weight shifts.",
		"idle_len": 1.55, "idle_bob": -1.0, "idle_sway": 0.020,
		"walk_len": 0.52, "walk_bob": -2.2, "walk_sway": 0.090,
		"attack_len": 0.42, "attack_rot": -0.90, "cast_len": 0.65, "cast_pulse": 1.5,
	},
	&"enemy_walk_hover": {
		"id": &"enemy_walk_hover", "description": "Enemy walk: ground-skimming hover with a pulsing shadow.",
		"idle_len": 1.35, "idle_bob": -1.6, "idle_sway": 0.030,
		"walk_len": 0.44, "walk_bob": -3.0, "walk_sway": 0.130,
		"attack_len": 0.38, "attack_rot": -1.05, "cast_len": 0.70, "cast_pulse": 1.75,
	},
	&"enemy_walk_stalk": {
		"id": &"enemy_walk_stalk", "description": "Enemy walk: deliberate stalk with slower body sway.",
		"idle_len": 1.70, "idle_bob": -0.9, "idle_sway": 0.016,
		"walk_len": 0.68, "walk_bob": -1.6, "walk_sway": 0.045,
		"attack_len": 0.48, "attack_rot": -0.75, "cast_len": 0.74, "cast_pulse": 1.45,
	},
	&"enemy_attack_rake": {
		"id": &"enemy_attack_rake", "description": "Enemy attack: short rake with fast recovery.",
		"idle_len": 1.55, "idle_bob": -1.0, "idle_sway": 0.020,
		"walk_len": 0.54, "walk_bob": -2.0, "walk_sway": 0.070,
		"attack_len": 0.32, "attack_rot": -1.20, "cast_len": 0.62, "cast_pulse": 1.45,
	},
	&"enemy_attack_lunge": {
		"id": &"enemy_attack_lunge", "description": "Enemy attack: lunging hit with body commitment.",
		"idle_len": 1.45, "idle_bob": -1.1, "idle_sway": 0.022,
		"walk_len": 0.50, "walk_bob": -2.3, "walk_sway": 0.090,
		"attack_len": 0.40, "attack_rot": -1.35, "cast_len": 0.66, "cast_pulse": 1.55,
	},
	&"enemy_attack_burst": {
		"id": &"enemy_attack_burst", "description": "Enemy attack: burst strike for larger or caster bodies.",
		"idle_len": 1.70, "idle_bob": -1.4, "idle_sway": 0.024,
		"walk_len": 0.56, "walk_bob": -2.1, "walk_sway": 0.080,
		"attack_len": 0.52, "attack_rot": -1.55, "cast_len": 0.78, "cast_pulse": 1.85,
	},
	&"enemy_cast_channel": {
		"id": &"enemy_cast_channel", "description": "Enemy cast: steady channel with bright pulse.",
		"idle_len": 1.75, "idle_bob": -1.0, "idle_sway": 0.018,
		"walk_len": 0.60, "walk_bob": -1.8, "walk_sway": 0.050,
		"attack_len": 0.46, "attack_rot": -0.90, "cast_len": 0.82, "cast_pulse": 1.95,
	},
	&"enemy_cast_hex": {
		"id": &"enemy_cast_hex", "description": "Enemy cast: abrupt curse snap and high glow peak.",
		"idle_len": 1.50, "idle_bob": -1.2, "idle_sway": 0.026,
		"walk_len": 0.54, "walk_bob": -2.1, "walk_sway": 0.070,
		"attack_len": 0.44, "attack_rot": -1.00, "cast_len": 0.55, "cast_pulse": 2.20,
	},
	&"enemy_cast_summon": {
		"id": &"enemy_cast_summon", "description": "Enemy cast: slower summoning swell with long recovery.",
		"idle_len": 1.90, "idle_bob": -1.4, "idle_sway": 0.018,
		"walk_len": 0.64, "walk_bob": -1.9, "walk_sway": 0.055,
		"attack_len": 0.50, "attack_rot": -0.95, "cast_len": 1.05, "cast_pulse": 2.35,
	},
	&"enemy_die_collapse": {
		"id": &"enemy_die_collapse", "description": "Enemy death: physical collapse weighting.",
		"idle_len": 1.55, "idle_bob": -1.0, "idle_sway": 0.018,
		"walk_len": 0.56, "walk_bob": -1.8, "walk_sway": 0.060,
		"attack_len": 0.44, "attack_rot": -0.95, "cast_len": 0.70, "cast_pulse": 1.45,
	},
	&"enemy_die_dissolve": {
		"id": &"enemy_die_dissolve", "description": "Enemy death: ethereal dissolve stance.",
		"idle_len": 1.35, "idle_bob": -1.8, "idle_sway": 0.030,
		"walk_len": 0.48, "walk_bob": -2.8, "walk_sway": 0.120,
		"attack_len": 0.38, "attack_rot": -1.05, "cast_len": 0.72, "cast_pulse": 1.85,
	},
	&"enemy_die_shatter": {
		"id": &"enemy_die_shatter", "description": "Enemy death: rigid shatter for bone and constructed bodies.",
		"idle_len": 1.45, "idle_bob": -0.7, "idle_sway": 0.010,
		"walk_len": 0.50, "walk_bob": -1.5, "walk_sway": 0.040,
		"attack_len": 0.40, "attack_rot": -0.80, "cast_len": 0.64, "cast_pulse": 1.35,
	},
	&"npc_idle_merchant_watch": {
		"id": &"npc_idle_merchant_watch", "description": "NPC idle: merchant watch with small cloak breath.",
		"idle_len": 2.10, "idle_bob": -0.7, "idle_sway": 0.010,
		"walk_len": 0.72, "walk_bob": -1.2, "walk_sway": 0.026,
		"attack_len": 0.50, "attack_rot": -0.35, "cast_len": 0.76, "cast_pulse": 1.25,
	},
	&"npc_idle_oracle_vigil": {
		"id": &"npc_idle_oracle_vigil", "description": "NPC idle: ritual stillness with slower sway.",
		"idle_len": 2.30, "idle_bob": -0.9, "idle_sway": 0.014,
		"walk_len": 0.78, "walk_bob": -1.1, "walk_sway": 0.024,
		"attack_len": 0.55, "attack_rot": -0.42, "cast_len": 0.90, "cast_pulse": 1.55,
	},
	&"npc_idle_sage_breath": {
		"id": &"npc_idle_sage_breath", "description": "NPC idle: elder breathing with minimal combat motion.",
		"idle_len": 2.45, "idle_bob": -0.6, "idle_sway": 0.008,
		"walk_len": 0.82, "walk_bob": -1.0, "walk_sway": 0.020,
		"attack_len": 0.58, "attack_rot": -0.30, "cast_len": 0.86, "cast_pulse": 1.35,
	},
	&"npc_walk_market_step": {
		"id": &"npc_walk_market_step", "description": "NPC walk: practical market step.",
		"idle_len": 2.0, "idle_bob": -0.7, "idle_sway": 0.010,
		"walk_len": 0.66, "walk_bob": -1.4, "walk_sway": 0.035,
		"attack_len": 0.50, "attack_rot": -0.35, "cast_len": 0.78, "cast_pulse": 1.25,
	},
	&"npc_walk_ceremonial_step": {
		"id": &"npc_walk_ceremonial_step", "description": "NPC walk: slow ceremonial step.",
		"idle_len": 2.2, "idle_bob": -0.8, "idle_sway": 0.012,
		"walk_len": 0.86, "walk_bob": -1.0, "walk_sway": 0.022,
		"attack_len": 0.54, "attack_rot": -0.38, "cast_len": 0.92, "cast_pulse": 1.55,
	},
	&"npc_walk_camp_pace": {
		"id": &"npc_walk_camp_pace", "description": "NPC walk: short camp pacing loop.",
		"idle_len": 2.05, "idle_bob": -0.7, "idle_sway": 0.012,
		"walk_len": 0.74, "walk_bob": -1.2, "walk_sway": 0.028,
		"attack_len": 0.52, "attack_rot": -0.32, "cast_len": 0.84, "cast_pulse": 1.32,
	},
	&"npc_attack_panic_swing": {
		"id": &"npc_attack_panic_swing", "description": "NPC attack: panicked shove or swing.",
		"idle_len": 2.0, "idle_bob": -0.7, "idle_sway": 0.012,
		"walk_len": 0.70, "walk_bob": -1.2, "walk_sway": 0.030,
		"attack_len": 0.46, "attack_rot": -0.62, "cast_len": 0.78, "cast_pulse": 1.25,
	},
	&"npc_attack_spirit_rebuke": {
		"id": &"npc_attack_spirit_rebuke", "description": "NPC attack: forceful rebuke gesture.",
		"idle_len": 2.2, "idle_bob": -0.8, "idle_sway": 0.014,
		"walk_len": 0.78, "walk_bob": -1.1, "walk_sway": 0.026,
		"attack_len": 0.58, "attack_rot": -0.74, "cast_len": 0.92, "cast_pulse": 1.65,
	},
	&"npc_attack_staffless_shove": {
		"id": &"npc_attack_staffless_shove", "description": "NPC attack: empty-hand defensive shove.",
		"idle_len": 2.05, "idle_bob": -0.7, "idle_sway": 0.010,
		"walk_len": 0.72, "walk_bob": -1.2, "walk_sway": 0.028,
		"attack_len": 0.40, "attack_rot": -0.50, "cast_len": 0.80, "cast_pulse": 1.25,
	},
	&"npc_cast_trade_gesture": {
		"id": &"npc_cast_trade_gesture", "description": "NPC cast: ledger or trade gesture.",
		"idle_len": 2.10, "idle_bob": -0.7, "idle_sway": 0.010,
		"walk_len": 0.72, "walk_bob": -1.1, "walk_sway": 0.026,
		"attack_len": 0.50, "attack_rot": -0.34, "cast_len": 0.70, "cast_pulse": 1.20,
	},
	&"npc_cast_quest_omen": {
		"id": &"npc_cast_quest_omen", "description": "NPC cast: omen reveal with brighter pulse.",
		"idle_len": 2.30, "idle_bob": -0.8, "idle_sway": 0.012,
		"walk_len": 0.80, "walk_bob": -1.0, "walk_sway": 0.024,
		"attack_len": 0.54, "attack_rot": -0.40, "cast_len": 0.95, "cast_pulse": 1.80,
	},
	&"npc_cast_blessing": {
		"id": &"npc_cast_blessing", "description": "NPC cast: compact blessing gesture.",
		"idle_len": 2.20, "idle_bob": -0.7, "idle_sway": 0.012,
		"walk_len": 0.76, "walk_bob": -1.0, "walk_sway": 0.024,
		"attack_len": 0.52, "attack_rot": -0.38, "cast_len": 0.82, "cast_pulse": 1.50,
	},
	&"npc_die_old_man_fall": {
		"id": &"npc_die_old_man_fall", "description": "NPC death: old man fall, grounded and slow.",
		"idle_len": 2.20, "idle_bob": -0.6, "idle_sway": 0.010,
		"walk_len": 0.78, "walk_bob": -1.0, "walk_sway": 0.022,
		"attack_len": 0.52, "attack_rot": -0.32, "cast_len": 0.80, "cast_pulse": 1.20,
	},
	&"npc_die_veil_collapse": {
		"id": &"npc_die_veil_collapse", "description": "NPC death: robed veil collapse.",
		"idle_len": 2.30, "idle_bob": -0.8, "idle_sway": 0.012,
		"walk_len": 0.82, "walk_bob": -1.0, "walk_sway": 0.024,
		"attack_len": 0.54, "attack_rot": -0.38, "cast_len": 0.88, "cast_pulse": 1.45,
	},
	&"npc_die_kneel": {
		"id": &"npc_die_kneel", "description": "NPC death: controlled kneel before collapse.",
		"idle_len": 2.10, "idle_bob": -0.7, "idle_sway": 0.010,
		"walk_len": 0.76, "walk_bob": -1.1, "walk_sway": 0.026,
		"attack_len": 0.50, "attack_rot": -0.36, "cast_len": 0.84, "cast_pulse": 1.35,
	},
	&"player_idle_guard": {
		"id": &"player_idle_guard", "description": "Player unarmed idle: compact guard with readable shoulders.",
		"idle_len": 1.55, "idle_bob": -1.0, "idle_sway": 0.016,
		"walk_len": 0.54, "walk_bob": -1.8, "walk_sway": 0.052,
		"attack_len": 0.40, "attack_rot": -0.78, "cast_len": 0.68, "cast_pulse": 1.45,
	},
	&"player_idle_low": {
		"id": &"player_idle_low", "description": "Player unarmed idle: lower stance with ready knees.",
		"idle_len": 1.70, "idle_bob": -0.8, "idle_sway": 0.026,
		"walk_len": 0.56, "walk_bob": -1.9, "walk_sway": 0.064,
		"attack_len": 0.38, "attack_rot": -0.92, "cast_len": 0.70, "cast_pulse": 1.40,
	},
	&"player_idle_focus": {
		"id": &"player_idle_focus", "description": "Player unarmed idle: caster focus with calmer legs.",
		"idle_len": 1.85, "idle_bob": -0.7, "idle_sway": 0.010,
		"walk_len": 0.62, "walk_bob": -1.4, "walk_sway": 0.035,
		"attack_len": 0.44, "attack_rot": -0.62, "cast_len": 0.84, "cast_pulse": 1.80,
	},
	&"player_walk_advance": {
		"id": &"player_walk_advance", "description": "Player unarmed walk: direct advance with balanced leg swing.",
		"idle_len": 1.60, "idle_bob": -0.9, "idle_sway": 0.014,
		"walk_len": 0.50, "walk_bob": -2.1, "walk_sway": 0.070,
		"attack_len": 0.40, "attack_rot": -0.80, "cast_len": 0.68, "cast_pulse": 1.45,
	},
	&"player_walk_stalk": {
		"id": &"player_walk_stalk", "description": "Player unarmed walk: slower stalking step.",
		"idle_len": 1.70, "idle_bob": -0.8, "idle_sway": 0.018,
		"walk_len": 0.64, "walk_bob": -1.5, "walk_sway": 0.045,
		"attack_len": 0.42, "attack_rot": -0.72, "cast_len": 0.72, "cast_pulse": 1.50,
	},
	&"player_walk_quick": {
		"id": &"player_walk_quick", "description": "Player unarmed walk: fast short-stride footwork.",
		"idle_len": 1.45, "idle_bob": -1.0, "idle_sway": 0.020,
		"walk_len": 0.42, "walk_bob": -2.4, "walk_sway": 0.090,
		"attack_len": 0.34, "attack_rot": -0.95, "cast_len": 0.60, "cast_pulse": 1.38,
	},
	&"player_attack_jab": {
		"id": &"player_attack_jab", "description": "Player unarmed attack: fast outward jab.",
		"idle_len": 1.55, "idle_bob": -0.9, "idle_sway": 0.014,
		"walk_len": 0.52, "walk_bob": -1.9, "walk_sway": 0.058,
		"attack_len": 0.30, "attack_rot": -1.10, "cast_len": 0.66, "cast_pulse": 1.40,
	},
	&"player_attack_cross": {
		"id": &"player_attack_cross", "description": "Player unarmed attack: committed cross from the shoulder.",
		"idle_len": 1.55, "idle_bob": -0.9, "idle_sway": 0.014,
		"walk_len": 0.54, "walk_bob": -1.9, "walk_sway": 0.060,
		"attack_len": 0.40, "attack_rot": -1.32, "cast_len": 0.68, "cast_pulse": 1.45,
	},
	&"player_attack_hook": {
		"id": &"player_attack_hook", "description": "Player unarmed attack: arcing hook that still strikes away from body.",
		"idle_len": 1.60, "idle_bob": -0.9, "idle_sway": 0.016,
		"walk_len": 0.54, "walk_bob": -1.8, "walk_sway": 0.062,
		"attack_len": 0.46, "attack_rot": -1.18, "cast_len": 0.70, "cast_pulse": 1.50,
	},
	&"player_cast_focus": {
		"id": &"player_cast_focus", "description": "Player unarmed cast: hands gather energy close to chest.",
		"idle_len": 1.80, "idle_bob": -0.7, "idle_sway": 0.010,
		"walk_len": 0.62, "walk_bob": -1.4, "walk_sway": 0.036,
		"attack_len": 0.42, "attack_rot": -0.64, "cast_len": 0.72, "cast_pulse": 1.85,
	},
	&"player_cast_reach": {
		"id": &"player_cast_reach", "description": "Player unarmed cast: outward hand release.",
		"idle_len": 1.75, "idle_bob": -0.8, "idle_sway": 0.012,
		"walk_len": 0.60, "walk_bob": -1.5, "walk_sway": 0.040,
		"attack_len": 0.42, "attack_rot": -0.68, "cast_len": 0.86, "cast_pulse": 2.05,
	},
	&"player_cast_ground": {
		"id": &"player_cast_ground", "description": "Player unarmed cast: grounded ritual pulse.",
		"idle_len": 1.90, "idle_bob": -0.6, "idle_sway": 0.008,
		"walk_len": 0.66, "walk_bob": -1.2, "walk_sway": 0.030,
		"attack_len": 0.44, "attack_rot": -0.58, "cast_len": 0.96, "cast_pulse": 2.20,
	},
	&"player_die_fall": {
		"id": &"player_die_fall", "description": "Player death: clean fall with physical weight.",
		"idle_len": 1.60, "idle_bob": -0.8, "idle_sway": 0.012,
		"walk_len": 0.55, "walk_bob": -1.7, "walk_sway": 0.050,
		"attack_len": 0.42, "attack_rot": -0.70, "cast_len": 0.70, "cast_pulse": 1.35,
	},
	&"player_die_kneel": {
		"id": &"player_die_kneel", "description": "Player death: knees fold before collapse.",
		"idle_len": 1.70, "idle_bob": -0.7, "idle_sway": 0.010,
		"walk_len": 0.58, "walk_bob": -1.5, "walk_sway": 0.045,
		"attack_len": 0.40, "attack_rot": -0.64, "cast_len": 0.74, "cast_pulse": 1.40,
	},
	&"player_die_collapse": {
		"id": &"player_die_collapse", "description": "Player death: full-body collapse variant.",
		"idle_len": 1.55, "idle_bob": -0.9, "idle_sway": 0.014,
		"walk_len": 0.54, "walk_bob": -1.8, "walk_sway": 0.052,
		"attack_len": 0.42, "attack_rot": -0.72, "cast_len": 0.70, "cast_pulse": 1.35,
	},

}

const DEFAULT_STANCE: StringName = &"idle_breathe"

static func get_stance(id: StringName) -> Dictionary:
	return STANCES.get(id, STANCES[DEFAULT_STANCE])

static func all_ids() -> Array:
	return STANCES.keys()

static func ids_for_context(bucket: StringName, _sprite_id: StringName, anim_name: StringName) -> Array:
	if bucket == &"npcs":
		return _ids_for_prefix("npc", String(anim_name))
	if bucket == &"classes":
		return _ids_for_prefix("player", String(anim_name))
	return _ids_for_prefix("enemy", String(anim_name))

static func _ids_for_prefix(prefix: String, anim_name: String) -> Array:
	match anim_name:
		"walk":
			return _walk_ids(prefix)
		"attack":
			return _attack_ids(prefix)
		"cast":
			return _cast_ids(prefix)
		"die":
			return _die_ids(prefix)
		_:
			return _idle_ids(prefix)

static func _idle_ids(prefix: String) -> Array:
	if prefix == "npc":
		return [&"npc_idle_merchant_watch", &"npc_idle_oracle_vigil", &"npc_idle_sage_breath"]
	if prefix == "player":
		return [&"player_idle_guard", &"player_idle_low", &"player_idle_focus"]
	return [&"enemy_idle_watch", &"enemy_idle_crouch", &"enemy_idle_haunt"]

static func _walk_ids(prefix: String) -> Array:
	if prefix == "npc":
		return [&"npc_walk_market_step", &"npc_walk_ceremonial_step", &"npc_walk_camp_pace"]
	if prefix == "player":
		return [&"player_walk_advance", &"player_walk_stalk", &"player_walk_quick"]
	return [&"enemy_walk_lurch", &"enemy_walk_hover", &"enemy_walk_stalk"]

static func _attack_ids(prefix: String) -> Array:
	if prefix == "npc":
		return [&"npc_attack_panic_swing", &"npc_attack_spirit_rebuke", &"npc_attack_staffless_shove"]
	if prefix == "player":
		return [&"player_attack_jab", &"player_attack_cross", &"player_attack_hook"]
	return [&"enemy_attack_rake", &"enemy_attack_lunge", &"enemy_attack_burst"]

static func _cast_ids(prefix: String) -> Array:
	if prefix == "npc":
		return [&"npc_cast_trade_gesture", &"npc_cast_quest_omen", &"npc_cast_blessing"]
	if prefix == "player":
		return [&"player_cast_focus", &"player_cast_reach", &"player_cast_ground"]
	return [&"enemy_cast_channel", &"enemy_cast_hex", &"enemy_cast_summon"]

static func _die_ids(prefix: String) -> Array:
	if prefix == "npc":
		return [&"npc_die_old_man_fall", &"npc_die_veil_collapse", &"npc_die_kneel"]
	if prefix == "player":
		return [&"player_die_fall", &"player_die_kneel", &"player_die_collapse"]
	return [&"enemy_die_collapse", &"enemy_die_dissolve", &"enemy_die_shatter"]
