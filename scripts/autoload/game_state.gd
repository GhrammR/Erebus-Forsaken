extends Node
## Run-scoped state. Holds references that the player session needs but
## that should not be sprinkled across scripts via get_node chains.
##
## See .agent_governance/rules/scene-architecture.md — this autoload is
## state, not behavior. No combat math, no save logic, no zone routing.

var player: Node = null
var current_zone_id: StringName = &""

## Set by the character-select scene, consumed by game.gd._ready
## on the new-game path. Transient — never written to the save file
## (class_id lives in the save under AD-06).
var pending_class_id: StringName = &""

## Stage 9 — Act 1 completion + first-kill state. The Act boss sets
## these in its death handler. Persisted via SaveSystem v12.
## act_1_complete unlocks the endless portal slot (Stage 9.7).
## boss_first_kill gates the guaranteed unique drop — once true, the
## boss falls back to its normal drop table on subsequent kills.
var act_1_complete: bool = false
var boss_first_kill: bool = false

## Stage 9.7 polish — Tower of Ascension milestones the player has
## already claimed. Persistent across runs (the reward is one-time).
## EndlessDirector reads this on _advance_wave_to to decide whether
## to grant the milestone reward; rewards write back through here.
## Stored as an array of ints (floor numbers) to keep the save JSON
## stable across schema changes.
var endless_milestones: Array = []

## Stage 9.7 polish — cosmetic titles the player has earned. Floor 50
## grants "Delver"; future stages may add more. Surfaced by the
## character-select screen (parked: skill-page / character-sheet UI).
## Stored as strings to keep the save JSON portable.
var titles: Array = []

const BUILD_VERSION: String = "0.0.1"

func reset_run() -> void:
	player = null
	current_zone_id = &""
	pending_class_id = &""
	act_1_complete = false
	boss_first_kill = false
	endless_milestones = []
	titles = []
