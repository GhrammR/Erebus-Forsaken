class_name EliteModifier extends Resource
## Stage 8 — elite suffix. Applied to an Enemy at spawn time. Three
## fixed suffixes ship: Fast, Tough, Spawner.
##
## Why a Resource (not subclassing Enemy): we want any wilderness or
## dungeon enemy to be optionally elite without scene duplication.
## The modifier is referenced by id from the save snapshot so a
## Tough Shade-Wretch round-trips as "shade_wretch + elite_tough".

@export var id: StringName
@export var display_name: String = ""

@export_group("Stat multipliers")
@export var hp_mult: float = 1.0
@export var damage_mult: float = 1.0
@export var defense_mult: float = 1.0
@export var speed_mult: float = 1.0
@export var attack_interval_mult: float = 1.0

@export_group("Visual")
## Multiplied into _sprite_anchor.modulate. Use values > 1.0 to brighten,
## < 1.0 to darken. Identity is Color(1,1,1,1).
@export var tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var scale_mult: float = 1.0

@export_group("Spawner suffix (optional)")
## When non-empty, on death the elite spawns N copies of this enemy_id
## at its position. Used by elite_spawner to drop a pair of trash on
## kill — adds "this isn't done yet" pressure to the room clear.
@export var spawns_on_death: StringName = &""
@export var spawn_count: int = 0
