extends Node
## Versioned save/load. See AD-06 and AD-07 in
## .agent_governance/rules/architecture-decisions.md.
##
## - SAVE_VERSION bumps with any schema change.
## - migrate() upgrades older saves on load.
## - Items and other content are stored by StringName ID, never by
##   res:// path (paths break under reorganization).

const SAVE_VERSION: int = 1
const SAVE_PATH: String = "user://save_slot_1.dat"

signal save_completed
signal load_completed(success: bool)

func save_game() -> void:
	push_warning("SaveSystem.save_game stub — implemented in Stage 4")
	save_completed.emit()

func load_game() -> bool:
	push_warning("SaveSystem.load_game stub — implemented in Stage 4")
	load_completed.emit(false)
	return false

func migrate(old: Dictionary) -> Dictionary:
	var version: int = int(old.get("version", 0))
	if version == SAVE_VERSION:
		return old
	# Future migrations chain here: if version < N: old = _migrate_to_N(old)
	return old
