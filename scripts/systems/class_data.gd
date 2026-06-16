class_name ClassData extends Resource
## AD-02 — per-class tunables consumed by Stats and (Stage 2) Player.
## .tres files live in data/classes/ and are loaded by Database at boot.

@export var id: StringName
@export var display_name: String

## One of: &"strength", &"dexterity", &"vitality", &"pneuma".
## Used by class-balance audits to verify identity invariants.
@export var primary_attribute: StringName

@export_group("Base attributes (level 1)")
@export var base_strength: int = 0
@export var base_dexterity: int = 0
@export var base_vitality: int = 0
@export var base_pneuma: int = 0

@export_group("Per-level gains (automatic)")
@export var str_per_level: int = 0
@export var dex_per_level: int = 0
@export var vit_per_level: int = 0
@export var pne_per_level: int = 0

@export_group("HP / MP coefficients")
@export var base_hp: int = 0
@export var vit_per_hp: float = 0.0
@export var base_mp: int = 0
@export var pne_per_mp: float = 0.0

@export_group("Visuals")
## Stage 17.7 — preferred: resolve the sprite through CharacterRegistry
## by this id. Falls back to `sprite_scene` when empty/unregistered.
@export var character_id: StringName = &""
## Populated in Stage 2 with the procedural sprite scene (fallback).
@export var sprite_scene: PackedScene
